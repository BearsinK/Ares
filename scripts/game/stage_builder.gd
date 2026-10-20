class_name StageBuilder
extends RefCounted
## Baut aus einem Layout (siehe Stages) die Spielwelt: Kollision, Optik, Seile und Dekor.
## Alles landet unter root, das beim Kartenwechsel komplett entfernt wird.

const DECOR_TEXTS: Array[String] = ["ZONE 02", "ACHTUNG", "SCHROTT", "LAGER", "WARTUNG", "NOT-AUS"]
const MACHINE_COLORS: Array[Color] = [Color(0.26, 0.3, 0.42), Color(0.4, 0.28, 0.24), Color(0.28, 0.38, 0.32)]


static func build(root: Node2D, layout: Dictionary, seed_value := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var size: Vector2 = layout.size
	for i in layout.solids.size():
		var rect: Rect2 = layout.solids[i]
		var frame: bool = rect.position.x < 0.0 or rect.end.x > size.x or rect.position.y < 0.0
		_add_solid(root, rect, frame, rng.randi())
	for points in layout.ramps:
		_add_ramp(root, points)
	for rect in layout.platforms:
		_add_platform(root, rect)
	for rect in layout.ropes:
		_add_rope(root, rect)
	var props := Props.new()
	props.classic = false
	props.decor = _make_decor(layout, rng)
	props.steam_points = layout.steam
	props.ember_center = size * 0.5
	props.ember_extents = size * 0.5
	root.add_child(props)


static func _add_solid(root: Node2D, rect: Rect2, frame: bool, seed_value: int) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1 << 0
	body.collision_mask = 0
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	if not frame:
		# Der Hexapod haengt sich auch an Unterseiten von Felsmassen und Platten.
		body.add_to_group("ceilings")
		body.set_meta("rect", rect)
	# Optik in Streifen, damit weit entfernte Teile nicht gezeichnet werden.
	var x := rect.position.x
	var index := 0
	while x < rect.end.x - 0.5:
		var width := minf(TerrainArt.CHUNK, rect.end.x - x)
		var art := TerrainArt.new()
		art.kind = "frame" if frame else "rect"
		art.rect = Rect2(Vector2(x, rect.position.y) - rect.get_center(), Vector2(width, rect.size.y))
		art.seed_value = seed_value + index
		body.add_child(art)
		x += width
		index += 1
	root.add_child(body)


static func _add_ramp(root: Node2D, points: PackedVector2Array) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1 << 0
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var convex := ConvexPolygonShape2D.new()
	convex.set_point_cloud(points)
	shape.shape = convex
	body.add_child(shape)
	var art := TerrainArt.new()
	art.kind = "ramp"
	art.points = points
	body.add_child(art)
	root.add_child(body)


static func _add_platform(root: Node2D, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1 << 5
	body.collision_mask = 0
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.one_way_collision = true
	shape.one_way_collision_margin = 10.0
	body.add_child(shape)
	body.add_to_group("ceilings")
	body.set_meta("rect", rect)
	var art := BlockArt.new()
	art.kind = "platform"
	art.size = rect.size
	body.add_child(art)
	root.add_child(body)


static func _add_rope(root: Node2D, rect: Rect2) -> void:
	var rope := RopeArt.new()
	rope.position = Vector2(rect.get_center().x, rect.position.y)
	rope.length = rect.size.y
	rope.add_to_group("ropes")
	rope.set_meta("rect", rect)
	root.add_child(rope)


## Dekor (Kisten, Faesser, Maschinen, Schilder) auf den flachen Oberflaechen. Rein optisch.
static func _make_decor(layout: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var starts: Array = layout.starts
	for surface in Stages.surfaces(layout):
		if surface.kind != "solid" or surface.island:
			continue
		var length: float = float(surface.x1) - float(surface.x0)
		if length < 500.0:
			continue
		var count := clampi(int(length / 700.0), 1, 4)
		for i in count:
			var x: float = float(surface.x0) + 160.0 + rng.randf() * (length - 320.0)
			var near_start := false
			for start in starts:
				if absf(start.x - x) < 200.0 and absf(start.y - float(surface.y0)) < 5.0:
					near_start = true
			if near_start:
				continue
			var pos := Vector2(x, float(surface.y0))
			match rng.randi() % 5:
				0:
					items.append({"type": "crate", "pos": pos, "size": rng.randf_range(54.0, 72.0)})
				1:
					items.append({"type": "stack", "pos": pos, "size": rng.randf_range(52.0, 62.0)})
				2:
					items.append({"type": "barrel", "pos": pos})
				3:
					items.append({"type": "machine", "pos": pos, "size": Vector2(rng.randf_range(90.0, 120.0), rng.randf_range(110.0, 160.0)), "color": MACHINE_COLORS[rng.randi() % MACHINE_COLORS.size()]})
				_:
					items.append({"type": "sign", "pos": pos, "text": DECOR_TEXTS[rng.randi() % DECOR_TEXTS.size()]})
	return items
