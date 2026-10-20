class_name LevelUpMenu
extends CanvasLayer
## Level-Up-Auswahl: drei Team-Perks, beide Spieler waehlen. Der Perk wird
## uebernommen, sobald beide dieselbe Karte bestaetigt haben. Links und rechts
## bewegt den Cursor, Bestaetigen sperrt die Wahl, Interagieren (oder erneute
## Bewegung) nimmt sie zurueck. Waehrend das Menue offen ist, pausiert das Spiel.

signal chosen(perk_id: String)

const CARD_SIZE := Vector2(340.0, 300.0)
const CARD_GAP := 40.0
const GRACE_TIME := 0.5

var players: Array[Player] = []
var perk_ids: Array[String] = []
var is_open := false

var _cursor := [0, 0]
var _locked := [-1, -1]
var _age := 0.0
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
	_title = "LEVEL UP!  Stufe %d" % level
	is_open = true
	visible = true
	get_tree().paused = true
	Sfx.play("levelup")


func _process(delta: float) -> void:
	if not is_open:
		return
	_age += delta
	if _age >= GRACE_TIME:
		for i in 2:
			_handle_player(i)
		if _locked[0] != -1 and _locked[0] == _locked[1]:
			_finish(perk_ids[_locked[0]])
	_canvas.queue_redraw()


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
	var font := ThemeDB.fallback_font
	_canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.7))
	_canvas.draw_string(font, Vector2(0, 140), _title, HORIZONTAL_ALIGNMENT_CENTER, view.x, 48, Color(1.0, 0.9, 0.4))
	_canvas.draw_string(font, Vector2(0, 180), "Beide muessen dieselbe Karte bestaetigen. Links/Rechts waehlen, Bestaetigen sperren, Interagieren zurueck.",
		HORIZONTAL_ALIGNMENT_CENTER, view.x, 18, Color(0.8, 0.8, 0.9))

	var total := perk_ids.size() * CARD_SIZE.x + (perk_ids.size() - 1) * CARD_GAP
	var start := Vector2((view.x - total) * 0.5, 230.0)
	for index in perk_ids.size():
		var pos := start + Vector2(index * (CARD_SIZE.x + CARD_GAP), 0.0)
		_draw_card(pos, perk_ids[index], index, font)


func _draw_card(pos: Vector2, perk_id: String, index: int, font: Font) -> void:
	var highlighted: bool = _cursor[0] == index or _cursor[1] == index
	Art.panel(_canvas, Rect2(pos, CARD_SIZE), Color(0.2, 0.22, 0.32) if highlighted else Color(0.14, 0.15, 0.22), 14.0, Color(1, 1, 1, 0.3))
	_canvas.draw_string(font, pos + Vector2(0, 50), Perks.DATA[perk_id].name, HORIZONTAL_ALIGNMENT_CENTER, CARD_SIZE.x, 30, Color.WHITE)

	var y := 110.0
	for player in players:
		var color: Color = RobotClasses.PLAYER_COLORS[player.player_index - 1]
		_canvas.draw_string(font, pos + Vector2(16, y), "P%d %s" % [player.player_index, player.stats.name], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
		_canvas.draw_string(font, pos + Vector2(16, y + 24), Perks.describe(perk_id, player.class_id), HORIZONTAL_ALIGNMENT_LEFT, CARD_SIZE.x - 32.0, 18, Color(0.9, 0.9, 0.95))
		y += 80.0

	# Cursor- und Sperr-Markierungen der Spieler.
	for i in 2:
		var marker_color: Color = RobotClasses.PLAYER_COLORS[i]
		var x := pos.x + 20.0 + i * 120.0
		if _locked[i] == index:
			Art.rrect(_canvas, Rect2(Vector2(x, pos.y + CARD_SIZE.y + 10.0), Vector2(100.0, 28.0)), marker_color, 8.0)
			_canvas.draw_string(font, Vector2(x, pos.y + CARD_SIZE.y + 30.0), "P%d bereit" % (i + 1), HORIZONTAL_ALIGNMENT_CENTER, 100.0, 16, Color.BLACK)
		elif _cursor[i] == index:
			Art.rrect_line(_canvas, Rect2(Vector2(x, pos.y + CARD_SIZE.y + 10.0), Vector2(100.0, 28.0)), marker_color, 8.0, 2.0)
			_canvas.draw_string(font, Vector2(x, pos.y + CARD_SIZE.y + 30.0), "P%d" % (i + 1), HORIZONTAL_ALIGNMENT_CENTER, 100.0, 16, marker_color)
