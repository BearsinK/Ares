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
	_check(hexapod._cling_amount > 0.9 and absf(float(hexapod._art_state().rot)) > 1.2, "An der Wand dreht sich der Koerper zur Wand")
	_check(absf(hexapod._climb_phase) > 0.5 and absf(hexapod._climb_phase) < 40.0, "Beim Klettern laeuft die Kletteranimation (%.1f)" % hexapod._climb_phase)
	_check(roomba.global_position.y > 1150.0, "Roomba kann nicht klettern (y=%.0f)" % roomba.global_position.y)
	Input.action_release("p1_left")
	Input.action_release("p1_up")

	# Haengen: ohne hoch/runter bleibt er an Ort und Stelle
	Input.action_release("p2_up")
	Input.action_release("p2_left")
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
	_place(hexapod, Vector2(2568.0, 800.0))
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

	await _ceiling()
	await _ceiling_fire()
	await _polish()
	print("Fertig, Fehler: ", failures)
	get_tree().quit(failures)


func _polish() -> void:
	# Aufstellen: sanft einblendend, im Stand weniger Schaden, in Bewegung nicht.
	hexapod.weapon_index = 0
	_place(hexapod, Vector2(850.0, 1210.0))
	await _frames(40)
	_check(hexapod.is_deployed() and hexapod._deploy_amount > 0.95, "Im Stand ist er aufgestellt (%.2f)" % hexapod._deploy_amount)
	hexapod.iframes = 0.0
	var hp := hexapod.hp
	hexapod.take_hit(20.0, hexapod.global_position + Vector2(30.0, 0.0))
	_check(is_equal_approx(hp - hexapod.hp, 16.0), "Aufgestellt steckt er 20 Prozent weniger ein (%.1f)" % (hp - hexapod.hp))
	hexapod.iframes = 0.0
	Input.action_press("p2_right")
	await _frames(25)
	_check(not hexapod.is_deployed() and hexapod._deploy_amount < 0.6, "In Bewegung klappt er die Beine wieder ein (%.2f)" % hexapod._deploy_amount)
	hp = hexapod.hp
	hexapod.take_hit(20.0, hexapod.global_position + Vector2(-30.0, 0.0))
	_check(is_equal_approx(hp - hexapod.hp, 20.0), "In Bewegung voller Schaden")
	Input.action_release("p2_right")
	hexapod.iframes = 0.0
	hexapod.velocity = Vector2.ZERO
	await _frames(40)

	# Schuss: Rueckstoss-Animation und Hitze.
	var saw_recoil := false
	var peak_heat := 0.0
	Input.action_press("p2_fire")
	for i in 60:
		await get_tree().physics_frame
		saw_recoil = saw_recoil or hexapod._recoil > 0.8
		peak_heat = maxf(peak_heat, hexapod._heat)
	Input.action_release("p2_fire")
	_check(saw_recoil and peak_heat > 0.2, "Schuss loest Rueckstoss und Hitze aus (Hitze %.2f)" % peak_heat)
	var state := hexapod._art_state()
	for key in ["squash", "deploy", "recoil", "heat", "climb", "hurt", "downed", "overdrive", "cling", "rot", "down"]:
		_check(state.has(key), "Animationszustand enthaelt %s" % key)

	# Ausfall und Wiederbeleben: Beine sacken ein und richten sich wieder auf.
	hexapod.iframes = 0.0
	hexapod.take_hit(9999.0, hexapod.global_position + Vector2(10.0, 0.0))
	await _frames(60)
	_check(hexapod.downed and hexapod._down_amount > 0.95, "Ausgeschaltet sackt er vollstaendig ein (%.2f)" % hexapod._down_amount)
	hexapod.revive(0.5)
	await _frames(70)
	_check(hexapod._down_amount < 0.05, "Nach dem Wiederbeleben steht er wieder auf (%.2f)" % hexapod._down_amount)

	# Landung: Stauchung nach hartem Fall.
	_place(hexapod, Vector2(850.0, 700.0))
	var saw_squash := false
	for i in 120:
		await get_tree().physics_frame
		saw_squash = saw_squash or hexapod._land_squash > 0.3
	_check(saw_squash, "Nach einem Fall staucht sich der Hexapod beim Landen")


func _ceiling() -> void:
	hexapod.revive(1.0)
	hexapod.weapon_index = 0
	# Unter einer Plattform festhalten (Plattform 1000..2100 bei y 1020..1044).
	_place(hexapod, Vector2(1500.0, 1072.0))
	await _frames(2)
	Input.action_press("p2_up")
	await _frames(20)
	_check(hexapod._ceiling and absf(hexapod.global_position.y - (1044.0 + 23.0 + 1.0)) < 2.0, "Hexapod haelt sich unter der Plattform fest (y=%.0f)" % hexapod.global_position.y)
	_check(hexapod._ceiling_amount > 0.9 and absf(float(hexapod._art_state().ceiling)) > 0.9, "Kopfueber: Zeichenzustand zeigt die Decke")
	# Er bleibt haengen und laeuft kopfueber entlang.
	var y0 := hexapod.global_position.y
	await _frames(30)
	_check(absf(hexapod.global_position.y - y0) < 1.0, "Haengend faellt er nicht")
	var x0 := hexapod.global_position.x
	Input.action_press("p2_right")
	await _frames(40)
	_check(hexapod._ceiling and hexapod.global_position.x > x0 + 80.0, "Er laeuft kopfueber entlang (%d px)" % (hexapod.global_position.x - x0))
	Input.action_release("p2_right")
	# Haengend im Stand ist er aufgestellt und kann schiessen.
	await _frames(30)
	_check(hexapod.is_deployed() and hexapod._can_fire("turret"), "Haengend im Stand ist das Geschuetz bereit")
	# Runter laesst ihn fallen.
	Input.action_release("p2_up")
	Input.action_press("p2_down")
	await _frames(25)
	Input.action_release("p2_down")
	_check(not hexapod._ceiling and hexapod.global_position.y > y0 + 20.0, "Runter loest ihn von der Decke")
	# Ohne Hoch-Taste greift er nicht.
	_place(hexapod, Vector2(1500.0, 1072.0))
	await _frames(10)
	_check(not hexapod._ceiling, "Ohne Hoch haelt er sich nicht fest")
	# Am Plattformrand faellt er herunter.
	_place(hexapod, Vector2(1500.0, 1072.0))
	Input.action_press("p2_up")
	await _frames(10)
	Input.action_press("p2_right")
	await _frames(240)
	Input.action_release("p2_right")
	Input.action_release("p2_up")
	_check(not hexapod._ceiling, "Am Ende der Plattform loest er sich")
	# Die Hallendecke geht auch.
	_place(hexapod, Vector2(800.0, 40.0))
	Input.action_press("p2_up")
	await _frames(15)
	Input.action_release("p2_up")
	_check(hexapod._ceiling and hexapod.global_position.y < 30.0, "Auch an der Hallendecke haelt er sich fest (y=%.0f)" % hexapod.global_position.y)
	Input.action_press("p2_down")
	await _frames(15)
	Input.action_release("p2_down")
	# Roomba kann das nicht.
	_place(roomba, Vector2(1500.0, 1140.0))
	Input.action_press("p1_up")
	await _frames(20)
	Input.action_release("p1_up")
	_check(not roomba._ceiling, "Nur der Hexapod klettert an Decken")

	# Wird er an der Decke ausgeschaltet, faellt er ab und haengt nicht mehr fest.
	_place(hexapod, Vector2(800.0, 40.0))
	Input.action_press("p2_up")
	await _frames(15)
	Input.action_release("p2_up")
	hexapod.iframes = 0.0
	hexapod.take_hit(9999.0, hexapod.global_position + Vector2(5.0, 0.0))
	await _frames(40)
	_check(hexapod.downed and not hexapod._ceiling and not hexapod._clinging and hexapod.global_position.y > 100.0, "Ausgeschaltet faellt er von der Decke (y=%.0f)" % hexapod.global_position.y)
	hexapod.revive(1.0)
	await _frames(30)



func _ceiling_fire() -> void:
	hexapod.revive(1.0)
	hexapod.weapon_index = 0
	_place(hexapod, Vector2(1500.0, 1072.0))
	await _frames(2)
	Input.action_press("p2_up")
	await _frames(20)
	var shots := [0]
	hexapod.fired.connect(func(_p: Player, _id: String, _o: Vector2, _d: Vector2, _c: float) -> void: shots[0] += 1)
	# Mit gehaltener Hoch-Taste (haengen) und Feuer.
	Input.action_press("p2_fire")
	await _frames(40)
	Input.action_release("p2_fire")
	_check(hexapod._ceiling and shots[0] >= 1, "An der Decke schiesst das Geschuetz mit gehaltener Hoch-Taste (%d Schuesse, ceiling %s)" % [shots[0], str(hexapod._ceiling)])
	Input.action_release("p2_up")
	await _frames(10)
	shots[0] = 0
	Input.action_press("p2_fire")
	await _frames(40)
	Input.action_release("p2_fire")
	_check(hexapod._ceiling and shots[0] >= 1, "An der Decke schiesst das Geschuetz im Haengen (%d Schuesse)" % shots[0])
	hexapod.velocity = Vector2.ZERO
	Input.action_press("p2_down")
	await _frames(20)
	Input.action_release("p2_down")
