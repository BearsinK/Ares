extends Node
## Test der Bewegungs-Firmware: Doppelsprung, Wandsprung, Gleiten, Bodenstoss,
## Haken, durchlaessige Plattformen.
## Ausfuehren: godot --headless --path . res://tests/movement_test.tscn

var main: Node
var failures := 0
var p1: Player


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.use_dummies = true
	main.shaft_lift = false
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


func _tap(action: String, frames := 3) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)


func _place(pos: Vector2) -> void:
	p1.global_position = pos
	p1.velocity = Vector2.ZERO
	p1.hook_active = false


func _run() -> void:
	await _frames(40)
	p1 = main.players[0]
	main.players[1].global_position = Vector2(300.0, 1210.0)

	# Ohne Firmware: kein Doppelsprung
	_place(Vector2(600.0, 1210.0))
	await _frames(20)
	await _tap("p1_jump", 20)
	var top1 := p1.global_position.y
	await _tap("p1_jump", 3)
	await _frames(10)
	_check(p1.velocity.y > -200.0, "Ohne Firmware gibt es keinen zweiten Sprung")
	await _frames(100)

	# Doppelsprung
	p1.add_firmware("double_jump")
	_place(Vector2(600.0, 1210.0))
	await _frames(20)
	await _tap("p1_jump", 12)
	await _frames(5)
	var vy_before := p1.velocity.y
	await _tap("p1_jump", 3)
	await _frames(2)
	_check(p1.velocity.y < vy_before - 300.0, "Doppelsprung gibt einen zweiten Impuls (%.0f -> %.0f)" % [vy_before, p1.velocity.y])
	await _frames(120)

	# Gleiten: Fallgeschwindigkeit begrenzt, solange Sprung gehalten wird
	_place(Vector2(880.0, 500.0))
	await _frames(40)
	var fall_fast := p1.velocity.y
	_check(fall_fast > 400.0, "Ohne Gleiten faellt man schnell (%.0f)" % fall_fast)
	p1.add_firmware("glide")
	_place(Vector2(880.0, 500.0))
	await _frames(5)
	Input.action_press("p1_jump")
	await _frames(40)
	var fall_glide := p1.velocity.y
	Input.action_release("p1_jump")
	_check(fall_glide <= 170.0, "Gleiten begrenzt die Fallgeschwindigkeit (%.0f)" % fall_glide)
	await _frames(200)

	# Wandsprung im Schacht (linke Schachtwand endet bei x=2640)
	p1.add_firmware("wall_jump")
	_place(Vector2(2662.0, 900.0))
	await _frames(3)
	Input.action_press("p1_left")
	await _frames(30)
	var slide := p1.velocity.y
	_check(slide <= 150.0 and slide >= 0.0, "Wandrutschen bremst den Fall (%.0f)" % slide)
	await _tap("p1_jump", 3)
	await _frames(3)
	Input.action_release("p1_left")
	_check(p1.velocity.x > 200.0 and p1.velocity.y < -300.0, "Wandsprung stoesst von der Wand ab (%.0f, %.0f)" % [p1.velocity.x, p1.velocity.y])
	await _frames(150)

	# Bodenstoss: Aufprall macht Flaechenschaden
	p1.add_firmware("slam")
	var dummy := TestDummy.new()
	dummy.position = Vector2(900.0, 1210.0)
	dummy.max_health = 100000.0
	dummy.health = 100000.0
	main.add_child(dummy)
	var target_x := dummy.global_position.x
	var hp_before := dummy.health
	_place(Vector2(target_x - 60.0, 700.0))
	await _frames(5)
	Input.action_press("p1_down")
	await _tap("p1_jump", 3)
	await _frames(2)
	_check(p1.velocity.y > 1000.0, "Bodenstoss beschleunigt nach unten (%.0f)" % p1.velocity.y)
	await _frames(40)
	Input.action_release("p1_down")
	_check(dummy.health < hp_before - 20.0, "Bodenstoss-Aufprall verletzt Gegner (%.0f)" % (hp_before - dummy.health))
	await _frames(60)

	# Plattformen sind von unten durchlaessig und tragen von oben
	_place(Vector2(250.0, 1210.0))
	await _frames(20)
	await _tap("p1_jump", 25)
	await _frames(90)
	var stand_y := 1130.0 - float(p1.stats.size.y) * 0.5
	_check(absf(p1.global_position.y - stand_y) < 4.0,
		"Spieler springt durch die Plattform und landet darauf (y=%.0f, erwartet %.0f)" % [p1.global_position.y, stand_y])

	# Durchfallen: unten + Sprung auf einer Plattform
	var on_platform_y := p1.global_position.y
	Input.action_press("p1_down")
	await _tap("p1_jump", 3)
	await _frames(30)
	Input.action_release("p1_down")
	_check(p1.global_position.y > on_platform_y + 20.0, "Unten + Sprung laesst den Spieler durch die Plattform fallen")
	await _frames(60)

	# Haken: zieht zum Ankerpunkt (Plattformunterseite), ohne Firmware passiert nichts
	_place(Vector2(1100.0, 1210.0))
	await _frames(15)
	var hook_start_y := p1.global_position.y
	Input.action_press("p1_aim_up")
	await _frames(3)
	await _tap("p1_hook", 3)
	_check(not p1.hook_active, "Ohne Firmware gibt es keinen Haken")
	p1.add_firmware("hook")
	await _tap("p1_hook", 3)
	_check(p1.hook_active, "Haken trifft die Plattform und haengt")
	await _frames(12)
	Input.action_release("p1_aim_up")
	_check(p1.global_position.y < hook_start_y - 40.0, "Haken zieht den Spieler nach oben (y=%.0f)" % p1.global_position.y)
	await _frames(100)

	print("Fertig, Fehler: ", failures)
	get_tree().quit(failures)
