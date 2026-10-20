extends Node
## Test der grossen Karten: Layout-Pruefung (Erreichbarkeit zu Fuss, per Sprung und Seil), Aufbau in der
## Hauptszene, Seile, Spawns und Kartenwechsel.
## Ausfuehren: godot --headless --path . res://tests/stage_test.tscn

var failures := 0
var main: Node


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("OK    ", message)
	else:
		print("FEHLER ", message)
		failures += 1


func _ready() -> void:
	_run.call_deferred()


# ---------------------------------------------------------------- Graph

func _y_at(surface: Dictionary, x: float) -> float:
	var width: float = float(surface.x1) - float(surface.x0)
	if width < 0.1:
		return float(surface.y0)
	return lerpf(float(surface.y0), float(surface.y1), clampf((x - float(surface.x0)) / width, 0.0, 1.0))


func _touching(a: Dictionary, b: Dictionary) -> bool:
	# Ein Endpunkt liegt auf der anderen Flaeche (auch mitten drauf, z.B. Rampe am Boden).
	for pair in [[a, b], [b, a]]:
		var first: Dictionary = pair[0]
		var second: Dictionary = pair[1]
		for end: Vector2 in [Vector2(first.x0, first.y0), Vector2(first.x1, first.y1)]:
			if end.x >= float(second.x0) - 6.0 and end.x <= float(second.x1) + 6.0 and absf(end.y - _y_at(second, end.x)) < 6.0:
				return true
	return false


## Alle von start aus erreichbaren Flaechen. mode "walk": nur zu Fuss ueber aneinanderstossende Flaechen.
## mode "player": zusaetzlich Sprung (bis 170 hoch, 280 weit), Fall (420 weit) und Seile.
func _reach(layout: Dictionary, surfaces: Array[Dictionary], start: int, mode: String) -> Array[bool]:
	var seen: Array[bool] = []
	seen.resize(surfaces.size())
	seen.fill(false)
	var queue: Array[int] = [start]
	seen[start] = true
	while not queue.is_empty():
		var i: int = queue.pop_front()
		var a: Dictionary = surfaces[i]
		for j in surfaces.size():
			if seen[j]:
				continue
			var b: Dictionary = surfaces[j]
			var ok := _touching(a, b)
			if not ok and mode == "player":
				var gap := maxf(0.0, maxf(float(b.x0) - float(a.x1), float(a.x0) - float(b.x1)))
				# Hoehe an den naechsten Punkten.
				var ax := clampf(float(b.x0) if float(b.x0) > float(a.x1) else (float(b.x1) if float(b.x1) < float(a.x0) else float(b.x0)), float(a.x0), float(a.x1))
				var bx := clampf(ax, float(b.x0), float(b.x1))
				var dy := _y_at(b, bx) - _y_at(a, ax)
				if dy >= -170.0 and gap <= (280.0 if dy < 0.0 else 420.0):
					ok = true
				elif dy >= 0.0 and gap <= 420.0:
					ok = true
				if not ok:
					for rope: Rect2 in layout.ropes:
						if _on_rope(a, rope) and _on_rope(b, rope):
							ok = true
							break
			if ok:
				seen[j] = true
				queue.append(j)
	return seen


func _on_rope(surface: Dictionary, rope: Rect2) -> bool:
	var cx := rope.get_center().x
	var near_x: bool = float(surface.x0) - 110.0 <= cx and cx <= float(surface.x1) + 110.0
	var y := _y_at(surface, clampf(cx, float(surface.x0), float(surface.x1)))
	return near_x and y >= rope.position.y - 14.0 and y <= rope.end.y + 14.0


func _start_surface(surfaces: Array[Dictionary], start: Vector2) -> int:
	for i in surfaces.size():
		var s: Dictionary = surfaces[i]
		if start.x >= float(s.x0) and start.x <= float(s.x1) and absf(_y_at(s, start.x) - start.y) < 6.0:
			return i
	return -1


func _validate_layout(id: String, mirrored: bool) -> void:
	var layout := Stages.build(id, mirrored)
	var label := "%s%s" % [id, " (gespiegelt)" if mirrored else ""]
	var surfaces := Stages.surfaces(layout)
	var start: int = _start_surface(surfaces, layout.starts[0])
	_check(start >= 0 and _start_surface(surfaces, layout.starts[1]) >= 0, "%s: beide Startpunkte stehen auf einer Flaeche" % label)
	if start < 0:
		return
	var player_reach := _reach(layout, surfaces, start, "player")
	var missing := 0
	for i in surfaces.size():
		if not player_reach[i]:
			missing += 1
			print("   nicht erreichbar fuer Spieler: ", surfaces[i])
	_check(missing == 0, "%s: alle %d Flaechen sind fuer Spieler erreichbar" % [label, surfaces.size()])
	var walk_reach := _reach(layout, surfaces, start, "walk")
	var stuck := 0
	for i in surfaces.size():
		var s: Dictionary = surfaces[i]
		if s.kind != "platform" and not s.island and not walk_reach[i]:
			stuck += 1
			print("   Bodengegner kommen nicht hin: ", s)
	_check(stuck == 0, "%s: Bodengegner erreichen alle Spawn-Flaechen zu Fuss" % label)
	_check(layout.ground.size() > 10 and layout.air.size() >= 1, "%s: Spawnpunkte vorhanden (%d Boden)" % [label, layout.ground.size()])
	# Bodenpunkte duerfen nicht in Bloecken liegen.
	var buried := 0
	for point: Vector2 in layout.ground:
		for rect: Rect2 in layout.solids:
			if rect.grow(-2.0).has_point(point + Vector2(0.0, -20.0)):
				buried += 1
				print("   Spawnpunkt im Fels: ", point, " in ", rect)
	_check(buried == 0, "%s: keine Spawnpunkte im Fels (%d)" % [label, buried])


# ---------------------------------------------------------------- Hauptlauf

func _start_main(stage: String, classes: Array) -> void:
	if main != null:
		main.queue_free()
		await get_tree().process_frame
	Engine.set_meta("classes", classes)
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	main.stage_id = stage
	add_child(main)
	await _frames(15)
	for p in main.players:
		p.iframes = 0.0


func _run() -> void:
	for id in Stages.IDS:
		_validate_layout(id, false)
		_validate_layout(id, true)

	# Aufbau in der Hauptszene.
	await _start_main("", ["roomba", "hexapod"])
	_check(not main.stage_layout.is_empty() and main.arena_size == Stages.SIZE, "Hauptszene baut die Karte (%s)" % main.stage_layout.name)
	var p1: Player = main.players[0]
	var p2: Player = main.players[1]
	_check(p1.is_on_floor() and p2.is_on_floor(), "Beide Spieler stehen am Start auf dem Boden")
	_check(get_tree().get_nodes_in_group("ropes").size() >= 3, "Seile sind gebaut (%d)" % get_tree().get_nodes_in_group("ropes").size())

	# Seil klettern: am unteren Ende greifen, hoch, oben auf den Rand hopsen.
	var rope: Rect2 = Rect2()
	for node in get_tree().get_nodes_in_group("ropes"):
		var r: Rect2 = node.get_meta("rect")
		if r.size.y > rope.size.y:
			rope = r
	var start_y := rope.end.y - float(p1.stats.size.y) * 0.5 - 2.0
	p1.global_position = Vector2(rope.get_center().x, start_y)
	p1.velocity = Vector2.ZERO
	await _frames(5)
	Input.action_press("p1_up")
	await _frames(20)
	_check(p1.on_rope, "Hoch am Seil greift zu")
	var y_before := p1.global_position.y
	await _frames(40)
	_check(p1.global_position.y < y_before - 150.0, "Am Seil klettert man nach oben (%d -> %d)" % [y_before, p1.global_position.y])
	for i in 400:
		await get_tree().physics_frame
		if not p1.on_rope:
			break
	Input.action_release("p1_up")
	await _frames(30)
	_check(not p1.on_rope and p1.global_position.y < rope.position.y + 40.0, "Oben hopst man auf den Rand (y=%d, Seiloberkante %d)" % [p1.global_position.y, rope.position.y])

	# Sprung vom Seil.
	p1.global_position = Vector2(rope.get_center().x, rope.position.y + 300.0)
	p1.velocity = Vector2.ZERO
	p1.on_rope = true
	p1._rope_rect = rope
	p1._rope_x = rope.get_center().x
	await _frames(3)
	Input.action_press("p1_right")
	Input.action_press("p1_jump")
	await _frames(4)
	Input.action_release("p1_jump")
	Input.action_release("p1_right")
	_check(not p1.on_rope and p1.velocity.x > 100.0, "Sprung loest vom Seil mit Schwung (%d)" % p1.velocity.x)
	await _frames(60)

	# Spawns: Bodengegner erscheinen auf Flaechen, nicht im Fels.
	var bad := 0
	for i in 150:
		for kind in ["walker", "brute", "flyer", "shooter"]:
			var pos: Vector2 = main.director._spawn_position(kind)
			if Stages.point_in_terrain(main.stage_layout, pos):
				bad += 1
				if bad < 6:
					print("   Spawn im Fels: ", kind, " ", pos, " Karte ", main.stage_layout.id)
	_check(bad == 0, "Keine Spawns im Fels (%d)" % bad)

	# Beute faellt auf Stege und Felsen statt durchzufallen.
	var platform: Rect2 = main.stage_layout.platforms[0]
	main._spawn_pickup("gold", 1, Vector2(platform.get_center().x, platform.position.y - 200.0))
	var coin: Pickup = main.pickups.get_child(main.pickups.get_child_count() - 1)
	coin.players = []
	await _frames(90)
	_check(absf(coin.position.y - (platform.position.y - 8.0)) < 14.0, "Beute bleibt auf dem Steg liegen (y=%d, Steg %d)" % [coin.position.y, platform.position.y])

	# Kartenwechsel nach drei Wellen.
	var old_id: String = main.stage_layout.id
	main.wave = 3
	main.phase = main.Phase.SHOP
	main._on_shop_closed()
	await _frames(5)
	_check(main.wave == 4 and main.stage_layout.id != old_id, "Nach Welle 3 wechselt die Karte (%s -> %s)" % [old_id, main.stage_layout.id])
	var start_pos: Vector2 = main.stage_layout.starts[0]
	_check(p1.global_position.distance_to(start_pos) < 200.0, "Spieler stehen am Start der neuen Karte (%d)" % p1.global_position.distance_to(start_pos))

	# Abstandsleine: Ein Spieler kann sich nicht weiter als die Kamera zeigt entfernen.
	p1.global_position = Vector2(500.0, 1800.0)
	p2.global_position = Vector2(500.0 + 5000.0, 1800.0)
	await _frames(3)
	_check(absf(p1.global_position.x - p2.global_position.x) <= main.TETHER.x + 5.0, "Abstandsleine haelt die Spieler im Bild (%d)" % absf(p1.global_position.x - p2.global_position.x))

	# Alte Halle bleibt fuer Tests verfuegbar.
	await _start_main("classic", ["roomba", "hexapod"])
	_check(main.stage_layout.is_empty() and main.arena_size == main.ARENA_SIZE, "classic ist die alte flache Halle")

	print("Fertig, Fehler: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
