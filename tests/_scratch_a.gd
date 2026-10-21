extends Node

var main: Node
var p1: Player
var p2: Player


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
	p1.invulnerable = true
	p2.invulnerable = true

	# Zone mit Element
	var e: Enemy = main.director.spawn("brute", Vector2(800.0, 1200.0))
	e.set_physics_process(false)
	e.hp = 5000.0
	e.max_hp = 5000.0
	var zone := Zone.new()
	zone.owner_player = p1
	zone.position = Vector2(800.0, 1200.0)
	zone.radius = 150.0
	zone.life = 3.0
	zone.dps = 10.0
	zone.status = "inked"
	zone.element = "fire"
	main.add_child(zone)
	await _frames(90)
	print("ZONE fire: burning=", e.statuses.has("burning"), " inked=", e.statuses.has("inked"), " hp=", e.hp)
	e.free()

	# Muendung beim Klammern mit Restneigung
	var hexa: Player = p2
	print("class p2 = ", hexa.class_id)
	hexa.global_position = Vector2(1000.0, 1200.0)
	hexa.facing = 1
	hexa._slope_tilt = -0.46
	hexa._slope_shift = Vector2(5.0, -9.0)
	hexa._clinging = true
	hexa._cling_dir = 1
	var with_slope := hexa._muzzle_offset()
	hexa._slope_tilt = 0.0
	hexa._slope_shift = Vector2.ZERO
	var without := hexa._muzzle_offset()
	print("Muendung klammernd mit Restneigung ", with_slope, " ohne ", without, " Abweichung ", with_slope.distance_to(without))
	hexa._clinging = false
	hexa._ceiling = true
	hexa._slope_tilt = -0.46
	hexa._slope_shift = Vector2(5.0, -9.0)
	print("Decke mit Restneigung ", hexa._muzzle_offset())
	hexa._slope_tilt = 0.0
	hexa._slope_shift = Vector2.ZERO
	print("Decke ohne ", hexa._muzzle_offset())
	hexa._ceiling = false
	print("Fertig")
	get_tree().quit()
