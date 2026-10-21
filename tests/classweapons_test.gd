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
