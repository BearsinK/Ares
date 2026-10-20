class_name RobotArt
extends RefCounted
## Zeichencode fuer Spieler-Roboter und Gegner (Seitenansicht).
## Alles wird nach rechts blickend gezeichnet und per Skalierung gespiegelt.
##
## Spielerzustand s: facing, aim (Weltrichtung), t (Zeit), vx, walk (Laufphase),
## grounded, clinging, cling_dir, planted, mood, firing (0 bis 1), charge (0 bis 1),
## weapon_color, accent (Spielerfarbe), eye_color.

static func draw_player(c: CanvasItem, class_id: String, s: Dictionary, offset := Vector2.ZERO, zoom := 1.0) -> void:
	var facing: float = s.facing
	var lean := clampf(float(s.vx) / 1100.0, -0.07, 0.07)
	c.draw_set_transform(offset, lean, Vector2(facing * zoom, zoom))
	match class_id:
		"roomba":
			_roomba(c, s)
		"hexapod":
			_hexapod(c, s)
		"vending":
			_vending(c, s)
		"printer":
			_printer(c, s)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _local_aim(s: Dictionary) -> Vector2:
	return Vector2(float(s.aim.x) * float(s.facing), float(s.aim.y))


static func _nozzle(c: CanvasItem, from: Vector2, direction: Vector2, length: float, width: float, color: Color, glow_color: Color, firing: float) -> void:
	var side := direction.orthogonal()
	var tip := from + direction * length
	var points := PackedVector2Array([
		from + side * width * 0.5, tip + side * width * 0.28,
		tip - side * width * 0.28, from - side * width * 0.5])
	c.draw_colored_polygon(points, color)
	points.append(points[0])
	c.draw_polyline(points, Art.OUTLINE, 1.5, true)
	if firing > 0.0:
		Art.glow(c, tip, 10.0 + 8.0 * firing, glow_color)


# ---------------------------------------------------------------- Roomba

static func _roomba(c: CanvasItem, s: Dictionary) -> void:
	var t: float = s.t
	var bob := sin(t * 3.0) * 0.5
	var accent: Color = s.accent
	Art.shadow(c, Vector2(0, 15), 30.0, 3.5)

	# Raeder: grosses Antriebsrad hinten, kleine Stuetzrolle vorn, Seitenbuerste.
	var spin := float(s.walk) * 0.9
	Art.disc(c, Vector2(-14, 9), 7.0, Color(0.12, 0.13, 0.17))
	for i in 4:
		var a := spin + i * PI / 2.0
		c.draw_line(Vector2(-14, 9), Vector2(-14, 9) + Vector2(cos(a), sin(a)) * 6.0, Color(0.5, 0.52, 0.6), 1.5, true)
	Art.disc(c, Vector2(-14, 9), 2.2, Color(0.75, 0.78, 0.85))
	Art.disc(c, Vector2(22, 11), 4.0, Color(0.12, 0.13, 0.17))
	for i in 3:
		var a := -spin * 1.6 + i * TAU / 3.0
		c.draw_line(Vector2(30, 12), Vector2(30, 12) + Vector2(cos(a), sin(a) * 0.4) * 5.0, Color(0.9, 0.85, 0.4), 1.5, true)

	# Chassis.
	Art.rrect(c, Rect2(-30, 6 + bob, 60, 7), Color(0.14, 0.16, 0.21), 3.0)
	Art.panel(c, Rect2(-32, -9 + bob, 64, 21), Color(0.94, 0.96, 0.99), 9.0)
	Art.rrect(c, Rect2(-28, 3 + bob, 54, 3), accent, 1.5)
	Art.rrect(c, Rect2(27, -6 + bob, 5, 15), Color(0.2, 0.22, 0.28), 2.5)
	for i in 3:
		c.draw_line(Vector2(-29 + i * 4, -3 + bob), Vector2(-29 + i * 4, 1 + bob), Color(0.55, 0.58, 0.66), 1.5, true)
	Art.rivet(c, Vector2(-26, -5 + bob))
	Art.rivet(c, Vector2(1, 9 + bob))

	# LiDAR-Kuppel und Statusleuchte.
	Art.ellipse(c, Vector2(-17, -9 + bob), 9.0, 4.5, Color(0.18, 0.2, 0.28))
	c.draw_line(Vector2(-23, -10 + bob), Vector2(-12, -10 + bob), Color(1, 1, 1, 0.4), 1.5, true)
	Art.led(c, Vector2(-17, -12 + bob), 1.6, Color(1.0, 0.35, 0.3), fmod(t, 1.2) < 0.6)

	var la := _local_aim(s)
	Art.face(c, Vector2(15, -0.5 + bob), Vector2(22, 12), s.eye_color, la, s.mood, t)

	# Arm mit Absaugduese, zeigt in Zielrichtung.
	var shoulder := Vector2(-5, -12 + bob)
	Art.panel(c, Rect2(-11, -15 + bob, 12, 6), Color(0.28, 0.3, 0.38), 2.5)
	Art.disc(c, shoulder, 4.0, Color(0.62, 0.65, 0.75))
	var reach := 24.0
	var wrist := Art.limb(c, shoulder, shoulder + la * reach, 14.0, 14.0, 5.0, Color(0.32, 0.36, 0.5), -1.0 if la.x >= 0.0 else 1.0, Color(0.9, 0.92, 1.0))
	_nozzle(c, wrist, la, 11.0, 10.0, Color(0.85, 0.87, 0.95), s.weapon_color, float(s.firing))
	Art.rivet(c, wrist, 1.6)


# ---------------------------------------------------------------- Hexapod

static func _hexapod(c: CanvasItem, s: Dictionary) -> void:
	var t: float = s.t
	var accent: Color = s.accent
	var planted: bool = s.planted
	var clinging: bool = s.clinging
	Art.shadow(c, Vector2(0, 23), 26.0, 3.5)

	var speed_factor := clampf(absf(float(s.vx)) / 300.0, 0.0, 1.0)
	var cling_side := float(s.cling_dir) * float(s.facing)
	# Beine: erst die fernen (dunkler), dann die nahen.
	for layer in 2:
		var far := layer == 0
		for i in 3:
			var hip := Vector2(-17.0 + i * 17.0 + (5.0 if far else 0.0), 4.0)
			var phase := float(s.walk) * 0.55 + (PI if (i % 2 == 0) != far else 0.0)
			var foot := Vector2.ZERO
			if clinging:
				foot = Vector2(cling_side * 31.0, -10.0 + i * 14.0 + (4.0 if far else 0.0))
			elif not bool(s.grounded):
				foot = Vector2(hip.x * 0.8, 14.0)
			elif planted:
				foot = Vector2(hip.x * 1.55 + (3.0 if far else 0.0), 23.0)
			else:
				foot = Vector2(hip.x + sin(phase) * 13.0 * speed_factor, 23.0 - maxf(0.0, cos(phase)) * 9.0 * speed_factor)
			var color := Color(0.18, 0.2, 0.27) if far else Color(0.3, 0.32, 0.4)
			var bend := 1.0 if i == 2 else -1.0
			if clinging:
				bend = -cling_side
			var end := Art.limb(c, hip, foot, 15.0, 15.0, 3.6, color, bend, Color(0.7, 0.72, 0.8))
			if planted and not far:
				c.draw_colored_polygon(PackedVector2Array([end + Vector2(-3, 0), end + Vector2(3, 0), end + Vector2(0, 5)]), Color(0.8, 0.8, 0.9))

	# Koerper: gepanzerter Unterbau und Kuppel.
	Art.panel(c, Rect2(-22, -3, 44, 15), Color(0.28, 0.3, 0.38), 6.0)
	Art.rrect(c, Rect2(-20, 3, 40, 3), accent, 1.5)
	var dome_points := PackedVector2Array()
	var dome_colors := PackedColorArray()
	for i in 17:
		var angle := PI + PI * float(i) / 16.0
		var p := Vector2(cos(angle) * 25.0, -3.0 + sin(angle) * 17.0)
		dome_points.append(p)
		dome_colors.append(Color(0.97, 0.98, 1.0).lerp(Color(0.72, 0.75, 0.85), clampf((p.y + 20.0) / 17.0, 0.0, 1.0)))
	c.draw_polygon(dome_points, dome_colors)
	dome_points.append(dome_points[0])
	c.draw_polyline(dome_points, Art.OUTLINE, 2.0, true)
	c.draw_line(Vector2(-14, -14), Vector2(4, -17), Color(1, 1, 1, 0.55), 2.0, true)
	var la := _local_aim(s)
	Art.face(c, Vector2(9, -8), Vector2(19, 10), s.eye_color, la, s.mood, t)
	Art.rivet(c, Vector2(-15, 8))
	Art.rivet(c, Vector2(15, 8))

	# Geschuetzkopf oben auf der Kuppel, Rohr zeigt in Zielrichtung.
	var pivot := Vector2(2, -18)
	Art.panel(c, Rect2(-6, -25, 16, 9), Color(0.35, 0.38, 0.48), 3.0)
	Art.led(c, Vector2(-1, -21), 1.5, Color(1.0, 0.3, 0.25), planted)
	var tip := pivot + la * 22.0
	Art.bar(c, pivot, tip, 5.0, Color(0.5, 0.53, 0.62))
	var side := la.orthogonal()
	c.draw_line(tip - la * 5.0 + side * 3.5, tip - la * 5.0 - side * 3.5, Color(0.85, 0.87, 0.95), 2.5, true)
	if float(s.firing) > 0.0:
		Art.glow(c, tip, 10.0 + 8.0 * float(s.firing), s.weapon_color)


# ---------------------------------------------------------------- Automat

static func _vending(c: CanvasItem, s: Dictionary) -> void:
	var t: float = s.t
	var accent: Color = s.accent
	var charge: float = s.charge
	Art.shadow(c, Vector2(0, 54), 38.0, 4.0)

	# Raupenketten.
	var spin := float(s.walk) * 0.5
	Art.panel(c, Rect2(-35, 36, 70, 19), Color(0.16, 0.17, 0.2), 9.0)
	for i in 14:
		var x := -33.0 + fposmod(float(i) * 5.2 - spin * 5.0, 68.0)
		c.draw_line(Vector2(x, 38), Vector2(x, 41), Color(0.32, 0.33, 0.38), 1.5)
		c.draw_line(Vector2(x, 51), Vector2(x, 54), Color(0.32, 0.33, 0.38), 1.5)
	for i in 4:
		var center := Vector2(-23.0 + i * 15.3, 45.5)
		Art.disc(c, center, 6.0, Color(0.9, 0.75, 0.15))
		for k in 3:
			var a := spin + k * TAU / 3.0
			c.draw_line(center, center + Vector2(cos(a), sin(a)) * 5.0, Color(0.35, 0.28, 0.05), 1.5, true)
		Art.disc(c, center, 1.6, Color(0.3, 0.25, 0.05))

	# Schrank.
	var green := Color(0.16, 0.6, 0.3)
	Art.panel(c, Rect2(-31, -54, 62, 92), green, 7.0)
	Art.rrect(c, Rect2(-31, -54, 62, 12), Color(0.95, 0.95, 0.9), 6.0)
	Art.rrect_line(c, Rect2(-31, -54, 62, 12), Art.OUTLINE, 6.0, 2.0)
	# Blitz-Logo der erfundenen Marke.
	c.draw_colored_polygon(PackedVector2Array([Vector2(-6, -52), Vector2(4, -52), Vector2(-1, -47), Vector2(5, -47), Vector2(-7, -40), Vector2(-3, -46), Vector2(-8, -46)]), Color(0.95, 0.75, 0.1))
	Art.led(c, Vector2(22, -48), 2.0, accent)
	Art.led(c, Vector2(-24, -48), 2.0, Color(0.95, 0.3, 0.3), fmod(t, 1.6) < 0.8)

	# Glasfront mit Dosen.
	var glass := Rect2(-25, -37, 34, 56)
	Art.rrect(c, glass, Color(0.05, 0.12, 0.16), 3.0)
	var can_colors := [Color(0.9, 0.3, 0.25), Color(0.3, 0.8, 0.4), Color(0.95, 0.7, 0.2), Color(0.3, 0.55, 0.95)]
	for row in 5:
		for col in 3:
			var can_color: Color = can_colors[(row + col * 2) % 4]
			Art.rrect(c, Rect2(-22.0 + col * 10.5, -34.0 + row * 10.5, 8, 9), can_color, 2.0)
			c.draw_line(Vector2(-22.0 + col * 10.5, -32.0 + row * 10.5), Vector2(-14.0 + col * 10.5, -32.0 + row * 10.5), Color(1, 1, 1, 0.5), 1.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-25, -37), Vector2(-10, -37), Vector2(-25, -12)]), Color(1, 1, 1, 0.1))
	Art.rrect_line(c, glass, Color(0.6, 0.65, 0.75), 3.0, 2.0)

	# Bedienfeld rechts: Gesicht, Tasten, Muenzschlitz.
	var la := _local_aim(s)
	Art.face(c, Vector2(20, -30), Vector2(15, 13), s.eye_color, la, s.mood, t)
	for row in 3:
		for col in 2:
			Art.disc(c, Vector2(16.0 + col * 7.0, -16.0 + row * 7.0), 2.1, Color(0.9, 0.9, 0.95) if (row + col) % 2 == 0 else Color(0.95, 0.7, 0.2))
	Art.rrect(c, Rect2(15, 8, 10, 3), Color(0.05, 0.08, 0.1), 1.5)
	Art.rrect(c, Rect2(-25, 24, 34, 11), Color(0.04, 0.07, 0.09), 3.0)
	c.draw_line(Vector2(-23, 26), Vector2(7, 26), Color(1, 1, 1, 0.25), 1.5)
	Art.rivet(c, Vector2(-28, -38))
	Art.rivet(c, Vector2(28, -38))
	Art.rivet(c, Vector2(-28, 33))
	Art.rivet(c, Vector2(28, 33))

	# Dosenwerfer oben: Rohr zeigt in Zielrichtung, geschuettelte Dose schaeumt.
	var pivot := Vector2(6, -56)
	var shake := Vector2.ZERO
	if charge > 0.0:
		shake = Vector2(sin(t * 90.0), cos(t * 77.0)) * charge * 2.0
	Art.disc(c, pivot, 7.0, Color(0.3, 0.32, 0.4))
	var tube_end := pivot + la * 22.0 + shake
	Art.bar(c, pivot, tube_end, 11.0, Color(0.55, 0.58, 0.66))
	var can_color: Color = s.weapon_color
	var can_pos := tube_end + la * 4.0
	Art.rrect(c, Rect2(can_pos - Vector2(5, 6), Vector2(10, 12)), can_color.lerp(Color.WHITE, charge * 0.5), 2.0)
	if charge > 0.0:
		Art.glow(c, can_pos, 9.0 + 10.0 * charge, Color(1, 1, 1))
		for i in 4:
			var a := t * 12.0 + i * 1.7
			c.draw_circle(can_pos + Vector2(cos(a), -absf(sin(a)) - 0.6) * (6.0 + 5.0 * charge), 1.6 + charge, Color(1, 1, 1, 0.8))


# ---------------------------------------------------------------- Drucker

static func _printer(c: CanvasItem, s: Dictionary) -> void:
	var t: float = s.t
	var accent: Color = s.accent
	Art.shadow(c, Vector2(0, 29), 30.0, 3.5)
	# Fuesse.
	Art.panel(c, Rect2(-25, 24, 14, 6), Color(0.1, 0.1, 0.13), 2.0)
	Art.panel(c, Rect2(11, 24, 14, 6), Color(0.1, 0.1, 0.13), 2.0)
	# Gehaeuse.
	Art.panel(c, Rect2(-29, -27, 58, 53), Color(0.2, 0.21, 0.27), 7.0)
	Art.rrect(c, Rect2(15, -23, 12, 45), Color(0.95, 0.5, 0.12), 5.0)
	Art.rrect_line(c, Rect2(15, -23, 12, 45), Art.OUTLINE, 5.0, 1.5)
	Art.disc(c, Vector2(21, 14), 3.0, Color(0.15, 0.15, 0.2))
	Art.rrect(c, Rect2(-29, -27, 58, 5), Color(0.1, 0.1, 0.14), 3.0)
	Art.rrect(c, Rect2(-25, 20, 36, 2.5), accent, 1.0)
	# Filamentspule an der Rueckseite.
	Art.disc(c, Vector2(-30, -8), 9.0, Color(0.95, 0.5, 0.12))
	Art.disc(c, Vector2(-30, -8), 3.5, Color(0.15, 0.15, 0.2))
	c.draw_arc(Vector2(-30, -8), 6.5, 0.0, TAU, 16, Color(1, 1, 1, 0.3), 1.0, true)
	# Sichtfenster: Druckbett, Portal mit Duese und das entstehende Objekt.
	var window := Rect2(-24, -17, 36, 33)
	Art.rrect(c, window, Color(0.04, 0.07, 0.1), 3.0)
	Art.rrect(c, Rect2(-21, 12, 30, 3), Color(0.6, 0.63, 0.72), 1.0)
	var progress := sin(t * 0.7) * 0.5 + 0.5
	var height := 5.0 + 20.0 * progress
	var top_y := 12.0 - height
	var layer := PackedVector2Array([Vector2(-14, 12), Vector2(-9, top_y + 4.0), Vector2(-7, top_y), Vector2(1, top_y), Vector2(3, top_y + 4.0), Vector2(8, 12)])
	c.draw_colored_polygon(layer, Color(0.92, 0.95, 1.0, 0.92))
	for i in int(height / 3.0):
		c.draw_line(Vector2(-12, 11.0 - i * 3.0), Vector2(6, 11.0 - i * 3.0), Color(0.6, 0.65, 0.8, 0.45), 1.0)
	var head_x := -3.0 + sin(t * 3.0) * 9.0
	c.draw_line(Vector2(-22, top_y - 5.0), Vector2(10, top_y - 5.0), Color(0.55, 0.58, 0.68), 2.0)
	Art.rrect(c, Rect2(head_x - 4, top_y - 9.0, 8, 7), Color(0.85, 0.87, 0.95), 1.5)
	c.draw_line(Vector2(head_x, top_y - 2.0), Vector2(head_x, top_y - 0.5), Color(1.0, 0.55, 0.15), 1.5)
	Art.glow(c, Vector2(head_x, top_y), 4.0, Color(1.0, 0.55, 0.15))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-24, -17), Vector2(-8, -17), Vector2(-24, 0)]), Color(1, 1, 1, 0.1))
	Art.rrect_line(c, window, Color(0.6, 0.65, 0.75), 3.0, 2.0)
	var la := _local_aim(s)
	Art.face(c, Vector2(21, -13), Vector2(11, 11), s.eye_color, la, s.mood, t)
	# Zwei Drohnen schweben ueber dem Gehaeuse (Platzhalter fuer die spaetere Drohnenmechanik).
	for i in 2:
		var base := Vector2(-13.0 + i * 27.0, -38.0 + sin(t * 3.0 + i * 2.0) * 2.0)
		Art.ellipse(c, base, 7.0, 3.5, Color(0.3, 0.32, 0.4))
		Art.ellipse(c, base + Vector2(0, -1), 4.5, 2.0, Color(0.55, 0.57, 0.66))
		c.draw_line(base + Vector2(-9, -4), base + Vector2(9, -4), Color(1, 1, 1, 0.55), 1.5)
		Art.led(c, base + Vector2(0, 2), 1.3, Color(1.0, 0.55, 0.2))
	var pivot := Vector2(0, -30)
	var wrist := pivot + la * 10.0
	Art.bar(c, pivot, wrist, 5.0, Color(0.5, 0.53, 0.62))
	if float(s.firing) > 0.0:
		Art.glow(c, wrist, 10.0 + 8.0 * float(s.firing), s.weapon_color)


# ---------------------------------------------------------------- Gegner

static func draw_enemy(c: CanvasItem, kind: String, s: Dictionary, offset := Vector2.ZERO, zoom := 1.0) -> void:
	var facing: float = s.facing
	c.draw_set_transform(offset, 0.0, Vector2(facing * zoom, zoom))
	match kind:
		"walker":
			_walker(c, s)
		"shooter":
			_shooter(c, s)
		"flyer":
			_flyer(c, s)
		"brute":
			_brute(c, s)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _tint(color: Color, s: Dictionary) -> Color:
	return color.lerp(Color.WHITE, 0.8) if s.flash else color


static func _walker(c: CanvasItem, s: Dictionary) -> void:
	var t: float = s.t
	var body := _tint(Color(0.82, 0.24, 0.3), s)
	var windup: float = s.windup
	Art.shadow(c, Vector2(0, 14), 12.0, 2.5, 0.3)
	# Rad und Koerper.
	var spin := float(s.walk) * 0.9
	Art.disc(c, Vector2(0, 8), 7.5, _tint(Color(0.15, 0.15, 0.2), s))
	for i in 4:
		var a := spin + i * PI / 2.0
		c.draw_line(Vector2(0, 8), Vector2(0, 8) + Vector2(cos(a), sin(a)) * 6.0, Color(0.6, 0.45, 0.45), 1.5, true)
	Art.panel(c, Rect2(-8, -8, 16, 16), body, 5.0)
	Art.rrect(c, Rect2(-8, 2, 16, 3), _tint(Color(1.0, 0.65, 0.15), s), 1.0)
	# Kopf mit Visier.
	Art.panel(c, Rect2(-8, -17, 16, 11), _tint(Color(0.35, 0.36, 0.45), s), 4.0)
	var look := Vector2(float(s.aim.x) * float(s.facing), float(s.aim.y))
	Art.face(c, Vector2(1, -11.5), Vector2(13, 7), Color(1.0, 0.2, 0.2), look, "angry", t)
	c.draw_line(Vector2(-4, -17), Vector2(-6, -23), Color(0.6, 0.6, 0.7), 1.5, true)
	Art.led(c, Vector2(-6, -23), 1.4, Color(1.0, 0.3, 0.2), fmod(t, 0.8) < 0.4)
	# Schlagstock: hebt sich in der Vorwarnung und schlaegt zu.
	var angle := 0.9
	if bool(s.slam):
		angle = 1.5
	elif windup >= 0.0:
		angle = lerpf(0.9, -1.9, windup)
	var shoulder := Vector2(6, -3)
	var hand := shoulder + Vector2(cos(angle), sin(angle)) * 8.0
	var tip := hand + Vector2(cos(angle), sin(angle)) * 13.0
	Art.bar(c, shoulder, hand, 3.5, _tint(Color(0.45, 0.46, 0.55), s))
	Art.bar(c, hand, tip, 3.0, _tint(Color(0.9, 0.3, 0.25), s))
	if windup >= 0.0:
		Art.glow(c, tip, 7.0 + 6.0 * windup, Color(1.0, 0.3, 0.2))


static func _shooter(c: CanvasItem, s: Dictionary) -> void:
	var t: float = s.t
	var windup: float = s.windup
	var body := _tint(Color(0.62, 0.3, 0.8), s)
	Art.shadow(c, Vector2(0, 13), 14.0, 2.5, 0.3)
	# Dreibein.
	var foot_color := _tint(Color(0.28, 0.28, 0.36), s)
	Art.limb(c, Vector2(-4, 4), Vector2(-14, 13), 7.0, 7.0, 3.0, foot_color, -1.0)
	Art.limb(c, Vector2(4, 4), Vector2(14, 13), 7.0, 7.0, 3.0, foot_color, 1.0)
	Art.bar(c, Vector2(0, 4), Vector2(0, 13), 3.5, foot_color)
	# Koerper und Linse.
	Art.panel(c, Rect2(-10, -9, 20, 17), body, 7.0)
	Art.rrect(c, Rect2(-10, 1, 20, 3), _tint(Color(1.0, 0.65, 0.15), s), 1.0)
	var aim_local := Vector2(float(s.aim.x) * float(s.facing), float(s.aim.y))
	var barrel_tip := Vector2(0, -2) + aim_local * 19.0
	Art.bar(c, Vector2(0, -2), barrel_tip, 5.0, _tint(Color(0.35, 0.36, 0.46), s))
	var lens := Color(1.0, 0.25 + 0.4 * (1.0 - maxf(windup, 0.0)), 0.2)
	Art.disc(c, Vector2(3, -4), 4.5, Color(0.1, 0.05, 0.08))
	Art.led(c, Vector2(3, -4), 3.0, lens, true)
	if windup >= 0.0:
		Art.glow(c, barrel_tip, 8.0 + 8.0 * windup, Color(1.0, 0.3, 0.3))
	c.draw_line(Vector2(-6, -9), Vector2(-8, -14), Color(0.6, 0.6, 0.7), 1.5, true)
	Art.led(c, Vector2(-8, -14), 1.3, Color(1.0, 0.3, 0.2), fmod(t, 1.0) < 0.5)


static func _flyer(c: CanvasItem, s: Dictionary) -> void:
	var t: float = s.t
	var body := _tint(Color(0.95, 0.6, 0.2), s)
	var windup: float = s.windup
	Art.shadow(c, Vector2(0, 40), 9.0, 2.0, 0.12)
	# Rotoren (verwischt).
	for side in [-1.0, 1.0]:
		var rotor := Vector2(side * 9.0, -9.0)
		c.draw_line(Vector2(side * 4.0, -4.0), rotor, Color(0.3, 0.3, 0.38), 2.0, true)
		var length := 10.0 + sin(t * 55.0 + side) * 2.5
		Art.ellipse(c, rotor, length, 1.6, Color(0.85, 0.88, 0.95, 0.45))
		c.draw_line(rotor + Vector2(-length, 0), rotor + Vector2(length, 0), Color(1, 1, 1, 0.5), 1.0, true)
	Art.ellipse(c, Vector2(0, 0), 12.0, 8.0, Art.OUTLINE)
	Art.ellipse(c, Vector2(0, -0.5), 11.0, 7.0, body)
	Art.ellipse(c, Vector2(-2, -3.0), 7.0, 2.5, Color(1, 1, 1, 0.3))
	Art.rrect(c, Rect2(-9, 1.5, 18, 2.5), _tint(Color(0.25, 0.25, 0.3), s), 1.0)
	# Auge und Triebwerk.
	Art.disc(c, Vector2(5, -0.5), 3.8, Color(0.08, 0.04, 0.06))
	Art.led(c, Vector2(5, -0.5), 2.6, Color(1.0, 0.25 + 0.5 * (1.0 - maxf(windup, 0.0)), 0.15), true)
	Art.glow(c, Vector2(-1, 9), 6.0 + sin(t * 30.0) * 1.5, Color(0.5, 0.8, 1.0))
	if windup >= 0.0:
		var aim_local := Vector2(float(s.aim.x) * float(s.facing), float(s.aim.y))
		Art.glow(c, aim_local * 12.0, 7.0 + 6.0 * windup, Color(1.0, 0.3, 0.3))


static func _brute(c: CanvasItem, s: Dictionary) -> void:
	var t: float = s.t
	var windup: float = s.windup
	var body := _tint(Color(0.55, 0.2, 0.25), s)
	var dark := _tint(Color(0.22, 0.14, 0.17), s)
	Art.shadow(c, Vector2(0, 26), 28.0, 3.5, 0.35)
	# Abgasrohre mit Rauch.
	for i in 2:
		var stack := Vector2(-16.0 + i * 9.0, -34.0)
		Art.rrect(c, Rect2(stack - Vector2(3, 8), Vector2(6, 12)), dark, 2.0)
		for k in 3:
			var life := fposmod(t * 0.9 + k * 0.33 + i * 0.2, 1.0)
			c.draw_circle(stack + Vector2(-life * 8.0, -9.0 - life * 22.0), 3.0 + life * 5.0, Color(0.6, 0.6, 0.66, 0.35 * (1.0 - life)))
	# Beine mit Hydraulikkolben.
	for i in 2:
		var x := -14.0 + i * 28.0
		Art.panel(c, Rect2(x - 7, 6, 14, 20), dark, 4.0)
		Art.rrect(c, Rect2(x - 3, 8, 6, 12), Color(0.65, 0.68, 0.78), 2.0)
		Art.panel(c, Rect2(x - 10, 22, 20, 6), _tint(Color(0.3, 0.3, 0.38), s), 3.0)
	# Rumpf mit Warnstreifen.
	Art.panel(c, Rect2(-24, -30, 48, 40), body, 7.0)
	for i in 5:
		var x := -22.0 + i * 9.5
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, 5), Vector2(x + 5, 5), Vector2(x + 9, 9), Vector2(x + 4, 9)]), _tint(Color(1.0, 0.75, 0.1), s))
	Art.rivet(c, Vector2(-20, -26))
	Art.rivet(c, Vector2(20, -26))
	Art.rivet(c, Vector2(-20, 1))
	Art.rivet(c, Vector2(20, 1))
	# Kopf mit Visierschlitz.
	Art.panel(c, Rect2(-11, -43, 22, 14), _tint(Color(0.32, 0.33, 0.42), s), 5.0)
	var look := Vector2(float(s.aim.x) * float(s.facing), float(s.aim.y))
	Art.face(c, Vector2(1, -36), Vector2(18, 8), Color(1.0, 0.2, 0.15), look, "angry", t)
	# Arme: Fausthoehe folgt der Vorwarnung (erhobene Fauste, dann Schlag nach unten).
	for i in 2:
		var near := i == 1
		var shoulder := Vector2(22.0 if near else -22.0, -22.0)
		var fist := Vector2(27.0 if near else -27.0, 8.0)
		if bool(s.slam):
			fist = Vector2(25.0 if near else -25.0, 26.0)
		elif windup >= 0.0:
			fist = Vector2(lerpf(27.0, 14.0, windup) * (1.0 if near else -1.0), lerpf(8.0, -56.0, windup))
		var arm_color := _tint(Color(0.4, 0.17, 0.2) if near else Color(0.3, 0.13, 0.16), s)
		var end := Art.limb(c, shoulder, fist, 18.0, 18.0, 8.0, arm_color, 1.0 if near else -1.0)
		Art.disc(c, end, 10.0, _tint(Color(0.28, 0.28, 0.35), s))
		c.draw_arc(end, 6.0, 0.0, TAU, 12, _tint(Color(1.0, 0.75, 0.1), s), 2.0, true)
	if windup >= 0.0:
		Art.glow(c, Vector2(0, -20), 30.0 + 16.0 * windup, Color(1.0, 0.25, 0.2))
