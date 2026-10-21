extends Node
## Test der Neigung auf schraegem Boden: Roboter stellen sich parallel zur Flaeche, in der Luft und auf ebenem Boden stehen sie gerade.
## Ausfuehren: godot --headless --path . res://tests/slope_test.tscn

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


func _ready() -> void:
	_run.call_deferred()


func _ramp(points: PackedVector2Array) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1 << 0
	var shape := CollisionPolygon2D.new()
	shape.polygon = points
	body.add_child(shape)
	main.add_child(body)
	return body


func _run() -> void:
	Engine.set_meta("classes", ["roomba", "vending"])
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	main.stage_id = "classic"
	add_child(main)
	await _frames(15)
	p1 = main.players[0]
	p2 = main.players[1]
	p1.invulnerable = true
	p2.invulnerable = true
	# Rampe: steigt nach rechts, 300 hoch auf 600 Breite (etwa 26,6 Grad).
	_ramp(PackedVector2Array([Vector2(1500.0, 1260.0), Vector2(2100.0, 1260.0), Vector2(2100.0, 960.0)]))
	await _frames(3)
	p1.global_position = Vector2(500.0, 1200.0)
	p2.global_position = Vector2(300.0, 1200.0)
	await _frames(60)
	_check(absf(p1._slope_tilt) < 0.01 and p1._slope_shift == Vector2.ZERO, "Auf ebenem Boden steht der Roboter gerade (%.3f)" % p1._slope_tilt)
	# Auf die Rampe stellen.
	p1.global_position = Vector2(1800.0, 1050.0)
	p2.global_position = Vector2(1650.0, 1100.0)
	await _frames(90)
	var expected := atan2(-300.0, 600.0) * -1.0
	_check(p1.is_on_floor(), "Spieler 1 steht auf der Rampe")
	_check(absf(p1._slope_tilt - (-expected)) < 0.08 or absf(absf(p1._slope_tilt) - absf(expected)) < 0.08, "Roboter neigt sich parallel zur Rampe (%.2f rad, Rampe %.2f)" % [p1._slope_tilt, expected])
	_check(p1._slope_tilt < 0.0, "Steigt die Rampe nach rechts, kippt der Roboter nach links (rueckwaerts im Uhrzeigersinn)")
	_check(p1._slope_shift.length() > 3.0, "Die Zeichnung sitzt mit den Fuessen auf der Flaeche (Verschiebung %.1f)" % p1._slope_shift.length())
	_check(p2.is_on_floor() and absf(p2._slope_tilt) > 0.3, "Auch der Vendor neigt sich (%.2f)" % p2._slope_tilt)
	var state := p1._art_state()
	_check(is_equal_approx(float(state.slope), p1._slope_tilt), "Die Zeichenfunktion bekommt die Neigung")
	var muzzle_flat := Vector2(p1.stats.muzzle.x * p1.facing, p1.stats.muzzle.y)
	_check(p1._muzzle_offset().distance_to(muzzle_flat) > 1.0, "Die Muendung folgt der Neigung")
	# In der Luft: zurueck auf gerade.
	p1.velocity = Vector2(0.0, -900.0)
	await _frames(14)
	_check(not p1.is_on_floor() and absf(p1._slope_tilt) < 0.45, "In der Luft richtet er sich wieder auf (%.2f)" % p1._slope_tilt)
	await _frames(60)
	# Ausgeschaltet bleibt die Zeichnung flach.
	p2.invulnerable = false
	p2.iframes = 0.0
	p2.take_hit(9999.0, p2.global_position + Vector2(10.0, 0.0))
	await _frames(40)
	_check(absf(p2._slope_tilt) < 0.05, "Ausgeschaltet gilt keine Neigung mehr (%.2f)" % p2._slope_tilt)
	print("Fertig, Fehler: ", failures)
	main.queue_free()
	get_tree().quit(1 if failures > 0 else 0)
