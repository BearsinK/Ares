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
## Bogenwurf: Schwerkraft in px/s^2. Dosen landen auch auf Plattformen.
var arc_gravity := 0.0
var collide_platforms := false
var shaken := false
var charge := 0.0

var _hit_targets: Array[Node] = []
var _velocity := Vector2.ZERO
var _trail_timer := 0.0


func _ready() -> void:
	collision_layer = 1 << 3
	collision_mask = (1 << 0) | (1 << 2) | ((1 << 5) if collide_platforms else 0)
	_velocity = direction * speed
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = size
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	_velocity.y += arc_gravity * delta
	position += _velocity * delta
	if arc_gravity > 0.0:
		direction = _velocity.normalized()
		queue_redraw()
		_trail_timer -= delta
		if shaken and _trail_timer <= 0.0 and Fx.instance:
			_trail_timer = 0.03
			Fx.instance.spark(global_position, Color(1.0, 1.0, 1.0), 1, 90.0)
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	if arc_gravity > 0.0:
		_draw_can()
		return
	var streak := clampf(speed * 0.02, 6.0, 40.0)
	draw_line(-direction * streak, Vector2.ZERO, Color(color, 0.5), size * 1.2)
	draw_circle(Vector2.ZERO, size, color)
	draw_circle(Vector2.ZERO, size * 1.8, Color(color, 0.25))


func _draw_can() -> void:
	# Dose: Koerper, Deckel und Boden, geschuettelte Dosen schaeumen.
	var body_color := color
	draw_set_transform(Vector2.ZERO, _velocity.angle() + PI / 2.0)
	draw_rect(Rect2(-size * 0.7, -size, size * 1.4, size * 2.0), body_color)
	draw_rect(Rect2(-size * 0.7, -size, size * 1.4, size * 2.0), Color(0.1, 0.3, 0.15), false, 2.0)
	draw_rect(Rect2(-size * 0.7, -size, size * 1.4, size * 0.4), Color(0.85, 0.85, 0.9))
	draw_set_transform(Vector2.ZERO)
	if shaken:
		draw_circle(Vector2.ZERO, size * (1.4 + 0.6 * charge), Color(1.0, 1.0, 1.0, 0.25))


func _on_body_entered(body: Node2D) -> void:
	if is_queued_for_deletion():
		return
	# Plattformen sind von unten durchlaessig, ein aufsteigender Wurf fliegt hindurch.
	if body is CollisionObject2D and (body.collision_layer & (1 << 5)) != 0 and _velocity.y <= 0.0:
		return
	hit.emit(self, global_position, null)
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if is_queued_for_deletion():
		return
	if not area.has_method("take_damage") or area in _hit_targets:
		return
	_hit_targets.append(area)
	area.take_damage(damage, shooter, direction, element)
	hit.emit(self, global_position, area)
	if pierce <= 0:
		queue_free()
	else:
		pierce -= 1
