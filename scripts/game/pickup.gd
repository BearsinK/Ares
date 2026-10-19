class_name Pickup
extends Node2D
## Einsammelbares Objekt: XP (gehoert beiden) oder Gold (gehoert dem Spieler,
## der es aufnimmt). Faellt zu Boden und wird von Spielern in der Naehe angezogen.

signal collected(pickup: Pickup, player: Player)

const GRAVITY := 1600.0
const MAGNET_RADIUS := 240.0
const COLLECT_RADIUS := 24.0
const LIFETIME := 30.0

var kind := "xp"
var value := 1
var players: Array[Player] = []
var floor_y := 1250.0
var velocity := Vector2.ZERO
## Wird am Wellenende gesetzt: Das Objekt fliegt zum naechsten Spieler, egal wie weit.
var force_pull := false

var _age := 0.0
var _pulling := false


func _ready() -> void:
	velocity = Vector2(randf_range(-160.0, 160.0), randf_range(-420.0, -220.0))


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return

	var nearest: Player = null
	var best := INF
	for player in players:
		if player.downed:
			continue
		var distance := global_position.distance_to(player.global_position)
		if distance < best:
			best = distance
			nearest = player

	if nearest != null and _age > 0.3:
		var radius := MAGNET_RADIUS * (1.0 + float(nearest.mods.pickup))
		if best <= radius or force_pull:
			_pulling = true
		if _pulling:
			var direction := (nearest.global_position - global_position).normalized()
			velocity = velocity.move_toward(direction * 900.0, 4000.0 * delta)
		if best <= COLLECT_RADIUS:
			collected.emit(self, nearest)
			queue_free()
			return

	if not _pulling:
		velocity.y += GRAVITY * delta
	position += velocity * delta
	if position.y > floor_y - 8.0:
		position.y = floor_y - 8.0
		velocity.y = -velocity.y * 0.35
		velocity.x *= 0.6
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + 0.15 * sin(_age * 8.0)
	if kind == "gold":
		draw_circle(Vector2.ZERO, 8.0 * pulse, Color(1.0, 0.82, 0.25))
		draw_arc(Vector2.ZERO, 8.0 * pulse, 0.0, TAU, 16, Color(0.7, 0.5, 0.1), 2.0)
	else:
		var r := 7.0 * pulse
		var points := PackedVector2Array([Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])
		draw_colored_polygon(points, Color(0.4, 0.7, 1.0))
		draw_circle(Vector2.ZERO, r * 1.8, Color(0.4, 0.7, 1.0, 0.2))
