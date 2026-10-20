extends Node
## Test des Automaten: Dosenwurf im Bogen und Schuettel-Aufladung.
## Ausfuehren: godot --headless --path . res://tests/vending_test.tscn

var main: Node
var failures := 0
var p1: Player


func _ready() -> void:
	Engine.set_meta("classes", ["vending", "roomba"])
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


func _cans() -> Array:
	var result: Array = []
	for child in main.projectiles.get_children():
		if child is Projectile and child.arc_gravity > 0.0:
			result.append(child)
	return result


func _clear() -> void:
	for child in main.projectiles.get_children():
		child.queue_free()
	await _frames(3)


func _dummy(x: float) -> TestDummy:
	var dummy := TestDummy.new()
	dummy.position = Vector2(x, 1210.0)
	dummy.max_health = 100000.0
	dummy.health = 100000.0
	main.add_child(dummy)
	return dummy


func _run() -> void:
	await _frames(40)
	p1 = main.players[0]
	main.players[1].global_position = Vector2(100.0, 1210.0)
	p1.global_position = Vector2(500.0, 1194.0)
	await _frames(10)
	_check(p1.class_id == "vending" and p1.current_weapon_id() == "can", "Der Automat startet mit der Dose")

	# Halten schuettelt, es wird noch nichts geworfen
	Input.action_press("p1_fire")
	await _frames(36)
	_check(p1.shake_charge > 0.35 and p1.shake_charge < 0.65, "Halten laedt das Schuetteln auf (%.2f)" % p1.shake_charge)
	_check(_cans().is_empty(), "Waehrend des Schuettelns fliegt noch keine Dose")

	# Loslassen wirft im Bogen
	Input.action_release("p1_fire")
	await _frames(2)
	var cans := _cans()
	_check(cans.size() == 1, "Loslassen wirft genau eine Dose")
	var can: Projectile = cans[0]
	_check(can.shaken and can.explosion_radius > 70.0 and can.explosion_radius < 190.0, "Geschuettelte Dose explodiert mit mittlerem Radius (%.0f)" % can.explosion_radius)
	var vy_start := can._velocity.y
	await _frames(5)
	_check(can._velocity.y > vy_start + 90.0, "Die Dose fliegt im Bogen (Schwerkraft: %.0f -> %.0f)" % [vy_start, can._velocity.y])
	_check(p1.shake_charge == 0.0, "Aufladung ist nach dem Wurf zurueckgesetzt")
	await _frames(120)
	await _clear()

	# Kurzer Tipp: ungeschuettelt, keine Explosion
	await _frames(30)
	Input.action_press("p1_fire")
	await _frames(3)
	Input.action_release("p1_fire")
	await _frames(2)
	cans = _cans()
	_check(cans.size() == 1 and not cans[0].shaken and cans[0].explosion_radius == 0.0, "Tipp wirft eine ungeschuettelte Dose ohne Explosion")
	var tap_speed: float = cans[0].speed
	await _frames(120)
	await _clear()

	# Voll geschuettelt: schneller und groesserer Radius
	await _frames(30)
	Input.action_press("p1_fire")
	await _frames(100)
	_check(is_equal_approx(p1.shake_charge, 1.0), "Aufladung stoppt bei voll (%.2f)" % p1.shake_charge)
	Input.action_release("p1_fire")
	await _frames(2)
	cans = _cans()
	_check(cans.size() == 1 and cans[0].explosion_radius >= 189.0 and cans[0].speed > tap_speed + 250.0, "Volle Aufladung: groesserer Radius (%.0f) und mehr Tempo (%.0f gegen %.0f)" % [cans[0].explosion_radius, cans[0].speed, tap_speed])
	await _frames(120)
	await _clear()

	# Explosion beim Aufprall verletzt Gegner im Radius (Wurf schraeg nach oben rechts)
	p1.global_position = Vector2(300.0, 1194.0)
	p1.velocity = Vector2.ZERO
	var near := _dummy(300.0 + 700.0)
	await _frames(20)
	Input.action_press("p1_aim_right")
	Input.action_press("p1_aim_up")
	await _frames(3)
	Input.action_press("p1_fire")
	await _frames(100)
	Input.action_release("p1_fire")
	await _frames(100)
	Input.action_release("p1_aim_right")
	Input.action_release("p1_aim_up")
	var loss: float = near.max_health - near.health
	_check(loss >= 25.0, "Explosion der geschuettelten Dose verletzt das Ziel (%.0f)" % loss)

	# Ungeschuettelte Dose macht nur kleinen Direktschaden und keine Flaechenwirkung
	near.health = near.max_health
	p1.global_position = Vector2(300.0, 1194.0)
	p1.velocity = Vector2.ZERO
	var close := _dummy(300.0 + 330.0)
	await _frames(40)
	Input.action_press("p1_aim_right")
	Input.action_press("p1_aim_up")
	await _frames(3)
	Input.action_press("p1_fire")
	await _frames(3)
	Input.action_release("p1_fire")
	await _frames(120)
	Input.action_release("p1_aim_right")
	Input.action_release("p1_aim_up")
	var tap_loss: float = close.max_health - close.health
	_check(tap_loss <= 15.0, "Ungeschuettelte Dose: nur Direktschaden, keine Explosion (%.0f)" % tap_loss)

	# Treffer unterbricht das Schuetteln
	await _frames(20)
	Input.action_press("p1_fire")
	await _frames(20)
	_check(p1.shake_charge > 0.1, "Aufladung laeuft")
	p1.iframes = 0.0
	p1.take_hit(9999.0, p1.global_position + Vector2(10.0, 0.0))
	await _frames(2)
	Input.action_release("p1_fire")
	_check(p1.shake_charge == 0.0 and p1.downed, "Am Boden ist die Aufladung weg")

	await _polish()
	print("Fertig, Fehler: ", failures)
	get_tree().quit(failures)


func _polish() -> void:
	p1.revive(1.0)
	p1.hp = p1.max_health()
	await _frames(30)
	# Schwerer Aufprall: Beben und Signal.
	var landed := [0.0]
	p1.heavy_landed.connect(func(_p: Player, strength: float) -> void: landed[0] = strength)
	p1.global_position = Vector2(850.0, 600.0)
	p1.velocity = Vector2.ZERO
	await _frames(120)
	_check(landed[0] > 0.3, "Harter Aufprall loest ein Beben aus (%.2f)" % landed[0])

	# Stabil: Rueckstoss bei Treffern nur halb so stark wie beim Roomba.
	p1.iframes = 0.0
	p1.velocity = Vector2.ZERO
	p1.take_hit(10.0, p1.global_position + Vector2(40.0, 0.0))
	var push_vending := absf(p1.velocity.x)
	var other: Player = main.players[1]
	other.iframes = 0.0
	other.velocity = Vector2.ZERO
	other.take_hit(10.0, other.global_position + Vector2(40.0, 0.0))
	_check(push_vending < absf(other.velocity.x) * 0.6, "Der Automat wird kaum zurueckgestossen (%d zu %d)" % [push_vending, absf(other.velocity.x)])

	# Muenze, Walze, Umkippen.
	await _frames(40)
	p1.gold_flash()
	var state := p1._art_state()
	_check(float(state.coin) > 0.9 and state.mood == "happy", "Gold laesst den Muenzschlitz aufleuchten")
	p1.ability.cooldown = 0.0
	p1.iframes = 0.0
	p1.ability.try_use()
	state = p1._art_state()
	_check(state.mood == "angry" and absf(float(state.tilt)) > 0.05 and float(state.overdrive) > 0.5, "Als Walze lehnt er sich vor und schaut boese")
	p1.ability.time = 0.0
	p1.hp = p1.max_health() * 0.1
	_check(float(p1._art_state().low) > 0.5, "Bei wenig Leben qualmt er")
	p1.iframes = 0.0
	p1.take_hit(9999.0, p1.global_position + Vector2(10.0, 0.0))
	await _frames(80)
	_check(float(p1._art_state().down) > 0.95, "Ausgeschaltet kippt er um (%.2f)" % float(p1._art_state().down))
	p1.revive(0.5)
	await _frames(80)
	_check(absf(float(p1._art_state().tilt)) < 0.05, "Wiederbelebt richtet er sich auf")
