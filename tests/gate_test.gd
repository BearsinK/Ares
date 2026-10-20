extends Node
## Test der Metalltore zwischen geschaffter Welle und Shop.
## Ausfuehren: godot --headless --path . res://tests/gate_test.tscn

var failures := 0


func _check(condition: bool, message: String) -> void:
	if condition:
		print("OK    ", message)
	else:
		print("FEHLER ", message)
		failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## Wartet, bis die Bedingung gilt (Spielzeit haengt unter Last an der Echtzeit).
func _until(condition: Callable, timeout := 20.0) -> void:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.set_meta("classes", ["roomba", "hexapod"])
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.stage_id = "classic"
	add_child(main)
	await _wait(0.5)
	var gates: GateOverlay = main.gates
	_check(gates != null and not gates.visible and not gates.is_closed, "Tore sind zu Beginn offen und unsichtbar")

	main.wave_intro = 0.0
	main._end_wave()
	_check(main.phase == main.Phase.CLEARING and not main.shop_menu.is_open, "Welle geschafft: noch kein Shop")
	await _until(func() -> bool: return gates.visible)
	_check(gates.visible and not gates.is_closed and not main.shop_menu.is_open, "Tore fahren zu, Shop noch zu")
	await _until(func() -> bool: return gates.is_closed)
	_check(gates.is_closed and gates.amount >= 1.0, "Tore sind zu")
	_check(main.shop_menu.is_open and main.phase == main.Phase.SHOP, "Shop oeffnet sich hinter den Toren")

	var wave_before: int = main.wave
	main.shop_menu._finish()
	_check(not gates.is_closed and gates.visible, "Beim Weitergehen oeffnen sich die Tore")
	_check(main.wave == wave_before + 1 and main.phase == main.Phase.WAVE, "Naechste Welle laeuft")
	await _until(func() -> bool: return not gates.visible)
	_check(not gates.visible and gates.amount <= 0.0, "Tore sind danach weg")

	# Game Over waehrend die Tore zu sind: Tore werden sofort weggeraeumt.
	gates.close()
	await _until(func() -> bool: return gates.is_closed)
	_check(gates.is_closed, "Tore lassen sich erneut schliessen")
	for player in main.players:
		player.iframes = 0.0
		player.take_hit(9999.0, player.global_position + Vector2(20.0, 0.0))
	_check(main.game_over and not gates.visible, "Game Over raeumt die Tore weg")

	main.queue_free()
	print("Fertig, Fehler: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
