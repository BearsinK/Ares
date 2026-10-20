class_name Art
extends RefCounted
## Zeichenhilfen fuer die Optik: Verlaeufe, abgerundete Panels, Gelenke,
## Leuchten und LCD-Gesichter. Alles wird im Code gezeichnet.

const OUTLINE := Color(0.05, 0.06, 0.1, 0.9)


static func rounded_points(rect: Rect2, radius: float, segments := 5) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var points := PackedVector2Array()
	var corners := [
		[rect.position + Vector2(rect.size.x - r, r), -PI / 2.0],
		[rect.position + Vector2(rect.size.x - r, rect.size.y - r), 0.0],
		[rect.position + Vector2(r, rect.size.y - r), PI / 2.0],
		[rect.position + Vector2(r, r), PI],
	]
	for corner in corners:
		for i in segments + 1:
			var angle: float = corner[1] + (PI / 2.0) * float(i) / float(segments)
			points.append(corner[0] + Vector2(cos(angle), sin(angle)) * r)
	return points


static func rrect(c: CanvasItem, rect: Rect2, color: Color, radius := 4.0) -> void:
	c.draw_colored_polygon(rounded_points(rect, radius), color)


## Senkrechter Farbverlauf von top nach bottom.
static func rrect_grad(c: CanvasItem, rect: Rect2, top: Color, bottom: Color, radius := 4.0) -> void:
	var points := rounded_points(rect, radius)
	var colors := PackedColorArray()
	for point in points:
		var t := clampf((point.y - rect.position.y) / maxf(rect.size.y, 0.001), 0.0, 1.0)
		colors.append(top.lerp(bottom, t))
	c.draw_polygon(points, colors)


static func rrect_line(c: CanvasItem, rect: Rect2, color: Color, radius := 4.0, width := 2.0) -> void:
	var points := rounded_points(rect, radius)
	points.append(points[0])
	c.draw_polyline(points, color, width, true)


## Metallisches Panel: Verlauf, dunkle Kontur und helle Oberkante.
static func panel(c: CanvasItem, rect: Rect2, base: Color, radius := 4.0, outline := OUTLINE) -> void:
	rrect_grad(c, rect, base.lightened(0.18), base.darkened(0.22), radius)
	rrect_line(c, rect, outline, radius, 2.0)
	var inset := minf(radius, 4.0)
	c.draw_line(rect.position + Vector2(inset + 1.0, 2.0), rect.position + Vector2(rect.size.x - inset - 1.0, 2.0),
		Color(1, 1, 1, 0.35), 1.5, true)


static func ellipse(c: CanvasItem, center: Vector2, rx: float, ry: float, color: Color, segments := 24) -> void:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	c.draw_colored_polygon(points, color)


static func disc(c: CanvasItem, center: Vector2, radius: float, color: Color, outline := OUTLINE) -> void:
	c.draw_circle(center, radius, color)
	c.draw_arc(center, radius, 0.0, TAU, 20, outline, 1.5, true)


static func glow(c: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	for i in 4:
		var t := float(i) / 3.0
		c.draw_circle(pos, radius * (1.0 - 0.6 * t), Color(color, 0.07 + 0.1 * t))


static func led(c: CanvasItem, pos: Vector2, radius: float, color: Color, on := true) -> void:
	if on:
		glow(c, pos, radius * 3.0, color)
	c.draw_circle(pos, radius, color if on else color.darkened(0.7))
	c.draw_circle(pos - Vector2(radius * 0.3, radius * 0.3), radius * 0.35, Color(1, 1, 1, 0.7 if on else 0.2))


static func rivet(c: CanvasItem, pos: Vector2, radius := 1.4) -> void:
	c.draw_circle(pos, radius, Color(0.75, 0.78, 0.85, 0.9))
	c.draw_circle(pos + Vector2(0.4, 0.4), radius * 0.5, Color(0.1, 0.1, 0.15, 0.6))


static func shadow(c: CanvasItem, center: Vector2, rx: float, ry: float, alpha := 0.35) -> void:
	ellipse(c, center, rx, ry, Color(0, 0, 0, alpha))


## Dicke Linie mit runden Enden.
static func bar(c: CanvasItem, a: Vector2, b: Vector2, width: float, color: Color, outline := true) -> void:
	if outline:
		c.draw_line(a, b, OUTLINE, width + 2.5, true)
		c.draw_circle(a, width * 0.5 + 1.2, OUTLINE)
		c.draw_circle(b, width * 0.5 + 1.2, OUTLINE)
	c.draw_line(a, b, color, width, true)
	c.draw_circle(a, width * 0.5, color)
	c.draw_circle(b, width * 0.5, color)


## Zweigliedriges Bein oder Arm: gibt das Gelenk zurueck. bend: +1 oder -1 (Knierichtung).
static func limb(c: CanvasItem, shoulder: Vector2, target: Vector2, upper: float, lower: float,
		width: float, color: Color, bend := 1.0, joint_color := Color(0.8, 0.82, 0.9)) -> Vector2:
	var to := target - shoulder
	var distance := clampf(to.length(), absf(upper - lower) + 0.01, upper + lower - 0.01)
	var direction := to.normalized() if to.length() > 0.001 else Vector2.DOWN
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(upper * upper - along * along, 0.0))
	var joint := shoulder + direction * along + direction.orthogonal() * height * bend
	var end := shoulder + direction * distance
	bar(c, shoulder, joint, width, color)
	bar(c, joint, end, width * 0.85, color.darkened(0.12))
	disc(c, joint, width * 0.55, joint_color)
	return end


## LCD-Gesicht auf einem Display. mood: normal, happy, hurt, dead, angry, focus.
static func face(c: CanvasItem, center: Vector2, size: Vector2, color: Color, look: Vector2, mood: String, t: float) -> void:
	var screen := Rect2(center - size * 0.5, size)
	rrect(c, screen, Color(0.03, 0.05, 0.08), 3.0)
	var eye_w := size.x * 0.2
	var eye_h := size.y * 0.5
	var spacing := size.x * 0.24
	var shift := look * Vector2(size.x * 0.05, size.y * 0.06)
	if mood == "normal" and fmod(t, 3.6) < 0.12:
		eye_h = size.y * 0.1
	if mood == "focus":
		eye_h = size.y * 0.28
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		var eye_center: Vector2 = center + Vector2(side * spacing, 0.0) + shift
		match mood:
			"happy":
				c.draw_arc(eye_center + Vector2(0, eye_h * 0.25), eye_w * 0.55, PI, TAU, 8, color, 2.0, true)
			"hurt":
				var k := eye_w * 0.45
				c.draw_line(eye_center + Vector2(-k, -k), eye_center + Vector2(k, k), color, 2.0, true)
				c.draw_line(eye_center + Vector2(-k, k), eye_center + Vector2(k, -k), color, 2.0, true)
			"dead":
				var d := eye_w * 0.4
				c.draw_line(eye_center + Vector2(-d, -d), eye_center + Vector2(d, d), Color(0.9, 0.3, 0.3), 2.0, true)
				c.draw_line(eye_center + Vector2(-d, d), eye_center + Vector2(d, -d), Color(0.9, 0.3, 0.3), 2.0, true)
			"angry":
				c.draw_colored_polygon(PackedVector2Array([
					eye_center + Vector2(side * eye_w * 0.5, -eye_h * 0.5),
					eye_center + Vector2(-side * eye_w * 0.5, -eye_h * 0.5 + eye_h * 0.45),
					eye_center + Vector2(-side * eye_w * 0.5, eye_h * 0.5),
					eye_center + Vector2(side * eye_w * 0.5, eye_h * 0.5)]), color)
			_:
				rrect(c, Rect2(eye_center - Vector2(eye_w * 0.5, eye_h * 0.5), Vector2(eye_w, eye_h)), color, eye_w * 0.4)
	if mood == "happy" and size.x > 16.0:
		c.draw_arc(center + Vector2(0, size.y * 0.18), size.x * 0.12, 0.2, PI - 0.2, 8, color, 1.5, true)
	# Glanz auf dem Display.
	c.draw_line(screen.position + Vector2(2, 2), screen.position + Vector2(size.x * 0.5, 2), Color(1, 1, 1, 0.25), 1.5, true)
	rrect_line(c, screen, Color(0.3, 0.33, 0.4), 3.0, 1.5)


## Starres Armsegment (Platte mit Kontur, Highlight und Schrauben an den Enden).
static func plate(c: CanvasItem, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var direction := (b - a).normalized() if a.distance_to(b) > 0.001 else Vector2.RIGHT
	var side := direction.orthogonal() * width * 0.5
	var points := PackedVector2Array([a + side, b + side, b - side, a - side])
	var outline := PackedVector2Array([a + side * 1.25, b + side * 1.25, b - side * 1.25, a - side * 1.25])
	c.draw_colored_polygon(outline, OUTLINE)
	var colors := PackedColorArray([color.lightened(0.25), color.lightened(0.25), color.darkened(0.2), color.darkened(0.2)])
	c.draw_polygon(points, colors)
	c.draw_line(a + side * 0.55, b + side * 0.55, Color(1, 1, 1, 0.35), 1.2, true)
	rivet(c, a + direction * width * 0.55, 1.2)
	rivet(c, b - direction * width * 0.55, 1.2)


## Gelenk eines zweigliedrigen Arms ohne zu zeichnen. Gibt [Gelenk, Ende] zurueck.
static func ik(shoulder: Vector2, target: Vector2, upper: float, lower: float, bend: float) -> Array:
	var to := target - shoulder
	var distance := clampf(to.length(), absf(upper - lower) + 0.01, upper + lower - 0.01)
	var direction := to.normalized() if to.length() > 0.001 else Vector2.RIGHT
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(upper * upper - along * along, 0.0))
	return [shoulder + direction * along + direction.orthogonal() * height * bend, shoulder + direction * distance]
