extends Node
## Test der neuen Bewegungs-Firmware: Jet Boots, Turbo Legs, Spring Legs, Blade Dash, Long Dash, dritte Stufe von Double Jump und Dash Cell.
## Ausfuehren: godot --headless --path . res://tests/mobility_test.tscn

var main: Node
var failures := 0
var p1: Player


func _ready() -> void:
	Engine.set_meta("classes", ["roomba", "hexapod"])
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.use_dummies = true
	main.shaft_lift = false
	main.intro_enabled = false
	main.stage_id = "classic"
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


func _place(pos: Vector2) -> void:
	p1.global_position = pos
	p1.velocity = Vector2.ZERO
	p1.hook_active = false


## Springt (Sprung gehalten oder getippt) und gibt die hoechste erreichte Hoehe zurueck (kleiner y = hoeher).
func _apex(hold_frames: int) -> float:
	_place(Vector2(600.0, 1210.0))
	await _frames(25)
	var start_y := p1.global_position.y
	var top := start_y
	await get_tree().physics_frame
	Input.action_press("p1_jump")
	for i in 120:
		await get_tree().physics_frame
		if i == hold_frames:
			Input.action_release("p1_jump")
		top = minf(top, p1.global_position.y)
	Input.action_release("p1_jump")
	await _frames(60)
	return start_y - top


func _run() -> void:
	await _frames(40)
	p1 = main.players[0]
	main.players[1].global_position = Vector2(300.0, 1210.0)
	main.players[1].invulnerable = true
	p1.invulnerable = true

	# Daten: jede Firmware hat Kurzname und Beschreibung
	var complete := true
	for id in Firmware.DATA:
		complete = complete and Firmware.SHORT.has(id) and String(Firmware.DATA[id].text) != ""
	_check(complete, "Jede Firmware hat Kurzname und Text")
	_check(int(Firmware.DATA.double_jump.max) == 3 and int(Firmware.DATA.dash_charge.max) == 3, "Dritte Stufe fuer Double Jump und Dash Cell")

	# Turbo Legs
	var speed_before := p1.base_speed()
	p1.add_firmware("sprint")
	_check(is_equal_approx(p1.base_speed(), speed_before * (1.0 + Firmware.SPRINT_BONUS) / 1.0) or p1.base_speed() > speed_before * 1.09, "Turbo Legs machen schneller (%d -> %d)" % [speed_before, p1.base_speed()])

	# Spring Legs: hoeherer Sprung
	var low := await _apex(8)
	p1.add_firmware("spring")
	p1.add_firmware("spring")
	var high := await _apex(8)
	_check(p1.jump_speed() > float(p1.stats.jump_speed) * 1.2 and high > low * 1.2, "Spring Legs springen hoeher (%d -> %d)" % [low, high])

	# Jet Boots: Sprung halten gibt zusaetzliche Hoehe, der Tank leert sich und fuellt sich am Boden
	var plain := await _apex(100)
	p1.add_firmware("jet")
	var jetted := await _apex(100)
	_check(jetted > plain + 150.0, "Jet Boots tragen deutlich hoeher (%d -> %d)" % [plain, jetted])
	_check(p1._jet_fuel > 0.95, "Der Tank fuellt sich am Boden wieder (%.2f)" % p1._jet_fuel)
	p1._jet_fuel = 0.0
	_place(Vector2(600.0, 1210.0))
	await _frames(25)
	p1._jet_fuel = 0.0
	await get_tree().physics_frame
	Input.action_press("p1_jump")
	var top := 0.0
	for i in 90:
		await get_tree().physics_frame
		top = maxf(top, 1210.0 - p1.global_position.y)
	Input.action_release("p1_jump")
	_check(top < plain + 40.0 and not p1.jet_active, "Mit leerem Tank gibt es keinen Schub (%d)" % top)
	await _frames(80)

	# Dritte Stufe Double Jump: zwei Spruenge in der Luft
	p1.add_firmware("double_jump")
	p1.add_firmware("double_jump")
	_place(Vector2(600.0, 1210.0))
	await _frames(25)
	_check(p1._air_jumps_left == 2, "Zwei Luftspruenge mit zwei Stapeln (%d)" % p1._air_jumps_left)

	# Long Dash: weiter
	p1.firmware.erase("jet")
	_place(Vector2(600.0, 1210.0))
	await _frames(25)
	p1.dash_charges = p1.dash_max()
	var x0 := p1.global_position.x
	Input.action_press("p1_right")
	await get_tree().physics_frame
	p1._try_dash()
	await _frames(14)
	Input.action_release("p1_right")
	var short := p1.global_position.x - x0
	await _frames(50)
	p1.add_firmware("long_dash")
	p1.add_firmware("long_dash")
	_place(Vector2(600.0, 1210.0))
	await _frames(25)
	p1.dash_charges = p1.dash_max()
	x0 = p1.global_position.x
	Input.action_press("p1_right")
	await get_tree().physics_frame
	p1._try_dash()
	await _frames(14)
	Input.action_release("p1_right")
	var long_distance := p1.global_position.x - x0
	_check(p1.dash_time() > Player.DASH_TIME * 1.5 and long_distance > short * 1.25, "Long Dash traegt weiter (%d -> %d)" % [short, long_distance])
	await _frames(50)

	# Blade Dash: Gegner auf dem Weg werden einmal getroffen
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await _frames(3)
	var dummy: Enemy = main.director.spawn("brute", Vector2(780.0, 1190.0))
	dummy.set_physics_process(false)
	dummy.hp = 5000.0
	dummy.max_hp = 5000.0
	await _frames(3)
	var hp_before: float = dummy.hp
	_place(Vector2(600.0, 1210.0))
	await _frames(25)
	p1.dash_charges = p1.dash_max()
	Input.action_press("p1_right")
	await get_tree().physics_frame
	p1._try_dash()
	await _frames(25)
	Input.action_release("p1_right")
	_check(dummy.hp == hp_before, "Ohne Blade Dash passiert dem Gegner nichts")
	p1.add_firmware("blade")
	_place(Vector2(600.0, 1210.0))
	await _frames(25)
	p1.dash_charges = p1.dash_max()
	Input.action_press("p1_right")
	await get_tree().physics_frame
	p1._try_dash()
	await _frames(25)
	Input.action_release("p1_right")
	var lost := hp_before - dummy.hp
	_check(lost > 10.0 and lost < Firmware.BLADE_DAMAGE * p1.damage_mult() * 1.5, "Blade Dash trifft den Gegner genau einmal (%.0f Schaden)" % lost)

	print("Fertig, Fehler: ", failures)
	get_tree().quit(failures)
