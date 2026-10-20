extends Node
## Test der Gegner Sprengi (Selbstsprengung) und Medic (heilt Verbuendete).
## Ausfuehren: godot --headless --path . res://tests/newenemy_test.tscn

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
	p1.global_position = Vector2(1200.0, 1210.0)
	p2.global_position = Vector2(300.0, 1210.0)
	p1.iframes = 0.0

	_check(EnemyTypes.DATA.has("bomber") and EnemyTypes.DATA.has("medic"), "Beide neuen Gegnertypen sind definiert")

	# Director: nach der Freischaltzeit tauchen beide auf.
	var director: Director = main.director
	director.wave = 6
	director.wave_progress = 0.5
	var seen := {}
	for i in 600:
		seen[director._choose_kind()] = true
	_check(seen.has("bomber") and seen.has("medic"), "Spaeter im Lauf erscheinen Sprengi und Medic (%s)" % str(seen.keys()))
	director.wave = 1
	director.wave_progress = 0.0
	var early := {}
	for i in 300:
		early[director._choose_kind()] = true
	_check(not early.has("bomber") and not early.has("medic"), "Am Anfang gibt es sie noch nicht")

	# Sprengi: rennt hin, sprengt sich, verletzt den Spieler, laesst nichts fallen.
	var kills_before: int = main.kills
	var bomber: Enemy = main.director.spawn("bomber", Vector2(1330.0, 1225.0))
	var hp_before := p1.hp
	var pickups_before: int = main.pickups.get_child_count()
	var waited := 0
	while is_instance_valid(bomber) and not bomber.is_queued_for_deletion() and waited < 400:
		await _frames(1)
		waited += 1
		p1.iframes = 0.0
	_check(not is_instance_valid(bomber) or bomber.is_queued_for_deletion(), "Der Sprengi sprengt sich selbst")
	_check(p1.hp < hp_before, "Die Explosion trifft den Spieler (%.0f -> %.0f)" % [hp_before, p1.hp])
	await _frames(3)
	_check(main.kills == kills_before, "Eine Selbstsprengung zaehlt nicht als Kill")
	_check(main.pickups.get_child_count() == pickups_before, "Und gibt keine Beute")
	p1.hp = p1.max_health()

	# Sprengi abgeschossen: normale Beute und Kill.
	var shot: Enemy = main.director.spawn("bomber", Vector2(1800.0, 1225.0))
	shot._cooldown = 99.0
	shot.take_damage(9999.0, p1, Vector2.ZERO)
	await _frames(3)
	_check(main.kills == kills_before + 1, "Abgeschossen zaehlt er als Kill")

	# Elite-Sprengi: behaelt die Beute, auch wenn er sich sprengt.
	var elite_bomber: Enemy = main.director.spawn("bomber", Vector2(1800.0, 1225.0), true)
	_check(elite_bomber.elite, "Ein Elite-Sprengi ist eine Elite")
	elite_bomber._cooldown = 99.0
	elite_bomber._execute_attack()
	_check(not elite_bomber.suicide, "Er behaelt seine Beute (kein Selbstmord-Verlust)")
	await _frames(3)

	# Medic heilt verwundete Verbuendete in der Naehe.
	p1.global_position = Vector2(300.0, 1210.0)
	p2.global_position = Vector2(200.0, 1210.0)
	var medic: Enemy = main.director.spawn("medic", Vector2(1800.0, 1225.0))
	var patient: Enemy = main.director.spawn("brute", Vector2(1900.0, 1225.0))
	var healthy: Enemy = main.director.spawn("walker", Vector2(1850.0, 1225.0))
	patient._cooldown = 99.0
	healthy._cooldown = 99.0
	patient.hp = patient.max_hp * 0.3
	var low_before := patient.hp
	medic._cooldown = 0.0
	waited = 0
	while patient.hp <= low_before and waited < 400:
		await _frames(1)
		waited += 1
	_check(patient.hp > low_before + patient.max_hp * 0.2, "Der Medic heilt den Verwundeten (%.0f -> %.0f)" % [low_before, patient.hp])
	_check(is_equal_approx(healthy.hp, healthy.max_hp), "Gesunde bleiben unveraendert")
	_check(medic.hp == medic.max_hp, "Er heilt nicht sich selbst")

	# Ohne Verwundete bleibt er untaetig.
	patient.hp = patient.max_hp
	medic._cooldown = 0.0
	await _frames(60)
	_check(medic._state != Enemy.State.WINDUP, "Ohne Verwundete startet er keine Heilung")

	# Waechter werden nur schwach geheilt.
	var champion: Enemy = main.director.spawn("brute", medic.global_position + Vector2(90.0, 0.0), true, "", true)
	champion._cooldown = 99.0
	champion.speed_mult = 0.0
	champion.hp = champion.max_hp * 0.4
	var champion_before := champion.hp
	medic._cooldown = 0.0
	waited = 0
	while champion.hp <= champion_before and waited < 400:
		await _frames(1)
		waited += 1
	var healed := champion.hp - champion_before
	_check(healed > 0.0 and healed < champion.max_hp * 0.2, "Waechter werden nur schwach geheilt (%.0f von %.0f)" % [healed, champion.max_hp])

	print("Fertig, Fehler: ", failures)
	main.queue_free()
	get_tree().quit(1 if failures > 0 else 0)
