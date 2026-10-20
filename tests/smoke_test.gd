extends Node
## Automatischer Smoke-Test: startet die Hauptszene, simuliert Eingaben und
## prueft Bewegung, Sprung, Dash, Schuss und die Hexapod-Regel.
## Ausfuehren: godot --headless --path . res://tests/smoke_test.tscn

var main: Node
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.test_loadout = true
	main.use_dummies = true
	main.director_enabled = false
	main.intro_enabled = false
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


func _reset_dummy(dummy: TestDummy) -> void:
	dummy.health = dummy.max_health


func _run() -> void:
	await _frames(40)
	var p1: Player = main.players[0]
	var p2: Player = main.players[1]
	_check(p1.is_on_floor() and p2.is_on_floor(), "Beide Spieler stehen auf dem Boden")

	# Laufen
	var x0 := p1.global_position.x
	Input.action_press("p1_right")
	await _frames(30)
	Input.action_release("p1_right")
	_check(p1.global_position.x > x0 + 80.0, "P1 laeuft nach rechts")
	await _frames(30)

	# Sprung
	var y0 := p1.global_position.y
	Input.action_press("p1_jump")
	await _frames(12)
	var y1 := p1.global_position.y
	Input.action_release("p1_jump")
	_check(y1 < y0 - 40.0, "P1 springt (Hoehe gewonnen: %d)" % int(y0 - y1))
	await _frames(90)
	_check(p1.is_on_floor(), "P1 landet wieder")

	# Dash
	p1.velocity = Vector2.ZERO
	var dx0 := p1.global_position.x
	var charges := p1.dash_charges
	Input.action_press("p1_right")
	Input.action_press("p1_dash")
	await _frames(3)
	Input.action_release("p1_dash")
	await _frames(14)
	Input.action_release("p1_right")
	_check(p1.global_position.x > dx0 + 150.0, "P1 dasht (Strecke: %d)" % int(p1.global_position.x - dx0))
	_check(p1.dash_charges == charges - 1, "Dash verbraucht eine Aufladung")
	await _frames(120)
	_check(p1.dash_charges == charges, "Dash-Aufladung regeneriert sich")

	# Schuss auf Puppe
	var dummy: TestDummy = null
	for child in main.get_children():
		if child is TestDummy:
			dummy = child
			break
	p1.global_position = Vector2(1100.0, 1210.0)
	p1.velocity = Vector2.ZERO
	await _frames(5)
	var hp_before := dummy.health
	Input.action_press("p1_fire")
	await _frames(60)
	Input.action_release("p1_fire")
	_check(dummy.health < hp_before, "P1 trifft Puppe (HP %d -> %d)" % [int(hp_before), int(dummy.health)])

	# Hexapod darf in der Bewegung nicht schiessen, im Stand schon
	var shots := [0]
	p2.fired.connect(func(_p: Player, _id: String, _o: Vector2, _d: Vector2, _c: float) -> void: shots[0] += 1)
	Input.action_press("p2_right")
	Input.action_press("p2_fire")
	await _frames(12)
	shots[0] = 0
	await _frames(25)
	_check(shots[0] == 0, "Hexapod schiesst nicht in der Bewegung")
	Input.action_release("p2_right")
	await _frames(30)
	shots[0] = 0
	await _frames(60)
	Input.action_release("p2_fire")
	_check(shots[0] >= 1, "Hexapod schiesst im Stand (Schuesse: %d)" % shots[0])

	# Waffen: Wechsel, Schrot, Rakete, Sniper und Strahl
	p1.global_position = Vector2(1100.0, 1210.0)
	p1.velocity = Vector2.ZERO
	p2.global_position = Vector2(1100.0, 1210.0)
	p2.velocity = Vector2.ZERO
	await _frames(10)

	_check(p1.current_weapon_id() == "dust", "P1 startet mit Staubkugeln")
	Input.action_press("p1_weapon")
	await _frames(3)
	Input.action_release("p1_weapon")
	await _frames(15)
	_check(p1.current_weapon_id() == "shotgun", "Waffenwechsel auf Schrot")

	_reset_dummy(dummy)
	var before_children: int = main.projectiles.get_child_count()
	Input.action_press("p1_fire")
	await _frames(2)
	Input.action_release("p1_fire")
	var pellets: int = main.projectiles.get_child_count() - before_children
	_check(pellets >= 8, "Schrot verschiesst mehrere Kugeln (%d)" % pellets)
	await _frames(40)

	Input.action_press("p1_weapon")
	await _frames(3)
	Input.action_release("p1_weapon")
	await _frames(15)
	_check(p1.current_weapon_id() == "rocket", "Waffenwechsel auf Rakete")
	_reset_dummy(dummy)
	Input.action_press("p1_fire")
	await _frames(2)
	Input.action_release("p1_fire")
	await _frames(40)
	_check(dummy.health < dummy.max_health - 30.0, "Rakete trifft mit Explosion (HP %d)" % int(dummy.health))

	_reset_dummy(dummy)
	Input.action_press("p2_fire")
	await _frames(3)
	Input.action_release("p2_fire")
	await _frames(5)
	_check(dummy.health <= dummy.max_health - 30.0, "Geschuetz trifft sofort (HP %d)" % int(dummy.health))
	await _frames(60)

	for i in 2:
		Input.action_press("p2_weapon")
		await _frames(3)
		Input.action_release("p2_weapon")
		await _frames(15)
	_reset_dummy(dummy)
	Input.action_press("p2_fire")
	await _frames(30)
	Input.action_release("p2_fire")
	_check(p2.current_weapon_id() == "beam" and dummy.health < dummy.max_health - 20.0, "Strahl macht Dauerschaden (HP %d)" % int(dummy.health))

	# Puppe stirbt, verschwindet und kommt nach der Wartezeit zurueck
	var dummy_count := 0
	for child in main.get_children():
		if child is TestDummy:
			dummy_count += 1
	dummy.take_damage(100000.0, p1)
	await _frames(2)
	var after_death := 0
	for child in main.get_children():
		if child is TestDummy:
			after_death += 1
	_check(after_death == dummy_count - 1, "Tote Puppe verschwindet (%d -> %d)" % [dummy_count, after_death])
	await _frames(int(main.DUMMY_RESPAWN_TIME * 60.0) + 10)
	var after_respawn := 0
	for child in main.get_children():
		if child is TestDummy:
			after_respawn += 1
	_check(after_respawn == dummy_count, "Puppe kommt zurueck (%d)" % after_respawn)

	print("Fertig, Fehler: ", failures)
	get_tree().quit(failures)
