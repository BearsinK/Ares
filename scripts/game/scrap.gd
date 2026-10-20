class_name Scrap
extends Node2D
## Schrott zerstoerter Gegner (Mutter, Schraube, Zahnrad, Blech). Bleibt auf dem Boden liegen
## und wird nur vom Roomba aufgesaugt (Klassenwert "vacuum"), im Wirbel aus groesserer Entfernung.

signal collected(scrap: Scrap, player: Player)

const GRAVITY := 1700.0
const LIFETIME := 28.0
const VACUUM_RADIUS := 95.0
const VORTEX_RADIUS := 260.0
const COLLECT_RADIUS := 26.0

var players: Array[Player] = []
var floor_y := 1250.0
var kind := "scrap"
var variant := 0
var tint := Color(0.7, 0.72, 0.8)
var velocity := Vector2.ZERO

var _age := 0.0
var _rot := 0.0
var _sucked := false
var _phase := 0.0


func _ready() -> void:
	add_to_group("scrap")
	z_index = -1
	variant = randi() % 4
	_rot = randf() * TAU
	_phase = randf() * TAU
	velocity = Vector2(randf_range(-140.0, 140.0), randf_range(-300.0, -160.0))


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	var vacuum := _vacuum_player()
	if vacuum != null and _age > 0.25:
		_sucked = true
		var goal := vacuum.global_position + Vector2(float(vacuum.facing) * 24.0, 8.0)
		velocity = velocity.move_toward((goal - global_position).normalized() * 700.0, 5000.0 * delta)
		_rot += delta * 18.0
		if global_position.distance_to(goal) <= COLLECT_RADIUS + 10.0:
			collected.emit(self, vacuum)
			queue_free()
			return
	else:
		_sucked = false
		velocity.y += GRAVITY * delta
	position += velocity * delta
	if not _sucked and position.y > floor_y - 5.0:
		position.y = floor_y - 5.0
		velocity.y = -velocity.y * 0.3
		velocity.x *= 0.55
		if absf(velocity.y) < 40.0:
			velocity = Vector2.ZERO
		_rot += velocity.x * delta * 0.05
	queue_redraw()


## Naechster lebender Spieler mit Staubsauger in Reichweite (im Wirbel weiter).
func _vacuum_player() -> Player:
	var best: Player = null
	var best_distance := INF
	for player in players:
		if player.downed or not bool(player.stats.get("vacuum", false)):
			continue
		var radius := VORTEX_RADIUS if player.ability.is_active("suck") else VACUUM_RADIUS * (1.0 + 0.5 * float(player.mods.pickup))
		var distance := global_position.distance_to(player.global_position)
		if distance <= radius and distance < best_distance:
			best = player
			best_distance = distance
	return best


func _draw() -> void:
	var fade := 1.0 if _age < LIFETIME - 4.0 else (0.35 + 0.65 * absf(sin(_age * 9.0)))
	var steel := Color(0.72, 0.75, 0.84, fade)
	var dark := Color(0.2, 0.21, 0.27, fade)
	var axis := Vector2(cos(_rot), sin(_rot))
	var side := axis.orthogonal()
	match variant:
		0:
			# Sechskantmutter mit Loch.
			var points := PackedVector2Array()
			for k in 6:
				var a := _rot + k * TAU / 6.0
				points.append(Vector2(cos(a), sin(a)) * 7.0)
			draw_colored_polygon(points, steel)
			points.append(points[0])
			draw_polyline(points, dark, 1.5, true)
			draw_circle(Vector2.ZERO, 2.6, dark)
		1:
			# Schraube: Kopf und Schaft.
			draw_line(-axis * 8.0, axis * 8.0, dark, 5.0, true)
			draw_line(-axis * 8.0, axis * 8.0, steel, 3.0, true)
			draw_line(axis * 6.0 + side * 3.5, axis * 6.0 - side * 3.5, dark, 3.0, true)
		2:
			# Zahnrad.
			for k in 8:
				var a := _rot + k * TAU / 8.0
				draw_line(Vector2(cos(a), sin(a)) * 5.0, Vector2(cos(a), sin(a)) * 8.0, steel, 3.0, true)
			draw_circle(Vector2.ZERO, 6.0, steel)
			draw_circle(Vector2.ZERO, 2.2, dark)
		_:
			# Blechstueck in Gegnerfarbe.
			var points := PackedVector2Array([axis * 8.0 + side * 4.5, -axis * 8.0 + side * 4.5, -axis * 8.0 - side * 4.5, axis * 8.0 - side * 4.5])
			draw_colored_polygon(points, Color(tint, fade))
			points.append(points[0])
			draw_polyline(points, dark, 1.5, true)
			draw_circle(axis * 4.0, 1.2, steel)
	# Glanz, damit man den Schrott im Staub sieht.
	if not _sucked and sin(_age * 3.0 + _phase) > 0.93:
		draw_line(Vector2(-6, -8), Vector2(6, -8), Color(1, 1, 1, 0.8 * fade), 1.5)
		draw_line(Vector2(0, -13), Vector2(0, -3), Color(1, 1, 1, 0.8 * fade), 1.5)
