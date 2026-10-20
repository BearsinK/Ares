class_name BeltObstacle
extends Node2D
## Hindernis auf dem Laufband des Endbosses. Es wandert mit dem Band nach links
## Richtung Ofen und verletzt Spieler, die es beruehren.
##   crate: niedrige Kiste, drueberspringen
##   stack: zwei Kisten, hoeher springen oder ueber eine Plattform ausweichen
##   beam: haengender Traeger (nur der untere Block trifft), darunter durchlaufen. Plattformen
##   darueber bleiben sicher, hoch genug Springende kommen ebenfalls drueber
##   saw: rollende Saege, drueberspringen, etwas schneller als das Band

const FLOOR_Y := 1250.0
const BEAM_GAP := 135.0
const BEAM_THICKNESS := 38.0
const DESPAWN_X := 215.0
## Frisch aus der Luke gerollte Hindernisse sind kurz harmlos (Reaktionszeit direkt an der Luke).
const SAFE_TIME := 0.6

var kind := "crate"
var speed := 120.0
var damage := 30.0
var players: Array[Player] = []

var _age := 0.0
var _rect := Rect2()


func _ready() -> void:
	z_index = 2
	z_as_relative = false
	match kind:
		"crate":
			_rect = Rect2(-36.0, -72.0, 72.0, 72.0)
		"stack":
			_rect = Rect2(-36.0, -144.0, 72.0, 144.0)
		"beam":
			_rect = Rect2(-55.0, -BEAM_GAP - BEAM_THICKNESS, 110.0, BEAM_THICKNESS)
		"saw":
			_rect = Rect2(-44.0, -88.0, 88.0, 88.0)
			speed *= 1.35
	position.y = FLOOR_Y
	add_to_group("belt_obstacles")


## Kollisionsrechteck in Weltkoordinaten.
func world_rect() -> Rect2:
	return Rect2(global_position + _rect.position, _rect.size)


func _physics_process(delta: float) -> void:
	_age += delta
	position.x -= speed * delta
	if position.x < DESPAWN_X:
		if Fx.instance:
			Fx.instance.spark(global_position + Vector2(0.0, -30.0), Color(1.0, 0.6, 0.2), 14, 380.0)
		queue_free()
		return
	if _age < SAFE_TIME:
		return
	var rect := world_rect()
	for player in players:
		if player.downed:
			continue
		var body := Rect2(player.global_position - player.stats.size * 0.5, player.stats.size)
		if rect.intersects(body):
			player.take_hit(damage, global_position)
	queue_redraw()


func _draw() -> void:
	modulate.a = 0.45 if _age < SAFE_TIME else 1.0
	match kind:
		"crate":
			_draw_crate(Vector2(0.0, 0.0), 72.0)
		"stack":
			_draw_crate(Vector2(0.0, 0.0), 72.0)
			_draw_crate(Vector2(0.0, -72.0), 72.0)
		"beam":
			_draw_beam()
		"saw":
			_draw_saw()


func _draw_crate(bottom: Vector2, size: float) -> void:
	var rect := Rect2(bottom - Vector2(size * 0.5, size), Vector2(size, size))
	Art.panel(self, rect, Color(0.6, 0.42, 0.22), 4.0)
	Art.rrect_line(self, rect.grow(-7.0), Color(0, 0, 0, 0.4), 2.0, 2.0)
	draw_line(rect.position + Vector2(7, 7), rect.end - Vector2(7, 7), Color(0, 0, 0, 0.35), 4.0)
	draw_line(rect.position + Vector2(size - 7, 7), rect.position + Vector2(7, size - 7), Color(0, 0, 0, 0.35), 4.0)
	for corner in [rect.position + Vector2(6, 6), rect.position + Vector2(size - 6, 6), rect.position + Vector2(6, size - 6), rect.end - Vector2(6, 6)]:
		Art.rivet(self, corner, 2.0)
	# Warnstreifen oben, damit man sie gut sieht.
	draw_rect(Rect2(rect.position, Vector2(size, 8)), Color(0.95, 0.75, 0.12))
	for i in 5:
		draw_rect(Rect2(rect.position + Vector2(i * 16.0 + 4.0, 0), Vector2(7, 8)), Color(0.1, 0.1, 0.13))


func _draw_beam() -> void:
	var bottom := -BEAM_GAP
	var block := Rect2(-55.0, bottom - BEAM_THICKNESS, 110.0, BEAM_THICKNESS)
	# Ketten von der Decke.
	for x in [-34.0, 34.0]:
		var y := -FLOOR_Y
		while y < block.position.y:
			Art.disc(self, Vector2(x, y + 8.0), 6.0, Color(0.5, 0.52, 0.6), Art.OUTLINE)
			y += 16.0
	Art.panel(self, block, Color(0.4, 0.42, 0.52), 5.0)
	draw_rect(Rect2(block.position + Vector2(4, block.size.y - 11.0), Vector2(block.size.x - 8.0, 8.0)), Color(0.95, 0.75, 0.12))
	for i in 7:
		draw_rect(Rect2(block.position + Vector2(8.0 + i * 15.0, block.size.y - 11.0), Vector2(7, 8)), Color(0.1, 0.1, 0.13))
	for x in [-44.0, 44.0]:
		Art.rivet(self, Vector2(x, block.position.y + 10.0), 2.0)
	# Pfeil nach unten als Warnung.
	Art.led(self, Vector2(0.0, block.position.y + 18.0), 4.0, Color(1.0, 0.3, 0.2), fmod(_age, 0.6) < 0.3)


func _draw_saw() -> void:
	var center := Vector2(0.0, -44.0)
	Art.glow(self, center, 60.0, Color(1.0, 0.5, 0.3))
	var points := PackedVector2Array()
	var teeth := 14
	for i in teeth * 2:
		var a := _age * -9.0 + i * PI / teeth
		points.append(center + Vector2(cos(a), sin(a)) * (44.0 if i % 2 == 0 else 34.0))
	draw_colored_polygon(points, Color(0.72, 0.75, 0.84))
	draw_polyline(points + PackedVector2Array([points[0]]), Art.OUTLINE, 2.0, true)
	Art.disc(self, center, 12.0, Color(0.35, 0.38, 0.46))
	Art.disc(self, center, 4.0, Color(0.9, 0.3, 0.2))
