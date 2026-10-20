class_name Vignette
extends CanvasLayer
## Dunkle Raender fuer Atmosphaere, liegt ueber der Spielwelt und unter dem HUD.

var _canvas: Node2D


func _ready() -> void:
	layer = 5
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_vignette)
	add_child(_canvas)


func _draw_vignette() -> void:
	var view := _canvas.get_viewport_rect().size
	var strong := Color(0.02, 0.02, 0.05, 0.6)
	var none := Color(0.02, 0.02, 0.05, 0.0)
	var edge := 260.0
	# Oben, unten, links, rechts.
	_band(PackedVector2Array([Vector2(0, 0), Vector2(view.x, 0), Vector2(view.x, edge), Vector2(0, edge)]), [strong, strong, none, none])
	_band(PackedVector2Array([Vector2(0, view.y - edge), Vector2(view.x, view.y - edge), Vector2(view.x, view.y), Vector2(0, view.y)]), [none, none, strong, strong])
	_band(PackedVector2Array([Vector2(0, 0), Vector2(edge, 0), Vector2(edge, view.y), Vector2(0, view.y)]), [strong, none, none, strong])
	_band(PackedVector2Array([Vector2(view.x - edge, 0), Vector2(view.x, 0), Vector2(view.x, view.y), Vector2(view.x - edge, view.y)]), [none, strong, strong, none])


func _band(points: PackedVector2Array, colors: Array) -> void:
	_canvas.draw_polygon(points, PackedColorArray(colors))
