class_name Hud
extends CanvasLayer
## Anzeige: Leben, Dash, Gold, Waffen und Firmware pro Spieler, Wellenzeit,
## Stufe, XP-Leiste, Game-Over-Hinweis und Controller-Diagnose.

const PANEL_WIDTH := 330.0
const PANEL_HEIGHT := 128.0

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
	var font := ThemeDB.fallback_font
	# Schatten fuer bessere Lesbarkeit auf hellem Hintergrund.
	_canvas.draw_string(font, pos + Vector2(1, 1), text, align, width, size, Color(0, 0, 0, 0.7))
	_canvas.draw_string(font, pos, text, align, width, size, color)


func _draw_hud() -> void:
	if main == null:
		return
	var view := _canvas.get_viewport_rect().size
	_draw_player_panel(main.players[0], Vector2(24.0, 16.0))
	_draw_player_panel(main.players[1], Vector2(view.x - PANEL_WIDTH - 24.0, 16.0))
	if not main.shop_menu.is_open:
		_draw_top_center(view)
	_draw_xp_bar(view)
	_draw_debug(view)
	if main.game_over:
		_draw_game_over(view)
	elif main.phase == main.Phase.VICTORY:
		_draw_victory(view)


func _draw_player_panel(player: Player, origin: Vector2) -> void:
	var accent: Color = RobotClasses.PLAYER_COLORS[player.player_index - 1]
	var panel := Rect2(origin + Vector2(-10, -8), Vector2(PANEL_WIDTH + 20.0, PANEL_HEIGHT))
	Art.rrect(_canvas, panel, Color(0.04, 0.05, 0.09, 0.72), 12.0)
	Art.rrect_line(_canvas, panel, Color(accent, 0.55), 12.0, 2.0)
	_canvas.draw_rect(Rect2(panel.position + Vector2(14, 0), Vector2(60, 3)), accent)

	# Kopfzeile: Spielermarke, Klasse, Gold.
	_canvas.draw_colored_polygon(PackedVector2Array([origin + Vector2(0, 8), origin + Vector2(12, 8), origin + Vector2(6, 17)]), accent)
	_text(origin + Vector2(18, 18), "P%d  %s" % [player.player_index, player.stats.name], 19, accent)
	_canvas.draw_circle(origin + Vector2(PANEL_WIDTH - 70, 12), 6.0, Color(1.0, 0.82, 0.25))
	_canvas.draw_arc(origin + Vector2(PANEL_WIDTH - 70, 12), 6.0, 0.0, TAU, 14, Color(0.6, 0.4, 0.05), 1.5, true)
	_text(origin + Vector2(0, 19), "%d" % player.gold, 18, Color(1.0, 0.85, 0.3), HORIZONTAL_ALIGNMENT_RIGHT, PANEL_WIDTH - 4.0)

	# Lebensleiste mit Segmenten, pulsiert bei wenig Leben.
	var bar := Rect2(origin + Vector2(0, 28), Vector2(PANEL_WIDTH, 17))
	var fraction := clampf(player.hp / player.max_health(), 0.0, 1.0)
	Art.rrect(_canvas, bar, Color(0.1, 0.1, 0.14), 5.0)
	var fill_top := Color(0.5, 0.95, 0.55)
	var fill_bottom := Color(0.2, 0.65, 0.35)
	if player.downed:
		fill_top = Color(0.55, 0.55, 0.6)
		fill_bottom = Color(0.35, 0.35, 0.4)
	elif fraction < 0.3:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
		fill_top = Color(1.0, 0.45, 0.4).lerp(Color(1.0, 0.7, 0.6), pulse)
		fill_bottom = Color(0.75, 0.2, 0.2)
	if fraction > 0.0:
		Art.rrect_grad(_canvas, Rect2(bar.position, Vector2(maxf(bar.size.x * fraction, 8.0), bar.size.y)), fill_top, fill_bottom, 5.0)
	var segments := int(player.max_health() / 20.0)
	for i in range(1, segments):
		var x := bar.position.x + bar.size.x * float(i) / float(segments)
		_canvas.draw_line(Vector2(x, bar.position.y + 2), Vector2(x, bar.end.y - 2), Color(0, 0, 0, 0.35), 1.5)
	Art.rrect_line(_canvas, bar, Color(1, 1, 1, 0.3), 5.0, 1.5)
	_text(origin + Vector2(8, 41), "%d / %d" % [int(ceil(player.hp)), int(player.max_health())], 13, Color(1, 1, 1, 0.95))

	# Dash-Aufladungen als Kapseln.
	for i in player.dash_max():
		var pill := Rect2(origin + Vector2(i * 22.0, 52), Vector2(18, 7))
		Art.rrect(_canvas, pill, accent if i < player.dash_charges else Color(1, 1, 1, 0.14), 3.0)

	# Waffen als Chips, aktive Waffe hervorgehoben.
	var x := 0.0
	for i in player.weapons.size():
		var weapon_name: String = Weapons.get_weapon(player.weapons[i]).name
		var active := i == player.weapon_index
		var width := 22.0 + weapon_name.length() * 8.0
		var chip := Rect2(origin + Vector2(x, 66), Vector2(width, 24))
		Art.rrect(_canvas, chip, Color(0.18, 0.2, 0.3) if active else Color(0.1, 0.11, 0.17), 6.0)
		Art.rrect_line(_canvas, chip, accent if active else Color(1, 1, 1, 0.15), 6.0, 2.0 if active else 1.0)
		var module: String = player.modules[i]
		if module != "":
			_canvas.draw_circle(chip.position + Vector2(10, 12), 4.5, Elements.COLORS[module])
		_text(chip.position + Vector2(18 if module != "" else 8, 17), weapon_name, 14, Color.WHITE if active else Color(0.65, 0.65, 0.72))
		x += width + 6.0

	# Firmware.
	var fw_parts: Array[String] = []
	for id in player.firmware:
		var count: int = player.firmware[id]
		fw_parts.append(Firmware.SHORT[id] + (" x%d" % count if count > 1 else ""))
	if not fw_parts.is_empty():
		_text(origin + Vector2(0, 108), "  ".join(fw_parts), 13, Color(0.55, 0.92, 0.7))
	if player.downed:
		_text(origin + Vector2(0, 108), "AM BODEN: Partner haelt Interagieren", 14, Color(1.0, 0.5, 0.4))


func _draw_top_center(view: Vector2) -> void:
	var title := "Welle %d / %d" % [main.wave, main.max_waves]
	var remaining := int(ceil(maxf(main.wave_time_left, 0.0)))
	var clock := "%02d:%02d" % [remaining / 60, remaining % 60]
	if main.phase == main.Phase.CLEARING:
		clock = "Welle geschafft!"
	var panel := Rect2(Vector2(view.x * 0.5 - 130.0, 8.0), Vector2(260.0, 82.0))
	Art.rrect(_canvas, panel, Color(0.04, 0.05, 0.09, 0.72), 12.0)
	Art.rrect_line(_canvas, panel, Color(1, 1, 1, 0.2), 12.0, 2.0)
	_text(Vector2(0, 30), title, 17, Color(0.8, 0.82, 0.95), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	_text(Vector2(0, 62), clock, 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, view.x)
	_text(Vector2(0, 82), "Stufe %d     Gegner %d" % [main.level, main.director.alive_count()], 14, Color(0.7, 0.72, 0.85), HORIZONTAL_ALIGNMENT_CENTER, view.x)


func _draw_xp_bar(view: Vector2) -> void:
	var bar := Rect2(Vector2(view.x * 0.5 - 360.0, view.y - 26.0), Vector2(720.0, 12.0))
	var fraction := clampf(float(main.xp) / float(main.xp_needed), 0.0, 1.0)
	Art.rrect(_canvas, bar.grow(2.0), Color(0.03, 0.04, 0.08, 0.8), 8.0)
	if fraction > 0.0:
		Art.rrect_grad(_canvas, Rect2(bar.position, Vector2(maxf(bar.size.x * fraction, 8.0), bar.size.y)), Color(0.55, 0.8, 1.0), Color(0.25, 0.5, 0.95), 6.0)
		Art.glow(_canvas, bar.position + Vector2(bar.size.x * fraction, 6), 10.0, Color(0.4, 0.7, 1.0))
	Art.rrect_line(_canvas, bar.grow(2.0), Color(1, 1, 1, 0.3), 8.0, 1.5)
	_text(bar.position + Vector2(-70, 11), "Stufe %d" % main.level, 14, Color(0.75, 0.85, 1.0))


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
		_text(Vector2(16, view.y - 24.0 - (lines.size() - 1 - i) * 16.0), lines[i], 12, Color(0.6, 0.62, 0.7, 0.8))


func _draw_game_over(view: Vector2) -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.65))
	_text(Vector2(0, view.y * 0.4), "GAME OVER", 68, Color(1.0, 0.4, 0.4), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	var seconds := int(main.director.time)
	_text(Vector2(0, view.y * 0.4 + 50.0), "Zeit %02d:%02d   Stufe %d   Besiegt %d" % [seconds / 60, seconds % 60, main.level, main.kills],
		24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, view.x)
	_text(Vector2(0, view.y * 0.4 + 100.0), "Springen, Schiessen oder Bestaetigen zum Neustart", 20, Color(0.8, 0.8, 0.9), HORIZONTAL_ALIGNMENT_CENTER, view.x)


func _draw_victory(view: Vector2) -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.6))
	_text(Vector2(0, view.y * 0.4), "ALLE WELLEN GESCHAFFT", 58, Color(0.5, 1.0, 0.6), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	_text(Vector2(0, view.y * 0.4 + 50.0), "Hier kommt spaeter der Endboss. Besiegt: %d   Stufe %d" % [main.kills, main.level],
		24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, view.x)
	_text(Vector2(0, view.y * 0.4 + 100.0), "Springen, Schiessen oder Bestaetigen zum Neustart", 20, Color(0.8, 0.8, 0.9), HORIZONTAL_ALIGNMENT_CENTER, view.x)
