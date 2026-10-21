class_name GateOverlay
extends CanvasLayer
## Zwei schwere Metalltore, die sich nach einer geschafften Welle schliessen und den Shop einrahmen,
## und beim Weitergehen wieder oeffnen. Laeuft auch bei Pause weiter.

signal closed
signal opened

const CLOSE_TIME := 0.85
const OPEN_TIME := 0.95

## 0 = offen, 1 = geschlossen.
var amount := 0.0
var is_closed := false

var _target := 0.0
var _speed := 0.0
var _canvas: Node2D
var _time := 0.0
var _shake := 0.0


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_gates)
	add_child(_canvas)
	visible = false


func close() -> void:
	if is_closed or _target == 1.0:
		return
	_target = 1.0
	_speed = 1.0 / CLOSE_TIME
	visible = true
	Sfx.play("gate", 0.0)


func open() -> void:
	if amount <= 0.0 and _target == 0.0:
		return
	_target = 0.0
	_speed = 1.0 / OPEN_TIME
	is_closed = false
	visible = true
	Sfx.play("gate", 0.0)


## Sofort offen (Tests, Neustart).
func reset() -> void:
	amount = 0.0
	_target = 0.0
	is_closed = false
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_shake = maxf(0.0, _shake - delta * 4.0)
	if amount != _target:
		# Schliessen beschleunigt zum Ende hin (faellt zu), Oeffnen laeuft sanft an.
		amount = move_toward(amount, _target, _speed * delta)
		if amount == _target:
			if _target == 1.0:
				is_closed = true
				_shake = 1.0
				Sfx.play("land_heavy", 0.0)
				closed.emit()
			else:
				visible = false
				opened.emit()
	_canvas.queue_redraw()


func _ease(x: float) -> float:
	# Schliessen: langsamer Start, harter Schluss. Oeffnen: gleiches Profil rueckwaerts.
	return x * x * (3.0 - 2.0 * x)


func _draw_gates() -> void:
	var view := _canvas.get_viewport_rect().size
	var a := _ease(amount)
	var half := view.x * 0.5
	var shake := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 7.0 * _shake * SaveData.shake_scale()
	for side in [-1.0, 1.0]:
		# Jedes Tor von aussen nach innen; bei a = 1 treffen sie sich in der Mitte.
		var width := half + 14.0
		var edge := half * a
		var x0 := (edge - width) if side < 0.0 else (view.x - edge)
		_draw_door(Rect2(Vector2(x0, 0.0) + shake, Vector2(width, view.y)), side)
	if is_closed:
		# Verriegelung in der Mitte.
		var lock := Rect2(Vector2(view.x * 0.5 - 28.0, view.y * 0.5 - 90.0) + shake, Vector2(56.0, 180.0))
		Art.panel(_canvas, lock, Color(0.28, 0.3, 0.38), 10.0)
		var glow := 0.6 + 0.4 * sin(_time * 4.0)
		for k in 3:
			Art.led(_canvas, lock.position + Vector2(28.0, 40.0 + k * 50.0), 8.0, Color(1.0, 0.7, 0.2), glow > 0.5 or k == 1)


func _draw_door(rect: Rect2, side: float) -> void:
	# Blech mit Verlauf und Fugen.
	Art.rrect_grad(_canvas, rect, Color(0.34, 0.37, 0.46), Color(0.13, 0.14, 0.2), 0.0)
	var y := rect.position.y + 110.0
	while y < rect.end.y:
		_canvas.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0, 0, 0, 0.5), 3.0)
		_canvas.draw_line(Vector2(rect.position.x, y + 3.0), Vector2(rect.end.x, y + 3.0), Color(1, 1, 1, 0.08), 1.5)
		y += 150.0
	# Senkrechte Verstaerkungen.
	for k in 4:
		var x := rect.position.x + rect.size.x * (0.12 + 0.24 * k)
		_canvas.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(0, 0, 0, 0.35), 4.0)
		_canvas.draw_line(Vector2(x + 4.0, rect.position.y), Vector2(x + 4.0, rect.end.y), Color(1, 1, 1, 0.06), 2.0)
	# Nieten.
	y = rect.position.y + 40.0
	while y < rect.end.y:
		var x := rect.position.x + 30.0
		while x < rect.end.x - 20.0:
			Art.rivet(_canvas, Vector2(x, y), 2.4)
			x += 110.0
		y += 150.0
	# Schriftzug, ueber beide Tore verteilt: links "SH", rechts "OP", an der inneren Kante.
	var font := ThemeDB.fallback_font
	var label := "SH" if side < 0.0 else "OP"
	var text_w := 220.0
	var text_x := rect.end.x - 90.0 - text_w if side < 0.0 else rect.position.x + 90.0
	var align := HORIZONTAL_ALIGNMENT_RIGHT if side < 0.0 else HORIZONTAL_ALIGNMENT_LEFT
	_canvas.draw_string(font, Vector2(text_x, rect.size.y * 0.5 + 40.0), label, align, text_w, 120, Color(0.08, 0.09, 0.13, 0.7))
	# Warnstreifen an der inneren Kante.
	var edge_w := 56.0
	var strip := Rect2(Vector2(rect.end.x - edge_w if side < 0.0 else rect.position.x, rect.position.y), Vector2(edge_w, rect.size.y))
	_canvas.draw_rect(strip, Color(0.95, 0.75, 0.12))
	var yy := strip.position.y - edge_w
	while yy < strip.end.y:
		var p0 := Vector2(strip.position.x, yy + edge_w)
		var points := PackedVector2Array([p0, p0 + Vector2(edge_w, -edge_w), p0 + Vector2(edge_w, -edge_w + 28.0), p0 + Vector2(0.0, 28.0)])
		if side > 0.0:
			points = PackedVector2Array([Vector2(strip.end.x, yy + edge_w), Vector2(strip.position.x, yy), Vector2(strip.position.x, yy + 28.0), Vector2(strip.end.x, yy + edge_w + 28.0)])
		_canvas.draw_colored_polygon(points, Color(0.1, 0.1, 0.13))
		yy += 56.0
	_canvas.draw_line(Vector2(strip.position.x if side > 0.0 else strip.end.x, strip.position.y), Vector2(strip.position.x if side > 0.0 else strip.end.x, strip.end.y), Color(0, 0, 0, 0.7), 4.0)
	_canvas.draw_rect(Rect2(rect.position, rect.size), Color(0, 0, 0, 0.6), false, 3.0)
