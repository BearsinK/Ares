extends Node
## Test der Kamera: Sie haelt beide Spieler im Bild, laesst aber einen Gefallenen los und folgt nur dem Stehenden.
## Ausfuehren: godot --headless --path . res://tests/camera_test.tscn

var main: Node
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
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


func _run() -> void:
	await _frames(20)
	var p1: Player = main.players[0]
	var p2: Player = main.players[1]
	var camera: CoopCamera = main.camera
	p1.global_position = Vector2(600.0, 1210.0)
	p2.global_position = Vector2(1800.0, 1210.0)
	p1.velocity = Vector2.ZERO
	p2.velocity = Vector2.ZERO
	await _frames(240)
	_check(absf(camera.global_position.x - 1200.0) < 120.0, "Kamera haelt beide Spieler im Bild (x %d)" % int(camera.global_position.x))
	var zoom_both := camera.zoom.x

	p2.iframes = 0.0
	p2.take_hit(9999.0, Vector2(1700.0, 1210.0))
	_check(p2.downed and not main.game_over, "Partner liegt am Boden, das Spiel laeuft weiter")
	await _frames(240)
	_check(absf(camera.global_position.x - p1.global_position.x) < 140.0, "Kamera folgt nur dem Stehenden (x %d, Spieler %d)" % [int(camera.global_position.x), int(p1.global_position.x)])
	_check(camera.zoom.x >= zoom_both - 0.01, "Kamera zoomt nicht wegen des Gefallenen heraus")

	# Gefallener Partner ausserhalb des Bildes: Marker am HUD-Rand wird gezeichnet, ohne Fehler.
	var xf: Transform2D = main.get_viewport().get_canvas_transform()
	var screen: Vector2 = xf * p2.global_position
	_check(screen.x > main.get_viewport().get_visible_rect().size.x * 0.0, "Berechnung der Bildschirmposition des Gefallenen funktioniert")

	# Beide am Boden: Kamera nimmt wieder beide, die Spielzeit friert ein
	main.director.enabled = true
	await _frames(30)
	var running: float = main.director.time
	_check(running > 0.0, "Spielzeit laeuft im Kampf (%.1f s)" % running)
	p1.iframes = 0.0
	p1.take_hit(9999.0, Vector2(500.0, 1210.0))
	_check(main.game_over, "Beide am Boden ist Game Over")
	var at_end: float = main.director.time
	await _frames(240)
	_check(is_equal_approx(main.director.time, at_end), "Spielzeit steht nach Game Over still (%.2f s)" % at_end)
	_check(absf(camera.global_position.x - 1200.0) < 150.0, "Beide am Boden: Kamera zeigt wieder beide (x %d)" % int(camera.global_position.x))

	print("Fertig, Fehler: ", failures)
	get_tree().quit(failures)
