extends Node
## Test der Klassenfaehigkeiten (L2).
## Ausfuehren: godot --headless --path . res://tests/ability_test.tscn

var main: Node
var failures := 0
var shots := 0


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


func _start(classes: Array) -> void:
	if main != null:
		main.queue_free()
		await get_tree().process_frame
	Engine.set_meta("classes", classes)
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	main.stage_id = "classic"
	add_child(main)
	await _frames(20)
	for p in main.players:
		p.iframes = 0.0


func _enemy(kind: String, pos: Vector2) -> Enemy:
	var e: Enemy = main.director.spawn(kind, pos)
	e._cooldown = 99.0
	return e


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _roomba_and_hexapod()
	await _vending_and_printer()
	print("Fertig, Fehler: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


func _roomba_and_hexapod() -> void:
	await _start(["roomba", "hexapod"])
	var p1: Player = main.players[0]
	var p2: Player = main.players[1]
	p1.global_position = Vector2(1000.0, 1225.0)
	p2.global_position = Vector2(2000.0, 1225.0)
	await _frames(5)

	# Roomba: Sog zieht Gegner und Beute heran.
	var walker := _enemy("walker", Vector2(1450.0, 1225.0))
	var coin := Pickup.new()
	coin.kind = "gold"
	coin.players = main.players
	coin.floor_y = 1250.0
	coin.position = Vector2(1500.0, 1240.0)
	main.pickups.add_child(coin)
	var start_gap := walker.global_position.x - p1.global_position.x
	_check(p1.ability.is_ready(), "Faehigkeit startet bereit")
	await _tap("p1_ability")
	_check(p1.ability.is_active("suck") and not p1.ability.is_ready(), "L2 loest den Sog aus")
	await _frames(45)
	var gap := walker.global_position.x - p1.global_position.x
	_check(start_gap - gap > 200.0, "Sog zieht den Gegner heran (%d -> %d)" % [start_gap, gap])
	_check(gap > 120.0, "Der Gegner kommt nicht in sein Gesicht (%d)" % gap)
	_check(walker.stunned_time > 0.0, "Der Gegner im Wirbel ist betaeubt")
	_check(not is_instance_valid(coin) or coin.force_pull, "Sog zieht Beute heran")
	_check(not p1.ability.try_use(), "Abklingzeit sperrt erneutes Ausloesen")
	await _frames(60)
	_check(not is_instance_valid(walker) or walker.hp < walker.max_hp, "Wirbel und Druckwelle treffen den Gegner")

	# Hexapod: Overwatch erlaubt Schuss in Bewegung mit doppelter Rate.
	main.players[1].fired.connect(func(_p: Player, _w: String, _o: Vector2, _d: Vector2, _c: float) -> void: shots += 1)
	p2.global_position = Vector2(2000.0, 1225.0)
	await _frames(40)
	shots = 0
	Input.action_press("p2_fire")
	await _frames(60)
	var standing := shots
	Input.action_release("p2_fire")
	await _frames(20)
	p2.ability.try_use()
	shots = 0
	Input.action_press("p2_fire")
	await _frames(60)
	var boosted := shots
	Input.action_press("p2_right")
	shots = 0
	await _frames(30)
	var moving := shots
	Input.action_release("p2_right")
	Input.action_release("p2_fire")
	_check(boosted > standing * 1.5, "Overwatch verdoppelt die Feuerrate (%d -> %d)" % [standing, boosted])
	_check(moving >= 3, "Overwatch schiesst auch in Bewegung (%d Schuesse)" % moving)


func _vending_and_printer() -> void:
	await _start(["vending", "printer"])
	var p1: Player = main.players[0]
	var p2: Player = main.players[1]
	p1.global_position = Vector2(1000.0, 1195.0)
	p2.global_position = Vector2(2200.0, 1215.0)
	await _frames(20)

	# Automat: Walze halbiert Schaden und rammt Gegner.
	var hp_before := p1.hp
	p1.take_hit(20.0, p1.global_position + Vector2(50.0, 0.0))
	var normal_loss := hp_before - p1.hp
	p1.iframes = 0.0
	p1.hp = hp_before
	await _tap("p1_ability")
	_check(p1.ability.is_active("roll"), "L2 startet die Walze")
	p1.take_hit(20.0, p1.global_position + Vector2(50.0, 0.0))
	var rolled_loss := hp_before - p1.hp
	_check(absf(rolled_loss - normal_loss * 0.5) < 0.01, "Walze halbiert den Schaden (%.0f -> %.0f)" % [normal_loss, rolled_loss])
	var base_speed := float(p1.stats.speed)
	_check(p1.move_speed() > base_speed * 1.5, "Walze ist schneller")
	await _frames(20)
	p1.velocity = Vector2.ZERO
	var brute := _enemy("brute", p1.global_position + Vector2(70.0, 20.0))
	var brute_hp := brute.hp
	await _frames(40)
	_check(brute.hp < brute_hp - 15.0, "Walze verletzt Gegner im Weg (%d -> %d)" % [brute_hp, brute.hp])

	# Drucker: zwei Drohnen schiessen auf Gegner.
	var target := _enemy("brute", p2.global_position + Vector2(380.0, 20.0))
	var target_hp := target.hp
	await _tap("p2_ability")
	var state := p2._art_state()
	_check(float(state.launch) >= 0.0 and float(state.print) < 0.2, "Nach dem Druck geht die Tür auf und der Druck beginnt neu")
	var drones := get_tree().get_nodes_in_group("drones")
	_check(p2.ability.is_active("print") and drones.size() == 2, "L2 druckt zwei Drohnen (%d)" % drones.size())
	await _frames(120)
	_check(target.hp < target_hp - 10.0, "Drohnen beschiessen Gegner (%d -> %d)" % [target_hp, target.hp])
	for d in drones:
		d.life = 0.05
	await _frames(10)
	_check(get_tree().get_nodes_in_group("drones").is_empty(), "Drohnen verschwinden nach Ablauf")

	# Der Drucker schiesst nur ueber seine Begleitdrohnen und wird dabei nicht zurueckgestossen.
	_check(p2.escorts.size() == 2 and get_tree().get_nodes_in_group("escorts").size() == 2, "Drucker hat zwei Begleitdrohnen")
	await _frames(40)
	p2.velocity = Vector2.ZERO
	var origins: Array[Vector2] = []
	p2.fired.connect(func(_p: Player, _w: String, origin: Vector2, _d: Vector2, _c: float) -> void:
		origins.append(origin))
	Input.action_press("p2_fire", 1.0)
	await _frames(20)
	Input.action_release("p2_fire")
	_check(origins.size() >= 2, "Drucker feuert (%d Schuesse)" % origins.size())
	var from_drone := origins.size() >= 2
	for origin in origins:
		var near := false
		for drone in p2.escorts:
			if origin.distance_to(drone.global_position) < 60.0:
				near = true
		from_drone = from_drone and near
	_check(from_drone, "Schuesse kommen aus den Drohnen")
	_check(absf(p2.velocity.x) < 1.0, "Drohnenschuesse stossen den Drucker nicht zurueck (%.1f)" % p2.velocity.x)

	# Druckbot: Kills verkuerzen die Abklingzeit, Drohnen erben das Modul.
	var cd_before: float = p2.ability.cooldown
	var victim := _enemy("brute", p2.global_position + Vector2(60.0, 0.0))
	victim.take_damage(9999.0, p2, Vector2.RIGHT, "")
	await _frames(2)
	_check(p2.ability.cooldown < cd_before - 0.12, "Kill verkuerzt Druckbot-Abklingzeit (%.2f -> %.2f)" % [cd_before, p2.ability.cooldown])
	p2.set_module("fire")
	p2.ability.cooldown = 0.0
	await _tap("p2_ability")
	var fire_drone: Drone = get_tree().get_nodes_in_group("drones")[0]
	_check(fire_drone._tint() == Elements.COLORS["fire"], "Drohne zeigt Modulfarbe")
	for d in get_tree().get_nodes_in_group("drones"):
		d.life = 0.05
	await _frames(10)
