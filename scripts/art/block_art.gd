class_name BlockArt
extends Node2D
## Optik fuer feste Level-Bloecke: Boden, Waende, Decke und Laufstege.

var kind := "platform"
var size := Vector2(100, 24)

const STEEL_LIGHT := Color(0.62, 0.65, 0.74)
const STEEL_MID := Color(0.34, 0.37, 0.46)
const STEEL_DARK := Color(0.14, 0.15, 0.21)
const HAZARD_YELLOW := Color(0.95, 0.75, 0.12)
const HAZARD_BLACK := Color(0.1, 0.1, 0.13)


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	match kind:
		"floor":
			_floor(r)
		"wall":
			_wall(r)
		"ceiling":
			_ceiling(r)
		_:
			_platform(r)


func _hazard(rect: Rect2, stripe := 7.0) -> void:
	draw_rect(rect, HAZARD_YELLOW)
	var x := rect.position.x - rect.size.y
	while x < rect.position.x + rect.size.x:
		var p0 := Vector2(x, rect.position.y + rect.size.y)
		var points := PackedVector2Array([p0, p0 + Vector2(stripe, 0.0), p0 + Vector2(stripe + rect.size.y, -rect.size.y), p0 + Vector2(rect.size.y, -rect.size.y)])
		var clipped := PackedVector2Array()
		for point in points:
			clipped.append(Vector2(clampf(point.x, rect.position.x, rect.position.x + rect.size.x), point.y))
		draw_colored_polygon(clipped, HAZARD_BLACK)
		x += stripe * 2.0
	draw_rect(rect, Color(0, 0, 0, 0.5), false, 1.5)


func _floor(r: Rect2) -> void:
	Art.rrect_grad(self, r, Color(0.22, 0.24, 0.32), Color(0.1, 0.11, 0.16), 0.0)
	# Obere Kante.
	Art.rrect_grad(self, Rect2(r.position, Vector2(r.size.x, 9)), STEEL_LIGHT, STEEL_MID, 0.0)
	draw_line(r.position + Vector2(0, 1), r.position + Vector2(r.size.x, 1), Color(1, 1, 1, 0.5), 1.5)
	_hazard(Rect2(r.position + Vector2(0, 9), Vector2(r.size.x, 9)), 9.0)
	# Platten, Nieten, Lueftungsgitter.
	var x := r.position.x
	while x < r.position.x + r.size.x:
		draw_line(Vector2(x, r.position.y + 18), Vector2(x, r.end.y), Color(0, 0, 0, 0.45), 2.0)
		draw_line(Vector2(x + 2, r.position.y + 18), Vector2(x + 2, r.end.y), Color(1, 1, 1, 0.06), 1.0)
		for k in 3:
			Art.rivet(self, Vector2(x + 14.0 + k * 62.0, r.position.y + 28.0))
		if int(x / 200.0) % 3 == 1:
			for k in 5:
				draw_line(Vector2(x + 40, r.position.y + 46 + k * 7), Vector2(x + 150, r.position.y + 46 + k * 7), Color(0, 0, 0, 0.5), 3.0)
		x += 200.0


func _wall(r: Rect2) -> void:
	Art.rrect_grad(self, r, Color(0.26, 0.28, 0.37), Color(0.16, 0.17, 0.24), 0.0)
	# Senkrechte Highlights an den Kanten.
	draw_line(r.position + Vector2(1.5, 0), r.position + Vector2(1.5, r.size.y), Color(1, 1, 1, 0.25), 2.0)
	draw_line(r.position + Vector2(r.size.x - 1.5, 0), r.position + Vector2(r.size.x - 1.5, r.size.y), Color(0, 0, 0, 0.5), 2.0)
	var y := r.position.y + 40.0
	while y < r.end.y - 10.0:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0, 0, 0, 0.45), 2.0)
		draw_line(Vector2(r.position.x, y + 2), Vector2(r.end.x, y + 2), Color(1, 1, 1, 0.07), 1.0)
		for k in 2:
			Art.rivet(self, Vector2(r.position.x + 7.0 + k * (r.size.x - 14.0), y + 8.0))
		if int(y / 90.0) % 4 == 0 and r.size.x >= 30.0:
			_hazard(Rect2(Vector2(r.position.x + 4, y + 14), Vector2(r.size.x - 8, 8)), 6.0)
		y += 90.0
	# Kappe oben.
	if r.size.y < 1500.0:
		Art.rrect_grad(self, Rect2(r.position + Vector2(-2, -3), Vector2(r.size.x + 4, 10)), STEEL_LIGHT, STEEL_MID, 2.0)


func _ceiling(r: Rect2) -> void:
	Art.rrect_grad(self, r, Color(0.14, 0.15, 0.21), Color(0.06, 0.06, 0.09), 0.0)
	draw_line(r.position + Vector2(0, r.size.y - 1), r.position + Vector2(r.size.x, r.size.y - 1), Color(1, 1, 1, 0.15), 2.0)


func _platform(r: Rect2) -> void:
	var w := r.size.x
	# Stuetzen unter dem Steg.
	var strut_x := [r.position.x + 14.0, r.position.x + w - 14.0]
	if w > 360.0:
		strut_x.append(r.position.x + w * 0.5)
	for sx in strut_x:
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 10, r.end.y), Vector2(sx + 10, r.end.y), Vector2(sx, r.end.y + 26)]), Color(0.14, 0.15, 0.21))
		draw_line(Vector2(sx, r.end.y), Vector2(sx, r.end.y + 26), Color(0.4, 0.43, 0.52), 1.5)
	# Gitterrost und Deckplatte.
	draw_rect(Rect2(r.position + Vector2(0, 7), Vector2(w, r.size.y - 7)), Color(0.1, 0.11, 0.15))
	var x := r.position.x + 4.0
	while x < r.position.x + w - 4.0:
		draw_line(Vector2(x, r.position.y + 8), Vector2(x + 5, r.end.y - 1), Color(0.32, 0.35, 0.44, 0.7), 1.5)
		x += 8.0
	Art.rrect_grad(self, Rect2(r.position, Vector2(w, 8)), STEEL_LIGHT, STEEL_MID, 2.0)
	draw_line(r.position + Vector2(3, 1.5), r.position + Vector2(w - 3, 1.5), Color(1, 1, 1, 0.55), 1.5)
	draw_rect(Rect2(r.position, Vector2(w, r.size.y)), Color(0, 0, 0, 0.5), false, 1.5)
	# Warnstreifen und Lampen an den Enden.
	for side in [0, 1]:
		var cap := Rect2(r.position + Vector2(0.0 if side == 0 else w - 16.0, 8), Vector2(16, r.size.y - 8))
		_hazard(cap, 5.0)
		Art.led(self, Vector2(cap.position.x + 8.0, r.position.y - 3.0), 2.0, Color(1.0, 0.7, 0.2), true)
