class_name Firmware
extends RefCounted
## Bewegungs-Firmware. Wird im Shop gekauft und ist persoenlich. "max" ist die
## Zahl der Stapel (1 = einmalig).

const DATA := {
	"double_jump": {"name": "Doppelsprung", "text": "ein Sprung mehr in der Luft", "max": 2},
	"wall_jump": {"name": "Wandsprung", "text": "an Wänden abspringen und rutschen", "max": 1},
	"glide": {"name": "Gleitschirm", "text": "Sprung halten bremst den Fall", "max": 1},
	"slam": {"name": "Bodenstoß", "text": "in der Luft runter + Sprung: Aufprall mit Schaden", "max": 1},
	"hook": {"name": "Greifhaken", "text": "Haken (Quadrat) zieht dich zum Zielpunkt", "max": 1},
	"dash_charge": {"name": "Dash-Ladung", "text": "eine Dash-Aufladung mehr", "max": 2},
}

const SHORT := {
	"double_jump": "Doppelsprung", "wall_jump": "Wandsprung", "glide": "Gleiten",
	"slam": "Stoß", "hook": "Haken", "dash_charge": "Dash+",
}
