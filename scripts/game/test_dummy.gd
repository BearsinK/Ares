class_name TestDummy
extends Area2D
## Uebungspuppe zum Testen von Schuss und Schaden. Stirbt bei 0 Leben und
## meldet das ueber das Signal died, damit die Hauptszene sie ersetzen kann.
## Spaeter durch echte Gegner ersetzt.

signal died(spawn_position: Vector2)

var max_health := 500.0
var health := 500.0
var half_size := Vector2(25.0, 40.0)

var _flash := 0.0
var _dead := false
var _wobble := Vector2.ZERO
var _time := 0.0
var statuses: StatusEffects


func _ready() -> void:
	collision_layer = 1 << 2
	collision_mask = 0
	add_to_group("enemies")
	statuses = StatusEffects.new(self)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = half_size * 2.0
	shape.shape = rect
	add_child(shape)


func _process(delta: float) -> void:
	_time += delta
	statuses.update(delta)
	if _dead:
		return
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()
	if _wobble != Vector2.ZERO:
		_wobble = _wobble.move_toward(Vector2.ZERO, 160.0 * delta)
		queue_redraw()


func take_damage(amount: float, source: Node, direction := Vector2.ZERO, element := "", from_effect := false) -> void:
	if _dead:
		return
	if element != "" and not from_effect:
		amount = statuses.process_hit(element, source, amount)
	health -= amount
	_flash = 0.08
	_wobble = direction * 8.0
	_spawn_number(amount, element)
	Sfx.play("hit")
	if health <= 0.0:
		_die()
	queue_redraw()


func _die() -> void:
	_dead = true
	Sfx.play("kill")
	_spawn_burst()
	died.emit(position)
	queue_free()


func _spawn_burst() -> void:
	var burst := CPUParticles2D.new()
	burst.position = position
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 24
	burst.lifetime = 0.6
	burst.spread = 180.0
	burst.initial_velocity_min = 150.0
	burst.initial_velocity_max = 400.0
	burst.gravity = Vector2(0.0, 900.0)
	burst.scale_amount_min = 3.0
	burst.scale_amount_max = 6.0
	burst.color = Color(1.0, 0.4, 0.4)
	get_parent().add_child(burst)
	var timer := burst.get_tree().create_timer(1.0)
	timer.timeout.connect(burst.queue_free)


func _spawn_number(amount: float, element := "") -> void:
	if Fx.instance:
		Fx.instance.number(global_position + Vector2(0.0, -half_size.y - 10.0), amount, Elements.color_of(element, Color(1, 1, 0.5)))


func _draw() -> void:
	draw_set_transform(_wobble)
	statuses.draw_overlay(self, 30.0, _time)
	var color := Color(0.8, 0.3, 0.4)
	if _flash > 0.0:
		color = Color.WHITE
	var rect := Rect2(-half_size, half_size * 2.0)
	draw_rect(rect, color)
	# Boeses Gesicht der Fabrik-Roboter.
	draw_circle(Vector2(-10.0, -10.0), 5.0, Color(1.0, 0.2, 0.2))
	draw_circle(Vector2(10.0, -10.0), 5.0, Color(1.0, 0.2, 0.2))
	var bar_width := half_size.x * 2.0
	draw_rect(Rect2(Vector2(-half_size.x, -half_size.y - 10.0), Vector2(bar_width, 5.0)), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(Vector2(-half_size.x, -half_size.y - 10.0), Vector2(bar_width * health / max_health, 5.0)), Color(0.3, 0.9, 0.3))
