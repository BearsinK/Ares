class_name TerrainArt
extends Node2D
## Optik fuer Felsmassen und Rampen der grossen Karten: dunkle Schichten mit Stahlkante oben,
## Warnstreifen an den Kanten, Nieten und Fugen. Rechtecke werden in Streifen zerlegt,
## damit die Grafikkarte weit entfernte Teile auslassen kann.

const CHUNK := 640.0

## "rect", "ramp" oder "frame" (Aussenwaende und Decke, nur dunkel).
var kind := "rect"
var rect := Rect2()
var points := PackedVector2Array()
var seed_value := 0


func _draw() -> void:
	match kind:
		"ramp":
			_draw_ramp()
		"frame":
			draw_rect(rect, Color(0.04, 0.045, 0.07))
		_:
			_draw_rect_mass()


func _draw_rect_mass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var depth := rect.size.y
	# Koerper mit Verlauf: oben mittelgrau, nach unten fast schwarz.
	var top := Color(0.24, 0.26, 0.34)
	var bottom := Color(0.05, 0.055, 0.085)
	var steps := clampi(int(depth / 110.0), 1, 8)
	for i in steps:
		var y0 := rect.position.y + depth * float(i) / float(steps)
		var y1 := rect.position.y + depth * float(i + 1) / float(steps)
		draw_rect(Rect2(rect.position.x, y0, rect.size.x, y1 - y0 + 1.0), top.lerp(bottom, clampf(float(i) / float(steps) * 1.1, 0.0, 1.0)))
	# Schichtfugen und Fugen senkrecht.
	var y := rect.position.y + 70.0
	while y < rect.end.y - 10.0:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0, 0, 0, 0.35), 2.0)
		draw_line(Vector2(rect.position.x, y + 2.0), Vector2(rect.end.x, y + 2.0), Color(1, 1, 1, 0.045), 1.0)
		var seam := rect.position.x + rng.randf_range(0.0, 200.0)
		while seam < rect.end.x:
			draw_line(Vector2(seam, y), Vector2(seam, minf(y + 70.0, rect.end.y)), Color(0, 0, 0, 0.28), 2.0)
			seam += rng.randf_range(180.0, 320.0)
		y += rng.randf_range(80.0, 120.0)
	# Obere Stahlkante mit Warnstreifen-Stuecken.
	if depth > 40.0:
		_top_lip(rect.position.x, rect.end.x, rect.position.y, rng)
	# Seitenkanten: helle Linke, dunkle Rechte.
	draw_line(rect.position + Vector2(1.5, 0), Vector2(rect.position.x + 1.5, rect.end.y), Color(1, 1, 1, 0.13), 3.0)
	draw_line(Vector2(rect.end.x - 1.5, rect.position.y), rect.end - Vector2(1.5, 0), Color(0, 0, 0, 0.5), 3.0)
	# Unterkante dunkel (Ueberhaenge).
	draw_line(Vector2(rect.position.x, rect.end.y - 1.0), rect.end - Vector2(0, 1.0), Color(0, 0, 0, 0.6), 3.0)


func _top_lip(x0: float, x1: float, y: float, rng: RandomNumberGenerator) -> void:
	draw_rect(Rect2(x0, y, x1 - x0, 9.0), Color(0.55, 0.58, 0.68))
	draw_rect(Rect2(x0, y + 5.0, x1 - x0, 4.0), Color(0.33, 0.36, 0.45))
	draw_line(Vector2(x0, y + 1.0), Vector2(x1, y + 1.0), Color(1, 1, 1, 0.5), 1.5)
	# Warnstreifen an der Kante, abschnittsweise.
	var x := x0 + rng.randf_range(40.0, 120.0)
	while x < x1 - 120.0:
		var length := rng.randf_range(60.0, 130.0)
		var strip := Rect2(x, y + 9.0, length, 8.0)
		draw_rect(strip, Color(0.95, 0.75, 0.12))
		var sx := strip.position.x - 8.0
		while sx < strip.end.x:
			var a := Vector2(clampf(sx, strip.position.x, strip.end.x), strip.end.y)
			var b := Vector2(clampf(sx + 6.0, strip.position.x, strip.end.x), strip.end.y)
			var c := Vector2(clampf(sx + 14.0, strip.position.x, strip.end.x), strip.position.y)
			var d := Vector2(clampf(sx + 8.0, strip.position.x, strip.end.x), strip.position.y)
			draw_colored_polygon(PackedVector2Array([a, b, c, d]), Color(0.1, 0.1, 0.13))
			sx += 12.0
		x += length + rng.randf_range(260.0, 520.0)
	# Nieten entlang der Kante.
	var r := x0 + 30.0
	while r < x1 - 20.0:
		Art.rivet(self, Vector2(r, y + 5.0), 1.2)
		r += 90.0


func _draw_ramp() -> void:
	if points.size() < 3:
		return
	draw_colored_polygon(points, Color(0.2, 0.22, 0.3))
	# Schichten parallel zur Hangneigung, nach unten dunkler.
	var a := points[0]
	var b := points[1]
	var slope := b - a
	var low_y := maxf(a.y, b.y)
	var bottom := 0.0
	for p in points:
		bottom = maxf(bottom, p.y)
	var offset := 40.0
	while offset < bottom - minf(a.y, b.y):
		var shade := clampf(offset / 600.0, 0.0, 0.7)
		var p0 := a + Vector2(0.0, offset)
		var p1 := b + Vector2(0.0, offset)
		draw_line(p0, p1, Color(0, 0, 0, 0.22 + 0.25 * shade), 2.0)
		offset += 60.0
	draw_polyline(PackedVector2Array([a, b]), Color(0.55, 0.58, 0.68), 9.0, true)
	draw_polyline(PackedVector2Array([a + Vector2(0, 4), b + Vector2(0, 4)]), Color(0.33, 0.36, 0.45), 4.0, true)
	draw_polyline(PackedVector2Array([a + Vector2(0, -1), b + Vector2(0, -1)]), Color(1, 1, 1, 0.45), 1.5, true)
	# Warnstreifen-Stuecke auf der Rampe.
	var length := slope.length()
	var dir := slope / maxf(length, 1.0)
	var normal := Vector2(-dir.y, dir.x)
	if normal.y < 0.0:
		normal = -normal
	var t := 60.0
	while t < length - 100.0:
		var start := a + dir * t
		var end := a + dir * (t + 70.0)
		draw_polygon_strip(start + normal * 6.0, end + normal * 6.0, normal * 7.0)
		t += 240.0
	draw_line(points[points.size() - 1], points[points.size() - 2], Color(0, 0, 0, 0.5), 2.0)
	var _unused := low_y


func draw_polygon_strip(from: Vector2, to: Vector2, thickness: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([from, to, to + thickness, from + thickness]), Color(0.95, 0.75, 0.12))
	draw_line(from, to, Color(0, 0, 0, 0.4), 1.0)
