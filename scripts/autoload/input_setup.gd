extends Node
## Registriert beim Start alle Eingabe-Aktionen fuer beide Spieler.
## Spieler 1 nutzt Controller 0 und Tastatur A, Spieler 2 nutzt Controller 1
## und Tastatur B. Beide Belegungen sind immer aktiv, damit man auch mit
## nur einem oder gar keinem Controller testen kann.
##
## Controller-Belegung (PS5 DualSense):
##   Linker Stick: bewegen        Rechter Stick: zielen
##   L1: Sprung    R1: Dash       R2: Hauptangriff    L2: Klassenfaehigkeit
##   Quadrat: Haken               Dreieck: Waffe wechseln
##   Kreis: Interagieren          Kreuz: Bestaetigen

const ACTIONS: Array[String] = [
	"left", "right", "up", "down",
	"aim_left", "aim_right", "aim_up", "aim_down",
	"jump", "dash", "fire", "ability", "hook", "weapon", "interact", "confirm",
]

const STICK_DEADZONE := 0.2
const TRIGGER_DEADZONE := 0.5


func _ready() -> void:
	for player in [1, 2]:
		for action in ACTIONS:
			var deadzone := TRIGGER_DEADZONE if action in ["fire", "ability"] else STICK_DEADZONE
			_add_action("p%d_%s" % [player, action], deadzone)

	_bind_gamepad(1, 0)
	_bind_gamepad(2, 1)
	_bind_keyboard_p1()
	_bind_keyboard_p2()

	_add_action("pause", 0.5)
	_key("pause", KEY_ESCAPE)
	_pad_button("pause", -1, JOY_BUTTON_START)


func _add_action(action: String, deadzone: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)


func _pad_button(action: String, device: int, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	InputMap.action_add_event(action, event)


func _pad_axis(action: String, device: int, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)


func _key(action: String, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _mouse(action: String, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


func _bind_gamepad(player: int, device: int) -> void:
	var p := "p%d_" % player
	_pad_axis(p + "left", device, JOY_AXIS_LEFT_X, -1.0)
	_pad_axis(p + "right", device, JOY_AXIS_LEFT_X, 1.0)
	_pad_axis(p + "up", device, JOY_AXIS_LEFT_Y, -1.0)
	_pad_axis(p + "down", device, JOY_AXIS_LEFT_Y, 1.0)
	_pad_button(p + "left", device, JOY_BUTTON_DPAD_LEFT)
	_pad_button(p + "right", device, JOY_BUTTON_DPAD_RIGHT)
	_pad_button(p + "up", device, JOY_BUTTON_DPAD_UP)
	_pad_button(p + "down", device, JOY_BUTTON_DPAD_DOWN)

	_pad_axis(p + "aim_left", device, JOY_AXIS_RIGHT_X, -1.0)
	_pad_axis(p + "aim_right", device, JOY_AXIS_RIGHT_X, 1.0)
	_pad_axis(p + "aim_up", device, JOY_AXIS_RIGHT_Y, -1.0)
	_pad_axis(p + "aim_down", device, JOY_AXIS_RIGHT_Y, 1.0)

	_pad_button(p + "jump", device, JOY_BUTTON_LEFT_SHOULDER)
	_pad_button(p + "dash", device, JOY_BUTTON_RIGHT_SHOULDER)
	_pad_axis(p + "fire", device, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_pad_axis(p + "ability", device, JOY_AXIS_TRIGGER_LEFT, 1.0)
	_pad_button(p + "hook", device, JOY_BUTTON_X)
	_pad_button(p + "weapon", device, JOY_BUTTON_Y)
	_pad_button(p + "interact", device, JOY_BUTTON_B)
	_pad_button(p + "confirm", device, JOY_BUTTON_A)


func _bind_keyboard_p1() -> void:
	# Bewegen: WASD, Sprung: Leertaste, Dash: Shift, Schuss: linke Maustaste oder F.
	# Gezielt wird mit der Maus.
	_key("p1_left", KEY_A)
	_key("p1_right", KEY_D)
	_key("p1_up", KEY_W)
	_key("p1_down", KEY_S)
	_key("p1_jump", KEY_SPACE)
	_key("p1_dash", KEY_SHIFT)
	_key("p1_fire", KEY_F)
	_mouse("p1_fire", MOUSE_BUTTON_LEFT)
	_key("p1_ability", KEY_E)
	_key("p1_hook", KEY_R)
	_key("p1_weapon", KEY_Q)
	_key("p1_interact", KEY_G)
	_key("p1_confirm", KEY_ENTER)


func _bind_keyboard_p2() -> void:
	# Bewegen: Pfeiltasten, Sprung: Pfeil hoch, Dash: Schraegstrich, Schuss: Punkt.
	_key("p2_left", KEY_LEFT)
	_key("p2_right", KEY_RIGHT)
	_key("p2_up", KEY_UP)
	_key("p2_down", KEY_DOWN)
	_key("p2_jump", KEY_UP)
	_key("p2_dash", KEY_SLASH)
	_key("p2_fire", KEY_PERIOD)
	_key("p2_ability", KEY_COMMA)
	_key("p2_hook", KEY_N)
	_key("p2_weapon", KEY_M)
	_key("p2_interact", KEY_L)
	_key("p2_confirm", KEY_KP_ENTER)
