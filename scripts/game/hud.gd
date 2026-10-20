class_name Hud
extends CanvasLayer
## Anzeige: Leben, Dash, Gold, Waffen und Firmware pro Spieler, Wellenzeit,
## Stufe, XP-Leiste, Game-Over-Hinweis und Controller-Diagnose.

const PANEL_WIDTH := 330.0
const PANEL_HEIGHT := 128.0

var main: Node = null
var _canvas: Node2D
var _flash_color := Color(0, 0, 0, 0)
var _flash_time := 0.0
var _age := 0.0


func _ready() -> void:
	layer = 10
	# Laeuft auch bei Pause weiter, damit die Anzeige zu den Menues passt.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)


func _process(delta: float) -> void:
	_age += delta
	_flash_time = maxf(0.0, _flash_time - delta)
	_canvas.queue_redraw()


## Farbiger Bildschirmrand-Blitz (z.B. rot bei Treffern).
func flash(color: Color) -> void:
	_flash_color = color
	_flash_time = 0.35


func _text(pos: Vector2, text: String, size := 18, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var font := ThemeDB.fallback_font
	# Schatten fuer bessere Lesbarkeit auf hellem Hintergrund.
	_canvas.draw_string(font, pos + Vector2(1, 1), text, align, width, size, Color(0, 0, 0, 0.7))
	_canvas.draw_string(font, pos, text, align, width, size, color)


func _draw_hud() -> void:
	if main == null:
		return
	var view := _canvas.get_viewport_rect().size
	_draw_flash(view)
	_draw_hints(view)
	_draw_player_panel(main.players[0], Vector2(24.0, 16.0))
	_draw_player_panel(main.players[1], Vector2(view.x - PANEL_WIDTH - 24.0, 16.0))
	if main.boss != null and is_instance_valid(main.boss):
		if not main.shop_menu.is_open and not main.levelup_menu.is_open:
			_draw_boss_bar(view, main.boss)
	elif not main.shop_menu.is_open and not main.levelup_menu.is_open:
		_draw_top_center(view)
	_draw_xp_bar(view)
	_draw_debug(view)


## Steuerungshinweis in den ersten Sekunden eines Laufs.
func _draw_hints(view: Vector2) -> void:
	var visible_time := 16.0
	if _age > visible_time or main.wave > 1 or main.phase != main.Phase.WAVE:
		return
	var alpha := clampf(minf(_age / 0.6, (visible_time - _age) / 1.5), 0.0, 1.0)
	var panel := Rect2(Vector2(view.x * 0.5 - 430.0, 104.0), Vector2(860.0, 112.0))
	Art.rrect(_canvas, panel, Color(0.04, 0.05, 0.09, 0.8 * alpha), 14.0)
	Art.rrect_line(_canvas, panel, Color(1, 1, 1, 0.25 * alpha), 14.0, 2.0)
	_text(panel.position + Vector2(0, 28), "STEUERUNG", 16, Color(1.0, 0.85, 0.4, alpha), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	_text(panel.position + Vector2(0, 56), "Controller: R2 schiessen   R1 Dash   L1 Sprung   L2 Faehigkeit   Dreieck Waffe   Kreis Partner beleben", 15, Color(0.9, 0.92, 1.0, alpha), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	_text(panel.position + Vector2(0, 80), "Tastatur P1: WASD, Maus, Leertaste, Shift, E     P2: Pfeile, Punkt, Strich, Komma     F11 Vollbild", 15, Color(0.7, 0.74, 0.9, alpha), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	_text(panel.position + Vector2(0, 102), "Je weiter ihr kommt, desto mehr Chips gibt es fuer die Werkstatt.", 13, Color(0.6, 0.95, 1.0, alpha * 0.9), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)


func _draw_flash(view: Vector2) -> void:
	if _flash_time <= 0.0:
		return
	var strength := _flash_time / 0.35
	var edge := Color(_flash_color, _flash_color.a * strength)
	var clear := Color(_flash_color, 0.0)
	var depth := 180.0
	# Vier Farbverlaeufe an den Raendern.
	for side in 4:
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		match side:
			0:
				points = PackedVector2Array([Vector2(0, 0), Vector2(view.x, 0), Vector2(view.x, depth), Vector2(0, depth)])
				colors = PackedColorArray([edge, edge, clear, clear])
			1:
				points = PackedVector2Array([Vector2(0, view.y - depth), Vector2(view.x, view.y - depth), Vector2(view.x, view.y), Vector2(0, view.y)])
				colors = PackedColorArray([clear, clear, edge, edge])
			2:
				points = PackedVector2Array([Vector2(0, 0), Vector2(depth, 0), Vector2(depth, view.y), Vector2(0, view.y)])
				colors = PackedColorArray([edge, clear, clear, edge])
			3:
				points = PackedVector2Array([Vector2(view.x - depth, 0), Vector2(view.x, 0), Vector2(view.x, view.y), Vector2(view.x - depth, view.y)])
				colors = PackedColorArray([clear, edge, edge, clear])
		_canvas.draw_polygon(points, colors)


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

	# Klassenfaehigkeit (L2): Leiste fuellt sich, bei Bereitschaft leuchtet sie.
	var ability := player.ability
	var ability_bar := Rect2(origin + Vector2(112, 47), Vector2(PANEL_WIDTH - 112.0, 15))
	var ability_color := Color(1.0, 0.85, 0.3) if ability.is_ready() else accent
	Art.rrect(_canvas, ability_bar, Color(0.1, 0.1, 0.14), 5.0)
	var ability_fill := ability.time / float(ability.data.duration) if ability.is_active() else ability.readiness()
	if ability_fill > 0.0:
		Art.rrect(_canvas, Rect2(ability_bar.position, Vector2(maxf(ability_bar.size.x * ability_fill, 8.0), ability_bar.size.y)), ability_color if not ability.is_active() else Color(1, 1, 1), 5.0)
	Art.rrect_line(_canvas, ability_bar, Color(ability_color, 0.8 if ability.is_ready() else 0.35), 5.0, 1.5)
	var ability_text := "L2 %s  BEREIT" % ability.data.name if ability.is_ready() else "L2 %s" % ability.data.name
	_text(ability_bar.position + Vector2(0, 12), ability_text, 12, Color(0.05, 0.06, 0.1) if ability_fill > 0.55 else Color(0.85, 0.88, 0.95), HORIZONTAL_ALIGNMENT_CENTER, ability_bar.size.x)

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


func _draw_boss_bar(view: Vector2, boss: Boss) -> void:
	var width := 620.0
	var bar := Rect2(Vector2(view.x * 0.5 - width * 0.5, 44.0), Vector2(width, 22.0))
	var panel := Rect2(bar.position + Vector2(-16.0, -38.0), Vector2(width + 32.0, 104.0))
	Art.rrect(_canvas, panel, Color(0.04, 0.05, 0.09, 0.78), 12.0)
	Art.rrect_line(_canvas, panel, Color(1.0, 0.45, 0.2, 0.6), 12.0, 2.0)
	_text(Vector2(0, 28), boss.boss_name, 22, Color(1.0, 0.75, 0.35), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	Art.rrect(_canvas, bar, Color(0.1, 0.1, 0.14), 7.0)
	var fraction := clampf(boss.hp / Boss.MAX_HP, 0.0, 1.0)
	var top := Color(1.0, 0.75, 0.3) if boss.open else Color(0.75, 0.78, 0.9)
	var bottom := Color(0.95, 0.35, 0.15) if boss.open else Color(0.45, 0.48, 0.6)
	if fraction > 0.0:
		Art.rrect_grad(_canvas, Rect2(bar.position, Vector2(maxf(bar.size.x * fraction, 8.0), bar.size.y)), top, bottom, 7.0)
	for mark in [0.33, 0.66]:
		_canvas.draw_line(Vector2(bar.position.x + bar.size.x * mark, bar.position.y), Vector2(bar.position.x + bar.size.x * mark, bar.end.y), Color(0, 0, 0, 0.6), 3.0)
	Art.rrect_line(_canvas, bar, Color(1, 1, 1, 0.35), 7.0, 1.5)
	var status := "PANZER GESCHLOSSEN: nur 25 Prozent Schaden" if not boss.open else "KERN OFFEN: voller Schaden"
	if boss.is_invulnerable() and not boss.dying:
		status = "unverwundbar"
	_text(Vector2(0, 78), "%s     Schwach gegen Wasser und Eis" % status, 14, Color(0.85, 0.87, 0.95), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	if boss.banner_time > 0.0:
		var alpha := clampf(boss.banner_time / 0.4, 0.0, 1.0)
		_text(Vector2(0, view.y * 0.3), boss.banner, 46, Color(1.0, 0.8, 0.3, alpha), HORIZONTAL_ALIGNMENT_CENTER, view.x)


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
