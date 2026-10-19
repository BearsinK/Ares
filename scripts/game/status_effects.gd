class_name StatusEffects
extends RefCounted
## Statuseffekte auf einem Ziel (Gegner oder Puppe) und die Element-Kombos.
## Status liegen auf dem Ziel, egal welcher Spieler sie gesetzt hat. Sie halten
## nur kurz. Kombos sind staerker, wenn zwei verschiedene Spieler zusammenarbeiten
## (Status von Spieler A, Ausloeser von Spieler B).
##
## Kombos:
##   Wasser + Blitz  nasse Ziele nehmen mehr Blitzschaden, Blitz springt auf nasse Nachbarn
##   Wasser + Eis    gefroren (Ziel steht still)
##   Wasser + Feuer  Dampfexplosion
##   Feuer + Eis     schmilzt, hebt beides auf

const WET_TIME := 3.0
const BURN_TIME := 2.5
const CHILL_TIME := 2.5
const FROZEN_TIME_SOLO := 1.2
const FROZEN_TIME_COOP := 2.0
const BURN_TICK := 0.5

const SHOCK_MULT_SOLO := 1.5
const SHOCK_MULT_COOP := 2.5
const ARCS_SOLO := 1
const ARCS_COOP := 3
const ARC_RADIUS := 240.0
const STEAM_RADIUS := 100.0
const STEAM_DAMAGE_SOLO := 30.0
const STEAM_DAMAGE_COOP := 70.0
const BURN_DAMAGE := 4.0

var target: Node2D
var _status: Dictionary = {}
var _burn_timer := 0.0


func _init(owner_node: Node2D) -> void:
	target = owner_node


func has(status_name: String) -> bool:
	return _status.has(status_name)


func is_frozen() -> bool:
	return _status.has("frozen")


func speed_factor() -> float:
	if _status.has("frozen"):
		return 0.0
	if _status.has("chilled"):
		return 0.6
	return 1.0


func update(delta: float) -> void:
	for status_name in _status.keys():
		_status[status_name].t -= delta
		if _status[status_name].t <= 0.0:
			_status.erase(status_name)
	if _status.has("burning"):
		_burn_timer -= delta
		if _burn_timer <= 0.0:
			_burn_timer = BURN_TICK
			var source: Node = _status.burning.source
			var power := _power_of(source)
			target.take_damage(BURN_DAMAGE * power, source, Vector2.ZERO, "fire", true)


## Wird beim Treffer aufgerufen. Gibt den (eventuell erhoehten) Schaden zurueck.
func process_hit(element: String, source: Node, amount: float) -> float:
	match element:
		"water":
			if _status.has("burning"):
				var coop := _is_coop(_status.burning.source, source)
				_status.erase("burning")
				_steam(source, coop)
			else:
				_apply_status("wet", WET_TIME, source)
		"fire":
			if _status.has("wet"):
				var coop := _is_coop(_status.wet.source, source)
				_status.erase("wet")
				_steam(source, coop)
			elif _status.has("chilled") or _status.has("frozen"):
				_status.erase("chilled")
				_status.erase("frozen")
				_effect_burst(Color(1.0, 0.8, 0.6))
			else:
				_apply_status("burning", BURN_TIME, source)
		"ice":
			if _status.has("wet"):
				var coop := _is_coop(_status.wet.source, source)
				_status.erase("wet")
				_apply_status("frozen", FROZEN_TIME_COOP if coop else FROZEN_TIME_SOLO, source)
				_effect_burst(Elements.COLORS.ice)
				Sfx.play("freeze")
			elif _status.has("burning"):
				_status.erase("burning")
				_effect_burst(Color(0.8, 0.9, 1.0))
			else:
				_apply_status("chilled", CHILL_TIME, source)
		"lightning":
			if _status.has("wet"):
				var coop := _is_coop(_status.wet.source, source)
				var mult := SHOCK_MULT_COOP if coop else SHOCK_MULT_SOLO
				_arc_to_wet(amount * 0.6 * mult, source, ARCS_COOP if coop else ARCS_SOLO)
				return amount * mult
			_effect_burst(Elements.COLORS.lightning)
	return amount


func draw_overlay(item: CanvasItem, radius: float, time: float) -> void:
	if _status.has("wet"):
		item.draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 24, Color(0.3, 0.6, 1.0, 0.9), 3.0)
		for i in 3:
			var a := time * 2.0 + i * 2.1
			item.draw_circle(Vector2(cos(a), sin(a)) * (radius + 6.0), 2.5, Color(0.5, 0.8, 1.0))
	if _status.has("burning"):
		for i in 3:
			var flicker := sin(time * 18.0 + i * 2.0)
			item.draw_circle(Vector2((i - 1) * radius * 0.5, -radius - 4.0 - flicker * 3.0), 4.0, Color(1.0, 0.5 + 0.3 * flicker, 0.1, 0.9))
	if _status.has("chilled"):
		item.draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 24, Color(0.7, 0.95, 1.0, 0.8), 2.0)
	if _status.has("frozen"):
		var r := radius + 5.0
		item.draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), Color(0.7, 0.95, 1.0, 0.45))
		item.draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), Color(0.9, 1.0, 1.0), false, 2.0)


func _apply_status(status_name: String, duration: float, source: Node) -> void:
	_status[status_name] = {"t": duration, "source": source}


func _is_coop(status_source: Node, trigger_source: Node) -> bool:
	return status_source != null and trigger_source != null \
		and is_instance_valid(status_source) and is_instance_valid(trigger_source) \
		and status_source != trigger_source


func _power_of(source: Node) -> float:
	if source is Player:
		return source.damage_mult()
	return 1.0


func _effect_burst(color: Color) -> void:
	if Fx.instance:
		Fx.instance.spark(target.global_position, color, 8, 300.0)


func _steam(source: Node, coop: bool) -> void:
	var damage := (STEAM_DAMAGE_COOP if coop else STEAM_DAMAGE_SOLO) * _power_of(source)
	var radius := STEAM_RADIUS * (1.3 if coop else 1.0)
	if Fx.instance:
		Fx.instance.explosion(target.global_position, radius, Color(0.85, 0.9, 0.95))
	Sfx.play("steam")
	for enemy in target.get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(target.global_position) <= radius + 20.0:
			enemy.take_damage(damage, source, Vector2.ZERO, "", true)


func _arc_to_wet(damage: float, source: Node, max_arcs: int) -> void:
	var candidates: Array[Node2D] = []
	for enemy in target.get_tree().get_nodes_in_group("enemies"):
		if enemy == target or not is_instance_valid(enemy):
			continue
		if enemy.statuses.has("wet") and enemy.global_position.distance_to(target.global_position) <= ARC_RADIUS:
			candidates.append(enemy)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(target.global_position) < b.global_position.distance_squared_to(target.global_position))
	var from := target.global_position
	for i in mini(max_arcs, candidates.size()):
		var enemy := candidates[i]
		if Fx.instance:
			Fx.instance.tracer(from, enemy.global_position, Elements.COLORS.lightning, 3.0, 0.15)
		enemy.take_damage(damage, source, Vector2.ZERO, "lightning", true)
		from = enemy.global_position
	Sfx.play("zap")
