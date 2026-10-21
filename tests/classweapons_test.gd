extends Node
## Test der Klassenwaffen: Besitzer, Schwung, Scheibe, Sog, Kettenblitz und die neuen Zustaende.
## Ausfuehren: godot --headless --path . res://tests/classweapons_test.tscn

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


func _until(test: Callable, max_frames := 600) -> bool:
	for i in max_frames:
		if test.call():
			return true
		await get_tree().physics_frame
	return test.call()


func _ready() -> void:
	_run.call_deferred()


func _dummy(kind: String, pos: Vector2, hp := 5000.0) -> Enemy:
	var e: Enemy = main.director.spawn(kind, pos)
	e.set_physics_process(false)
	e.hp = hp
	e.max_hp = hp
	e._cooldown = 99.0
	return e


func _fire(player: Player, weapon_id: String, direction := Vector2.RIGHT) -> void:
	main._on_player_fired(player, weapon_id, player.global_position + direction * 20.0, direction, 0.0)


func _run() -> void:
	Engine.set_meta("classes", ["roomba", "hexapod"])
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	main.stage_id = "classic"
	add_child(main)
	await _frames(15)
	p1 = main.players[0]
	p2 = main.players[1]
	p1.global_position = Vector2(600.0, 1210.0)
	p2.global_position = Vector2(200.0, 1210.0)
	p1.invulnerable = true
	p2.invulnerable = true
	_ownership()
	await _statuses()
	await _sweeper()
	await _disc()
	await _vacuum()
	await _zapper()
	await _burst()
	await _mine()
	await _silk()
	await _vendor_set()
	await _printer_set()
	_all_sets()
	print("Fertig, Fehler: ", failures)
	main.queue_free()
	get_tree().quit(1 if failures > 0 else 0)


func _clear() -> void:
	for child in main.projectiles.get_children():
		child.free()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy:
			enemy.free()
	for bullet in main.enemy_projectiles.get_children():
		bullet.free()


func _ownership() -> void:
	var roomba: Array = Weapons.CLASS_SETS.roomba
	_check(roomba.size() == 5 and roomba[0] == "dust", "Roomba hat fuenf Waffen, die Staubkanone zuerst")
	var exclusive := true
	for id in roomba:
		exclusive = exclusive and Weapons.owner_of(id) == "roomba" and Weapons.usable_by(id, "roomba") and not Weapons.usable_by(id, "hexapod") \
			and not Weapons.usable_by(id, "vending") and not Weapons.usable_by(id, "printer") and Weapons.ALL_IDS.has(id)
	_check(exclusive, "Nur der Roomba darf seine Waffen benutzen")
	_check(Weapons.usable_by("rapid", "printer") and Weapons.usable_by("rocket", "vending"), "Allgemeine Waffen darf jeder")
	var complete := true
	for id in Weapons.ALL_IDS:
		var weapon := Weapons.get_weapon(id)
		complete = complete and weapon.has("name") and weapon.has("kind") and weapon.has("sound") and weapon.has("fire_rate") and weapon.has("damage")
		complete = complete and Weapons.summary(id) != ""
	_check(complete, "Jede Waffe hat Name, Art, Klang, Feuerrate, Schaden und eine Kurzbeschreibung")


func _statuses() -> void:
	_clear()
	var e := _dummy("brute", Vector2(900.0, 1200.0))
	_check(is_equal_approx(e.statuses.speed_factor(), 1.0) and is_equal_approx(e.statuses.damage_factor(), 1.0), "Normaler Gegner: kein Zustand")
	e.apply_status("webbed", 3.0, p1)
	_check(is_equal_approx(e.statuses.speed_factor(), StatusEffects.WEB_SPEED), "Gespinst bremst stark")
	e.apply_status("inked", 3.0, p1)
	_check(e.statuses.speed_factor() <= StatusEffects.WEB_SPEED + 0.001, "Die staerkere Bremse zaehlt")
	var before := e.hp
	e.take_damage(100.0, p1, Vector2.ZERO, "")
	var plain := before - e.hp
	e.apply_status("tagged", 5.0, p1)
	before = e.hp
	e.take_damage(100.0, p1, Vector2.ZERO, "")
	var tagged := before - e.hp
	_check(absf(tagged / plain - StatusEffects.TAG_MULT) < 0.02, "Markierte Gegner nehmen 30 Prozent mehr Schaden (%.2f)" % (tagged / plain))
	e.apply_status("stun", 0.6, p1)
	_check(e.stunned_time > 0.5, "Betaeubung wirkt")
	e.stunned_time = 0.0
	e.apply_status("stun", 0.6, p1)
	_check(e.stunned_time == 0.0, "Direkt danach ist der Gegner immun gegen Betaeubung")
	e.statuses.update(5.0)
	_check(is_equal_approx(e.statuses.speed_factor(), 1.0) and is_equal_approx(e.statuses.damage_factor(), 1.0), "Zustaende laufen ab")
	_clear()


func _sweeper() -> void:
	_clear()
	p1.weapons = ["sweeper"]
	p1.modules = [""]
	p1.weapon_index = 0
	p1.global_position = Vector2(600.0, 1200.0)
	var front := _dummy("brute", Vector2(740.0, 1200.0))
	var side := _dummy("brute", Vector2(740.0, 1000.0))
	var behind := _dummy("brute", Vector2(460.0, 1200.0))
	var far := _dummy("brute", Vector2(1100.0, 1200.0))
	await _frames(2)
	var shot := EnemyProjectile.new()
	shot.global_position = Vector2(700.0, 1190.0)
	main.enemy_projectiles.add_child(shot)
	var ref: WeakRef = weakref(shot)
	var hp_front := front.hp
	_fire(p1, "sweeper")
	_check(front.hp < hp_front, "Sweeper trifft den Gegner vor ihm (%.0f Schaden)" % (hp_front - front.hp))
	_check(side.hp == 5000.0 and behind.hp == 5000.0 and far.hp == 5000.0, "Gegner seitlich, hinten und weit weg bleiben unberuehrt")
	_check(front.velocity.x > 50.0, "Der Treffer schleudert den Gegner weg (%.0f)" % front.velocity.x)
	await _frames(2)
	_check(ref.get_ref() == null, "Der Schwung raeumt gegnerische Schuesse ab")
	# Breiterer Bogen mit Split Barrel.
	p1.mods.proj = 3.0
	hp_front = side.hp
	_fire(p1, "sweeper")
	p1.mods.proj = 0.0
	_clear()


func _disc() -> void:
	_clear()
	p1.weapons = ["disc"]
	p1.modules = [""]
	p1.weapon_index = 0
	p1.global_position = Vector2(500.0, 1200.0)
	var e := _dummy("brute", Vector2(800.0, 1200.0))
	await _frames(2)
	_fire(p1, "disc")
	var discs: Array[Projectile] = []
	for child in main.projectiles.get_children():
		if child is Projectile:
			discs.append(child)
	_check(discs.size() == 1 and discs[0].style == "disc" and discs[0].boomerang > 0.0, "Scheibe fliegt als Boomerang")
	var ref: WeakRef = weakref(discs[0])
	var gone := await _until(func() -> bool: return ref.get_ref() == null, 400)
	_check(gone, "Die Scheibe kommt zurueck und verschwindet beim Spieler")
	var dealt := 5000.0 - e.hp
	var single := float(Weapons.get_weapon("disc").damage) * p1.damage_mult()
	_check(dealt > single * 1.5, "Sie trifft auf dem Hin- und Rueckweg (%.0f Schaden, einfach %.0f)" % [dealt, single])
	_clear()


func _vacuum() -> void:
	_clear()
	p1.weapons = ["vacuum"]
	p1.modules = [""]
	p1.weapon_index = 0
	p1.global_position = Vector2(500.0, 1200.0)
	var up := _dummy("brute", Vector2(780.0, 1130.0))
	var down := _dummy("brute", Vector2(780.0, 1215.0))
	var out := _dummy("brute", Vector2(780.0, 600.0))
	await _frames(2)
	_fire(p1, "vacuum")
	_check(up.hp < 5000.0 and down.hp < 5000.0, "Der Sog verletzt Gegner im Kegel")
	_check(out.hp == 5000.0, "Gegner ausserhalb des Kegels bleiben unberuehrt")
	_check(up.velocity.y > 0.0 and down.velocity.y < 0.0, "Beide werden zur Mittellinie gezogen")
	_check(up.velocity.x < 400.0, "Der Zug geht zum Fokuspunkt, nicht zum Spieler")
	_clear()


func _zapper() -> void:
	_clear()
	p1.weapons = ["zapper"]
	p1.modules = [""]
	p1.weapon_index = 0
	p1.global_position = Vector2(500.0, 1200.0)
	var a := _dummy("brute", Vector2(800.0, 1200.0))
	var b := _dummy("brute", Vector2(950.0, 1150.0))
	var c := _dummy("brute", Vector2(1100.0, 1200.0))
	var d := _dummy("brute", Vector2(1250.0, 1180.0))
	var e := _dummy("brute", Vector2(1300.0, 700.0))
	var offaxis := _dummy("brute", Vector2(800.0, 800.0))
	await _frames(2)
	_fire(p1, "zapper")
	_check(a.hp < 5000.0 and b.hp < 5000.0 and c.hp < 5000.0 and d.hp < 5000.0, "Der Blitz trifft alle vier in der Kette")
	_check(e.hp == 5000.0 and offaxis.hp == 5000.0, "Weit entfernte Gegner werden nicht erreicht")
	_check((5000.0 - a.hp) > (5000.0 - d.hp), "Jeder Sprung schwaecht den Blitz ab (%.1f gegen %.1f)" % [5000.0 - a.hp, 5000.0 - d.hp])
	# Nasse Gegner: Blitz hat sein Element, daher gilt der Volt-Effekt.
	a.statuses.update(0.0)
	a.statuses.process_hit("water", p2, 1.0)
	var before := a.hp
	_fire(p1, "zapper")
	_check(before - a.hp > 12.0 * p1.damage_mult() * 1.4, "Zapper setzt den Volt-Effekt: nasse Gegner nehmen mehr Schaden (%.1f)" % (before - a.hp))
	_clear()


func _burst() -> void:
	_clear()
	var set_ok := Weapons.CLASS_SETS.hexapod.size() == 5 and Weapons.CLASS_SETS.hexapod[0] == "turret"
	_check(set_ok, "Hexapod hat fuenf Waffen, das Geschuetz zuerst")
	p2.weapons = ["burst"]
	p2.modules = [""]
	p2.weapon_index = 0
	p2.global_position = Vector2(500.0, 1200.0)
	await _frames(3)
	var count := [0]
	var counter := func(_p: Player, id: String, _o: Vector2, _d: Vector2, _c: float) -> void:
		if id == "burst":
			count[0] += 1
	p2.fired.connect(counter)
	var before := p2.ammo_of(0)
	Input.action_press("p2_fire")
	await _frames(4)
	Input.action_release("p2_fire")
	await _frames(30)
	_check(count[0] == 3, "Ein Druck loest eine Dreiersalve aus (%d Schuesse)" % count[0])
	_check(before - p2.ammo_of(0) == 3, "Jeder Schuss der Salve kostet Munition (%d)" % (before - p2.ammo_of(0)))
	# Waffenwechsel bricht die Salve ab.
	p2.weapons = ["burst", "rapid"]
	p2.modules = ["", ""]
	await _frames(2)
	count[0] = 0
	p2._fire_cooldown = 0.0
	Input.action_press("p2_fire")
	await _frames(2)
	Input.action_release("p2_fire")
	p2.weapon_index = 1
	p2._burst_left = 0
	await _frames(20)
	_check(count[0] < 3, "Nach dem Abbruch kommen keine weiteren Salvenschuesse")
	p2.fired.disconnect(counter)
	p2.weapon_index = 0
	p2.weapons = ["burst"]
	p2.modules = [""]


func mine_ref_valid(mine: Mine) -> bool:
	return is_instance_valid(mine) and not mine.is_queued_for_deletion()


func _mine() -> void:
	_clear()
	p2.weapons = ["mine"]
	p2.modules = [""]
	p2.weapon_index = 0
	p2.global_position = Vector2(500.0, 1200.0)
	await _frames(3)
	_fire(p2, "mine")
	var mines: Array = get_tree().get_nodes_in_group("deployables")
	_check(mines.size() == 1, "Eine Mine liegt in der Welt")
	var mine: Mine = mines[0]
	var landed := await _until(func() -> bool: return mine.planted, 240)
	_check(landed and mine.global_position.y > 1150.0, "Die Mine faellt und bleibt am Boden liegen (y %.0f)" % mine.global_position.y)
	_check(not mine.is_armed(), "Frisch gelegt ist sie noch nicht scharf")
	var armed := await _until(func() -> bool: return mine.is_armed(), 120)
	_check(armed, "Nach kurzer Zeit wird sie scharf")
	var far := _dummy("brute", Vector2(mine.global_position.x + 700.0, 1200.0))
	await _frames(20)
	_check(mine_ref_valid(mine) and far.hp == 5000.0, "Ein weit entfernter Gegner loest sie nicht aus")
	var near := _dummy("brute", Vector2(mine.global_position.x + 60.0, 1200.0))
	var mine_ref: WeakRef = weakref(mine)
	var gone := await _until(func() -> bool: return mine_ref.get_ref() == null, 60)
	await _frames(2)
	_check(gone and near.hp < 5000.0, "Ein Gegner in der Naehe loest sie aus und wird verletzt (%.0f Schaden)" % (5000.0 - near.hp))
	_clear()
	# Limit: mehr als vier Minen gleichzeitig gibt es nicht.
	for i in 6:
		_fire(p2, "mine")
		await _frames(2)
	_check(get_tree().get_nodes_in_group("deployables").size() <= 4, "Hoechstens vier Minen gleichzeitig (%d)" % get_tree().get_nodes_in_group("deployables").size())
	_clear()


func _silk() -> void:
	_clear()
	p2.weapons = ["silk"]
	p2.modules = [""]
	p2.weapon_index = 0
	p2.global_position = Vector2(500.0, 1200.0)
	var e := _dummy("brute", Vector2(900.0, 1200.0))
	await _frames(3)
	_fire(p2, "silk")
	var hit := await _until(func() -> bool: return e.hp < 5000.0, 120)
	_check(hit, "Das Gespinst trifft den Gegner")
	_check(is_equal_approx(e.statuses.speed_factor(), StatusEffects.WEB_SPEED), "Getroffene sind gebremst (%.2f)" % e.statuses.speed_factor())
	_clear()


func _vendor_set() -> void:
	_clear()
	_check(Weapons.CLASS_SETS.vending.size() == 5 and Weapons.CLASS_SETS.vending[0] == "can", "Vendor hat fuenf Waffen, die Soda Bomb zuerst")
	p1.gold = 0
	p1.weapons = ["flamer"]
	p1.modules = [""]
	p1.weapon_index = 0
	p1.global_position = Vector2(500.0, 1200.0)
	var a := _dummy("brute", Vector2(620.0, 1200.0))
	var b := _dummy("brute", Vector2(690.0, 1200.0))
	await _frames(3)
	Input.action_press("p1_fire")
	await _frames(30)
	Input.action_release("p1_fire")
	_check(a.hp < 5000.0 and b.hp < 5000.0, "Der Flammenstrahl geht durch beide Gegner")
	_check(a.statuses.has("burning"), "Flamer brennt Gegner an (fester Feuer-Effekt)")
	_clear()

	# Six Pack: sechs Dosen, jede explodiert.
	p1.weapons = ["sixpack"]
	p1.modules = [""]
	p1.weapon_index = 0
	await _frames(3)
	_fire(p1, "sixpack")
	var cans := 0
	for child in main.projectiles.get_children():
		if child is Projectile and child.explosion_radius > 0.0 and child.arc_gravity > 0.0:
			cans += 1
	_check(cans == 6, "Six Pack wirft sechs Dosen (%d)" % cans)
	_clear()
	var target := _dummy("brute", Vector2(650.0, 1200.0))
	await _frames(2)
	_fire(p1, "sixpack")
	var boom := await _until(func() -> bool: return target.hp < 5000.0, 180)
	_check(boom, "Die Dosen treffen und explodieren (%.0f Schaden)" % (5000.0 - target.hp))
	_clear()

	# Coinshot: Prallt ab und wird mit Gold staerker.
	p1.weapons = ["coinshot"]
	p1.modules = [""]
	p1.weapon_index = 0
	await _frames(3)
	p1.gold = 0
	_fire(p1, "coinshot")
	var poor: Projectile = null
	for child in main.projectiles.get_children():
		if child is Projectile:
			poor = child
	var poor_damage := poor.damage
	_check(poor.bounces == 3 and poor.style == "coin", "Coinshot: Muenzen prallen dreimal ab")
	_clear()
	p1.gold = 500
	_fire(p1, "coinshot")
	var rich: Projectile = null
	for child in main.projectiles.get_children():
		if child is Projectile:
			rich = child
	_check(rich.damage > poor_damage * 1.3, "Mit Gold wird der Schaden hoeher (%.1f gegen %.1f)" % [rich.damage, poor_damage])
	p1.gold = 5000
	_clear()
	_fire(p1, "coinshot")
	for child in main.projectiles.get_children():
		if child is Projectile:
			rich = child
	_check(rich.damage <= poor_damage * 1.61, "Der Goldbonus ist gedeckelt (%.1f)" % rich.damage)
	p1.gold = 0
	_clear()

	# Dispenser: Turm landet, schiesst auf den naechsten Gegner, Limit zwei.
	p1.weapons = ["dispenser"]
	p1.modules = [""]
	p1.weapon_index = 0
	await _frames(3)
	_fire(p1, "dispenser")
	var towers: Array = get_tree().get_nodes_in_group("deployables")
	_check(towers.size() == 1 and towers[0] is Sentry, "Ein Geschuetzturm wird geworfen")
	var tower: Sentry = towers[0]
	var landed := await _until(func() -> bool: return tower.planted, 240)
	_check(landed, "Er landet und steht still")
	var foe := _dummy("brute", Vector2(tower.global_position.x + 400.0, 1200.0))
	var hit := await _until(func() -> bool: return foe.hp < 5000.0, 240)
	_check(hit, "Der Turm schiesst auf den Gegner in Sichtweite (%.0f Schaden)" % (5000.0 - foe.hp))
	for i in 4:
		_fire(p1, "dispenser")
		await _frames(2)
	var count := 0
	for node in get_tree().get_nodes_in_group("deployables"):
		if node is Sentry:
			count += 1
	_check(count <= 2, "Hoechstens zwei Tuerme gleichzeitig (%d)" % count)
	_clear()


func _printer_set() -> void:
	_clear()
	_check(Weapons.CLASS_SETS.printer.size() == 5 and Weapons.CLASS_SETS.printer[0] == "dronegun", "Printbot hat fuenf Waffen, den Drohnenpuls zuerst")
	p1.weapons = ["boomdrone"]
	p1.modules = [""]
	p1.weapon_index = 0
	p1.global_position = Vector2(500.0, 1200.0)
	p1.refill_ammo()
	var foe := _dummy("brute", Vector2(900.0, 1200.0))
	await _frames(3)
	var ammo_before := p1.ammo_of(0)
	p1._fire_cooldown = 0.0
	Input.action_press("p1_fire")
	await _frames(2)
	Input.action_release("p1_fire")
	_check(ammo_before - p1.ammo_of(0) == 2, "Boomdrone verbraucht zwei Schuss pro Salve (%d)" % (ammo_before - p1.ammo_of(0)))
	var drones := 0
	for child in main.projectiles.get_children():
		if child is Projectile and child.style == "drone":
			drones += 1
	_check(drones == 2, "Zwei Sprengdrohnen fliegen los (%d)" % drones)
	var boom := await _until(func() -> bool: return foe.hp < 5000.0, 240)
	_check(boom, "Die Drohnen finden den Gegner und explodieren (%.0f Schaden)" % (5000.0 - foe.hp))
	_clear()

	# Toner Bomb: Wolke am Aufprall, verletzt und bremst.
	p1.weapons = ["toner"]
	p1.modules = [""]
	p1.weapon_index = 0
	await _frames(3)
	var victim := _dummy("brute", Vector2(660.0, 1200.0))
	_fire(p1, "toner")
	var cloud: Zone = null
	for i in 240:
		await get_tree().physics_frame
		for child in main.projectiles.get_children():
			if child is Zone:
				cloud = child
		if cloud != null:
			break
	_check(cloud != null, "Die Kartusche hinterlaesst eine Wolke")
	var inked := await _until(func() -> bool: return victim.statuses.has("inked"), 240)
	_check(inked and victim.statuses.speed_factor() < 0.7, "Gegner in der Wolke sind gebremst (%.2f)" % victim.statuses.speed_factor())
	_check(victim.hp < 5000.0, "und werden verletzt (%.0f)" % (5000.0 - victim.hp))
	var cloud_ref: WeakRef = weakref(cloud)
	var faded := await _until(func() -> bool: return cloud_ref.get_ref() == null, 400)
	_check(faded, "Die Wolke verschwindet nach ein paar Sekunden")
	_clear()

	# Labeler: markierte Gegner nehmen mehr Schaden.
	p1.weapons = ["label"]
	p1.modules = [""]
	p1.weapon_index = 0
	await _frames(3)
	var marked := _dummy("brute", Vector2(800.0, p1.global_position.y - 8.0))
	_fire(p1, "label")
	var tagged := await _until(func() -> bool: return marked.statuses.has("tagged"), 120)
	_check(tagged, "Das Etikett markiert den Gegner")
	var hp := marked.hp
	marked.take_damage(100.0, p2, Vector2.ZERO, "")
	_check(absf((hp - marked.hp) - 130.0) < 1.0, "Auch der Partner macht 30 Prozent mehr Schaden (%.0f)" % (hp - marked.hp))
	_clear()

	# Paper Jam: Welle betaeubt, danach kurz immun.
	p1.weapons = ["paperjam"]
	p1.modules = [""]
	p1.weapon_index = 0
	p1.global_position = Vector2(500.0, 1200.0)
	await _frames(3)
	var close := _dummy("brute", Vector2(650.0, p1.global_position.y - 8.0))
	_fire(p1, "paperjam")
	var sheets := 0
	for child in main.projectiles.get_children():
		if child is Projectile and child.style == "paper":
			sheets += 1
	_check(sheets == 7, "Sieben Blaetter in der Welle (%d)" % sheets)
	var stunned := await _until(func() -> bool: return close.stunned_time > 0.0, 60)
	_check(stunned, "Ein Gegner in der Naehe wird betaeubt")
	close.stunned_time = 0.0
	_clear()
	close = _dummy("brute", Vector2(650.0, p1.global_position.y - 8.0))
	close._stun_immunity = 1.0
	await _frames(2)
	_fire(p1, "paperjam")
	await _frames(40)
	_check(close.stunned_time == 0.0, "Direkt nach einer Betaeubung ist er immun")
	_clear()


func _all_sets() -> void:
	var seen := {}
	var ok := true
	for class_id in Weapons.CLASS_SETS:
		var set: Array = Weapons.CLASS_SETS[class_id]
		ok = ok and set.size() == 5 and set[0] == RobotClasses.get_stats(class_id).weapons[0]
		for id in set:
			ok = ok and Weapons.owner_of(id) == class_id and not seen.has(id) and Weapons.ALL_IDS.has(id)
			seen[id] = true
	_check(ok, "Jede Klasse hat genau fuenf eigene Waffen, ohne Ueberschneidung")
	_check(seen.size() == 20 and Weapons.ALL_IDS.size() == 24, "20 Klassenwaffen und 4 allgemeine (%d von %d)" % [seen.size(), Weapons.ALL_IDS.size()])
	var texts := true
	for id in Weapons.ALL_IDS:
		texts = texts and Archive.WEAPON_TEXT.has(id)
	_check(texts, "Jede Waffe hat einen Archiv-Text")
