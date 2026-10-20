class_name Fx
extends Node2D
## Einfache Effekte (Funken, Muendungsfeuer, Strahlen, Explosionen), die in
## Weltkoordinaten gezeichnet werden. Eine Liste, ein Zeichenaufruf.

const MAX_ITEMS := 500

## Letzte Instanz, damit Gegner und Pickups Effekte ohne feste Verdrahtung erzeugen koennen.
static var instance: Fx = null

## Hoehe des Bodens fuer Truemmerteile (wird von der Hauptszene gesetzt).
var floor_y := 1250.0
var _items: Array[Dictionary] = []


func _ready() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func number(pos: Vector2, amount: float, color := Color(1.0, 1.0, 0.5), size := 22) -> void:
	if _items.size() >= MAX_ITEMS:
		return
	_items.append({"type": "number", "pos": pos + Vector2(randf_range(-14.0, 14.0), 0.0), "text": str(int(round(amount))),
		"t": 0.6, "max": 0.6, "color": color, "size": size})


## Wie number, aber mit beliebigem Text und laengerer Lebensdauer (z.B. Perk-Wirkung).
func number_text(pos: Vector2, text: String, color: Color, size := 22) -> void:
	if _items.size() >= MAX_ITEMS:
		return
	_items.append({"type": "number", "pos": pos, "text": text, "t": 1.6, "max": 1.6, "color": color, "size": size})


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


## Truemmerteil eines zerstoerten Roboters. shape: plate, wheel oder bolt.
func gib(pos: Vector2, color: Color, shape: String, size: float, speed: float) -> void:
	if _items.size() >= MAX_ITEMS - 40:
		return
	var angle := randf_range(-PI * 0.95, -PI * 0.05)
	var life := randf_range(0.9, 1.5)
	_items.append({
		"type": "gib", "pos": pos, "vel": Vector2(cos(angle), sin(angle)) * randf_range(0.4, 1.0) * speed,
		"rot": randf() * TAU, "spin": randf_range(-14.0, 14.0), "t": life, "max": life, "color": color,
		"shape": shape, "size": size,
	})


## Glanz auf frisch gesaubertem Boden: kleiner Stern, der kurz funkelt.
func glint(pos: Vector2, size := 7.0) -> void:
	if _items.size() >= MAX_ITEMS - 60:
		return
	var life := randf_range(0.7, 1.3)
	_items.append({"type": "glint", "pos": pos, "t": life, "max": life, "color": Color(0.85, 1.0, 1.0), "size": size, "phase": randf() * TAU})


## Blanker Streifen auf dem Boden zwischen zwei Punkten (die sauber gesaugte Spur).
func shine(from: Vector2, to: Vector2) -> void:
	if _items.size() >= MAX_ITEMS - 60:
		return
	_items.append({"type": "shine", "from": from, "to": to, "t": 1.7, "max": 1.7, "color": Color(0.8, 1.0, 1.0)})


func muzzle(pos: Vector2, dir: Vector2, color: Color) -> void:
	_items.append({"type": "muzzle", "pos": pos, "dir": dir, "t": 0.06, "max": 0.06, "color": color})


func tracer(from: Vector2, to: Vector2, color: Color, width: float, life: float) -> void:
	_items.append({"type": "tracer", "from": from, "to": to, "t": life, "max": life, "color": color, "width": width})


func ring(pos: Vector2, radius: float, color: Color) -> void:
	_items.append({"type": "ring", "pos": pos, "radius": radius, "t": 0.2, "max": 0.2, "color": color})


func explosion(pos: Vector2, radius: float, color: Color) -> void:
	_items.append({"type": "explosion", "pos": pos, "radius": radius, "t": 0.3, "max": 0.3, "color": color})
	spark(pos, color, 18, 500.0)


func _process(delta: float) -> void:
	for item in _items:
		item.t -= delta
		if item.type == "spark":
			item.pos += item.vel * delta
			item.vel *= 0.9
		elif item.type == "number":
			item.pos.y -= 70.0 * delta
		elif item.type == "gib":
			item.vel.y += 1800.0 * delta
			var before: Vector2 = item.pos
			item.pos += item.vel * delta
			item.rot += item.spin * delta
			var rest: float = floor_y - float(item.size) * 0.5
			if item.vel.y > 0.0 and item.pos.y < rest - 4.0:
				var ground := GroundProbe.ground_y(self, before, item.pos + Vector2(0.0, float(item.size) * 0.5))
				if ground < INF:
					item.pos.y = ground - float(item.size) * 0.5
					item.vel.y *= -0.35
					item.vel.x *= 0.65
					item.spin *= 0.5
			if item.pos.y > rest:
				item.pos.y = rest
				item.vel.y *= -0.35
				item.vel.x *= 0.65
				item.spin *= 0.5
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
			"number":
				color.a = fade
				var font := ThemeDB.fallback_font
				var at: Vector2 = item.pos + Vector2(-300.0, 0.0)
				# Dunkle Kontur, damit Zahlen und Texte auf jedem Hintergrund lesbar bleiben.
				draw_string_outline(font, at, item.text, HORIZONTAL_ALIGNMENT_CENTER, 600.0, item.size, 6, Color(0.03, 0.03, 0.07, 0.85 * fade))
				draw_string(font, at, item.text, HORIZONTAL_ALIGNMENT_CENTER, 600.0, item.size, color)
			"gib":
				var alpha := clampf(fade * 3.0, 0.0, 1.0)
				var size: float = item.size
				var rot: float = item.rot
				var axis := Vector2(cos(rot), sin(rot))
				var side := axis.orthogonal()
				match item.shape:
					"wheel":
						draw_circle(item.pos, size * 0.5, Color(0.12, 0.12, 0.16, alpha))
						draw_line(item.pos - axis * size * 0.45, item.pos + axis * size * 0.45, Color(0.6, 0.55, 0.55, alpha), 1.5)
					"bolt":
						draw_circle(item.pos, size * 0.35, Color(0.75, 0.78, 0.85, alpha))
					_:
						var points := PackedVector2Array([item.pos + axis * size * 0.6 + side * size * 0.3, item.pos - axis * size * 0.6 + side * size * 0.3, item.pos - axis * size * 0.6 - side * size * 0.3, item.pos + axis * size * 0.6 - side * size * 0.3])
						color.a = alpha
						draw_colored_polygon(points, color)
						points.append(points[0])
						draw_polyline(points, Color(Art.OUTLINE, alpha), 1.5, true)
			"glint":
				# Funkeln: Stern pulsiert und schrumpft am Ende.
				var twinkle := 0.6 + 0.4 * sin(float(item.phase) + fade * 14.0)
				var arm: float = float(item.size) * fade * twinkle
				color.a = clampf(fade * 1.6, 0.0, 1.0)
				draw_line(item.pos + Vector2(-arm, 0.0), item.pos + Vector2(arm, 0.0), color, 1.6, true)
				draw_line(item.pos + Vector2(0.0, -arm), item.pos + Vector2(0.0, arm), color, 1.6, true)
				draw_line(item.pos + Vector2(-arm, -arm) * 0.45, item.pos + Vector2(arm, arm) * 0.45, Color(color, color.a * 0.6), 1.2, true)
				draw_line(item.pos + Vector2(-arm, arm) * 0.45, item.pos + Vector2(arm, -arm) * 0.45, Color(color, color.a * 0.6), 1.2, true)
				draw_circle(item.pos, arm * 0.25, Color(1, 1, 1, color.a))
			"shine":
				color.a = 0.5 * fade
				draw_line(item.from + Vector2(0, -2), item.to + Vector2(0, -2), color, 8.0)
				draw_line(item.from + Vector2(0, -3), item.to + Vector2(0, -3), Color(1, 1, 1, 0.7 * fade), 2.0)
			"muzzle":
				color.a = fade
				draw_circle(item.pos, 9.0, color)
				draw_line(item.pos, item.pos + item.dir * 22.0, Color(1, 1, 1, fade), 4.0)
			"tracer":
				color.a = fade
				draw_line(item.from, item.to, color, item.width * 2.2)
				draw_line(item.from, item.to, Color(1, 1, 1, fade), item.width)
			"ring":
				color.a = fade
				draw_arc(item.pos, item.radius * (1.1 - 0.1 * fade), 0.0, TAU, 32, color, 4.0)
			"explosion":
				var progress := 1.0 - fade
				var r: float = item.radius * (0.4 + 0.6 * progress)
				color.a = 0.35 * fade
				draw_circle(item.pos, r, color)
				color.a = fade
				draw_arc(item.pos, r, 0.0, TAU, 40, color, 4.0)
