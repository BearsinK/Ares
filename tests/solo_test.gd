extends Node
## Test des Solo-Modus: ein Spieler, kein Partner, Menues mit einer Wahl, weniger Gegner.
## Ausfuehren: godot --headless --path . res://tests/solo_test.tscn

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
	Engine.set_meta("classes", ["printer"])
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	main.stage_id = "classic"
	add_child(main)
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	_check(main.players.size() == 1, "Solo hat einen Spieler (%d)" % main.players.size())
	var p1: Player = main.players[0]
	_check(p1.partner == null and p1.class_id == "printer", "Kein Partner, gewaehlte Klasse")
	_check(is_equal_approx(p1.max_health(), float(p1.stats.max_hp) + main.SOLO_BONUS_HP), "Solo bekommt mehr Leben (%d)" % int(p1.max_health()))
	_check(main.director.solo and main.director.current_cap() < 20, "Der Director plant weniger Gegner (Limit %d)" % main.director.current_cap())
	_check(main.camera.targets.size() == 1, "Die Kamera folgt einem Spieler")
	await _frames(60)
	_check(main.camera.global_position.distance_to(p1.global_position) < 200.0, "Die Kamera haelt den Spieler im Bild")

	# HUD und Ergebnisbildschirm zeichnen ohne Fehler
	main.hud._canvas.queue_redraw()
	await _frames(3)
	main.pause_menu.open_result(false)
	await _frames(3)
	main.pause_menu.close()

	# Level-Up: eine Wahl genuegt
	var picked := []
	var on_chosen := func(id: String) -> void: picked.append(id)
	main.levelup_menu.chosen.connect(on_chosen)
	var ids: Array[String] = ["overclock", "oilchange", "grease"]
	main.levelup_menu.open(main.players, ids, 2)
	await _frames(45)
	Input.action_press("p1_right")
	await _frames(2)
	Input.action_release("p1_right")
	await _frames(2)
	Input.action_press("p1_confirm")
	await _frames(3)
	Input.action_release("p1_confirm")
	await _frames(5)
	_check(picked.size() == 1 and not main.levelup_menu.is_open, "Allein genuegt eine Bestaetigung im Level-Up (%s)" % str(picked))
	main.levelup_menu.chosen.disconnect(on_chosen)

	# Shop: nur ein Spieler, Fertig beendet ihn
	main.shop_menu.open(main.players, 1)
	await _frames(5)
	_check(main.shop_menu._offers[0].size() > 0 and main.shop_menu._offers[1].is_empty(), "Der Shop hat nur ein Angebot")
	await _frames(45)
	main.shop_menu._ready_flags[0] = true
	await _frames(5)
	_check(not main.shop_menu.is_open, "Allein beendet FERTIG den Shop")

	# Allein am Boden ist sofort Game Over
	p1.iframes = 0.0
	p1.take_hit(9999.0, p1.global_position + Vector2(40.0, 0.0))
	_check(p1.downed and main.game_over, "Allein am Boden ist Game Over")
	main.pause_menu.open_result(false)
	await _frames(5)

	print("Fertig, Fehler: ", failures)
	get_tree().quit(failures)
