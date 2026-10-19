class_name Director
extends Node
## Laesst Gegner nach und nach erscheinen (wie in Risk of Rain): Ein Punktekonto
## fuellt sich ueber die Zeit, jeder Gegnertyp kostet Punkte. Die Schwierigkeit
## steigt mit der Zeit kontinuierlich. Eine Obergrenze verhindert Ueberlastung.

signal enemy_spawned(enemy: Enemy)
signal projectile_requested(enemy: Enemy, origin: Vector2, direction: Vector2, speed: float, damage: float)

const SPAWN_INTERVAL := 0.35
const MIN_SPAWN_DISTANCE := 500.0

var enabled := true
var arena_size := Vector2(3200.0, 1350.0)
var floor_y := 1250.0
var players: Array[Player] = []
var enemies: Array[Enemy] = []
var parent_node: Node = null
var time := 0.0

var _credits := 4.0
var _spawn_timer := 1.0


func current_cap() -> int:
	return mini(30 + int(time / 5.0), 200)


func hp_scale() -> float:
	return 1.0 + time / 120.0


func damage_scale() -> float:
	return 1.0 + time / 300.0


func alive_count() -> int:
	return enemies.size()


func _physics_process(delta: float) -> void:
	enemies = enemies.filter(func(e: Enemy) -> bool: return is_instance_valid(e) and not e.is_queued_for_deletion())
	if not enabled:
		return
	time += delta
	_credits += (1.2 + time / 45.0) * delta
	_spawn_timer -= delta
	if _spawn_timer > 0.0 or enemies.size() >= current_cap():
		return
	var kind := _choose_kind()
	if kind == "":
		return
	_spawn_timer = SPAWN_INTERVAL
	_credits -= float(EnemyTypes.get_type(kind).cost)
	spawn(kind)


func _choose_kind() -> String:
	var options: Array[String] = []
	var weights: Array[float] = []
	for kind in EnemyTypes.DATA:
		var info: Dictionary = EnemyTypes.DATA[kind]
		if time >= float(info.from_time) and _credits >= float(info.cost):
			options.append(kind)
			# Billige Gegner sind haeufiger.
			weights.append(1.0 / float(info.cost))
	if options.is_empty():
		return ""
	var total := 0.0
	for weight in weights:
		total += weight
	var roll := randf() * total
	for i in options.size():
		roll -= weights[i]
		if roll <= 0.0:
			return options[i]
	return options[0]


func spawn(kind: String, at: Variant = null) -> Enemy:
	var enemy := Enemy.new()
	enemy.setup(kind, hp_scale(), damage_scale(), players)
	enemy.siblings = enemies
	enemy.position = at if at != null else _spawn_position(kind)
	enemy.fire_projectile.connect(projectile_requested.emit)
	enemies.append(enemy)
	parent_node.add_child(enemy)
	enemy_spawned.emit(enemy)
	return enemy


func _spawn_position(kind: String) -> Vector2:
	var info := EnemyTypes.get_type(kind)
	# Gegner erscheinen in einiger Entfernung zu einem zufaelligen Spieler, damit
	# der Kampf schnell beginnt und sie nicht ueber die ganze Arena laufen muessen.
	var anchor := players[randi() % players.size()].global_position
	var side := 1.0 if randf() < 0.5 else -1.0
	var x := clampf(anchor.x + side * randf_range(700.0, 1000.0), 90.0, arena_size.x - 90.0)
	for player in players:
		if absf(player.global_position.x - x) < MIN_SPAWN_DISTANCE:
			x = clampf(anchor.x - side * randf_range(700.0, 1000.0), 90.0, arena_size.x - 90.0)
			break
	if info.movement == "fly":
		return Vector2(x, randf_range(250.0, 800.0))
	return Vector2(x, floor_y - float(info.radius) - 4.0)
