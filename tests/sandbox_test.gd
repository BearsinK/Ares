extends Node
## Test des Sandbox-Modus: Einstellung, Titelmenue und Anwendung in der Hauptszene.
## Ausfuehren: godot --headless --path . res://tests/sandbox_test.tscn

var failures := 0


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("OK    ", message)
	else:
		print("FEHLER ", message)
		failures += 1


func _tap(action: String) -> void:
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func _ready() -> void:
	_run.call_deferred()


func _row(config: Dictionary, index: int, class_id: String, kind: String, id := "") -> Dictionary:
	for row in SandboxConfig.rows(config, index, class_id):
		if row.kind == kind and (id == "" or row.get("id", "") == id):
			return row
	return {}


func _run() -> void:
	# Einstellung: Werte aendern sich und bleiben in Grenzen.
	var config := SandboxConfig.default_config(["vending", "hexapod"])
	_check(config.players[0].weapons == ["can"] and config.players[1].weapons == ["turret"], "Start mit der Klassenwaffe")
	SandboxConfig.change(config, 0, "vending", _row(config, 0, "vending", "perk", "overclock"), 1)
	SandboxConfig.change(config, 0, "vending", _row(config, 0, "vending", "perk", "overclock"), 1)
	_check(config.players[0].perks.overclock == 2, "Perk-Stapel zaehlt hoch")
	for i in 10:
		SandboxConfig.change(config, 0, "vending", _row(config, 0, "vending", "perk", "overclock"), 1)
	_check(config.players[0].perks.overclock == SandboxConfig.MAX_PERK_STACK, "Perk-Stapel hat eine Obergrenze")
	SandboxConfig.change(config, 1, "hexapod", _row(config, 1, "hexapod", "firmware", "hook"), 1)
	SandboxConfig.change(config, 1, "hexapod", _row(config, 1, "hexapod", "firmware", "hook"), 1)
	_check(config.players[1].firmware.hook == 1, "Firmware hat ihr Maximum")
	var slot2 := {"kind": "weapon", "slot": 1}
	SandboxConfig.change(config, 0, "vending", slot2, 1)
	_check(config.players[0].weapons.size() == 2 and config.players[0].modules.size() == 2, "Zweite Waffe belegt einen Slot")
	SandboxConfig.change(config, 0, "vending", {"kind": "module", "slot": 1}, 1)
	_check(Elements.IDS.has(config.players[0].modules[1]), "Modul fuer die zweite Waffe waehlbar")
	SandboxConfig.change(config, 0, "vending", slot2, -1)
	_check(config.players[0].weapons.size() == 1, "Leerer Slot gibt die Waffe wieder frei")
	var choices := SandboxConfig.weapon_choices("roomba")
	_check(not choices.has("can") and not choices.has("turret") and choices[0] == "dust", "Roomba bekommt keine Klassenwaffen anderer Klassen")
	_check(SandboxConfig.weapon_choices("vending").has("can"), "Automat darf Soda Bomb waehlen")

	# Anwendung in der Hauptszene.
	config = SandboxConfig.default_config(["roomba", "printer"])
	config.wave = 4
	config.gold = 1000
	config.god = true
	config.players[0].perks.overclock = 2
	config.players[1].firmware.double_jump = 2
	config.players[1].weapons = ["dronegun", "rocket"]
	config.players[1].modules = ["", "ice"]
	Engine.set_meta("sandbox", config)
	Engine.set_meta("classes", ["roomba", "printer"])
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	main.stage_id = "classic"
	add_child(main)
	await _frames(10)
	var p1: Player = main.players[0]
	var p2: Player = main.players[1]
	_check(main.sandbox and main.wave == 4, "Sandbox startet in Welle 4 (%d)" % main.wave)
	_check(p1.gold == 1000 and p2.gold == 1000, "Startgold gesetzt")
	_check(float(p1.mods.fire_rate) >= 0.4 - 0.001, "Perks wurden angewendet (%.2f)" % float(p1.mods.fire_rate))
	_check(p2.fw("double_jump") == 2 and p2.weapons == ["dronegun", "rocket"] and p2.modules[1] == "ice", "Waffen, Module und Firmware uebernommen")
	var hp := p1.hp
	p1.iframes = 0.0
	p1.take_hit(50.0, p1.global_position + Vector2(10, 0))
	_check(p1.hp == hp, "Unverwundbar: kein Schaden")
	main._record_run(false)
	_check(main.run_chips == 0, "Sandbox vergibt keine Chips")
	main.queue_free()
	Engine.remove_meta("sandbox")
	await get_tree().process_frame

	# Titelmenue: Sandbox -> Klassenwahl -> Einstellungen.
	Engine.set_meta("classes", ["roomba", "hexapod"])
	var title: Node = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await _frames(5)
	await _tap("p1_down")
	_check(title.MENU_ITEMS[title.cursor] == "Sandbox", "Menue hat den Eintrag Sandbox")
	await _tap("p1_confirm")
	_check(title.state == title.State.SELECT and title.sandbox_mode, "Sandbox oeffnet zuerst die Klassenwahl")
	await _tap("p1_confirm")
	await _tap("p2_confirm")
	await _frames(int(title.COUNTDOWN * 60.0) + 20)
	_check(title.state == title.State.SANDBOX, "Danach folgt die Einstellung")
	await _tap("p1_right")
	_check(title.sandbox_config.wave == 2, "P1 aendert die Startwelle mit rechts")
	for i in 20:
		await _tap("p1_down")
	var last: Dictionary = SandboxConfig.rows(title.sandbox_config, 0, "roomba")[title.sandbox_cursor[0]]
	_check(last.kind == "ready" or title.sandbox_cursor[0] > 10, "Runter laeuft durch die Liste (Zeile %d)" % title.sandbox_cursor[0])
	title.set_process(false)
	title.queue_free()
	await get_tree().process_frame

	print("Fertig, Fehler: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
