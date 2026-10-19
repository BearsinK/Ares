extends Node
## Test der Elemente, Status und Kombos inklusive Coop-Bonus.
## Ausfuehren: godot --headless --path . res://tests/element_test.tscn

var main: Node
var failures := 0
var p1: Player
var p2: Player


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
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


func _dummy(x: float) -> TestDummy:
	var dummy := TestDummy.new()
	dummy.position = Vector2(x, 1210.0)
	dummy.max_health = 100000.0
	dummy.health = 100000.0
	main.add_child(dummy)
	return dummy


func _run() -> void:
	await _frames(30)
	p1 = main.players[0]
	p2 = main.players[1]
	p1.global_position = Vector2(100.0, 1210.0)
	p2.global_position = Vector2(200.0, 1210.0)

	# Wasser macht nass
	var a := _dummy(1000.0)
	a.take_damage(1.0, p1, Vector2.ZERO, "water")
	_check(a.statuses.has("wet"), "Wasser macht nass")

	# Wasser + Blitz, allein: x1,5
	var hp := a.health
	a.take_damage(20.0, p1, Vector2.ZERO, "lightning")
	_check(is_equal_approx(hp - a.health, 30.0), "Solo: Blitz auf nass macht x1,5 (%.1f)" % (hp - a.health))
	a.queue_free()
	await _frames(2)

	# Wasser + Blitz, Coop: x2,5
	var b := _dummy(1000.0)
	b.take_damage(1.0, p1, Vector2.ZERO, "water")
	hp = b.health
	b.take_damage(20.0, p2, Vector2.ZERO, "lightning")
	_check(is_equal_approx(hp - b.health, 50.0), "Coop: Blitz von P2 auf P1s Nass macht x2,5 (%.1f)" % (hp - b.health))
	b.queue_free()
	await _frames(2)

	# Blitz ohne Nass: normaler Schaden
	var c := _dummy(1000.0)
	hp = c.health
	c.take_damage(20.0, p2, Vector2.ZERO, "lightning")
	_check(is_equal_approx(hp - c.health, 20.0), "Blitz auf trockenes Ziel macht normalen Schaden")
	c.queue_free()
	await _frames(2)

	# Kettenblitz springt auf nasse Nachbarn (Coop: bis zu 3)
	var d1 := _dummy(1000.0)
	var d2 := _dummy(1100.0)
	var d3 := _dummy(1200.0)
	var d4 := _dummy(1700.0)
	for d in [d1, d2, d3, d4]:
		d.take_damage(1.0, p1, Vector2.ZERO, "water")
	var hp2 := d2.health
	var hp3 := d3.health
	var hp4 := d4.health
	d1.take_damage(20.0, p2, Vector2.ZERO, "lightning")
	_check(hp2 - d2.health >= 29.0 and hp3 - d3.health >= 29.0, "Blitz kettet auf nasse Nachbarn (%.0f, %.0f)" % [hp2 - d2.health, hp3 - d3.health])
	_check(is_equal_approx(hp4, d4.health), "Zu weit entfernte nasse Ziele bleiben unberuehrt")
	for d in [d1, d2, d3, d4]:
		d.queue_free()
	await _frames(2)

	# Wasser + Eis: gefroren (Coop laenger)
	var e := _dummy(1000.0)
	e.take_damage(1.0, p1, Vector2.ZERO, "water")
	e.take_damage(1.0, p2, Vector2.ZERO, "ice")
	_check(e.statuses.is_frozen() and not e.statuses.has("wet"), "Wasser + Eis friert ein und verbraucht Nass")
	_check(e.statuses._status.frozen.t > 1.5, "Coop-Frost haelt laenger (%.1f s)" % e.statuses._status.frozen.t)
	var f := _dummy(1000.0)
	f.take_damage(1.0, p1, Vector2.ZERO, "water")
	f.take_damage(1.0, p1, Vector2.ZERO, "ice")
	_check(f.statuses._status.frozen.t < 1.5, "Solo-Frost ist kuerzer (%.1f s)" % f.statuses._status.frozen.t)
	e.queue_free()
	f.queue_free()
	await _frames(2)

	# Wasser + Feuer: Dampfexplosion trifft Nachbarn
	var g := _dummy(1000.0)
	var near := _dummy(1060.0)
	var far := _dummy(1500.0)
	g.take_damage(1.0, p1, Vector2.ZERO, "water")
	var near_hp := near.health
	var far_hp := far.health
	g.take_damage(1.0, p2, Vector2.ZERO, "fire")
	_check(near_hp - near.health >= 60.0, "Coop-Dampf trifft Nachbarn (%.0f)" % (near_hp - near.health))
	_check(is_equal_approx(far_hp, far.health), "Dampf trifft Entfernte nicht")
	_check(not g.statuses.has("wet") and not g.statuses.has("burning"), "Dampf verbraucht Nass und setzt kein Brennen")
	g.queue_free()
	near.queue_free()
	far.queue_free()
	await _frames(2)

	# Feuer + Eis: schmilzt
	var h := _dummy(1000.0)
	h.take_damage(1.0, p1, Vector2.ZERO, "ice")
	_check(h.statuses.has("chilled") and h.statuses.speed_factor() < 1.0, "Eis verlangsamt")
	h.take_damage(1.0, p1, Vector2.ZERO, "fire")
	_check(not h.statuses.has("chilled") and not h.statuses.has("burning"), "Feuer auf Eis schmilzt beides")
	h.queue_free()
	await _frames(2)

	# Brennen macht Schaden ueber Zeit und endet
	var i := _dummy(1000.0)
	i.take_damage(1.0, p1, Vector2.ZERO, "fire")
	hp = i.health
	await _frames(80)
	_check(i.statuses.has("burning") and hp - i.health >= 4.0, "Brennen verursacht Schaden ueber Zeit (%.0f)" % (hp - i.health))
	await _frames(120)
	_check(not i.statuses.has("burning"), "Brennen endet nach kurzer Zeit")
	i.queue_free()

	# Nass laeuft ab
	var j := _dummy(1000.0)
	j.take_damage(1.0, p1, Vector2.ZERO, "water")
	await _frames(60 * 3 + 20)
	_check(not j.statuses.has("wet"), "Nass haelt nur kurz")
	j.queue_free()

	# Eingefrorener Gegner greift nicht an
	p1.global_position = Vector2(1000.0, 1210.0)
	p1.hp = p1.max_health()
	var walker: Enemy = main.director.spawn("walker", Vector2(1030.0, 1230.0))
	walker.take_damage(1.0, p1, Vector2.ZERO, "water")
	walker.take_damage(1.0, p2, Vector2.ZERO, "ice")
	await _frames(100)
	_check(walker.statuses.is_frozen() and is_equal_approx(p1.hp, p1.max_health()), "Eingefrorener Gegner greift nicht an")
	walker.queue_free()
	await _frames(2)

	# Ende zu Ende: P1 macht per Waffe nass, P2 schockt mit dem Sniper
	var target := _dummy(1400.0)
	p1.global_position = Vector2(1100.0, 1210.0)
	p1.velocity = Vector2.ZERO
	p1.weapon_index = 0
	p1.facing = 1.0
	p2.global_position = Vector2(900.0, 1210.0)
	p2.velocity = Vector2.ZERO
	p2.weapon_index = 0
	await _frames(20)
	Input.action_press("p1_fire")
	await _frames(30)
	Input.action_release("p1_fire")
	_check(target.statuses.has("wet"), "Waffe mit Wassermodul macht Ziele nass")
	hp = target.health
	Input.action_press("p2_fire")
	await _frames(4)
	Input.action_release("p2_fire")
	await _frames(5)
	_check(hp - target.health >= 200.0, "Sniper mit Blitzmodul trifft Nass hart (%.0f)" % (hp - target.health))

	print("Fertig, Fehler: ", failures)
	get_tree().quit(failures)
