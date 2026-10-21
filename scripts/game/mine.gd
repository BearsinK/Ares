class_name Mine
extends Deployable
## Proxy Mine des Hexapods: bleibt am Boden liegen, wird nach kurzer Zeit scharf und explodiert,
## sobald ein Gegner in die Naehe kommt.

signal detonated(mine: Mine)

var damage := 70.0
var radius := 120.0
var trigger_radius := 95.0
var arm_time := 0.5

var _scan := 0.0


func is_armed() -> bool:
	return planted and age >= arm_time


func _tick_planted(delta: float) -> void:
	_scan -= delta
	if _scan <= 0.0 and is_armed():
		_scan = 0.08
		if _enemy_near():
			detonate()


func _enemy_near() -> bool:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var reach := trigger_radius + Targeting.slack_of(enemy)
		if Targeting.point_of(enemy, global_position).distance_to(global_position) <= reach:
			return true
	return false


func detonate() -> void:
	detonated.emit(self)
	queue_free()


func _draw() -> void:
	# Flache Kuppel mit Beinchen, LED blinkt gelb (nicht scharf) oder rot (scharf).
	draw_set_transform(Vector2.ZERO, _normal.angle() + PI / 2.0, Vector2(1.5, 1.5))
	for side in [-1.0, 1.0]:
		draw_line(Vector2(side * 6.0, -2.0), Vector2(side * 15.0, 2.0), Color(0.45, 0.47, 0.55), 2.0, true)
	var dome := PackedVector2Array()
	for i in 9:
		var a := PI + PI * i / 8.0
		dome.append(Vector2(cos(a) * 12.0, sin(a) * 8.0))
	draw_colored_polygon(dome, Color(0.2, 0.22, 0.3))
	draw_polyline(dome, Color(0.7, 0.72, 0.8), 1.5, true)
	var armed := is_armed()
	var blink := 0.5 + 0.5 * sin(age * (14.0 if armed else 6.0))
	var led := Color(1.0, 0.25, 0.2) if armed else Color(1.0, 0.85, 0.3)
	draw_circle(Vector2(0.0, -6.0), 2.6, Color(led, 0.35 + 0.65 * blink))
	draw_set_transform(Vector2.ZERO)
	if armed:
		draw_arc(Vector2.ZERO, trigger_radius, 0.0, TAU, 36, Color(led, 0.07 + 0.05 * blink), 2.0, true)
