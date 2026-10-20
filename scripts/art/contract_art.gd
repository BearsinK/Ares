class_name ContractArt
extends RefCounted
## Symbole der Wellen-Vertraege, im Code gezeichnet (siehe WaveModifiers). Liegen in einem Quadrat der Kantenlaenge size.


static func draw(c: CanvasItem, id: String, center: Vector2, size: float) -> void:
	var color: Color = WaveModifiers.DATA[id].color
	var u := size / 2.0
	Art.glow(c, center, u * 1.5, color)
	Art.disc(c, center, u * 1.05, Color(0.1, 0.11, 0.17), Color(color, 0.8))
	var k := u * 0.62
	match id:
		"normal":
			c.draw_arc(center, k * 0.8, 0.0, TAU, 24, color, 4.0, true)
			c.draw_line(center + Vector2(-0.4, 0.05) * k, center + Vector2(-0.1, 0.4) * k, color, 4.0, true)
			c.draw_line(center + Vector2(-0.1, 0.4) * k, center + Vector2(0.45, -0.3) * k, color, 4.0, true)
		"swarm":
			for point in [Vector2(-0.6, -0.5), Vector2(0.1, -0.7), Vector2(0.7, -0.2), Vector2(-0.3, 0.1), Vector2(0.35, 0.3), Vector2(-0.7, 0.6), Vector2(0.0, 0.75), Vector2(0.75, 0.7)]:
				c.draw_circle(center + point * k, k * 0.2, color)
		"elites":
			var points := PackedVector2Array([Vector2(-0.8, 0.5), Vector2(-0.8, -0.5), Vector2(-0.4, -0.1), Vector2(0.0, -0.8), Vector2(0.4, -0.1), Vector2(0.8, -0.5), Vector2(0.8, 0.5)])
			for i in points.size():
				points[i] = center + points[i] * k
			c.draw_colored_polygon(points, color)
		"armor":
			var shield := PackedVector2Array([Vector2(0, -0.95), Vector2(0.8, -0.6), Vector2(0.7, 0.3), Vector2(0, 0.95), Vector2(-0.7, 0.3), Vector2(-0.8, -0.6)])
			for i in shield.size():
				shield[i] = center + shield[i] * k
			c.draw_colored_polygon(shield, color)
			c.draw_line(center + Vector2(0, -0.6) * k, center + Vector2(0, 0.6) * k, Color(0.1, 0.11, 0.17, 0.7), 3.0)
		"air":
			for row in 2:
				var y := (-0.2 + row * 0.55) * k
				c.draw_polyline(PackedVector2Array([center + Vector2(-0.8, y + 0.35 * k), center + Vector2(0.0, y - 0.25 * k), center + Vector2(0.8, y + 0.35 * k)]), color, 4.0, true)
		"rush":
			for i in 2:
				var x := (i - 0.5) * 0.85
				c.draw_polyline(PackedVector2Array([center + Vector2(x - 0.4, -0.7) * k, center + Vector2(x + 0.2, 0.0) * k, center + Vector2(x - 0.4, 0.7) * k]), color, 4.0, true)
		_:
			c.draw_circle(center, k * 0.5, color)
