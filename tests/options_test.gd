extends Node
## Test der Optionen: Lautstaerke, Wackeln, Schadenszahlen, Vibration, Bedienung im Titel.
## Ausfuehren: godot --headless --path . res://tests/options_test.tscn

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


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_values()
	_effects()
	await _title_flow()
	await _hold()
	print("Fertig, Fehler: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


func _values() -> void:
	SaveData.reset()
	_check(SaveData.volume_step("master") == 8 and SaveData.volume_step("music") == 8 and SaveData.volume_step("sfx") == 8, "Standardlautstaerke ist Stufe 8")
	_check(absf(SaveData.gain_db("sfx")) < 0.01 and absf(SaveData.gain_db("music")) < 0.01, "Standardstufen klingen wie vorher (0 dB)")
	SaveData.set_volume_step("master", 4)
	_check(SaveData.gain_db("music") < -5.0, "Halbe Gesamtlautstaerke macht Musik deutlich leiser")
	SaveData.set_volume_step("master", 10)
	_check(SaveData.gain_db("sfx") > 0.0, "Stufe 10 ist lauter als der Standard")
	SaveData.set_volume_step("sfx", 0)
	_check(SaveData.gain_db("sfx") <= -79.0 and SaveData.gain_db("music") > -79.0, "Effekte auf 0 sind stumm, Musik bleibt")
	SaveData.set_volume_step("music", 99)
	_check(SaveData.volume_step("music") == SaveData.VOLUME_STEPS, "Lautstaerke wird auf 10 begrenzt")
	SaveData.reset()
	_check(SaveData.shake_scale() == 1.0 and SaveData.numbers_enabled() and SaveData.rumble_enabled(), "Wackeln normal, Zahlen und Vibration an")
	SaveData.set_shake_level(3)
	_check(SaveData.shake_scale() == 1.5, "Wackeln Stark ist 1,5-fach")
	SaveData.set_shake_level(-4)
	_check(SaveData.shake_level() == 0 and SaveData.shake_scale() == 0.0, "Wackeln wird auf Aus begrenzt")
	SaveData.reset()


func _effects() -> void:
	SaveData.reset()
	var camera := CoopCamera.new()
	add_child(camera)
	camera.add_shake(10.0)
	_check(is_equal_approx(camera._shake, 10.0), "Kamera wackelt mit Faktor 1 voll")
	camera._shake = 0.0
	SaveData.set_shake_level(0)
	camera.add_shake(10.0)
	_check(camera._shake == 0.0, "Wackeln aus: die Kamera bleibt ruhig")
	SaveData.set_shake_level(1)
	camera.add_shake(10.0)
	_check(is_equal_approx(camera._shake, 5.0), "Wackeln wenig: halber Ausschlag")
	camera.queue_free()

	var fx := Fx.new()
	add_child(fx)
	fx.number(Vector2.ZERO, 12.0)
	_check(fx._items.size() == 1, "Schadenszahl erscheint")
	SaveData.set_numbers(false)
	fx.number(Vector2.ZERO, 12.0)
	_check(fx._items.size() == 1, "Zahlen aus: keine neue Schadenszahl")
	fx.number_text(Vector2.ZERO, "Wächter besiegt", Color.WHITE)
	_check(fx._items.size() == 2, "Hinweistexte bleiben auch ohne Schadenszahlen")
	fx.queue_free()

	# Ruhige Effekte: weniger Funken, kein Randblitz, kein Zeitlupen-Stopp.
	var fx2 := Fx.new()
	add_child(fx2)
	fx2.spark(Vector2.ZERO, Color.WHITE, 8)
	var normal_sparks: int = fx2._items.size()
	SaveData.set_calm_effects(true)
	fx2.spark(Vector2.ZERO, Color.WHITE, 8)
	var calm_sparks: int = fx2._items.size() - normal_sparks
	_check(normal_sparks == 8 and calm_sparks == 4, "Ruhige Effekte halbieren die Funken (%d gegen %d)" % [normal_sparks, calm_sparks])
	fx2.queue_free()
	SaveData.set_calm_effects(false)

	SaveData.set_volume_step("sfx", 0)
	Sfx.apply_settings()
	var before: int = Sfx._next
	Sfx.play("hit")
	_check(Sfx._next == before, "Effekte auf 0: es wird nichts abgespielt")
	SaveData.set_volume_step("sfx", 8)
	Sfx.apply_settings()
	Sfx._last_played.clear()
	Sfx.play("hit")
	_check(Sfx._next != before, "Mit Lautstaerke wird abgespielt")
	_check(absf(Sfx._players[before].volume_db - Sfx.BASE_DB) < 0.01, "Standardstufen: Pegel wie vorher")
	# Ohne Controller passiert nichts, auch mit Vibration an (kein Absturz).
	InputSetup.rumble(1, 0.5, 0.5, 0.2)
	SaveData.set_rumble(false)
	InputSetup.rumble(2, 0.5, 0.5, 0.2)
	_check(true, "Rumble ohne Controller laeuft ohne Fehler")
	SaveData.reset()


func _title_flow() -> void:
	SaveData.reset()
	Engine.set_meta("classes", ["roomba", "hexapod"])
	var title: Node = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().create_timer(0.3, true, false, true).timeout
	var index: int = title.MENU_ITEMS.find("Optionen")
	_check(index >= 0, "Titelmenue hat den Eintrag Optionen")
	for i in index:
		await _tap("p1_down")
	await _tap("p1_confirm")
	_check(title.state == title.State.OPTIONS, "Optionen oeffnen die Seite")
	var page: OptionsPage = title.options
	_check(page.cursor == 0, "Cursor startet oben (Gesamtlautstaerke)")
	await _tap("p1_right")
	_check(SaveData.volume_step("master") == 9, "Rechts erhoeht die Gesamtlautstaerke")
	await _tap("p2_left")
	await _tap("p2_left")
	_check(SaveData.volume_step("master") == 7, "Links senkt sie (auch mit Spieler 2)")
	await _tap("p1_down")
	await _tap("p1_confirm")
	_check(SaveData.volume_step("music") == 8, "Kreuz verstellt keine Lautstaerke")
	for i in 5:
		await _tap("p1_right")
	_check(SaveData.volume_step("music") == 10, "Musik stoppt bei 100 %")
	await _tap("p1_down")
	await _tap("p1_down")
	_check(page.cursor == 3, "Cursor steht bei Bildschirmwackeln")
	await _tap("p1_right")
	_check(SaveData.shake_level() == 3, "Rechts: Wackeln Stark")
	await _tap("p1_right")
	_check(SaveData.shake_level() == 0, "und weiter im Kreis: Aus")
	await _tap("p1_down")
	await _tap("p1_confirm")
	_check(SaveData.calm_effects(), "Kreuz schaltet die Ruhigen Effekte ein")
	await _tap("p1_down")
	await _tap("p1_confirm")
	_check(not SaveData.numbers_enabled(), "Kreuz schaltet Schadenszahlen aus")
	await _tap("p1_down")
	await _tap("p1_confirm")
	_check(not SaveData.rumble_enabled(), "Kreuz schaltet Vibration aus")
	_check(page.value_text("rumble") == "Aus" and page.value_text("master") == "70 %", "Werte erscheinen als Text")
	for i in 6:
		await _tap("p1_up")
	await _tap("p1_interact")
	_check(title.state == title.State.MAIN, "Kreis schliesst die Optionen")
	await _tap("p1_down")
	_check(title.MENU_ITEMS[title.cursor] == "Credits", "Unter Optionen steht Credits")
	await _tap("p1_confirm")
	_check(title.state == title.State.CREDITS, "Credits oeffnen die Seite")
	await _tap("p1_interact")
	_check(title.state == title.State.MAIN, "Kreis schliesst die Credits")
	_check(title.version_text() == "Version 0.6.0", "Versionsnummer kommt aus den Projekteinstellungen")
	_check(Transition.layer == 100 and not Transition.busy, "Uebergangs-Overlay liegt ganz oben und ist bereit")
	title.set_process(false)
	title.queue_free()
	await get_tree().process_frame
	SaveData.reset()


func _hold() -> void:
	SaveData.reset()
	SaveData.set_volume_step("music", 0)
	var page := OptionsPage.new()
	page.cursor = 1
	await get_tree().process_frame
	Input.action_press("p1_right")
	for i in 75:
		page.update(1.0 / 60.0)
		await get_tree().process_frame
	Input.action_release("p1_right")
	var steps := SaveData.volume_step("music")
	_check(steps >= 4 and steps <= 10, "Gehaltene Taste verstellt die Lautstaerke fortlaufend (Stufe %d)" % steps)
	page.update(1.0 / 60.0)
	await get_tree().process_frame
	var after := SaveData.volume_step("music")
	_check(after == steps, "Nach dem Loslassen ist Ruhe")
	_check(not page._dirty, "Nach dem Loslassen ist die Lautstaerke gespeichert (nicht bei jeder Wiederholung)")

	# Schalter wechseln nur beim frischen Druck, Halten flackert nicht.
	SaveData.reset()
	page = OptionsPage.new()
	page.cursor = 5
	_check(String(OptionsPage.ROWS[5].id) == "numbers" and SaveData.numbers_enabled(), "Zeile 6 ist der Zahlen-Schalter (an)")
	await get_tree().process_frame
	Input.action_press("p1_right")
	for i in 90:
		page.update(1.0 / 60.0)
		await get_tree().process_frame
	Input.action_release("p1_right")
	_check(not SaveData.numbers_enabled(), "Gehaltene Taste schaltet den Schalter genau einmal um")
	Sfx.apply_settings()
	SaveData.reset()
