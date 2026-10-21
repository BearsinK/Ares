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
	if _items.size() >= MAX_ITEMS or not SaveData.numbers_enabled():
		return
	_items.append({"type": "number", "pos": pos + Vector2(randf_range(-14.0, 14.0), 0.0), "text": str(int(round(amount))),
		"t": 0.6, "max": 0.6, "color": color, "size": size})


## Wie number, aber mit beliebigem Text und laengerer Lebensdauer (z.B. Perk-Wirkung).
func number_text(pos: Vector2, text: String, color: Color, size := 22, life := 1.6) -> void:
	if _items.size() >= MAX_ITEMS:
		return
	_items.append({"type": "number", "pos": pos, "text": text, "t": life, "max": life, "color": color, "size": size})


func spark(pos: Vector2, color: Color, count := 6, speed := 260.0) -> void:
	if SaveData.calm_effects():
		count = maxi(1, count / 2)
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


## Einzelnes Teilchen mit Bewegung (ember, drop, shard, puff). Alles kurzlebig, kein Eingriff in die Spielwelt.
func _particle(type: String, pos: Vector2, vel: Vector2, life: float, color: Color, size: float) -> void:
	if _items.size() >= MAX_ITEMS - 60:
		return
	_items.append({"type": type, "pos": pos, "vel": vel, "t": life, "max": life, "color": color, "size": size, "rot": randf() * TAU, "spin": randf_range(-12.0, 12.0)})


func _calm_count(count: int) -> int:
	return maxi(1, count / 2) if SaveData.calm_effects() else count


## Eine Spur hinter einem Element-Geschoss: Glut steigt auf, Tropfen fallen, Eiskristalle funkeln, kleine Blitze zucken.
func element_trail(pos: Vector2, element: String) -> void:
	match element:
		"fire":
			_particle("ember", pos + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)), Vector2(randf_range(-30.0, 30.0), randf_range(-130.0, -60.0)), randf_range(0.35, 0.6), Color(1.0, 0.55, 0.15), randf_range(2.0, 3.6))
		"water":
			_particle("drop", pos, Vector2(randf_range(-40.0, 40.0), randf_range(-30.0, 30.0)), randf_range(0.3, 0.5), Color(0.4, 0.7, 1.0), randf_range(2.0, 3.2))
		"ice":
			if _items.size() < MAX_ITEMS - 100:
				_items.append({"type": "glint", "pos": pos + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0)), "t": 0.4, "max": 0.4, "color": Elements.COLORS.ice, "size": randf_range(5.0, 9.0), "phase": randf() * TAU})
		"lightning":
			var a := randf() * TAU
			zigzag(pos, pos + Vector2(cos(a), sin(a)) * randf_range(14.0, 26.0), Elements.COLORS.lightning, 1.6, 0.07)


## Treffer eines Elements: Glutfunken, Spritzer, Eisscherben oder kleine Blitzgabeln.
func element_hit(pos: Vector2, element: String, strength := 1.0) -> void:
	var count := _calm_count(int(round(6.0 * strength)))
	for i in count:
		var angle := randf() * TAU
		var dir := Vector2(cos(angle), sin(angle))
		match element:
			"fire":
				_particle("ember", pos + dir * 6.0, dir * randf_range(60.0, 220.0) + Vector2(0.0, -60.0), randf_range(0.35, 0.7), Color(1.0, 0.5, 0.12), randf_range(2.5, 4.5))
			"water":
				_particle("drop", pos + dir * 4.0, Vector2(dir.x * randf_range(60.0, 200.0), randf_range(-260.0, -80.0)), randf_range(0.35, 0.6), Color(0.4, 0.7, 1.0), randf_range(2.5, 4.0))
			"ice":
				_particle("shard", pos, dir * randf_range(120.0, 340.0), randf_range(0.3, 0.5), Color(0.8, 0.96, 1.0), randf_range(4.0, 7.0))
			"lightning":
				if i < 3:
					zigzag(pos, pos + dir * randf_range(26.0, 56.0), Elements.COLORS.lightning, 2.0, 0.1)
	if element == "water":
		_items.append({"type": "ring", "pos": pos, "radius": 22.0 * minf(strength, 2.0), "t": 0.2, "max": 0.2, "color": Color(0.45, 0.75, 1.0)})


## Muendungseffekt des Elements vor dem Lauf.
func element_muzzle(pos: Vector2, dir: Vector2, element: String) -> void:
	for i in _calm_count(4):
		var spread := dir.rotated(randf_range(-0.5, 0.5))
		match element:
			"fire":
				_particle("ember", pos, spread * randf_range(120.0, 260.0), randf_range(0.2, 0.4), Color(1.0, 0.55, 0.15), randf_range(2.5, 4.0))
			"water":
				_particle("drop", pos, spread * randf_range(120.0, 240.0), randf_range(0.25, 0.4), Color(0.4, 0.7, 1.0), randf_range(2.5, 3.5))
			"ice":
				_particle("shard", pos, spread * randf_range(150.0, 300.0), randf_range(0.2, 0.35), Color(0.8, 0.96, 1.0), randf_range(3.5, 6.0))
			"lightning":
				if i < 2:
					zigzag(pos, pos + spread * randf_range(24.0, 44.0), Elements.COLORS.lightning, 2.0, 0.08)


## Teilchen entlang eines Strahls (alle ca. 100 px eines): macht das Element auch bei Strahlwaffen sichtbar.
func element_beam(from: Vector2, to: Vector2, element: String) -> void:
	var length := from.distance_to(to)
	var steps := int(length / 100.0)
	for i in steps:
		element_trail(from.lerp(to, (float(i) + randf()) / float(maxi(steps, 1))), element)


## Aufsteigender Dampf oder Rauch.
func puff(pos: Vector2, radius: float, color: Color, count := 6) -> void:
	for i in _calm_count(count):
		_particle("puff", pos + Vector2(randf_range(-radius, radius), randf_range(-radius, radius) * 0.5), Vector2(randf_range(-20.0, 20.0), randf_range(-70.0, -20.0)), randf_range(0.6, 1.0), color, randf_range(radius * 0.25, radius * 0.5))


## Kombo-Meldung am Ziel: Name (bei Koop mit goldener Zeile), Ring und Teilchen der Kombo.
func combo(pos: Vector2, combo_name: String, coop: bool) -> void:
	var info: Dictionary = Elements.COMBOS[combo_name]
	var color: Color = info.color
	number_text(pos + Vector2(0.0, -78.0), String(info.text), color, 24 if coop else 20, 1.2)
	if coop:
		number_text(pos + Vector2(0.0, -102.0), "KOOP", Color(1.0, 0.85, 0.3), 16, 1.2)
		_items.append({"type": "ring", "pos": pos, "radius": 100.0, "t": 0.3, "max": 0.3, "color": Color(1.0, 0.85, 0.3)})
	_items.append({"type": "ring", "pos": pos, "radius": 72.0 if coop else 56.0, "t": 0.25, "max": 0.25, "color": color})
	match combo_name:
		"steam":
			puff(pos, 55.0, Color(0.92, 0.95, 1.0, 0.85), 9)
		"freeze":
			element_hit(pos, "ice", 2.5)
			puff(pos, 40.0, Color(0.8, 0.96, 1.0, 0.8), 4)
		"shock":
			element_hit(pos, "lightning", 2.0)
			spark(pos, color, 10, 380.0)
		"melt":
			puff(pos, 40.0, Color(1.0, 0.8, 0.6, 0.8), 5)
			element_hit(pos, "ice", 1.2)
		"overload":
			element_hit(pos, "fire", 3.0)
			element_hit(pos, "lightning", 1.5)
			spark(pos, color, 14, 460.0)
		"short":
			element_hit(pos, "ice", 1.5)
			element_hit(pos, "lightning", 2.0)


## Schwung eines Nahkampf-Bogens: heller Halbmond vor dem Spieler (Sweeper).
func slash(pos: Vector2, dir: Vector2, reach: float, arc: float, color: Color) -> void:
	if _items.size() >= MAX_ITEMS:
		return
	_items.append({"type": "slash", "pos": pos, "dir": dir, "reach": reach, "arc": arc, "t": 0.16, "max": 0.16, "color": color})


## Gezackte Blitzlinie zwischen zwei Punkten (Kettenblitz). Die Zacken werden einmal ausgewuerfelt.
func zigzag(from: Vector2, to: Vector2, color: Color, width := 3.0, life := 0.14) -> void:
	if _items.size() >= MAX_ITEMS:
		return
	var points := PackedVector2Array([from])
	var length := from.distance_to(to)
	var segments := maxi(2, int(length / 32.0))
	var side := (to - from).normalized().orthogonal()
	for i in range(1, segments):
		var along := from.lerp(to, float(i) / float(segments))
		points.append(along + side * randf_range(-9.0, 9.0))
	points.append(to)
	_items.append({"type": "zigzag", "points": points, "t": life, "max": life, "color": color, "width": width})


## Sog-Kegel (Vacuum): schmale Linien, die zum Fokuspunkt laufen.
func suction(pos: Vector2, dir: Vector2, reach: float, cone: float, color: Color) -> void:
	_items.append({"type": "suction", "pos": pos, "dir": dir, "reach": reach, "cone": cone, "t": 0.1, "max": 0.1, "color": color, "phase": randf()})


## Symbol eines Items steigt auf und verblasst (Kiste geoeffnet).
func perk_icon(pos: Vector2, perk_id: String, life := 2.2) -> void:
	if _items.size() >= MAX_ITEMS:
		return
	_items.append({"type": "icon", "pos": pos, "id": perk_id, "t": life, "max": life, "color": Color.WHITE})


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
		elif item.type == "ember":
			item.vel.y -= 90.0 * delta
			item.pos += item.vel * delta
			item.vel.x *= 0.96
		elif item.type == "drop":
			item.vel.y += 1100.0 * delta
			item.pos += item.vel * delta
		elif item.type == "shard":
			item.pos += item.vel * delta
			item.vel *= 0.9
			item.rot += item.spin * delta
		elif item.type == "puff":
			item.pos += item.vel * delta
			item.vel *= 0.97
		elif item.type == "icon":
			# Steigt erst schnell, dann langsam.
			item.pos.y -= (90.0 * item.t / item.max + 10.0) * delta
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
	var outlined := 0
	for item in _items:
		var fade: float = item.t / item.max
		var color: Color = item.color
		match item.type:
			"spark":
				color.a = fade
				draw_line(item.pos, item.pos - item.vel * 0.04, color, 2.5)
			"icon":
				var grow := minf(1.0, (1.0 - fade) * 6.0)
				var icon_size := 56.0 * (0.4 + 0.6 * grow) * minf(1.0, fade * 3.0)
				# Sehr kleine Symbole ergeben ungueltige Vielecke, dann gar nicht zeichnen.
				if icon_size > 12.0:
					PerkArt.draw(self, item.id, item.pos, icon_size)
			"number":
				color.a = fade
				var font := ThemeDB.fallback_font
				var at: Vector2 = item.pos + Vector2(-300.0, 0.0)
				# Dunkle Kontur, damit Zahlen und Texte auf jedem Hintergrund lesbar bleiben (nur fuer die ersten, spart Zeit bei Dauerfeuer).
				if outlined < 20 or item.size >= 20:
					outlined += 1
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
			"ember":
				var heat := 1.0 - fade
				var glow := Color(1.0, 0.85 - 0.5 * heat, 0.3 - 0.2 * heat, fade)
				draw_circle(item.pos, float(item.size) * (0.6 + 0.6 * fade), glow)
				draw_circle(item.pos, float(item.size) * 0.4 * fade, Color(1.0, 1.0, 0.8, fade))
			"drop":
				color.a = fade
				draw_circle(item.pos, float(item.size), color)
				draw_line(item.pos, item.pos - item.vel.normalized() * float(item.size) * 2.2, Color(color, fade * 0.5), float(item.size) * 0.9)
			"shard":
				var axis := Vector2(cos(item.rot), sin(item.rot))
				var side := axis.orthogonal()
				var sz: float = item.size
				var tri := PackedVector2Array([item.pos + axis * sz, item.pos - axis * sz * 0.5 + side * sz * 0.45, item.pos - axis * sz * 0.5 - side * sz * 0.45])
				color.a = clampf(fade * 1.5, 0.0, 1.0)
				draw_colored_polygon(tri, color)
				tri.append(tri[0])
				draw_polyline(tri, Color(1, 1, 1, color.a), 1.0, true)
			"puff":
				var grow: float = float(item.size) * (1.0 + 1.6 * (1.0 - fade))
				color.a *= 0.45 * fade
				draw_circle(item.pos, grow, color)
			"slash":
				# Halbmond: aeusserer Bogen blitzt auf und verblasst, der innere folgt.
				var base_angle: float = item.dir.angle()
				var half: float = item.arc * 0.5
				var sweep := 1.0 - fade
				var reach: float = item.reach
				color.a = fade
				draw_arc(item.pos, reach * (0.75 + 0.25 * sweep), base_angle - half, base_angle + half, 24, color, 12.0 * fade + 2.0, true)
				draw_arc(item.pos, reach * (0.7 + 0.25 * sweep), base_angle - half, base_angle + half, 24, Color(1, 1, 1, fade), 3.0, true)
				draw_arc(item.pos, reach * 0.55, base_angle - half * 0.9, base_angle + half * 0.9, 20, Color(color, 0.4 * fade), 6.0, true)
			"zigzag":
				color.a = fade
				draw_polyline(item.points, color, item.width * 2.6, true)
				draw_polyline(item.points, Color(1, 1, 1, fade), item.width, true)
			"suction":
				# Kegelflaeche und Linien, die von aussen auf die Mittelachse zulaufen (Zugrichtung).
				var heading: float = item.dir.angle()
				var reach: float = item.reach
				var cone: float = item.cone
				var fan := PackedVector2Array([item.pos])
				for k in 9:
					fan.append(item.pos + Vector2.from_angle(heading + lerpf(-cone, cone, float(k) / 8.0)) * reach)
				draw_colored_polygon(fan, Color(color, 0.08 * fade))
				for k in 7:
					var lane := lerpf(-cone, cone, (float(k) + 0.5) / 7.0)
					var run := fposmod(float(item.phase) + float(k) * 0.29, 1.0)
					var angle := heading + lane * (0.25 + 0.75 * (1.0 - run))
					var dist := reach * (1.0 - run * 0.7)
					draw_line(item.pos + Vector2.from_angle(angle) * dist, item.pos + Vector2.from_angle(angle) * (dist + 38.0), Color(color, 0.8 * fade * (1.0 - run * 0.4)), 3.0, true)
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
