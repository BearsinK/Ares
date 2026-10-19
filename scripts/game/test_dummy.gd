class_name TestDummy
extends Area2D
## Uebungspuppe zum Testen von Schuss und Schaden. Spaeter durch echte
## Gegner ersetzt.

var max_health := 500.0
var health := 500.0
var half_size := Vector2(25.0, 40.0)

var _flash := 0.0


func _ready() -> void:
	collision_layer = 1 << 2
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = half_size * 2.0
	shape.shape = rect
	add_child(shape)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()


func take_damage(amount: float, _source: Node) -> void:
	health -= amount
	_flash = 0.08
	_spawn_number(amount)
	if health <= 0.0:
		health = max_health
	queue_redraw()


func _spawn_number(amount: float) -> void:
	var label := Label.new()
	label.text = str(int(round(amount)))
	label.add_theme_color_override("font_color", Color(1, 1, 0.5))
	label.add_theme_font_size_override("font_size", 22)
	label.global_position = global_position + Vector2(randf_range(-20.0, 20.0), -half_size.y - 20.0)
	get_parent().add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40.0, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(label.queue_free)


func _draw() -> void:
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
