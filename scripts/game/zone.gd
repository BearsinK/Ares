class_name Zone
extends Node2D
## Wolke am Boden (Toner Bomb): verletzt Gegner darin ueber Zeit und haelt sie mit einem Zustand
## (Tinte) langsam. Waechst beim Entstehen und verblasst am Ende.

var owner_player: Node = null
var radius := 115.0
var life := 4.5
var dps := 9.0
var status := "inked"
var color := Color(0.12, 0.08, 0.2)
var element := ""

var _age := 0.0
var _tick := 0.2
var _blobs: Array[Dictionary] = []


func _ready() -> void:
	for i in 9:
		_blobs.append({"angle": randf() * TAU, "dist": randf_range(0.0, 0.8), "size": randf_range(0.3, 0.6), "speed": randf_range(-0.5, 0.5)})


func grow() -> float:
	return clampf(_age / 0.25, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	_age += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.4
		var reach := radius * grow()
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy):
				continue
			var body := float(enemy.radius()) if enemy.has_method("radius") else 40.0
			if enemy.global_position.distance_to(global_position) > reach + body:
				continue
			enemy.take_damage(dps * 0.4, owner_player, Vector2.ZERO, element, true)
			if status != "" and enemy.has_method("apply_status"):
				enemy.apply_status(status, 1.2, owner_player)
	queue_redraw()


func _draw() -> void:
	var fade := clampf(life / 1.0, 0.0, 1.0)
	var r := radius * grow()
	draw_circle(Vector2.ZERO, r, Color(color, 0.22 * fade))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(color.lightened(0.35), 0.5 * fade), 2.0, true)
	for blob in _blobs:
		var a: float = float(blob.angle) + _age * float(blob.speed)
		var d: float = float(blob.dist) * r * 0.8
		draw_circle(Vector2(cos(a), sin(a) * 0.7) * d, float(blob.size) * r * (0.7 + 0.15 * sin(_age * 2.0 + a)), Color(color, 0.3 * fade))
