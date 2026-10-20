extends Node
## Test von Titelbildschirm, Pausemenue und Ergebnisbildschirm.
## Ausfuehren: godot --headless --path . res://tests/menu_test.tscn

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


func _escape() -> void:
	await get_tree().process_frame
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _title()
	await _pause_and_result()
	print("Fertig, Fehler: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


func _title() -> void:
	SaveData.reset()
	SaveData.add_chips(500)
	_check(SaveData.buy_unlock("class", "printer") and SaveData.buy_unlock("class", "vending"), "Klassen lassen sich mit Chips freischalten")
	Engine.set_meta("classes", ["printer", "vending"])
	var title: Node = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await _wait(0.3)
	_check(title.picks[0] == 3 and title.picks[1] == 2, "Titel merkt sich die zuletzt gewaehlten Klassen")
	await _tap("p1_confirm")
	_check(title.state == title.State.SELECT, "Spielen oeffnet die Klassenauswahl")
	await _tap("p1_right")
	_check(title.picks[0] == 0, "P1 waehlt mit rechts die naechste Klasse (Roomba)")
	await _tap("p2_left")
	_check(title.picks[1] == 1, "P2 waehlt mit links die vorherige Klasse (Hexapod)")
	await _tap("p1_confirm")
	_check(title.locked[0] and not title.locked[1], "P1 ist bereit, P2 noch nicht")
	await _tap("p1_right")
	_check(title.picks[0] == 0, "Bereiter Spieler kann nicht mehr wechseln")
	await _tap("p1_interact")
	_check(not title.locked[0], "Kreis nimmt die Bereitschaft zurueck")
	await _tap("p1_confirm")
	await _tap("p2_confirm")
	_check(title.start_timer > 0.0, "Wenn beide bereit sind, laeuft der Start-Countdown")
	_check(UiKit.CLASS_ORDER[title.picks[0]] == "roomba" and UiKit.CLASS_ORDER[title.picks[1]] == "hexapod", "Gewaehlte Klassen stimmen")
	await _tap("p1_interact")
	_check(title.locked[0] and title.state == title.State.SELECT or title.start_timer > 0.0, "Waehrend des Countdowns bleibt man in der Auswahl")
	title.set_process(false)
	title.queue_free()
	await get_tree().process_frame


func _pause_and_result() -> void:
	Engine.set_meta("classes", ["roomba", "hexapod"])
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	add_child(main)
	await _wait(0.5)
	var menu: PauseMenu = main.pause_menu
	_check(not menu.is_open() and not get_tree().paused, "Spiel startet ohne Menue")

	await _escape()
	_check(menu.is_open() and menu.mode == PauseMenu.Mode.PAUSE and get_tree().paused, "Escape oeffnet die Pause und haelt das Spiel an")
	await _wait(0.8)
	await _tap("p1_down")
	_check(menu.cursor == 1, "Runter waehlt Steuerung")
	await _tap("p1_confirm")
	_check(menu.page == PauseMenu.Page.CONTROLS, "Steuerungsseite offen")
	await _tap("p1_interact")
	_check(menu.page == PauseMenu.Page.MAIN, "Kreis geht zurueck")
	var music_before: bool = Music.enabled
	await _tap("p2_down")
	await _tap("p2_confirm")
	_check(Music.enabled != music_before, "Musik laesst sich im Pausemenue umschalten")
	await _tap("p2_confirm")
	_check(Music.enabled == music_before, "und wieder zurueck")
	await _tap("p2_down")
	await _tap("p2_confirm")
	_check(menu.page == PauseMenu.Page.CONFIRM, "Neustart fragt nach")
	await _tap("p1_confirm")
	_check(menu.page == PauseMenu.Page.MAIN, "Nein bricht den Neustart ab")
	await _escape()
	_check(not menu.is_open() and not get_tree().paused, "Escape schliesst die Pause")

	var p1: Player = main.players[0]
	var p2: Player = main.players[1]
	p1.iframes = 0.0
	p2.iframes = 0.0
	p1.take_hit(9999.0, p1.global_position + Vector2(20.0, 0.0))
	p2.take_hit(9999.0, p2.global_position + Vector2(20.0, 0.0))
	_check(main.game_over, "Beide am Boden: Game Over")
	await _escape()
	_check(not menu.is_open() or menu.mode == PauseMenu.Mode.RESULT, "Pause ist im Game Over gesperrt")
	await _wait(2.0)
	_check(menu.is_open() and menu.mode == PauseMenu.Mode.RESULT, "Ergebnisbildschirm erscheint nach Game Over")
	_check(menu.cursor == 0 and menu._items()[0] == "Neustart", "Ergebnis bietet Neustart zuerst")
	await _tap("p1_down")
	await _tap("p1_confirm")
	_check(menu.page == PauseMenu.Page.CONFIRM and menu._pending == "title", "Hauptmenue fragt nach")
	await _tap("p2_interact")
	_check(menu.page == PauseMenu.Page.MAIN, "Kreis bricht die Rueckfrage ab")
	main.queue_free()
