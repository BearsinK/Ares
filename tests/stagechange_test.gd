extends Node
## Test: Oft die Karte wechseln (auch von beliebigen Spielerzustaenden aus) und pruefen, dass beide Spieler
## danach sicher auf dem Boden stehen und nicht durch die neue Welt fallen (alte Welt darf nicht mehr stoeren).
## Ausfuehren: godot --headless --path . res://tests/stagechange_test.tscn

var failures := 0
var main: Node


func _check(condition: bool, message: String) -> void:
	if condition:
		print("OK    ", message)
	else:
		print("FEHLER ", message)
		failures += 1


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.set_meta("classes", ["roomba", "vending"])
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	main.chests_enabled = false
	add_child(main)
	await get_tree().physics_frame
	var bad := 0
	var maps := {}
	for round in 48:
		main.wave = 1 + (round % 9)
		main._stage_order = Stages.random_order()
		# Mal in der Luft, mal am Boden, mal mit Schwung: die alte Welt verschwindet auch dann sofort.
		for p in main.players:
			p.velocity = Vector2(randf_range(-600.0, 600.0), randf_range(-500.0, 500.0))
		main._change_stage()
		maps[main.stage_layout.id] = true
		for i in 70:
			await get_tree().physics_frame
		for p in main.players:
			p.hp = p.max_health()
			if p.global_position.y > 2210.0 or not p.is_on_floor():
				bad += 1
				print("   schlecht: Runde %d Karte %s P%d bei %s Boden %s" % [round, main.stage_layout.id, p.player_index, str(p.global_position), str(p.is_on_floor())])
	_check(maps.size() == 3, "Alle drei Karten wurden gebaut (%s)" % str(maps.keys()))
	_check(bad == 0, "Nach 48 Kartenwechseln stehen alle Spieler auf dem Boden (%d schlechte Faelle)" % bad)
	_check(main._arena_root != null and main._arena_root.is_inside_tree(), "Die neue Welt steht im Baum")
	print("Fertig, Fehler: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
