class_name Backdrop
extends Node2D
## Hintergrund der Fabrikhalle in drei Parallax-Ebenen: ferne Halle mit
## Fenstern und Schornsteinen, mittlere Maschinen mit sich drehenden Zahnraedern,
## nahes Geruest. Ebenen verschieben sich langsamer als die Kamera.

const AREA := Rect2(-2200, -1400, 7600, 4400)

var camera: Camera2D
var _layers: Array = []


class Layer extends Node2D:
	var factor := 0.2
	var painter: Callable
	var animated := false

	func _draw() -> void:
		painter.call(self)

	func _process(_delta: float) -> void:
		if animated:
			queue_redraw()


func _ready() -> void:
	z_index = -100
	# Der Hintergrund soll zurueckstehen: gedaempft, damit Figuren, Gegner und Geschosse davor lesbar bleiben.
	modulate = Color(0.66, 0.66, 0.72)
	_add_layer(0.12, _paint_far, false)
	_add_layer(0.35, _paint_mid, true)
	_add_layer(0.62, _paint_near, false)


func _add_layer(factor: float, painter: Callable, animated: bool) -> void:
	var layer := Layer.new()
	layer.factor = factor
	layer.painter = painter
	layer.animated = animated
	add_child(layer)
	_layers.append(layer)


func _process(_delta: float) -> void:
	if camera == null:
		return
	for layer in _layers:
		layer.position = camera.get_screen_center_position() * (1.0 - layer.factor)


func _time() -> float:
	return Time.get_ticks_msec() / 1000.0


# ----------------------------------------------------------- ferne Ebene

func _paint_far(c: CanvasItem) -> void:
	var area := AREA
	# Wand der Halle: dunkler Verlauf, unten warmer Schein.
	var points := PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])
	var colors := PackedColorArray([Color(0.05, 0.06, 0.12), Color(0.05, 0.06, 0.12), Color(0.2, 0.12, 0.16), Color(0.2, 0.12, 0.16)])
	c.draw_polygon(points, colors)
	# Grosse Fenster mit Gluehen dahinter.
	var x := -900.0
	while x < 4300.0:
		var window := Rect2(x, 250, 220, 520)
		Art.rrect(c, window, Color(0.75, 0.46, 0.26, 0.9), 6.0)
		Art.rrect_grad(c, Rect2(window.position + Vector2(8, 8), window.size - Vector2(16, 16)), Color(0.18, 0.22, 0.4), Color(0.72, 0.42, 0.3), 3.0)
		for k in 4:
			c.draw_line(window.position + Vector2(10, 8 + k * 130), window.position + Vector2(window.size.x - 10, 8 + k * 130), Color(0.06, 0.06, 0.1), 5.0)
		c.draw_line(window.position + Vector2(window.size.x * 0.5, 8), window.position + Vector2(window.size.x * 0.5, window.size.y - 8), Color(0.06, 0.06, 0.1), 5.0)
		Art.rrect_line(c, window, Color(0.08, 0.08, 0.13), 6.0, 8.0)
		x += 420.0
	# Schornsteine am Horizont.
	for i in 9:
		var cx := -800.0 + i * 600.0
		var h := 380.0 + (i % 3) * 120.0
		Art.rrect_grad(c, Rect2(cx, 1150 - h, 80, h), Color(0.12, 0.1, 0.16), Color(0.08, 0.07, 0.11), 3.0)
		c.draw_rect(Rect2(cx - 6, 1150 - h, 92, 14), Color(0.2, 0.15, 0.2))
		for k in 3:
			c.draw_circle(Vector2(cx + 40 + k * 22, 1150 - h - 30 - k * 40), 34 + k * 16, Color(0.25, 0.2, 0.26, 0.2))


# ----------------------------------------------------------- mittlere Ebene

func _paint_mid(c: CanvasItem) -> void:
	var t := _time()
	# Grosse Rohre quer durch die Halle.
	for i in 4:
		var y := 180.0 + i * 260.0
		Art.rrect_grad(c, Rect2(-1800, y, 7200, 46), Color(0.24, 0.26, 0.36), Color(0.1, 0.11, 0.17), 20.0)
		c.draw_line(Vector2(-1800, y + 8), Vector2(5400, y + 8), Color(1, 1, 1, 0.12), 3.0)
		var x := -1700.0
		while x < 5300.0:
			c.draw_rect(Rect2(x, y - 4, 16, 54), Color(0.08, 0.09, 0.13))
			x += 380.0
	# Tanks und Stahltraeger.
	for i in 8:
		var cx := -900.0 + i * 700.0
		Art.rrect_grad(c, Rect2(cx, 700, 190, 760), Color(0.2, 0.22, 0.31), Color(0.08, 0.09, 0.14), 40.0)
		c.draw_line(Vector2(cx + 30, 720), Vector2(cx + 30, 1440), Color(1, 1, 1, 0.07), 14.0)
		for k in 3:
			c.draw_line(Vector2(cx, 860 + k * 200), Vector2(cx + 190, 860 + k * 200), Color(0, 0, 0, 0.4), 4.0)
		Art.led(c, Vector2(cx + 160, 730), 6.0, Color(0.3, 0.9, 0.5) if int(t + i) % 2 == 0 else Color(0.9, 0.35, 0.3))
	# Drehende Zahnraeder.
	var gears := [Vector2(500, 560), Vector2(1700, 420), Vector2(2900, 600), Vector2(4000, 460)]
	for i in gears.size():
		_gear(c, gears[i], 120.0 + (i % 2) * 40.0, 10 + (i % 2) * 2, t * (0.25 if i % 2 == 0 else -0.3))


func _gear(c: CanvasItem, center: Vector2, radius: float, teeth: int, angle: float) -> void:
	var points := PackedVector2Array()
	for i in teeth * 2:
		var a := angle + TAU * float(i) / float(teeth * 2)
		var r := radius if i % 2 == 0 else radius * 0.82
		points.append(center + Vector2(cos(a), sin(a)) * r)
		points.append(center + Vector2(cos(a + TAU / float(teeth * 4)), sin(a + TAU / float(teeth * 4))) * r)
	c.draw_colored_polygon(points, Color(0.16, 0.17, 0.25))
	c.draw_circle(center, radius * 0.55, Color(0.1, 0.11, 0.17))
	c.draw_arc(center, radius * 0.55, 0.0, TAU, 32, Color(0.3, 0.32, 0.42), 4.0, true)
	for i in 5:
		var a := angle + i * TAU / 5.0
		c.draw_line(center, center + Vector2(cos(a), sin(a)) * radius * 0.5, Color(0.22, 0.24, 0.33), 10.0)
	c.draw_circle(center, radius * 0.14, Color(0.35, 0.37, 0.48))


# ----------------------------------------------------------- nahe Ebene

func _paint_near(c: CanvasItem) -> void:
	# Senkrechte Stahlsaeulen mit Querstreben und haengenden Lampen.
	for i in 14:
		var x := -1000.0 + i * 480.0
		Art.rrect_grad(c, Rect2(x, -200, 64, 1900), Color(0.15, 0.16, 0.23), Color(0.07, 0.08, 0.12), 3.0)
		c.draw_line(Vector2(x + 6, -200), Vector2(x + 6, 1700), Color(1, 1, 1, 0.1), 3.0)
		for k in 12:
			c.draw_line(Vector2(x, 60 + k * 150), Vector2(x + 64, 60 + k * 150), Color(0, 0, 0, 0.5), 3.0)
		if i % 2 == 0:
			var lamp := Vector2(x + 32, 330)
			c.draw_line(Vector2(x + 32, 190), lamp, Color(0.05, 0.05, 0.08), 3.0)
			Art.rrect(c, Rect2(lamp + Vector2(-26, 0), Vector2(52, 16)), Color(0.12, 0.12, 0.17), 6.0)
			c.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-24, 16), lamp + Vector2(24, 16), lamp + Vector2(120, 520), lamp + Vector2(-120, 520)]), Color(1.0, 0.85, 0.55, 0.045))
			Art.glow(c, lamp + Vector2(0, 16), 34.0, Color(1.0, 0.85, 0.55))
