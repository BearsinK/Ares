extends Node
## Test des Archivs: Eintraege vollstaendig, Entdecken und Zaehlen im Spielstand, Meldungen im Spiel, Seite im Titel.
## Ausfuehren: godot --headless --path . res://tests/archive_test.tscn

var failures := 0


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


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## Wartet (in Echtzeit, hoechstens timeout Sekunden), bis die Bedingung gilt.
func _until(condition: Callable, timeout := 4.0) -> void:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await get_tree().physics_frame
		waited += 1.0 / 60.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_data()
	_save()
	await _in_game()
	await _title()
	print("Fertig, Fehler: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


func _data() -> void:
	var items := Archive.entries("items")
	var enemies := Archive.entries("enemies")
	var weapons := Archive.entries("weapons")
	_check(items.size() == Perks.DATA.size(), "Jedes Item hat einen Archiv-Eintrag (%d)" % items.size())
	_check(weapons.size() == Weapons.ALL_IDS.size(), "Jede Waffe hat einen Archiv-Eintrag (%d)" % weapons.size())
	var covered := true
	for kind in EnemyTypes.DATA:
		if not Archive.ENEMY_ORDER.has(kind):
			covered = false
	_check(covered and enemies.size() == Archive.ENEMY_ORDER.size(), "Jeder Gegnertyp ist im Archiv (%d Eintraege)" % enemies.size())
	for kind in Archive.KINDS:
		var seen := {}
		var complete := true
		for entry in Archive.entries(kind):
			if String(entry.name) == "" or String(entry.text).length() < 8 or seen.has(entry.id):
				complete = false
				print("  unvollstaendig: ", entry.id, " '", entry.text, "'")
			seen[entry.id] = true
		_check(complete, "Eintraege der Art %s haben Namen und Text, ohne Doppelte" % kind)
	_check(Archive.entry_name("enemies", "medic") == "Medic" and Archive.entry_name("items", "frenzy") != "frenzy", "Namen lassen sich nachschlagen")


func _save() -> void:
	SaveData.reset()
	_check(not SaveData.archive_has("items", "frenzy") and SaveData.archive_count("items") == 0, "Neuer Spielstand: nichts entdeckt")
	_check(SaveData.archive_discover("items", "frenzy"), "Erstes Entdecken meldet neu")
	_check(not SaveData.archive_discover("items", "frenzy"), "Zweites Entdecken meldet nicht neu")
	_check(SaveData.archive_has("items", "frenzy") and SaveData.archive_count("items") == 1, "Item ist eingetragen")
	_check(SaveData.archive_discover("enemies", "walker") and SaveData.archive_kills("walker") == 0, "Gesehener Gegner hat 0 Besiegte")
	SaveData.archive_add_kill("walker")
	SaveData.archive_add_kill("walker")
	_check(SaveData.archive_kills("walker") == 2 and SaveData.archive_has("enemies", "walker"), "Besiegte werden gezaehlt")
	SaveData.archive_add_kill("brute")
	_check(SaveData.archive_has("enemies", "brute"), "Ein Kill traegt den Gegner auch ein")
	var p := Archive.progress("enemies")
	_check(p.x == 2 and p.y == Archive.ENEMY_ORDER.size(), "Fortschritt zaehlt entdeckte Eintraege (%d/%d)" % [p.x, p.y])
	SaveData.reset()


func _in_game() -> void:
	SaveData.reset()
	Engine.set_meta("classes", ["roomba", "hexapod"])
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	main.stage_id = "classic"
	add_child(main)
	await _frames(5)
	var p1: Player = main.players[0]
	var hud: Hud = main.hud
	await _until(func() -> bool: return SaveData.archive_has("weapons", p1.weapons[0]))
	_check(SaveData.archive_has("weapons", p1.weapons[0]), "Startwaffe ist im Archiv")
	_check(hud._notices.size() >= 1, "Neuer Eintrag meldet sich im HUD")
	_check(hud._notices.size() <= 3, "Hoechstens drei Meldungen gleichzeitig")

	p1.add_item("frenzy")
	var medic: Enemy = main.director.spawn("medic", p1.global_position + Vector2(600.0, 0.0))
	var elite: Enemy = main.director.spawn("walker", p1.global_position + Vector2(-600.0, 0.0), true)
	var walker: Enemy = main.director.spawn("walker", p1.global_position + Vector2(800.0, 0.0))
	await _until(func() -> bool: return SaveData.archive_has("items", "frenzy") and SaveData.archive_has("enemies", "walker") and SaveData.archive_has("enemies", "elite"))
	_check(SaveData.archive_has("items", "frenzy"), "Neues Item wird eingetragen")
	_check(SaveData.archive_has("enemies", "medic"), "Gesehener Medic wird eingetragen")
	_check(SaveData.archive_has("enemies", "elite") and not SaveData.archive_has("enemies", "guardian"), "Elite zaehlt als eigener Eintrag")
	_check(SaveData.archive_has("enemies", "walker"), "Grunt wird eingetragen")
	walker.take_damage(99999.0, p1, Vector2.RIGHT, "")
	await _frames(3)
	_check(SaveData.archive_kills("walker") == 1, "Besiegter Grunt wird gezaehlt")
	elite.take_damage(99999.0, p1, Vector2.RIGHT, "")
	await _frames(3)
	_check(SaveData.archive_kills("elite") == 1 and SaveData.archive_kills("walker") == 1, "Elite zaehlt getrennt vom Grunt")
	# Sofort besiegter Gegner: erst Meldung, dann Zaehlung.
	var shooter: Enemy = main.director.spawn("shooter", p1.global_position + Vector2(900.0, 0.0))
	shooter.take_damage(99999.0, p1, Vector2.RIGHT, "")
	await _frames(3)
	var announced := false
	for notice in hud._notices:
		announced = announced or (notice.kind == "enemies" and notice.id == "shooter")
	_check(announced and SaveData.archive_kills("shooter") == 1, "Sofort besiegter Gegner meldet sich im Archiv und wird gezaehlt")
	if is_instance_valid(medic):
		medic.queue_free()
	main.queue_free()
	await get_tree().process_frame
	SaveData.reset()


func _title() -> void:
	SaveData.reset()
	SaveData.archive_discover("items", "frenzy")
	Engine.set_meta("classes", ["roomba", "hexapod"])
	var title: Node = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().create_timer(0.3, true, false, true).timeout
	var index: int = title.MENU_ITEMS.find("Archiv")
	_check(index >= 0, "Titelmenue hat den Eintrag Archiv")
	for i in index:
		await _tap("p1_down")
	await _tap("p1_confirm")
	_check(title.state == title.State.ARCHIVE, "Archiv oeffnet die Seite")
	var page: ArchivePage = title.archive
	_check(page.kind() == "items" and page.cursor == 0, "Startet bei den Items")
	await _tap("p1_down")
	await _tap("p1_down")
	_check(page.cursor == 2, "Runter waehlt den naechsten Eintrag")
	await _tap("p2_right")
	_check(page.kind() == "enemies" and page.cursor == 0, "Rechts wechselt zu den Gegnern, Cursor oben")
	await _tap("p1_left")
	await _tap("p1_left")
	_check(page.kind() == "weapons", "Links laeuft im Kreis bis zu den Waffen")
	await _tap("p1_up")
	_check(page.cursor == page.entries().size() - 1, "Hoch vom ersten Eintrag springt ans Ende")
	await _tap("p1_interact")
	_check(title.state == title.State.MAIN, "Kreis schliesst das Archiv")
	title.set_process(false)
	title.queue_free()
	await get_tree().process_frame
	SaveData.reset()
