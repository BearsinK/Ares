extends Node
## Test der Kisten auf den grossen Karten: Platzierung, Preis, Oeffnen mit Gold, Belohnung, Kartenwechsel.
## Ausfuehren: godot --headless --path . res://tests/chest_test.tscn

var failures := 0
var main: Node
var p1: Player
var p2: Player


func _check(condition: bool, message: String) -> void:
	if condition:
		print("OK    ", message)
	else:
		print("FEHLER ", message)
		failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func _ready() -> void:
	_run.call_deferred()


func _live() -> Array[Chest]:
	var result: Array[Chest] = []
	for chest in main.chests.get_children():
		if chest is Chest and not chest is Altar and not chest.is_open and not chest.is_queued_for_deletion():
			result.append(chest)
	return result


func _altars() -> Array[Altar]:
	var result: Array[Altar] = []
	for chest in main.chests.get_children():
		if chest is Altar and not chest.is_open and not chest.is_queued_for_deletion():
			result.append(chest)
	return result


func _run() -> void:
	Engine.set_meta("classes", ["roomba", "hexapod"])

	# Flache Testhalle: keine Kisten.
	var flat: Node = load("res://scenes/main.tscn").instantiate()
	flat.director_enabled = false
	flat.intro_enabled = false
	flat.stage_id = "classic"
	add_child(flat)
	await _frames(5)
	_check(flat.chests.get_child_count() == 0, "Die flache Testhalle hat keine Kisten")
	flat.queue_free()
	await _frames(3)

	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	main.stage_id = "basin"
	add_child(main)
	await _frames(20)
	p1 = main.players[0]
	p2 = main.players[1]

	var chests := _live()
	_check(chests.size() >= 3 and chests.size() <= 5, "Auf der grossen Karte liegen Kisten (%d)" % chests.size())
	var large := 0
	for chest in chests:
		if chest.large:
			large += 1
	_check(large == 1, "Genau eine grosse Goldkiste pro Karte")
	var spaced := true
	for i in chests.size():
		for j in range(i + 1, chests.size()):
			if chests[i].position.distance_to(chests[j].position) < 699.0:
				spaced = false
	_check(spaced, "Kisten liegen weit auseinander")
	var on_ground := true
	for chest in chests:
		var found := false
		for point: Vector2 in main.stage_layout.ground:
			if point.distance_to(chest.position) < 1.0:
				found = true
		on_ground = on_ground and found
	_check(on_ground, "Kisten stehen auf begehbaren Flaechen")
	var small: Chest = null
	var big: Chest = null
	for chest in chests:
		if chest.large:
			big = chest
		else:
			small = chest
	_check(big.price > small.price * 2 and small.price == main.chest_price(false), "Die Goldkiste kostet mehr (%d gegen %d)" % [big.price, small.price])

	# Zu wenig Gold: nichts passiert.
	p1.gold = 0
	p1.global_position = small.global_position + Vector2(0.0, -30.0)
	p2.global_position = small.global_position + Vector2(-1500.0, -30.0)
	await _frames(3)
	await _tap("p1_interact")
	_check(not small.is_open and p1.items.is_empty(), "Ohne genug Gold bleibt die Kiste zu")

	# Genug Gold: Kiste geht auf, Gold weg, Item drin.
	p1.gold = 500
	var price := small.price
	await _tap("p1_interact")
	_check(small.is_open and p1.gold == 500 - price, "Mit Gold geht sie auf und kostet den Preis (%d)" % p1.gold)
	var count := 0
	for id in p1.items:
		count += int(p1.items[id])
	_check(count == 1, "Der Oeffner bekommt genau ein Item (%s)" % str(p1.items))
	_check(p2.items.is_empty(), "Der Partner geht leer aus")
	_check(main.chests_opened == 1, "Der Zaehler steigt")
	var next_price: int = main.chest_price(false)
	_check(next_price > price or main.chest_price(false) == int(round((10.0 + 4.0 * main.wave) * 1.1)), "Jede geoeffnete Kiste macht die naechsten teurer (%d)" % next_price)
	await _frames(10)
	await _tap("p1_interact")
	_check(p1.gold == 500 - price, "Eine offene Kiste lässt sich nicht noch mal oeffnen")

	# Wiederbeleben hat Vorrang vor Oeffnen.
	var other: Chest = null
	for chest in _live():
		if chest != big:
			other = chest
			break
	if other != null:
		p1.global_position = other.global_position + Vector2(0.0, -30.0)
		p2.global_position = p1.global_position + Vector2(50.0, 0.0)
		p2.hp = 0.0
		p2.downed = true
		var gold_before := p1.gold
		await _tap("p1_interact")
		_check(not other.is_open and p1.gold == gold_before, "Wiederbeleben geht vor Kiste oeffnen")
		p2.revive(1.0)

	# Die grosse Kiste enthaelt immer ein Verhaltens-Item.
	p2.global_position = big.global_position + Vector2(0.0, -30.0)
	p2.gold = 500
	p1.global_position = big.global_position + Vector2(-1500.0, -30.0)
	await _frames(3)
	await _tap("p2_interact")
	var rare := false
	for id in p2.items:
		rare = rare or Perks.RARE_IDS.has(id)
	_check(big.is_open and rare, "Die Goldkiste enthaelt ein Verhaltens-Item (%s)" % str(p2.items))

	# Naechste Welle: neue Kisten fuellen auf, Preise steigen mit der Welle.
	await _frames(300)
	main.wave = 3
	main._refresh_chests()
	var after := _live()
	_check(after.size() >= 3, "Nach dem Auffuellen liegen wieder Kisten (%d)" % after.size())
	_check(after[0].price == main.chest_price(after[0].large), "Preise folgen der Welle (%d)" % after[0].price)

	# Kartenwechsel: alte Kisten weg, neue Karte hat neue.
	main.wave = 4
	main._change_stage()
	await _frames(3)
	main._refresh_chests()
	await _frames(3)
	_check(main.chests_opened == 0 and _live().size() >= 3, "Neue Karte, neue Kisten (%d)" % _live().size())
	var larges := 0
	for chest in _live():
		if chest.large:
			larges += 1
	_check(larges == 1, "Auch die neue Karte hat eine Goldkiste")

	# Altaere: Blut gegen Gold, Glueck gegen Item.
	main.wave = 4
	main._refresh_chests()
	var altars := _altars()
	_check(altars.size() == 2 and altars[0].kind != altars[1].kind, "Ab Welle 4 stehen zwei verschiedene Altaere da (%d)" % altars.size())
	var blood: Altar = null
	var luck: Altar = null
	for altar in altars:
		if altar.kind == "blood":
			blood = altar
		else:
			luck = altar
	p1.global_position = blood.global_position + Vector2(0.0, -30.0)
	p2.global_position = blood.global_position + Vector2(-1800.0, -30.0)
	p1.hp = p1.max_health()
	p1.gold = 0
	await _frames(3)
	await _tap("p1_interact")
	_check(is_equal_approx(p1.hp, p1.max_health() * 0.7) and p1.gold == 16 + 6 * main.wave, "Blutaltar: 30%% Leben gegen Gold (HP %.0f, Gold %d)" % [p1.hp, p1.gold])
	_check(blood.uses_left == 2 and not blood.is_open, "Der Altar bleibt nutzbar (%d Nutzungen uebrig)" % blood.uses_left)
	p1.hp = p1.max_health()
	await _tap("p1_interact")
	_check(blood.uses_left == 1 and not blood.is_open, "Zweite Nutzung (%d uebrig)" % blood.uses_left)
	p1.hp = p1.max_health()
	await _tap("p1_interact")
	_check(blood.uses_left == 0 and blood.is_open, "Nach drei Nutzungen ist der Altar leer")
	var spent_gold := p1.gold
	await _tap("p1_interact")
	_check(p1.gold == spent_gold, "Ein leerer Altar tut nichts mehr")
	main._refresh_chests()
	var again := 0
	for altar in _altars():
		if altar.kind == "blood":
			again += 1
	_check(again == 0, "Ein benutzter Altar wird nicht ersetzt")
	# Zu wenig Leben: verweigert (neuer Altar dazu).
	var low_gold := p1.gold
	p1.hp = p1.max_health() * 0.35
	var guarded: Altar = null
	for altar in _altars():
		guarded = altar if altar.kind == "chance" else guarded
	if guarded != null:
		guarded.kind = "blood"
		guarded.uses_left = 3
		p1.global_position = guarded.global_position + Vector2(0.0, -30.0)
		await _frames(3)
		await _tap("p1_interact")
		_check(p1.gold == low_gold and is_equal_approx(p1.hp, p1.max_health() * 0.35), "Zu wenig Leben: der Altar verweigert (Gold %d)" % p1.gold)
		guarded.kind = "chance"
		luck = guarded

	# Gluecksaltar: erzwungene Wuerfe.
	p2.global_position = luck.global_position + Vector2(0.0, -30.0)
	p1.global_position = luck.global_position + Vector2(-1800.0, -30.0)
	p2.gold = 1000
	main.chance_roll_override = 0.9
	var luck_price := luck.price
	var items_before := 0
	for id in p2.items:
		items_before += int(p2.items[id])
	await _frames(3)
	await _tap("p2_interact")
	var items_unlucky := 0
	for id in p2.items:
		items_unlucky += int(p2.items[id])
	_check(p2.gold == 1000 - luck_price and items_unlucky == items_before, "Gluecksaltar: Pech kostet Gold und gibt nichts (%d)" % p2.gold)
	_check(luck.price > luck_price and luck.uses_left == 2, "Jede Nutzung macht ihn teurer (%d -> %d)" % [luck_price, luck.price])
	main.chance_roll_override = 0.1
	await _tap("p2_interact")
	var got := 0
	for id in p2.items:
		got += int(p2.items[id])
	_check(got == items_before + 1, "Mit Glueck faellt ein Item heraus (%s)" % str(p2.items))
	main.chance_roll_override = -1.0

	# Kartenwechsel und Auffuellen im selben Frame (ohne Vertragswahl): alte Kisten zaehlen nicht mehr mit.
	main.wave = 7
	main._change_stage()
	main._refresh_chests()
	var fresh := 0
	for chest in main.chests.get_children():
		if chest is Chest and not chest.is_queued_for_deletion():
			fresh += 1
	_check(fresh >= 4, "Gleich nach dem Kartenwechsel liegen die neuen Kisten (%d)" % fresh)

	# Nach dem Oeffnen der grossen Kiste fuellt sich nicht mehr als das Soll auf.
	for chest in main.chests.get_children():
		if chest is Chest and chest.large:
			chest.force_open(p1)
	main._refresh_chests()
	var normal := 0
	for chest in main.chests.get_children():
		if chest is Chest and not chest is Altar and not chest.is_open and not chest.large and not chest.is_queued_for_deletion():
			normal += 1
	_check(normal <= mini(4, 2 + (main.wave - 1) / 2), "Normale Kisten bleiben beim Soll (%d)" % normal)

	# Boss: keine Kisten.
	main._start_boss()
	await _frames(5)
	_check(_live().is_empty(), "Im Bosskampf gibt es keine Kisten")

	print("Fertig, Fehler: ", failures)
	main.queue_free()
	get_tree().quit(1 if failures > 0 else 0)
