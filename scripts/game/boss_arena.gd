class_name BossArena
extends Node2D
## Kampfplatz des Endbosses: Ein Laufband zieht alles auf dem Boden nach rechts auf den Boss zu. Vor ihm sitzt der Schredder:
## Wer hineingezogen wird, nimmt fetten Schaden (aber keinen Instakill) und wird zurueckgeschleudert. Hindernisse rollen
## von links aufs Band und fahren auf den Boss zu, dazu kommen Lasten von der Decke. Es gibt keine Plattformen:
## Man muss gegen das Band anlaufen, ausweichen und dabei den Boss beschiessen. Das Band wird mit der Zeit etwas schneller.

const FLOOR_Y := 1250.0
const ARENA_WIDTH := 3200.0
const BOSS_POSITION := Vector2(2960.0, FLOOR_Y)
const BOSS_WALL_X := 2740.0
## Schredder vor dem Boss: Streifen direkt an der Wand, in dem man gefressen wird.
const MAW_WIDTH := 80.0
const MAW_DAMAGE := 40.0
## Hindernisse rollen etwas schneller als das Band, damit sie die Spieler erreichen.
const OBSTACLE_BOOST := 140.0
## So weit links vom linkesten Spieler rollen neue Hindernisse ein (ausserhalb des Bildes).
const SPAWN_AHEAD := 1000.0
## Das Band wird von selbst schneller: Zuwachs pro Sekunde und Obergrenze (zusaetzlich zu den Phasen).
const BELT_CREEP := 0.25
const BELT_CREEP_MAX := 25.0

var main: Node
var players: Array[Player] = []
var boss: Boss
## Grundtempo der Phase (setzt der Boss) und das aktuelle Tempo inklusive Zuwachs.
var base_speed := 100.0
var belt_speed := 100.0
var running := true

var _time := 0.0
var _belt_offset := 0.0
var _creep := 0.0
var _maw_flash := 0.0


func setup(new_main: Node, new_players: Array[Player]) -> void:
	main = new_main
	players = new_players
	boss = Boss.new()
	boss.arena = self
	boss.main = new_main
	boss.position = BOSS_POSITION
	add_child(boss)


func _ready() -> void:
	z_index = 1
	z_as_relative = false


## Ein Hindernis rollt links ausserhalb des Bildes aufs Band.
func spawn_obstacle(kind: String) -> void:
	var obstacle := BeltObstacle.new()
	obstacle.kind = kind
	obstacle.speed = belt_speed + OBSTACLE_BOOST
	obstacle.damage = 20.0 * Boss.damage_scale()
	obstacle.players = players
	obstacle.end_x = BOSS_WALL_X - 30.0
	obstacle.position.x = _spawn_x()
	add_child(obstacle)
	Sfx.play("telegraph")


## Eine Last faellt an der Stelle x von der Decke aufs Band.
func spawn_drop(x: float) -> void:
	var drop := BeltObstacle.new()
	drop.kind = "drop"
	drop.speed = belt_speed + OBSTACLE_BOOST * 0.6
	drop.damage = 20.0 * Boss.damage_scale()
	drop.players = players
	drop.end_x = BOSS_WALL_X - 30.0
	drop.position.x = clampf(x, 120.0, BOSS_WALL_X - 140.0)
	add_child(drop)
	Sfx.play("telegraph")


func _spawn_x() -> float:
	var leftmost := BOSS_WALL_X
	for player in players:
		if not player.downed:
			leftmost = minf(leftmost, player.global_position.x)
	return maxf(60.0, leftmost - SPAWN_AHEAD)


func clear_obstacles() -> void:
	for obstacle in get_tree().get_nodes_in_group("belt_obstacles"):
		obstacle.queue_free()


## Schredder vor dem Boss in Weltkoordinaten (Streifen an der Wand ueber die ganze Bandhoehe).
func maw_zone() -> Rect2:
	return Rect2(BOSS_WALL_X - MAW_WIDTH, FLOOR_Y - 400.0, MAW_WIDTH + 20.0, 400.0)


func _physics_process(delta: float) -> void:
	_time += delta
	_maw_flash = maxf(0.0, _maw_flash - delta * 2.0)
	if running:
		# Das Band wird mit der Zeit schneller (ab dem Auftritt des Bosses, nicht uebertrieben).
		if boss != null and not boss.is_invulnerable():
			_creep = minf(BELT_CREEP_MAX, _creep + BELT_CREEP * delta)
		belt_speed = base_speed + _creep
		_belt_offset = fposmod(_belt_offset + belt_speed * delta, 48.0)
	for player in players:
		var feet := player.global_position.y + float(player.stats.size.y) * 0.5
		var on_belt := running and feet >= FLOOR_Y - 6.0
		player.belt_push = belt_speed if on_belt else 0.0
		if player.downed or not running:
			continue
		# Schredder: fetter Schaden, kein Instakill, danach fliegt man zurueck.
		var body := Rect2(player.global_position - player.stats.size * 0.5, player.stats.size)
		if body.intersects(maw_zone()):
			var scale := Boss.damage_scale() / Boss.DAMAGE_SCALE
			if player.take_hit(MAW_DAMAGE * scale, Vector2(BOSS_WALL_X + 60.0, FLOOR_Y - 60.0)):
				player.velocity = Vector2(-560.0, -520.0)
				_maw_flash = 1.0
				Sfx.play("explosion", 0.1)
				if Fx.instance:
					Fx.instance.explosion(Vector2(BOSS_WALL_X - 30.0, FLOOR_Y - 60.0), 90.0, Color(1.0, 0.5, 0.2))
				if main != null and "camera" in main and main.camera != null:
					main.camera.add_shake(12.0)
	queue_redraw()


func _exit_tree() -> void:
	for player in players:
		if is_instance_valid(player):
			player.belt_push = 0.0


# ---------------------------------------------------------------- Zeichnen

func _draw() -> void:
	_draw_belt()
	_draw_maw()


func _draw_belt() -> void:
	var rect := Rect2(0.0, FLOOR_Y, BOSS_WALL_X + 40.0, 22.0)
	draw_rect(rect, Color(0.07, 0.07, 0.1))
	var x := rect.position.x + _belt_offset - 48.0
	while x < rect.end.x - 20.0:
		var p := Vector2(x, rect.position.y + 3.0)
		# Pfeile zeigen nach rechts, zum Boss.
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, 0), p + Vector2(14, 8), p + Vector2(0, 16), p + Vector2(4, 8)]), Color(0.95, 0.75, 0.12, 0.9 if running else 0.3))
		x += 48.0
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(0.7, 0.72, 0.8), 2.0)
	draw_line(Vector2(rect.position.x, rect.end.y), rect.end, Color(0.25, 0.27, 0.35), 3.0)


## Schredder vor dem Boss: zwei gegenlaeufige Zahnwalzen in einem Schacht, glutrot beim Fressen.
func _draw_maw() -> void:
	var zone := maw_zone()
	var shaft := Rect2(BOSS_WALL_X - 125.0, FLOOR_Y - 150.0, 130.0, 150.0)
	Art.panel(self, shaft, Color(0.1, 0.09, 0.12), 6.0, Color(0.95, 0.75, 0.12, 0.8))
	Art.glow(self, shaft.get_center(), 120.0 + 60.0 * _maw_flash, Color(1.0, 0.35, 0.1))
	for k in 2:
		var center := Vector2(shaft.position.x + 36.0 + k * 58.0, FLOOR_Y - 76.0)
		var direction := 1.0 if k == 0 else -1.0
		var points := PackedVector2Array()
		var teeth := 9
		for i in teeth * 2:
			var a := _time * 4.0 * direction + i * PI / teeth
			points.append(center + Vector2(cos(a), sin(a)) * (34.0 if i % 2 == 0 else 24.0))
		draw_colored_polygon(points, Color(0.55, 0.58, 0.68))
		draw_polyline(points + PackedVector2Array([points[0]]), Art.OUTLINE, 2.0, true)
		Art.disc(self, center, 9.0, Color(0.2, 0.2, 0.26))
	# Warnstreifen ueber dem Schacht und Schild.
	draw_rect(Rect2(shaft.position.x - 6.0, shaft.position.y - 16.0, shaft.size.x + 12.0, 14.0), Color(0.95, 0.75, 0.12))
	for i in 8:
		draw_rect(Rect2(shaft.position.x + i * 17.0, shaft.position.y - 16.0, 8.0, 14.0), Color(0.1, 0.1, 0.13))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(shaft.position.x, shaft.position.y - 24.0), "SCHREDDER", HORIZONTAL_ALIGNMENT_CENTER, shaft.size.x, 18, Color(1.0, 0.8, 0.3))
	if running and (zone.size.x > 0.0):
		# Gefahrenstreifen am Boden vor dem Schacht.
		for i in 5:
			var alpha := 0.35 + 0.25 * sin(_time * 6.0 + i)
			draw_rect(Rect2(zone.position.x + i * 16.0, FLOOR_Y - 8.0, 8.0, 8.0), Color(1.0, 0.3, 0.2, alpha))
