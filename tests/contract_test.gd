extends Node
## Test der Vertragswahl vor jeder Welle (sicher oder riskant mit Gold-Praemie).
## Ausfuehren: godot --headless --path . res://tests/contract_test.tscn

var failures := 0
var main: Node


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


func _run() -> void:
	# Reine Daten: Angebote und Gold-Faktoren.
	var valid := true
	for i in 100:
		var previous: String = WaveModifiers.POOL[i % WaveModifiers.POOL.size()]
		var offers := WaveModifiers.offers(previous)
		valid = valid and offers.size() == 3 and offers[0] == "normal" and not offers.has(previous) and offers[1] != offers[2]
		for id in offers:
			valid = valid and WaveModifiers.DATA.has(id)
	_check(valid, "Angebote: Standard plus zwei verschiedene Vertraege, nie der letzte")
	_check(is_equal_approx(WaveModifiers.gold_factor("normal"), 1.0), "Standard gibt keine Praemie")
	_check(is_equal_approx(WaveModifiers.gold_factor("swarm"), 1.3) and is_equal_approx(WaveModifiers.gold_factor("armor"), 2.0), "Praemien: Swarm +30%%, Heavy Metal doppelt (%.2f / %.2f)" % [WaveModifiers.gold_factor("swarm"), WaveModifiers.gold_factor("armor")])
	var risky_pays := true
	for id in WaveModifiers.POOL:
		risky_pays = risky_pays and WaveModifiers.gold_factor(id) > 1.0
	_check(risky_pays, "Jeder riskante Vertrag zahlt mehr als der Standard")

	Engine.set_meta("classes", ["roomba", "hexapod"])
	main = load("res://scenes/main.tscn").instantiate()
	main.stage_id = "classic"
	add_child(main)
	await _frames(10)
	main.wave_intro = 0.0
	main.director.enabled = false

	# Shop zu: statt sofort loszulegen erscheint die Vertragswahl.
	main.wave = 1
	main.phase = main.Phase.SHOP
	main.gates.close()
	await _frames(70)
	_check(main.gates.is_closed, "Die Tore sind zu")
	main._on_shop_closed()
	var menu: ContractMenu = main.contract_menu
	_check(menu.is_open and get_tree().paused, "Nach dem Shop oeffnet sich die Vertragswahl und haelt das Spiel an")
	_check(main.wave == 2 and main.phase == main.Phase.SHOP and not main.director.enabled, "Die Welle hat noch nicht begonnen")
	_check(menu.perk_ids.size() == 3 and menu.perk_ids[0] == "normal", "Drei Vertraege, der erste ist der Standard (%s)" % str(menu.perk_ids))
	_check(main.gates.is_closed, "Die Tore bleiben waehrend der Wahl zu")
	var ids: Array[String] = menu.perk_ids.duplicate()

	# Beide waehlen den dritten Vertrag.
	await _frames(40)
	for i in 2:
		await _tap("p1_right")
	for i in 2:
		await _tap("p2_right")
	Input.action_press("p1_confirm")
	Input.action_press("p2_confirm")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("p1_confirm")
	Input.action_release("p2_confirm")
	await _frames(5)
	_check(not menu.is_open and not get_tree().paused, "Einigen sich beide, geht es los")
	_check(main.wave_modifier == ids[2] and main.phase == main.Phase.WAVE, "Der gewaehlte Vertrag gilt (%s)" % main.wave_modifier)
	_check(str(main.director.modifier.get("name")) == str(WaveModifiers.DATA[ids[2]].name), "Der Director bekommt den Vertrag (%s)" % str(main.director.modifier.get("name")))
	_check(main.wave_intro > 0.0, "Danach laeuft der Wellen-Einstieg")
	_check(is_equal_approx(main.contract_bonus, float(WaveModifiers.DATA[ids[2]].bonus)), "Die Praemie des gewaehlten Vertrags gilt (%.2f)" % main.contract_bonus)
	await _frames(70)
	_check(not main.gates.is_closed, "Die Tore oeffnen sich")

	# Die letzte Welle vor dem Boss ist immer die Elite-Welle, ohne Wahl.
	main.wave = main.max_waves - 1
	main.phase = main.Phase.SHOP
	main._on_shop_closed()
	await _frames(3)
	_check(not menu.is_open and main.wave_modifier == "elites", "Die letzte Welle ist fest: Elite Rush ohne Wahl")
	_check(is_equal_approx(main.contract_bonus, 0.0), "Ohne gewaehlten Vertrag gibt es keine Praemie")

	# Vor dem Endboss gibt es keine Wahl.
	main.wave = main.max_waves
	main.phase = main.Phase.SHOP
	main._on_shop_closed()
	await _frames(3)
	_check(not menu.is_open and main.phase == main.Phase.BOSS, "Der Bosskampf beginnt ohne Vertragswahl")

	# Mit ausgeschaltetem Wellen-Einstieg (Tests) bleibt der Zufall.
	var plain: Node = load("res://scenes/main.tscn").instantiate()
	plain.intro_enabled = false
	plain.stage_id = "classic"
	add_child(plain)
	await _frames(5)
	plain.wave = 1
	plain.phase = plain.Phase.SHOP
	plain._on_shop_closed()
	_check(not plain.contract_menu.is_open and plain.phase == plain.Phase.WAVE, "Ohne Einstieg startet die naechste Welle direkt")
	plain.queue_free()

	print("Fertig, Fehler: ", failures)
	main.queue_free()
	get_tree().quit(1 if failures > 0 else 0)
