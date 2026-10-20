extends Node
## Test der Spielschleife: Elite-Gegner, Reparaturkits, Treffer-Rueckmeldung.
## Ausfuehren: godot --headless --path . res://tests/loop_test.tscn

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


func _count(kind: String) -> int:
	var n := 0
	for pickup in main.pickups.get_children():
		if pickup.kind == kind:
			n += 1
	return n


func _run() -> void:
	Engine.set_meta("classes", ["roomba", "hexapod"])
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	add_child(main)
	await _frames(20)
	var p1: Player = main.players[0]
	var p2: Player = main.players[1]
	p1.global_position = Vector2(500.0, 1225.0)
	p2.global_position = Vector2(2500.0, 1225.0)

	# Elite: groesser, zaeher, mit Beute.
	var normal: Enemy = main.director.spawn("walker", Vector2(1500.0, 1225.0))
	var elite: Enemy = main.director.spawn("walker", Vector2(1600.0, 1225.0), true)
	normal._cooldown = 99.0
	elite._cooldown = 99.0
	_check(elite.elite and not normal.elite, "Elite-Flag wird gesetzt")
	_check(elite.max_hp > normal.max_hp * 3.0, "Elite hat deutlich mehr Leben (%d zu %d)" % [elite.max_hp, normal.max_hp])
	_check(elite.radius() > normal.radius() * 1.2, "Elite ist groesser")
	main.director.time = 100.0
	_check(main.director.elite_chance() >= 0.04 and main.director.elite_chance() <= 0.15, "Elite-Anteil bleibt im Rahmen")
	var xp_normal: int = normal.data.xp
	var before_gold := _count("gold")
	elite.take_damage(1.0e9, p1, Vector2.ZERO, "", true)
	await _frames(3)
	_check(_count("hp") >= 1, "Elite laesst ein Reparaturkit fallen")
	_check(_count("gold") - before_gold >= 3, "Elite laesst viel Gold fallen")
	var xp_values := 0
	for pickup in main.pickups.get_children():
		if pickup.kind == "xp":
			xp_values += pickup.value
	_check(xp_values >= xp_normal * 3, "Elite gibt dreifache Erfahrung (%d)" % xp_values)

	# Reparaturkit geht an den Spieler, der es braucht.
	for pickup in main.pickups.get_children():
		pickup.queue_free()
	await _frames(3)
	p1.hp = p1.max_health()
	p2.hp = p2.max_health() * 0.4
	p2.global_position = Vector2(1500.0, 1225.0)
	var kit := Pickup.new()
	kit.kind = "hp"
	kit.value = 1
	kit.players = main.players
	kit.floor_y = 1250.0
	kit.position = Vector2(1500.0, 1200.0)
	kit.collected.connect(main._on_pickup_collected)
	main.pickups.add_child(kit)
	await _frames(60)
	_check(p2.hp > p2.max_health() * 0.4 + 10.0, "Reparaturkit heilt den verletzten Spieler (%d)" % p2.hp)
	_check(p2.hp <= p2.max_health(), "Heilung ueberschreitet das Maximum nicht")

	# Kit liegt liegen, wenn niemand es braucht.
	p2.hp = p2.max_health()
	var idle := Pickup.new()
	idle.kind = "hp"
	idle.players = main.players
	idle.floor_y = 1250.0
	idle.position = Vector2(1500.0, 1200.0)
	idle.collected.connect(main._on_pickup_collected)
	main.pickups.add_child(idle)
	await _frames(40)
	_check(is_instance_valid(idle) and not idle.is_queued_for_deletion(), "Kit bleibt liegen, wenn alle volle Leben haben")

	# Treffer-Rueckmeldung.
	p1.iframes = 0.0
	var shake_before: float = main.camera._shake
	p1.take_hit(20.0, p1.global_position + Vector2(40.0, 0.0))
	_check(main.camera._shake > shake_before, "Treffer loest Kamerawackeln aus")
	_check(main.hud._flash_time > 0.0, "Treffer loest roten Bildschirmrand aus")
	await get_tree().create_timer(0.3, true, false, true).timeout
	_check(is_equal_approx(Engine.time_scale, 1.0), "Hitstop endet wieder")
	print("Fertig, Fehler: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
