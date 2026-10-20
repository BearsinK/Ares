class_name Firmware
extends RefCounted
## Bewegungs-Firmware. Wird im Shop gekauft und ist persoenlich. "max" ist die
## Zahl der Stapel (1 = einmalig).

const DATA := {
	"double_jump": {"name": "Double Jump", "text": "ein Sprung mehr in der Luft", "max": 2},
	"wall_jump": {"name": "Wall Jump", "text": "an Wänden abspringen und rutschen", "max": 1},
	"glide": {"name": "Glider", "text": "Sprung halten bremst den Fall", "max": 1},
	"slam": {"name": "Ground Slam", "text": "in der Luft runter + Sprung: Aufprall mit Schaden", "max": 1},
	"hook": {"name": "Grapple Hook", "text": "Haken (Quadrat) zieht dich zum Zielpunkt", "max": 1},
	"dash_charge": {"name": "Dash Cell", "text": "eine Dash-Aufladung mehr", "max": 2},
}

const SHORT := {
	"double_jump": "Double Jump", "wall_jump": "Wall Jump", "glide": "Glider",
	"slam": "Slam", "hook": "Grapple", "dash_charge": "Dash+",
}
