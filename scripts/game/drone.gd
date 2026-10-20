class_name Drone
extends Node2D
## Gedruckte Drohne des Druckers: schwebt um ihren Besitzer und beschiesst
## selbststaendig den naechsten Gegner mit kleinen Explosivgeschossen.

const ORBIT_RADIUS := 80.0
const SHOT_INTERVAL := 0.55
const RANGE := 700.0

var owner_player: Player
var slot := 0
var life := 8.0

var _age := 0.0
var _shot_timer := 0.3
var _target_angle := 0.0
var _aim := Vector2.RIGHT
var _velocity := Vector2.ZERO
var _recoil := 0.0


func _ready() -> void:
	z_index = 3
	add_to_group("drones")


func _physics_process(delta: float) -> void:
	_age += delta
	life -= delta
	if life <= 0.0 or not is_instance_valid(owner_player):
		queue_free()
		return
	var angle := _age * 1.8 + slot * PI
	var goal := owner_player.global_position + Vector2(cos(angle) * ORBIT_RADIUS, -50.0 + sin(angle * 1.5) * 24.0)
	var before := global_position
	global_position = global_position.lerp(goal, 1.0 - exp(-8.0 * delta))
	_velocity = (global_position - before) / maxf(delta, 0.0001)
	_recoil = maxf(0.0, _recoil - delta * 8.0)
	_shot_timer -= delta
	var target := _nearest_enemy()
	if target != null:
		_aim = (target.global_position - global_position).normalized()
		if _shot_timer <= 0.0 and not owner_player.downed:
			_shot_timer = SHOT_INTERVAL
			_shoot()
	queue_redraw()


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


func _draw() -> void:
	# Blinkt in den letzten Sekunden und ploppt beim Start auf.
	var fade := clampf(life / 0.5, 0.0, 1.0)
	if life < 2.0:
		fade *= 0.55 + 0.45 * sin(_age * 22.0)
	modulate.a = fade
	var pop := clampf(_age / 0.25, 0.0, 1.0)
	var grow := 1.0 - pow(1.0 - pop, 3.0)
	var tilt := clampf(_velocity.x / 400.0, -0.35, 0.35)
	var bob := sin(_age * 7.0 + slot) * 2.0
	var tint := _tint()
	Art.shadow(self, Vector2(0.0, 22.0), 12.0 * grow, 3.0, 0.2)
	draw_set_transform(Vector2(0.0, bob), tilt, Vector2.ONE * grow)
	# Rotoren: schnell wechselnde Blattbreite statt Standbild.
	for side in [-1.0, 1.0]:
		var rotor := Vector2(side * 13.0, -7.0)
		var width := 4.0 + 6.0 * absf(cos(_age * 40.0 + side))
		Art.ellipse(self, rotor, width, 2.4, Color(0.8, 0.85, 0.95, 0.5))
		draw_line(Vector2(side * 6.0, -1.0), rotor, Art.OUTLINE, 2.0)
		draw_circle(rotor, 1.6, Art.OUTLINE)
	# Rumpf in Druckerorange (oder Modulfarbe) mit Auge.
	var body := Rect2(Vector2(-9.0, -5.0), Vector2(18.0, 12.0))
	Art.rrect_grad(self, body, tint.lightened(0.15), tint.darkened(0.2), 4.0)
	Art.rrect_line(self, body, Art.OUTLINE, 4.0, 1.5)
	draw_line(Vector2(-6.0, -3.5), Vector2(5.0, -3.5), Color(1, 1, 1, 0.35), 1.3, true)
	Art.led(self, Vector2(_aim.x * 3.0, 0.5 + _aim.y * 2.0), 2.6, Color(1.0, 0.95, 0.5))
	# Kleiner Lauf in Zielrichtung.
	draw_line(_aim * 7.0, _aim * (11.0 - 3.0 * _recoil), Art.OUTLINE, 3.2, true)
	Art.glow(self, Vector2.ZERO, 14.0, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _tint() -> Color:
	var element := owner_player.current_module() if is_instance_valid(owner_player) else ""
	if element != "":
		return Elements.COLORS[element]
	return Color(0.95, 0.55, 0.2)
