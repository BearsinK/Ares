class_name Props
extends Node2D
## Kulissen der Fabrikhalle: Kisten, Faesser, Maschinen, Schilder, Foerderband,
## Dampfauslaesse, Schwebeteilchen und die Schachtmarkierung. Rein optisch.

const FLOOR_Y := 1250.0

var shaft := Rect2()
## Karten (Stages): Dekor und Dampfauslaesse kommen aus dem Layout statt der festen Liste der Halle.
var classic := true
var decor: Array[Dictionary] = []
var steam_points: Array[Vector2] = []
var ember_center := Vector2(1600.0, 700.0)
var ember_extents := Vector2(1700.0, 650.0)
## Im Bosskampf entfallen Kisten, Foerderbaender und Dampf (das Laufband ist dann Teil des Kampfs).
var boss_mode := false


class Animated extends Node2D:
	var props: Props
	var belts := false

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		if belts:
			_draw_belts(t)
		else:
			_draw_shaft(t)

	func _draw_belts(t: float) -> void:
		# Foerderbaender im Boden, Chevrons wandern.
		for belt in [Vector2(820, 1480), Vector2(1900, 2500)]:
			var rect := Rect2(belt.x, FLOOR_Y + 30.0, belt.y - belt.x, 22.0)
			Art.rrect(self, rect, Color(0.07, 0.07, 0.1), 8.0)
			var x := rect.position.x + fposmod(t * 40.0, 44.0)
			while x < rect.end.x - 14.0:
				var p := Vector2(x, rect.position.y + 4.0)
				draw_colored_polygon(PackedVector2Array([p, p + Vector2(10, 7), p + Vector2(0, 14), p + Vector2(4, 7)]), Color(0.95, 0.75, 0.12, 0.85))
				x += 44.0
			Art.rrect_line(self, rect, Color(0.45, 0.48, 0.58), 8.0, 2.0)
			for end in [rect.position.x + 6.0, rect.end.x - 6.0]:
				Art.disc(self, Vector2(end, rect.position.y + 11.0), 7.0, Color(0.3, 0.32, 0.4))
	func _draw_shaft(t: float) -> void:
		# Schacht: aufsteigende Pfeile und blinkende Warnlampen.
		if props.shaft.size != Vector2.ZERO:
			var s := props.shaft
			draw_rect(s, Color(0.04, 0.05, 0.08, 0.85))
			var y := s.end.y - fposmod(t * 70.0, 120.0)
			while y > s.position.y + 20.0:
				var cx := s.position.x + s.size.x * 0.5
				var alpha := clampf((y - s.position.y) / 250.0, 0.0, 1.0) * 0.55
				draw_polyline(PackedVector2Array([Vector2(cx - 22, y + 12), Vector2(cx, y - 8), Vector2(cx + 22, y + 12)]), Color(0.3, 0.9, 0.6, alpha), 6.0, true)
				y -= 120.0
			Art.led(self, Vector2(s.position.x + 14.0, s.position.y + 20.0), 5.0, Color(1.0, 0.3, 0.2), fmod(t, 1.0) < 0.5)
			Art.led(self, Vector2(s.end.x - 14.0, s.position.y + 20.0), 5.0, Color(1.0, 0.3, 0.2), fmod(t, 1.0) >= 0.5)


func _ready() -> void:
	z_index = -10
	if boss_mode:
		_add_embers()
		return
	if not classic:
		for point in steam_points:
			_add_steam(point)
		_add_embers()
		return
	var shaft_layer := Animated.new()
	shaft_layer.props = self
	shaft_layer.z_index = -9
	add_child(shaft_layer)
	var belt_layer := Animated.new()
	belt_layer.props = self
	belt_layer.belts = true
	belt_layer.z_as_relative = false
	belt_layer.z_index = 1
	add_child(belt_layer)
	_add_steam(Vector2(730.0, FLOOR_Y))
	_add_steam(Vector2(1700.0, FLOOR_Y))
	_add_steam(Vector2(2780.0, FLOOR_Y + 2.0))
	_add_embers()


## Weiche runde Textur fuer Partikel (sonst erscheinen sie als Quadrate).
static func soft_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


func _add_steam(pos: Vector2) -> void:
	var steam := CPUParticles2D.new()
	steam.position = pos
	steam.amount = 14
	steam.lifetime = 2.0
	steam.direction = Vector2(0, -1)
	steam.spread = 14.0
	steam.initial_velocity_min = 50.0
	steam.initial_velocity_max = 90.0
	steam.gravity = Vector2(0, -20)
	steam.scale_amount_min = 0.5
	steam.scale_amount_max = 1.1
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.9, 1.0, 0.0))
	ramp.add_point(0.2, Color(0.85, 0.9, 1.0, 0.28))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.85, 0.9, 1.0, 0.0))
	steam.color_ramp = ramp
	steam.texture = soft_texture()
	steam.z_index = -5
	add_child(steam)


func _add_embers() -> void:
	var embers := CPUParticles2D.new()
	embers.position = ember_center
	embers.amount = 70
	embers.lifetime = 9.0
	embers.preprocess = 9.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = ember_extents
	embers.direction = Vector2(0, -1)
	embers.spread = 40.0
	embers.initial_velocity_min = 6.0
	embers.initial_velocity_max = 22.0
	embers.gravity = Vector2(0, -2)
	embers.scale_amount_min = 0.03
	embers.scale_amount_max = 0.07
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.65, 0.3, 0.0))
	ramp.add_point(0.3, Color(1.0, 0.65, 0.3, 0.7))
	ramp.set_color(ramp.get_point_count() - 1, Color(1.0, 0.45, 0.2, 0.0))
	embers.color_ramp = ramp
	embers.texture = soft_texture()
	embers.z_index = 20
	add_child(embers)


func _draw() -> void:
	if boss_mode:
		return
	if not classic:
		for item in decor:
			match item.type:
				"crate":
					_crate(item.pos, float(item.size))
				"stack":
					_crate(item.pos, float(item.size))
					_crate(item.pos + Vector2(float(item.size), 0.0), float(item.size))
					_crate(item.pos + Vector2(float(item.size) * 0.5, -float(item.size)), float(item.size) * 0.85)
				"barrel":
					_barrel(item.pos)
					_barrel(item.pos + Vector2(42.0, 0.0))
				"machine":
					_machine(item.pos, item.size, item.color)
				"sign":
					_sign(item.pos, item.text)
		return
	# Kisten, Faesser und Maschinen am Boden (rein dekorativ, ohne Kollision).
	_machine(Vector2(560, FLOOR_Y), Vector2(90, 120), Color(0.26, 0.3, 0.42))
	_crate(Vector2(930, FLOOR_Y), 62.0)
	_crate(Vector2(992, FLOOR_Y), 62.0)
	_crate(Vector2(961, FLOOR_Y - 62.0), 54.0)
	_barrel(Vector2(1330, FLOOR_Y))
	_barrel(Vector2(1372, FLOOR_Y))
	_machine(Vector2(2140, FLOOR_Y), Vector2(110, 150), Color(0.4, 0.28, 0.24))
	_crate(Vector2(2520, FLOOR_Y), 70.0)
	_barrel(Vector2(2470, FLOOR_Y))
	_machine(Vector2(2960, FLOOR_Y), Vector2(100, 110), Color(0.26, 0.3, 0.42))
	_sign(Vector2(300, FLOOR_Y), "ZONE 02")
	_sign(Vector2(1880, FLOOR_Y), "ACHTUNG")
	_sign(Vector2(3050, FLOOR_Y), "SCHACHT")
	_pipe_run(Vector2(-60, FLOOR_Y - 8.0), 190.0)
	_pipe_run(Vector2(3080, FLOOR_Y - 8.0), 190.0)


func _crate(bottom: Vector2, size: float) -> void:
	var rect := Rect2(bottom - Vector2(size * 0.5, size), Vector2(size, size))
	Art.panel(self, rect, Color(0.55, 0.42, 0.25), 3.0)
	Art.rrect_line(self, rect.grow(-6.0), Color(0, 0, 0, 0.35), 2.0, 2.0)
	draw_line(rect.position + Vector2(6, 6), rect.end - Vector2(6, 6), Color(0, 0, 0, 0.3), 3.0)
	draw_line(rect.position + Vector2(size - 6, 6), rect.position + Vector2(6, size - 6), Color(0, 0, 0, 0.3), 3.0)
	for corner in [rect.position + Vector2(5, 5), rect.position + Vector2(size - 5, 5), rect.position + Vector2(5, size - 5), rect.end - Vector2(5, 5)]:
		Art.rivet(self, corner)


func _barrel(bottom: Vector2) -> void:
	var rect := Rect2(bottom - Vector2(18, 52), Vector2(36, 52))
	Art.panel(self, rect, Color(0.75, 0.22, 0.2), 8.0)
	for y in [10.0, 26.0, 42.0]:
		draw_line(rect.position + Vector2(1, y), rect.position + Vector2(35, y), Color(0, 0, 0, 0.4), 2.5)
	draw_colored_polygon(PackedVector2Array([rect.position + Vector2(9, 15), rect.position + Vector2(27, 15), rect.position + Vector2(18, 33)]), Color(0.95, 0.75, 0.12))
	draw_colored_polygon(PackedVector2Array([rect.position + Vector2(13, 20), rect.position + Vector2(23, 20), rect.position + Vector2(18, 29)]), Color(0.1, 0.1, 0.13))


func _machine(bottom: Vector2, size: Vector2, color: Color) -> void:
	var rect := Rect2(bottom - Vector2(size.x * 0.5, size.y), size)
	Art.panel(self, rect, color, 6.0)
	var screen := Rect2(rect.position + Vector2(10, 12), Vector2(size.x - 20.0, size.y * 0.3))
	Art.rrect(self, screen, Color(0.03, 0.12, 0.1), 3.0)
	for i in 4:
		draw_line(screen.position + Vector2(5, 7 + i * 6.0), screen.position + Vector2(5.0 + fposmod(10.0 + i * 11.0, screen.size.x - 10.0), 7 + i * 6.0), Color(0.3, 0.95, 0.6, 0.8), 2.0)
	Art.rrect_line(self, screen, Color(0.6, 0.65, 0.75), 3.0, 1.5)
	for i in 5:
		draw_line(rect.position + Vector2(12, size.y * 0.55 + i * 8.0), rect.position + Vector2(size.x - 12.0, size.y * 0.55 + i * 8.0), Color(0, 0, 0, 0.45), 3.0)
	Art.led(self, rect.position + Vector2(size.x - 12.0, size.y - 12.0), 3.0, Color(1.0, 0.4, 0.3))
	Art.led(self, rect.position + Vector2(size.x - 24.0, size.y - 12.0), 3.0, Color(0.3, 0.9, 0.5))


func _sign(bottom: Vector2, text: String) -> void:
	draw_line(bottom, bottom + Vector2(0, -90), Color(0.2, 0.22, 0.3), 5.0)
	var rect := Rect2(bottom + Vector2(-48, -128), Vector2(96, 34))
	Art.panel(self, rect, Color(0.95, 0.75, 0.12), 4.0)
	Art.rrect_line(self, rect.grow(-4.0), Color(0.1, 0.1, 0.13), 2.0, 2.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, 23), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 18, Color(0.1, 0.1, 0.13))


func _pipe_run(from: Vector2, length: float) -> void:
	Art.rrect_grad(self, Rect2(from + Vector2(0, -22), Vector2(length, 22)), Color(0.5, 0.53, 0.62), Color(0.22, 0.24, 0.32), 10.0)
	for x in [20.0, length - 30.0]:
		draw_rect(Rect2(from + Vector2(x, -26), Vector2(10, 30)), Color(0.15, 0.16, 0.22))
