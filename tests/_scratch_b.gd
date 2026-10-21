extends Node

var main: Node
var p1: Player


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _ready() -> void:
	_run.call_deferred()


func _spawn(n: int) -> Array:
	var list: Array = []
	var kinds := ["walker", "shooter", "flyer", "charger", "mortar", "brute", "walker", "walker"]
	for i in n:
		var e: Enemy = main.director.spawn(kinds[i % kinds.size()], Vector2(1100.0 + (i % 20) * 40.0, 1225.0 - (i / 20) * 60.0))
		e.on_screen = true
		e._cooldown = 99.0
		e.hp = 1.0e7
		e.max_hp = 1.0e7
		list.append(e)
	return list


func _clear() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy:
			enemy.free()
	main.director.enemies.clear()


func _measure(label: String, enemies: Array, mode: String, hits_per_frame: int) -> void:
	var phys: Array[float] = []
	var proc: Array[float] = []
	var hit_us: Array[float] = []
	var fx_us: Array[float] = []
	var items_max := 0
	for f in 300:
		var t0 := Time.get_ticks_usec()
		for k in hits_per_frame:
			var e: Enemy = enemies[randi() % enemies.size()]
			match mode:
				"fire": e.take_damage(3.0, p1, Vector2.ZERO, "fire")
				"lightning": e.take_damage(3.0, p1, Vector2.ZERO, "lightning")
				"fire+lightning": e.take_damage(3.0, p1, Vector2.ZERO, "fire" if randf() < 0.5 else "lightning")
				"water+lightning": e.take_damage(3.0, p1, Vector2.ZERO, "water" if randf() < 0.5 else "lightning")
				"water+ice": e.take_damage(3.0, p1, Vector2.ZERO, "water" if randf() < 0.5 else "ice")
				"all": e.take_damage(3.0, p1, Vector2.ZERO, ["fire", "water", "ice", "lightning"][randi() % 4])
				"none": pass
		hit_us.append(float(Time.get_ticks_usec() - t0))
		var t1 := Time.get_ticks_usec()
		await get_tree().physics_frame
		phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
		proc.append(Performance.get_monitor(Performance.TIME_PROCESS))
		items_max = maxi(items_max, Fx.instance._items.size())
	phys.sort()
	proc.sort()
	hit_us.sort()
	print("%-18s hits/frame=%3d  hit-cost median %.0f us p99 %.0f us max %.0f us | physics med %.2f ms p90 %.2f | process med %.2f ms p90 %.2f | Fx items max %d" % [label, hits_per_frame, hit_us[150], hit_us[297], hit_us[299], phys[150] * 1000.0, phys[270] * 1000.0, proc[150] * 1000.0, proc[270] * 1000.0, items_max])


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
		p.global_position = Vector2(1500.0, 1215.0)
	var enemies := _spawn(60)
	await _frames(30)
	await _measure("baseline", enemies, "none", 0)
	for mode in ["fire", "lightning", "fire+lightning", "water+lightning", "water+ice", "all"]:
		for e in enemies:
			e.statuses._status.clear()
		await _measure(mode, enemies, mode, 4)
	for mode in ["fire+lightning", "all"]:
		await _measure(mode, enemies, mode, 20)
	print("Fertig")
	get_tree().quit()
