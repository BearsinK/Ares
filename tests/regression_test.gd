extends Node
## Regressionstests fuer behobene Fehler (Menues, Pickups, Spawns, Eingaben, Niederstrecken).
## Ausfuehren: godot --headless --path . res://tests/regression_test.tscn

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
	Engine.set_meta("classes", ["roomba", "hexapod"])
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	add_child(main)
	await _frames(20)
	var p1: Player = main.players[0]
	var p2: Player = main.players[1]

	# Spieler 2 kann im Menue auch ohne Nummernblock bestaetigen.
	var keys := []
	for event in InputMap.action_get_events("p2_confirm"):
		if event is InputEventKey:
			keys.append(event.physical_keycode)
	_check(keys.size() >= 2, "P2 hat mehr als eine Bestaetigungstaste (%d)" % keys.size())

	# Level-Up ueber dem Shop: Der Shop wartet, bis das Level-Up-Menue zu ist.
	main.phase = main.Phase.CLEARING
	main._clear_time = 0.0
	main.xp = main.xp_needed
	await _frames(2)
	_check(main.levelup_menu.is_open and not main.shop_menu.is_open, "Level-Up hat Vorrang vor dem Shop")
	main.levelup_menu._finish(main.levelup_menu.perk_ids[0])
	get_tree().paused = false
	await _frames(3)
	_check(main.shop_menu.is_open, "Danach oeffnet der Shop")
	main.xp = main.xp_needed
	await _frames(3)
	_check(not main.levelup_menu.is_open, "Im Shop oeffnet sich kein Level-Up darueber")
	main.shop_menu._finish()
	get_tree().paused = false
	await _frames(3)
	main.phase = main.Phase.WAVE
	await _frames(3)
	if main.levelup_menu.is_open:
		main.levelup_menu._finish(main.levelup_menu.perk_ids[0])
	get_tree().paused = false
	await _frames(3)

	# Bei zu vielen Pickups wird Gold trotzdem gutgeschrieben.
	for i in 151:
		main._spawn_pickup("xp", 1, Vector2(100.0, 100.0))
	var gold_before := p1.gold + p2.gold
	main._spawn_pickup("gold", 3, Vector2(100.0, 100.0))
	_check(p1.gold + p2.gold > gold_before, "Gold geht bei vollem Pickup-Limit nicht verloren")
	for pickup in main.pickups.get_children():
		pickup.queue_free()
	await _frames(2)

	# Keine Gegner im geschlossenen Schacht.
	var inside := 0
	main.director.players = main.players
	for i in 400:
		for kind in ["walker", "flyer"]:
			var pos: Vector2 = main.director._spawn_position(kind)
			if pos.x > 2570.0 and pos.x < 2910.0:
				inside += 1
	_check(inside == 0, "Kein Spawn im Schacht (%d)" % inside)

	# Schrott: zerstoerte Gegner lassen ihn fallen, nur der Roomba saugt ihn auf.
	for scrap in get_tree().get_nodes_in_group("scrap"):
		scrap.queue_free()
	await _frames(2)
	p1.global_position = Vector2(600.0, 1215.0)
	p2.global_position = Vector2(2000.0, 1215.0)
	for i in 6:
		var brute: Enemy = main.director.spawn("brute", Vector2(1200.0 + i * 5.0, 1200.0))
		brute._cooldown = 99.0
		brute.on_screen = true
		brute.take_damage(1.0e9, p1, Vector2.RIGHT, "", true)
	await _frames(60)
	var scrap_count := get_tree().get_nodes_in_group("scrap").size()
	_check(scrap_count > 3 and scrap_count <= main.MAX_SCRAP, "Schrott bleibt liegen, aber begrenzt (%d)" % scrap_count)
	var xp_before: int = main.xp
	var hp_before := p1.hp
	p1.hp = p1.max_health() - 5.0
	var near := Scrap.new()
	near.players = main.players
	near.position = p1.global_position + Vector2(60.0, 0.0)
	near.collected.connect(main._on_scrap_collected)
	main.pickups.add_child(near)
	var far := Scrap.new()
	far.players = main.players
	far.position = p2.global_position + Vector2(40.0, 0.0)
	main.pickups.add_child(far)
	await _frames(70)
	_check(not is_instance_valid(near) or near.is_queued_for_deletion(), "Der Roomba saugt Schrott in der Naehe auf")
	_check(is_instance_valid(far) and not far.is_queued_for_deletion(), "Der Hexapod saugt keinen Schrott auf")
	_check(main.xp > xp_before or main.level > 1, "Schrott gibt XP")
	p1.hp = p1.max_health()
	for scrap in get_tree().get_nodes_in_group("scrap"):
		scrap.queue_free()
	if main.levelup_menu.is_open:
		main.levelup_menu._finish(main.levelup_menu.perk_ids[0])
	get_tree().paused = false
	await _frames(2)

	# Dash hinterlaesst Nachbilder der Figur, die wieder verschwinden.
	var ghosts_before := get_tree().get_nodes_in_group("dash_ghosts").size()
	p1.dash_charges = 2
	p1._try_dash()
	await _frames(12)
	var ghosts_now := get_tree().get_nodes_in_group("dash_ghosts").size()
	_check(ghosts_now > ghosts_before, "Dash erzeugt Nachbilder (%d)" % ghosts_now)
	await _frames(60)
	_check(get_tree().get_nodes_in_group("dash_ghosts").is_empty(), "Nachbilder verschwinden wieder")

	# Gegner zerfallen beim Tod in Truemmerteile und zucken bei Treffern.
	var victim: Enemy = main.director.spawn("walker", p1.global_position + Vector2(300.0, 0.0))
	victim._cooldown = 99.0
	await _frames(5)
	victim.take_damage(1.0, p1, Vector2.RIGHT, "")
	_check(victim._hurt_time > 0.2, "Treffer loest Zucken aus")
	var gibs_before := 0
	for item in Fx.instance._items:
		if item.type == "gib":
			gibs_before += 1
	victim.take_damage(9999.0, p1, Vector2.RIGHT, "")
	var gibs_after := 0
	for item in Fx.instance._items:
		if item.type == "gib":
			gibs_after += 1
	_check(gibs_after > gibs_before + 3, "Tod erzeugt Truemmerteile (%d)" % (gibs_after - gibs_before))

	# Der Schacht ist durchgaengig: unten durchlaufen, im Aufwind nach oben getragen.
	p1.global_position = Vector2(2500.0, 1215.0)
	p1.velocity = Vector2.ZERO
	Input.action_press("p1_right")
	await _frames(150)
	Input.action_release("p1_right")
	_check(p1.global_position.x > 2950.0, "Man kommt durch den Schacht auf die andere Seite (x=%.0f)" % p1.global_position.x)
	p1.global_position = Vector2(2740.0, 1200.0)
	p1.velocity = Vector2.ZERO
	await _frames(100)
	_check(p1.global_position.y < 600.0, "Der Aufwind traegt nach oben (y=%.0f)" % p1.global_position.y)

	# Klassenwaffen werden nur ihrer Klasse angeboten.
	var seen_can_for_roomba := false
	var seen_can_for_vending := false
	for i in 300:
		for offer in ShopItems.make_offers(p1, 3):
			if offer.type == "weapon" and (offer.id == "can" or offer.id == "turret"):
				seen_can_for_roomba = true
	_check(not seen_can_for_roomba, "Roomba bekommt weder Soda Bomb noch Turret im Shop")
	_check(Weapons.usable_by("can", "vending") and not Weapons.usable_by("can", "roomba") and Weapons.usable_by("turret", "hexapod"), "Klassenwaffen sind exklusiv")

	# Team-Perk: Zaehler, Banner und Einigung per Zufall.
	main._on_perk_chosen("overclock")
	_check(main.perks_taken.get("overclock", 0) == 1 and main.perk_banner_time > 2.0, "Perk-Wahl zaehlt und zeigt ein Banner")
	var menu: LevelUpMenu = main.levelup_menu
	menu.open(main.players, ["overclock", "magnet", "piggy"], 2)
	menu._age = 1.0
	menu._locked = [0, 2]
	var finished := [""]
	menu.chosen.connect(func(id: String) -> void: finished[0] = id)
	menu._split_time = LevelUpMenu.SPLIT_TIME - 0.01
	await get_tree().create_timer(0.2, true, false, true).timeout
	_check(finished[0] == "overclock" or finished[0] == "piggy", "Uneinigkeit wird nach kurzer Zeit zufaellig entschieden (%s)" % finished[0])
	get_tree().paused = false

	# Dash waehrend des Hakens verbraucht keine Ladung.
	p1.hook_active = true
	var charges := p1.dash_charges
	p1._try_dash()
	_check(p1.dash_charges == charges, "Dash ist waehrend des Hakens gesperrt")
	p1.hook_active = false

	# Niederstrecken setzt Slam, Dash und Haken zurueck.
	p1._slamming = true
	p1.iframes = 0.0
	p1.take_hit(9999.0, p1.global_position + Vector2(5.0, 0.0))
	_check(p1.downed and not p1._slamming, "Niedergestreckt: kein Slam mehr aktiv")
	var hp_down := p1.hp
	p1.add_mods({"max_hp": 25.0})
	_check(p1.hp == hp_down, "Niedergestreckte bekommen keine HP durch Perks")
	p1.revive(1.0)

	# Bosssterbeanimation: Gehen beide Spieler zu Boden, ist es kein Game Over.
	main._start_boss()
	await _frames(10)
	main.boss.dying = true
	p1.iframes = 0.0
	p2.iframes = 0.0
	p1.take_hit(9999.0, p1.global_position + Vector2(5.0, 0.0))
	p2.take_hit(9999.0, p2.global_position + Vector2(5.0, 0.0))
	await _frames(3)
	_check(not main.game_over, "Kein Game Over waehrend der Bosssterbeanimation")

	print("Fertig, Fehler: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
