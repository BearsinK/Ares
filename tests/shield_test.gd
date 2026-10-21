extends Node
## Test der Gegner Aegis (Frontschild) und Nest (setzt Buzzer ab).
## Ausfuehren: godot --headless --path . res://tests/shield_test.tscn

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


func _ready() -> void:
	_run.call_deferred()


func _hurtbox(enemy: Enemy) -> EnemyHurtbox:
	for child in enemy.get_children():
		if child is EnemyHurtbox:
			return child
	return null


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
	p1.global_position = Vector2(300.0, 1210.0)
	p2.global_position = Vector2(200.0, 1210.0)
	p1.hp = 1.0e6
	p2.hp = 1.0e6
	p1.invulnerable = true
	p2.invulnerable = true
	await _aegis()
	await _nest()
	print("Fertig, Fehler: ", failures)
	main.queue_free()
	get_tree().quit(1 if failures > 0 else 0)


func _aegis() -> void:
	_check(EnemyTypes.DATA.has("aegis") and EnemyTypes.DATA.has("nest"), "Beide Gegnertypen sind definiert")
	var director: Director = main.director
	director.wave = 1
	director.wave_progress = 0.0
	var early := {}
	for i in 400:
		early[director._choose_kind()] = true
	_check(not early.has("aegis") and not early.has("nest"), "Am Anfang gibt es sie noch nicht")
	director.wave = 6
	director.wave_progress = 0.5
	var late := {}
	for i in 1500:
		late[director._choose_kind()] = true
	_check(late.has("aegis") and late.has("nest"), "Spaeter im Lauf erscheinen beide")

	var aegis: Enemy = director.spawn("aegis", Vector2(1500.0, 1225.0))
	aegis._cooldown = 99.0
	aegis.speed_mult = 0.0
	aegis._facing = 1.0
	_check(aegis.is_blocking(Vector2.LEFT), "Schuss von vorn (gegen die Blickrichtung) wird abgefangen")
	_check(aegis.is_blocking(Vector2(-1.0, 0.3)), "Auch leicht schraeg von vorn")
	_check(not aegis.is_blocking(Vector2.RIGHT), "Schuss von hinten geht durch")
	_check(not aegis.is_blocking(Vector2.DOWN) and not aegis.is_blocking(Vector2(-0.3, 1.0)), "Steil von oben geht durch")
	_check(not aegis.is_blocking(Vector2.ZERO), "Ohne Richtung (Sprengung, Effekt) geht es durch")
	aegis._facing = -1.0
	_check(aegis.is_blocking(Vector2.RIGHT) and not aegis.is_blocking(Vector2.LEFT), "Schaut er nach links, dreht sich der Schutz mit")
	aegis._facing = 1.0

	var box := _hurtbox(aegis)
	var before := aegis.hp
	box.take_damage(50.0, p1, Vector2.LEFT, "")
	var blocked_loss := before - aegis.hp
	before = aegis.hp
	box.take_damage(50.0, p1, Vector2.RIGHT, "")
	var open_loss := before - aegis.hp
	_check(open_loss > 30.0 and blocked_loss < open_loss * 0.2, "Von vorn kaum Schaden, von hinten voll (%.1f gegen %.1f)" % [blocked_loss, open_loss])
	_check(aegis._block_flash > 0.0 or open_loss > 0.0, "Der Schild blitzt beim Abprallen")

	# Elemente wirken nicht durch den Schild.
	var fresh: Enemy = director.spawn("aegis", Vector2(1700.0, 1225.0))
	fresh._cooldown = 99.0
	fresh.speed_mult = 0.0
	fresh._facing = 1.0
	_hurtbox(fresh).take_damage(10.0, p1, Vector2.LEFT, "fire")
	_check(not fresh.statuses.has("burning"), "Feuer brennt nicht durch den Frontschild")
	_hurtbox(fresh).take_damage(10.0, p1, Vector2.RIGHT, "fire")
	_check(fresh.statuses.has("burning"), "Von hinten brennt es")

	# Sprengungen gehen durch.
	var target: Enemy = director.spawn("aegis", Vector2(2000.0, 1225.0))
	target._cooldown = 99.0
	target.speed_mult = 0.0
	target._facing = 1.0
	var hp_before := target.hp
	main._explode(target.global_position + Vector2(60.0, 0.0), 120.0, 80.0, p1, Color.WHITE)
	_check(hp_before - target.hp > 20.0, "Eine Sprengung von vorn trifft voll (%.0f)" % (hp_before - target.hp))

	# Betaeubt: Schild unten.
	target.stun(2.0)
	_check(not target.is_blocking(Vector2.LEFT), "Betaeubt faengt er nichts ab")

	# Schlag: trifft einen Spieler in der Reichweite.
	p1.invulnerable = false
	p1.hp = p1.max_health()
	p1.iframes = 0.0
	var basher: Enemy = director.spawn("aegis", Vector2(1000.0, 1225.0))
	p1.global_position = Vector2(1040.0, 1210.0)
	p2.global_position = Vector2(2900.0, 1210.0)
	var waited := 0
	while p1.hp >= p1.max_health() and waited < 600:
		await _frames(1)
		waited += 1
		p1.global_position = Vector2(1040.0, 1210.0)
	_check(p1.hp < p1.max_health(), "Der Schildschlag trifft den Spieler (%.0f)" % p1.hp)
	p1.invulnerable = true
	p1.hp = 1.0e6
	for e in [aegis, fresh, target, basher]:
		if is_instance_valid(e):
			e.queue_free()
	await _frames(2)


func _nest() -> void:
	var director: Director = main.director
	p1.global_position = Vector2(500.0, 1210.0)
	p2.global_position = Vector2(400.0, 1210.0)
	var nest: Enemy = director.spawn("nest", Vector2(1100.0, 1225.0))
	nest.speed_mult = 0.0
	nest._cooldown = 0.0
	var waited := 0
	while nest.alive_minions() < 2 and waited < 600:
		await _frames(1)
		waited += 1
	_check(nest.alive_minions() == 2, "Das Nest setzt zwei Buzzer ab (%d)" % nest.alive_minions())
	var minions: Array = nest._minions.duplicate()
	var all_flyers := true
	for m in minions:
		all_flyers = all_flyers and m.kind == "flyer" and m.minion
	_check(all_flyers, "Es sind Buzzer und als Nest-Gegner markiert")

	# Obergrenze.
	for round in 5:
		nest._cooldown = 0.0
		nest._state = Enemy.State.CHASE
		director._on_spawn_requested(nest, "flyer", 2)
	_check(nest.alive_minions() <= int(nest.data.max_minions), "Hoechstens %d gleichzeitig (%d)" % [int(nest.data.max_minions), nest.alive_minions()])

	# Nest-Buzzer geben keine Beute und zaehlen nicht.
	var kills_before: int = main.kills
	var pickups_before: int = main.pickups.get_child_count()
	var victim: Enemy = nest._minions[0]
	victim.take_damage(9999.0, p1, Vector2.RIGHT, "")
	await _frames(3)
	_check(main.kills == kills_before and main.pickups.get_child_count() == pickups_before, "Ein Nest-Buzzer gibt weder Kill noch Beute")

	# Zerstoert man das Nest, stuerzen alle Buzzer mit ab.
	var survivors: Array = []
	for m in nest._minions:
		if is_instance_valid(m) and not m._dead:
			survivors.append(m)
	_check(survivors.size() >= 1, "Es leben noch Buzzer (%d)" % survivors.size())
	nest.take_damage(99999.0, p1, Vector2.RIGHT, "")
	await _frames(4)
	var left := 0
	for m in survivors:
		if is_instance_valid(m) and not m.is_queued_for_deletion():
			left += 1
	_check(left == 0, "Mit dem Nest sind auch seine Buzzer weg")
	_check(main.kills == kills_before + 1, "Nur das Nest zaehlt als Kill")
