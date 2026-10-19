class_name Hud
extends CanvasLayer
## Anzeige: Leben, Dash, Gold und Waffen pro Spieler, Zeit, Stufe, XP-Leiste,
## Game-Over-Hinweis und Controller-Diagnose.

const PANEL_WIDTH := 320.0
const BAR_HEIGHT := 16.0

var main: Node = null
var _canvas: Node2D


func _ready() -> void:
	layer = 10
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)


func _process(_delta: float) -> void:
	_canvas.queue_redraw()


func _text(pos: Vector2, text: String, size := 18, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	_canvas.draw_string(ThemeDB.fallback_font, pos, text, align, width, size, color)


func _bar(pos: Vector2, size: Vector2, fraction: float, color: Color) -> void:
	_canvas.draw_rect(Rect2(pos, size), Color(0.1, 0.1, 0.14, 0.85))
	_canvas.draw_rect(Rect2(pos, Vector2(size.x * clampf(fraction, 0.0, 1.0), size.y)), color)
	_canvas.draw_rect(Rect2(pos, size), Color(1, 1, 1, 0.25), false, 1.0)


func _draw_hud() -> void:
	if main == null:
		return
	var view := _canvas.get_viewport_rect().size
	_draw_player_panel(main.players[0], Vector2(20.0, 14.0))
	_draw_player_panel(main.players[1], Vector2(view.x - PANEL_WIDTH - 20.0, 14.0))
	_draw_top_center(view)
	_draw_xp_bar(view)
	_draw_debug(view)
	if main.game_over:
		_draw_game_over(view)


func _draw_player_panel(player: Player, origin: Vector2) -> void:
	var color: Color = RobotClasses.PLAYER_COLORS[player.player_index - 1]
	_text(origin + Vector2(0, 20), "P%d  %s" % [player.player_index, player.stats.name], 20, color)
	_text(origin + Vector2(0, 20), "Gold %d" % player.gold, 18, Color(1.0, 0.85, 0.3), HORIZONTAL_ALIGNMENT_RIGHT, PANEL_WIDTH)
	var hp_color := Color(0.35, 0.85, 0.45) if not player.downed else Color(0.5, 0.5, 0.55)
	_bar(origin + Vector2(0, 28), Vector2(PANEL_WIDTH, BAR_HEIGHT), player.hp / player.max_health(), hp_color)
	_text(origin + Vector2(6, 41), "%d / %d" % [int(ceil(player.hp)), int(player.max_health())], 13, Color(0, 0, 0, 0.9))

	for i in int(player.stats.dash_charges):
		var filled := i < player.dash_charges
		_canvas.draw_circle(origin + Vector2(8 + i * 18, 60), 6.0, Color(1, 1, 1, 0.9 if filled else 0.2))

	var x := 0.0
	for i in player.weapons.size():
		var weapon_name: String = Weapons.get_weapon(player.weapons[i]).name
		var active := i == player.weapon_index
		var label := "[%s]" % weapon_name if active else weapon_name
		var module: String = player.modules[i]
		if module != "":
			_canvas.draw_circle(origin + Vector2(x + 5, 77), 5.0, Elements.COLORS[module])
			x += 14.0
		_text(origin + Vector2(x, 82), label, 16, Color.WHITE if active else Color(0.65, 0.65, 0.7))
		x += 16.0 + label.length() * 8.0

	if player.downed:
		_text(origin + Vector2(0, 104), "AM BODEN - Partner: Interagieren halten", 16, Color(1.0, 0.5, 0.4))


func _draw_top_center(view: Vector2) -> void:
	var seconds := int(main.director.time)
	var clock := "%02d:%02d" % [seconds / 60, seconds % 60]
	_text(Vector2(0, 28), clock, 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, view.x)
	_text(Vector2(0, 52), "Stufe %d   Gegner %d" % [main.level, main.director.alive_count()], 16, Color(0.8, 0.8, 0.9), HORIZONTAL_ALIGNMENT_CENTER, view.x)


func _draw_xp_bar(view: Vector2) -> void:
	_bar(Vector2(0, view.y - 12.0), Vector2(view.x, 12.0), float(main.xp) / float(main.xp_needed), Color(0.35, 0.6, 1.0))


func _draw_debug(view: Vector2) -> void:
	var lines: Array[String] = []
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		lines.append("Kein Controller erkannt (Tastatur aktiv)")
	for pad in pads:
		lines.append("Controller %d: %s" % [pad, Input.get_joy_name(pad)])
	lines.append("Letzter Controller-Input: %s" % main.last_pad_event)
	lines.append("FPS: %d" % Engine.get_frames_per_second())
	for i in lines.size():
		_text(Vector2(16, view.y - 24.0 - (lines.size() - 1 - i) * 18.0), lines[i], 14, Color(0.6, 0.6, 0.65))


func _draw_game_over(view: Vector2) -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.6))
	_text(Vector2(0, view.y * 0.4), "GAME OVER", 64, Color(1.0, 0.4, 0.4), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	var seconds := int(main.director.time)
	_text(Vector2(0, view.y * 0.4 + 50.0), "Zeit %02d:%02d   Stufe %d   Besiegt %d" % [seconds / 60, seconds % 60, main.level, main.kills],
		24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, view.x)
	_text(Vector2(0, view.y * 0.4 + 100.0), "Springen, Schiessen oder Bestaetigen zum Neustart", 20, Color(0.8, 0.8, 0.9), HORIZONTAL_ALIGNMENT_CENTER, view.x)
