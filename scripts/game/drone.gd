class_name Drone
extends Node2D
## Drohne des Druckers. Zwei Begleitdrohnen schweben dauerhaft beim Besitzer und feuern
## dessen Waffe (der Drucker selbst hat keine). Gedruckte Zusatzdrohnen der Fähigkeit
## kreisen weiter außen und beschießen selbstständig den nächsten Gegner.

const ORBIT_RADIUS := 80.0
const SHOT_INTERVAL := 0.55
const RANGE := 700.0

var owner_player: Player
var slot := 0
var life := 8.0
## Begleitdrohne: lebt, solange der Besitzer lebt, und schießt nur auf Befehl.
var escort := false

var _age := 0.0
var _shot_timer := 0.3
var _aim := Vector2.RIGHT
var _velocity := Vector2.ZERO
var _recoil := 0.0


func _ready() -> void:
	z_index = 3
	add_to_group("escorts" if escort else "drones")


func _physics_process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(owner_player):
		queue_free()
		return
	if not escort:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
	var goal := _goal()
	var before := global_position
	global_position = global_position.lerp(goal, 1.0 - exp(-(10.0 if escort else 8.0) * delta))
	_velocity = (global_position - before) / maxf(delta, 0.0001)
	_recoil = maxf(0.0, _recoil - delta * 8.0)
	if escort:
		_aim = _aim.lerp(owner_player.aim_dir, 1.0 - exp(-18.0 * delta)).normalized()
	else:
		_shot_timer -= delta
		var target := _nearest_enemy()
		if target != null:
			_aim = (target.global_position - global_position).normalized()
			if _shot_timer <= 0.0 and not owner_player.downed:
				_shot_timer = SHOT_INTERVAL
				_shoot()
	queue_redraw()


func _goal() -> Vector2:
	var base := owner_player.global_position
	if escort:
		if owner_player.downed:
			return base + Vector2((-1.0 if slot == 0 else 1.0) * 42.0, 12.0)
		var side := -1.0 if slot == 0 else 1.0
		var sway := Vector2(0.0, sin(_age * 2.4 + slot * 2.0) * 4.0)
		return _clamp_to_world(base, base + Vector2(side * 50.0, -56.0) + sway)
	var angle := _age * 1.8 + slot * PI
	return base + Vector2(cos(angle) * ORBIT_RADIUS, -50.0 + sin(angle * 1.5) * 24.0)


## Haelt die Begleitdrohne vor Waenden und Decken: sie bleibt vor dem ersten Treffer des Strahls.
func _clamp_to_world(from: Vector2, goal: Vector2) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(from + Vector2(0.0, -20.0), goal, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return goal
	return hit.position + hit.normal * 14.0


## Begleitdrohne feuert: Rückstoß für die Optik.
func kick() -> void:
	_recoil = 1.0


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_distance := RANGE
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var distance := global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


func _shoot() -> void:
	var main := owner_player.get_parent()
	if main.has_method("spawn_drone_shot"):
		main.spawn_drone_shot(owner_player, global_position + _aim * 12.0, _aim)
		Sfx.play("drone", 0.25)
		_recoil = 1.0


func _tint() -> Color:
	if escort:
		return RobotClasses.PLAYER_COLORS[owner_player.player_index - 1] if is_instance_valid(owner_player) else Color(0.4, 0.7, 1.0)
	var element := owner_player.current_module() if is_instance_valid(owner_player) else ""
	if element != "":
		return Elements.COLORS[element]
	return Color(0.95, 0.55, 0.2)


func _weapon_color() -> Color:
	if not is_instance_valid(owner_player):
		return Color.WHITE
	var base: Color = Weapons.get_weapon(owner_player.current_weapon_id()).color
	return Elements.color_of(owner_player.current_module(), base)


func _draw() -> void:
	var fade := 1.0 if escort else clampf(life / 0.5, 0.0, 1.0)
	if not escort and life < 2.0:
		# Blinkt in den letzten Sekunden.
		fade *= 0.55 + 0.45 * sin(_age * 22.0)
	if escort and is_instance_valid(owner_player) and owner_player.downed:
		fade = 0.5
	modulate.a = fade
	var grow := 1.0 - pow(1.0 - clampf(_age / 0.25, 0.0, 1.0), 3.0)
	var powered := not (escort and is_instance_valid(owner_player) and owner_player.downed)
	var tilt := clampf(_velocity.x / 420.0, -0.35, 0.35) if powered else 0.0
	var bob := sin(_age * 7.0 + slot) * 1.6 if powered else 0.0
	var tint := _tint()
	var weapon_color := _weapon_color()
	draw_set_transform(Vector2(0.0, bob), tilt, Vector2.ONE * grow)
	var steel := Color(0.34, 0.36, 0.45)
	var dark := Color(0.14, 0.15, 0.2)

	# Auslegerarme und Rotoren: Blätter als schnell wechselnde Breite, dazu ein Schleier.
	for side in [-1.0, 1.0]:
		var mount := Vector2(side * 15.0, -4.0)
		Art.bar(self, Vector2(side * 5.0, 0.0), mount, 2.4, steel)
		draw_line(mount, mount + Vector2(0.0, -3.0), Art.OUTLINE, 2.0)
		var rotor := mount + Vector2(0.0, -4.0)
		if powered:
			Art.ellipse(self, rotor, 10.0, 2.2, Color(0.85, 0.9, 1.0, 0.18))
			var width := 3.0 + 7.0 * absf(cos(_age * 38.0 + side * 1.7))
			draw_line(rotor - Vector2(width, 0.0), rotor + Vector2(width, 0.0), Color(0.92, 0.95, 1.0, 0.85), 1.8, true)
		else:
			draw_line(rotor - Vector2(8.0, -1.0), rotor + Vector2(8.0, 1.0), Color(0.6, 0.62, 0.7), 1.8, true)
		draw_circle(rotor, 1.4, Art.OUTLINE)

	# Kufen und Rumpf: dunkles Gehäuse mit farbiger Kuppel und Seitenstreifen.
	for side in [-1.0, 1.0]:
		draw_line(Vector2(side * 6.0, 5.0), Vector2(side * 8.5, 9.0), Art.OUTLINE, 2.2, true)
		draw_line(Vector2(side * 8.5, 9.0), Vector2(side * 4.0, 9.0), Art.OUTLINE, 2.2, true)
	var hull := Rect2(Vector2(-9.0, -3.5), Vector2(18.0, 9.0))
	Art.panel(self, hull, steel, 4.0)
	Art.rrect(self, Rect2(Vector2(-6.0, -6.5), Vector2(12.0, 4.5)), tint, 3.0)
	Art.rrect_line(self, Rect2(Vector2(-6.0, -6.5), Vector2(12.0, 4.5)), Art.OUTLINE, 3.0, 1.2)
	draw_line(Vector2(-7.0, 3.5), Vector2(7.0, 3.5), tint.darkened(0.15), 1.4, true)

	# Kameralinse in Zielrichtung, dahinter ein Lauf, der beim Schuss zurückfedert.
	var lens := Vector2(_aim.x * 4.0, 1.0 + _aim.y * 2.5)
	draw_circle(lens, 3.2, dark)
	draw_circle(lens, 1.9, weapon_color if (powered and _recoil > 0.2) else Color(0.4, 0.85, 1.0) if powered else Color(0.25, 0.25, 0.3))
	draw_circle(lens + Vector2(-0.6, -0.7), 0.7, Color(1, 1, 1, 0.8))
	var barrel_len := 12.0 - 3.5 * _recoil
	Art.bar(self, _aim * 4.0 + Vector2(0.0, 1.5), _aim * barrel_len + Vector2(0.0, 1.5), 3.0, dark, true)
	if _recoil > 0.5:
		Art.glow(self, _aim * (barrel_len + 3.0) + Vector2(0.0, 1.5), 6.0 + 4.0 * _recoil, weapon_color)
	# Heckleuchte und Schubdüsenschimmer.
	if powered:
		Art.led(self, Vector2(-7.0 * (1.0 if _aim.x < 0.0 else -1.0), -1.0), 1.1, Color(1.0, 0.3, 0.25), fmod(_age, 1.0) < 0.5)
		Art.ellipse(self, Vector2(0.0, 11.0), 5.0, 1.4, Color(tint, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
