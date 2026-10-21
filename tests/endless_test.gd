extends Node
## Test des Endlosmodus nach dem Smelter: Weiterspielen, Karte, Waechter im Kreis, Rekord, Erfolge.
## Ausfuehren: godot --headless --path . res://tests/endless_test.tscn

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


func _until(condition: Callable, timeout := 6.0) -> void:
	var start := Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec() - start < int(timeout * 1000.0):
		await get_tree().physics_frame


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_pure()
	SaveData.reset()
	Engine.set_meta("classes", ["roomba", "hexapod"])
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	main.stage_id = ""
	add_child(main)
	await _frames(10)
	var p1: Player = main.players[0]
	var p2: Player = main.players[1]
	p1.hp = 1.0e6
	p2.hp = 1.0e6

	# Zum Boss und zum Sieg.
	main.wave = main.max_waves
	main._start_boss()
	await _frames(10)
	_check(main.phase == main.Phase.BOSS and main.boss != null, "Bosskampf laeuft")
	main._on_boss_died()
	_check(main.phase == main.Phase.VICTORY, "Sieg")
	_check(not main.endless, "Zuerst ist es kein Endlosmodus")
	var chips_before := SaveData.chips()
	main.continue_endless()
	_check(main.endless and main.phase == main.Phase.CLEARING and main.max_waves > 1000, "Endlos weiter: Aufraeumphase, keine Wellengrenze mehr")
	main.continue_endless()
	_check(main.endless, "Zweimal Weiterspielen schadet nicht")

	# Hinter den Toren: Boss-Halle weg, neue Karte, Shop.
	await _until(func() -> bool: return main.phase == main.Phase.SHOP)
	_check(main.phase == main.Phase.SHOP, "Danach oeffnet der Shop")
	_check(main.boss == null and main.boss_arena == null, "Der Boss und seine Halle sind weg")
	_check(not main.stage_layout.is_empty() and main.stage_layout.id != "classic", "Eine normale Karte steht (%s)" % str(main.stage_layout.get("id", "")))
	_check(not main.shop_menu.before_boss, "Der Shop kuendigt keinen Boss mehr an")
	main.shop_menu._finish()
	await _until(func() -> bool: return main.phase == main.Phase.WAVE)
	_check(main.phase == main.Phase.WAVE and main.wave == 11, "Welle 11 beginnt (Welle %d)" % main.wave)
	_check(main.director.wave == 11, "Der Director kennt Welle 11")
	_check(main.director.hp_scale() > 3.5, "Die Gegner sind staerker (Leben x%.1f)" % main.director.hp_scale())

	# Waechter im Kreis.
	_check(EnemyTypes.guardian_for(12) == "brute" and EnemyTypes.guardian_for(15) == "charger" and EnemyTypes.guardian_for(18) == "mortar" and EnemyTypes.guardian_for(21) == "brute", "Waechter wechseln im Kreis")
	main.wave = 12
	_check(main.is_guardian_wave(), "Welle 12 ist eine Waechterwelle")
	main.wave = 11

	# Erfolge und Rekord.
	main.wave = 15
	main._end_wave()
	_check(SaveData.archive_has("achievements", "endless_15") and not SaveData.archive_has("achievements", "endless_20"), "Welle 15 schaltet Immer weiter frei")
	main.wave = 20
	main._end_wave()
	_check(SaveData.archive_has("achievements", "endless_20"), "Welle 20 schaltet Unaufhaltsam frei")
	_check(not SaveData.archive_has("achievements", "wave_5"), "Durchhalter zaehlt nur ausserhalb des Endlosmodus")
	main.wave = 14
	main.phase = main.Phase.WAVE
	var before := SaveData.chips()
	main._record_endless()
	_check(int(SaveData.stats().endless_best) == 13, "Rekord: 13 Wellen (%d)" % int(SaveData.stats().endless_best))
	_check(SaveData.chips() - before == (13 - 10) * Meta.ENDLESS_CHIPS_PER_WAVE, "Chips fuer drei Wellen nach dem Boss (%d)" % (SaveData.chips() - before))
	_check(main.run_chips >= (13 - 10) * Meta.ENDLESS_CHIPS_PER_WAVE, "Der Ergebnisbildschirm zaehlt sie zu den Chips des Laufs (%d)" % main.run_chips)
	# Im Shop ist die laufende Welle schon geschafft.
	main._endless_recorded = false
	main.phase = main.Phase.SHOP
	main.wave = 14
	var shop_before := SaveData.chips()
	main._record_endless()
	_check(int(SaveData.stats().endless_best) == 14 and SaveData.chips() > shop_before, "Im Shop zaehlt die gerade geschaffte Welle mit (Rekord %d)" % int(SaveData.stats().endless_best))
	main.phase = main.Phase.WAVE
	var again := SaveData.chips()
	main._record_endless()
	_check(SaveData.chips() == again, "Nur einmal verbuchen")
	_check(SaveData.chips() >= chips_before, "Chips gehen nie verloren")

	# Pausemenue: Endlos-Eintrag nur nach dem ersten Sieg.
	var menu: PauseMenu = main.pause_menu
	menu.victory = true
	menu.mode = PauseMenu.Mode.RESULT
	_check(not menu._items().has("Endlos weiter"), "Im Endlosmodus gibt es den Eintrag nicht noch einmal")
	main.endless = false
	_check(menu._items()[0] == "Endlos weiter" and menu._items().size() == 3, "Nach dem ersten Sieg steht Endlos weiter oben")
	menu.victory = false
	_check(menu._items() == PauseMenu.RESULT_ITEMS, "Nach einer Niederlage nur Neustart und Hauptmenue")
	menu.mode = PauseMenu.Mode.CLOSED

	main.queue_free()
	await get_tree().process_frame
	await _with_gates()
	print("Fertig, Fehler: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


## Mit Toren und Vertragswahl, wie im echten Spiel: Die Halle wird hinter den geschlossenen Toren abgebaut.
func _with_gates() -> void:
	SaveData.reset()
	Engine.set_meta("classes", ["roomba", "hexapod"])
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.stage_id = ""
	add_child(main)
	await _frames(10)
	for p in main.players:
		p.hp = 1.0e6
	main.wave = main.max_waves
	main._start_boss()
	await _frames(10)
	main._on_boss_died()
	main.continue_endless()
	await _until(func() -> bool: return main.phase == main.Phase.SHOP, 8.0)
	_check(main.phase == main.Phase.SHOP and main.gates.is_closed, "Der Shop oeffnet sich hinter geschlossenen Toren")
	_check(main.boss_arena == null and not main.stage_layout.is_empty(), "Die Boss-Halle ist abgebaut, eine Karte steht")
	main.shop_menu._finish()
	await _until(func() -> bool: return main.contract_menu.is_open, 4.0)
	_check(main.contract_menu.is_open and main.wave == 11, "Danach kommt die Vertragswahl fuer Welle 11")
	main.contract_menu._finish(main.contract_menu.perk_ids[0])
	await _until(func() -> bool: return main.phase == main.Phase.WAVE and not main.gates.is_closed, 6.0)
	_check(main.phase == main.Phase.WAVE and not main.gates.is_closed, "Die Tore oeffnen sich, Welle 11 laeuft")
	main.queue_free()
	await get_tree().process_frame


func _pure() -> void:
	_check(SaveData.record_endless(10, 10) == 0, "Kein Boss-Ueberhang, keine Chips")
	_check(SaveData.record_endless(12, 10) == 2 * Meta.ENDLESS_CHIPS_PER_WAVE, "Zwei Wellen ueber dem Boss")
	_check(int(SaveData.stats().endless_best) == 12, "Rekord merkt sich das Maximum")
	SaveData.record_endless(11, 10)
	_check(int(SaveData.stats().endless_best) == 12, "Ein niedrigerer Lauf senkt ihn nicht")
	SaveData.set_difficulty(0)
	var rookie := SaveData.record_endless(12, 10)
	_check(rookie == int(round(2.0 * float(Meta.ENDLESS_CHIPS_PER_WAVE) * float(Meta.difficulty_data().chips))) and rookie < 2 * Meta.ENDLESS_CHIPS_PER_WAVE, "Endlos-Chips folgen dem Schwierigkeitsfaktor (Rookie %d)" % rookie)
	SaveData.set_difficulty(1)
