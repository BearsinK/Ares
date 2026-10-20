extends Node
## Test des Waechters (Mini-Boss in Welle 3, 6, 9): Erscheinen, Zaehigkeit, Belohnung, Wellenende.
## Ausfuehren: godot --headless --path . res://tests/guardian_test.tscn

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
		# Ein Level-Up durch die Beute wuerde das ganze Spiel anhalten.
		if main != null and main.levelup_menu.is_open:
			main.levelup_menu._finish(main.levelup_menu.perk_ids[0])


func _tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func _ready() -> void:
	_run.call_deferred()


func _bounty() -> Chest:
	for chest in main.chests.get_children():
		if chest is Chest and chest.bounty and not chest.is_open and not chest.is_queued_for_deletion():
			return chest
	return null


func _until(condition: Callable, max_frames := 200) -> void:
	var waited := 0
	while not condition.call() and waited < max_frames:
		await _frames(1)
		waited += 1


func _start_guardian_wave(number: int) -> void:
	Engine.time_scale = 1.0
	main.phase = main.Phase.WAVE
	main.overtime = 0.0
	main.wave = number
	main.director.start_wave(number)
	main.director.enabled = false
	main._guardian_spawned = false
	main.guardian = null
	main.wave_time_left = main.wave_duration * 0.5
	await _frames(4)


func _run() -> void:
	Engine.set_meta("classes", ["roomba", "hexapod"])
	main = load("res://scenes/main.tscn").instantiate()
	main.intro_enabled = false
	main.stage_id = "basin"
	add_child(main)
	await _frames(20)
	p1 = main.players[0]
	p2 = main.players[1]
	main.director.enabled = false

	# Welche Wellen haben einen Waechter?
	var expected := {1: false, 2: false, 3: true, 4: false, 5: false, 6: true, 8: false, 9: true, 10: false}
	var all_ok := true
	for number in expected:
		main.wave = number
		all_ok = all_ok and main.is_guardian_wave() == expected[number]
	_check(all_ok, "Waechter nur in Welle 3, 6 und 9")
	main.wave = 1
	await _start_guardian_wave(3)
	_check(main.guardian != null and is_instance_valid(main.guardian), "In Welle 3 erscheint nach einer Weile der Waechter")
	var guardian: Enemy = main.guardian
	_check(guardian.champion and guardian.elite and guardian.body_scale > 1.5, "Er ist eine grosse Elite")
	var plain: Enemy = main.director.spawn("brute", Vector2(2000.0, 1500.0), true)
	_check(guardian.max_hp > plain.max_hp * 1.2, "Er ist zaeher als eine normale Elite (%d gegen %d)" % [guardian.max_hp, plain.max_hp])
	plain.queue_free()
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.champion:
			count += 1
	await _frames(30)
	_check(main.guardian_banner_time > 0.0, "Ein Banner kuendigt ihn an")
	_check(main.guardian == guardian and count == 1, "Es gibt nur einen Waechter pro Welle")

	# Sieg: Gratiskiste, Heilung, Beute.
	p1.hp = p1.max_health() * 0.4
	guardian.take_damage(1.0e9, p1, Vector2.ZERO)
	await _frames(5)
	var chest := _bounty()
	_check(main.guardian == null and chest != null, "Nach dem Sieg liegt eine Waechterkiste da")
	_check(chest != null and chest.bounty and chest.large and chest.price == 0, "Sie ist gratis und gross")
	_check(p1.hp > p1.max_health() * 0.7, "Beide Roboter werden repariert (%.0f)" % p1.hp)
	var coins := 0
	for pickup in main.pickups.get_children():
		if pickup is Pickup and pickup.kind == "gold":
			coins += 1
	_check(coins >= 8, "Beute fliegt aus dem Waechter (%d Muenzen)" % coins)
	p1.gold = 0
	p1.global_position = chest.global_position + Vector2(0.0, -30.0)
	p2.global_position = chest.global_position + Vector2(-1500.0, -30.0)
	await _frames(3)
	await _tap("p1_interact")
	var rare := false
	for id in p1.items:
		rare = rare or Perks.RARE_IDS.has(id)
	_check(chest.is_open and p1.gold == 0 and rare, "Die Kiste ist gratis und enthaelt ein Verhaltens-Item (%s)" % str(p1.items))

	# Verlaengerung: Ist die Zeit um und der Waechter lebt, geht der Kampf weiter, ohne neue Gegner.
	await _start_guardian_wave(3)
	main.director.enabled = true
	main.wave_time_left = 0.05
	await _frames(20)
	_check(main.phase == main.Phase.WAVE and main.overtime > 0.0, "Zeit um, Waechter lebt: Verlaengerung (%.1f s)" % main.overtime)
	_check(not main.director.enabled and is_equal_approx(main.wave_time_left, 0.0), "In der Verlaengerung kommen keine neuen Gegner")
	var late: Enemy = main.guardian
	late.take_damage(1.0e9, p1, Vector2.ZERO)
	await _until(func() -> bool: return _bounty() != null)
	_check(_bounty() != null, "Wird er in der Verlaengerung besiegt, gibt es die Belohnung")
	await _until(func() -> bool: return main.phase == main.Phase.CLEARING)
	_check(main.phase == main.Phase.CLEARING, "Danach endet die Welle (Phase %d, Zeit %.2f, Waechter %s, Overtime %.1f)" % [main.phase, main.wave_time_left, str(main.guardian), main.overtime])
	for leftover in main.chests.get_children():
		if leftover is Chest and leftover.bounty and not leftover.is_open:
			leftover.force_open(p1)

	# Zu lange: der Waechter entkommt, die Welle endet.
	await _start_guardian_wave(3)
	main.overtime = main.OVERTIME_MAX
	main.wave_time_left = 0.01
	await _until(func() -> bool: return main.phase == main.Phase.CLEARING)
	_check(main.phase == main.Phase.CLEARING and main.guardian == null, "Nach der Hoechstzeit endet die Welle trotzdem")

	# Waechter ueberlebt das Wellenende: keine Belohnung.
	await _start_guardian_wave(6)
	_check(main.guardian != null, "In Welle 6 erscheint ein neuer Waechter")
	var opened_before: int = main.chests.get_child_count()
	main._end_wave()
	await _frames(5)
	_check(main.guardian == null and _bounty() == null, "Entkommt der Waechter, gibt es keine Beute")

	# Waechterbeute liegen gelassen: wird am Wellenende automatisch vergeben.
	await _start_guardian_wave(9)
	var g3: Enemy = main.guardian
	p2.hp = p2.max_health()
	g3.take_damage(1.0e9, p2, Vector2.ZERO)
	await _frames(5)
	var left := _bounty()
	_check(left != null and not left.is_open, "Die Beute liegt noch da")
	p1.global_position = left.global_position + Vector2(-1200.0, 0.0)
	p2.global_position = left.global_position + Vector2(900.0, 0.0)
	var items_before := 0
	for player in main.players:
		for id in player.items:
			items_before += int(player.items[id])
	main._end_wave()
	await _frames(5)
	var items_after := 0
	for player in main.players:
		for id in player.items:
			items_after += int(player.items[id])
	_check(left.is_open and items_after == items_before + 1, "Am Wellenende bekommt der naechste Spieler die Beute")

	# Flache Halle: nie ein Waechter.
	main.stage_layout = {}
	main.wave = 3
	_check(not main.is_guardian_wave(), "Ohne grosse Karte kein Waechter")

	print("Fertig, Fehler: ", failures)
	main.queue_free()
	get_tree().quit(1 if failures > 0 else 0)
