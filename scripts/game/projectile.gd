class_name Projectile
extends Area2D
## Einfaches Spielerprojektil. Trifft Welt (Ebene 1) und Gegner (Ebene 3).

var direction := Vector2.RIGHT
var speed := 900.0
var damage := 10.0
var shooter: Node = null
var color := Color.WHITE

var _lifetime := 1.2


func _ready() -> void:
	collision_layer = 1 << 3
	collision_mask = (1 << 0) | (1 << 2)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, color)
	draw_circle(Vector2.ZERO, 9.0, Color(color, 0.25))


func _on_body_entered(_body: Node2D) -> void:
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage, shooter)
		queue_free()
