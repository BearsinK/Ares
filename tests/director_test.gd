extends Node
## Test des Directors: Gegner erscheinen nach und nach, Obergrenze, Typfreischaltung.
## Ausfuehren: godot --headless --path . res://tests/director_test.tscn

var main: Node
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
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


func _run() -> void:
	await _frames(10)
	var director: Director = main.director
	# Spieler unverwundbar machen, damit der Test lange laufen kann
	for player in main.players:
		player.iframes = 9999.0
	await _frames(60 * 3)
	var early := director.alive_count()
	_check(early >= 1 and early <= 12, "Anfangs erscheinen wenige Gegner (%d nach 3 s)" % early)
	var kinds := {}
	await _frames(60 * 5)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		kinds[enemy.kind] = true
	_check(not kinds.has("brute"), "Brute erscheint nicht zu frueh")

	# Zeit vorspulen
	director.wave = 4
	director.enemy_spawned.connect(func(enemy: Enemy) -> void: kinds[enemy.kind] = true)
	await _frames(60 * 20)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		kinds[enemy.kind] = true
	_check(kinds.size() >= 3, "Spaeter erscheinen mehrere Typen (%s)" % str(kinds.keys()))
	_check(director.alive_count() <= director.current_cap(), "Obergrenze wird eingehalten (%d <= %d)" % [director.alive_count(), director.current_cap()])
	_check(director.alive_count() > early, "Menge steigt mit der Zeit (%d)" % director.alive_count())
	print("Fertig, Fehler: ", failures)
	get_tree().quit(failures)
