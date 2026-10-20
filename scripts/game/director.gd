class_name Director
extends Node
## Laesst Gegner nach und nach erscheinen (wie in Risk of Rain): Ein Punktekonto
## fuellt sich ueber die Zeit, jeder Gegnertyp kostet Punkte. Die Schwierigkeit
## steigt mit der Zeit kontinuierlich. Eine Obergrenze verhindert Ueberlastung.

signal enemy_spawned(enemy: Enemy)
signal projectile_requested(enemy: Enemy, origin: Vector2, direction: Vector2, speed: float, damage: float)
signal strike_requested(enemy: Enemy, position: Vector2, radius: float, delay: float, damage: float)

const SPAWN_INTERVAL := 0.35
const MIN_SPAWN_DISTANCE := 500.0
const ELITE_FROM := 60.0
const ELITE_COST_MULT := 3.0

var enabled := true
var arena_size := Vector2(3200.0, 1350.0)
var floor_y := 1250.0
var players: Array[Player] = []
var enemies: Array[Enemy] = []
var parent_node: Node = null
var time := 0.0
var wave := 1
var wave_progress := 0.0

var _credits := 4.0
var _spawn_timer := 1.0
var _next_kind := ""
var _next_elite := false


## Schwierigkeit: 0 am Anfang, waechst mit jeder Welle um 1 (innerhalb der Welle stetig).
func difficulty() -> float:
	return float(wave - 1) + clampf(wave_progress, 0.0, 1.0)


## Zeit-Aequivalent fuer das Freischalten von Gegnertypen (100 s pro Schwierigkeitsstufe).
func unlock_time() -> float:
	return difficulty() * 100.0


func current_cap() -> int:
	return mini(20 + int(difficulty() * 4.5), 200)


## Anteil der Spawns, die als Elite erscheinen (ab ELITE_FROM, wachsend bis 15 Prozent).
func elite_chance() -> float:
	return clampf(0.04 + (unlock_time() - ELITE_FROM) / 1500.0, 0.0, 0.15)


func hp_scale() -> float:
	return 1.0 + difficulty() * 0.3


func damage_scale() -> float:
	return 1.0 + difficulty() * 0.12


## Neue Welle: die Punkte beginnen mit einem kleinen Startvorrat.
func start_wave(new_wave: int) -> void:
	wave = new_wave
	wave_progress = 0.0
	_credits = 4.0
	_spawn_timer = 1.0
	_next_kind = ""


func alive_count() -> int:
	return enemies.size()


func _physics_process(delta: float) -> void:
	# In place, damit die Listen der Gegner (siblings) dieselbe Instanz behalten.
	for i in range(enemies.size() - 1, -1, -1):
		if not is_instance_valid(enemies[i]) or enemies[i].is_queued_for_deletion():
			enemies.remove_at(i)
	if not enabled:
		return
	time += delta
	_credits += (0.8 + 0.45 * difficulty()) * delta
	_spawn_timer -= delta
	if _spawn_timer > 0.0 or enemies.size() >= current_cap():
		return
	# Der naechste Typ wird vorab gewuerfelt und dann abgewartet, bis die Punkte reichen.
	# Sonst wuerden teure Typen nie erscheinen, weil billige die Punkte aufbrauchen.
	if _next_kind == "":
		_next_kind = _choose_kind()
		_next_elite = unlock_time() >= ELITE_FROM and randf() < elite_chance()
	var cost := float(EnemyTypes.get_type(_next_kind).cost) * (ELITE_COST_MULT if _next_elite else 1.0)
	if cost > _credits:
		return
	_spawn_timer = SPAWN_INTERVAL
	_credits -= cost
	var kind := _next_kind
	var elite := _next_elite
	_next_kind = ""
	spawn(kind, null, elite)


func _choose_kind() -> String:
	var options: Array[String] = []
	var weights: Array[float] = []
	for kind in EnemyTypes.DATA:
		var info: Dictionary = EnemyTypes.DATA[kind]
		if unlock_time() >= float(info.from_time):
			options.append(kind)
			# Billige Gegner sind haeufiger.
			weights.append(1.0 / float(info.cost))
	var total := 0.0
	for weight in weights:
		total += weight
	var roll := randf() * total
	for i in options.size():
		roll -= weights[i]
		if roll <= 0.0:
			return options[i]
	return options[0]


func spawn(kind: String, at: Variant = null, elite := false, elite_kind := "") -> Enemy:
	var enemy := Enemy.new()
	enemy.setup(kind, hp_scale(), damage_scale(), players, elite, elite_kind)
	enemy.siblings = enemies
	enemy.position = at if at != null else _spawn_position(kind)
	enemy.fire_projectile.connect(projectile_requested.emit)
	enemy.strike_requested.connect(strike_requested.emit)
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
