extends Node
## Test des Hexapods: Wandklettern, Geschuetz nur im Stand mit Aufbauzeit.
## Ausfuehren: godot --headless --path . res://tests/hexapod_test.tscn

var main: Node
var failures := 0
var hexapod: Player
var roomba: Player


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.use_dummies = true
	main.test_loadout = true
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


func _place(player: Player, pos: Vector2) -> void:
	player.global_position = pos
	player.velocity = Vector2.ZERO


func _run() -> void:
	await _frames(40)
	roomba = main.players[0]
	hexapod = main.players[1]
	_check(hexapod.class_id == "hexapod" and hexapod.weapons[0] == "turret", "Hexapod startet mit dem Geschuetz")

	# Wandklettern: Hexapod klettert die linke Arenawand hoch, der Roomba nicht
	_place(hexapod, Vector2(40.0, 1210.0))
	_place(roomba, Vector2(60.0, 1210.0))
	await _frames(10)
	Input.action_press("p2_left")
	Input.action_press("p2_up")
	Input.action_press("p1_left")
	Input.action_press("p1_up")
	await _frames(80)
	_check(hexapod.is_clinging() and hexapod.global_position.y < 900.0, "Hexapod klettert die Wand hoch (y=%.0f)" % hexapod.global_position.y)
	_check(roomba.global_position.y > 1150.0, "Roomba kann nicht klettern (y=%.0f)" % roomba.global_position.y)
	Input.action_release("p1_left")
	Input.action_release("p1_up")

	# Haengen: ohne hoch/runter bleibt er an Ort und Stelle
	Input.action_release("p2_up")
	await _frames(10)
	var hang_y := hexapod.global_position.y
	await _frames(40)
	_check(hexapod.is_clinging() and absf(hexapod.global_position.y - hang_y) < 6.0, "Ohne Eingabe haengt er an der Wand")

	# An der Wand kann er schiessen, sobald er aufgebaut ist
	var shots := [0]
	hexapod.fired.connect(func(_p: Player, _id: String, _o: Vector2, _d: Vector2, _c: float) -> void: shots[0] += 1)
	Input.action_press("p2_fire")
	await _frames(40)
	Input.action_release("p2_fire")
	_check(shots[0] >= 1, "Haengend an der Wand schiesst das Geschuetz (%d Schuesse)" % shots[0])

	# Beim Klettern nicht
	shots[0] = 0
	Input.action_press("p2_up")
	Input.action_press("p2_fire")
	await _frames(40)
	Input.action_release("p2_fire")
	Input.action_release("p2_up")
	_check(shots[0] == 0, "Waehrend des Kletterns schiesst er nicht")

	# Von der Wand abspringen
	Input.action_press("p2_jump")
	await _frames(3)
	Input.action_release("p2_jump")
	Input.action_release("p2_left")
	await _frames(3)
	_check(hexapod.velocity.x > 200.0 and hexapod.velocity.y < -300.0, "Wandsprung stoesst von der Wand ab (%.0f, %.0f)" % [hexapod.velocity.x, hexapod.velocity.y])
	await _frames(150)

	# Aufbauzeit: direkt nach dem Stehenbleiben schiesst er noch nicht
	_place(hexapod, Vector2(1000.0, 1210.0))
	await _frames(10)
	Input.action_press("p2_right")
	await _frames(30)
	Input.action_release("p2_right")
	await _frames(2)
	shots[0] = 0
	Input.action_press("p2_fire")
	await _frames(5)
	var early: int = shots[0]
	await _frames(30)
	Input.action_release("p2_fire")
	_check(early == 0, "Direkt nach dem Stehenbleiben ist das Geschuetz noch nicht aufgebaut")
	_check(shots[0] >= 1, "Danach schiesst es (%d Schuesse)" % shots[0])

	# In der Luft kein Schuss
	_place(hexapod, Vector2(1000.0, 600.0))
	shots[0] = 0
	Input.action_press("p2_fire")
	await _frames(10)
	Input.action_release("p2_fire")
	_check(shots[0] == 0, "In der Luft schiesst er nicht")
	await _frames(100)

	# Feuerrate: deutlich schneller als der alte Sniper (0,9 pro Sekunde)
	_place(hexapod, Vector2(1000.0, 1210.0))
	await _frames(30)
	shots[0] = 0
	Input.action_press("p2_fire")
	await _frames(120)
	Input.action_release("p2_fire")
	_check(shots[0] >= 4, "Schnelle Schussrate (%d Schuesse in 2 s)" % shots[0])

	# Nur die Klassenwaffe ist an den Stand gebunden: der Sniper aus dem Shop nicht
	hexapod.weapon_index = 1
	await _frames(20)
	shots[0] = 0
	Input.action_press("p2_right")
	Input.action_press("p2_fire")
	await _frames(40)
	Input.action_release("p2_fire")
	Input.action_release("p2_right")
	_check(shots[0] >= 1, "Andere Waffen duerfen im Gehen schiessen (%d)" % shots[0])
	await _frames(10)

	# Mantle: am Schacht hochklettern und auf die Plattform oben hopsen
	hexapod.weapon_index = 0
	_place(hexapod, Vector2(2574.0, 1210.0))
	await _frames(10)
	Input.action_press("p2_right")
	Input.action_press("p2_up")
	for i in 300:
		await _frames(1)
		if hexapod.global_position.y < 680.0 and hexapod.is_on_floor():
			break
	Input.action_release("p2_right")
	Input.action_release("p2_up")
	await _frames(30)
	_check(hexapod.global_position.y < 690.0 and hexapod.is_on_floor(), "Hexapod klettert den Schacht hoch und steht oben (y=%.0f)" % hexapod.global_position.y)

	print("Fertig, Fehler: ", failures)
	get_tree().quit(failures)
