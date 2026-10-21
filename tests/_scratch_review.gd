extends Node
## Scratch (wird nach dem Review geloescht).

var main: Node
var p1: Player
var p2: Player


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _ready() -> void:
	_run.call_deferred()


func _dummy(kind: String, pos: Vector2, hp := 5000.0) -> Enemy:
	var e: Enemy = main.director.spawn(kind, pos)
	e.set_physics_process(false)
	e.hp = hp
	e.max_hp = hp
	e._cooldown = 99.0
	return e


func _fire(player: Player, weapon_id: String, direction := Vector2.RIGHT) -> void:
	main._on_player_fired(player, weapon_id, player.global_position + direction * 20.0, direction, 0.0)


func _clear() -> void:
	for child in main.projectiles.get_children():
		child.free()
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
	p1.invulnerable = false
	p2.invulnerable = true
	p1.global_position = Vector2(600.0, 1210.0)
	p2.global_position = Vector2(200.0, 1210.0)
	await _ricochet_wall()
	print("SCRATCH DONE")
	get_tree().quit(0)


func _burst_after_down() -> void:
	print("--- burst after down")
	p1.weapons = ["burst"]
	p1.modules = [""]
	p1.weapon_index = 0
	p1.global_position = Vector2(600.0, 1210.0)
	await _frames(3)
	var count := [0]
	var counter := func(_p: Player, id: String, _o: Vector2, _d: Vector2, _c: float) -> void:
		count[0] += 1
	p1.fired.connect(counter)
	Input.action_press("p1_fire")
	await _frames(2)
	print("shots after press: ", count[0], " burst_left=", p1._burst_left)
	Input.action_release("p1_fire")
	p1.iframes = 0.0
	p1.take_hit(9999.0, Vector2.ZERO)
	print("downed=", p1.downed, " burst_left=", p1._burst_left)
	await _frames(60)
	print("shots while downed: ", count[0])
	var before: int = count[0]
	p1.revive(0.5)
	await _frames(6)
	print("shots after revive without pressing fire: ", count[0] - before, " (ammo ", p1.ammo_of(0), ")")
	p1.fired.disconnect(counter)


func _sentry_stack() -> void:
	print("--- sentry / proj stacking")
	for proj in [0.0, 2.0, 3.0]:
		_clear()
		p2.weapons = ["dispenser"]
		p2.modules = [""]
		p2.weapon_index = 0
		p2.mods.proj = proj
		p2.global_position = Vector2(500.0, 1210.0)
		await _frames(3)
		_fire(p2, "dispenser")
		await _frames(2)
		_fire(p2, "dispenser")
		await _frames(2)
		_fire(p2, "dispenser")
		await _frames(120)
		var e := _dummy("brute", Vector2(900.0, 1200.0), 1.0e7)
		var sentries := 0
		for node in get_tree().get_nodes_in_group("deployables"):
			sentries += 1
		await _frames(60)
		var start := 1.0e7
		var e_hp: float = e.hp
		await _frames(120)
		print("proj=", proj, " sentries=", sentries, " dps(2s window)=", (e_hp - e.hp) / 2.0)
	p2.mods.proj = 0.0
	# Referenz: Dustgun mit gleicher Stapelung
	for proj in [0.0, 3.0]:
		_clear()
		p2.weapons = ["rapid"]
		p2.weapon_index = 0
		p2.mods.proj = proj
		p2.global_position = Vector2(500.0, 1210.0)
		var e := _dummy("brute", Vector2(900.0, 1200.0), 1.0e7)
		await _frames(3)
		var h0: float = e.hp
		for i in 60:
			_fire(p2, "rapid")
			await _frames(4)
		print("rapid proj=", proj, " dmg per shot=", (h0 - e.hp) / 60.0, " (14 shots/s -> dps ", (h0 - e.hp) / 60.0 * 14.0, ")")
	p2.mods.proj = 0.0


func _boss_reach() -> void:
	print("--- boss reach")
	_clear()
	main._start_boss()
	await _frames(10)
	var boss: Boss = main.boss
	boss._delay = 0.0
	boss._transition = 0.0
	boss.open = true
	print("boss pos ", boss.global_position)
	p1.invulnerable = true
	p2.invulnerable = true
	# Spieler so weit rechts wie moeglich.
	p1.global_position = Vector2(2705.0, 1225.0)
	p1.velocity = Vector2.RIGHT * 400.0
	await _frames(30)
	print("p1 pos at wall ", p1.global_position)
	p1.weapons = ["sweeper"]
	p1.modules = [""]
	p1.weapon_index = 0
	var h0 := boss.hp
	for i in 5:
		main._on_player_fired(p1, "sweeper", p1.global_position + Vector2.RIGHT * 10.0, Vector2.RIGHT, 0.0)
	print("sweeper boss damage: ", h0 - boss.hp)
	p1.weapons = ["vacuum"]
	h0 = boss.hp
	main._on_player_fired(p1, "vacuum", p1.global_position + Vector2.RIGHT * 10.0, Vector2.RIGHT, 0.0)
	print("vacuum boss damage: ", h0 - boss.hp)
	p1.weapons = ["zapper"]
	h0 = boss.hp
	main._on_player_fired(p1, "zapper", p1.global_position + Vector2.RIGHT * 10.0, Vector2.RIGHT, 0.0)
	print("zapper boss damage (aim right): ", h0 - boss.hp)
	h0 = boss.hp
	main._on_player_fired(p1, "zapper", p1.global_position + Vector2.RIGHT * 10.0, Vector2(1.0, -0.7).normalized(), 0.0)
	print("zapper boss damage (aim up-right at body): ", h0 - boss.hp)
	p1.weapons = ["rapid"]
	h0 = boss.hp
	main._on_player_fired(p1, "rapid", p1.global_position + Vector2.RIGHT * 10.0, Vector2(1.0, -0.2).normalized(), 0.0)
	await _frames(40)
	print("rapid boss damage: ", h0 - boss.hp)
	# Mine direkt am Boss-Fuss-Abstand
	p1.weapons = ["mine"]
	p1.weapon_index = 0
	main._on_player_fired(p1, "mine", p1.global_position + Vector2.RIGHT * 10.0, Vector2.RIGHT, 0.0)
	await _frames(120)
	var mine: Node = null
	for node in get_tree().get_nodes_in_group("deployables"):
		mine = node
	if mine != null:
		print("mine landed at ", mine.global_position, " dist to boss feet ", mine.global_position.distance_to(boss.global_position))
	else:
		print("mine gone")


func _boss_leftovers() -> void:
	print("--- leftovers into boss arena")
	# Frische Szene fuer sauberen Zustand
	pass


func _boss_reach2() -> void:
	print("--- boss reach 2")
	_clear()
	main._start_boss()
	await _frames(10)
	var boss: Boss = main.boss
	p1.invulnerable = true
	p2.invulnerable = true
	p1.global_position = Vector2(2705.0, 1225.0)
	p1.velocity = Vector2.RIGHT * 400.0
	await _frames(30)
	var o: Vector2 = p1.global_position + Vector2.RIGHT * 10.0
	print("player ", p1.global_position, " origin ", o)
	print("clear_line to feet: ", main._clear_line(o, boss.global_position))
	print("clear_line to feet-20: ", main._clear_line(o, boss.global_position + Vector2(0, -20)))
	print("in_cone vac (reach 360, cone .5): ", main._in_cone(o, Vector2.RIGHT, boss, 360.0, 0.5))
	print("in_cone sweep (reach 175, arc 1.9): ", main._in_cone(o - Vector2.RIGHT * 24.0, Vector2.RIGHT, boss, 175.0, 0.95))
	print("distance origin->boss feet ", o.distance_to(boss.global_position))
	# Platform position: stand on the platform at y=1070 (x 2070-2370) / 890 (2380-2600)
	p1.global_position = Vector2(2560.0, 860.0)
	await _frames(30)
	o = p1.global_position + Vector2.RIGHT * 10.0
	print("on platform player ", p1.global_position)
	var dir: Vector2 = (boss.global_position - o).normalized()
	print("clear_line plat to feet: ", main._clear_line(o, boss.global_position), " dist ", o.distance_to(boss.global_position))
	p1.weapons = ["zapper"]
	p1.modules = [""]
	p1.weapon_index = 0
	var h0: float = boss.hp
	main._on_player_fired(p1, "zapper", o, dir, 0.0)
	print("zapper at feet from platform: ", h0 - boss.hp)
	h0 = boss.hp
	main._on_player_fired(p1, "zapper", o, Vector2(1.0, 0.3).normalized(), 0.0)
	print("zapper aimed at body mid (dir 1,0.3): ", h0 - boss.hp)


func _boss_reach3() -> void:
	print("--- boss reach 3 (sentry, leftovers)")
	_clear()
	# Vor dem Boss: Mine + Sentry + Zone legen
	p2.weapons = ["mine", "dispenser", "toner"]
	p2.modules = ["", "", ""]
	p2.weapon_index = 0
	p2.global_position = Vector2(500.0, 1210.0)
	await _frames(3)
	main._on_player_fired(p2, "mine", p2.global_position + Vector2.RIGHT * 20.0, Vector2.RIGHT, 0.0)
	main._on_player_fired(p2, "dispenser", p2.global_position + Vector2.RIGHT * 20.0, Vector2.RIGHT, 0.0)
	main._on_player_fired(p2, "toner", p2.global_position + Vector2.RIGHT * 20.0, Vector2.RIGHT, 0.0)
	await _frames(40)
	var before := get_tree().get_nodes_in_group("deployables").size()
	var props := []
	for n in main.projectiles.get_children():
		props.append(n.get_class() + ":" + str(n.get_script().get_global_name()) + "@" + str(n.global_position))
	print("before boss: ", props)
	main._start_boss()
	await _frames(5)
	props = []
	for n in main.projectiles.get_children():
		props.append(n.get_class() + ":" + str(n.get_script().get_global_name()) + "@" + str(n.global_position))
	print("after _start_boss: ", props)
	var boss: Boss = main.boss
	p1.invulnerable = true
	p2.invulnerable = true
	boss._delay = 0.0
	# Sentry nahe der Wand platzieren
	p2.weapons = ["dispenser"]
	p2.modules = [""]
	p2.weapon_index = 0
	p2.global_position = Vector2(2640.0, 1225.0)
	p2.velocity = Vector2.ZERO
	await _frames(20)
	for n in get_tree().get_nodes_in_group("deployables"):
		n.queue_free()
	await _frames(2)
	main._on_player_fired(p2, "dispenser", p2.global_position + Vector2.RIGHT * 20.0, Vector2.RIGHT, 0.0)
	await _frames(100)
	var tower: Node = null
	for n in get_tree().get_nodes_in_group("deployables"):
		tower = n
	print("tower at ", tower.global_position if tower else "none")
	if tower:
		print("tower find_target: ", tower._find_target())
	var h0: float = boss.hp
	await _frames(120)
	print("boss damage from sentry over 2s: ", h0 - boss.hp)


func _ricochet_wall() -> void:
	print("--- ricochet in wall")
	_clear()
	p1.weapons = ["rapid"]
	p1.modules = [""]
	p1.weapon_index = 0
	p1.mods.bounce = 1.0
	p1.global_position = Vector2(12.0, 1000.0)
	p1.velocity = Vector2.ZERO
	await _frames(1)
	main._on_player_fired(p1, "rapid", Vector2(-1.0, 1000.0), Vector2.LEFT, 0.0)
	var b: Projectile = null
	for c in main.projectiles.get_children():
		if c is Projectile:
			b = c
	print("spawned at ", b.global_position, " bounces ", b.bounces)
	for i in 6:
		await _frames(1)
		if is_instance_valid(b):
			print("frame ", i, " pos ", b.global_position, " vel ", b._velocity, " bounces ", b.bounces, " queued ", b.is_queued_for_deletion())
		else:
			print("frame ", i, " gone")
	p1.mods.bounce = 0.0
