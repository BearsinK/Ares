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
## Der geschlossene Schacht rechts (x-Bereich inklusive Waende).
const SHAFT_LEFT := 2570.0
const SHAFT_RIGHT := 2910.0

var enabled := true
var arena_size := Vector2(3200.0, 1350.0)
var floor_y := 1250.0
## Layout der aktuellen Karte (siehe Stages). Leer = alte flache Halle.
var stage: Dictionary = {}
var players: Array[Player] = []
var enemies: Array[Enemy] = []
## Raster fuer die Abstandssuche der Gegner, wird jeden Frame neu gefuellt.
var grid := EnemyGrid.new()
var parent_node: Node = null
var time := 0.0
var wave := 1
var wave_progress := 0.0
## Modifikator der laufenden Welle (siehe WaveModifiers), leer = normal.
var modifier: Dictionary = {}

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
	return mini(int((20.0 + difficulty() * 4.5) * float(modifier.get("cap", 1.0))), 200)


## Anteil der Spawns, die als Elite erscheinen (ab ELITE_FROM, wachsend bis 15 Prozent).
func elite_chance() -> float:
	return clampf((0.04 + (unlock_time() - ELITE_FROM) / 1500.0) * float(modifier.get("elite", 1.0)), 0.0, 0.5)


func hp_scale() -> float:
	return (1.0 + difficulty() * 0.3) * float(modifier.get("hp", 1.0))


func damage_scale() -> float:
	return 1.0 + difficulty() * 0.12


## Neue Welle: die Punkte beginnen mit einem kleinen Startvorrat.
func start_wave(new_wave: int, new_modifier := {}) -> void:
	wave = new_wave
	modifier = new_modifier
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
	grid.rebuild(enemies)
	_update_visibility()
	if not enabled:
		return
	time += delta
	_credits += (0.8 + 0.45 * difficulty()) * float(modifier.get("credits", 1.0)) * delta
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


func _update_visibility() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var view: Rect2 = viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()
	view = view.grow(260.0)
	for enemy in enemies:
		enemy.on_screen = view.has_point(enemy.global_position)


func _choose_kind() -> String:
	var options: Array[String] = []
	var weights: Array[float] = []
	for kind in EnemyTypes.DATA:
		var info: Dictionary = EnemyTypes.DATA[kind]
		if unlock_time() >= float(info.from_time) and (not modifier.has("kinds") or (modifier.kinds as Array).has(kind)):
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


func spawn(kind: String, at: Variant = null, elite := false, elite_kind := "", champion := false) -> Enemy:
	var enemy := Enemy.new()
	enemy.setup(kind, hp_scale(), damage_scale(), players, elite, elite_kind, champion)
	enemy.siblings = enemies
	enemy.grid = grid
	enemy.stuck.connect(relocate)
	enemy.speed_mult = float(modifier.get("speed", 1.0))
	enemy.position = at if at != null else _spawn_position(kind)
	enemy.fire_projectile.connect(projectile_requested.emit)
	enemy.strike_requested.connect(strike_requested.emit)
	enemies.append(enemy)
	parent_node.add_child(enemy)
	enemy_spawned.emit(enemy)
	return enemy


func _spawn_position(kind: String) -> Vector2:
	var info := EnemyTypes.get_type(kind)
	if not stage.is_empty():
		return _stage_spawn_position(kind, info)
	# Gegner erscheinen in einiger Entfernung zu einem zufaelligen Spieler, damit
	# der Kampf schnell beginnt und sie nicht ueber die ganze Arena laufen muessen.
	var anchor := players[randi() % players.size()].global_position
	var side := 1.0 if randf() < 0.5 else -1.0
	var x := clampf(anchor.x + side * randf_range(700.0, 1000.0), 90.0, arena_size.x - 90.0)
	for player in players:
		if absf(player.global_position.x - x) < MIN_SPAWN_DISTANCE:
			x = clampf(anchor.x - side * randf_range(700.0, 1000.0), 90.0, arena_size.x - 90.0)
			break
	# Der Schacht rechts ist ringsum zu: dort darf niemand erscheinen.
	if x > SHAFT_LEFT and x < SHAFT_RIGHT:
		x = SHAFT_LEFT - 40.0 if anchor.x < (SHAFT_LEFT + SHAFT_RIGHT) * 0.5 else SHAFT_RIGHT + 40.0
	if info.movement == "fly":
		return Vector2(x, randf_range(250.0, 800.0))
	return Vector2(x, floor_y - float(info.radius) - 4.0)


## Auf grossen Karten: Bodengegner erscheinen auf begehbaren Flaechen auf aehnlicher Hoehe wie ein
## Spieler, ausserhalb des Bildes. Flieger in den Luftbereichen der Karte.
func _stage_spawn_position(kind: String, info: Dictionary) -> Vector2:
	var anchor: Vector2 = players[randi() % players.size()].global_position
	if info.movement == "fly":
		var options: Array[Vector2] = []
		for rect: Rect2 in stage.air:
			var point := Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y, rect.end.y))
			if point.distance_to(anchor) > 650.0 and point.distance_to(anchor) < 1800.0 and not Stages.point_in_terrain(stage, point):
				options.append(point)
		if options.is_empty():
			var fallback := anchor + Vector2(randf_range(-900.0, 900.0), -500.0)
			return fallback if not Stages.point_in_terrain(stage, fallback) else anchor + Vector2(0.0, -300.0)
		return options[randi() % options.size()]
	var best: Array[Vector2] = []
	var fallback: Array[Vector2] = []
	for point: Vector2 in stage.ground:
		var distance := point.distance_to(anchor)
		if distance < 600.0 or distance > 1900.0:
			continue
		var too_close := false
		for player in players:
			if player.global_position.distance_to(point) < MIN_SPAWN_DISTANCE:
				too_close = true
		if too_close:
			continue
		fallback.append(point)
		# Am liebsten auf der Ebene eines Spielers und nicht im Bild.
		if absf(point.y - anchor.y) < 260.0 and distance > 800.0:
			best.append(point)
	var pool: Array[Vector2] = best if not best.is_empty() else fallback
	if pool.is_empty():
		var points: Array = stage.ground
		var any: Vector2 = points[randi() % points.size()]
		return any + Vector2(0.0, -float(info.radius) - 4.0)
	return pool[randi() % pool.size()] + Vector2(0.0, -float(info.radius) - 4.0)


## Ein Gegner steckt unter einem Spieler auf einer anderen Ebene fest: er taucht auf der Ebene des Spielers wieder auf.
func relocate(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var pos := _spawn_position(enemy.kind)
	if Fx.instance:
		Fx.instance.spark(enemy.global_position, Color(0.7, 0.8, 1.0), 6, 200.0)
		Fx.instance.spark(pos, Color(0.7, 0.8, 1.0), 6, 200.0)
	enemy.global_position = pos
	enemy.velocity = Vector2.ZERO
