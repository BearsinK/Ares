extends Node

var main: Node
var p1: Player


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _ready() -> void:
	_run.call_deferred()


func _spawn(n: int, hp: float) -> Array:
	var list: Array = []
	var kinds := ["walker", "shooter", "charger", "mortar", "brute", "walker", "walker"]
	for i in n:
		var e: Enemy = main.director.spawn(kinds[i % kinds.size()], Vector2(1100.0 + (i % 20) * 40.0, 1225.0 - (i / 20) * 60.0))
		e.on_screen = true
		e._cooldown = 99.0
		e.set_physics_process(false)
		e.hp = hp
		e.max_hp = hp
		list.append(e)
	return list


func _clear() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy:
			enemy.free()
	main.director.enemies.clear()
	Fx.instance._items.clear()


func _run() -> void:
	Engine.set_meta("classes", ["roomba", "hexapod"])
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	main.stage_id = "classic"
	add_child(main)
	await _frames(15)
	p1 = main.players[0]
	p1.invulnerable = true
	main.players[1].invulnerable = true
	for p in main.players:
		p.global_position = Vector2(300.0, 1215.0)

	# Spitze 1: 60 brennende Gegner, ein Blitz-Explosionstreffer auf alle
	var enemies := _spawn(60, 1.0e7)
	for e in enemies:
		e.statuses.apply("burning", 5.0, p1)
	var items0 := Fx.instance._items.size()
	var t0 := Time.get_ticks_usec()
	main._explode(Vector2(1500.0, 1200.0), 2000.0, 5.0, p1, Color.YELLOW, "lightning")
	var dt := Time.get_ticks_usec() - t0
	print("Spitze Ueberlast-Kaskade (60 brennende, Blitz-Explosion): ", dt, " us, neue Fx-Items ", Fx.instance._items.size() - items0)
	var alive_burning := 0
	for e in enemies:
		if e.statuses.has("burning"):
			alive_burning += 1
	print("noch brennend: ", alive_burning)
	_clear()
	await _frames(2)

	# Spitze 2: 60 gefrorene Gegner mit wenig HP in Haufen, einer stirbt -> Kette
	enemies = _spawn(60, 20.0)
	for e in enemies:
		e.statuses.apply("frozen", 5.0, p1)
	t0 = Time.get_ticks_usec()
	enemies[0].take_damage(1000.0, p1, Vector2.ZERO, "", true)
	dt = Time.get_ticks_usec() - t0
	var dead := 0
	for e in enemies:
		if is_instance_valid(e) and e._dead:
			dead += 1
	print("Zersplitter-Kette: ", dt, " us, tot ", dead, " von 60")
	_clear()
	await _frames(2)

	# 3: Kette ueber lange Reihe (Rekursionstiefe)
	var line: Array = []
	for i in 150:
		var e: Enemy = main.director.spawn("walker", Vector2(300.0 + i * 20.0, 1200.0))
		e.set_physics_process(false)
		e.hp = 5.0
		e.max_hp = 5.0
		e.statuses.apply("frozen", 5.0, p1)
		line.append(e)
	t0 = Time.get_ticks_usec()
	line[0].take_damage(1000.0, p1, Vector2.ZERO, "", true)
	dt = Time.get_ticks_usec() - t0
	dead = 0
	for e in line:
		if is_instance_valid(e) and e._dead:
			dead += 1
	print("Zersplitter-Reihe 150: ", dt, " us, tot ", dead, " von 150")
	print("Fertig")
	get_tree().quit()
