extends Node2D
## Titelbildschirm mit Hauptmenue, Klassenauswahl fuer beide Spieler und
## Steuerungsuebersicht. Startet danach die Hauptszene.

enum State { MAIN, SELECT, CONTROLS, STARTING }

const MENU_ITEMS: Array[String] = ["Spielen", "Steuerung", "Beenden"]
const COUNTDOWN := 1.1

var state := State.MAIN
var cursor := 0
var picks: Array[int] = [0, 1]
var locked: Array[bool] = [false, false]
var start_timer := 0.0

var _time := 0.0
var _camera: Camera2D
var _stage: Node2D
var _ui: Node2D


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.06, 0.1))
	var backdrop := Backdrop.new()
	add_child(backdrop)
	_camera = Camera2D.new()
	_camera.position = Vector2(1600, 800)
	add_child(_camera)
	backdrop.camera = _camera
	_stage = Node2D.new()
	_stage.draw.connect(_draw_stage)
	add_child(_stage)
	add_child(Vignette.new())
	var layer := CanvasLayer.new()
	layer.layer = 10
	_ui = Node2D.new()
	_ui.draw.connect(_draw_ui)
	layer.add_child(_ui)
	add_child(layer)
	# Zuletzt gewaehlte Klassen vorbelegen.
	var classes: Array = Engine.get_meta("classes", ["roomba", "hexapod"])
	for i in 2:
		picks[i] = maxi(0, UiKit.CLASS_ORDER.find(classes[i]))


func _process(delta: float) -> void:
	_time += delta
	_camera.position.x = 1600.0 + sin(_time * 0.12) * 500.0
	match state:
		State.MAIN:
			_update_main()
		State.SELECT:
			_update_select(delta)
		State.CONTROLS:
			if UiKit.back() or UiKit.confirm():
				state = State.MAIN
	_stage.queue_redraw()
	_ui.queue_redraw()


func _update_main() -> void:
	if UiKit.pressed("up"):
		cursor = (cursor + MENU_ITEMS.size() - 1) % MENU_ITEMS.size()
		Sfx.play("switch")
	if UiKit.pressed("down"):
		cursor = (cursor + 1) % MENU_ITEMS.size()
		Sfx.play("switch")
	if UiKit.confirm():
		Sfx.play("pickup")
		match cursor:
			0:
				state = State.SELECT
				locked = [false, false]
			1:
				state = State.CONTROLS
			2:
				get_tree().quit()


func _update_select(delta: float) -> void:
	if start_timer > 0.0:
		start_timer -= delta
		if start_timer <= 0.0:
			var classes: Array = []
			for i in 2:
				classes.append(UiKit.CLASS_ORDER[picks[i]])
			Engine.set_meta("classes", classes)
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	for i in 2:
		var prefix := "p%d_" % (i + 1)
		if not locked[i]:
			if Input.is_action_just_pressed(prefix + "left"):
				picks[i] = (picks[i] + UiKit.CLASS_ORDER.size() - 1) % UiKit.CLASS_ORDER.size()
				Sfx.play("switch")
			if Input.is_action_just_pressed(prefix + "right"):
				picks[i] = (picks[i] + 1) % UiKit.CLASS_ORDER.size()
				Sfx.play("switch")
			if Input.is_action_just_pressed(prefix + "confirm"):
				locked[i] = true
				Sfx.play("pickup")
		elif Input.is_action_just_pressed(prefix + "interact"):
			locked[i] = false
	if not locked[0] and not locked[1] and (Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("p1_interact") or Input.is_action_just_pressed("p2_interact")):
		state = State.MAIN
	if locked[0] and locked[1]:
		start_timer = COUNTDOWN
		Sfx.play("levelup")


# ---------------------------------------------------------------- Zeichnen

func _draw_stage() -> void:
	# Fabrikboden mit den vier Klassen als Kulisse.
	var floor_y := 1130.0
	_stage.draw_rect(Rect2(-1200, floor_y, 7000, 400), Color(0.14, 0.15, 0.21))
	_stage.draw_rect(Rect2(-1200, floor_y, 7000, 8), Color(0.55, 0.58, 0.68))
	for i in 60:
		_stage.draw_rect(Rect2(-1200 + i * 120.0, floor_y + 8, 60, 8), Color(0.95, 0.75, 0.12) if i % 2 == 0 else Color(0.1, 0.1, 0.13))
	var x := 1100.0
	for i in 4:
		var class_id: String = UiKit.CLASS_ORDER[i]
		var size: Vector2 = RobotClasses.get_stats(class_id).size
		var state_dict := UiKit.idle_state(Color(0.5, 0.8, 1.0), class_id, _time + i)
		state_dict["walk"] = 0.0
		RobotArt.draw_player(_stage, class_id, state_dict, Vector2(x + i * 260.0, floor_y - size.y * 0.5), 1.0)


func _draw_ui() -> void:
	var view := _ui.get_viewport_rect().size
	match state:
		State.MAIN, State.STARTING:
			_draw_main(view)
		State.SELECT:
			_draw_select(view)
		State.CONTROLS:
			_draw_main(view)
			UiKit.controls_panel(_ui, view)


func _draw_main(view: Vector2) -> void:
	# Logo.
	var pulse := 0.5 + 0.5 * sin(_time * 2.0)
	UiKit.text(_ui, Vector2(0, 190), "ARES", 150, Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.6, 0.2), pulse), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	UiKit.text(_ui, Vector2(0, 240), "Roboter gegen die Fabrik", 28, Color(0.8, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	Art.glow(_ui, Vector2(view.x * 0.5, 150), 160.0, Color(1.0, 0.6, 0.2))
	for i in MENU_ITEMS.size():
		var rect := Rect2(Vector2(view.x * 0.5 - 160, 310 + i * 76), Vector2(320, 60))
		UiKit.button(_ui, rect, MENU_ITEMS[i], i == cursor and state == State.MAIN)
	UiKit.text(_ui, Vector2(0, view.y - 40), "Hoch/Runter waehlen, Kreuz oder Enter bestaetigen", 18, Color(0.65, 0.68, 0.8), HORIZONTAL_ALIGNMENT_CENTER, view.x)


func _draw_select(view: Vector2) -> void:
	_ui.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.55))
	UiKit.text(_ui, Vector2(0, 90), "WAEHLT EURE ROBOTER", 44, Color(1.0, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	for i in 2:
		_draw_player_select(i, Rect2(Vector2(view.x * 0.5 - 760 + i * 800.0, 120), Vector2(720, 640)))
	var hint := "Links/Rechts waehlen, Kreuz bestaetigen, Kreis zurueck"
	if start_timer > 0.0:
		hint = "LOS GEHT'S!"
	UiKit.text(_ui, Vector2(0, view.y - 50), hint, 24, Color(0.9, 0.92, 1.0), HORIZONTAL_ALIGNMENT_CENTER, view.x)


func _draw_player_select(i: int, panel: Rect2) -> void:
	var accent: Color = RobotClasses.PLAYER_COLORS[i]
	var class_id: String = UiKit.CLASS_ORDER[picks[i]]
	var stats := RobotClasses.get_stats(class_id)
	var info: Dictionary = UiKit.CLASS_INFO[class_id]
	Art.panel(_ui, panel, Color(0.09, 0.11, 0.18), 20.0, accent if locked[i] else Color(1, 1, 1, 0.3))
	_ui.draw_rect(Rect2(panel.position + Vector2(24, 0), Vector2(120, 5)), accent)
	UiKit.text(_ui, panel.position + Vector2(30, 52), "SPIELER %d" % (i + 1), 26, accent)
	UiKit.text(_ui, panel.position + Vector2(0, 52), "BEREIT" if locked[i] else "waehlt ...", 22, Color(0.5, 1.0, 0.6) if locked[i] else Color(0.7, 0.72, 0.85), HORIZONTAL_ALIGNMENT_RIGHT, panel.size.x - 30.0)
	# Pfeile und Name.
	var center_x := panel.position.x + panel.size.x * 0.5
	UiKit.text(_ui, Vector2(panel.position.x, panel.position.y + 120), stats.name.to_upper(), 46, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	if not locked[i]:
		var blink := 0.6 + 0.4 * sin(_time * 6.0)
		UiKit.text(_ui, Vector2(panel.position.x + 24, panel.position.y + 250), "<", 60, Color(1, 1, 1, blink))
		UiKit.text(_ui, Vector2(panel.end.x - 56, panel.position.y + 250), ">", 60, Color(1, 1, 1, blink))
	# Roboter gross auf einem Podest.
	var floor_pos := Vector2(center_x, panel.position.y + 330)
	Art.ellipse(_ui, floor_pos + Vector2(0, 6), 130.0, 14.0, Color(0, 0, 0, 0.4))
	Art.rrect(_ui, Rect2(floor_pos + Vector2(-140, 0), Vector2(280, 12)), Color(0.3, 0.33, 0.42), 6.0)
	var size: Vector2 = stats.size
	var zoom := 2.4 if size.y < 90.0 else 1.5
	var state_dict := UiKit.idle_state(accent, class_id, _time)
	state_dict["arm"] = 0.5 + 0.5 * sin(_time * 1.5)
	RobotArt.draw_player(_ui, class_id, state_dict, floor_pos + Vector2(0, -size.y * 0.5 * zoom), zoom)
	# Tags, Beschreibung, Werte.
	var tag_x := panel.position.x + 40.0
	for tag in info.tags:
		var width := 24.0 + String(tag).length() * 10.0
		var chip := Rect2(Vector2(tag_x, panel.position.y + 360), Vector2(width, 28))
		Art.rrect(_ui, chip, Color(0.18, 0.2, 0.3), 10.0)
		Art.rrect_line(_ui, chip, accent, 10.0, 1.5)
		UiKit.text(_ui, chip.position + Vector2(0, 20), String(tag), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, width)
		tag_x += width + 10.0
	UiKit.text(_ui, panel.position + Vector2(40, 420), info.blurb, 18, Color(0.82, 0.85, 0.95), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 80.0, true)
	UiKit.stat_bar(_ui, panel.position + Vector2(40, 495), 300.0, "Leben", float(stats.max_hp) / 160.0, Color(0.4, 0.85, 0.5))
	UiKit.stat_bar(_ui, panel.position + Vector2(40, 523), 300.0, "Tempo", float(stats.speed) / 390.0, Color(0.4, 0.7, 1.0))
	UiKit.stat_bar(_ui, panel.position + Vector2(40, 551), 300.0, "Feuerkraft", float(info.damage) / 5.0, Color(1.0, 0.6, 0.3))
	UiKit.stat_bar(_ui, panel.position + Vector2(40, 579), 300.0, "Schwierigkeit", float(info.difficulty) / 5.0, Color(0.9, 0.5, 0.9))
	UiKit.text(_ui, panel.position + Vector2(370, 500), "Fähigkeit (L2):", 16, Color(1.0, 0.85, 0.4))
	UiKit.text(_ui, panel.position + Vector2(370, 524), info.ability, 16, Color(0.88, 0.9, 0.98), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 400.0, true)
