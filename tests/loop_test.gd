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
	await _perks(p1, p2)
	await _new_enemies(p1, p2)
	print("Fertig, Fehler: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


func _perks(p1: Player, p2: Player) -> void:
	for pickup in main.pickups.get_children():
		pickup.queue_free()
	p1.global_position = Vector2(300.0, 1225.0)
	p2.global_position = Vector2(2900.0, 1225.0)
	p1.hp = 50.0
	p1.add_mods(Perks.mods_for("scavenger", p1.class_id))
	_check(float(p1.mods.kill_heal) == 1.0, "Notstrom gibt Heilung pro Kill")
	var a: Enemy = main.director.spawn("walker", Vector2(1500.0, 1225.0))
	a._cooldown = 99.0
	a.take_damage(1.0e9, p1, Vector2.ZERO, "", true)
	_check(is_equal_approx(p1.hp, 51.0), "Kill heilt den Spieler (%.1f)" % p1.hp)

	# Sprengkapsel: Nachbarn des Toten nehmen Schaden.
	p1.add_mods(Perks.mods_for("boomchip", p1.class_id))
	var victim: Enemy = main.director.spawn("walker", Vector2(1500.0, 1225.0))
	var neighbor: Enemy = main.director.spawn("walker", Vector2(1540.0, 1225.0))
	var far: Enemy = main.director.spawn("walker", Vector2(1900.0, 1225.0))
	for e in [victim, neighbor, far]:
		e._cooldown = 99.0
	var neighbor_hp := neighbor.hp
	var far_hp := far.hp
	victim.take_damage(1.0e9, p1, Vector2.ZERO, "", true)
	_check(neighbor.hp < neighbor_hp, "Sprengkapsel verletzt Gegner in der Naehe")
	_check(far.hp == far_hp, "Sprengkapsel verschont ferne Gegner")

	# Kuehlkreislauf verkuerzt die Abklingzeit, Durchschlag haelt als Wert.
	p1.add_mods(Perks.mods_for("chillloop", p1.class_id))
	p1.ability.cooldown = 0.0
	p1.ability.try_use()
	_check(absf(p1.ability.cooldown_total - float(p1.stats.ability.cooldown) * 0.8) < 0.01, "Kuehlkreislauf senkt die Abklingzeit um 20 Prozent")
	p1.add_mods(Perks.mods_for("piercer", p1.class_id))
	_check(int(p1.mods.pierce) == 1, "Durchschlag stapelt sich als Wert")
	for id in Perks.DATA:
		_check(Perks.describe(id, "roomba") != "" and Perks.describe(id, "vending") != "", "Perk %s hat eine Beschreibung" % id)


func _new_enemies(p1: Player, p2: Player) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await _frames(3)
	p1.global_position = Vector2(1100.0, 1225.0)
	p2.global_position = Vector2(2900.0, 1225.0)
	p1.hp = p1.max_health()
	p1.iframes = 0.0
	await _frames(10)

	# Rammbock: kuendigt an, rennt los und trifft.
	var charger: Enemy = main.director.spawn("charger", Vector2(1450.0, 1225.0))
	charger._cooldown = 0.0
	var saw_windup := false
	var saw_charge := false
	for i in 150:
		await get_tree().physics_frame
		saw_windup = saw_windup or charger._state == Enemy.State.WINDUP
		saw_charge = saw_charge or charger._state == Enemy.State.CHARGE
		if saw_charge and p1.hp < p1.max_health():
			break
	_check(saw_windup, "Rammbock kuendigt den Ansturm an")
	_check(saw_charge, "Rammbock rennt los")
	_check(p1.hp < p1.max_health(), "Rammbock trifft den Spieler im Weg (%d Leben)" % p1.hp)
	charger.queue_free()
	await _frames(3)

	# Moerser: Warnkreis, dann Einschlag.
	p1.iframes = 0.0
	p1.hp = p1.max_health()
	p1.global_position = Vector2(1100.0, 1225.0)
	var mortar: Enemy = main.director.spawn("mortar", Vector2(1800.0, 1225.0))
	mortar._cooldown = 0.0
	var strike: AreaStrike = null
	for i in 200:
		await get_tree().physics_frame
		for node in main.enemy_projectiles.get_children():
			if node is AreaStrike:
				strike = node
		if strike != null:
			break
	_check(strike != null, "Moerser feuert einen Warnkreis ab")
	if strike != null:
		var hp_before := p1.hp
		strike.global_position = p1.global_position
		await get_tree().create_timer(1.6, true, false, true).timeout
		_check(p1.hp < hp_before, "Einschlag verletzt, wer im Kreis stehen bleibt (%d -> %d)" % [hp_before, p1.hp])
	mortar.queue_free()
	await _frames(3)
	# Ausweichen: Spieler steht beim Einschlag woanders.
	p1.iframes = 0.0
	p1.hp = p1.max_health()
	var dodge := AreaStrike.new()
	dodge.position = Vector2(1500.0, 1225.0)
	dodge.delay = 0.3
	dodge.players = main.players
	main.enemy_projectiles.add_child(dodge)
	await get_tree().create_timer(0.8, true, false, true).timeout
	_check(p1.hp == p1.max_health(), "Wer ausserhalb des Kreises steht, bleibt unverletzt")
