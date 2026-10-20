class_name RopeArt
extends Node2D
## Kletterseil: dicke Leine mit Klemmen, oben an einem Haken befestigt. Schwingt leicht.

var length := 400.0
var _phase := 0.0


func _ready() -> void:
	_phase = randf() * TAU
	z_index = -2


func _process(_delta: float) -> void:
	# Nur sichtbare Seile zeichnen sich neu.
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0 + _phase
	var points := PackedVector2Array()
	var segments := maxi(int(length / 40.0), 2)
	for i in segments + 1:
		var f := float(i) / float(segments)
		points.append(Vector2(sin(t * 1.4 + f * 3.0) * 3.0 * f, f * length))
	draw_polyline(points, Color(0.04, 0.04, 0.06), 7.0, true)
	draw_polyline(points, Color(0.5, 0.42, 0.28), 4.5, true)
	draw_polyline(points, Color(0.75, 0.68, 0.5, 0.6), 1.5, true)
	# Klemmen alle 70 Pixel.
	var y := 50.0
	while y < length - 10.0:
		var f := y / length
		var x := sin(t * 1.4 + f * 3.0) * 3.0 * f
		draw_rect(Rect2(x - 5.0, y, 10.0, 8.0), Color(0.95, 0.75, 0.12))
		draw_rect(Rect2(x - 5.0, y, 10.0, 8.0), Color(0, 0, 0, 0.5), false, 1.0)
		y += 70.0
	# Befestigung oben.
	draw_rect(Rect2(-11.0, -8.0, 22.0, 10.0), Color(0.34, 0.37, 0.46))
	draw_rect(Rect2(-11.0, -8.0, 22.0, 10.0), Color(0, 0, 0, 0.6), false, 1.5)
	Art.rivet(self, Vector2(-6.0, -3.0))
	Art.rivet(self, Vector2(6.0, -3.0))
