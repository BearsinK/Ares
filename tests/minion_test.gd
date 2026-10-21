extends Node
## Test der Diener des Printbots: Auto-Druck, Angriff, Ablenkung, Tod durch Treffer und durch Zeit.
## Ausfuehren: godot --headless --path . res://tests/minion_test.tscn

var main: Node
var p1: Player
var p2: Player
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


func _until(condition: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _clear() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy:
			enemy.free()
	for bullet in main.enemy_projectiles.get_children():
		bullet.free()
	for child in main.projectiles.get_children():
		child.free()
	for minion in Minion.active.duplicate():
		minion.free()


func _ready() -> void:
	Engine.set_meta("classes", ["roomba", "printer"])
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	main.stage_id = "classic"
	add_child(main)
	_run.call_deferred()


func _run() -> void:
	await _frames(20)
	p1 = main.players[0]
	p2 = main.players[1]
	p1.invulnerable = true
	p2.invulnerable = true
	p1.global_position = Vector2(300.0, 1200.0)
	p2.global_position = Vector2(900.0, 1200.0)

	# Start: ein Printling ist sofort da, die Klasse ist Beschwoerer ohne Begleitdrohnen
	_check(bool(p2.stats.get("summoner", false)) and not p2.stats.has("escort_drones"), "Printbot ist Beschwoerer")
	_check(Minion.count_of(p2, "printling") == 1, "Beim Start gibt es einen Printling (%d)" % Minion.count_of(p2, "printling"))
	_check(Minion.count_of(p1, "printling") == 0, "Andere Klassen drucken nichts")

	# Auto-Druck bis zur Hoechstzahl, dann Pause
	var cap := p2.minion_cap("printling")
	for i in 4:
		p2._print_timer = 0.05
		await _frames(6)
	_check(Minion.count_of(p2, "printling") == cap and cap == 3, "Auto-Druck fuellt bis zur Hoechstzahl %d (%d)" % [cap, Minion.count_of(p2, "printling")])
	_check(is_equal_approx(p2.print_progress(), 1.0), "Die Lampen zeigen voll, solange die Hoechstzahl erreicht ist")

	# Printlinge beschiessen Gegner
	var foe: Enemy = main.director.spawn("brute", Vector2(1300.0, 1190.0))
	foe.hp = 5000.0
	foe.max_hp = 5000.0
	var shot := await _until(func() -> bool: return foe.hp < 5000.0, 300)
	_check(shot, "Printlinge beschiessen Gegner (%.0f Schaden)" % (5000.0 - foe.hp))
	_check(p2.damage_dealt > 0.0, "Der Schaden zaehlt dem Besitzer")
	_clear()

	# Gegner lenken sich auf Diener ab, wenn die naeher sind als der Spieler
	await _frames(2)
	var bait: Minion = p2.summon_minion("printling")
	bait.global_position = Vector2(1500.0, 1150.0)
	bait.set_physics_process(false)
	p1.global_position = Vector2(300.0, 1200.0)
	p2.global_position = Vector2(300.0, 1200.0)
	var walker: Enemy = main.director.spawn("walker", Vector2(1650.0, 1190.0))
	await _frames(4)
	_check(walker._target == bait, "Ein naher Diener zieht den Gegner auf sich")

	# Nahkampf trifft den Diener, er stirbt
	await _frames(40)
	bait.global_position = walker.global_position + Vector2(-35.0, -12.0)
	var bait_ref: WeakRef = weakref(bait)
	# Der Diener steht still (ohne Physik), daher laeuft seine Schonzeit hier von Hand ab.
	var killed := await _until(func() -> bool:
		var live: Minion = bait_ref.get_ref()
		if live == null:
			return true
		live._iframes = 0.0
		return live.is_dead(), 700)
	_check(killed, "Gegner toeten den Diener im Nahkampf")
	await _frames(4)
	_check(bait_ref.get_ref() == null and Minion.count_of(p2, "printling") == 0, "Tote Diener verschwinden aus der Liste")
	_clear()

	# Medic und Nest ignorieren Diener, der Ansturm-Gegner (Rammtank) lenkt sich nur auf erreichbare ab
	_clear()
	await _frames(2)
	var near := p2.summon_minion("printling")
	near.global_position = Vector2(1500.0, 1160.0)
	near.set_physics_process(false)
	var medic: Enemy = main.director.spawn("medic", Vector2(1560.0, 1190.0))
	var nest: Enemy = main.director.spawn("nest", Vector2(1620.0, 1190.0))
	var rammer: Enemy = main.director.spawn("charger", Vector2(1680.0, 1190.0))
	await _frames(6)
	_check(medic._target != near and nest._target != near, "Medic und Nest lassen sich nicht ablenken")
	_check(rammer._target == near, "Der Rammtank greift den nahen Diener an")
	_clear()

	# Gegnerschuesse treffen Diener
	var target_minion: Minion = p2.summon_minion("printling")
	target_minion.global_position = Vector2(1500.0, 1150.0)
	target_minion.set_physics_process(false)
	var hp_before := target_minion.hp
	var bullet := EnemyProjectile.new()
	bullet.global_position = target_minion.global_position + Vector2(-40.0, 0.0)
	bullet.direction = Vector2.RIGHT
	bullet.speed = 600.0
	bullet.damage = 12.0
	main.enemy_projectiles.add_child(bullet)
	await _frames(20)
	_check(target_minion.hp < hp_before, "Gegnerschuesse verletzen Diener (%.0f -> %.0f)" % [hp_before, target_minion.hp])
	var short := target_minion.take_hit(5.0, Vector2.ZERO)
	_check(not short, "Kurze Schonzeit nach einem Treffer")
	_clear()

	# Zeit laeuft ab
	var shortlived: Minion = p2.summon_minion("gnat", -1.0, 0.3)
	var short_ref: WeakRef = weakref(shortlived)
	await _frames(40)
	_check(short_ref.get_ref() == null, "Diener verglueht nach Ablauf der Lebensdauer")
	_clear()

	# Beisser bleiben nahe beim Besitzer und treffen Gegner
	await _frames(2)
	p2.global_position = Vector2(900.0, 1200.0)
	var meal: Enemy = main.director.spawn("walker", Vector2(1100.0, 1190.0))
	meal.hp = 5000.0
	meal.max_hp = 5000.0
	for i in 3:
		p2.summon_minion("gnat", 4.0, 7.0, p2.global_position + Vector2(0.0, -40.0))
	var bitten := await _until(func() -> bool: return meal.hp < 5000.0, 240)
	_check(bitten, "Gnats beissen den Gegner (%.0f Schaden)" % (5000.0 - meal.hp))
	_clear()

	# Besitzer weg: Diener verschwinden
	var orphan: Minion = p2.summon_minion("printling")
	var orphan_ref: WeakRef = weakref(orphan)
	orphan.owner_player = null
	await _frames(6)
	_check(orphan_ref.get_ref() == null, "Ohne Besitzer verschwindet der Diener")

	print("Fertig, Fehler: ", failures)
	get_tree().quit(failures)
