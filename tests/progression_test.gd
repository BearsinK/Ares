extends Node
## Test von XP, Gold und Level-Up-Auswahl.
## Ausfuehren: godot --headless --path . res://tests/progression_test.tscn

var main: Node
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	add_child(main)
	_run.call_deferred()


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
	# Erst auf den Beginn eines Frames warten, damit "just pressed" im selben Frame
	# wie die Auswertung durch das Menue liegt.
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func _run() -> void:
	await _frames(40)
	var p1: Player = main.players[0]
	var p2: Player = main.players[1]
	p1.global_position = Vector2(1000.0, 1210.0)
	p2.global_position = Vector2(300.0, 1210.0)

	# Gegner besiegen laesst XP fallen, der Spieler sammelt sie ein
	var xp_before: int = main.xp
	var enemy: Enemy = main.director.spawn("brute", Vector2(1060.0, 1220.0))
	enemy.take_damage(99999.0, p1)
	await _frames(2)
	_check(main.pickups.get_child_count() >= 1, "Besiegter Gegner laesst Beute fallen")
	await _frames(150)
	_check(main.xp > xp_before, "XP wird eingesammelt (%d -> %d)" % [xp_before, main.xp])

	# Gold gehoert dem Spieler, der es einsammelt
	var gold_before := p1.gold
	main._spawn_pickup("gold", 5, p1.global_position + Vector2(10.0, -30.0))
	await _frames(120)
	_check(p1.gold == gold_before + 5 and p2.gold == 0, "Gold geht an den Einsammler (P1 %d, P2 %d)" % [p1.gold, p2.gold])

	# Klassenspezifische Perks
	var overclock_roomba := Perks.mods_for("overclock", "roomba")
	var overclock_hexapod := Perks.mods_for("overclock", "hexapod")
	_check(overclock_roomba.has("fire_rate") and overclock_hexapod.has("damage"), "Perk wirkt je nach Klasse anders")

	# Level-Up: Menue oeffnet und pausiert
	main.xp = main.xp_needed
	await _frames(3)
	var menu: LevelUpMenu = main.levelup_menu
	_check(menu.is_open and get_tree().paused, "Level-Up oeffnet das Menue und pausiert")
	_check(main.level == 2, "Stufe steigt auf 2")

	# Uneinigkeit: P1 geht nach links, P2 bestaetigt die Mitte
	while menu._age < 0.7:
		await get_tree().process_frame
	await _tap("p1_left")
	await _tap("p1_confirm")
	await _tap("p2_confirm")
	await get_tree().create_timer(0.1).timeout
	_check(menu.is_open, "Bei unterschiedlicher Wahl bleibt das Menue offen")

	# Einigung: P1 geht wieder nach rechts und bestaetigt die Mitte
	await _tap("p1_right")
	await _tap("p1_confirm")
	await get_tree().create_timer(0.1).timeout
	_check(not menu.is_open and not get_tree().paused, "Bei gleicher Wahl schliesst das Menue")
	var changed := false
	for player in [p1, p2]:
		for key in player.mods:
			if float(player.mods[key]) != 0.0:
				changed = true
	_check(changed, "Gewaehlter Perk wird auf beide Spieler angewendet")

	print("Fertig, Fehler: ", failures)
	get_tree().quit(failures)
