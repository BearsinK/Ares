extends Node
## Test der Erfolge: Daten, Freischalten mit Chips, Ausloeser in der Hauptszene.
## Ausfuehren: godot --headless --path . res://tests/achievements_test.tscn

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


func _ready() -> void:
	_run.call_deferred()


func _fresh_main() -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
		await get_tree().process_frame
	SaveData.reset()
	Engine.set_meta("classes", ["roomba", "hexapod"])
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	main.stage_id = "classic"
	add_child(main)
	await _frames(5)
	p1 = main.players[0]
	p2 = main.players[1]


func _has(id: String) -> bool:
	return SaveData.archive_has("achievements", id)


func _run() -> void:
	_data()
	await _kills()
	await _waves()
	await _bosses()
	await _holdings()
	await _newer()
	await _team()
	await _page()
	print("Fertig, Fehler: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


func _data() -> void:
	var entries := Archive.entries("achievements")
	_check(entries.size() == Achievements.DATA.size() and entries.size() >= 15, "Jeder Erfolg steht im Archiv (%d)" % entries.size())
	var sensible := true
	for id in Achievements.DATA:
		var info: Dictionary = Achievements.DATA[id]
		if String(info.name) == "" or String(info.text).length() < 10 or int(info.chips) <= 0:
			sensible = false
	_check(sensible, "Alle Erfolge haben Name, Text und Belohnung")


func _kills() -> void:
	await _fresh_main()
	var chips := SaveData.chips()
	var e: Enemy = main.director.spawn("walker", p1.global_position + Vector2(500.0, 0.0))
	e.take_damage(99999.0, p1, Vector2.RIGHT, "")
	await _frames(3)
	_check(_has("first_blood"), "Erster Kill schaltet Erstes Blech frei")
	_check(SaveData.chips() == chips + int(Achievements.DATA.first_blood.chips), "Die Belohnung wird gutgeschrieben")
	var after := SaveData.chips()
	main._unlock("first_blood")
	_check(SaveData.chips() == after, "Ein Erfolg zahlt nur einmal")
	main.kills = 99
	var e2: Enemy = main.director.spawn("walker", p1.global_position + Vector2(-500.0, 0.0))
	e2.take_damage(99999.0, p1, Vector2.RIGHT, "")
	await _frames(3)
	_check(_has("kills_100"), "100 Kills schalten Hundertschaft frei")
	for i in 10:
		var elite: Enemy = main.director.spawn("walker", p1.global_position + Vector2(300.0 + i * 20.0, 0.0), true)
		elite.take_damage(99999.0, p1, Vector2.RIGHT, "")
	await _frames(3)
	_check(_has("elite_10"), "Zehn Elites schalten Elitejaeger frei")
	var count := SaveData.archive_count("achievements")
	var notices: int = main.hud._notices.size()
	_check(notices >= 1 and notices <= 3, "Erfolge melden sich im HUD (%d)" % notices)
	_check(count >= 3, "Mehrere Erfolge stehen im Spielstand (%d)" % count)


func _newer() -> void:
	await _fresh_main()
	var target: Enemy = main.director.spawn("brute", Vector2(900.0, 1200.0))
	target.set_physics_process(false)
	target.hp = 99999.0
	target.max_hp = 99999.0
	for pair in [["water", "fire"], ["water", "ice"], ["water", "lightning"], ["fire", "ice"], ["fire", "lightning"], ["ice", "lightning"]]:
		target.statuses._status.clear()
		target.take_damage(1.0, p1, Vector2.ZERO, pair[0])
		target.take_damage(1.0, p2, Vector2.ZERO, pair[1])
	main._check_holdings()
	_check(Achievements.combos_seen.size() == 6, "Alle sechs Kombos wurden gezaehlt (%d)" % Achievements.combos_seen.size())
	_check(_has("combo_all"), "Kombinator: alle Kombos in einem Lauf")
	await _fresh_main()
	_check(Achievements.combos_seen.is_empty(), "Ein neuer Lauf beginnt ohne gezaehlte Kombos")
	_check(not _has("arsenal"), "Anfangs kein Waffenmeister")
	for id in Weapons.CLASS_SETS.roomba:
		SaveData.archive_discover("weapons", id)
	main._check_holdings()
	_check(_has("arsenal"), "Waffenmeister: alle fuenf Waffen der Klasse entdeckt")


func _waves() -> void:
	await _fresh_main()
	main.wave = 2
	main._hit_this_wave = true
	main._end_wave()
	_check(not _has("no_hit"), "Mit Treffer gibt es kein Unberuehrbar")
	await _fresh_main()
	main.wave = 5
	main._hit_this_wave = false
	main.contract_bonus = 0.2
	main._end_wave()
	_check(_has("no_hit") and _has("wave_5") and _has("contract"), "Welle 5 ohne Treffer mit Vertrag: drei Erfolge")
	await _fresh_main()
	main.wave = 1
	main._end_wave()
	_check(not _has("no_hit") and not _has("wave_5") and not _has("contract"), "Welle 1 ohne Treffer zaehlt nicht (Vertrag fehlt, zu frueh)")
	# Ein Treffer in der Welle merkt sich Main, eine neue Welle setzt zurueck.
	p1.iframes = 0.0
	p1.take_hit(1.0, p1.global_position + Vector2(20.0, 0.0))
	await _frames(2)
	_check(main._hit_this_wave, "Ein Treffer wird gemerkt")
	main._begin_new_wave("")
	_check(not main._hit_this_wave, "Neue Welle setzt zurueck")
	# Waechter.
	main.phase = main.Phase.WAVE
	main._guardian_defeated(p1.global_position + Vector2(300.0, 0.0), 40.0)
	_check(_has("guardian"), "Waechter besiegt schaltet Waechterfall frei")


func _bosses() -> void:
	await _fresh_main()
	SaveData.set_difficulty(2)
	main.director.time = 600.0
	main._on_boss_died()
	_check(_has("boss") and _has("speedrun") and _has("boss_hard"), "Smelter auf Hardcore in zehn Minuten: drei Erfolge")
	await _fresh_main()
	SaveData.set_difficulty(1)
	main.director.time = 1200.0
	main._on_boss_died()
	_check(_has("boss") and not _has("speedrun") and not _has("boss_hard"), "Normal und langsam: nur Ofen aus")
	SaveData.set_difficulty(1)


func _holdings() -> void:
	await _fresh_main()
	p1.gold = 499
	main._check_holdings()
	_check(not _has("rich"), "499 Gold reichen nicht")
	p2.gold = 500
	main._check_holdings()
	_check(_has("rich"), "500 Gold bei einem Spieler: Goldrausch")
	p1.add_item("overclock")
	main._check_holdings()
	_check(not _has("rare_find") and not _has("stack_5"), "Normales Item allein bringt nichts")
	p1.add_item(Perks.RARE_IDS[0])
	main._check_holdings()
	_check(_has("rare_find"), "Seltenes Item: Seltener Fund")
	for i in 4:
		p2.add_item("oilchange")
	main._check_holdings()
	_check(not _has("stack_5"), "Vier gleiche Items reichen nicht")
	p2.add_item("oilchange")
	main._check_holdings()
	_check(_has("stack_5"), "Fuenf gleiche Items: Sammelwut")
	# Archiv zur Haelfte: erst knapp darunter, dann ein Eintrag mehr.
	await _fresh_main()
	var total := Archive.collection_progress().y
	var needed := int(ceil(total / 2.0))
	var spare: Array = []
	for kind in ["items", "enemies", "weapons"]:
		for entry in Archive.entries(kind):
			if Archive.collection_progress().x < needed - 1 and not SaveData.archive_has(kind, String(entry.id)):
				SaveData.archive_discover(kind, String(entry.id))
			elif not SaveData.archive_has(kind, String(entry.id)):
				spare.append([kind, String(entry.id)])
	_check(Archive.collection_progress().x == needed - 1, "Aufbau: genau ein Eintrag unter der Haelfte (%d von %d)" % [needed - 1, total])
	main._discover("items", "zzz_test")
	_check(not _has("archive_half"), "Knapp unter der Haelfte: noch nicht")
	main._discover(spare[0][0], spare[0][1])
	_check(_has("archive_half"), "Haelfte erreicht: Archivar")


func _team() -> void:
	await _fresh_main()
	var chest := Chest.new()
	chest.players = main.players
	main.chests.add_child(chest)
	for i in 4:
		main._on_chest_opened(chest, p1)
	_check(not _has("chests_5"), "Vier Kisten reichen nicht")
	main._on_chest_opened(chest, p1)
	_check(_has("chests_5"), "Fuenf Kisten: Schatzsucher")
	var blood := Altar.new()
	blood.kind = "blood"
	blood.players = main.players
	main.chests.add_child(blood)
	for i in 3:
		main._on_altar_used(blood, p1)
	_check(_has("blood"), "Drei Blutopfer: Blutpakt")
	var luck := Altar.new()
	luck.kind = "chance"
	luck.players = main.players
	main.chests.add_child(luck)
	main.chance_roll_override = 0.9
	for i in 3:
		main._on_altar_used(luck, p1)
	_check(not _has("gambler"), "Drei Nieten bringen nichts")
	main.chance_roll_override = 0.0
	for i in 3:
		main._on_altar_used(luck, p1)
	_check(_has("gambler"), "Drei Gewinne: Gluecksritter")
	# Wiederbeleben: wirklich ueber den Partner, nicht ueber die Waechter-Reparatur.
	p1.revive()
	_check(not _has("revive_3"), "Direktes Wiederbeleben zaehlt nicht")
	for round in 3:
		p1.iframes = 0.0
		p1.take_hit(9999.0, p1.global_position + Vector2(20.0, 0.0))
		p2.global_position = p1.global_position + Vector2(40.0, 0.0)
		Input.action_press("p2_interact")
		var waited := 0
		while p1.downed and waited < 400:
			await get_tree().physics_frame
			waited += 1
		Input.action_release("p2_interact")
		await _frames(2)
	_check(not p1.downed and _has("revive_3"), "Dreimal vom Partner belebt: Teamgeist")


func _page() -> void:
	SaveData.reset()
	SaveData.archive_discover("achievements", "boss")
	var page := ArchivePage.new()
	page.tab = Archive.KINDS.find("achievements")
	_check(page.kind() == "achievements" and page.entries().size() == Achievements.DATA.size(), "Archivseite hat den Reiter Erfolge")
	var p := Archive.progress("achievements")
	_check(p.x == 1 and p.y == Achievements.DATA.size(), "Fortschritt der Erfolge (%d/%d)" % [p.x, p.y])
	_check(Archive.collection_progress().x == 0, "Erfolge zaehlen nicht zur Sammlung")
	SaveData.reset()
