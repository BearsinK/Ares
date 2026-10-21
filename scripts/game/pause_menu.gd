class_name PauseMenu
extends CanvasLayer
## Pausemenue (Escape / Start) und Ergebnisbildschirm nach Game Over oder Sieg.
## Beide Spieler koennen es bedienen. Neustart und Hauptmenue fragen nach.

enum Mode { CLOSED, PAUSE, RESULT }
enum Page { MAIN, CONTROLS, CONFIRM, OPTIONS }

const PAUSE_ITEMS: Array[String] = ["Weiter", "Optionen", "Steuerung", "Neustart", "Hauptmenü"]
const RESULT_ITEMS: Array[String] = ["Neustart", "Hauptmenü"]
const INPUT_GRACE := 0.5

var main: Node = null
var mode := Mode.CLOSED
var page := Page.MAIN
var cursor := 0
var victory := false

var options := OptionsPage.new()

var _pending := ""
var _leaving := false
var _confirm_cursor := 1
var _age := 0.0
var _canvas: Node2D


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_menu)
	add_child(_canvas)
	visible = false


func is_open() -> bool:
	return mode != Mode.CLOSED


func open_pause() -> void:
	mode = Mode.PAUSE
	_reset()
	get_tree().paused = true
	Sfx.play("switch")


func open_result(new_victory: bool) -> void:
	mode = Mode.RESULT
	victory = new_victory
	_reset()


func close() -> void:
	mode = Mode.CLOSED
	visible = false
	get_tree().paused = false


func _reset() -> void:
	page = Page.MAIN
	cursor = 0
	_age = 0.0
	visible = true


func _items() -> Array[String]:
	return PAUSE_ITEMS if mode == Mode.PAUSE else RESULT_ITEMS


func _process(delta: float) -> void:
	if mode == Mode.CLOSED or _leaving:
		return
	_age += delta
	match page:
		Page.MAIN:
			_update_main()
		Page.CONTROLS:
			if UiKit.back() or UiKit.confirm():
				page = Page.MAIN
		Page.CONFIRM:
			_update_confirm()
		Page.OPTIONS:
			if options.update(delta):
				page = Page.MAIN
	_canvas.queue_redraw()


func _update_main() -> void:
	var items := _items()
	if UiKit.pressed("up"):
		cursor = (cursor + items.size() - 1) % items.size()
		Sfx.play("switch")
	if UiKit.pressed("down"):
		cursor = (cursor + 1) % items.size()
		Sfx.play("switch")
	if _age < 0.15:
		return
	if mode == Mode.PAUSE and Input.is_action_just_pressed("pause"):
		close()
		return
	if _age < INPUT_GRACE or not UiKit.confirm():
		return
	Sfx.play("pickup")
	match items[cursor]:
		"Weiter":
			close()
		"Optionen":
			page = Page.OPTIONS
			options.cursor = 0
		"Steuerung":
			page = Page.CONTROLS
		"Neustart":
			_ask("restart")
		"Hauptmenü":
			_ask("title")


func _ask(action: String) -> void:
	_pending = action
	_confirm_cursor = 1
	page = Page.CONFIRM


func _update_confirm() -> void:
	if UiKit.pressed("left") or UiKit.pressed("right") or UiKit.pressed("up") or UiKit.pressed("down"):
		_confirm_cursor = 1 - _confirm_cursor
		Sfx.play("switch")
	if UiKit.back():
		page = Page.MAIN
	elif UiKit.confirm():
		if _confirm_cursor == 0:
			_run(_pending)
		else:
			page = Page.MAIN


func _run(action: String) -> void:
	if _leaving:
		return
	_leaving = true
	main.abandon_run()
	Transition.go("" if action == "restart" else "res://scenes/title.tscn")


# ---------------------------------------------------------------- Zeichnen

func _draw_menu() -> void:
	var view := _canvas.get_viewport_rect().size
	_canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.7))
	if page == Page.CONTROLS:
		UiKit.controls_panel(_canvas, view)
		return
	if page == Page.OPTIONS:
		options.draw(_canvas, view)
		return
	if mode == Mode.RESULT:
		_draw_result(view)
	else:
		UiKit.text(_canvas, Vector2(0, 220), "PAUSE", 80, Color(1.0, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	var top := 330.0 if mode == Mode.PAUSE else view.y - 250.0
	if page == Page.CONFIRM:
		var question := "Lauf neu starten?" if _pending == "restart" else "Zurück zum Hauptmenü? Die Chips bleiben."
		UiKit.text(_canvas, Vector2(0, top - 20.0), question, 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, view.x)
		for i in 2:
			var rect := Rect2(Vector2(view.x * 0.5 - 170.0 + i * 180.0, top + 10.0), Vector2(160, 56))
			UiKit.button(_canvas, rect, "Ja" if i == 0 else "Nein", i == _confirm_cursor, Color(1.0, 0.5, 0.4) if i == 0 else Color(0.4, 0.75, 1.0))
		return
	var items := _items()
	for i in items.size():
		var rect := Rect2(Vector2(view.x * 0.5 - 160.0, top + i * 70.0), Vector2(320, 56))
		UiKit.button(_canvas, rect, items[i], i == cursor)
	UiKit.text(_canvas, Vector2(0, view.y - 40.0), "Hoch/Runter wählen, Kreuz oder Enter bestätigen", 18, Color(0.65, 0.68, 0.8), HORIZONTAL_ALIGNMENT_CENTER, view.x)


## Eine Zeile mit Neuem aus diesem Lauf: Erfolge und Archiv-Eintraege.
func _news_line() -> String:
	var parts: Array[String] = []
	if not main.run_achievements.is_empty():
		parts.append("Erfolge: %s" % ", ".join(main.run_achievements))
	if not main.run_discoveries.is_empty():
		parts.append("%d neu im Archiv" % main.run_discoveries.size())
	return "     ".join(parts)


func _draw_result(view: Vector2) -> void:
	var title := "GESCHAFFT!" if victory else "GAME OVER"
	var color := Color(0.5, 1.0, 0.6) if victory else Color(1.0, 0.4, 0.4)
	UiKit.text(_canvas, Vector2(0, 190), title, 84, color, HORIZONTAL_ALIGNMENT_CENTER, view.x)
	if victory:
		UiKit.text(_canvas, Vector2(0, 232), "Der Smelter ist erledigt. Die Fabrik steht still.", 22, Color(0.85, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	var seconds := int(main.director.time)
	var panel := Rect2(Vector2(view.x * 0.5 - 420.0, 270.0), Vector2(840, 250))
	Art.panel(_canvas, panel, Color(0.09, 0.11, 0.18), 18.0, Color(1, 1, 1, 0.25))
	var stats: Array = [
		["Welle", ("Boss" if main.boss != null else "%d / %d" % [main.wave, main.max_waves])],
		["Zeit", "%02d:%02d" % [seconds / 60, seconds % 60]],
		["Stufe", "%d" % main.level],
		["Besiegt", "%d" % main.kills],
	]
	for i in stats.size():
		var x := panel.position.x + 50.0 + i * 190.0
		UiKit.text(_canvas, Vector2(x, panel.position.y + 60.0), stats[i][0], 18, Color(0.7, 0.74, 0.88))
		UiKit.text(_canvas, Vector2(x, panel.position.y + 105.0), stats[i][1], 40, Color.WHITE)
	var chips_text := "+%d Chips   (Vorrat %d)" % [main.run_chips, SaveData.chips()]
	UiKit.text(_canvas, Vector2(0, panel.end.y + 36.0), chips_text, 26, Color(0.6, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	var news := _news_line()
	if news != "":
		UiKit.text(_canvas, Vector2(0, panel.end.y + 62.0), news, 17, Color(1.0, 0.9, 0.55), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	for i in 2:
		var player: Player = main.players[i]
		var accent: Color = RobotClasses.PLAYER_COLORS[i]
		var x := panel.position.x + 50.0 + i * 380.0
		_canvas.draw_rect(Rect2(Vector2(x, panel.position.y + 150.0), Vector2(60, 4)), accent)
		UiKit.text(_canvas, Vector2(x, panel.position.y + 188.0), "P%d  %s" % [i + 1, player.stats.name], 22, accent)
		UiKit.text(_canvas, Vector2(x, panel.position.y + 220.0), "Gold %d    Waffen %d    Firmware %d" % [player.gold, player.weapons.size(), player.firmware_count()], 16, Color(0.85, 0.88, 0.97))
		# Gesammelte Items als Symbole mit Zaehler.
		var item_x := x + 14.0
		var shown := 0
		for id in player.items:
			if shown >= 9:
				UiKit.text(_canvas, Vector2(item_x - 10.0, panel.end.y + 104.0), "+%d" % (player.items.size() - shown), 18, Color(0.85, 0.88, 0.97))
				break
			PerkArt.draw(_canvas, id, Vector2(item_x, panel.end.y + 98.0), 30.0)
			if int(player.items[id]) > 1:
				UiKit.text(_canvas, Vector2(item_x + 8.0, panel.end.y + 118.0), "x%d" % int(player.items[id]), 14, Color(1.0, 0.95, 0.6))
			item_x += 38.0
			shown += 1
