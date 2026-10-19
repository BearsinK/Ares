class_name Fx
extends Node2D
## Einfache Effekte (Funken, Muendungsfeuer, Strahlen, Explosionen), die in
## Weltkoordinaten gezeichnet werden. Eine Liste, ein Zeichenaufruf.

const MAX_ITEMS := 500

var _items: Array[Dictionary] = []


func spark(pos: Vector2, color: Color, count := 6, speed := 260.0) -> void:
	for i in count:
		if _items.size() >= MAX_ITEMS:
			return
		var angle := randf() * TAU
		var life := randf_range(0.12, 0.3)
		_items.append({
			"type": "spark", "pos": pos, "vel": Vector2(cos(angle), sin(angle)) * randf_range(0.3, 1.0) * speed,
			"t": life, "max": life, "color": color,
		})


func muzzle(pos: Vector2, dir: Vector2, color: Color) -> void:
	_items.append({"type": "muzzle", "pos": pos, "dir": dir, "t": 0.06, "max": 0.06, "color": color})


func tracer(from: Vector2, to: Vector2, color: Color, width: float, life: float) -> void:
	_items.append({"type": "tracer", "from": from, "to": to, "t": life, "max": life, "color": color, "width": width})


func explosion(pos: Vector2, radius: float, color: Color) -> void:
	_items.append({"type": "explosion", "pos": pos, "radius": radius, "t": 0.3, "max": 0.3, "color": color})
	spark(pos, color, 18, 500.0)


func _process(delta: float) -> void:
	for item in _items:
		item.t -= delta
		if item.type == "spark":
			item.pos += item.vel * delta
			item.vel *= 0.9
	_items = _items.filter(func(item: Dictionary) -> bool: return item.t > 0.0)
	queue_redraw()


func _draw() -> void:
	for item in _items:
		var fade: float = item.t / item.max
		var color: Color = item.color
		match item.type:
			"spark":
				color.a = fade
				draw_line(item.pos, item.pos - item.vel * 0.04, color, 2.5)
			"muzzle":
				color.a = fade
				draw_circle(item.pos, 9.0, color)
				draw_line(item.pos, item.pos + item.dir * 22.0, Color(1, 1, 1, fade), 4.0)
			"tracer":
				color.a = fade
				draw_line(item.from, item.to, color, item.width * 2.2)
				draw_line(item.from, item.to, Color(1, 1, 1, fade), item.width)
			"explosion":
				var progress := 1.0 - fade
				var r: float = item.radius * (0.4 + 0.6 * progress)
				color.a = 0.35 * fade
				draw_circle(item.pos, r, color)
				color.a = fade
				draw_arc(item.pos, r, 0.0, TAU, 40, color, 4.0)
