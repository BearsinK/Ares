class_name Projectile
extends Area2D
## Spielergeschoss. Trifft Welt (Ebene 1) und Gegner (Ebene 3). Meldet jeden
## Treffer ueber das Signal hit, damit die Hauptszene Effekte und Explosionen
## erzeugen kann.

signal hit(projectile: Projectile, position: Vector2, target: Node)

var direction := Vector2.RIGHT
var speed := 900.0
var damage := 10.0
var lifetime := 1.2
var pierce := 0
var size := 5.0
var color := Color.WHITE
var shooter: Node = null
var explosion_radius := 0.0
var explosion_damage := 0.0
var element := ""

var _hit_targets: Array[Node] = []


func _ready() -> void:
	collision_layer = 1 << 3
	collision_mask = (1 << 0) | (1 << 2)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = size
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	var streak := clampf(speed * 0.02, 6.0, 40.0)
	draw_line(-direction * streak, Vector2.ZERO, Color(color, 0.5), size * 1.2)
	draw_circle(Vector2.ZERO, size, color)
	draw_circle(Vector2.ZERO, size * 1.8, Color(color, 0.25))


func _on_body_entered(_body: Node2D) -> void:
	hit.emit(self, global_position, null)
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not area.has_method("take_damage") or area in _hit_targets:
		return
	_hit_targets.append(area)
	area.take_damage(damage, shooter, direction, element)
	hit.emit(self, global_position, area)
	if pierce <= 0:
		queue_free()
	else:
		pierce -= 1
