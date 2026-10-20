class_name BossArena
extends Node2D
## Kampfplatz des Endbosses: Ein Laufband zieht alles auf dem Boden nach links in
## den Verbrennungsofen. Der Boss steht rechts und schickt Hindernisse aufs Band.
## Plattformen sind vom Band getrennt und dienen als sicherer Weg.

const FLOOR_Y := 1250.0
const ARENA_WIDTH := 3200.0
const PIT_WIDTH := 200.0
const BURN_DAMAGE := 30.0
const BOSS_POSITION := Vector2(2960.0, FLOOR_Y)
const BOSS_WALL_X := 2740.0
const HATCH_X := 2740.0

var main: Node
var players: Array[Player] = []
var boss: Boss
var belt_speed := 100.0
var running := true

var _time := 0.0
var _belt_offset := 0.0
var _hatch_flash := 0.0


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


func spawn_obstacle(kind: String) -> void:
	var obstacle := BeltObstacle.new()
	obstacle.kind = kind
	obstacle.speed = belt_speed
	obstacle.damage = 20.0 * Boss.damage_scale()
	obstacle.players = players
	obstacle.position.x = HATCH_X
	add_child(obstacle)
	_hatch_flash = 0.4
	Sfx.play("telegraph")


func clear_obstacles() -> void:
	for obstacle in get_tree().get_nodes_in_group("belt_obstacles"):
		obstacle.queue_free()


func _physics_process(delta: float) -> void:
	_time += delta
	_hatch_flash = maxf(0.0, _hatch_flash - delta)
	if running:
		_belt_offset = fposmod(_belt_offset - belt_speed * delta, 48.0)
	for player in players:
		var feet := player.global_position.y + float(player.stats.size.y) * 0.5
		var on_belt := running and feet >= FLOOR_Y - 6.0 and player.global_position.x > PIT_WIDTH
		player.belt_push = -belt_speed if on_belt else 0.0
		if player.downed:
			continue
		# Der Ofen am linken Ende: wer hineinrutscht, verbrennt.
		var body := Rect2(player.global_position - player.stats.size * 0.5, player.stats.size)
		if body.intersects(burn_zone()):
			player.take_hit(BURN_DAMAGE * Boss.damage_scale() / 1.6, Vector2(0.0, FLOOR_Y))
	queue_redraw()


func burn_zone() -> Rect2:
	return Rect2(0.0, FLOOR_Y - 110.0, PIT_WIDTH, 300.0)


func _exit_tree() -> void:
	for player in players:
		if is_instance_valid(player):
			player.belt_push = 0.0


# ---------------------------------------------------------------- Zeichnen

func _draw() -> void:
	_draw_belt()
	_draw_hatch()
	_draw_incinerator()


func _draw_belt() -> void:
	var rect := Rect2(PIT_WIDTH, FLOOR_Y, ARENA_WIDTH - PIT_WIDTH, 22.0)
	draw_rect(rect, Color(0.07, 0.07, 0.1))
	var x := rect.position.x + _belt_offset
	while x < rect.end.x - 20.0:
		var p := Vector2(x, rect.position.y + 3.0)
		# Pfeile zeigen nach links, zum Ofen.
		draw_colored_polygon(PackedVector2Array([p + Vector2(14, 0), p + Vector2(0, 8), p + Vector2(14, 16), p + Vector2(10, 8)]), Color(0.95, 0.75, 0.12, 0.9 if running else 0.3))
		x += 48.0
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(0.7, 0.72, 0.8), 2.0)
	draw_line(Vector2(rect.position.x, rect.end.y), rect.end, Color(0.25, 0.27, 0.35), 3.0)


func _draw_hatch() -> void:
	# Luke am Boss, aus der die Hindernisse aufs Band rollen.
	var hatch := Rect2(HATCH_X + 30.0, FLOOR_Y - 160.0, 40.0, 160.0)
	Art.panel(self, hatch, Color(0.12, 0.12, 0.16), 4.0, Color(0.95, 0.75, 0.12, 0.8))
	if _hatch_flash > 0.0:
		Art.glow(self, hatch.get_center(), 90.0, Color(1.0, 0.4, 0.2))


func _draw_incinerator() -> void:
	var zone := Rect2(0.0, FLOOR_Y, PIT_WIDTH, 100.0)
	# Grube mit glutroter Wand.
	Art.rrect_grad(self, zone, Color(0.55, 0.12, 0.05), Color(1.0, 0.55, 0.1), 0.0)
	Art.glow(self, Vector2(PIT_WIDTH * 0.5, FLOOR_Y + 10.0), 260.0, Color(1.0, 0.4, 0.1))
	# Flammen: wabernde Zungen.
	for i in 9:
		var x := 8.0 + i * 23.0
		var phase := _time * 7.0 + i * 1.7
		var height := 90.0 + 40.0 * sin(phase) + 25.0 * sin(phase * 2.3 + i)
		var base_y := FLOOR_Y + 40.0
		var tongue := PackedVector2Array([
			Vector2(x - 13.0, base_y), Vector2(x - 8.0, base_y - height * 0.55),
			Vector2(x + sin(phase * 1.3) * 7.0, base_y - height), Vector2(x + 8.0, base_y - height * 0.5), Vector2(x + 13.0, base_y)])
		draw_colored_polygon(tongue, Color(1.0, 0.45, 0.1, 0.85))
		var inner := PackedVector2Array([
			Vector2(x - 6.0, base_y), Vector2(x, base_y - height * 0.6), Vector2(x + 6.0, base_y)])
		draw_colored_polygon(inner, Color(1.0, 0.9, 0.4, 0.9))
	# Einlass-Rahmen mit Warnstreifen und Schild.
	draw_rect(Rect2(0.0, FLOOR_Y - 120.0, PIT_WIDTH, 14.0), Color(0.95, 0.75, 0.12))
	for i in 12:
		draw_rect(Rect2(i * 18.0 + 4.0, FLOOR_Y - 120.0, 9.0, 14.0), Color(0.1, 0.1, 0.13))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0.0, FLOOR_Y - 130.0), "OFEN", HORIZONTAL_ALIGNMENT_CENTER, PIT_WIDTH, 22, Color(1.0, 0.8, 0.3))
