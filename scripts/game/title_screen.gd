extends Node2D
## Titelbildschirm mit Hauptmenue, Klassenauswahl fuer beide Spieler und
## Steuerungsuebersicht. Startet danach die Hauptszene.

enum State { MAIN, SELECT, CONTROLS, WORKSHOP, STARTING, SANDBOX, OPTIONS, CREDITS }

const MENU_ITEMS: Array[String] = ["Spielen", "Sandbox", "Garage", "Schwierigkeit", "Steuerung", "Optionen", "Credits", "Beenden"]
const COUNTDOWN := 1.1

var state := State.MAIN
var cursor := 0
var picks: Array[int] = [0, 1]
var locked: Array[bool] = [false, false]
var start_timer := 0.0
var workshop_cursor := 0
var workshop_message := ""
var workshop_good := false
var workshop_message_time := 0.0
## Sandbox: Klassenwahl fuehrt danach in die Einstellungen. Einstellung, Cursor und Bereitschaft je Spieler.
var sandbox_mode := false
var sandbox_config := {}
var sandbox_cursor: Array[int] = [0, 0]
var sandbox_locked: Array[bool] = [false, false]
var sandbox_classes: Array[String] = []

var options := OptionsPage.new()

var _time := 0.0
var _leaving := false
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
	Music.set_layer_level(0.3)
	match state:
		State.MAIN:
			_update_main()
		State.SELECT:
			_update_select(delta)
		State.CONTROLS:
			if UiKit.back() or UiKit.confirm():
				state = State.MAIN
		State.WORKSHOP:
			_update_workshop(delta)
		State.SANDBOX:
			_update_sandbox(delta)
		State.OPTIONS:
			if options.update(delta):
				state = State.MAIN
		State.CREDITS:
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
	if MENU_ITEMS[cursor] == "Schwierigkeit":
		# Links/Rechts stellt die Schwierigkeit direkt um.
		if UiKit.pressed("left") or UiKit.pressed("right"):
			_cycle_difficulty(1 if UiKit.pressed("right") else -1)
	if UiKit.confirm():
		Sfx.play("pickup")
		match MENU_ITEMS[cursor]:
			"Schwierigkeit":
				_cycle_difficulty(1)
			"Spielen":
				state = State.SELECT
				locked = [false, false]
				sandbox_mode = false
			"Sandbox":
				state = State.SELECT
				locked = [false, false]
				sandbox_mode = true
			"Garage":
				state = State.WORKSHOP
				workshop_cursor = 0
			"Steuerung":
				state = State.CONTROLS
			"Optionen":
				state = State.OPTIONS
				options.cursor = 0
			"Credits":
				state = State.CREDITS
			"Beenden":
				get_tree().quit()


func _cycle_difficulty(step: int) -> void:
	var count := Meta.DIFFICULTIES.size()
	SaveData.set_difficulty((SaveData.difficulty() + step + count) % count)
	Sfx.play("switch")


## Alle Zeilen der Werkstatt: Upgrades, dann Klassen und Waffen zum Freischalten.
func workshop_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for id in Meta.UPGRADES:
		var info: Dictionary = Meta.UPGRADES[id]
		var level := SaveData.level(id)
		var maxed := level >= int(info.max)
		rows.append({"kind": "upgrade", "id": id, "name": info.name, "text": info.text, "level": level, "max": int(info.max),
			"done": maxed, "cost": 0 if maxed else Meta.cost_of(id, level)})
	for id in Meta.CLASS_UNLOCKS:
		rows.append({"kind": "class", "id": id, "name": "Klasse: %s" % RobotClasses.get_stats(id).name,
			"text": "Spielbar im Auswahlbildschirm", "level": 0, "max": 1,
			"done": SaveData.class_unlocked(id), "cost": int(Meta.CLASS_UNLOCKS[id])})
	for id in Meta.WEAPON_UNLOCKS:
		rows.append({"kind": "weapon", "id": id, "name": "Waffe: %s" % Weapons.get_weapon(id).name,
			"text": "Erscheint im Shop", "level": 0, "max": 1,
			"done": SaveData.weapon_unlocked(id), "cost": int(Meta.WEAPON_UNLOCKS[id])})
	return rows


func _update_workshop(delta: float) -> void:
	workshop_message_time = maxf(0.0, workshop_message_time - delta)
	var rows := workshop_rows()
	if UiKit.pressed("up"):
		workshop_cursor = (workshop_cursor + rows.size() - 1) % rows.size()
		Sfx.play("switch")
	if UiKit.pressed("down"):
		workshop_cursor = (workshop_cursor + 1) % rows.size()
		Sfx.play("switch")
	if UiKit.back():
		state = State.MAIN
		return
	if UiKit.confirm():
		var row := rows[workshop_cursor]
		if row.done:
			_workshop_say("Schon freigeschaltet" if row.kind != "upgrade" else "Schon auf Maximum")
		elif SaveData.chips() < int(row.cost):
			_workshop_say("Zu wenig Chips")
		else:
			var ok := SaveData.buy_upgrade(row.id) if row.kind == "upgrade" else SaveData.buy_unlock(row.kind, row.id)
			if ok:
				Sfx.play("coin")
				_workshop_say("Gekauft: %s" % row.name, true)


func _workshop_say(text: String, good := false) -> void:
	workshop_message = text
	workshop_message_time = 1.6
	workshop_good = good
	if not good:
		Sfx.play("hurt")


func _update_select(delta: float) -> void:
	if _leaving:
		return
	if start_timer > 0.0:
		start_timer -= delta
		if start_timer <= 0.0:
			var classes: Array = []
			for i in 2:
				classes.append(UiKit.CLASS_ORDER[picks[i]])
			Engine.set_meta("classes", classes)
			if sandbox_mode:
				_enter_sandbox(classes)
				return
			if Engine.has_meta("sandbox"):
				Engine.remove_meta("sandbox")
			_leaving = true
			Transition.go("res://scenes/main.tscn")
		return
	var nobody_ready := not locked[0] and not locked[1]
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
				if SaveData.class_unlocked(UiKit.CLASS_ORDER[picks[i]]):
					locked[i] = true
					Sfx.play("pickup")
				else:
					Sfx.play("hurt")
		elif Input.is_action_just_pressed(prefix + "interact"):
			locked[i] = false
	if nobody_ready and (Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("p1_interact") or Input.is_action_just_pressed("p2_interact")):
		state = State.MAIN
	if locked[0] and locked[1]:
		start_timer = COUNTDOWN
		Sfx.play("levelup")


func _enter_sandbox(classes: Array) -> void:
	sandbox_classes = []
	for class_id in classes:
		sandbox_classes.append(String(class_id))
	sandbox_config = SandboxConfig.default_config(sandbox_classes)
	sandbox_cursor = [0, 0]
	sandbox_locked = [false, false]
	state = State.SANDBOX
	start_timer = 0.0


func _update_sandbox(delta: float) -> void:
	if _leaving:
		return
	if start_timer > 0.0:
		start_timer -= delta
		if start_timer <= 0.0:
			Engine.set_meta("sandbox", sandbox_config)
			Engine.set_meta("classes", sandbox_classes)
			_leaving = true
			Transition.go("res://scenes/main.tscn")
		return
	for i in 2:
		var prefix := "p%d_" % (i + 1)
		var rows := SandboxConfig.rows(sandbox_config, i, sandbox_classes[i])
		if sandbox_locked[i]:
			if Input.is_action_just_pressed(prefix + "interact"):
				sandbox_locked[i] = false
			continue
		if Input.is_action_just_pressed(prefix + "up"):
			sandbox_cursor[i] = (sandbox_cursor[i] + rows.size() - 1) % rows.size()
			Sfx.play("switch")
		if Input.is_action_just_pressed(prefix + "down"):
			sandbox_cursor[i] = (sandbox_cursor[i] + 1) % rows.size()
			Sfx.play("switch")
		var delta_value := 0
		if Input.is_action_just_pressed(prefix + "left"):
			delta_value -= 1
		if Input.is_action_just_pressed(prefix + "right"):
			delta_value += 1
		var row: Dictionary = rows[sandbox_cursor[i]]
		if delta_value != 0 and row.kind != "ready":
			SandboxConfig.change(sandbox_config, i, sandbox_classes[i], row, delta_value)
			Sfx.play("switch")
		if Input.is_action_just_pressed(prefix + "confirm"):
			if row.kind == "ready":
				sandbox_locked[i] = true
				Sfx.play("pickup")
			else:
				SandboxConfig.change(sandbox_config, i, sandbox_classes[i], row, 1)
				Sfx.play("switch")
		if Input.is_action_just_pressed(prefix + "interact") and not sandbox_locked[0] and not sandbox_locked[1]:
			state = State.SELECT
			locked = [false, false]
			return
	if sandbox_locked[0] and sandbox_locked[1]:
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
		State.WORKSHOP:
			_draw_workshop(view)
		State.SANDBOX:
			_draw_sandbox(view)
		State.OPTIONS:
			options.draw(_ui, view)
		State.CREDITS:
			_draw_credits(view)


func _item_label(index: int) -> String:
	if MENU_ITEMS[index] == "Schwierigkeit":
		return "Stufe: %s" % String(Meta.difficulty_data().name)
	return MENU_ITEMS[index]


func _draw_main(view: Vector2) -> void:
	# Logo.
	var pulse := 0.5 + 0.5 * sin(_time * 2.0)
	UiKit.text(_ui, Vector2(0, 190), "ROBROS", 118, Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.6, 0.2), pulse), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	UiKit.text(_ui, Vector2(0, 240), "Der Aufstand der Apparate", 28, Color(0.8, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	Art.glow(_ui, Vector2(view.x * 0.5, 150), 160.0, Color(1.0, 0.6, 0.2))
	for i in MENU_ITEMS.size():
		var rect := Rect2(Vector2(view.x * 0.5 - 160, 270 + i * 62), Vector2(320, 52))
		UiKit.button(_ui, rect, _item_label(i), i == cursor and state == State.MAIN)
	if MENU_ITEMS[cursor] == "Schwierigkeit" and state == State.MAIN:
		UiKit.text(_ui, Vector2(0, view.y - 70), String(Meta.difficulty_data().text), 20, Color(1.0, 0.85, 0.5), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	var hint := "Hoch/Runter wählen, Kreuz oder Enter bestätigen"
	if MENU_ITEMS[cursor] == "Schwierigkeit" and state == State.MAIN:
		hint = "Links/Rechts oder Kreuz: Stufe wechseln"
	UiKit.text(_ui, Vector2(0, view.y - 40), hint, 18, Color(0.65, 0.68, 0.8), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	UiKit.text(_ui, Vector2(0, view.y - 20), version_text(), 14, Color(0.5, 0.54, 0.68), HORIZONTAL_ALIGNMENT_RIGHT, view.x - 20.0)


## Versionsnummer aus den Projekteinstellungen.
static func version_text() -> String:
	return "Version %s" % String(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func _draw_credits(view: Vector2) -> void:
	_ui.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.78))
	var panel := Rect2(Vector2(view.x * 0.5 - 520.0, 150.0), Vector2(1040.0, 560.0))
	Art.panel(_ui, panel, Color(0.09, 0.11, 0.18), 18.0, Color(1, 1, 1, 0.28))
	UiKit.text(_ui, Vector2(0, 110), "CREDITS", 52, Color(1.0, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	var y := panel.position.y + 70.0
	UiKit.text(_ui, Vector2(0, y), "ROBROS", 46, Color(1.0, 0.8, 0.3), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	UiKit.text(_ui, Vector2(0, y + 34.0), "Der Aufstand der Apparate", 22, Color(0.85, 0.88, 1.0), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	UiKit.text(_ui, Vector2(0, y + 64.0), version_text(), 18, Color(0.6, 0.65, 0.8), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	UiKit.text(_ui, Vector2(0, y + 130.0), "TECHNIK", 18, Color(0.6, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	UiKit.text(_ui, Vector2(panel.position.x + 80.0, y + 160.0), "Alle Grafik, alle Sounds und die Musik entstehen beim Start im Code. Es gibt keine Bild- oder Audiodateien.", 20, Color(0.9, 0.92, 1.0), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 160.0, true)
	UiKit.text(_ui, Vector2(0, y + 250.0), "ENGINE", 18, Color(0.6, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	UiKit.text(_ui, Vector2(panel.position.x + 80.0, y + 280.0), "Gebaut mit der Godot Engine 4.7 (godotengine.org), MIT-Lizenz.", 20, Color(0.9, 0.92, 1.0), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 160.0, true)
	UiKit.text(_ui, Vector2(panel.position.x + 80.0, y + 312.0), "Copyright (c) 2014-present Godot Engine contributors. Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur. Weitere Lizenzen Dritter: godotengine.org/license", 16, Color(0.75, 0.78, 0.9), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 160.0, true)
	UiKit.text(_ui, Vector2(0, y + 420.0), "Danke fürs Spielen!", 26, Color(1.0, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	UiKit.text(_ui, Vector2(0, view.y - 40.0), "Zurück: Kreis oder Escape", 18, Color(0.65, 0.68, 0.8), HORIZONTAL_ALIGNMENT_CENTER, view.x)


func _draw_sandbox(view: Vector2) -> void:
	_ui.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.75))
	UiKit.text(_ui, Vector2(0, 70), "SANDBOX", 52, Color(1.0, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	UiKit.text(_ui, Vector2(0, 104), "Hoch/Runter: Zeile, Links/Rechts: ändern, Kreuz bei BEREIT: los. Startwelle, Gold und Unverwundbar gelten für beide.", 18, Color(0.75, 0.8, 0.95), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	var wave_text := "Endboss" if int(sandbox_config.wave) >= SandboxConfig.BOSS_WAVE else "Welle %d" % int(sandbox_config.wave)
	UiKit.text(_ui, Vector2(0, 128), "Start: %s     Gold: %d     Unverwundbar: %s" % [wave_text, int(sandbox_config.gold), "An" if bool(sandbox_config.god) else "Aus"], 22, Color(1.0, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	for i in 2:
		_draw_sandbox_panel(i, Rect2(Vector2(view.x * 0.5 - 760 + i * 800.0, 150), Vector2(720, view.y - 210)))
	if start_timer > 0.0:
		UiKit.text(_ui, Vector2(0, view.y - 30), "LOS GEHT'S!", 28, Color(0.9, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER, view.x)


func _draw_sandbox_panel(i: int, panel: Rect2) -> void:
	var accent: Color = RobotClasses.PLAYER_COLORS[i]
	var rows := SandboxConfig.rows(sandbox_config, i, sandbox_classes[i])
	Art.panel(_ui, panel, Color(0.09, 0.11, 0.18), 20.0, accent if sandbox_locked[i] else Color(1, 1, 1, 0.3))
	_ui.draw_rect(Rect2(panel.position + Vector2(24, 0), Vector2(120, 5)), accent)
	UiKit.text(_ui, panel.position + Vector2(30, 44), "SPIELER %d  %s" % [i + 1, RobotClasses.get_stats(sandbox_classes[i]).name], 26, accent)
	if sandbox_locked[i]:
		UiKit.text(_ui, panel.position + Vector2(0, 44), "BEREIT", 24, Color(0.5, 1.0, 0.6), HORIZONTAL_ALIGNMENT_RIGHT, panel.size.x - 30.0)
	var row_height := 38.0
	var visible_rows := int((panel.size.y - 120.0) / row_height)
	var first := clampi(sandbox_cursor[i] - visible_rows / 2, 0, maxi(0, rows.size() - visible_rows))
	for k in visible_rows:
		var index := first + k
		if index >= rows.size():
			break
		var row: Dictionary = rows[index]
		var rect := Rect2(panel.position + Vector2(20, 64 + k * row_height), Vector2(panel.size.x - 40.0, row_height - 4.0))
		var selected := index == sandbox_cursor[i] and not sandbox_locked[i]
		var disabled: bool = row.get("disabled", false)
		Art.rrect(_ui, rect, Color(0.2, 0.24, 0.36) if selected else Color(0.12, 0.14, 0.22), 8.0)
		if selected:
			Art.rrect_line(_ui, rect, accent, 8.0, 2.0)
		var label_color := Color(0.45, 0.47, 0.55) if disabled else (Color.WHITE if selected else Color(0.8, 0.83, 0.93))
		UiKit.text(_ui, rect.position + Vector2(14, 25), String(row.label), 20, label_color)
		if row.kind == "ready":
			UiKit.text(_ui, rect.position + Vector2(0, 25), "Kreuz: bereit", 18, Color(0.6, 0.95, 0.7), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 14.0)
		else:
			var value: String = String(row.value)
			if selected and not disabled:
				value = "<  %s  >" % value
			UiKit.text(_ui, rect.position + Vector2(0, 25), value, 20, Color(1.0, 0.9, 0.5) if not disabled else Color(0.4, 0.42, 0.5), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 14.0)
		if selected and row.has("text"):
			UiKit.text(_ui, rect.position + Vector2(190, 25), String(row.text), 14, Color(0.7, 0.8, 0.95), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 400.0)


func _draw_workshop(view: Vector2) -> void:
	_ui.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.72))
	UiKit.text(_ui, Vector2(0, 80), "GARAGE", 52, Color(1.0, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	var stats := SaveData.stats()
	UiKit.text(_ui, Vector2(0, 112), "Läufe %d    Beste Welle %d    Boss besiegt %d" % [int(stats.runs), int(stats.best_wave), int(stats.boss_kills)], 17, Color(0.7, 0.74, 0.88), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	var chips_rect := Rect2(Vector2(view.x * 0.5 - 130.0, 128.0), Vector2(260, 44))
	Art.rrect(_ui, chips_rect, Color(0.08, 0.14, 0.2), 14.0)
	Art.rrect_line(_ui, chips_rect, Color(0.5, 0.9, 1.0, 0.7), 14.0, 2.0)
	UiKit.text(_ui, chips_rect.position + Vector2(0, 31), "%d Chips" % SaveData.chips(), 26, Color(0.6, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER, chips_rect.size.x)
	var rows := workshop_rows()
	var top := 190.0
	var row_height := 46.0
	var panel := Rect2(Vector2(view.x * 0.5 - 560.0, top - 8.0), Vector2(1120, rows.size() * row_height + 16.0))
	Art.panel(_ui, panel, Color(0.09, 0.11, 0.18), 16.0, Color(1, 1, 1, 0.25))
	for i in rows.size():
		var row := rows[i]
		var rect := Rect2(Vector2(panel.position.x + 10.0, top + i * row_height), Vector2(panel.size.x - 20.0, row_height - 4.0))
		var selected := i == workshop_cursor
		if selected:
			Art.rrect(_ui, rect, Color(0.2, 0.25, 0.38), 10.0)
			Art.rrect_line(_ui, rect, Color(0.4, 0.75, 1.0), 10.0, 2.0)
		var tag_colors := {"upgrade": Color(0.5, 0.85, 1.0), "class": Color(1.0, 0.7, 0.4), "weapon": Color(0.6, 1.0, 0.6)}
		_ui.draw_rect(Rect2(rect.position + Vector2(10, 8), Vector2(5, rect.size.y - 16)), tag_colors[row.kind])
		UiKit.text(_ui, rect.position + Vector2(26, 28), row.name, 21, Color.WHITE if not row.done or row.kind == "upgrade" else Color(0.7, 1.0, 0.75))
		UiKit.text(_ui, rect.position + Vector2(330, 28), row.text, 17, Color(0.78, 0.8, 0.92))
		# Stufenpunkte oder Status.
		if row.kind == "upgrade":
			for k in int(row.max):
				var center := rect.position + Vector2(760.0 + k * 22.0, rect.size.y * 0.5)
				_ui.draw_circle(center, 7.0, Color(0.5, 0.9, 1.0) if k < int(row.level) else Color(1, 1, 1, 0.15))
		elif row.done:
			UiKit.text(_ui, rect.position + Vector2(760, 28), "freigeschaltet", 17, Color(0.6, 1.0, 0.7))
		var cost_text := "" if row.done else "%d" % int(row.cost)
		var affordable := SaveData.chips() >= int(row.cost)
		UiKit.text(_ui, rect.position + Vector2(0, 28), cost_text if not row.done else "max" if row.kind == "upgrade" else "", 21,
			Color(0.6, 0.95, 1.0) if affordable else Color(0.7, 0.45, 0.45), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 18.0)
	if workshop_message_time > 0.0:
		UiKit.text(_ui, Vector2(0, panel.end.y + 36.0), workshop_message, 22, Color(0.6, 1.0, 0.7) if workshop_good else Color(1.0, 0.55, 0.45), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	UiKit.text(_ui, Vector2(0, view.y - 30.0), "Hoch/Runter wählen, Kreuz kaufen, Kreis zurück. Chips gibt es am Ende jedes Laufs.", 18, Color(0.65, 0.68, 0.8), HORIZONTAL_ALIGNMENT_CENTER, view.x)


func _draw_select(view: Vector2) -> void:
	_ui.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.55))
	UiKit.text(_ui, Vector2(0, 90), "WÄHLT EURE ROBOTER", 44, Color(1.0, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	for i in 2:
		_draw_player_select(i, Rect2(Vector2(view.x * 0.5 - 760 + i * 800.0, 120), Vector2(720, 640)))
	var hint := "Links/Rechts wählen, Kreuz bestätigen, Kreis zurück"
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
	var available := SaveData.class_unlocked(class_id)
	UiKit.text(_ui, panel.position + Vector2(30, 52), "SPIELER %d" % (i + 1), 26, accent)
	UiKit.text(_ui, panel.position + Vector2(0, 52), "GESPERRT" if not available else ("BEREIT" if locked[i] else "wählt ..."), 22, Color(1.0, 0.55, 0.45) if not available else (Color(0.5, 1.0, 0.6) if locked[i] else Color(0.7, 0.72, 0.85)), HORIZONTAL_ALIGNMENT_RIGHT, panel.size.x - 30.0)
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
	var zoom := 2.4 if size.y < 60.0 else (1.7 if size.y < 90.0 else 1.5)
	var state_dict := UiKit.idle_state(accent, class_id, _time)
	state_dict["arm"] = 0.5 + 0.5 * sin(_time * 1.5)
	RobotArt.draw_player(_ui, class_id, state_dict, floor_pos + Vector2(0, -size.y * 0.5 * zoom), zoom)
	if not available:
		_ui.draw_rect(Rect2(panel.position + Vector2(20, 150), Vector2(panel.size.x - 40.0, 195)), Color(0.04, 0.05, 0.09, 0.78))
		UiKit.text(_ui, panel.position + Vector2(0, 240), "GESPERRT", 36, Color(1.0, 0.6, 0.45), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		UiKit.text(_ui, panel.position + Vector2(0, 275), "Freischalten in der Garage: %d Chips" % int(Meta.CLASS_UNLOCKS[class_id]), 19, Color(0.85, 0.88, 0.97), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
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
	UiKit.text(_ui, panel.position + Vector2(370, 500), "Fähigkeit (Quadrat):", 16, Color(1.0, 0.85, 0.4))
	UiKit.text(_ui, panel.position + Vector2(370, 524), info.ability, 16, Color(0.88, 0.9, 0.98), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 400.0, true)
