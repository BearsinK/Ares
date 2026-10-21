class_name Hud
extends CanvasLayer
## Anzeige: Leben, Dash, Gold, Waffen und Firmware pro Spieler, Wellenzeit,
## Stufe, XP-Leiste, Game-Over-Hinweis und Controller-Diagnose.

const PANEL_WIDTH := 330.0
const PANEL_HEIGHT := 128.0
const HINTS_TIME := 16.0
const TIP_TIME := 7.0
const NOTICE_TIME := 4.0

var main: Node = null
var _canvas: Node2D
var _flash_color := Color(0, 0, 0, 0)
var _flash_time := 0.0
var _age := 0.0
var _tip_id := ""
var _tip_time := 0.0
## Meldungen "Neu im Archiv" unten links, hoechstens drei.
var _notices: Array[Dictionary] = []


func _ready() -> void:
	layer = 10
	# Laeuft auch bei Pause weiter, damit die Anzeige zu den Menues passt.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)
	Tips.queue.clear()


func _process(delta: float) -> void:
	_age += delta
	_flash_time = maxf(0.0, _flash_time - delta)
	_update_tips(delta)
	if not get_tree().paused:
		for notice in _notices:
			notice.t = float(notice.t) - delta
		_notices = _notices.filter(func(n: Dictionary) -> bool: return float(n.t) > 0.0)
	_canvas.queue_redraw()


## Meldet einen neuen Archiv-Eintrag (siehe Archive).
func notice(kind: String, id: String) -> void:
	_notices.append({"kind": kind, "id": id, "name": Archive.entry_name(kind, id), "t": NOTICE_TIME})
	while _notices.size() > 3:
		_notices.pop_front()
	Sfx.play("pickup", 0.0)


## Zeigt wartende Hinweise nacheinander, aber nie waehrend Menues, der Steuerungsuebersicht oder nach dem Ende.
func _update_tips(delta: float) -> void:
	if main == null or get_tree().paused or main.game_over or main.shop_menu.is_open or main.levelup_menu.is_open:
		return
	_tip_time = maxf(0.0, _tip_time - delta)
	if _tip_time > 0.0:
		return
	_tip_id = ""
	if Tips.queue.is_empty() or _hints_visible() or (main.phase != main.Phase.WAVE and main.phase != main.Phase.BOSS):
		return
	_tip_id = Tips.queue.pop_front()
	_tip_time = TIP_TIME
	SaveData.mark_tip(_tip_id)
	Sfx.play("ready", 0.0)


## Farbiger Bildschirmrand-Blitz (z.B. rot bei Treffern).
func flash(color: Color) -> void:
	if SaveData.calm_effects():
		return
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
	if main.shop_menu.is_open:
		# Der Shop zeigt Gold und Waffen selbst, die Spieleranzeige stoert dort nur.
		_draw_xp_bar(view)
		return
	_draw_hints(view)
	_draw_tip(view)
	_draw_notices(view)
	_draw_wave_banner(view)
	_draw_wave_clear(view)
	_draw_player_panels(view)
	if main.boss != null and is_instance_valid(main.boss):
		if not main.shop_menu.is_open and not main.levelup_menu.is_open:
			_draw_boss_bar(view, main.boss)
	elif not main.shop_menu.is_open and not main.levelup_menu.is_open:
		var scale_top := ui_scale(view) * 0.9
		_canvas.draw_set_transform(Vector2(view.x * 0.5 * (1.0 - scale_top), 6.0), 0.0, Vector2(scale_top, scale_top))
		_draw_top_center(view)
		_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_perk_strip(view)
	_draw_perk_banner(view)
	_draw_chest_markers(view)
	_draw_downed_markers(view)
	_draw_guardian(view)
	_draw_stage_banner(view)
	_draw_xp_bar(view)
	_draw_debug(view)


## Weicher Ein- und Ausstieg: 0 bis 1 ueber die Dauer fade, dann bleibt es bei 1.
static func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


## Wellenstart: Letterbox, einfliegender Titel mit Modifikator, Countdown 3 2 1 und LOS.
func _draw_wave_banner(view: Vector2) -> void:
	if main.phase != main.Phase.WAVE:
		return
	if main.wave_go > 0.0:
		var k: float = 1.0 - float(main.wave_go) / 0.7
		var size := int(120.0 + 60.0 * k)
		_text(Vector2(0, view.y * 0.5 + 40.0), "LOS!", size, Color(1.0, 0.9, 0.4, 1.0 - k), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	if main.wave_intro <= 0.0:
		return
	var elapsed: float = main.WAVE_INTRO - main.wave_intro
	var bars := minf(_ease_out(elapsed / 0.4), _ease_out(main.wave_intro / 0.4))
	var bar_height := 64.0 * bars
	_canvas.draw_rect(Rect2(0, 0, view.x, bar_height), Color(0, 0, 0, 0.85))
	_canvas.draw_rect(Rect2(0, view.y - bar_height, view.x, bar_height), Color(0, 0, 0, 0.85))
	var last: bool = main.wave >= main.max_waves
	var title := "LETZTE WELLE" if last else "WELLE %d" % main.wave
	var slide := (1.0 - _ease_out(elapsed / 0.55)) * -view.x * 0.6
	var alpha := clampf(main.wave_intro / 0.35, 0.0, 1.0)
	var title_color := Color(1.0, 0.55, 0.3, alpha) if last else Color(1.0, 0.92, 0.55, alpha)
	_text(Vector2(slide + 4.0, view.y * 0.26 + 4.0), title, 96, Color(0, 0, 0, 0.5 * alpha), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	_text(Vector2(slide, view.y * 0.26), title, 96, title_color, HORIZONTAL_ALIGNMENT_CENTER, view.x)
	if main.wave_modifier != "normal":
		var info: Dictionary = WaveModifiers.DATA[main.wave_modifier]
		var pop := _ease_out((elapsed - 0.5) / 0.35)
		_text(Vector2(0, view.y * 0.26 + 56.0), String(info.name), int(36.0 + 14.0 * pop), Color(1.0, 0.65, 0.25, alpha * pop), HORIZONTAL_ALIGNMENT_CENTER, view.x)
		_text(Vector2(0, view.y * 0.26 + 92.0), String(info.text), 22, Color(0.95, 0.95, 1.0, alpha * pop), HORIZONTAL_ALIGNMENT_CENTER, view.x)
		if main.contract_bonus > 0.0:
			_text(Vector2(0, view.y * 0.26 + 122.0), "Prämie: +%d%% Gold" % int(round(float(main.contract_bonus) * 100.0)), 22, Color(1.0, 0.85, 0.3, alpha * pop), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	# Countdown: jede Zahl poppt gross auf und schrumpft.
	if main.wave_intro <= 3.0:
		var number := int(ceil(main.wave_intro))
		var frac: float = 1.0 - (float(main.wave_intro) - float(number - 1))
		var size := int(150.0 - 50.0 * _ease_out(frac * 1.5))
		_text(Vector2(0, view.y * 0.55 + 40.0), str(number), size, Color(1, 1, 1, 0.65 * clampf(1.2 - frac * 0.5, 0.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, view.x)


## Wellenende: grosses WELLE GESCHAFFT mit Aufpoppen, Zusammenfassung und Bonus.
func _draw_wave_clear(view: Vector2) -> void:
	if main.phase != main.Phase.CLEARING:
		return
	var elapsed: float = main.CLEAR_DELAY - main._clear_time
	var remaining: float = main._clear_time
	var fade := clampf(remaining / 0.4, 0.0, 1.0)
	var pop := _ease_out(elapsed / 0.35)
	var overshoot := 1.0 + 0.25 * sin(clampf(elapsed / 0.35, 0.0, 1.0) * PI)
	var y := view.y * 0.22
	# Leuchtband hinter dem Titel.
	var band := Rect2(0, y - 20.0, view.x * pop, 110.0)
	_canvas.draw_rect(band, Color(0.05, 0.04, 0.0, 0.55 * fade))
	_canvas.draw_rect(Rect2(0, y - 22.0, view.x * pop, 3.0), Color(1.0, 0.85, 0.3, 0.9 * fade))
	_canvas.draw_rect(Rect2(0, y + 88.0, view.x * pop, 3.0), Color(1.0, 0.85, 0.3, 0.9 * fade))
	_text(Vector2(0, y + 66.0 - 8.0 * overshoot), "WELLE %d GESCHAFFT!" % main.wave, int(78.0 * overshoot), Color(1.0, 0.9, 0.4, fade), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	var info_alpha := _ease_out((elapsed - 0.45) / 0.3) * fade
	_text(Vector2(0, y + 140.0), "Besiegt: %d      Bonus: +%d Gold" % [main.wave_kills, main.wave_bonus], 28, Color(0.95, 0.96, 1.0, info_alpha), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	var next := "Als Nächstes: der Endboss" if main.wave >= main.max_waves else "Gleich öffnet der Shop"
	_text(Vector2(0, y + 178.0), next, 20, Color(0.7, 0.75, 0.9, info_alpha), HORIZONTAL_ALIGNMENT_CENTER, view.x)


## Die Steuerungsuebersicht steht in der ersten Welle die ersten Sekunden.
func _hints_visible() -> bool:
	return _age <= HINTS_TIME and main.wave <= 1 and main.phase == main.Phase.WAVE and not main.levelup_menu.is_open and not main.shop_menu.is_open


func _draw_hints(view: Vector2) -> void:
	if not _hints_visible():
		return
	var visible_time := HINTS_TIME
	var alpha := clampf(minf(_age / 0.6, (visible_time - _age) / 1.5), 0.0, 1.0)
	var panel := Rect2(Vector2(view.x * 0.5 - 430.0, view.y - 190.0), Vector2(860.0, 112.0))
	Art.rrect(_canvas, panel, Color(0.04, 0.05, 0.09, 0.8 * alpha), 14.0)
	Art.rrect_line(_canvas, panel, Color(1, 1, 1, 0.25 * alpha), 14.0, 2.0)
	_text(panel.position + Vector2(0, 28), "STEUERUNG", 16, Color(1.0, 0.85, 0.4, alpha), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	_text(panel.position + Vector2(0, 56), "Controller: R2 schießen   R1 Dash   L1 Sprung   Quadrat Fähigkeit   L2 Haken   Dreieck Waffe   Kreis Partner beleben", 15, Color(0.9, 0.92, 1.0, alpha), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	_text(panel.position + Vector2(0, 80), "Tastatur P1: WASD, Maus, Leertaste, Shift, E     P2: Pfeile, Punkt, Strich, Komma     F11 Vollbild", 15, Color(0.7, 0.74, 0.9, alpha), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	_text(panel.position + Vector2(0, 102), "Je weiter ihr kommt, desto mehr Chips gibt es für die Garage.", 13, Color(0.6, 0.95, 1.0, alpha * 0.9), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)


## Einmaliger Hinweis (siehe Tips): Tafel unten in der Mitte, gleicher Platz wie die Steuerungsuebersicht.
func _draw_tip(view: Vector2) -> void:
	if _tip_id == "" or _tip_time <= 0.0 or not Tips.DATA.has(_tip_id):
		return
	var info: Dictionary = Tips.DATA[_tip_id]
	var alpha := clampf(minf((TIP_TIME - _tip_time) / 0.4, _tip_time / 0.6), 0.0, 1.0)
	var panel := Rect2(Vector2(view.x * 0.5 - 380.0, view.y - 190.0 + (1.0 - alpha) * 16.0), Vector2(760.0, 96.0))
	Art.rrect(_canvas, panel, Color(0.04, 0.05, 0.09, 0.88 * alpha), 14.0)
	Art.rrect_line(_canvas, panel, Color(0.5, 0.85, 1.0, 0.8 * alpha), 14.0, 2.0)
	_canvas.draw_rect(Rect2(panel.position + Vector2(20.0, 0.0), Vector2(90.0, 4.0)), Color(0.5, 0.85, 1.0, alpha))
	_text(panel.position + Vector2(24.0, 30.0), "HINWEIS   %s" % String(info.title), 17, Color(0.6, 0.92, 1.0, alpha))
	UiKit.text(_canvas, panel.position + Vector2(24.0, 58.0), String(info.text), 19, Color(0.94, 0.96, 1.0, alpha), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 48.0, true)


## Kleine Tafeln unten links: "Neu im Archiv" mit Namen des Eintrags.
func _draw_notices(view: Vector2) -> void:
	for i in _notices.size():
		var notice := _notices[_notices.size() - 1 - i]
		var t: float = notice.t
		var alpha := clampf(minf((NOTICE_TIME - t) / 0.25, t / 0.5), 0.0, 1.0)
		var slide := (1.0 - alpha) * -40.0
		var plate := Rect2(Vector2(18.0 + slide, view.y - 130.0 - i * 54.0), Vector2(320.0, 46.0))
		Art.rrect(_canvas, plate, Color(0.04, 0.05, 0.09, 0.86 * alpha), 10.0)
		Art.rrect_line(_canvas, plate, Color(0.5, 0.85, 1.0, 0.7 * alpha), 10.0, 2.0)
		var achievement: bool = notice.kind == "achievements"
		var accent := Color(1.0, 0.85, 0.35) if achievement else Color(0.6, 0.92, 1.0)
		if achievement:
			Art.rrect_line(_canvas, plate, Color(accent, 0.8 * alpha), 10.0, 2.0)
		var header := "ERFOLG  +%d Chips" % int(Achievements.DATA[notice.id].chips) if achievement else "NEU IM ARCHIV"
		_text(plate.position + Vector2(16.0, 18.0), header, 12, Color(accent, alpha))
		_text(plate.position + Vector2(16.0, 38.0), String(notice.name), 19, Color(1.0, 1.0, 1.0, alpha))


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


## Groesse der Anzeige: waechst mit der Fensterhoehe (Basis 1,4x bei 900 px).
func ui_scale(view: Vector2) -> float:
	return clampf(view.y / 900.0, 0.8, 1.7) * 1.4


## Beide Spielerpanels, vergroessert. Ein Treffer laesst das Panel des Getroffenen rot aufblitzen und wackeln.
func _draw_player_panels(view: Vector2) -> void:
	var s := ui_scale(view)
	var width := (PANEL_WIDTH + 20.0) * s
	for i in 2:
		var player: Player = main.players[i]
		var x := 18.0 if i == 0 else view.x - width - 18.0
		var shake := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 6.0 * player.hurt_amount() * SaveData.shake_scale()
		_canvas.draw_set_transform(Vector2(x, 12.0) + shake, 0.0, Vector2(s, s))
		_draw_player_panel(player, Vector2(10.0, 8.0))
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_player_panel(player: Player, origin: Vector2) -> void:
	var accent: Color = RobotClasses.PLAYER_COLORS[player.player_index - 1]
	var panel := Rect2(origin + Vector2(-10, -8), Vector2(PANEL_WIDTH + 20.0, PANEL_HEIGHT))
	var hurt := player.hurt_amount()
	Art.rrect(_canvas, panel, Color(0.04, 0.05, 0.09, 0.8).lerp(Color(0.5, 0.05, 0.05, 0.9), hurt), 12.0)
	Art.rrect_line(_canvas, panel, Color(accent, 0.7).lerp(Color(1.0, 0.25, 0.2), hurt), 12.0, 2.0 + 2.0 * hurt)
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
	if player.shield > 0.0:
		# Schild: cyanfarbene Leiste ueber der Lebensleiste, im Massstab der Leben.
		var shield_width := minf(bar.size.x * player.shield / player.max_health(), bar.size.x)
		Art.rrect(_canvas, Rect2(bar.position + Vector2(0, -4), Vector2(maxf(shield_width, 6.0), 5.0)), Color(0.5, 0.88, 1.0), 2.5)
	_text(origin + Vector2(8, 41), "%d / %d" % [int(ceil(player.hp)), int(player.max_health())], 13, Color(1, 1, 1, 0.95))

	# Dash-Aufladungen als Kapseln.
	for i in player.dash_max():
		var pill := Rect2(origin + Vector2(i * 22.0, 52), Vector2(18, 7))
		Art.rrect(_canvas, pill, accent if i < player.dash_charges else Color(1, 1, 1, 0.14), 3.0)

	# Klassenfaehigkeit (Quadrat): Leiste fuellt sich, bei Bereitschaft leuchtet sie.
	var ability := player.ability
	var ability_bar := Rect2(origin + Vector2(138, 47), Vector2(PANEL_WIDTH - 138.0, 15))
	var ability_color := Color(1.0, 0.85, 0.3) if ability.is_ready() else accent
	Art.rrect(_canvas, ability_bar, Color(0.1, 0.1, 0.14), 5.0)
	var ability_fill := ability.time / float(ability.data.duration) if ability.is_active() else ability.readiness()
	if ability_fill > 0.0:
		Art.rrect(_canvas, Rect2(ability_bar.position, Vector2(maxf(ability_bar.size.x * ability_fill, 8.0), ability_bar.size.y)), ability_color if not ability.is_active() else Color(1, 1, 1), 5.0)
	Art.rrect_line(_canvas, ability_bar, Color(ability_color, 0.8 if ability.is_ready() else 0.35), 5.0, 1.5)
	# Tastensymbol (Quadrat) vor der Leiste, leuchtet bei Bereitschaft.
	var key_rect := Rect2(ability_bar.position + Vector2(-24, 0), Vector2(18, 15))
	var key_pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 160.0) if ability.is_ready() else 0.4
	Art.rrect_line(_canvas, key_rect, Color(1.0, 0.55, 0.8, key_pulse), 4.0, 2.0)
	_text(origin + Vector2(48, 60), "Fähigkeit", 12, Color(0.7, 0.74, 0.9))
	var ability_text := "%s  BEREIT" % ability.data.name if ability.is_ready() else "%s" % ability.data.name
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
		_draw_ammo_strip(player, i, chip)
		x += width + 6.0
	# Zahl der aktiven Waffe hinter den Chips.
	var count_color := Color(1.0, 0.8, 0.3) if player.is_reloading() else (Color(1.0, 0.45, 0.35) if player.ammo_of(player.weapon_index) * 4 <= player.ammo_max_of(player.weapon_index) else Color(0.85, 0.92, 1.0))
	var count_text := "Nachladen" if player.is_reloading() else "%d / %d" % [player.ammo_of(player.weapon_index), player.ammo_max_of(player.weapon_index)]
	var held := Weapons.get_weapon(player.current_weapon_id())
	_text(origin + Vector2(0, 85), count_text, 16, count_color, HORIZONTAL_ALIGNMENT_RIGHT, PANEL_WIDTH - 10.0)
	# Minen und Tuerme in der Welt: eigene Zeile rechts unter den Chips, damit nichts ueberlappt.
	if held.kind == "deploy" and not player.downed:
		_text(origin + Vector2(0, 110), "%d aktiv" % player.deployed_count(String(held.entity)), 14, Color(0.6, 1.0, 0.78), HORIZONTAL_ALIGNMENT_RIGHT, PANEL_WIDTH - 10.0)

	# Firmware.
	var fw_parts: Array[String] = []
	for id in player.firmware:
		var count: int = player.firmware[id]
		fw_parts.append(Firmware.SHORT[id] + (" x%d" % count if count > 1 else ""))
	if not fw_parts.is_empty():
		_text(origin + Vector2(0, 122), "  ".join(fw_parts), 13, Color(0.55, 0.92, 0.7), HORIZONTAL_ALIGNMENT_RIGHT, PANEL_WIDTH)
	if player.downed:
		_text(origin + Vector2(0, 108), "AM BODEN: Partner hält Interagieren", 14, Color(1.0, 0.5, 0.4))
	else:
		# Persoenliche Items (Shop, Kisten) als Symbole mit Zaehler.
		var item_x := 12.0
		var shown := 0
		for id in player.items:
			if shown >= 10:
				_text(origin + Vector2(item_x - 8.0, 108.0), "+%d" % (player.items.size() - shown), 14, Color(0.85, 0.88, 0.97))
				break
			var item_center := origin + Vector2(item_x, 100.0)
			PerkArt.draw(_canvas, id, item_center, 22.0)
			var count: int = player.items[id]
			if count > 1:
				_text(item_center + Vector2(7.0, 12.0), "x%d" % count, 12, Color(1.0, 0.95, 0.6))
			item_x += 30.0
			shown += 1


## Munition als schmaler Streifen am unteren Rand des Waffenchips: gefuellt = Magazin, beim Nachladen waechst er gelb.
func _draw_ammo_strip(player: Player, index: int, chip: Rect2) -> void:
	var strip := Rect2(chip.position + Vector2(4.0, chip.size.y - 5.0), Vector2(chip.size.x - 8.0, 3.0))
	_canvas.draw_rect(strip, Color(0, 0, 0, 0.5))
	var maximum := maxi(player.ammo_max_of(index), 1)
	if player.is_reloading(index):
		_canvas.draw_rect(Rect2(strip.position, Vector2(strip.size.x * player.reload_ratio(index), strip.size.y)), Color(1.0, 0.8, 0.3))
		return
	var fraction := float(player.ammo_of(index)) / float(maximum)
	var tint := Color(0.55, 0.9, 1.0) if fraction > 0.25 else Color(1.0, 0.4, 0.3)
	_canvas.draw_rect(Rect2(strip.position, Vector2(strip.size.x * fraction, strip.size.y)), tint)


func _draw_boss_bar(view: Vector2, boss: Boss) -> void:
	# Passt zwischen die beiden Spielerpanels, damit nichts ueberdeckt wird.
	var free := view.x - 2.0 * ((PANEL_WIDTH + 20.0) * ui_scale(view) + 24.0)
	var width := clampf(free - 40.0, 340.0, 620.0)
	var bar := Rect2(Vector2(view.x * 0.5 - width * 0.5, 44.0), Vector2(width, 22.0))
	var panel := Rect2(bar.position + Vector2(-16.0, -38.0), Vector2(width + 32.0, 104.0))
	Art.rrect(_canvas, panel, Color(0.04, 0.05, 0.09, 0.78), 12.0)
	Art.rrect_line(_canvas, panel, Color(1.0, 0.45, 0.2, 0.6), 12.0, 2.0)
	_text(Vector2(0, 28), boss.boss_name, 22, Color(1.0, 0.75, 0.35), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	Art.rrect(_canvas, bar, Color(0.1, 0.1, 0.14), 7.0)
	var fraction := clampf(boss.hp / boss.max_hp, 0.0, 1.0)
	var top := Color(1.0, 0.75, 0.3) if boss.open else Color(0.75, 0.78, 0.9)
	var bottom := Color(0.95, 0.35, 0.15) if boss.open else Color(0.45, 0.48, 0.6)
	if fraction > 0.0:
		Art.rrect_grad(_canvas, Rect2(bar.position, Vector2(maxf(bar.size.x * fraction, 8.0), bar.size.y)), top, bottom, 7.0)
	for mark in [0.33, 0.66]:
		_canvas.draw_line(Vector2(bar.position.x + bar.size.x * mark, bar.position.y), Vector2(bar.position.x + bar.size.x * mark, bar.end.y), Color(0, 0, 0, 0.6), 3.0)
	Art.rrect_line(_canvas, bar, Color(1, 1, 1, 0.35), 7.0, 1.5)
	var status := "PANZER ZU: nur 25 % Schaden" if not boss.open else "KERN OFFEN: voller Schaden"
	if boss.is_invulnerable() and not boss.dying:
		status = "unverwundbar"
	_text(Vector2(0, 78), "%s   Schwach: Hydro, Cryo" % status, 14, Color(0.85, 0.87, 0.95), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	if boss.banner_time > 0.0:
		var alpha := clampf(boss.banner_time / 0.4, 0.0, 1.0)
		_text(Vector2(0, view.y * 0.3), boss.banner, 46, Color(1.0, 0.8, 0.3, alpha), HORIZONTAL_ALIGNMENT_CENTER, view.x)


func _draw_top_center(view: Vector2) -> void:
	var title := "Welle %d   ENDLOS" % main.wave if main.endless else "Welle %d / %d" % [main.wave, main.max_waves]
	if main.wave_modifier != "normal":
		title += "  " + String(WaveModifiers.DATA[main.wave_modifier].name)
	var remaining := int(ceil(maxf(main.wave_time_left, 0.0)))
	var clock := "%02d:%02d" % [remaining / 60, remaining % 60]
	if main.phase == main.Phase.CLEARING:
		clock = "Geschafft!"
	elif main.overtime > 0.0:
		clock = "Wächter!" if fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.0 else "00:00"
	if main.sandbox:
		_text(Vector2(0, 104), "SANDBOX", 14, Color(1.0, 0.85, 0.4), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	elif String(Meta.difficulty_data().id) != "normal":
		var hard := String(Meta.difficulty_data().id) == "hard"
		_text(Vector2(0, 104), String(Meta.difficulty_data().name).to_upper(), 14, Color(1.0, 0.5, 0.4) if hard else Color(0.6, 0.9, 0.7), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	var panel := Rect2(Vector2(view.x * 0.5 - 130.0, 8.0), Vector2(260.0, 82.0))
	Art.rrect(_canvas, panel, Color(0.04, 0.05, 0.09, 0.72), 12.0)
	Art.rrect_line(_canvas, panel, Color(1, 1, 1, 0.2), 12.0, 2.0)
	_text(Vector2(0, 30), title, 17, Color(0.8, 0.82, 0.95), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	_text(Vector2(0, 62), clock, 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, view.x)
	_text(Vector2(0, 82), "Stufe %d     Gegner %d" % [main.level, main.director.alive_count()], 14, Color(0.7, 0.72, 0.85), HORIZONTAL_ALIGNMENT_CENTER, view.x)


## Reihe der bisher gewaehlten Team-Perks (Symbol und Anzahl) unter der Wellenanzeige.
func _draw_perk_strip(view: Vector2) -> void:
	if main.perks_taken.is_empty() or main.shop_menu.is_open or main.levelup_menu.is_open:
		return
	var s := ui_scale(view)
	var count: int = main.perks_taken.size()
	var step := 44.0 * s * 0.8
	var start := Vector2(view.x * 0.5 - (count - 1) * step * 0.5, ui_scale(view) * 90.0 + 14.0)
	var index := 0
	for id in main.perks_taken:
		var center := start + Vector2(index * step, 0.0)
		Art.rrect(_canvas, Rect2(center - Vector2(step * 0.46, step * 0.46), Vector2(step * 0.92, step * 0.92)), Color(0.04, 0.05, 0.09, 0.7), 8.0)
		PerkArt.draw(_canvas, id, center, step * 0.7)
		var amount: int = main.perks_taken[id]
		if amount > 1:
			_text(center + Vector2(step * 0.1, step * 0.45), "x%d" % amount, 15, Color(1.0, 0.95, 0.6))
		index += 1


## Nach der Wahl: Name und Wirkung des Perks gross in der Bildmitte oben.
func _draw_perk_banner(view: Vector2) -> void:
	if main.perk_banner_time <= 0.0 or main.perk_banner_id == "":
		return
	var t: float = main.perk_banner_time
	var alpha := clampf(minf(t / 0.5, (3.0 - t) / 0.2), 0.0, 1.0)
	var pop := _ease_out((3.0 - t) / 0.3)
	var id: String = main.perk_banner_id
	var color := PerkArt.color_of(id)
	var y := view.y * 0.2
	var panel := Rect2(Vector2(view.x * 0.5 - 330.0, y), Vector2(660.0, 120.0 * pop))
	Art.rrect(_canvas, panel, Color(0.04, 0.05, 0.09, 0.85 * alpha), 14.0)
	Art.rrect_line(_canvas, panel, Color(color, alpha), 14.0, 3.0)
	if pop > 0.9:
		PerkArt.draw(_canvas, id, panel.position + Vector2(70.0, 60.0), 70.0)
		_text(panel.position + Vector2(130.0, 44.0), "UPGRADE: %s" % String(Perks.DATA[id].name), 34, Color(1.0, 0.95, 0.7, alpha))
		_text(panel.position + Vector2(130.0, 82.0), "Für beide Roboter, je nach Klasse", 20, Color(0.8, 0.84, 0.95, alpha))


## Kisten ausserhalb des Bildes: Pfeil am Bildrand mit Preis, golden wenn ein Spieler sie bezahlen kann.
func _draw_chest_markers(view: Vector2) -> void:
	if main.chests == null or main.phase == main.Phase.SHOP or main.levelup_menu.is_open:
		return
	var xf: Transform2D = main.get_viewport().get_canvas_transform()
	var inner := Rect2(Vector2(70.0, 200.0), view - Vector2(140.0, 330.0))
	for chest in main.chests.get_children():
		if not (chest is Chest) or chest is Altar or chest.is_open:
			continue
		var screen: Vector2 = xf * (chest.global_position + Vector2(0.0, -30.0))
		if inner.has_point(screen):
			continue
		var edge := Vector2(clampf(screen.x, inner.position.x, inner.end.x), clampf(screen.y, inner.position.y, inner.end.y))
		var dir := (screen - edge).normalized() if screen != edge else Vector2.UP
		var affordable := false
		for player in main.players:
			if player.gold >= chest.price:
				affordable = true
		var color := Color(1.0, 0.82, 0.3) if affordable else Color(0.62, 0.64, 0.72)
		if chest.large:
			color = Color(1.0, 0.7, 0.2) if affordable else Color(0.75, 0.62, 0.4)
		var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() / 220.0)
		var plate := Rect2(edge - Vector2(26.0, 14.0), Vector2(52.0, 28.0))
		Art.rrect(_canvas, plate, Color(0.04, 0.05, 0.09, 0.85), 8.0)
		Art.rrect_line(_canvas, plate, Color(color, 0.9), 8.0, 2.0)
		_canvas.draw_circle(plate.position + Vector2(14, 14), 5.5 * pulse, color)
		_text(plate.position + Vector2(24, 19), "%d" % chest.price, 14, color)
		var tip := edge + dir * 30.0
		var side := dir.orthogonal() * 9.0
		_canvas.draw_colored_polygon(PackedVector2Array([tip + dir * 8.0, tip - dir * 4.0 + side, tip - dir * 4.0 - side]), Color(color, 0.95))


## Gefallener Partner ausserhalb des Bildes: Pfeil am Rand in seiner Farbe, pulsiert rot, der Ring zeigt das Wiederbeleben.
## Die Kamera folgt Gefallenen nicht, darum muss man wissen, wohin man laufen muss.
func _draw_downed_markers(view: Vector2) -> void:
	if main.shop_menu.is_open or main.levelup_menu.is_open or main.game_over:
		return
	var xf: Transform2D = main.get_viewport().get_canvas_transform()
	var inner := Rect2(Vector2(70.0, 200.0), view - Vector2(140.0, 330.0))
	for player in main.players:
		if not player.downed:
			continue
		var screen: Vector2 = xf * (player.global_position + Vector2(0.0, -30.0))
		if inner.has_point(screen):
			continue
		var edge := Vector2(clampf(screen.x, inner.position.x, inner.end.x), clampf(screen.y, inner.position.y, inner.end.y))
		var dir := (screen - edge).normalized() if screen != edge else Vector2.UP
		var accent: Color = RobotClasses.PLAYER_COLORS[player.player_index - 1]
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
		var plate := Rect2(edge - Vector2(44.0, 18.0), Vector2(88.0, 36.0))
		Art.rrect(_canvas, plate, Color(0.12, 0.03, 0.04, 0.92), 9.0)
		Art.rrect_line(_canvas, plate, Color(1.0, 0.3 + 0.2 * pulse, 0.3, 0.6 + 0.4 * pulse), 9.0, 2.5)
		_canvas.draw_circle(plate.position + Vector2(18.0, 18.0), 8.0, Color(0.05, 0.05, 0.08))
		_canvas.draw_arc(plate.position + Vector2(18.0, 18.0), 8.0, -PI / 2.0, -PI / 2.0 + TAU * maxf(player.revive_progress, 0.02), 24, Color(0.4, 1.0, 0.5) if player.revive_progress > 0.0 else Color(1, 1, 1, 0.3), 3.0, true)
		_text(plate.position + Vector2(32.0, 25.0), "P%d" % player.player_index, 18, accent.lightened(0.2))
		var tip := edge + dir * 36.0
		var side := dir.orthogonal() * 11.0
		_canvas.draw_colored_polygon(PackedVector2Array([tip + dir * 10.0, tip - dir * 5.0 + side, tip - dir * 5.0 - side]), Color(1.0, 0.35, 0.3, 0.7 + 0.3 * pulse))


## Neue Karte: Name und Charakter unten in der Mitte, solange der Wellen-Einstieg laeuft.
func _draw_stage_banner(view: Vector2) -> void:
	if main.stage_banner_time <= 0.0 or main.stage_layout.is_empty() or main.shop_menu.is_open or main.levelup_menu.is_open:
		return
	var t: float = main.stage_banner_time
	var alpha := clampf(minf(t / 0.6, (3.2 - t) / 0.4), 0.0, 1.0)
	var y := view.y * 0.69
	_canvas.draw_rect(Rect2(0, y - 52.0, view.x, 92.0), Color(0, 0, 0, 0.5 * alpha))
	_text(Vector2(0, y), String(main.stage_layout.name).to_upper(), 44, Color(1.0, 0.9, 0.55, alpha), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	_text(Vector2(0, y + 28.0), String(main.stage_layout.get("text", "")), 20, Color(0.9, 0.92, 1.0, alpha), HORIZONTAL_ALIGNMENT_CENTER, view.x)


## Waechter: Banner beim Erscheinen, Lebensleiste oben in der Mitte und ein Pfeil am Rand, wenn er ausserhalb des Bildes ist.
func _draw_guardian(view: Vector2) -> void:
	if main.shop_menu.is_open or main.levelup_menu.is_open:
		return
	if main.guardian_banner_time > 0.0:
		var t: float = main.guardian_banner_time
		var alpha := clampf(minf(t / 0.5, (3.4 - t) / 0.25), 0.0, 1.0)
		var pop := 1.0 + 0.2 * (1.0 - _ease_out((3.4 - t) / 0.3))
		_text(Vector2(0, view.y * 0.34 + 3.0), "WÄCHTER ERSCHEINT", int(64.0 * pop), Color(0, 0, 0, 0.55 * alpha), HORIZONTAL_ALIGNMENT_CENTER, view.x)
		_text(Vector2(0, view.y * 0.34), "WÄCHTER ERSCHEINT", int(64.0 * pop), Color(1.0, 0.4, 0.3, alpha), HORIZONTAL_ALIGNMENT_CENTER, view.x)
		_text(Vector2(0, view.y * 0.34 + 40.0), "Besiegt ihn für eine Goldkiste und Reparatur", 22, Color(1.0, 0.92, 0.85, alpha), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	var guardian: Enemy = main.guardian
	if guardian == null or not is_instance_valid(guardian):
		return
	var kind_info: Dictionary = EnemyTypes.ELITE_KINDS.get(guardian.elite_kind, {"name": "", "color": Color(1.0, 0.5, 0.3)})
	var accent: Color = kind_info.color
	var width := 460.0
	var bar := Rect2(Vector2(view.x * 0.5 - width * 0.5, 204.0), Vector2(width, 18.0))
	Art.rrect(_canvas, bar.grow(3.0), Color(0.04, 0.05, 0.09, 0.85), 8.0)
	var fraction := clampf(guardian.hp / guardian.max_hp, 0.0, 1.0)
	Art.rrect(_canvas, bar, Color(0.1, 0.1, 0.14), 6.0)
	if fraction > 0.0:
		Art.rrect_grad(_canvas, Rect2(bar.position, Vector2(maxf(bar.size.x * fraction, 8.0), bar.size.y)), accent.lightened(0.2), accent.darkened(0.3), 6.0)
	if guardian.shield > 0.0:
		_canvas.draw_rect(Rect2(bar.position + Vector2(0, -3), Vector2(bar.size.x * clampf(guardian.shield / guardian.max_shield, 0.0, 1.0), 4.0)), Color(0.5, 0.88, 1.0))
	Art.rrect_line(_canvas, bar, Color(1, 1, 1, 0.4), 6.0, 1.5)
	_text(Vector2(0, bar.position.y - 6.0), "WÄCHTER  %s  %s" % [String(guardian.data.name).to_upper(), String(kind_info.name)], 17, accent.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	# Pfeil am Bildrand, solange er nicht zu sehen ist.
	var xf: Transform2D = main.get_viewport().get_canvas_transform()
	var inner := Rect2(Vector2(70.0, 240.0), view - Vector2(140.0, 370.0))
	var screen: Vector2 = xf * guardian.global_position
	if not inner.has_point(screen):
		var edge := Vector2(clampf(screen.x, inner.position.x, inner.end.x), clampf(screen.y, inner.position.y, inner.end.y))
		var dir := (screen - edge).normalized() if screen != edge else Vector2.UP
		var plate := Rect2(edge - Vector2(22.0, 14.0), Vector2(44.0, 28.0))
		Art.rrect(_canvas, plate, Color(0.1, 0.03, 0.04, 0.9), 8.0)
		Art.rrect_line(_canvas, plate, Color(1.0, 0.35, 0.3), 8.0, 2.0)
		_text(plate.position + Vector2(0, 21), "W", 18, Color(1.0, 0.5, 0.4), HORIZONTAL_ALIGNMENT_CENTER, plate.size.x)
		var tip := edge + dir * 28.0
		var side := dir.orthogonal() * 9.0
		_canvas.draw_colored_polygon(PackedVector2Array([tip + dir * 8.0, tip - dir * 4.0 + side, tip - dir * 4.0 - side]), Color(1.0, 0.4, 0.35))


func _draw_xp_bar(view: Vector2) -> void:
	var bar := Rect2(Vector2(view.x * 0.5 - 420.0, view.y - 38.0), Vector2(840.0, 18.0))
	var fraction := clampf(float(main.xp) / float(main.xp_needed), 0.0, 1.0)
	Art.rrect(_canvas, bar.grow(2.0), Color(0.03, 0.04, 0.08, 0.8), 8.0)
	if fraction > 0.0:
		Art.rrect_grad(_canvas, Rect2(bar.position, Vector2(maxf(bar.size.x * fraction, 8.0), bar.size.y)), Color(0.55, 0.8, 1.0), Color(0.25, 0.5, 0.95), 6.0)
		Art.glow(_canvas, bar.position + Vector2(bar.size.x * fraction, 6), 10.0, Color(0.4, 0.7, 1.0))
	Art.rrect_line(_canvas, bar.grow(2.0), Color(1, 1, 1, 0.3), 8.0, 1.5)
	_text(bar.position + Vector2(-100, 16), "Stufe %d" % main.level, 20, Color(0.75, 0.85, 1.0))
	_text(bar.position + Vector2(bar.size.x + 14.0, 16), "%d / %d XP" % [main.xp, main.xp_needed], 16, Color(0.65, 0.78, 0.95))


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
