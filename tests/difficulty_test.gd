extends Node
## Test der Schwierigkeitsstufen: Gegnerwerte, Spawnrate, Chips und die Auswahl im Titelmenue.
## Ausfuehren: godot --headless --path . res://tests/difficulty_test.tscn

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
	SaveData.persist = false
	SaveData.reset()
	_check(SaveData.difficulty() == 1 and String(Meta.difficulty_data().id) == "normal", "Standard ist Normal")

	var director := Director.new()
	director.wave = 5
	director.wave_progress = 0.5
	var normal_hp := director.hp_scale()
	var normal_damage := director.damage_scale()
	var normal_chips := Meta.chips_for_run(5, 200, 8, false)
	SaveData.set_difficulty(0)
	_check(director.hp_scale() < normal_hp * 0.8 and director.damage_scale() < normal_damage * 0.8, "Rookie: Gegner haben weniger Leben und Schaden (%.2f / %.2f)" % [director.hp_scale(), director.damage_scale()])
	_check(Meta.chips_for_run(5, 200, 8, false) < normal_chips, "Rookie gibt weniger Chips")
	SaveData.set_difficulty(2)
	_check(director.hp_scale() > normal_hp * 1.3 and director.damage_scale() > normal_damage * 1.25, "Hardcore: Gegner sind zaeher und gefaehrlicher (%.2f / %.2f)" % [director.hp_scale(), director.damage_scale()])
	_check(Meta.chips_for_run(5, 200, 8, false) > normal_chips * 1.5, "Hardcore gibt deutlich mehr Chips (%d gegen %d)" % [Meta.chips_for_run(5, 200, 8, false), normal_chips])
	var more := float(Meta.DIFFICULTIES[2].credits) > float(Meta.DIFFICULTIES[1].credits) and float(Meta.DIFFICULTIES[0].credits) < float(Meta.DIFFICULTIES[1].credits)
	_check(more, "Hardcore spawnt schneller, Rookie langsamer")
	director.free()
	# Auch der Endboss folgt der Stufe.
	var boss_hard := Boss.new()
	var hard_damage := Boss.damage_scale()
	SaveData.set_difficulty(0)
	var boss_easy := Boss.new()
	_check(boss_hard.max_hp > Boss.MAX_HP * 1.3 and boss_easy.max_hp < Boss.MAX_HP * 0.8, "Der Boss hat je nach Stufe mehr oder weniger Leben (%d / %d)" % [boss_easy.max_hp, boss_hard.max_hp])
	_check(hard_damage > Boss.damage_scale() * 1.5, "und macht mehr oder weniger Schaden")
	boss_hard.free()
	boss_easy.free()
	SaveData.set_difficulty(99)
	_check(SaveData.difficulty() == 2, "Ungueltige Werte werden begrenzt")
	SaveData.set_difficulty(1)

	# Titelmenue: Links/Rechts und Bestaetigen schalten durch, gespeichert wird die Wahl.
	var title: Node = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().create_timer(0.4, true, false, true).timeout
	var index: int = title.MENU_ITEMS.find("Schwierigkeit")
	_check(index >= 0, "Das Titelmenue hat den Eintrag Schwierigkeit")
	title.cursor = index
	await _tap("p1_right")
	_check(SaveData.difficulty() == 2, "Rechts: Hardcore")
	await _tap("p1_right")
	_check(SaveData.difficulty() == 0, "Weiter rechts: wieder Rookie")
	await _tap("p1_left")
	_check(SaveData.difficulty() == 2, "Links: zurueck zu Hardcore")
	await get_tree().create_timer(0.6, true, false, true).timeout
	await _tap("p1_confirm")
	_check(SaveData.difficulty() == 0, "Bestaetigen schaltet auch weiter")
	_check(title._item_label(index) == "Stufe: Rookie", "Der Eintrag zeigt die Stufe (%s)" % title._item_label(index))
	SaveData.set_difficulty(1)
	title.set_process(false)
	title.queue_free()

	print("Fertig, Fehler: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
