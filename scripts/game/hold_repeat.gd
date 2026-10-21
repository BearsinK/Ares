class_name HoldRepeat
extends RefCounted
## Menue-Eingabe mit Wiederholung: Die Richtung gilt sofort beim Druecken, nach DELAY Sekunden
## Halten wiederholt sie sich alle INTERVAL Sekunden. Beide Spieler zaehlen.

const DELAY := 0.4
const INTERVAL := 0.07

var _direction := 0
var _time := 0.0


## Gibt -1, 0 oder 1 zurueck. negative und positive sind Aktionsnamen ohne Spielerkennung, z.B. "left" und "right".
func step(delta: float, negative: String, positive: String) -> int:
	var direction := 0
	if UiKit.pressed(negative):
		direction -= 1
	if UiKit.pressed(positive):
		direction += 1
	var held := int(_held(positive)) - int(_held(negative))
	if direction != 0:
		_direction = direction
		_time = 0.0
	elif held != 0 and held == _direction:
		_time += delta
		if _time >= DELAY:
			_time -= INTERVAL
			direction = held
	else:
		_direction = 0
	return direction


static func _held(suffix: String) -> bool:
	return Input.is_action_pressed("p1_" + suffix) or Input.is_action_pressed("p2_" + suffix)
