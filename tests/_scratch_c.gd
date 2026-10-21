extends Node

var main: Node
var p1: Player


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _ready() -> void:
	_run.call_deferred()


func _clear() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy:
			enemy.free()
	main.director.enemies.clear()
	Fx.instance._items.clear()


func _chain(n: int, spacing: float) -> void:
	var line: Array = []
	for i in n:
		var e: Enemy = main.director.spawn("walker", Vector2(300.0 + (i % 100) * spacing, 1200.0 - (i / 100) * 40.0))
		e.set_physics_process(false)
		e.hp = 5.0
		e.max_hp = 5.0
		e.statuses.apply("frozen", 5.0, p1)
		line.append(e)
	var t0 := Time.get_ticks_usec()
	line[0].take_damage(1000.0, p1, Vector2.ZERO, "", true)
	var dt := Time.get_ticks_usec() - t0
	var dead := 0
	for e in line:
		if is_instance_valid(e) and e._dead:
			dead += 1
	print("Zersplitter-Dichte n=", n, " Abstand ", spacing, ": ", dt, " us, tot ", dead)


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
	for n in [200, 400]:
		_clear()
		await _frames(2)
		_chain(n, 30.0)
		await _frames(2)
	print("Fertig")
	get_tree().quit()
