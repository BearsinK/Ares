class_name StatusEffects
extends RefCounted
## Statuseffekte auf einem Ziel (Gegner oder Puppe) und die Element-Kombos.
## Status liegen auf dem Ziel, egal welcher Spieler sie gesetzt hat. Sie halten
## nur kurz. Kombos sind staerker, wenn zwei verschiedene Spieler zusammenarbeiten
## (Status von Spieler A, Ausloeser von Spieler B).
##
## Kombos (siehe Elements.COMBOS):
##   Wasser + Blitz  Stromschlag: nasse Ziele nehmen mehr Blitzschaden, Blitz springt auf nasse Nachbarn, kurze Laehmung
##   Wasser + Eis    gefroren: Ziel steht still, nimmt mehr Schaden und zersplittert beim Tod
##   Wasser + Feuer  Dampfexplosion
##   Feuer + Eis     schmilzt, hebt beides auf
##   Feuer + Blitz   Ueberlast: brennendes Ziel explodiert
##   Eis + Blitz     Kurzschluss: kaltes Ziel wird gelaehmt und nimmt Schaden

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
const OVERLOAD_RADIUS := 95.0
const OVERLOAD_DAMAGE_SOLO := 38.0
const OVERLOAD_DAMAGE_COOP := 75.0
const SHORT_STUN_SOLO := 1.0
const SHORT_STUN_COOP := 1.8
const SHORT_DAMAGE_SOLO := 20.0
const SHORT_DAMAGE_COOP := 40.0
const SHOCK_STUN_SOLO := 0.4
const SHOCK_STUN_COOP := 0.8
const BRITTLE_MULT := 1.3
const SHATTER_RADIUS := 110.0
const SHATTER_DAMAGE := 26.0
## Blitze springen auch ohne Nässe manchmal auf einen Nachbarn ueber.
const SPARK_CHANCE := 0.3
const SPARK_DAMAGE := 0.5
const SPARK_RADIUS := 210.0
## Kurze Meldung, wenn ein Zustand neu gesetzt wird: Text und Farbe.
const POPUPS := {
	"wet": ["Nass", Color(0.4, 0.7, 1.0)], "burning": ["Brennt", Color(1.0, 0.55, 0.2)],
	"chilled": ["Frostig", Color(0.75, 0.95, 1.0)], "frozen": ["Eingefroren", Color(0.75, 0.95, 1.0)],
	"webbed": ["Gespinst", Color(0.95, 0.97, 1.0)], "inked": ["Tinte", Color(0.7, 0.55, 1.0)], "tagged": ["Markiert", Color(1.0, 0.88, 0.35)],
}
## Zustaende aus Waffen (nicht aus Elementen): Gespinst bremst stark, Tinte bremst, Markierung erhoeht den Schaden.
const WEB_TIME := 3.0
const WEB_SPEED := 0.3
const INK_SPEED := 0.55
const TAG_MULT := 1.3

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
	var factor := 1.0
	if _status.has("chilled"):
		factor = 0.6
	if _status.has("webbed"):
		factor = minf(factor, WEB_SPEED)
	if _status.has("inked"):
		factor = minf(factor, INK_SPEED)
	return factor


## Schadensfaktor auf das Ziel: markierte Gegner (Labeler) nehmen von allen mehr Schaden.
func damage_factor() -> float:
	var factor := TAG_MULT if _status.has("tagged") else 1.0
	# Gefrorene Ziele sind spröde.
	if _status.has("frozen") and not (target is Boss):
		factor *= BRITTLE_MULT
	return factor


## Zustand aus einer Waffe setzen. Ein laengerer Rest bleibt erhalten.
func apply(status_name: String, duration: float, source: Node) -> void:
	var left: float = float(_status[status_name].t) if _status.has(status_name) else 0.0
	_apply_status(status_name, maxf(duration, left), source)


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
				var cold: Dictionary = _status.frozen if _status.has("frozen") else _status.chilled
				var coop := _is_coop(cold.source, source)
				_status.erase("chilled")
				_status.erase("frozen")
				_combo("melt", coop)
			else:
				_apply_status("burning", BURN_TIME, source)
		"ice":
			if _status.has("wet") and not (target is Boss):
				var coop := _is_coop(_status.wet.source, source)
				_status.erase("wet")
				_apply_status("frozen", FROZEN_TIME_COOP if coop else FROZEN_TIME_SOLO, source)
				_combo("freeze", coop)
				Sfx.play("freeze")
			elif _status.has("wet"):
				# Bosse frieren nicht ein: nur Kaelte.
				_status.erase("wet")
				_apply_status("chilled", CHILL_TIME, source)
			elif _status.has("burning"):
				var coop := _is_coop(_status.burning.source, source)
				_status.erase("burning")
				_combo("melt", coop)
			else:
				_apply_status("chilled", CHILL_TIME, source)
		"lightning":
			if _status.has("wet"):
				var coop := _is_coop(_status.wet.source, source)
				var mult := SHOCK_MULT_COOP if coop else SHOCK_MULT_SOLO
				_arc_to_wet(amount * 0.6 * mult, source, ARCS_COOP if coop else ARCS_SOLO)
				_stun(SHOCK_STUN_COOP if coop else SHOCK_STUN_SOLO)
				_apply_status("shocked", 0.5, source)
				_combo("shock", coop)
				return amount * mult
			if _status.has("burning"):
				_overload(source, _is_coop(_status.burning.source, source))
			elif _status.has("chilled") or _status.has("frozen"):
				var cold: Dictionary = _status.frozen if _status.has("frozen") else _status.chilled
				_short_circuit(source, _is_coop(cold.source, source))
			else:
				_apply_status("shocked", 0.5, source)
				_effect_burst(Elements.COLORS.lightning)
				_spark_over(amount, source)
	return amount


## Das Ziel stirbt: Gefrorene zersplittern, die Scherben verletzen Nachbarn.
func on_death() -> void:
	if not _status.has("frozen"):
		return
	var source: Node = _status.frozen.source
	var damage := SHATTER_DAMAGE * _power_of(source)
	if Fx.instance:
		Fx.instance.element_hit(target.global_position, "ice", 3.0)
		Fx.instance.ring(target.global_position, SHATTER_RADIUS, Elements.COLORS.ice)
	Sfx.play("freeze")
	for enemy in target.get_tree().get_nodes_in_group("enemies"):
		if enemy != target and is_instance_valid(enemy) and enemy.global_position.distance_to(target.global_position) <= SHATTER_RADIUS + 20.0:
			enemy.take_damage(damage, source, (enemy.global_position - target.global_position).normalized(), "", true)


func draw_overlay(item: CanvasItem, radius: float, time: float) -> void:
	if _status.has("wet"):
		# Glaenzende Nässe: blauer Schimmer, Ring und Tropfen, die vom Koerper laufen.
		item.draw_circle(Vector2.ZERO, radius + 2.0, Color(0.3, 0.55, 1.0, 0.16))
		item.draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 24, Color(0.3, 0.6, 1.0, 0.9), 3.0)
		for i in 4:
			var phase := fposmod(time * 1.3 + i * 0.27, 1.0)
			var x := (float(i) - 1.5) * radius * 0.5
			item.draw_circle(Vector2(x, -radius * 0.3 + phase * radius * 1.5), 2.6 * (1.0 - phase * 0.4), Color(0.5, 0.8, 1.0, 1.0 - phase))
	if _status.has("burning"):
		# Flammen und Glut ueber dem Koerper, Schein darunter.
		item.draw_circle(Vector2.ZERO, radius + 4.0, Color(1.0, 0.45, 0.1, 0.18))
		for i in 4:
			var flicker := sin(time * 16.0 + i * 1.9)
			var x := (float(i) - 1.5) * radius * 0.55
			var base := Vector2(x, -radius * 0.55)
			var tall := radius * (0.8 + 0.25 * flicker)
			item.draw_colored_polygon(PackedVector2Array([base + Vector2(-radius * 0.2, 0.0), base + Vector2(flicker * 3.0, -tall), base + Vector2(radius * 0.2, 0.0)]), Color(1.0, 0.45 + 0.2 * flicker, 0.1, 0.85))
			item.draw_colored_polygon(PackedVector2Array([base + Vector2(-radius * 0.1, 0.0), base + Vector2(flicker * 2.0, -tall * 0.6), base + Vector2(radius * 0.1, 0.0)]), Color(1.0, 0.9, 0.5, 0.9))
		for i in 3:
			var rise := fposmod(time * 1.1 + i * 0.33, 1.0)
			item.draw_circle(Vector2(sin(time * 3.0 + i * 2.0) * radius * 0.6, -radius - rise * radius * 1.2), 2.4 * (1.0 - rise), Color(1.0, 0.7, 0.2, 1.0 - rise))
	if _status.has("chilled"):
		# Frost: blasser Schimmer, Ring und kleine Eisspitzen am Rand.
		item.draw_circle(Vector2.ZERO, radius + 2.0, Color(0.7, 0.95, 1.0, 0.14))
		item.draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 24, Color(0.7, 0.95, 1.0, 0.8), 2.0)
		for i in 7:
			var a := TAU * i / 7.0 + 0.4
			var dir := Vector2(cos(a), sin(a))
			item.draw_colored_polygon(PackedVector2Array([dir * (radius + 1.0) + dir.orthogonal() * 3.0, dir * (radius + 9.0), dir * (radius + 1.0) - dir.orthogonal() * 3.0]), Color(0.85, 0.98, 1.0, 0.9))
	if _status.has("frozen"):
		var r := radius + 5.0
		item.draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), Color(0.7, 0.95, 1.0, 0.45))
		item.draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), Color(0.9, 1.0, 1.0), false, 2.0)
		# Facetten und Glanz.
		item.draw_line(Vector2(-r, -r * 0.2), Vector2(r * 0.3, -r), Color(1, 1, 1, 0.5), 1.5)
		item.draw_line(Vector2(-r * 0.4, r), Vector2(r, r * 0.1), Color(1, 1, 1, 0.35), 1.5)
		item.draw_line(Vector2(-r * 0.6, -r * 0.6), Vector2(-r * 0.2, -r * 0.2), Color(1, 1, 1, 0.8), 2.0)
	if _status.has("shocked"):
		# Zuckende Funken rund um den Koerper (flackern im festen Takt).
		var seed_step := int(time * 28.0)
		for i in 4:
			var a := float((seed_step * 7 + i * 13) % 100) / 100.0 * TAU
			var from := Vector2(cos(a), sin(a)) * radius
			var mid := from + Vector2(cos(a + 1.2), sin(a + 1.2)) * radius * 0.35
			var to := from + Vector2(cos(a), sin(a)) * radius * 0.55
			item.draw_polyline(PackedVector2Array([from, mid, to]), Color(1.0, 0.95, 0.3, 0.95), 2.0, true)
	if _status.has("webbed"):
		# Gespinst: Speichen und zwei Ringe ueber dem ganzen Gegner.
		var web := Color(0.95, 0.97, 1.0, 0.85)
		for i in 6:
			var a := TAU * i / 6.0 + 0.3
			item.draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * (radius + 6.0), web, 1.5, true)
		for ring in [0.55, 1.0]:
			var points := PackedVector2Array()
			for i in 7:
				var a := TAU * i / 6.0 + 0.3
				points.append(Vector2(cos(a), sin(a)) * (radius + 6.0) * ring)
			item.draw_polyline(points, web, 1.5, true)
	if _status.has("inked"):
		for i in 4:
			var a := time * 0.8 + i * 1.6
			item.draw_circle(Vector2(cos(a), sin(a * 1.3)) * radius * 0.6, 4.5 + 2.0 * sin(time * 3.0 + i), Color(0.08, 0.05, 0.12, 0.85))
	if _status.has("tagged"):
		# Etikett ueber dem Kopf.
		var tag := Rect2(Vector2(-9.0, -radius - 26.0), Vector2(18.0, 11.0))
		item.draw_rect(tag, Color(1.0, 0.85, 0.3))
		item.draw_rect(tag, Color(0.2, 0.15, 0.05), false, 1.5)
		item.draw_line(tag.position + Vector2(4.0, 5.5), tag.position + Vector2(14.0, 5.5), Color(0.2, 0.15, 0.05), 2.0)


func _apply_status(status_name: String, duration: float, source: Node) -> void:
	# Beim ersten Setzen eine kurze Meldung ueber dem Ziel, damit man sieht, was das Modul bewirkt.
	if not _status.has(status_name) and POPUPS.has(status_name) and Fx.instance != null and is_instance_valid(target):
		var info: Array = POPUPS[status_name]
		var lift := float(target.radius()) + 22.0 if target.has_method("radius") else 40.0
		Fx.instance.number_text(target.global_position + Vector2(0.0, -lift), String(info[0]), info[1], 15, 0.8)
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


func _combo(combo_name: String, coop: bool) -> void:
	Achievements.combos_seen[combo_name] = true
	Tips.request("combo")
	if Fx.instance and is_instance_valid(target):
		Fx.instance.combo(target.global_position, combo_name, coop)


## Laehmung aus einer Kombo. Gegner mit Immunitaet (apply_status) lassen sich nicht dauerhaft festnageln.
func _stun(duration: float) -> void:
	if target.has_method("apply_status") and target.has_method("stun"):
		target.apply_status("stun", duration, null)
	elif target.has_method("stun"):
		target.stun(duration)


## Ueberlast (Feuer + Blitz): das brennende Ziel explodiert und verletzt alle im Umkreis.
func _overload(source: Node, coop: bool) -> void:
	_status.erase("burning")
	var radius := OVERLOAD_RADIUS * (1.3 if coop else 1.0)
	var damage := (OVERLOAD_DAMAGE_COOP if coop else OVERLOAD_DAMAGE_SOLO) * _power_of(source)
	if Fx.instance:
		Fx.instance.explosion(target.global_position, radius, Color(1.0, 0.7, 0.25))
	Sfx.play("combo_overload")
	_combo("overload", coop)
	for enemy in target.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.global_position.distance_to(target.global_position) <= radius + 20.0:
			enemy.take_damage(damage, source, (enemy.global_position - target.global_position).normalized() * 1.5, "", true)


## Kurzschluss (Eis + Blitz): das kalte Ziel wird gelaehmt und nimmt Schaden.
func _short_circuit(source: Node, coop: bool) -> void:
	_status.erase("chilled")
	_status.erase("frozen")
	_stun(SHORT_STUN_COOP if coop else SHORT_STUN_SOLO)
	_apply_status("shocked", 0.8, source)
	Sfx.play("combo_short")
	_combo("short", coop)
	target.take_damage((SHORT_DAMAGE_COOP if coop else SHORT_DAMAGE_SOLO) * _power_of(source), source, Vector2.ZERO, "", true)


## Ein Blitz ohne Nässe springt manchmal auf den naechsten Gegner ueber (Funkenschlag).
func _spark_over(amount: float, source: Node) -> void:
	if randf() >= SPARK_CHANCE:
		return
	var best: Node2D = null
	var best_distance := SPARK_RADIUS
	for enemy in target.get_tree().get_nodes_in_group("enemies"):
		if enemy == target or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		var distance: float = enemy.global_position.distance_to(target.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	if best == null:
		return
	if Fx.instance:
		Fx.instance.zigzag(target.global_position, best.global_position, Elements.COLORS.lightning, 2.5, 0.14)
	Sfx.play("zap", 0.15)
	best.take_damage(maxf(1.0, amount * SPARK_DAMAGE), source, Vector2.ZERO, "", true)


func _steam(source: Node, coop: bool) -> void:
	var damage := (STEAM_DAMAGE_COOP if coop else STEAM_DAMAGE_SOLO) * _power_of(source)
	var radius := STEAM_RADIUS * (1.3 if coop else 1.0)
	if Fx.instance:
		Fx.instance.explosion(target.global_position, radius, Color(0.85, 0.9, 0.95))
	_combo("steam", coop)
	Sfx.play("steam")
	for enemy in target.get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(target.global_position) <= radius + 20.0:
			enemy.take_damage(damage, source, Vector2.ZERO, "", true)


func _arc_to_wet(damage: float, source: Node, max_arcs: int) -> void:
	var candidates: Array[Node2D] = []
	for enemy in target.get_tree().get_nodes_in_group("enemies"):
		if enemy == target or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.statuses.has("wet") and enemy.global_position.distance_to(target.global_position) <= ARC_RADIUS:
			candidates.append(enemy)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(target.global_position) < b.global_position.distance_squared_to(target.global_position))
	var from := target.global_position
	for i in mini(max_arcs, candidates.size()):
		var enemy := candidates[i]
		if Fx.instance:
			Fx.instance.zigzag(from, enemy.global_position, Elements.COLORS.lightning, 3.0, 0.18)
		enemy.take_damage(damage, source, Vector2.ZERO, "lightning", true)
		from = enemy.global_position
	Sfx.play("zap")
