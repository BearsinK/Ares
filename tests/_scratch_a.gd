extends Node

var main: Node
var p1: Player
var p2: Player
var dummy_died := 0


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _ready() -> void:
	_run.call_deferred()


func _dummy(pos: Vector2, hp := 5000.0, kind := "brute") -> Enemy:
	var e: Enemy = main.director.spawn(kind, pos)
	e.set_physics_process(false)
	e.hp = hp
	e.max_hp = hp
	e._cooldown = 99.0
	return e


func _clear() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy:
			enemy.free()


func _run() -> void:
	Engine.set_meta("classes", ["roomba", "hexapod"])
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
	_clear()

	# 1. Stunlock durch Stromschlag
	var champ: Enemy = main.director.spawn("brute", Vector2(800.0, 1200.0), false, "", true)
	champ.hp = 1.0e6
	champ.max_hp = 1.0e6
	champ._cooldown = 99.0
	print("champion=", champ.champion, " elite=", champ.elite)
	await _frames(2)
	var stunned_frames := 0
	var total := 0
	champ.take_damage(1.0, p1, Vector2.ZERO, "water")
	for i in 120:
		# 6 Treffer/s Blitz, alle 20 Frames (0,33 s) Wasser nachlegen
		if i % 10 == 0:
			champ.take_damage(1.0, p2, Vector2.ZERO, "lightning")
		if i % 40 == 0:
			champ.take_damage(1.0, p1, Vector2.ZERO, "water")
		await get_tree().physics_frame
		total += 1
		if champ.stunned_time > 0.0:
			stunned_frames += 1
	print("STUNLOCK champion: ", stunned_frames, " von ", total, " Frames betaeubt (2 s Spiel)")
	_clear()

	# 2. TestDummy doppelter Tod
	var d := TestDummy.new()
	d.position = Vector2(1000.0, 1200.0)
	d.died.connect(func(_p: Vector2) -> void: dummy_died += 1)
	main.add_child(d)
	await _frames(2)
	d.health = 10.0
	d.take_damage(1.0, p1, Vector2.ZERO, "fire")
	d.take_damage(5.0, p1, Vector2.ZERO, "lightning")
	print("DUMMY died-Signale: ", dummy_died, " (erwartet 1), respawns=", main._respawns.size())

	# 3. Funkenschlag auf toten, noch nicht freigegebenen Gegner
	var a := _dummy(Vector2(800.0, 1200.0))
	var b := _dummy(Vector2(900.0, 1200.0))
	await _frames(2)
	b.take_damage(1.0e9, p1, Vector2.ZERO, "", true)
	print("b dead=", b._dead, " valid=", is_instance_valid(b), " in group=", b.is_in_group("enemies"))
	var hits := 0
	for i in 200:
		var before := a.hp
		a.take_damage(10.0, p1, Vector2.ZERO, "lightning")
		a.statuses.update(1.0)
		# wieviele Sprunge gingen an b? (sichtbar nur ueber Zigzag in Fx)
	var zig := 0
	for item in Fx.instance._items:
		if item.type == "zigzag" and item.points[item.points.size() - 1].distance_to(b.global_position) < 1.0:
			zig += 1
	print("zigzag-items (Funkenschlag auf toten b?): ", zig)
	_clear()
	print("Fertig")
	get_tree().quit()
