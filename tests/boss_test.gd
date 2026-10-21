extends Node
## Test des Endbosses: Ablauf, Laufband, Ofen, Hindernisse, Panzer, Phasen, Tod.
## Ausfuehren: godot --headless --path . res://tests/boss_test.tscn

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
	_run.call_deferred()


func _run() -> void:
	Engine.set_meta("classes", ["roomba", "hexapod"])
	main = load("res://scenes/main.tscn").instantiate()
	main.wave_duration = 1.0
	main.max_waves = 1
	main.intro_enabled = false
	main.stage_id = "classic"
	add_child(main)
	await _frames(20)
	var p1: Player = main.players[0]
	var p2: Player = main.players[1]
	p1.iframes = 0.0

	# Ablauf: letzte Welle, Shop, dann der Boss.
	await get_tree().create_timer(1.5, true, false, true).timeout
	await _frames(240)
	_check(main.phase == main.Phase.SHOP, "Nach der letzten Welle kommt der Shop (Phase %d)" % main.phase)
	_check(main.shop_menu.before_boss, "Der Shop kuendigt den Boss an")
	main.shop_menu._finish()
	await _frames(20)
	_check(main.phase == main.Phase.BOSS and main.boss != null, "Danach beginnt der Bosskampf")
	var boss: Boss = main.boss
	var arena: BossArena = main.boss_arena
	_check(arena.base_speed == Boss.BELT_SPEEDS[0], "Laufband laeuft in Phase 1")
	_check(boss.is_invulnerable(), "Boss ist anfangs unverwundbar (Auftritt)")
	var hp0 := boss.hp
	boss.take_damage(500.0, p1)
	_check(boss.hp == hp0, "Waehrend des Auftritts nimmt er keinen Schaden")

	# Laufband zieht nach rechts, zum Boss. Plattformen gibt es nicht mehr.
	p1.iframes = 9999.0
	p2.iframes = 9999.0
	p1.global_position = Vector2(1500.0, 1225.0)
	p1.velocity = Vector2.ZERO
	await _frames(10)
	var x0 := p1.global_position.x
	await _frames(60)
	_check(p1.global_position.x - x0 > 60.0, "Laufband zieht den Spieler zum Boss (%d px)" % (p1.global_position.x - x0))
	var floating := false
	for node in get_tree().get_nodes_in_group("ceilings"):
		if (node.get_meta("rect") as Rect2).position.y > 0.0:
			floating = true
	_check(not floating, "Es gibt keine Plattformen in der Boss-Halle")

	# Hexapod an der unsichtbaren Wand vor dem Boss: kein Klettern.
	p2.iframes = 9999.0
	p2.global_position = Vector2(BossArena.BOSS_WALL_X - 60.0, 1215.0)
	p2.velocity = Vector2.ZERO
	await _frames(10)
	Input.action_press("p2_right")
	Input.action_press("p2_up")
	await _frames(70)
	Input.action_release("p2_right")
	Input.action_release("p2_up")
	_check(not p2.is_clinging() and p2.global_position.y > 1100.0, "Die unsichtbare Wand laesst sich nicht beklettern (y %d)" % p2.global_position.y)
	p2.global_position = Vector2(1000.0, 1225.0)
	p2.velocity = Vector2.ZERO

	# Schredder vor dem Boss: fetter Schaden, kein Instakill, Rueckschleudern.
	p1.iframes = 0.0
	p1.hp = p1.max_health()
	p1.global_position = Vector2(BossArena.BOSS_WALL_X - 50.0, 1215.0)
	p1.velocity = Vector2.ZERO
	await _frames(4)
	var maw_loss := p1.max_health() - p1.hp
	_check(maw_loss >= 25.0 and p1.hp > 0.0, "Der Schredder frisst fett, aber toetet nicht sofort (%d Schaden)" % maw_loss)
	_check(p1.velocity.x < -100.0, "Man wird zurueckgeschleudert (%d)" % p1.velocity.x)
	p1.iframes = 9999.0
	p1.global_position = Vector2(1500.0, 1225.0)

	# Das Band wird mit der Zeit schneller, aber nur begrenzt.
	boss._delay = 0.0
	await _frames(60)
	_check(arena.belt_speed > arena.base_speed, "Das Band zieht von selbst an (%.1f auf %.1f)" % [arena.base_speed, arena.belt_speed])
	arena._creep = BossArena.BELT_CREEP_MAX
	await _frames(5)
	_check(arena.belt_speed <= arena.base_speed + BossArena.BELT_CREEP_MAX + 0.01, "Zuwachs ist begrenzt (%.1f)" % arena.belt_speed)
	arena._creep = 0.0

	# Hindernisse.
	boss._delay = 0.0
	boss._attack = "idle"
	boss._attack_time = 9999.0
	var crate := BeltObstacle.new()
	crate.kind = "crate"
	crate.speed = 0.0
	crate.players = main.players
	crate.position.x = 1800.0
	arena.add_child(crate)
	crate._age = 1.0
	p1.iframes = 0.0
	p1.hp = p1.max_health()
	p1.global_position = Vector2(1700.0, 1225.0)
	p1.velocity = Vector2.ZERO
	await _frames(2)
	crate.position.x = p1.global_position.x
	await _frames(2)
	_check(p1.hp < p1.max_health(), "Kiste auf dem Band verletzt")
	crate.queue_free()
	await _frames(2)
	var fresh := BeltObstacle.new()
	fresh.kind = "crate"
	fresh.speed = 0.0
	fresh.players = main.players
	fresh.position.x = 1700.0
	arena.add_child(fresh)
	p1.iframes = 0.0
	p1.hp = p1.max_health()
	p1.global_position = Vector2(1700.0, 1225.0)
	await _frames(5)
	_check(p1.hp == p1.max_health(), "Frisch eingerollt ist ein Hindernis kurz harmlos")
	fresh.queue_free()
	p1.iframes = 0.0
	var beam := BeltObstacle.new()
	beam.kind = "beam"
	beam.speed = 0.0
	beam.players = main.players
	arena.add_child(beam)
	beam._age = 1.0
	p1.iframes = 0.0
	p1.hp = p1.max_health()
	p1.global_position = Vector2(1900.0, 1225.0)
	p1.velocity = Vector2.ZERO
	beam.position.x = 1900.0
	await _frames(3)
	_check(p1.hp == p1.max_health(), "Unter dem Traeger kann man durchlaufen")
	p1.global_position = Vector2(1900.0, 1100.0)
	p1.velocity = Vector2.ZERO
	await _frames(1)
	_check(p1.hp < p1.max_health(), "Im Bereich des Traegers wird man getroffen")
	beam.queue_free()
	p1.iframes = 9999.0

	# Lasten von der Decke: erst Warnung (harmlos), dann Fall und Einschlag, danach rollt sie als Kiste zum Boss.
	p1.iframes = 0.0
	p1.hp = p1.max_health()
	p1.global_position = Vector2(1500.0, 1225.0)
	p1.velocity = Vector2.ZERO
	arena.base_speed = 0.0
	arena._creep = 0.0
	await _frames(3)
	arena.spawn_drop(1500.0)
	var drop: BeltObstacle = null
	for node in get_tree().get_nodes_in_group("belt_obstacles"):
		if node.kind == "drop":
			drop = node
	_check(drop != null and drop.is_falling(), "Eine Last erscheint ueber dem Band")
	await _frames(30)
	_check(p1.hp == p1.max_health() and drop.global_position.y < 1100.0, "Die Warnung ist harmlos")
	var landed := false
	for i in 200:
		await get_tree().physics_frame
		if not drop.is_falling():
			landed = true
			break
	_check(landed and p1.hp < p1.max_health(), "Der Einschlag trifft hart (%d Schaden)" % (p1.max_health() - p1.hp))
	var drop_x := drop.global_position.x
	await _frames(90)
	_check(drop.global_position.x > drop_x + 20.0, "Die gelandete Last rollt zum Boss")
	drop.queue_free()
	arena.base_speed = Boss.BELT_SPEEDS[0]
	p1.iframes = 9999.0

	# Verstaerkung: der Boss ruft Gegner.
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Enemy:
			node.free()
	boss._begin("adds")
	await _frames(3)
	_check(main.director.alive_count() >= 2, "Der Boss ruft Verstaerkung (%d Gegner)" % main.director.alive_count())
	boss._end_attack()
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Enemy:
			node.free()

	# Machbarkeit: Kiste, Stapel und Saege lassen sich mit Anlauf und Sprung ueberwinden.
	boss._attack = "idle"
	boss._attack_time = 9999.0
	for kind in ["crate", "stack", "saw"]:
		await _dodge(p1, kind)
	p1.iframes = 9999.0

	# Panzer, Kern, Schwaeche.
	await _frames(5)
	boss._attack = ""
	boss._attack_time = 0.0
	hp0 = boss.hp
	boss.take_damage(100.0, p1)
	_check(is_equal_approx(hp0 - boss.hp, 25.0), "Geschlossener Panzer: 25 Prozent Schaden (%.0f)" % (hp0 - boss.hp))
	boss.open = true
	hp0 = boss.hp
	boss.take_damage(100.0, p1)
	_check(is_equal_approx(hp0 - boss.hp, 100.0), "Offener Kern: voller Schaden")
	hp0 = boss.hp
	boss.take_damage(100.0, p1, Vector2.ZERO, "water")
	_check(hp0 - boss.hp >= 149.0, "Wasser trifft die Schwaeche (%.0f)" % (hp0 - boss.hp))
	boss.statuses._status.clear()
	hp0 = boss.hp
	boss.take_damage(100.0, p1, Vector2.ZERO, "fire")
	_check(is_equal_approx(hp0 - boss.hp, 60.0), "Feuer prallt teilweise ab (%.0f)" % (hp0 - boss.hp))

	# Angriffe laufen von selbst.
	boss.open = false
	boss._queue.clear()
	boss._attack = ""
	boss._gap = 0.0
	var saw_obstacle := false
	for i in 600:
		await get_tree().physics_frame
		if get_tree().get_nodes_in_group("belt_obstacles").size() > 0:
			saw_obstacle = true
			break
	_check(saw_obstacle, "Der Boss schickt Hindernisse aufs Band")
	boss._begin("fire")
	await _frames(150)
	var shots: int = main.enemy_projectiles.get_child_count()
	_check(shots > 0, "Der Boss feuert Geschosse (%d)" % shots)
	boss._end_attack()
	boss._begin("vent")
	_check(boss.open, "Vent oeffnet den Kern")
	boss._end_attack()
	_check(not boss.open, "Nach dem Vent ist der Panzer wieder zu")
	boss._begin("rain")
	var strikes := 0
	for node in main.enemy_projectiles.get_children():
		if node is AreaStrike:
			strikes += 1
	_check(strikes >= 4, "Ascheregen erzeugt Warnkreise (%d)" % strikes)
	boss._end_attack()

	# Phasenwechsel.
	boss.open = true
	boss.hp = Boss.MAX_HP * 0.67
	boss.take_damage(Boss.MAX_HP * 0.05, p1)
	_check(boss.phase == 2, "Unter 66 Prozent beginnt Phase 2")
	_check(arena.base_speed == Boss.BELT_SPEEDS[1], "Das Band wird schneller")
	_check(boss.is_invulnerable() and not boss.open, "Beim Phasenwechsel ist er kurz unverwundbar")
	await get_tree().create_timer(Boss.TRANSITION_TIME + 0.3, true, false, true).timeout
	boss.open = true
	boss.hp = Boss.MAX_HP * 0.34
	boss.take_damage(Boss.MAX_HP * 0.05, p1)
	_check(boss.phase == 3 and arena.base_speed == Boss.BELT_SPEEDS[2], "Unter 33 Prozent beginnt Phase 3")
	await get_tree().create_timer(Boss.TRANSITION_TIME + 0.3, true, false, true).timeout

	# Tod und Sieg.
	boss.open = true
	boss.take_damage(Boss.MAX_HP, p1)
	_check(boss.dying and boss.hp == 0.0, "Boss geht zu Boden")
	await _frames(3)
	_check(get_tree().get_nodes_in_group("belt_obstacles").is_empty(), "Hindernisse werden entfernt")
	await get_tree().create_timer(4.0, true, false, true).timeout
	_check(main.phase == main.Phase.VICTORY, "Nach dem Boss ist der Lauf geschafft")
	await get_tree().create_timer(2.0, true, false, true).timeout
	_check(main.pause_menu.is_open() and main.pause_menu.victory, "Ergebnisbildschirm erscheint")
	print("Fertig, Fehler: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


## Spielt einen Hindernis-Durchgang mit gutem Timing durch und prueft, dass kein Schaden entsteht.
func _dodge(player: Player, kind: String) -> void:
	var arena: BossArena = main.boss_arena
	for node in get_tree().get_nodes_in_group("belt_obstacles"):
		node.queue_free()
	await _frames(2)
	player.iframes = 0.0
	player.hp = player.max_health()
	player.global_position = Vector2(1500.0, 1225.0)
	player.velocity = Vector2.ZERO
	await _frames(10)
	var obstacle := BeltObstacle.new()
	obstacle.kind = kind
	obstacle.speed = arena.belt_speed + BossArena.OBSTACLE_BOOST
	obstacle.players = main.players
	obstacle.position.x = player.global_position.x - 700.0
	arena.add_child(obstacle)
	obstacle._age = 1.0
	var hold := 0.0
	var jumped := false
	# Das Hindernis kommt von links aufs Band, man laeuft gegen das Band und springt rechtzeitig.
	Input.action_press("p1_left")
	for i in 240:
		await get_tree().physics_frame
		if not is_instance_valid(obstacle):
			break
		var dx := player.global_position.x - obstacle.global_position.x
		var closing := obstacle.speed + maxf(0.0, -player.velocity.x)
		if not jumped and player.is_on_floor() and dx < closing * 0.42 + 10.0:
			jumped = true
			hold = 0.5
		if hold > 0.0:
			Input.action_press("p1_jump")
			hold -= 1.0 / 60.0
		else:
			Input.action_release("p1_jump")
		if dx < -160.0:
			break
	Input.action_release("p1_left")
	Input.action_release("p1_jump")
	_check(jumped and player.hp == player.max_health(), "%s ist mit Anlauf und Sprung machbar" % kind)
	if is_instance_valid(obstacle):
		obstacle.queue_free()
	await _frames(2)
