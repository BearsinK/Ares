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
	var bob := sin(t * 3.0) * 0.4
	var accent: Color = s.accent
	var silver := Color(0.78, 0.81, 0.9)
	Art.shadow(c, Vector2(0, 13), 34.0, 3.2)

	# Antriebsrad, zur Haelfte unter der Schuerze verborgen.
	var spin := float(s.walk) * 0.9
	Art.disc(c, Vector2(-18, 7), 6.5, Color(0.1, 0.1, 0.13))
	for i in 3:
		var a := spin + i * TAU / 3.0
		c.draw_line(Vector2(-18, 7), Vector2(-18, 7) + Vector2(cos(a), sin(a)) * 5.0, Color(0.4, 0.42, 0.5), 1.5, true)

	# Flache Scheibe: dunkle Schuerze, Gehaeuse mit Silberring, Deckel, grosser Knopf.
	Art.rrect(c, Rect2(-33, 4 + bob, 66, 8), Color(0.08, 0.09, 0.12), 4.0)
	Art.panel(c, Rect2(-34, -7 + bob, 68, 17), Color(0.4, 0.42, 0.52), 8.5)
	c.draw_line(Vector2(-29, 2.5 + bob), Vector2(29, 2.5 + bob), silver, 2.0, true)
	c.draw_line(Vector2(-29, 4.0 + bob), Vector2(29, 4.0 + bob), Color(0, 0, 0, 0.4), 1.0, true)
	Art.rrect(c, Rect2(-29, 8 + bob, 58, 2), accent, 1.0)
	Art.panel(c, Rect2(-28, -11 + bob, 56, 7), Color(0.5, 0.52, 0.62), 3.5)
	# Der typische runde Knopf auf dem Deckel.
	Art.ellipse(c, Vector2(-4, -11.5 + bob), 9.0, 3.2, Color(0.12, 0.13, 0.17))
	Art.ellipse(c, Vector2(-4, -11.8 + bob), 7.0, 2.3, s.eye_color.darkened(0.15))
	Art.glow(c, Vector2(-4, -12 + bob), 9.0, s.eye_color)
	# LiDAR-Turm und Statusleuchte.
	Art.rrect(c, Rect2(-26, -15 + bob, 10, 5), Color(0.12, 0.13, 0.17), 2.0)
	Art.led(c, Vector2(-21, -12.5 + bob), 1.4, Color(1.0, 0.35, 0.3), fmod(t, 1.2) < 0.6)
	# Griffmulde und Lueftung am Heck.
	for i in 3:
		c.draw_line(Vector2(-30 + i * 3.5, -4 + bob), Vector2(-30 + i * 3.5, 0 + bob), Color(0, 0, 0, 0.5), 1.5, true)
	Art.rivet(c, Vector2(2, 7 + bob))

	# Stossstange vorn mit Display, Klippensensor und Seitenbuerste.
	Art.panel(c, Rect2(25, -6 + bob, 9, 15), Color(0.62, 0.65, 0.74), 4.0)
	c.draw_line(Vector2(25, -3 + bob), Vector2(25, 7 + bob), Color(0, 0, 0, 0.5), 1.5)
	var la := _local_aim(s)
	Art.face(c, Vector2(13, -1.5 + bob), Vector2(20, 9), s.eye_color, la, s.mood, t)
	Art.led(c, Vector2(31, 1.5 + bob), 1.1, Color(0.4, 1.0, 0.5))
	# Grosse Seitenbuerste vorn unter der Stossstange: Nabe und sechs drehende Borsten.
	var brush := Vector2(37, 9)
	Art.disc(c, brush, 3.0, Color(0.25, 0.26, 0.32))
	for i in 6:
		var a := -spin * 2.2 + i * TAU / 6.0
		var tip := brush + Vector2(cos(a) * 11.0, sin(a) * 5.0)
		c.draw_line(brush, tip, Color(0.15, 0.15, 0.1), 3.2, true)
		c.draw_line(brush, tip, Color(0.98, 0.85, 0.25), 2.0, true)
		c.draw_circle(tip, 1.7, Color(1.0, 0.95, 0.5))

	# Ausklappbarer Roboterarm vom Heck: eingeklappt liegt er flach auf dem Deckel, beim
	# Schiessen klappt er aus und zielt. Starre Segmente mit Hydraulikkolben.
	var deploy := clampf(float(s.arm), 0.0, 1.0)
	deploy = deploy * deploy * (3.0 - 2.0 * deploy)
	var shoulder := Vector2(-25, -14 + bob)
	Art.panel(c, Rect2(-31, -18 + bob, 12, 6), Color(0.55, 0.58, 0.68), 2.5)
	var stow_elbow := shoulder + Vector2(15, -1.5)
	var stow_wrist := shoulder + Vector2(1, -4.5)
	var reach := 27.0
	var joints := Art.ik(shoulder, shoulder + la * reach, 14.0, 14.0, -1.0 if la.x >= 0.0 else 1.0)
	var elbow: Vector2 = stow_elbow.lerp(joints[0], deploy)
	var wrist: Vector2 = stow_wrist.lerp(joints[1], deploy)
	var arm_color := Color(0.62, 0.66, 0.78)
	Art.plate(c, shoulder, elbow, 5.5, arm_color)
	# Kolben parallel zum Oberarm.
	var side := (elbow - shoulder).orthogonal().normalized()
	c.draw_line(shoulder + side * 3.5 + (elbow - shoulder) * 0.2, shoulder + side * 3.5 + (elbow - shoulder) * 0.7, Color(0.85, 0.87, 0.95), 1.6, true)
	c.draw_line(shoulder + side * 3.5 + (elbow - shoulder) * 0.7, shoulder + side * 3.5 + (elbow - shoulder) * 0.9, Color(0.2, 0.22, 0.28), 2.4, true)
	Art.plate(c, elbow, wrist, 4.8, arm_color.darkened(0.08))
	Art.disc(c, shoulder, 3.6, Color(0.9, 0.92, 1.0))
	Art.disc(c, elbow, 3.4, Color(0.9, 0.92, 1.0))
	var stow_dir := Vector2(-1.0, 0.25).normalized()
	var nozzle_dir := stow_dir.slerp(la, deploy)
	_nozzle(c, wrist, nozzle_dir, 11.0, 11.0, Color(0.14, 0.15, 0.2), s.weapon_color, float(s.firing) * deploy)


# ---------------------------------------------------------------- Hexapod

## Ein Spinnenbein: Oberschenkel steigt vom Rumpf zum hohen Knie auf, der lange, spitz
## zulaufende Unterschenkel faellt zum Boden. Orange Servos sitzen am Knie.
static func _spider_leg(c: CanvasItem, hip: Vector2, knee: Vector2, foot: Vector2, color: Color) -> void:
	Art.bar(c, hip, knee, 4.2, color)
	var dir := (foot - knee).normalized()
	var side := dir.orthogonal()
	var claw := PackedVector2Array([knee + side * 3.2, knee - side * 3.2, foot - side * 0.7, foot + dir * 3.0, foot + side * 0.7])
	c.draw_colored_polygon(claw, color.darkened(0.08))
	c.draw_polyline(PackedVector2Array([claw[0], claw[4], claw[3], claw[2], claw[1]]), Art.OUTLINE, 1.6, true)
	c.draw_line(knee + side * 1.4, foot + side * 0.2, color.lightened(0.28), 1.0, true)
	# Servo am Knie.
	var mid := hip.lerp(knee, 0.55)
	var along := (knee - hip).normalized()
	Art.bar(c, mid - along * 2.8, mid + along * 2.8, 3.4, Color(0.95, 0.5, 0.15), false)
	Art.disc(c, knee, 2.8, Color(0.62, 0.65, 0.74))


static func _hexapod(c: CanvasItem, s: Dictionary) -> void:
	var t: float = s.t
	var accent: Color = s.accent
	var planted: bool = s.planted
	var clinging: bool = s.clinging
	Art.shadow(c, Vector2(0, 23), 28.0, 3.5)

	var speed_factor := clampf(absf(float(s.vx)) / 300.0, 0.0, 1.0)
	var cling_side := float(s.cling_dir) * float(s.facing)
	# Sechs Beine, erst die fernen (dunkler), dann die nahen. Vorn greifen sie nach vorn,
	# hinten nach hinten, die mittleren stehen seitlich und wirken kuerzer.
	var knee_reach := [-19.0, 16.0, 19.0]
	var knee_rise := [14.0, 17.0, 14.0]
	var foot_reach := [-12.0, 7.0, 12.0]
	for layer in 2:
		var far := layer == 0
		for i in 3:
			var hip := Vector2(-13.0 + i * 13.0 + (3.0 if far else 0.0), 1.0)
			var side := -1.0 if i == 0 else (1.0 if i == 2 else (-1.0 if far else 1.0))
			var kx := absf(float(knee_reach[i])) * side
			var fx := absf(float(foot_reach[i])) * side
			var knee := hip + Vector2(kx, -float(knee_rise[i]))
			var foot := Vector2(knee.x + fx, 23.0)
			var color := Color(0.14, 0.15, 0.2) if far else Color(0.24, 0.25, 0.32)
			if clinging:
				var wall_foot := Vector2(cling_side * 31.0, -10.0 + i * 14.0 + (4.0 if far else 0.0))
				var wall_knee := hip + (wall_foot - hip) * 0.5 + Vector2(-cling_side * 7.0, -9.0)
				_spider_leg(c, hip, wall_knee, wall_foot, color)
				continue
			if not bool(s.grounded):
				knee = hip + Vector2(kx * 0.8, -float(knee_rise[i]) - 2.0)
				foot = Vector2(knee.x + fx * 0.5, 17.0)
			elif planted:
				knee.x += side * 4.0
				foot.x += side * 7.0
			else:
				# Dreibeingang: nahe und ferne Beine wechseln sich ab, kleine ruhige Schritte.
				var phase := float(s.walk) * 0.35 + (PI if (i % 2 == 0) != far else 0.0)
				var swing := sin(phase) * 7.0 * speed_factor
				var lift := maxf(0.0, cos(phase)) * 7.0 * speed_factor
				foot += Vector2(swing, -lift)
				knee += Vector2(swing * 0.5, -lift * 0.9)
			_spider_leg(c, hip, knee, foot, color)

	# Rumpf: flache, dunkle Panzerschale mit Sensorkopf.
	var shell := PackedVector2Array([Vector2(-23, -1), Vector2(-17, -11), Vector2(13, -13), Vector2(23, -4), Vector2(19, 6), Vector2(-19, 6)])
	c.draw_colored_polygon(shell, Color(0.17, 0.18, 0.23))
	c.draw_polyline(shell + PackedVector2Array([shell[0]]), Art.OUTLINE, 2.0, true)
	c.draw_line(Vector2(-15, -10), Vector2(11, -12), Color(1, 1, 1, 0.3), 1.8, true)
	c.draw_line(Vector2(-18, 3), Vector2(17, 3), accent, 2.0, true)
	Art.rivet(c, Vector2(-17, -2))
	Art.rivet(c, Vector2(18, 0))
	# Antenne.
	c.draw_line(Vector2(-16, -10), Vector2(-19, -27), Color(0.6, 0.62, 0.7), 1.2, true)
	Art.led(c, Vector2(-19, -27), 1.5, Color(1.0, 0.3, 0.25), fmod(t, 1.2) < 0.6)
	var la := _local_aim(s)
	Art.face(c, Vector2(8, -5), Vector2(17, 9), s.eye_color, la, s.mood, t)

	# Geschuetzkopf oben auf dem Rumpf, Rohr zeigt in Zielrichtung.
	var pivot := Vector2(2, -17)
	Art.panel(c, Rect2(-8, -23, 18, 10), Color(0.2, 0.21, 0.27), 3.0)
	Art.led(c, Vector2(-3, -19), 1.5, Color(1.0, 0.3, 0.25), planted)
	var tip := pivot + la * 22.0
	Art.bar(c, pivot, tip, 5.0, Color(0.45, 0.48, 0.58))
	var side_vec := la.orthogonal()
	c.draw_line(tip - la * 5.0 + side_vec * 3.5, tip - la * 5.0 - side_vec * 3.5, Color(0.85, 0.87, 0.95), 2.5, true)
	if float(s.firing) > 0.0:
		Art.glow(c, tip, 10.0 + 8.0 * float(s.firing), s.weapon_color)


# ---------------------------------------------------------------- Automat

static func hull_clockwise(points: PackedVector2Array) -> bool:
	var area := 0.0
	for k in points.size():
		var p := points[k]
		var q := points[(k + 1) % points.size()]
		area += p.x * q.y - q.x * p.y
	return area > 0.0


static func _vending(c: CanvasItem, s: Dictionary) -> void:
	var t: float = s.t
	var accent: Color = s.accent
	var charge: float = s.charge
	var firing: float = s.firing
	Art.shadow(c, Vector2(0, 54), 38.0, 4.0)
	# Schrank.
	var green := Color(0.24, 0.36, 0.36)
	Art.panel(c, Rect2(-31, -54, 62, 92), green, 7.0)
	Art.rrect(c, Rect2(-31, -54, 62, 12), Color(0.95, 0.95, 0.9), 6.0)
	Art.rrect_line(c, Rect2(-31, -54, 62, 12), Art.OUTLINE, 6.0, 2.0)
	# Blitz-Logo der erfundenen Marke.
	c.draw_colored_polygon(PackedVector2Array([Vector2(-6, -52), Vector2(4, -52), Vector2(-1, -47), Vector2(5, -47), Vector2(-7, -40), Vector2(-3, -46), Vector2(-8, -46)]), Color(0.85, 0.72, 0.4))
	Art.led(c, Vector2(22, -48), 2.0, accent)
	Art.led(c, Vector2(-24, -48), 2.0, Color(0.85, 0.4, 0.35), fmod(t, 1.6) < 0.8)

	# Glasfront mit Dosen, beim Schuetteln wackeln sie.
	var glass := Rect2(-25, -37, 34, 56)
	Art.rrect(c, glass, Color(0.05, 0.12, 0.16), 3.0)
	var can_colors := [Color(0.62, 0.66, 0.72), Color(0.46, 0.5, 0.58), Color(0.62, 0.66, 0.72), Color(0.78, 0.6, 0.35)]
	for row in 5:
		for col in 3:
			var can_color: Color = can_colors[(row + col * 2) % 4]
			var wobble := Vector2(sin(t * 70.0 + row * 2.0 + col), cos(t * 63.0 + col)) * charge * 1.4
			var pos := Vector2(-22.0 + col * 10.5, -34.0 + row * 10.5) + wobble
			Art.rrect(c, Rect2(pos, Vector2(8, 9)), can_color, 2.0)
			c.draw_line(pos + Vector2(0, 2), pos + Vector2(8, 2), Color(1, 1, 1, 0.5), 1.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-25, -37), Vector2(-10, -37), Vector2(-25, -12)]), Color(1, 1, 1, 0.1))
	Art.rrect_line(c, glass, Color(0.6, 0.65, 0.75), 3.0, 2.0)

	# Bedienfeld rechts: Gesicht, Tasten, Muenzschlitz.
	var la := _local_aim(s)
	Art.face(c, Vector2(20, -30), Vector2(15, 13), s.eye_color, la, s.mood, t)
	for row in 3:
		for col in 2:
			Art.disc(c, Vector2(16.0 + col * 7.0, -16.0 + row * 7.0), 2.1, Color(0.82, 0.84, 0.9) if (row + col) % 2 == 0 else Color(0.62, 0.66, 0.74))
	Art.rrect(c, Rect2(15, 8, 10, 3), Color(0.05, 0.08, 0.1), 1.5)
	Art.rivet(c, Vector2(-28, -38))
	Art.rivet(c, Vector2(28, -38))
	Art.rivet(c, Vector2(-28, 33))
	Art.rivet(c, Vector2(28, 33))

	# Dreieckiges Raupenlaufwerk wie bei Schneefahrzeugen: abgerundetes Dreieck mit flacher
	# Auflage, Rollen an den Ecken und umlaufenden Stollen.
	var spin := float(s.walk) * 0.5
	var corners := [Vector2(-27, 47.5), Vector2(27, 47.5), Vector2(14, 36.0)]
	var radii := [7.0, 7.0, 5.0]
	var hull_source := PackedVector2Array()
	for k in 3:
		for step in 16:
			var angle := TAU * float(step) / 16.0
			hull_source.append(Vector2(corners[k]) + Vector2(cos(angle), sin(angle)) * float(radii[k]))
	var hull := Geometry2D.convex_hull(hull_source)
	c.draw_colored_polygon(hull, Color(0.12, 0.13, 0.16))
	var closed := PackedVector2Array(hull)
	closed.append(hull[0])
	c.draw_polyline(closed, Color(0.3, 0.32, 0.38), 3.5, true)
	c.draw_polyline(closed, Art.OUTLINE, 1.2, true)
	# Stollen laufen am Umfang entlang.
	var perimeter := 0.0
	for k in hull.size():
		perimeter += hull[k].distance_to(hull[(k + 1) % hull.size()])
	var spacing := 6.0
	var distance := fposmod(-spin * 5.0, spacing)
	var walked := 0.0
	for k in hull.size():
		var from := hull[k]
		var to := hull[(k + 1) % hull.size()]
		var edge := to - from
		var length := edge.length()
		if length < 0.01:
			continue
		var along := edge / length
		var outward := -along.orthogonal() if hull_clockwise(hull) else along.orthogonal()
		while distance < walked + length:
			var point := from + along * (distance - walked)
			c.draw_line(point, point + outward * 2.6, Color(0.5, 0.52, 0.6), 1.4)
			distance += spacing
		walked += length
	# Rollen an den Ecken und eine Mittelachse mit Federbein.
	for k in 3:
		var center: Vector2 = corners[k]
		Art.disc(c, center, float(radii[k]) - 2.0, Color(0.55, 0.58, 0.66))
		for m in 3:
			var a := spin + m * TAU / 3.0
			c.draw_line(center, center + Vector2(cos(a), sin(a)) * (float(radii[k]) - 3.0), Color(0.2, 0.22, 0.28), 1.4, true)
		Art.disc(c, center, 1.4, Color(0.2, 0.22, 0.28))
	Art.bar(c, Vector2(-8, 45.0), Vector2(14, 41.5), 3.0, Color(0.4, 0.42, 0.5), false)

	# Ausgabefach unten: hier kommen die Dosen heraus. Die Klappe schwingt beim Wurf auf.
	var slot := Rect2(-25, 24, 34, 11)
	Art.rrect(c, slot, Color(0.03, 0.05, 0.07), 3.0)
	var can_color: Color = s.weapon_color
	if charge > 0.0:
		# Die Dose steckt halb im Fach und schaeumt.
		var shake := Vector2(sin(t * 90.0), cos(t * 77.0)) * charge * 1.2
		Art.rrect(c, Rect2(Vector2(-14, 25) + shake, Vector2(12, 9)), can_color.lerp(Color.WHITE, charge * 0.5), 2.0)
		Art.glow(c, Vector2(-8, 30), 10.0 + 12.0 * charge, Color(1, 1, 1))
		for i in 5:
			var a := t * 11.0 + i * 1.3
			c.draw_circle(Vector2(-8, 28) + Vector2(cos(a) * (4.0 + 6.0 * charge), -absf(sin(a)) * (3.0 + 8.0 * charge)), 1.4 + charge * 1.2, Color(1, 1, 1, 0.8))
	# Klappe: geschlossen deckt sie das Fach, beim Wurf klappt sie nach oben weg (von vorn gesehen
	# wird sie dabei flach) und gibt den Blick auf die Dose frei.
	var open := clampf(maxf(firing * 1.4, charge * 0.7), 0.0, 1.0)
	var flap_height := lerpf(11.0, 2.5, open)
	var flap_rect := Rect2(Vector2(-25, 24), Vector2(34, flap_height))
	Art.panel(c, flap_rect, Color(0.66, 0.7, 0.8), 2.0)
	c.draw_line(Vector2(-23, 25.5), Vector2(7, 25.5), Color(1, 1, 1, 0.45), 1.5)
	if firing > 0.3:
		Art.glow(c, Vector2(-8, 30), 14.0 * firing, can_color)


# ---------------------------------------------------------------- Drucker

## Breite der Drohne pro Schicht von unten nach oben (Kufen, Rumpf, Mast, Rotorarme).
const DRONE_LAYERS := [10.0, 10.0, 16.0, 19.0, 20.0, 20.0, 19.0, 16.0, 7.0, 7.0, 26.0, 26.0, 5.0]


## Zeichnet die gedruckte Drohne bis zur aktuellen Schicht. Beim Start (launch 0..1)
## hebt sie ab und steigt aus der geoeffneten Tuer.
static func _print_drone(c: CanvasItem, base: Vector2, progress: float, t: float, launch: float) -> void:
	var layer_height := 1.9
	var total := DRONE_LAYERS.size()
	var done := progress * total
	var lift := 0.0
	if launch >= 0.0:
		lift = launch * launch * 34.0
	for k in total:
		if float(k) >= done:
			break
		var width: float = DRONE_LAYERS[k]
		var y := base.y - (k + 1) * layer_height - lift
		var shade := 0.0 if k % 2 == 0 else 0.1
		var color := Color(0.95, 0.56 + shade, 0.2)
		c.draw_rect(Rect2(base.x - width * 0.5, y, width, layer_height), color)
		c.draw_line(Vector2(base.x - width * 0.5, y), Vector2(base.x + width * 0.5, y), Color(1.0, 0.85, 0.6, 0.7), 0.8)
	if launch >= 0.0:
		# Rotoren drehen beim Abheben.
		var rotor_y := base.y - 11.5 * layer_height - lift
		Art.ellipse(c, Vector2(base.x - 10.0, rotor_y - 1.0), 6.0, 1.5, Color(0.9, 0.93, 1.0, 0.6))
		Art.ellipse(c, Vector2(base.x + 10.0, rotor_y - 1.0), 6.0, 1.5, Color(0.9, 0.93, 1.0, 0.6))
		return
	if progress >= 1.0:
		return
	# Portal und Druckkopf an der aktuellen Schicht.
	var top_y := base.y - done * layer_height
	var head_x := base.x + sin(t * 6.0) * 9.0
	c.draw_line(Vector2(base.x - 17.0, top_y - 4.0), Vector2(base.x + 17.0, top_y - 4.0), Color(0.55, 0.58, 0.68), 1.6)
	Art.rrect(c, Rect2(head_x - 3.0, top_y - 8.0, 6.0, 5.0), Color(0.85, 0.87, 0.95), 1.0)
	c.draw_line(Vector2(head_x, top_y - 3.0), Vector2(head_x, top_y), Color(1.0, 0.55, 0.15), 1.4)
	Art.glow(c, Vector2(head_x, top_y), 3.5, Color(1.0, 0.55, 0.15))


static func _printer(c: CanvasItem, s: Dictionary) -> void:
	var t: float = s.t
	var accent: Color = s.accent
	# Alles liegt um zehn Pixel nach oben verschoben, darunter laufen die gedruckten Beine.
	var shift := Vector2(0, -10)
	var speed_factor := clampf(absf(float(s.vx)) / 300.0, 0.0, 1.0)
	Art.shadow(c, Vector2(0, 37), 26.0, 3.5)

	# Zwei selbst gedruckte Beine: sichtbare Schichtlinien, verschiedene Filamentfarben, plumpe Fuesse.
	for i in 2:
		var hip := Vector2(-14.0 + i * 28.0, 12.0)
		var phase := float(s.walk) * 0.5 + (PI if i == 1 else 0.0)
		var foot := Vector2(hip.x + sin(phase) * 11.0 * speed_factor, 37.0 - maxf(0.0, cos(phase)) * 8.0 * speed_factor)
		if not bool(s.grounded):
			foot = Vector2(hip.x, 28.0)
		var leg_color := Color(0.95, 0.5, 0.12) if i == 0 else Color(0.9, 0.92, 0.97)
		var joint := Art.limb(c, hip, foot, 13.0, 13.0, 7.0, leg_color, 1.0, leg_color.darkened(0.15))
		# Schichtlinien quer zu den Segmenten (so sieht man, dass die Beine gedruckt sind).
		var knee := hip + (foot - hip) * 0.5
		for k in 5:
			var f := float(k + 1) / 6.0
			var p1 := hip.lerp(knee, f)
			c.draw_line(p1 + Vector2(-3.5, 0), p1 + Vector2(3.5, 0), Color(0, 0, 0, 0.18), 1.0)
			var p2 := knee.lerp(foot, f)
			c.draw_line(p2 + Vector2(-3.0, 0), p2 + Vector2(3.0, 0), Color(0, 0, 0, 0.18), 1.0)
		Art.panel(c, Rect2(joint + Vector2(-6, -2), Vector2(13, 5)), leg_color.darkened(0.1), 2.5)

	# Gehaeuse.
	Art.panel(c, Rect2(-29 + shift.x, -27 + shift.y, 58, 52), Color(0.2, 0.21, 0.27), 7.0)
	Art.rrect(c, Rect2(15, -23 + shift.y, 12, 44), Color(0.95, 0.5, 0.12), 5.0)
	Art.rrect_line(c, Rect2(15, -23 + shift.y, 12, 44), Art.OUTLINE, 5.0, 1.5)
	Art.disc(c, Vector2(21, 14 + shift.y), 3.0, Color(0.15, 0.15, 0.2))
	Art.rrect(c, Rect2(-29, -27 + shift.y, 58, 5), Color(0.1, 0.1, 0.14), 3.0)
	Art.rrect(c, Rect2(-25, 20 + shift.y, 36, 2.5), accent, 1.0)
	# Filamentspule an der Rueckseite.
	Art.disc(c, Vector2(-30, -8 + shift.y), 9.0, Color(0.95, 0.5, 0.12))
	Art.disc(c, Vector2(-30, -8 + shift.y), 3.5, Color(0.15, 0.15, 0.2))
	c.draw_arc(Vector2(-30, -8 + shift.y), 6.5, 0.0, TAU, 16, Color(1, 1, 1, 0.3), 1.0, true)
	# Druckkammer: Eine Drohne wird Schicht fuer Schicht gedruckt. Ist sie fertig und wird
	# die Faehigkeit benutzt, geht die Tuer auf und die Drohne fliegt hinaus.
	var window := Rect2(-24, -17 + shift.y, 36, 33)
	Art.rrect(c, window, Color(0.04, 0.07, 0.1), 3.0)
	var bed_y := 11.0 + shift.y
	Art.rrect(c, Rect2(-21, bed_y, 30, 3), Color(0.6, 0.63, 0.72), 1.0)
	var progress := clampf(float(s.get("print", 0.6)), 0.0, 1.0)
	var launch := float(s.get("launch", -1.0))
	var door := 0.0
	if launch >= 0.0:
		progress = 1.0
		door = clampf(sin(launch * PI) * 1.6, 0.0, 1.0)
	_print_drone(c, Vector2(-6, bed_y), progress, t, launch)
	# Glas oder offene Tuer: geschlossen spiegelt das Glas, offen klappt das Blech nach oben weg.
	if door < 0.98:
		var glass_height := window.size.y * (1.0 - door)
		var glass := Rect2(window.position, Vector2(window.size.x, glass_height))
		c.draw_colored_polygon(PackedVector2Array([glass.position, glass.position + Vector2(16, 0), glass.position + Vector2(0, minf(glass_height, 17.0))]), Color(1, 1, 1, 0.1))
		if door > 0.02:
			Art.rrect(c, Rect2(window.position, Vector2(window.size.x, maxf(glass_height, 3.0))), Color(0.66, 0.7, 0.8, 0.9), 2.0)
	Art.rrect_line(c, window, Color(0.6, 0.65, 0.75), 3.0, 2.0)
	if progress >= 1.0 and launch < 0.0:
		Art.led(c, Vector2(-6, -21 + shift.y), 1.8, Color(0.4, 1.0, 0.5), fmod(t, 0.8) < 0.5)
	var la := _local_aim(s)
	Art.face(c, Vector2(21, -13 + shift.y), Vector2(11, 11), s.eye_color, la, s.mood, t)
	var pivot := Vector2(0, -40)
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
		"charger":
			_charger(c, s)
		"mortar":
			_mortar(c, s)
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


static func _charger(c: CanvasItem, s: Dictionary) -> void:
	var t: float = s.t
	var windup: float = s.windup
	var charging: bool = s.slam
	var body := _tint(Color(0.9, 0.5, 0.15), s)
	var dark := _tint(Color(0.25, 0.2, 0.2), s)
	# Beim Anlauf duckt er sich nach hinten, beim Ansturm lehnt er nach vorn.
	var lean := -windup * 3.0 if windup >= 0.0 else (3.0 if charging else 0.0)
	var shake := Vector2(randf_range(-1.0, 1.0), 0.0) * windup * 1.2 if windup >= 0.0 else Vector2.ZERO
	var base := Vector2(lean, 0.0) + shake
	Art.shadow(c, Vector2(0, 19), 20.0, 3.0, 0.35)
	if charging:
		for i in 3:
			c.draw_line(Vector2(-22 - i * 8, -6 + i * 6), Vector2(-40 - i * 8, -6 + i * 6), Color(1.0, 0.8, 0.5, 0.5 - i * 0.12), 2.5, true)
	# Raeder.
	var spin := float(s.walk) * 1.2 + (t * 20.0 if charging else 0.0)
	for x in [-11.0, 11.0]:
		Art.disc(c, base + Vector2(x, 11), 8.5, dark)
		for i in 3:
			var a := spin + i * TAU / 3.0
			c.draw_line(base + Vector2(x, 11), base + Vector2(x, 11) + Vector2(cos(a), sin(a)) * 7.0, Color(0.65, 0.55, 0.5), 1.8, true)
	# Rumpf mit Warnstreifen.
	Art.panel(c, Rect2(base + Vector2(-19, -12), Vector2(36, 22)), body, 6.0)
	for i in 4:
		var x := -16.0 + i * 8.0
		c.draw_colored_polygon(PackedVector2Array([base + Vector2(x, 4), base + Vector2(x + 4, 4), base + Vector2(x + 7, 8), base + Vector2(x + 3, 8)]), _tint(Color(0.1, 0.1, 0.13), s))
	Art.rivet(c, base + Vector2(-15, -8))
	# Rammschild vorn.
	var plow := PackedVector2Array([base + Vector2(17, -14), base + Vector2(30, -2), base + Vector2(30, 12), base + Vector2(17, 10)])
	c.draw_colored_polygon(plow, _tint(Color(0.55, 0.57, 0.66), s))
	c.draw_polyline(PackedVector2Array([plow[0], plow[1], plow[2], plow[3], plow[0]]), Art.OUTLINE, 1.5, true)
	c.draw_line(base + Vector2(19, -8), base + Vector2(28, 0), Color(1.0, 0.75, 0.1), 3.0, true)
	c.draw_line(base + Vector2(19, 0), base + Vector2(28, 8), Color(1.0, 0.75, 0.1), 3.0, true)
	# Kopf mit Gesicht.
	Art.panel(c, Rect2(base + Vector2(-7, -23), Vector2(20, 12)), _tint(Color(0.35, 0.36, 0.45), s), 4.0)
	var look := Vector2(float(s.aim.x) * float(s.facing), float(s.aim.y))
	Art.face(c, base + Vector2(3, -17), Vector2(15, 7), Color(1.0, 0.2, 0.15), look, "angry", t)
	# Auspuff.
	Art.rrect(c, Rect2(base + Vector2(-17, -20), Vector2(5, 9)), dark, 2.0)
	for k in 2:
		var life := fposmod(t * 1.5 + k * 0.5, 1.0)
		c.draw_circle(base + Vector2(-15 - life * 6.0, -22 - life * 12.0), 2.0 + life * 3.5, Color(0.6, 0.6, 0.66, 0.3 * (1.0 - life)))
	if windup >= 0.0:
		Art.glow(c, base + Vector2(8, -4), 26.0 + 10.0 * windup, Color(1.0, 0.3, 0.2))


static func _mortar(c: CanvasItem, s: Dictionary) -> void:
	var t: float = s.t
	var windup: float = s.windup
	var body := _tint(Color(0.3, 0.7, 0.6), s)
	var dark := _tint(Color(0.2, 0.25, 0.28), s)
	Art.shadow(c, Vector2(0, 17), 18.0, 2.8, 0.3)
	# Kettenlaufwerk.
	Art.panel(c, Rect2(-17, 7, 34, 10), dark, 5.0)
	for i in 5:
		var x := -13.0 + i * 6.5
		Art.disc(c, Vector2(x, 12), 2.4, _tint(Color(0.55, 0.6, 0.65), s), Art.OUTLINE)
	# Rohr: neigt sich nach oben und rueckt beim Abschuss zurueck.
	var angle := -1.15
	var recoil := 0.0
	if windup >= 0.0:
		recoil = -4.0 * sin(windup * PI)
	var dir := Vector2(cos(angle), sin(angle))
	var pivot := Vector2(4, -3)
	var tip := pivot + dir * (24.0 + recoil)
	Art.bar(c, pivot, tip, 8.0, _tint(Color(0.38, 0.4, 0.5), s))
	Art.bar(c, tip - dir * 4.0, tip, 10.0, dark)
	if windup >= 0.0:
		Art.glow(c, tip, 10.0 + 12.0 * windup, Color(1.0, 0.55, 0.25))
	# Rumpf mit Kopf.
	Art.panel(c, Rect2(-14, -9, 26, 17), body, 6.0)
	Art.rrect(c, Rect2(-14, 1, 26, 3), _tint(Color(1.0, 0.65, 0.15), s), 1.0)
	Art.panel(c, Rect2(-13, -18, 17, 10), _tint(Color(0.35, 0.36, 0.45), s), 4.0)
	var look := Vector2(float(s.aim.x) * float(s.facing), float(s.aim.y))
	Art.face(c, Vector2(-4, -13), Vector2(13, 6), Color(1.0, 0.2, 0.15), look, "angry", t)
	c.draw_line(Vector2(-10, -18), Vector2(-12, -23), Color(0.6, 0.6, 0.7), 1.5, true)
	Art.led(c, Vector2(-12, -23), 1.3, Color(1.0, 0.3, 0.2), fmod(t, 1.0) < 0.5)


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
