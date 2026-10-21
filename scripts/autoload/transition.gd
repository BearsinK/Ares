extends CanvasLayer
## Weiche Szenenwechsel: abdunkeln, Szene wechseln, wieder aufhellen. Beim Start blendet das Spiel
## aus Schwarz ein. Im Headless-Modus (Tests) wird sofort gewechselt.
## Benutzung: Transition.go("res://scenes/title.tscn") oder Transition.go("") zum Neuladen der aktuellen Szene.

const FADE_OUT := 0.22
const FADE_IN := 0.35
const COLOR := Color(0.02, 0.025, 0.05)

var busy := false

var _rect: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(COLOR, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	if DisplayServer.get_name() != "headless":
		_rect.color = Color(COLOR, 1.0)
		_fade(0.0, 0.6)


func go(path: String) -> void:
	if busy:
		return
	if DisplayServer.get_name() == "headless":
		_switch(path)
		return
	busy = true
	await _fade(1.0, FADE_OUT).finished
	_switch(path)
	# Die neue Szene steht erst nach einem Frame.
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade(0.0, FADE_IN).finished
	busy = false


func _switch(path: String) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if path == "":
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(path)


func _fade(alpha: float, seconds: float) -> Tween:
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(_rect, "color:a", alpha, seconds)
	return tween
