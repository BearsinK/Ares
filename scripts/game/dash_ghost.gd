class_name DashGhost
extends Node2D
## Nachbild eines Roboters beim Dash: zeichnet die echte Figur einmal in Spielerfarbe und blendet aus.

const LIFETIME := 0.28

var class_id := "roomba"
var state: Dictionary = {}
var tint := Color(0.4, 0.8, 1.0)
var zoom := 1.0

var _age := 0.0


func _ready() -> void:
	z_index = -1
	add_to_group("dash_ghosts")
	modulate = Color(tint.r, tint.g, tint.b, 0.55)
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	var k := 1.0 - _age / LIFETIME
	modulate.a = 0.5 * k * k


func _draw() -> void:
	RobotArt.draw_player(self, class_id, state, Vector2.ZERO, zoom)
