class_name EnemyProjectile
extends Area2D
## Geschoss eines Gegners. Trifft Spieler (Ebene 2) und Welt (Ebene 1).
## Wer gerade durch Iframes geschuetzt ist (z.B. im Dash), wird durchflogen.

var direction := Vector2.RIGHT
var speed := 500.0
var damage := 8.0
var lifetime := 3.0
var color := Color(1.0, 0.4, 0.5)


func _ready() -> void:
	collision_layer = 1 << 4
	collision_mask = (1 << 0) | (1 << 1)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
	elif get_overlapping_bodies().size() > 0:
		# Faengt Faelle ab, in denen ein Spieler nach den Iframes im Geschoss steht.
		for body in get_overlapping_bodies():
			_on_body_entered(body)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, color)
	draw_circle(Vector2.ZERO, 12.0, Color(color, 0.25))


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		if body.take_hit(damage, global_position):
			queue_free()
	else:
		queue_free()
