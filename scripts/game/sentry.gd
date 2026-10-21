class_name Sentry
extends Deployable
## Geschuetzturm des Vendors (Dispenser): steht nach dem Wurf still und schiesst auf den naechsten
## Gegner in Sichtweite. Die Schuesse laufen ueber die Hauptszene, damit die Upgrades des Spielers gelten.

signal shot(sentry: Sentry, direction: Vector2)

var damage := 12.0
var reach := 700.0
var shots_per_second := 2.4

var _cooldown := 0.4
var _aim := Vector2.RIGHT
var _muzzle := 0.0


func _on_planted() -> void:
	_cooldown = 0.4


func _tick_planted(delta: float) -> void:
	_muzzle = maxf(0.0, _muzzle - delta * 8.0)
	_cooldown -= delta
	var target := _find_target()
	if target != null:
		_aim = (Targeting.point_of(target, muzzle_position()) - muzzle_position()).normalized()
		if _cooldown <= 0.0:
			_cooldown = 1.0 / shots_per_second
			_muzzle = 1.0
			shot.emit(self, _aim)


func muzzle_position() -> Vector2:
	return global_position + Vector2(0.0, -26.0) + _aim * 22.0


func _find_target() -> Node2D:
	var best: Node2D = null
	var best_distance := reach
	var origin := global_position + Vector2(0.0, -26.0)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var point := Targeting.point_of(enemy, origin)
		var distance: float = point.distance_to(origin)
		if distance >= best_distance:
			continue
		var query := PhysicsRayQueryParameters2D.create(origin, point, 1 << 0)
		if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			best_distance = distance
			best = enemy
	return best


func _draw() -> void:
	# Kleiner Automat auf Standfuessen mit leuchtendem Fach und einem Rohr, das dem Ziel folgt.
	var body := Rect2(Vector2(-15.0, -36.0), Vector2(30.0, 34.0))
	draw_rect(body, Color(0.2, 0.34, 0.26))
	draw_rect(body, Color(0.7, 0.9, 0.78), false, 2.0)
	draw_rect(Rect2(Vector2(-10.0, -31.0), Vector2(14.0, 18.0)), Color(color, 0.55 + 0.25 * sin(age * 4.0)))
	for i in 3:
		draw_circle(Vector2(10.0, -30.0 + i * 7.0), 1.8, Color(1.0, 0.9, 0.5))
	draw_line(Vector2(-12.0, -2.0), Vector2(-17.0, 3.0), Color(0.5, 0.52, 0.6), 3.0)
	draw_line(Vector2(12.0, -2.0), Vector2(17.0, 3.0), Color(0.5, 0.52, 0.6), 3.0)
	var pivot := Vector2(0.0, -26.0)
	draw_line(pivot, pivot + _aim * (16.0 - 4.0 * _muzzle), Color(0.85, 0.9, 0.95), 5.0, true)
	draw_circle(pivot, 5.0, Color(0.3, 0.34, 0.4))
	if _muzzle > 0.0:
		draw_circle(pivot + _aim * 22.0, 6.0 * _muzzle, Color(1.0, 0.95, 0.7, _muzzle))
	# Restzeit als duenner Bogen um den Turm.
	if life < 4.0:
		draw_arc(Vector2(0.0, -18.0), 30.0, 0.0, TAU * clampf(life / 4.0, 0.0, 1.0), 24, Color(1.0, 0.6, 0.4, 0.7), 2.0, true)
