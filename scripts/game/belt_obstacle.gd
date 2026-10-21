class_name BeltObstacle
extends Node2D
## Hindernis auf dem Laufband des Endbosses. Es rollt mit dem Band nach rechts auf den Boss zu (der Schredder vor ihm
## frisst alles) und verletzt Spieler, die es beruehren.
##   crate: niedrige Kiste, drueberspringen
##   stack: zwei Kisten, hoeher springen
##   beam: haengender Traeger (nur der untere Block trifft), darunter durchlaufen oder hoch genug drueberspringen
##   saw: rollende Saege, drueberspringen, etwas schneller als die anderen
##   drop: Last von der Decke. Ein Warnstreifen zeigt kurz vorher, wo sie einschlaegt, dann faellt sie und trifft hart.
##   Danach rollt sie als Kiste weiter zum Boss.

const FLOOR_Y := 1250.0
const BEAM_GAP := 135.0
const BEAM_THICKNESS := 38.0
## Frisch eingerollte Hindernisse sind kurz harmlos (Reaktionszeit).
const SAFE_TIME := 0.6
## Abwurf: Hoehe ueber dem Band, Warnzeit bis zum Fall, Fallbeschleunigung und Schadensfaktor beim Einschlag.
const DROP_HEIGHT := 1000.0
const DROP_WARN := 0.9
const DROP_GRAVITY := 2600.0
const DROP_DAMAGE := 1.5

var kind := "crate"
var speed := 120.0
var damage := 30.0
var players: Array[Player] = []
## Ab dieser x-Position frisst der Schredder das Hindernis.
var end_x := 2700.0

var _age := 0.0
var _rect := Rect2()
var _falling := false
var _fall_speed := 0.0
var _landed_time := 0.0


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
		"drop":
			_rect = Rect2(-40.0, -80.0, 80.0, 80.0)
			_falling = true
	position.y = FLOOR_Y - (DROP_HEIGHT if kind == "drop" else 0.0)
	add_to_group("belt_obstacles")


## Kollisionsrechteck in Weltkoordinaten.
func world_rect() -> Rect2:
	return Rect2(global_position + _rect.position, _rect.size)


## True, solange die Last noch fliegt (Warnung und Fall).
func is_falling() -> bool:
	return _falling


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if kind == "drop" and _falling:
		_update_fall(delta)
		return
	_landed_time += delta
	# Gelandete Lasten bleiben einen Moment liegen, bevor das Band sie mitnimmt.
	if kind != "drop" or _landed_time > 0.35:
		position.x += speed * delta
	if position.x > end_x:
		if Fx.instance:
			Fx.instance.spark(global_position + Vector2(0.0, -30.0), Color(1.0, 0.6, 0.2), 14, 380.0)
		queue_free()
		return
	if kind != "drop" and _age < SAFE_TIME:
		return
	_hit_players(damage)


func _update_fall(delta: float) -> void:
	if _age < DROP_WARN:
		return
	_fall_speed += DROP_GRAVITY * delta
	position.y = minf(position.y + _fall_speed * delta, FLOOR_Y)
	_hit_players(damage * DROP_DAMAGE)
	if position.y >= FLOOR_Y:
		_falling = false
		_landed_time = 0.0
		Sfx.play("slam")
		var arena := get_parent()
		var main: Node = arena.main if arena != null and "main" in arena else null
		if main != null and "camera" in main and main.camera != null:
			main.camera.add_shake(8.0)
		if Fx.instance:
			Fx.instance.spark(global_position + Vector2(0.0, -6.0), Color(0.9, 0.8, 0.6), 12, 320.0)
			Fx.instance.ring(global_position + Vector2(0.0, -10.0), 90.0, Color(0.95, 0.75, 0.12))


func _hit_players(amount: float) -> void:
	var rect := world_rect()
	for player in players:
		if player.downed:
			continue
		var body := Rect2(player.global_position - player.stats.size * 0.5, player.stats.size)
		if rect.intersects(body):
			player.take_hit(amount, global_position)


func _draw() -> void:
	modulate.a = 0.45 if (kind != "drop" and _age < SAFE_TIME) else 1.0
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
		"drop":
			_draw_drop()


## Abwurf: Warnstreifen auf dem Band, Lichtsaeule bis zur Last, die Last selbst als schwere Kiste mit Haken.
func _draw_drop() -> void:
	if _falling:
		var floor_local := FLOOR_Y - position.y
		var blink := 0.55 + 0.45 * sin(_age * 18.0)
		var warn := Rect2(-52.0, floor_local - 14.0, 104.0, 14.0)
		draw_rect(warn, Color(0.95, 0.75, 0.12, 0.85 * blink))
		for i in 6:
			draw_rect(Rect2(warn.position + Vector2(i * 18.0 + 4.0, 0), Vector2(8, 14)), Color(0.1, 0.1, 0.13, 0.9 * blink))
		draw_rect(Rect2(-40.0, -80.0, 80.0, floor_local + 80.0), Color(1.0, 0.3, 0.2, 0.06 + 0.06 * blink))
		draw_line(Vector2(-40.0, floor_local), Vector2(-40.0, -80.0), Color(1.0, 0.4, 0.3, 0.25 * blink), 2.0)
		draw_line(Vector2(40.0, floor_local), Vector2(40.0, -80.0), Color(1.0, 0.4, 0.3, 0.25 * blink), 2.0)
	var rect := Rect2(-40.0, -80.0, 80.0, 80.0)
	Art.panel(self, rect, Color(0.34, 0.36, 0.44), 5.0)
	Art.rrect_line(self, rect.grow(-8.0), Color(0, 0, 0, 0.4), 2.0, 2.0)
	for i in 4:
		draw_rect(Rect2(rect.position + Vector2(6.0 + i * 18.0, 62.0), Vector2(9, 12)), Color(0.95, 0.75, 0.12))
	draw_rect(Rect2(rect.position + Vector2(0.0, 52.0), Vector2(80.0, 5.0)), Color(0.1, 0.1, 0.13))
	draw_arc(Vector2(0.0, -86.0), 12.0, PI, TAU, 10, Color(0.6, 0.62, 0.7), 4.0, true)
	for corner in [rect.position + Vector2(8, 8), rect.position + Vector2(72, 8)]:
		Art.rivet(self, corner, 2.5)
	Art.led(self, Vector2(0.0, -40.0), 5.0, Color(1.0, 0.3, 0.2), fmod(_age, 0.5) < 0.25)


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
