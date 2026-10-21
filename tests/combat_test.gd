extends Node
## Test des Kampfkerns: Gegnerangriffe mit Vorwarnung, kein Kontaktschaden,
## Projektile, Wiederbeleben, Game Over und Director.
## Ausfuehren: godot --headless --path . res://tests/combat_test.tscn

var main: Node
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	main.stage_id = "classic"
	add_child(main)
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("OK    ", message)
	else:
		print("FEHLER ", message)
		failures += 1


func _clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	for bullet in main.enemy_projectiles.get_children():
		bullet.queue_free()
	await _frames(2)


func _reset(player: Player, pos: Vector2) -> void:
	player.global_position = pos
	player.velocity = Vector2.ZERO
	player.hp = player.max_health()
	player.downed = false
	player.iframes = 0.0


func _run() -> void:
	await _frames(40)
	var p1: Player = main.players[0]
	var p2: Player = main.players[1]
	var director: Director = main.director

	# Kein Kontaktschaden: Gegner steht im Spieler, Schaden kommt erst nach der Vorwarnung
	_reset(p1, Vector2(1000.0, 1210.0))
	_reset(p2, Vector2(300.0, 1210.0))
	var walker: Enemy = director.spawn("walker", Vector2(1020.0, 1230.0))
	await _frames(15)
	_check(is_equal_approx(p1.hp, p1.max_health()), "Laeufer im Spieler macht keinen Kontaktschaden")
	var hit_frame := -1
	for i in 150:
		await _frames(1)
		if p1.hp < p1.max_health():
			hit_frame = i
			break
	_check(hit_frame >= 15, "Laeufer greift erst nach Vorwarnung an (Frame %d)" % hit_frame)
	_check(p1.iframes > 0.0, "Treffer loest Unverwundbarkeit aus")
	var hp_after := p1.hp
	await _frames(20)
	_check(is_equal_approx(p1.hp, hp_after) or p1.iframes > 0.0, "Iframes verhindern Mehrfachtreffer")
	await _clear_enemies()

	# Dash macht unverwundbar
	_reset(p1, Vector2(1000.0, 1210.0))
	Input.action_press("p1_dash")
	await _frames(3)
	Input.action_release("p1_dash")
	var blocked := not p1.take_hit(50.0, Vector2(900.0, 1210.0))
	_check(blocked and is_equal_approx(p1.hp, p1.max_health()), "Dash-Iframes blocken Treffer")
	await _frames(60)

	# Schuetze feuert Projektil mit Zielhilfe
	_reset(p1, Vector2(1000.0, 1210.0))
	var shooter: Enemy = director.spawn("shooter", Vector2(1500.0, 1230.0))
	var saw_projectile := false
	for i in 220:
		await _frames(1)
		if main.enemy_projectiles.get_child_count() > 0:
			saw_projectile = true
			break
	_check(saw_projectile, "Schuetze feuert ein Projektil")
	await _frames(120)
	_check(p1.hp < p1.max_health(), "Projektil trifft den Spieler (HP %d)" % int(p1.hp))
	await _clear_enemies()

	# Brute: Flaechenschlag
	_reset(p1, Vector2(1000.0, 1210.0))
	var brute: Enemy = director.spawn("brute", Vector2(1040.0, 1220.0))
	await _frames(40)
	_check(is_equal_approx(p1.hp, p1.max_health()), "Brute macht waehrend der Vorwarnung keinen Schaden")
	for i in 200:
		await _frames(1)
		if p1.hp < p1.max_health():
			break
	_check(p1.hp <= p1.max_health() - 20.0, "Brute-Schlag trifft hart (HP %d)" % int(p1.hp))
	await _clear_enemies()

	# Flieger fliegt und schiesst
	_reset(p1, Vector2(1000.0, 1210.0))
	var flyer: Enemy = director.spawn("flyer", Vector2(1200.0, 700.0))
	await _frames(120)
	_check(flyer.global_position.y < 1100.0, "Flieger bleibt in der Luft")
	await _clear_enemies()

	# Gegner sterben durch Schaden und zaehlen als besiegt
	var kills_before: int = main.kills
	var victim: Enemy = director.spawn("walker", Vector2(1500.0, 1230.0))
	victim.take_damage(9999.0, p1)
	await _frames(2)
	_check(main.kills == kills_before + 1, "Besiegter Gegner wird gezaehlt")

	# Niederlage und Wiederbeleben
	_reset(p1, Vector2(1000.0, 1210.0))
	_reset(p2, Vector2(1040.0, 1210.0))
	p1.take_hit(9999.0, Vector2(900.0, 1210.0))
	_check(p1.downed, "Spieler geht bei 0 Leben zu Boden")
	_check(not main.game_over, "Kein Game Over, solange der Partner steht")
	await _frames(30)
	Input.action_press("p2_interact")
	await _frames(100)
	_check(p1.downed and p1.revive_progress > 0.3, "Wiederbeleben baut Fortschritt auf (%.2f)" % p1.revive_progress)
	await _frames(120)
	Input.action_release("p2_interact")
	_check(not p1.downed and p1.hp > 0.0, "Partner belebt den Spieler (HP %d)" % int(p1.hp))

	# Zu weit weg: kein Fortschritt
	p1.iframes = 0.0
	p1.take_hit(9999.0, Vector2(900.0, 1210.0))
	p2.global_position = Vector2(1600.0, 1210.0)
	Input.action_press("p2_interact")
	await _frames(60)
	Input.action_release("p2_interact")
	_check(p1.downed and p1.revive_progress == 0.0, "Ohne Naehe kein Wiederbeleben")

	# Game Over, wenn beide am Boden sind
	p2.iframes = 0.0
	p2.take_hit(9999.0, Vector2(900.0, 1210.0))
	_check(main.game_over, "Game Over, wenn beide am Boden liegen")

	# Schadensstatistik: zaehlt echten Lebensverlust, ein Ueberschuss beim Todesstoss zaehlt nicht
	await _clear_enemies()
	_reset(p1, Vector2(1000.0, 1210.0))
	_reset(p2, Vector2(300.0, 1210.0))
	var target: Enemy = director.spawn("walker", Vector2(1400.0, 1230.0))
	await _frames(5)
	p1.damage_dealt = 0.0
	var before := target.hp
	target.take_damage(10.0, p1, Vector2.RIGHT, "", true)
	_check(is_equal_approx(p1.damage_dealt, 10.0), "Schaden wird dem Schuetzen gutgeschrieben (%.1f)" % p1.damage_dealt)
	p1.damage_dealt = 0.0
	var remaining := target.hp
	target.take_damage(99999.0, p1, Vector2.RIGHT, "", true)
	_check(is_equal_approx(p1.damage_dealt, remaining) and remaining < before, "Ueberschuss beim Todesstoss zaehlt nicht (%.1f von %.1f)" % [p1.damage_dealt, remaining])
	p2.damage_dealt = 0.0
	await _frames(3)
	_check(is_zero_approx(p2.damage_dealt), "Der Partner bekommt nichts gutgeschrieben")

	print("Fertig, Fehler: ", failures)
	get_tree().quit(failures)
