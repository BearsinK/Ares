class_name PerkArt
extends RefCounted
## Kleine Symbole fuer Perks, im Code gezeichnet. Alle Symbole liegen in einem
## Quadrat der Kantenlaenge size um die Mitte center.

const COLORS := {
	"overclock": Color(1.0, 0.85, 0.25),
	"oilchange": Color(0.95, 0.65, 0.2),
	"grease": Color(0.4, 0.85, 1.0),
	"coolant": Color(0.55, 0.8, 1.0),
	"magnet": Color(1.0, 0.4, 0.4),
	"piggy": Color(1.0, 0.82, 0.3),
	"plating": Color(0.7, 0.78, 0.9),
	"sharpchip": Color(0.5, 1.0, 0.6),
	"chillloop": Color(0.4, 0.95, 0.9),
	"luckychip": Color(0.8, 0.55, 1.0),
	"scavenger": Color(0.5, 1.0, 0.55),
	"piercer": Color(1.0, 0.6, 0.35),
	"boomchip": Color(1.0, 0.5, 0.25),
	"cablelink": Color(0.55, 0.85, 1.0),
	"frenzy": Color(1.0, 0.55, 0.2),
	"arccoil": Color(0.95, 0.9, 0.35),
	"dashblast": Color(0.5, 0.9, 1.0),
	"thorns": Color(1.0, 0.45, 0.4),
	"laststand": Color(1.0, 0.3, 0.35),
	"shieldcell": Color(0.45, 0.8, 1.0),
	"recycler": Color(0.5, 1.0, 0.6),
	"executioner": Color(1.0, 0.35, 0.5),
	"closequarters": Color(1.0, 0.7, 0.35),
	"longshot": Color(0.75, 0.6, 1.0),
	"extmag": Color(1.0, 0.8, 0.35),
	"speedloader": Color(0.5, 1.0, 0.8),
	"splitter": Color(1.0, 0.55, 0.75),
	"velocoil": Color(0.45, 0.85, 1.0),
	"longbarrel": Color(0.75, 0.8, 1.0),
	"stabilizer": Color(0.6, 1.0, 0.6),
	"blastcore": Color(1.0, 0.55, 0.2),
	"killshot": Color(1.0, 0.3, 0.35),
	"ecochip": Color(0.55, 0.95, 0.45),
	"heavyslugs": Color(0.9, 0.75, 0.55),
	"ricochet": Color(0.4, 1.0, 0.85),
	"seeker": Color(1.0, 0.4, 0.9),
}


static func color_of(perk_id: String) -> Color:
	return COLORS.get(perk_id, Color(0.8, 0.8, 0.9))


static func draw(c: CanvasItem, perk_id: String, center: Vector2, size: float) -> void:
	var color := color_of(perk_id)
	var u := size / 2.0
	Art.glow(c, center, u * 1.5, color)
	Art.disc(c, center, u * 1.05, Color(0.1, 0.11, 0.17), Color(color, 0.8))
	var k := u * 0.62
	match perk_id:
		"overclock":
			_poly(c, center, k, [Vector2(0.15, -1), Vector2(-0.55, 0.1), Vector2(-0.05, 0.1), Vector2(-0.2, 1), Vector2(0.55, -0.15), Vector2(0.05, -0.15)], color)
		"oilchange":
			_poly(c, center, k, [Vector2(0, -1), Vector2(0.62, 0.2), Vector2(0.5, 0.65), Vector2(0, 1), Vector2(-0.5, 0.65), Vector2(-0.62, 0.2)], color)
			c.draw_circle(center + Vector2(-0.2, 0.3) * k, k * 0.14, Color(1, 1, 1, 0.6))
		"grease":
			for i in 2:
				var x := (i - 0.5) * 0.9
				_line(c, center, k, [Vector2(x - 0.4, -0.7), Vector2(x + 0.15, 0), Vector2(x - 0.4, 0.7)], color, 3.5)
		"coolant":
			for i in 3:
				var a := PI * i / 3.0
				c.draw_line(center - Vector2(cos(a), sin(a)) * k, center + Vector2(cos(a), sin(a)) * k, color, 3.0, true)
			c.draw_circle(center, k * 0.22, color)
		"magnet":
			c.draw_arc(center + Vector2(0, -0.1 * k), k * 0.7, PI, TAU, 16, color, 6.0, true)
			c.draw_line(center + Vector2(-0.7, -0.1) * k, center + Vector2(-0.7, 0.8) * k, color, 6.0)
			c.draw_line(center + Vector2(0.7, -0.1) * k, center + Vector2(0.7, 0.8) * k, color, 6.0)
			c.draw_rect(Rect2(center + Vector2(-0.95, 0.5) * k, Vector2(0.5, 0.35) * k), Color.WHITE)
			c.draw_rect(Rect2(center + Vector2(0.45, 0.5) * k, Vector2(0.5, 0.35) * k), Color.WHITE)
		"piggy":
			for i in 3:
				var y := (0.55 - i * 0.5) * k
				Art.ellipse(c, center + Vector2(0, y), k * 0.8, k * 0.28, color)
				Art.ellipse(c, center + Vector2(0, y - 2), k * 0.8, k * 0.2, color.lightened(0.25))
		"plating":
			_poly(c, center, k, [Vector2(0, -1), Vector2(0.85, -0.6), Vector2(0.7, 0.35), Vector2(0, 1), Vector2(-0.7, 0.35), Vector2(-0.85, -0.6)], color)
			_line(c, center, k, [Vector2(0, -0.6), Vector2(0, 0.6)], Color(0.1, 0.11, 0.17, 0.6), 3.0)
		"sharpchip":
			c.draw_rect(Rect2(center - Vector2(0.6, 0.6) * k, Vector2(1.2, 1.2) * k), color)
			for i in 3:
				var p := (-0.4 + i * 0.4) * k
				c.draw_line(center + Vector2(p, -0.6 * k), center + Vector2(p, -1.0 * k), color, 2.5)
				c.draw_line(center + Vector2(p, 0.6 * k), center + Vector2(p, 1.0 * k), color, 2.5)
				c.draw_line(center + Vector2(-0.6 * k, p), center + Vector2(-1.0 * k, p), color, 2.5)
				c.draw_line(center + Vector2(0.6 * k, p), center + Vector2(1.0 * k, p), color, 2.5)
			c.draw_rect(Rect2(center - Vector2(0.28, 0.28) * k, Vector2(0.56, 0.56) * k), Color(0.1, 0.11, 0.17))
		"chillloop":
			c.draw_arc(center, k * 0.75, 0.4, TAU - 0.5, 24, color, 4.0, true)
			_poly(c, center, k, [Vector2(0.55, -0.25), Vector2(1.0, -0.25), Vector2(0.8, 0.25)], color)
		"luckychip":
			c.draw_rect(Rect2(center - Vector2(0.7, 0.7) * k, Vector2(1.4, 1.4) * k), color)
			for pip in [Vector2(-0.35, -0.35), Vector2(0.35, 0.35), Vector2(0.35, -0.35), Vector2(-0.35, 0.35), Vector2(0, 0)]:
				c.draw_circle(center + pip * k, k * 0.14, Color(0.1, 0.11, 0.17))
		"scavenger":
			c.draw_rect(Rect2(center - Vector2(0.6, 0.55) * k, Vector2(1.2, 1.3) * k), color)
			c.draw_rect(Rect2(center + Vector2(-0.25, -0.8) * k, Vector2(0.5, 0.25) * k), color)
			c.draw_line(center + Vector2(-0.3, 0.1) * k, center + Vector2(0.3, 0.1) * k, Color(0.1, 0.11, 0.17), 3.0)
			c.draw_line(center + Vector2(0, -0.2) * k, center + Vector2(0, 0.4) * k, Color(0.1, 0.11, 0.17), 3.0)
		"piercer":
			c.draw_line(center + Vector2(-1.0, 0) * k, center + Vector2(0.7, 0) * k, color, 4.0, true)
			_poly(c, center, k, [Vector2(0.55, -0.4), Vector2(1.05, 0), Vector2(0.55, 0.4)], color)
			c.draw_line(center + Vector2(-0.1, -0.7) * k, center + Vector2(-0.1, 0.7) * k, Color(1, 1, 1, 0.6), 2.0)
			c.draw_line(center + Vector2(0.25, -0.7) * k, center + Vector2(0.25, 0.7) * k, Color(1, 1, 1, 0.6), 2.0)
		"boomchip":
			c.draw_circle(center + Vector2(-0.1, 0.2) * k, k * 0.7, color)
			c.draw_line(center + Vector2(0.3, -0.3) * k, center + Vector2(0.65, -0.75) * k, Color(0.8, 0.8, 0.85), 3.0)
			Art.led(c, center + Vector2(0.75, -0.85) * k, k * 0.2, Color(1.0, 0.9, 0.4))
		"cablelink":
			# Zwei Stecker, durch ein Kabel verbunden.
			c.draw_arc(center + Vector2(0, 0.2 * k), k * 0.65, 0.2, PI - 0.2, 16, color, 3.0, true)
			for side in [-1.0, 1.0]:
				c.draw_rect(Rect2(center + Vector2(side * 0.65 * k - 0.22 * k, -0.7 * k), Vector2(0.44, 0.6) * k), color)
				c.draw_line(center + Vector2(side * 0.65 * k - 0.12 * k, -0.95 * k), center + Vector2(side * 0.65 * k - 0.12 * k, -0.7 * k), Color(1, 1, 1, 0.8), 2.0)
				c.draw_line(center + Vector2(side * 0.65 * k + 0.12 * k, -0.95 * k), center + Vector2(side * 0.65 * k + 0.12 * k, -0.7 * k), Color(1, 1, 1, 0.8), 2.0)
		"frenzy":
			_poly(c, center, k, [Vector2(0, -1), Vector2(0.55, -0.25), Vector2(0.4, 0.05), Vector2(0.7, 0.35), Vector2(0.35, 1), Vector2(-0.45, 1), Vector2(-0.75, 0.35), Vector2(-0.35, -0.1), Vector2(-0.5, -0.45), Vector2(-0.15, -0.35)], color)
			_poly(c, center, k, [Vector2(0, 0.1), Vector2(0.25, 0.55), Vector2(0, 0.9), Vector2(-0.25, 0.55)], Color(1.0, 0.95, 0.6))
		"arccoil":
			_line(c, center, k, [Vector2(0.2, -1), Vector2(-0.35, -0.05), Vector2(0.3, -0.05), Vector2(-0.25, 1)], color, 4.0)
			c.draw_circle(center + Vector2(0.65, 0.65) * k, k * 0.16, color)
			c.draw_circle(center + Vector2(-0.7, -0.65) * k, k * 0.16, color)
		"dashblast":
			for i in 8:
				var a := TAU * i / 8.0
				c.draw_line(center + Vector2(cos(a), sin(a)) * k * 0.35, center + Vector2(cos(a), sin(a)) * k * (0.95 if i % 2 == 0 else 0.7), color, 3.0, true)
			c.draw_circle(center, k * 0.28, Color(1, 1, 1, 0.9))
		"thorns":
			c.draw_circle(center, k * 0.5, color)
			for i in 8:
				var a := TAU * i / 8.0 + 0.2
				_poly(c, center, k, [Vector2(cos(a - 0.22), sin(a - 0.22)) * 0.5, Vector2(cos(a), sin(a)) * 1.0, Vector2(cos(a + 0.22), sin(a + 0.22)) * 0.5], color)
		"laststand":
			_poly(c, center, k, [Vector2(0, 0.95), Vector2(-0.95, -0.05), Vector2(-0.8, -0.6), Vector2(-0.35, -0.8), Vector2(0, -0.45), Vector2(0.35, -0.8), Vector2(0.8, -0.6), Vector2(0.95, -0.05)], color)
			_line(c, center, k, [Vector2(0.1, -0.5), Vector2(-0.1, -0.05), Vector2(0.15, 0.2), Vector2(-0.05, 0.6)], Color(0.1, 0.11, 0.17), 2.5)
		"shieldcell":
			_poly(c, center, k, [Vector2(0, -1), Vector2(0.8, -0.65), Vector2(0.75, 0.2), Vector2(0, 1), Vector2(-0.75, 0.2), Vector2(-0.8, -0.65)], Color(color, 0.35))
			c.draw_polyline(PackedVector2Array([center + Vector2(0, -1) * k, center + Vector2(0.8, -0.65) * k, center + Vector2(0.75, 0.2) * k, center + Vector2(0, 1) * k, center + Vector2(-0.75, 0.2) * k, center + Vector2(-0.8, -0.65) * k, center + Vector2(0, -1) * k]), color, 3.0, true)
			_line(c, center, k, [Vector2(0.15, -0.5), Vector2(-0.2, 0.05), Vector2(0.15, 0.05), Vector2(-0.1, 0.6)], Color(1, 1, 0.8), 2.5)
		"recycler":
			c.draw_arc(center, k * 0.75, 0.2, PI - 0.3, 16, color, 4.0, true)
			c.draw_arc(center, k * 0.75, PI + 0.2, TAU - 0.3, 16, color, 4.0, true)
			_poly(c, center, k, [Vector2(0.9, 0.0), Vector2(0.5, -0.45), Vector2(0.45, 0.2)], color)
			_poly(c, center, k, [Vector2(-0.9, 0.0), Vector2(-0.5, 0.45), Vector2(-0.45, -0.2)], color)
		"executioner":
			c.draw_arc(center, k * 0.85, 0.0, TAU, 24, color, 3.0, true)
			c.draw_line(center + Vector2(-0.45, -0.45) * k, center + Vector2(0.45, 0.45) * k, color, 4.0, true)
			c.draw_line(center + Vector2(0.45, -0.45) * k, center + Vector2(-0.45, 0.45) * k, color, 4.0, true)
		"closequarters":
			_poly(c, center, k, [Vector2(-1.0, -0.5), Vector2(-0.15, 0.0), Vector2(-1.0, 0.5)], color)
			_poly(c, center, k, [Vector2(1.0, -0.5), Vector2(0.15, 0.0), Vector2(1.0, 0.5)], color)
			c.draw_circle(center, k * 0.14, Color.WHITE)
		"longshot":
			c.draw_line(center + Vector2(-1.0, 0.0) * k, center + Vector2(0.35, 0.0) * k, color, 3.0, true)
			_poly(c, center, k, [Vector2(0.2, -0.3), Vector2(0.6, 0.0), Vector2(0.2, 0.3)], color)
			c.draw_arc(center + Vector2(0.75, 0.0) * k, k * 0.28, 0.0, TAU, 14, color, 2.5, true)
			c.draw_circle(center + Vector2(0.75, 0.0) * k, k * 0.07, color)
		"extmag":
			# Magazin mit drei Patronen oben.
			c.draw_rect(Rect2(center + Vector2(-0.55, -0.1) * k, Vector2(1.1, 1.0) * k), color)
			for i in 3:
				c.draw_rect(Rect2(center + Vector2(-0.45 + i * 0.33, -0.75) * k, Vector2(0.27, 0.6) * k), Color(1, 1, 1, 0.9))
			c.draw_line(center + Vector2(-0.35, 0.3) * k, center + Vector2(0.35, 0.3) * k, Color(0.1, 0.11, 0.17), 2.5)
			c.draw_line(center + Vector2(-0.35, 0.6) * k, center + Vector2(0.35, 0.6) * k, Color(0.1, 0.11, 0.17), 2.5)
		"speedloader":
			# Kreispfeil mit Blitz.
			var end := TAU - 1.0
			c.draw_arc(center, k * 0.8, -0.3, end, 20, color, 4.0, true)
			var tip := Vector2(cos(end), sin(end))
			var along := Vector2(-sin(end), cos(end))
			_poly(c, center, k, [tip * 0.8 + along * 0.4, tip * 0.8 + tip * 0.3, tip * 0.8 - tip * 0.3], color)
			_line(c, center, k, [Vector2(0.15, -0.45), Vector2(-0.15, 0.0), Vector2(0.15, 0.0), Vector2(-0.1, 0.45)], Color(1, 1, 0.8), 2.5)
		"splitter":
			# Ein Lauf, drei Schuesse im Faecher.
			c.draw_line(center + Vector2(-1.0, 0.0) * k, center + Vector2(-0.1, 0.0) * k, color, 4.0, true)
			for dy in [-0.7, 0.0, 0.7]:
				c.draw_line(center + Vector2(-0.1, 0.0) * k, center + Vector2(0.75, dy) * k, color, 3.0, true)
				c.draw_circle(center + Vector2(0.85, dy) * k, k * 0.17, Color.WHITE)
		"velocoil":
			# Geschoss mit Tempostreifen.
			_poly(c, center, k, [Vector2(0.15, -0.4), Vector2(0.65, -0.4), Vector2(1.0, 0.0), Vector2(0.65, 0.4), Vector2(0.15, 0.4)], color)
			for i in 3:
				var y := (-0.55 + i * 0.55) * k
				c.draw_line(center + Vector2(-1.0 + i * 0.12, 0.0) * k + Vector2(0, y), center + Vector2(-0.15, 0.0) * k + Vector2(0, y), Color(color, 0.8), 3.0, true)
		"longbarrel":
			# Langer Lauf mit Visier und Entfernungsstrichen.
			c.draw_rect(Rect2(center + Vector2(-1.0, -0.14) * k, Vector2(1.9, 0.28) * k), color)
			c.draw_rect(Rect2(center + Vector2(-0.4, -0.38) * k, Vector2(0.14, 0.26) * k), color)
			c.draw_rect(Rect2(center + Vector2(0.55, -0.34) * k, Vector2(0.12, 0.22) * k), color)
			for i in 4:
				c.draw_line(center + Vector2(-0.8 + i * 0.5, 0.45) * k, center + Vector2(-0.8 + i * 0.5, 0.75) * k, Color(1, 1, 1, 0.7), 2.0)
		"stabilizer":
			# Fadenkreuz.
			c.draw_arc(center, k * 0.65, 0.0, TAU, 24, color, 3.0, true)
			for a in [0.0, PI / 2.0, PI, PI * 1.5]:
				var dir := Vector2(cos(a), sin(a))
				c.draw_line(center + dir * k * 0.4, center + dir * k * 1.0, color, 3.0, true)
			c.draw_circle(center, k * 0.12, Color.WHITE)
		"blastcore":
			# Zackiger Explosionsstern mit heissem Kern.
			var star: Array = []
			for i in 14:
				var a := TAU * i / 14.0
				star.append(Vector2(cos(a), sin(a)) * (1.0 if i % 2 == 0 else 0.55))
			_poly(c, center, k, star, color)
			c.draw_circle(center, k * 0.38, Color(1.0, 0.95, 0.55))
		"killshot":
			# Vierzackiger Stern in einem Ring: der Volltreffer.
			c.draw_arc(center, k * 0.9, 0.0, TAU, 24, Color(color, 0.7), 2.5, true)
			_poly(c, center, k, [Vector2(0, -0.95), Vector2(0.18, -0.18), Vector2(0.95, 0), Vector2(0.18, 0.18), Vector2(0, 0.95), Vector2(-0.18, 0.18), Vector2(-0.95, 0), Vector2(-0.18, -0.18)], color)
			c.draw_circle(center, k * 0.12, Color.WHITE)
		"ecochip":
			# Patrone im Kreislauf.
			c.draw_arc(center, k * 0.85, 0.3, PI - 0.3, 14, color, 3.0, true)
			c.draw_arc(center, k * 0.85, PI + 0.3, TAU - 0.3, 14, color, 3.0, true)
			c.draw_rect(Rect2(center + Vector2(-0.2, -0.1) * k, Vector2(0.4, 0.6) * k), color)
			_poly(c, center, k, [Vector2(-0.2, -0.1), Vector2(0.0, -0.5), Vector2(0.2, -0.1)], Color(1, 1, 1, 0.9))
		"heavyslugs":
			# Schwerer Brocken mit Wuchtlinien.
			c.draw_circle(center + Vector2(0.35, 0.0) * k, k * 0.55, color)
			c.draw_circle(center + Vector2(0.2, -0.15) * k, k * 0.15, Color(1, 1, 1, 0.5))
			for dy in [-0.5, 0.0, 0.5]:
				c.draw_line(center + Vector2(-1.0, dy) * k, center + Vector2(-0.4, dy) * k, Color(color, 0.8), 3.0, true)
		"ricochet":
			# Strahl prallt vom Boden ab.
			_line(c, center, k, [Vector2(-0.95, -0.85), Vector2(0.0, 0.65), Vector2(0.95, -0.85)], color, 3.5)
			c.draw_line(center + Vector2(-1.0, 0.75) * k, center + Vector2(1.0, 0.75) * k, Color(1, 1, 1, 0.8), 3.0)
			c.draw_circle(center + Vector2(0.0, 0.65) * k, k * 0.14, Color.WHITE)
		"seeker":
			# Gekruemmte Bahn zum Ziel.
			c.draw_arc(center + Vector2(-0.2, 0.5) * k, k * 0.9, PI * 1.05, PI * 1.75, 14, color, 3.5, true)
			c.draw_arc(center + Vector2(0.7, -0.3) * k, k * 0.28, 0.0, TAU, 14, color, 2.5, true)
			c.draw_circle(center + Vector2(0.7, -0.3) * k, k * 0.09, Color.WHITE)
		_:
			c.draw_circle(center, k * 0.5, color)


static func _poly(c: CanvasItem, center: Vector2, k: float, points: Array, color: Color) -> void:
	var packed := PackedVector2Array()
	for point in points:
		packed.append(center + point * k)
	c.draw_colored_polygon(packed, color)


static func _line(c: CanvasItem, center: Vector2, k: float, points: Array, color: Color, width: float) -> void:
	var packed := PackedVector2Array()
	for point in points:
		packed.append(center + point * k)
	c.draw_polyline(packed, color, width, true)


## Symbole fuer Bewegungs-Firmware (Shop).
static func draw_firmware(c: CanvasItem, firmware_id: String, center: Vector2, size: float, color: Color) -> void:
	var u := size / 2.0
	Art.glow(c, center, u * 1.5, color)
	Art.disc(c, center, u * 1.05, Color(0.1, 0.11, 0.17), Color(color, 0.8))
	var k := u * 0.6
	match firmware_id:
		"double_jump":
			_line(c, center, k, [Vector2(-0.7, 0.1), Vector2(0, -0.5), Vector2(0.7, 0.1)], color, 4.0)
			_line(c, center, k, [Vector2(-0.7, 0.8), Vector2(0, 0.2), Vector2(0.7, 0.8)], color, 4.0)
		"wall_jump":
			c.draw_rect(Rect2(center + Vector2(-0.9, -0.9) * k, Vector2(0.3, 1.8) * k), color)
			_line(c, center, k, [Vector2(-0.3, 0.7), Vector2(0.5, -0.1), Vector2(0.1, -0.1)], color, 4.0)
			_poly(c, center, k, [Vector2(0.4, -0.7), Vector2(0.9, -0.1), Vector2(0.2, -0.05)], color)
		"glide":
			c.draw_arc(center + Vector2(0, -0.1 * k), k * 0.95, PI, TAU, 16, color, 4.0, true)
			c.draw_line(center + Vector2(-0.95, -0.1) * k, center + Vector2(0, 0.8) * k, Color(color, 0.7), 2.0)
			c.draw_line(center + Vector2(0.95, -0.1) * k, center + Vector2(0, 0.8) * k, Color(color, 0.7), 2.0)
		"slam":
			c.draw_line(center + Vector2(0, -0.9) * k, center + Vector2(0, 0.3) * k, color, 5.0, true)
			_poly(c, center, k, [Vector2(-0.6, 0.1), Vector2(0.6, 0.1), Vector2(0, 0.85)], color)
			c.draw_line(center + Vector2(-0.9, 0.95) * k, center + Vector2(0.9, 0.95) * k, color, 3.0)
		"hook":
			c.draw_line(center + Vector2(0, -0.9) * k, center + Vector2(0, 0.3) * k, color, 4.0, true)
			c.draw_arc(center + Vector2(-0.35, 0.3) * k, k * 0.35, 0.0, PI, 12, color, 4.0, true)
			_poly(c, center, k, [Vector2(-0.8, 0.3), Vector2(-0.5, 0.0), Vector2(-0.3, 0.5)], color)
		"dash_charge":
			_poly(c, center, k, [Vector2(0.15, -1), Vector2(-0.55, 0.1), Vector2(-0.05, 0.1), Vector2(-0.2, 1), Vector2(0.55, -0.15), Vector2(0.05, -0.15)], color)
			c.draw_line(center + Vector2(-1.0, -0.4) * k, center + Vector2(-0.6, -0.4) * k, Color(color, 0.7), 2.5)
			c.draw_line(center + Vector2(-1.0, 0.4) * k, center + Vector2(-0.7, 0.4) * k, Color(color, 0.7), 2.5)
		_:
			_line(c, center, k, [Vector2(-0.7, 0.5), Vector2(0, -0.6), Vector2(0.7, 0.5)], color, 4.0)
