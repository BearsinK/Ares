extends Node
## Entwickler-Werkzeug: misst die Frame-Zeit mit vielen Gegnern gleichzeitig.
## Ausfuehren: PERF_ENEMIES=60 godot --headless --path . res://tests/perf.tscn

var main: Node


func _ready() -> void:
	Engine.set_meta("classes", OS.get_environment("PERF_CLASSES").split(",") if OS.get_environment("PERF_CLASSES") != "" else ["roomba", "hexapod"])
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	main.stage_id = "classic"
	add_child(main)
	_run.call_deferred()


func _run() -> void:
	for i in 30:
		await get_tree().physics_frame
	var count := int(OS.get_environment("PERF_ENEMIES")) if OS.get_environment("PERF_ENEMIES") != "" else 60
	var kinds := ["walker", "shooter", "flyer", "charger", "mortar", "brute", "walker", "walker"]
	for p in main.players:
		p.global_position = Vector2(1500.0, 1215.0)
		p.hp = 1.0e6
	for i in count:
		var e: Enemy = main.director.spawn(kinds[i % kinds.size()], Vector2(1100.0 + (i % 20) * 40.0, 1225.0 - (i / 20) * 60.0))
		e.on_screen = true
	var drop := OS.get_environment("PERF_DROP")
	if drop != "":
		for child in main.get_children():
			if child.get_class() == drop or child.get_script() != null and str(child.get_script().get_global_name()) == drop:
				child.queue_free()
				print("entfernt ", child)
		await get_tree().process_frame
	var process_total := 0.0
	var physics_total := 0.0
	var frames := 240
	for i in frames:
		await get_tree().process_frame
		process_total += Performance.get_monitor(Performance.TIME_PROCESS)
		physics_total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	print("Gegner ", count, ": process ", snappedf(process_total / frames * 1000.0, 0.01), " ms, physics ", snappedf(physics_total / frames * 1000.0, 0.01), " ms pro Frame, Objekte ", Performance.get_monitor(Performance.OBJECT_COUNT), " Nodes ", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	get_tree().quit()
