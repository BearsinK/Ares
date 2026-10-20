class_name LevelUpMenu
extends CanvasLayer
## Level-Up-Auswahl: drei Team-Perks, beide Spieler waehlen. Der Perk wird
## uebernommen, sobald beide dieselbe Karte bestaetigt haben. Links und rechts
## bewegt den Cursor, Bestaetigen sperrt die Wahl, Interagieren (oder erneute
## Bewegung) nimmt sie zurueck. Waehrend das Menue offen ist, pausiert das Spiel.

signal chosen(perk_id: String)

const CARD_SIZE := Vector2(340.0, 420.0)
const CARD_GAP := 40.0
const GRACE_TIME := 0.5
## So lange dauert der Streit um verschiedene Karten, bevor der Zufall entscheidet.
const SPLIT_TIME := 2.5

var players: Array[Player] = []
var perk_ids: Array[String] = []
var is_open := false

var _cursor := [0, 0]
var _locked := [-1, -1]
var _age := 0.0
var _split_time := 0.0
## Zufallsentscheid bei Uneinigkeit: Hervorhebung springt zwischen den Karten und bleibt beim Gewinner.
var _roulette := false
var _roulette_t := 0.0
var _roulette_order: Array[int] = []
var _roulette_times: Array[float] = []
var _roulette_shown := -1
var _roulette_done := false
var _roulette_winner := -1
var _roulette_end := 0.0
const ROULETTE_HOLD := 1.5
var _split_message := ""
var _title := ""
var _canvas: Node2D


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_menu)
	add_child(_canvas)
	visible = false


func open(new_players: Array[Player], new_perk_ids: Array[String], level: int) -> void:
	players = new_players
	perk_ids = new_perk_ids
	_cursor = [1, 1]
	_locked = [-1, -1]
	_age = 0.0
	_split_time = 0.0
	_roulette = false
	_title = "LEVEL UP!  Stufe %d" % level
	is_open = true
	visible = true
	get_tree().paused = true
	Sfx.play("levelup")


func _process(delta: float) -> void:
	if not is_open:
		return
	_age += delta
	if _roulette:
		_update_roulette(delta)
		_canvas.queue_redraw()
		return
	if _age >= GRACE_TIME:
		for i in 2:
			_handle_player(i)
		if _locked[0] != -1 and _locked[0] == _locked[1]:
			_finish(perk_ids[_locked[0]])
		elif _locked[0] != -1 and _locked[1] != -1:
			# Beide bereit, aber auf verschiedenen Karten: nach kurzer Zeit entscheidet der Zufall.
			_split_time += delta
			if _split_time >= SPLIT_TIME:
				_start_roulette()
		else:
			_split_time = 0.0
	_canvas.queue_redraw()


func _start_roulette() -> void:
	var a: int = _locked[0]
	var b: int = _locked[1]
	_roulette_winner = a if randi() % 2 == 0 else b
	var loser := b if _roulette_winner == a else a
	_roulette_order = []
	_roulette_times = []
	var t := 0.0
	var delay := 0.07
	var current := a
	for k in 200:
		_roulette_order.append(current)
		_roulette_times.append(t)
		t += delay
		delay *= 1.15
		if t > 2.0 and current == _roulette_winner:
			break
		current = loser if current == _roulette_winner else _roulette_winner
	_roulette_end = t
	_roulette_t = 0.0
	_roulette_shown = -1
	_roulette_done = false
	_roulette = true


func _update_roulette(delta: float) -> void:
	_roulette_t += delta
	var shown := _roulette_order[0]
	for k in _roulette_order.size():
		if _roulette_times[k] <= _roulette_t:
			shown = _roulette_order[k]
	if shown != _roulette_shown:
		_roulette_shown = shown
		Sfx.play("switch")
	if not _roulette_done and _roulette_t >= _roulette_end:
		_roulette_done = true
		Sfx.play("levelup")
	if _roulette_t >= _roulette_end + ROULETTE_HOLD:
		_finish(perk_ids[_roulette_winner])


func _handle_player(i: int) -> void:
	var prefix := "p%d_" % (i + 1)
	var move := 0
	if Input.is_action_just_pressed(prefix + "left"):
		move -= 1
	if Input.is_action_just_pressed(prefix + "right"):
		move += 1
	if move != 0:
		_locked[i] = -1
		_cursor[i] = clampi(_cursor[i] + move, 0, perk_ids.size() - 1)
		Sfx.play("switch")
	if Input.is_action_just_pressed(prefix + "confirm"):
		_locked[i] = _cursor[i]
		Sfx.play("pickup")
	if Input.is_action_just_pressed(prefix + "interact"):
		_locked[i] = -1


func _finish(perk_id: String) -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	chosen.emit(perk_id)


func _draw_menu() -> void:
	var view := _canvas.get_viewport_rect().size
	_canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.74))
	UiKit.text(_canvas, Vector2(0, 150), _title, 56, Color(1.0, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	UiKit.text(_canvas, Vector2(0, 192), "Beide wählen dieselbe Karte. Links/Rechts: wählen, Kreuz: bestätigen, Kreis: zurück", 20, Color(0.78, 0.8, 0.92), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	if _roulette:
		UiKit.text(_canvas, Vector2(0, 222), "Der Zufall entscheidet ..." if _roulette_t < _roulette_end else "Der Zufall hat entschieden!", 26, Color(1.0, 0.8, 0.4), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	elif _locked[0] != -1 and _locked[1] != -1 and _locked[0] != _locked[1]:
		UiKit.text(_canvas, Vector2(0, 222), "Uneinig! Der Zufall entscheidet in %.1f s" % maxf(0.0, SPLIT_TIME - _split_time), 24, Color(1.0, 0.6, 0.4), HORIZONTAL_ALIGNMENT_CENTER, view.x)

	var total := perk_ids.size() * CARD_SIZE.x + (perk_ids.size() - 1) * CARD_GAP
	var start := Vector2((view.x - total) * 0.5, 240.0)
	for index in perk_ids.size():
		var pos := start + Vector2(index * (CARD_SIZE.x + CARD_GAP), 0.0)
		_draw_card(pos, perk_ids[index], index)


func _draw_card(pos: Vector2, perk_id: String, index: int) -> void:
	var highlighted: bool = _cursor[0] == index or _cursor[1] == index
	var both: bool = _cursor[0] == index and _cursor[1] == index
	var perk_color := PerkArt.color_of(perk_id)
	var flash := 0.0
	if _roulette:
		# Roulette: nur die gerade leuchtende Karte ist hell, am Ende blinkt der Gewinner.
		highlighted = index == _roulette_shown
		both = highlighted
		if _roulette_t >= _roulette_end:
			flash = 0.5 + 0.5 * sin(_roulette_t * 16.0) if index == _roulette_winner else 0.0
			highlighted = index == _roulette_winner
		elif highlighted:
			flash = 1.0
	var rect := Rect2(pos, CARD_SIZE)
	var lift := Vector2(0.0, -10.0) if highlighted else Vector2.ZERO
	rect.position += lift
	var fill := Color(0.2, 0.22, 0.32) if highlighted else Color(0.12, 0.13, 0.2)
	if flash > 0.0:
		fill = fill.lerp(perk_color.lightened(0.2), 0.55 * flash)
	Art.panel(_canvas, rect, fill, 16.0, Color(perk_color.lerp(Color.WHITE, flash * 0.6), 0.9 if both else (0.6 if highlighted else 0.25)))
	if flash > 0.0:
		Art.glow(_canvas, rect.get_center(), 190.0 * flash, perk_color)
		_canvas.draw_rect(rect.grow(6.0), Color(1, 1, 1, 0.5 * flash), false, 4.0)
	if _roulette and _roulette_t >= _roulette_end and index == _roulette_winner:
		UiKit.text(_canvas, rect.position + Vector2(0, -16.0), "GEWONNEN!", 30, Color(1.0, 0.95, 0.5, 0.6 + 0.4 * flash), HORIZONTAL_ALIGNMENT_CENTER, CARD_SIZE.x)
	_canvas.draw_rect(Rect2(rect.position + Vector2(20, 0), Vector2(80, 5)), perk_color)
	PerkArt.draw(_canvas, perk_id, rect.position + Vector2(CARD_SIZE.x * 0.5, 84.0), 88.0)
	UiKit.text(_canvas, rect.position + Vector2(0, 176), Perks.DATA[perk_id].name, 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, CARD_SIZE.x)
	_canvas.draw_line(rect.position + Vector2(30, 196), rect.position + Vector2(CARD_SIZE.x - 30, 196), Color(1, 1, 1, 0.15), 2.0)

	var y := 228.0
	for player in players:
		var color: Color = RobotClasses.PLAYER_COLORS[player.player_index - 1]
		UiKit.text(_canvas, rect.position + Vector2(24, y), "P%d  %s" % [player.player_index, player.stats.name], 18, color)
		UiKit.text(_canvas, rect.position + Vector2(24, y + 24), Perks.describe(perk_id, player.class_id), 17, Color(0.92, 0.93, 0.98), HORIZONTAL_ALIGNMENT_LEFT, CARD_SIZE.x - 48.0, true)
		y += 92.0

	# Cursor- und Sperr-Markierungen der Spieler.
	for i in 2:
		var marker_color: Color = RobotClasses.PLAYER_COLORS[i]
		var x := pos.x + 20.0 + i * 120.0
		var marker := Rect2(Vector2(x, pos.y + CARD_SIZE.y + 16.0), Vector2(100.0, 30.0))
		if _locked[i] == index:
			Art.rrect(_canvas, marker, marker_color, 9.0)
			UiKit.text(_canvas, marker.position + Vector2(0, 21), "P%d bereit" % (i + 1), 16, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, 100.0)
		elif _cursor[i] == index:
			Art.rrect_line(_canvas, marker, marker_color, 9.0, 2.0)
			UiKit.text(_canvas, marker.position + Vector2(0, 21), "P%d" % (i + 1), 16, marker_color, HORIZONTAL_ALIGNMENT_CENTER, 100.0)
