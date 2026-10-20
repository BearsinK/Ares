extends Node
## Test von Spielstand, Werkstatt, Chips, Freischaltungen, Shop-Neuerungen und Elite-Arten.
## Ausfuehren: godot --headless --path . res://tests/meta_test.tscn

var main: Node
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


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_save_logic()
	await _in_game()
	await _elites()
	print("Fertig, Fehler: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


func _save_logic() -> void:
	SaveData.reset()
	_check(SaveData.chips() == 0, "Frischer Spielstand hat keine Chips")
	_check(not SaveData.buy_upgrade("vitality"), "Ohne Chips kein Kauf")
	SaveData.add_chips(100)
	_check(SaveData.buy_upgrade("vitality") and SaveData.level("vitality") == 1 and SaveData.chips() == 80, "Upgrade kostet Chips und steigt")
	_check(Meta.cost_of("vitality", 1) > Meta.cost_of("vitality", 0), "Naechste Stufe ist teurer")
	SaveData.add_chips(1000)
	for i in 10:
		SaveData.buy_upgrade("dealer")
	_check(SaveData.level("dealer") == 1, "Maximalstufe wird nicht ueberschritten")
	_check(not SaveData.weapon_unlocked("rocket") and SaveData.weapon_unlocked("dust"), "Raketen sind anfangs gesperrt, Staubkugeln frei")
	_check(SaveData.buy_unlock("weapon", "rocket") and SaveData.weapon_unlocked("rocket"), "Waffe laesst sich freischalten")
	_check(not SaveData.buy_unlock("weapon", "rocket"), "Doppelkauf wird abgelehnt")
	_check(not SaveData.class_unlocked("printer") and SaveData.class_unlocked("roomba"), "Drucker gesperrt, Roomba frei")
	var earned := SaveData.record_run(5, 200, 8, 600, false)
	_check(earned == Meta.chips_for_run(5, 200, 8, false) and earned >= 5, "Lauf bringt Chips (%d)" % earned)
	_check(SaveData.stats().runs == 1 and SaveData.stats().best_wave == 5, "Bestwerte werden gespeichert")
	var boss_chips := Meta.chips_for_run(10, 500, 12, true)
	_check(boss_chips >= Meta.chips_for_run(10, 500, 12, false) + 100, "Boss-Sieg gibt einen grossen Bonus")


func _in_game() -> void:
	SaveData.reset()
	SaveData.add_chips(2000)
	for id in ["vitality", "vitality", "firepower", "capital", "scholar", "scholar", "dealer"]:
		SaveData.buy_upgrade(id)
	Engine.set_meta("classes", ["roomba", "hexapod"])
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	add_child(main)
	await _frames(20)
	var p1: Player = main.players[0]
	var p2: Player = main.players[1]
	_check(is_equal_approx(p1.max_health(), float(p1.stats.max_hp) + 16.0), "Rahmen-Upgrade erhoeht die Leben (%d)" % p1.max_health())
	_check(is_equal_approx(p1.hp, p1.max_health()), "Spieler starten mit vollen Leben")
	_check(is_equal_approx(float(p1.mods.damage), 0.04), "Ladungs-Upgrade erhoeht den Schaden")
	_check(p1.gold == 12 and p2.gold == 12, "Startkapital wird gutgeschrieben")
	_check(float(p1.mods.pickup) >= 0.5, "Roomba hat einen groesseren Sammelradius")
	_check(float(p2.mods.pickup) == 0.0, "Hexapod hat keinen")

	var pickup := Pickup.new()
	pickup.kind = "xp"
	pickup.value = 10
	main.xp = 0
	main._on_pickup_collected(pickup, p1)
	_check(main.xp == 12, "Lernchip erhoeht die Erfahrung (%d)" % main.xp)
	pickup.free()

	# Shop: gesperrte Waffen erscheinen nicht, erster Reroll gratis, Inflation, Reparatur.
	SaveData.reset()
	var locked_seen := false
	for i in 80:
		for offer in ShopItems.make_offers(p1, 3):
			if offer.type == "weapon" and not SaveData.weapon_unlocked(offer.id):
				locked_seen = true
	_check(not locked_seen, "Gesperrte Waffen erscheinen nicht im Shop")
	_check(ShopItems.price_for("perk", 3, 10) > ShopItems.price_for("perk", 3, 0), "Kaeufe machen weitere Kaeufe teurer")
	p1.hp = 10.0
	var repair := {"type": "repair", "id": "repair"}
	var purchases := p1.purchases
	ShopItems.apply(p1, repair)
	_check(p1.hp >= 10.0 + p1.max_health() * 0.5 and p1.purchases == purchases, "Reparatur heilt und zaehlt nicht als Inflation")
	ShopItems.apply(p1, {"type": "perk", "id": "overclock"})
	_check(p1.purchases == purchases + 1, "Ein Kauf erhoeht den Preiszaehler")
	SaveData.reset()
	SaveData.add_chips(100)
	SaveData.buy_upgrade("dealer")
	SaveData.add_chips(100)
	main.shop_menu.open(main.players, 2)
	await _frames(3)
	_check(main.shop_menu._reroll_price(0) == 0, "Haendlerkontakt macht den ersten Reroll gratis")
	main.shop_menu._cursor[0] = ShopMenu.REROLL_SLOT
	main.shop_menu._activate(0)
	_check(main.shop_menu._reroll_price(0) > 0, "Der zweite Reroll kostet wieder")
	main.shop_menu._finish()
	await _frames(3)

	# Lauf-Ende: Chips werden genau einmal verbucht.
	var chips_before := SaveData.chips()
	main.kills = 150
	p1.take_hit(9999.0, p1.global_position + Vector2(10.0, 0.0))
	p2.take_hit(9999.0, p2.global_position + Vector2(10.0, 0.0))
	_check(main.game_over and main.run_recorded and main.run_chips > 0, "Game Over bringt Chips (%d)" % main.run_chips)
	_check(SaveData.chips() == chips_before + main.run_chips, "Chips landen im Spielstand")
	main.abandon_run()
	_check(SaveData.chips() == chips_before + main.run_chips, "Ein Lauf wird nur einmal verbucht")
	main.queue_free()
	get_tree().paused = false
	await _frames(3)


func _elites() -> void:
	SaveData.reset()
	Engine.set_meta("classes", ["roomba", "hexapod"])
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	add_child(main)
	await _frames(20)
	var p1: Player = main.players[0]
	var p2: Player = main.players[1]
	p1.global_position = Vector2(1000.0, 1225.0)
	p2.global_position = Vector2(2900.0, 1225.0)
	p1.iframes = 9999.0

	var strikes := [0]
	var shots := [0]
	main.director.strike_requested.connect(func(_e: Enemy, _p: Vector2, _r: float, _d: float, _dmg: float) -> void: strikes[0] += 1)
	main.director.projectile_requested.connect(func(_e: Enemy, _o: Vector2, _d: Vector2, _s: float, _dmg: float) -> void: shots[0] += 1)

	var fire: Enemy = main.director.spawn("walker", Vector2(1500.0, 1225.0), true, "fire")
	fire._cooldown = 99.0
	_check(fire.elite_kind == "fire", "Elite-Art wird gesetzt")
	await _frames(240)
	_check(strikes[0] >= 1, "Brandherd legt Feuerstellen (%d)" % strikes[0])
	fire.queue_free()

	var storm: Enemy = main.director.spawn("walker", Vector2(1500.0, 1225.0), true, "storm")
	storm._cooldown = 99.0
	storm._elite_timer = 0.1
	await _frames(100)
	_check(shots[0] >= 3, "Sturmbot feuert einen Blitzfaecher (%d Geschosse)" % shots[0])
	storm.queue_free()

	var frost: Enemy = main.director.spawn("walker", Vector2(1100.0, 1225.0), true, "frost")
	frost._cooldown = 99.0
	await _frames(10)
	_check(p1.slow_time > 0.0 and p1.move_speed() < float(p1.stats.speed) * 0.7, "Frostwache bremst Spieler in der Naehe")
	p1.global_position = Vector2(2000.0, 1225.0)
	await _frames(30)
	_check(p1.slow_time <= 0.0, "Ausserhalb der Aura endet die Bremse")
	frost.queue_free()

	var shield: Enemy = main.director.spawn("walker", Vector2(1600.0, 1225.0), true, "shield")
	shield._cooldown = 99.0
	var hp := shield.hp
	var shield_value := shield.shield
	_check(shield_value > 0.0, "Schildtraeger hat einen Schild (%d)" % shield_value)
	shield.take_damage(shield_value * 0.5, p1)
	_check(shield.hp == hp and shield.shield < shield_value, "Der Schild schluckt Schaden")
	shield.take_damage(shield_value, p1)
	_check(shield.shield == 0.0 and shield.hp < hp, "Gebrochener Schild laesst Schaden durch")
	for kind in EnemyTypes.ELITE_KINDS:
		_check(EnemyTypes.ELITE_KINDS[kind].has("name"), "Elite-Art %s ist beschrieben" % kind)
