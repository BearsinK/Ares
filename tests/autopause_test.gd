extends Node
## Test der Auto-Pause: Fokusverlust und getrennter Controller pausieren das Spiel mit Hinweis.
## Ausfuehren: godot --headless --path . res://tests/autopause_test.tscn

var failures := 0


func _check(condition: bool, message: String) -> void:
	if condition:
		print("OK    ", message)
	else:
		print("FEHLER ", message)
		failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveData.reset()
	Engine.set_meta("classes", ["roomba", "hexapod"])
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	main.stage_id = "classic"
	add_child(main)
	await _frames(10)
	var menu: PauseMenu = main.pause_menu
	_check(SaveData.autopause_enabled(), "Auto-Pause ist standardmaessig an")

	# Controller 1 war beim Start da und faellt aus.
	main._pads_at_start = [0]
	main._on_joy_connection_changed(0, false)
	_check(menu.is_open() and get_tree().paused, "Getrennter Controller pausiert das Spiel")
	_check(menu.note.contains("Spieler 1") and menu.note.contains("getrennt"), "Der Hinweis nennt den Spieler (%s)" % menu.note)
	main._on_joy_connection_changed(0, true)
	_check(menu.note.contains("wieder verbunden"), "Wieder verbunden wird gemeldet (%s)" % menu.note)
	menu.close()
	_check(menu.note == "" and not get_tree().paused, "Schliessen raeumt den Hinweis auf")

	# Ein Controller, der nie da war, loest nichts aus.
	main._on_joy_connection_changed(1, false)
	_check(not menu.is_open(), "Ein unbekannter Controller pausiert nicht")

	# Fokusverlust.
	main._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(menu.is_open() and menu.note != "", "Fensterfokus weg pausiert (%s)" % menu.note)
	main._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(menu.is_open(), "Zweimal Fokusverlust stapelt nichts")
	menu.close()

	# Abgeschaltet in den Optionen.
	SaveData.set_autopause(false)
	main._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	main._on_joy_connection_changed(0, false)
	_check(not menu.is_open(), "Mit ausgeschalteter Auto-Pause bleibt das Spiel laufen")
	SaveData.set_autopause(true)

	# Nicht im Shop, nicht nach dem Ende.
	main.phase = main.Phase.SHOP
	main._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not menu.is_open(), "Im Shop gibt es nichts zu pausieren")
	main.phase = main.Phase.WAVE
	main.game_over = true
	main._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not menu.is_open(), "Nach dem Ende auch nicht")
	main.game_over = false

	# Optionsseite kennt den Schalter.
	var page := OptionsPage.new()
	_check(page.value_text("autopause") == "An", "Optionen zeigen Auto-Pause")
	page.change("autopause", 1)
	_check(not SaveData.autopause_enabled() and page.value_text("autopause") == "Aus", "Der Schalter schaltet um")
	SaveData.reset()

	print("Fertig, Fehler: ", failures)
	main.queue_free()
	get_tree().quit(1 if failures > 0 else 0)
