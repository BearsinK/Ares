extends Node
## Test der Wellenstruktur und des Shops.
## Ausfuehren: godot --headless --path . res://tests/wave_test.tscn

var main: Node
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.wave_duration = 3.0
	main.max_waves = 2
	main.boss_enabled = false
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
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func _run() -> void:
	await _frames(30)
	var p1: Player = main.players[0]
	var p2: Player = main.players[1]
	var shop: ShopMenu = main.shop_menu
	_check(p1.weapons.size() == 1 and p1.modules == [""], "Ohne Testset startet man nur mit der Klassenwaffe")

	# Mitten in der Welle faellt P2, P1 steht
	await _frames(60)
	p2.take_hit(9999.0, p2.global_position + Vector2(20.0, 0.0))
	_check(p2.downed and not main.game_over, "P2 liegt am Boden, P1 steht")
	p1.iframes = 99999.0
	await _frames(60 * 3)

	_check(main.phase == main.Phase.CLEARING, "Welle endet nach der Zeit")
	await _frames(5)
	_check(main.director.alive_count() == 0 and get_tree().get_nodes_in_group("enemies").is_empty(), "Restliche Gegner verschwinden am Wellenende")
	_check(not p2.downed and p2.hp > 0.0, "Am Wellenende stehen alle wieder auf")
	_check(not main.director.enabled, "Director spawnt waehrend der Pause nicht")

	await _frames(60 * 4)
	_check(shop.is_open and get_tree().paused and main.phase == main.Phase.SHOP, "Shop oeffnet nach dem Aufraeumen")
	_check(shop._offers[0].size() == 4 and shop._offers[1].size() == 4, "Jeder Spieler hat vier Angebote")

	# Kaufen mit zu wenig Gold
	p1.gold = 0
	p2.gold = 500
	while shop._age < 0.7:
		await get_tree().process_frame
	await _tap("p1_confirm")
	_check(not shop._offers[0][0].bought, "Ohne Gold wird nichts gekauft")

	# Kaufen mit genug Gold: P2 kauft das erste Angebot
	var offer: Dictionary = shop._offers[1][0]
	var gold_before: int = p2.gold
	await _tap("p2_confirm")
	_check(offer.bought and p2.gold == gold_before - int(offer.price), "P2 kauft Angebot fuer %d Gold" % int(offer.price))
	var gold_p1: int = p1.gold
	_check(gold_p1 == 0, "Gold ist persoenlich (P1 unveraendert)")

	# Reroll
	for i in 4:
		await _tap("p2_right")
	_check(shop._cursor[1] == 4, "Cursor steht auf Reroll")
	gold_before = p2.gold
	await _tap("p2_confirm")
	_check(p2.gold == gold_before - 5, "Reroll kostet Gold (%d -> %d)" % [gold_before, p2.gold])

	# Beide fertig, naechste Welle
	await _tap("p2_right")
	await _tap("p2_confirm")
	_check(shop.is_open, "Shop bleibt offen, bis beide fertig sind")
	for i in 5:
		await _tap("p1_right")
	await _tap("p1_confirm")
	await get_tree().create_timer(0.1).timeout
	_check(not shop.is_open and not get_tree().paused, "Shop schliesst, wenn beide fertig sind")
	_check(main.wave == 2 and main.phase == main.Phase.WAVE and main.director.enabled, "Welle 2 beginnt")

	# Kaufeffekte
	p1.add_weapon("shotgun")
	_check(p1.weapons.size() == 2 and p1.weapons[1] == "shotgun" and p1.weapon_index == 1, "Neue Waffe landet im freien Slot")
	p1.set_module("ice")
	_check(p1.current_module() == "ice", "Modul steckt in der aktiven Waffe")
	p1.add_weapon("rocket")
	p1.add_weapon("beam")
	_check(p1.weapons.size() == 3 and p1.weapons[p1.weapon_index] == "beam" and p1.current_module() == "", "Bei vollen Slots ersetzt die Waffe die aktive")

	# Sieg nach der letzten Welle (Level-Up-Menue soll dabei nicht dazwischenfunken)
	main.xp_needed = 99999
	await _frames(60 * 3 + 30)
	await _frames(60 * 4)
	_check(main.phase == main.Phase.VICTORY, "Nach der letzten Welle ist der Lauf geschafft")

	print("Fertig, Fehler: ", failures)
	get_tree().quit(failures)
