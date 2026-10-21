class_name Minion
extends Node2D
## Diener des Printbots (Werte in Minions.DATA). Er greift selbststaendig an, hat Leben und eine Lebensdauer und stirbt, wenn
## Gegner ihn treffen oder die Zeit ablaeuft. Gegner greifen nahe Diener bevorzugt an (siehe Enemy._pick_target).
## Zwei Arten: "gunner" schwebt beim Besitzer und beschiesst den naechsten Gegner, "biter" fliegt in Gegner hinein und beisst.

## Alle lebenden Diener, damit Gegner und Geschosse sie ohne Gruppensuche finden.
static var active: Array[Minion] = []

var kind := "printling"
var data: Dictionary = {}
var owner_player: Player
var slot := 0
var hp := 30.0
var max_hp := 30.0
var life := 20.0
## Schaden je Schuss oder Biss (vom Besitzer vorberechnet, mit seinen Upgrades).
var damage := 4.0
var velocity := Vector2.ZERO
var age := 0.0

var _shot_timer := 0.3
var _aim := Vector2.RIGHT
var _recoil := 0.0
var _flash := 0.0
var _iframes := 0.0
var _target: Node2D = null
var _target_timer := 0.0
var _dead := false
var _lunge := 0.0
var _bite_timer := 0.0


## Kollisionsradius gegen Gegnerangriffe.
func radius() -> float:
	return float(data.radius)


func is_dead() -> bool:
	return _dead


## Lebende Diener einer Art von einem Besitzer.
static func count_of(player: Player, minion_kind: String) -> int:
	var count := 0
	for minion in active:
		if minion.owner_player == player and minion.kind == minion_kind and not minion._dead:
			count += 1
	return count


## Aeltester lebender Diener einer Art von einem Besitzer, oder null.
static func oldest_of(player: Player, minion_kind: String) -> Minion:
	var best: Minion = null
	for minion in active:
		if minion.owner_player == player and minion.kind == minion_kind and not minion._dead:
			if best == null or minion.age > best.age:
				best = minion
	return best


func setup(new_kind: String, player: Player, new_damage: float, new_life := -1.0) -> void:
	kind = new_kind
	data = Minions.DATA[kind]
	owner_player = player
	max_hp = float(data.hp)
	hp = max_hp
	life = new_life if new_life > 0.0 else float(data.life)
	damage = new_damage
	_shot_timer = randf_range(0.2, 0.6)


func _enter_tree() -> void:
	active.append(self)


func _exit_tree() -> void:
	active.erase(self)


func _ready() -> void:
	z_index = 3
	add_to_group("minions")


func _physics_process(delta: float) -> void:
	if _dead:
		return
	age += delta
	if not is_instance_valid(owner_player):
		_expire()
		return
	life -= delta
	if life <= 0.0:
		_expire()
		return
	_iframes = maxf(0.0, _iframes - delta)
	_flash = maxf(0.0, _flash - delta * 6.0)
	_recoil = maxf(0.0, _recoil - delta * 8.0)
	_lunge = maxf(0.0, _lunge - delta * 5.0)
	_bite_timer = maxf(0.0, _bite_timer - delta)
	_target_timer -= delta
	if _target_timer <= 0.0:
		_target_timer = 0.15 + randf() * 0.05
		_target = _find_target()
	var before := global_position
	if String(data.style) == "gunner":
		_update_gunner(delta)
	else:
		_update_biter(delta)
	velocity = (global_position - before) / maxf(delta, 0.0001)
	queue_redraw()


# ---------------------------------------------------------------- Verhalten

func _update_gunner(delta: float) -> void:
	var goal := _orbit_goal()
	global_position = global_position.lerp(goal, 1.0 - exp(-8.0 * delta))
	if _target != null:
		_aim = _aim.lerp((Targeting.point_of(_target, global_position) - global_position).normalized(), 1.0 - exp(-16.0 * delta)).normalized()
		_shot_timer -= delta
		if _shot_timer <= 0.0 and not owner_player.downed:
			_shot_timer = float(data.interval)
			_shoot()
	else:
		_aim = _aim.lerp(owner_player.aim_dir, 1.0 - exp(-6.0 * delta)).normalized()


func _update_biter(delta: float) -> void:
	var speed := float(data.speed)
	var desired := Vector2.ZERO
	if _target != null and is_instance_valid(_target):
		var point := Targeting.point_of(_target, global_position)
		var to_target := point - global_position
		var gap := to_target.length()
		_aim = to_target.normalized() if gap > 1.0 else _aim
		# Leicht schlaengelnd anfliegen, damit ein Schwarm nicht als Linie ankommt.
		var weave := _aim.orthogonal() * sin(age * 9.0 + float(slot) * 1.7) * 0.35
		desired = (_aim + weave).normalized() * speed
		if gap <= radius() + Targeting.slack_of(_target) + 6.0:
			_bite()
			desired = -_aim * speed * 0.6
	else:
		var goal := _orbit_goal()
		desired = (goal - global_position) * 4.0
		desired = desired.limit_length(speed * 0.7)
	velocity = velocity.move_toward(desired, 2600.0 * delta)
	global_position += velocity.limit_length(speed * 1.2) * delta
	# Nicht ineinander kleben.
	for other in active:
		if other != self and not other._dead and String(other.data.style) == "biter":
			var apart := global_position - other.global_position
			var gap := apart.length()
			if gap < 14.0 and gap > 0.01:
				global_position += apart / gap * (14.0 - gap) * 0.5


## Bahn um den Besitzer: ein Platz je Diener, die Drohnen kreisen versetzt.
func _orbit_goal() -> Vector2:
	var base := owner_player.global_position
	var orbit := float(data.get("orbit", 70.0))
	var angle := age * 1.6 + float(slot) * TAU / 3.0
	var goal := base + Vector2(cos(angle) * orbit, -30.0 + sin(angle * 1.5) * 16.0)
	if owner_player.downed:
		goal = base + Vector2(cos(angle) * orbit * 0.5, -30.0)
	return _clamp_to_world(base, goal)


## Haelt Diener vor Waenden und Decken: sie bleiben vor dem ersten Treffer des Strahls.
func _clamp_to_world(from: Vector2, goal: Vector2) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(from + Vector2(0.0, -20.0), goal, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return goal
	return hit.position + hit.normal * 14.0


func _find_target() -> Node2D:
	var best: Node2D = null
	var best_distance := float(data.range)
	var anchor := owner_player.global_position
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_queued_for_deletion() or (enemy is Boss and enemy.dying):
			continue
		var point := Targeting.point_of(enemy, global_position)
		var distance := global_position.distance_to(point)
		if distance >= best_distance:
			continue
		# Beisser bleiben in der Naehe ihres Besitzers, sonst verlieren sie sich quer durch die Karte.
		if String(data.style) == "biter" and anchor.distance_to(point) > 900.0:
			continue
		if not _sees(point):
			continue
		best_distance = distance
		best = enemy
	return best


func _sees(point: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, point, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _shoot() -> void:
	var main := owner_player.get_parent()
	if main.has_method("spawn_drone_shot"):
		main.spawn_drone_shot(owner_player, global_position + _aim * 12.0 * float(data.scale), _aim, damage)
		Sfx.play("drone", 0.25)
		_recoil = 1.0


func _bite() -> void:
	if _bite_timer > 0.0 or not is_instance_valid(_target):
		return
	_bite_timer = float(data.interval)
	_lunge = 1.0
	var from := global_position
	var element := owner_player.current_module()
	var push := _aim * 1.2
	if _target.has_method("take_damage"):
		_target.take_damage(damage, owner_player, push, element)
	if Fx.instance:
		Fx.instance.spark(from + _aim * 8.0, Color(1.0, 0.9, 0.4), 3, 140.0)
	Sfx.play("hit", 0.35)


# ---------------------------------------------------------------- Schaden und Tod

## Treffer durch einen Gegner. Gibt true zurueck, wenn er gezaehlt hat (kurze Schonzeit danach).
func take_hit(amount: float, from: Vector2) -> bool:
	if _dead or _iframes > 0.0:
		return false
	hp -= amount
	_iframes = 0.2
	_flash = 1.0
	velocity += (global_position - from).normalized() * 160.0
	if Fx.instance:
		Fx.instance.spark(global_position, Color(1.0, 0.6, 0.3), 3, 160.0)
	if hp <= 0.0:
		_destroy()
	return true


## Zerstoert: Funken und Teile.
func _destroy() -> void:
	_dead = true
	if Fx.instance:
		Fx.instance.explosion(global_position, 26.0 * float(data.scale), Color(1.0, 0.6, 0.25))
		Fx.instance.gib(global_position, Color(0.5, 0.52, 0.62), "plate", 4.0 * float(data.scale), 220.0)
	Sfx.play("pop", 0.15)
	queue_free()


## Zeit abgelaufen: leises Verglimmen.
func _expire() -> void:
	_dead = true
	if Fx.instance:
		Fx.instance.spark(global_position, _tint(), 6, 120.0)
	queue_free()


# ---------------------------------------------------------------- Zeichnen

func _tint() -> Color:
	var element := owner_player.current_module() if is_instance_valid(owner_player) else ""
	if element != "":
		return Elements.COLORS[element]
	match kind:
		"printling":
			return RobotClasses.PLAYER_COLORS[owner_player.player_index - 1] if is_instance_valid(owner_player) else Color(0.4, 0.7, 1.0)
		"gnat":
			return Color(1.0, 0.85, 0.3)
	return Color(1.0, 0.55, 0.2)


func _draw() -> void:
	var fade := 1.0
	if life < 2.0:
		# Blinkt in den letzten Sekunden.
		fade = 0.55 + 0.45 * sin(age * 22.0)
	modulate = Color(1, 1, 1, fade).lerp(Color(2.2, 2.2, 2.2, fade), _flash)
	var scale_factor := float(data.scale)
	var grow := 1.0 - pow(1.0 - clampf(age / 0.25, 0.0, 1.0), 3.0)
	var tilt := clampf(velocity.x / 420.0, -0.35, 0.35)
	var bob := sin(age * 7.0 + float(slot)) * 1.6
	var tint := _tint()
	draw_set_transform(Vector2(0.0, bob), tilt, Vector2.ONE * grow * scale_factor)
	if String(data.style) == "biter":
		_draw_biter(tint)
	else:
		_draw_gunner(tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Lebensleiste, sobald er angeschlagen ist.
	if hp < max_hp:
		var width := 26.0 * maxf(scale_factor, 0.8)
		var top := -20.0 * scale_factor - 8.0
		draw_rect(Rect2(Vector2(-width * 0.5, top), Vector2(width, 3.5)), Color(0, 0, 0, 0.65))
		draw_rect(Rect2(Vector2(-width * 0.5, top), Vector2(width * clampf(hp / max_hp, 0.0, 1.0), 3.5)), Color(0.5, 1.0, 0.55).lerp(Color(1.0, 0.4, 0.3), 1.0 - hp / max_hp))


func _draw_gunner(tint: Color) -> void:
	var steel := Color(0.34, 0.36, 0.45)
	var dark := Color(0.14, 0.15, 0.2)
	# Auslegerarme und Rotoren.
	for side in [-1.0, 1.0]:
		var mount := Vector2(side * 15.0, -4.0)
		Art.bar(self, Vector2(side * 5.0, 0.0), mount, 2.4, steel)
		draw_line(mount, mount + Vector2(0.0, -3.0), Art.OUTLINE, 2.0)
		var rotor := mount + Vector2(0.0, -4.0)
		Art.ellipse(self, rotor, 10.0, 2.2, Color(0.85, 0.9, 1.0, 0.18))
		var width := 3.0 + 7.0 * absf(cos(age * 38.0 + side * 1.7))
		draw_line(rotor - Vector2(width, 0.0), rotor + Vector2(width, 0.0), Color(0.92, 0.95, 1.0, 0.85), 1.8, true)
		draw_circle(rotor, 1.4, Art.OUTLINE)
	# Kufen und Rumpf mit farbiger Kuppel.
	for side in [-1.0, 1.0]:
		draw_line(Vector2(side * 6.0, 5.0), Vector2(side * 8.5, 9.0), Art.OUTLINE, 2.2, true)
		draw_line(Vector2(side * 8.5, 9.0), Vector2(side * 4.0, 9.0), Art.OUTLINE, 2.2, true)
	Art.panel(self, Rect2(Vector2(-9.0, -3.5), Vector2(18.0, 9.0)), steel, 4.0)
	Art.rrect(self, Rect2(Vector2(-6.0, -6.5), Vector2(12.0, 4.5)), tint, 3.0)
	Art.rrect_line(self, Rect2(Vector2(-6.0, -6.5), Vector2(12.0, 4.5)), Art.OUTLINE, 3.0, 1.2)
	draw_line(Vector2(-7.0, 3.5), Vector2(7.0, 3.5), tint.darkened(0.15), 1.4, true)
	# Kameralinse in Zielrichtung, dahinter ein Lauf, der beim Schuss zurueckfedert.
	var lens := Vector2(_aim.x * 4.0, 1.0 + _aim.y * 2.5)
	draw_circle(lens, 3.2, dark)
	draw_circle(lens, 1.9, Color(1.0, 0.75, 0.4) if _recoil > 0.2 else Color(0.4, 0.85, 1.0))
	draw_circle(lens + Vector2(-0.6, -0.7), 0.7, Color(1, 1, 1, 0.8))
	var barrel_len := 12.0 - 3.5 * _recoil
	Art.bar(self, _aim * 4.0 + Vector2(0.0, 1.5), _aim * barrel_len + Vector2(0.0, 1.5), 3.0, dark, true)
	if _recoil > 0.5:
		Art.glow(self, _aim * (barrel_len + 3.0) + Vector2(0.0, 1.5), 6.0 + 4.0 * _recoil, tint)
	Art.led(self, Vector2(-7.0 * (1.0 if _aim.x < 0.0 else -1.0), -1.0), 1.1, Color(1.0, 0.3, 0.25), fmod(age, 1.0) < 0.5)
	Art.ellipse(self, Vector2(0.0, 11.0), 5.0, 1.4, Color(tint, 0.25))


func _draw_biter(tint: Color) -> void:
	var dark := Color(0.14, 0.15, 0.2)
	var lunge := _lunge
	var nose := _aim * (9.0 + 5.0 * lunge)
	# Schwirrende Fluegel.
	for side in [-1.0, 1.0]:
		var wing := Vector2(side * 9.0, -5.0)
		var flap := 0.6 + 0.4 * absf(cos(age * 46.0 + side))
		Art.ellipse(self, wing, 9.0 * flap, 3.0, Color(0.9, 0.95, 1.0, 0.4))
	# Rumpf: gedruckter Koerper mit Stachel in Flugrichtung.
	Art.disc(self, Vector2.ZERO, 8.0, Color(0.95, 0.6, 0.15))
	Art.disc(self, Vector2(-2.0, -1.0), 5.0, tint)
	draw_line(_aim * 5.0, nose, dark, 3.0, true)
	draw_line(_aim * 7.0, nose, Color(1.0, 0.9, 0.5), 1.4, true)
	draw_circle(_aim * 3.5 + Vector2(0.0, -2.0), 2.4, Art.OUTLINE)
	draw_circle(_aim * 3.5 + Vector2(0.0, -2.0), 1.3, Color(1.0, 0.3, 0.2))
