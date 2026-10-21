extends Node
## Entwickler-Werkzeug: misst fuer jede Waffe den Schaden pro Sekunde gegen ein einzelnes Ziel und gegen eine Gruppe.
## Der Schuetze und die Ziele bleiben an ihrem Platz, Nachladen zaehlt mit. Nur Richtwerte zum Vergleichen (Klassen-
## Schadensfaktoren sind nicht enthalten, Modul und Upgrades fehlen).
## Ausfuehren: godot --headless --path . res://tests/weapon_bench.tscn   (BENCH_WEAPONS=dust,rapid fuer eine Auswahl, BENCH_SECONDS=6; dauert in Echtzeit rund 5 Minuten)

var main: Node
var p1: Player
var rows: Array[Dictionary] = []
var _homes: Array[Vector2] = []
var _targets: Array[Enemy] = []
var _current := "dust"

const SHOOTER_POS := Vector2(500.0, 1200.0)
const HP := 1.0e7


func _ready() -> void:
	Engine.set_meta("classes", ["roomba", "hexapod"])
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	main.stage_id = "classic"
	add_child(main)
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _run() -> void:
	# Zeitraffer vergroessert auch den Zeitschritt (Geschosse tunneln), daher Echtzeit. BENCH_SCALE nur fuer grobe Laeufe.
	Engine.time_scale = float(OS.get_environment("BENCH_SCALE")) if OS.get_environment("BENCH_SCALE") != "" else 1.0
	await _frames(15)
	p1 = main.players[0]
	p1.invulnerable = true
	main.players[1].invulnerable = true
	main.players[1].global_position = Vector2(100.0, 1200.0)
	var ids: Array = Weapons.ALL_IDS
	if OS.get_environment("BENCH_WEAPONS") != "":
		ids = OS.get_environment("BENCH_WEAPONS").split(",")
	var seconds := float(OS.get_environment("BENCH_SECONDS")) if OS.get_environment("BENCH_SECONDS") != "" else 10.0
	for id in ids:
		var single := await _measure(String(id), 1, seconds)
		var pack := await _measure(String(id), 8, seconds)
		rows.append({"id": id, "single": single, "pack": pack})
	print("")
	print("%-10s %-10s %8s %8s %6s" % ["Waffe", "Art", "1 Ziel", "8 Ziele", "Faktor"])
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.single) > float(b.single))
	for row in rows:
		var weapon := Weapons.get_weapon(row.id)
		print("%-10s %-10s %8.0f %8.0f %6.1f" % [row.id, weapon.kind, row.single, row.pack, float(row.pack) / maxf(float(row.single), 0.01)])
	Engine.time_scale = 1.0
	get_tree().quit()


func _clear() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy:
			enemy.free()
	for child in main.projectiles.get_children():
		child.free()
	_targets.clear()
	_homes.clear()


## Abstand, in dem eine Waffe gut arbeitet: ein Teil ihrer Reichweite, mindestens 150 px.
func _distance_for(id: String) -> float:
	var weapon := Weapons.get_weapon(id)
	var reach := 450.0
	match String(weapon.kind):
		"hitscan":
			reach = 500.0
		"sweep", "stream", "chain":
			reach = float(weapon.range)
		"deploy", "summon":
			reach = 420.0
		_:
			if weapon.has("boomerang"):
				reach = float(weapon.speed) * float(weapon.boomerang)
			elif weapon.has("gravity"):
				reach = 420.0
			elif weapon.has("homing"):
				reach = 600.0
			else:
				reach = float(weapon.speed) * float(weapon.lifetime)
	return clampf(reach * 0.6, 150.0, 520.0)


func _spawn(count: int) -> void:
	var near := _distance_for(_current)
	for i in count:
		var pos := Vector2(SHOOTER_POS.x + near, 1200.0) if count == 1 else Vector2(SHOOTER_POS.x + near - 30.0 + (i % 4) * 55.0, 1200.0 - (i / 4) * 70.0)
		var e: Enemy = main.director.spawn("brute", pos)
		e.hp = HP
		e.max_hp = HP
		e._cooldown = 99.0
		e.speed_mult = 0.0
		_targets.append(e)
		_homes.append(pos)


## Schaden pro Sekunde einer Waffe gegen count Ziele in der angegebenen Zeit.
func _measure(id: String, count: int, seconds: float) -> float:
	_clear()
	_current = id
	p1.weapons = [id]
	p1.modules = [""]
	p1.weapon_index = 0
	p1.refill_ammo()
	p1.global_position = SHOOTER_POS
	_spawn(count)
	await _frames(3)
	for e in _targets:
		e.hp = HP
	var shots := [0]
	var counter := func(_p: Player, _id: String, _o: Vector2, _d: Vector2, _c: float) -> void: shots[0] += 1
	p1.fired.connect(counter)
	var lob := String(Weapons.get_weapon(id).kind) == "lob"
	Input.action_press("p1_fire")
	var frames := int(seconds * 60.0)
	for i in frames:
		await get_tree().physics_frame
		if lob:
			# Wurfwaffe: kurz halten (schuetteln), loslassen, wieder halten.
			if i % 60 == 50:
				Input.action_release("p1_fire")
			elif i % 60 == 0:
				Input.action_press("p1_fire")
		p1.global_position = SHOOTER_POS
		p1.velocity = Vector2.ZERO
		p1.aim_dir = Vector2.RIGHT
		for k in _targets.size():
			if is_instance_valid(_targets[k]):
				_targets[k].global_position = _homes[k]
				_targets[k].velocity = Vector2.ZERO
				_targets[k].stunned_time = 0.0
	Input.action_release("p1_fire")
	p1.fired.disconnect(counter)
	if OS.get_environment("BENCH_DEBUG") != "":
		print("DBG ", id, " Ziele ", count, " Schuesse ", shots[0], " aim ", p1.aim_dir, " facing ", p1.facing, " ammo ", p1.ammo)
	var total := 0.0
	for e in _targets:
		total += HP - e.hp
	return total / seconds
