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
## Verfolgungsrakete: Lenkrate in rad/s (0 = ungelenkt), Beschleunigung bis speed_max, Wucht beim Treffer.
var homing := 0.0
var accel := 0.0
var speed_max := 0.0
var push := 1.0

var _hit_targets: Array[Node] = []
var _velocity := Vector2.ZERO
var _trail_timer := 0.0
var _target: Node2D = null
var _retarget_timer := 0.0
var _age := 0.0


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
	_age += delta
	if homing > 0.0:
		_steer(delta)
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
		if homing > 0.0 and not is_queued_for_deletion():
			# Eine Rakete, die ihr Ziel verfehlt, zuendet am Ende ihrer Flugzeit.
			hit.emit(self, global_position, null)
		queue_free()


## Lenkt auf den naechsten Gegner vor der Rakete und beschleunigt bis zur Hoechstgeschwindigkeit.
func _steer(delta: float) -> void:
	if accel > 0.0:
		var now := minf(_velocity.length() + accel * delta, speed_max if speed_max > 0.0 else speed)
		_velocity = _velocity.normalized() * now
	if _age < 0.12:
		return
	_retarget_timer -= delta
	var lost := _target == null or not is_instance_valid(_target) or _target.is_queued_for_deletion()
	if lost or _retarget_timer <= 0.0:
		_retarget_timer = 0.2
		# Verlorenes Ziel oder keine freie Sicht mehr: naechsten sichtbaren Gegner vor der Rakete suchen.
		if lost or not _has_line_of_sight(_target):
			_target = _find_target()
	if _target != null:
		var wanted := (_target.global_position - global_position).angle()
		var diff := angle_difference(_velocity.angle(), wanted)
		_velocity = _velocity.rotated(clampf(diff, -homing * delta, homing * delta))
	direction = _velocity.normalized()
	queue_redraw()
	_trail_timer -= delta
	if _trail_timer <= 0.0 and Fx.instance:
		_trail_timer = 0.025
		Fx.instance.spark(global_position - direction * 10.0, Color(1.0, 0.7, 0.3, 0.8), 1, 70.0)


## Naechster Gegner einigermassen in Flugrichtung (sonst dreht die Rakete Kreise), ohne Wand dazwischen.
func _find_target() -> Node2D:
	var best := 1100.0
	var result: Node2D = null
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector2 = enemy.global_position - global_position
		var distance := offset.length()
		if distance < best and offset.normalized().dot(_velocity.normalized()) > -0.15 and _has_line_of_sight(enemy):
			best = distance
			result = enemy
	return result


func _has_line_of_sight(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _draw() -> void:
	if homing > 0.0:
		_draw_rocket()
		return
	if arc_gravity > 0.0:
		_draw_can()
		return
	var streak := clampf(speed * 0.02, 6.0, 40.0)
	draw_line(-direction * streak, Vector2.ZERO, Color(color, 0.5), size * 1.2)
	draw_circle(Vector2.ZERO, size, color)
	draw_circle(Vector2.ZERO, size * 1.8, Color(color, 0.25))


func _draw_rocket() -> void:
	# Rakete: Rumpf mit Spitze, Leitwerk und Flamme, zeigt in Flugrichtung.
	draw_set_transform(Vector2.ZERO, _velocity.angle())
	var flame := 8.0 + 6.0 * absf(sin(_age * 40.0))
	draw_colored_polygon(PackedVector2Array([Vector2(-size * 1.4, -size * 0.45), Vector2(-size * 1.4 - flame, 0.0), Vector2(-size * 1.4, size * 0.45)]), Color(1.0, 0.7, 0.2, 0.9))
	draw_colored_polygon(PackedVector2Array([Vector2(-size * 1.4, -size * 0.25), Vector2(-size * 1.4 - flame * 0.6, 0.0), Vector2(-size * 1.4, size * 0.25)]), Color(1.0, 0.95, 0.7))
	draw_rect(Rect2(-size * 1.4, -size * 0.55, size * 2.2, size * 1.1), Color(0.75, 0.78, 0.85))
	draw_colored_polygon(PackedVector2Array([Vector2(size * 0.8, -size * 0.55), Vector2(size * 1.8, 0.0), Vector2(size * 0.8, size * 0.55)]), color)
	draw_colored_polygon(PackedVector2Array([Vector2(-size * 1.4, -size * 0.55), Vector2(-size * 1.9, -size * 1.1), Vector2(-size * 0.8, -size * 0.55)]), color.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(-size * 1.4, size * 0.55), Vector2(-size * 1.9, size * 1.1), Vector2(-size * 0.8, size * 0.55)]), color.darkened(0.2))
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2.ZERO, size * 2.2, Color(color, 0.2))


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
	area.take_damage(damage, shooter, direction * push, element)
	hit.emit(self, global_position, area)
	if pierce <= 0:
		queue_free()
	else:
		pierce -= 1
