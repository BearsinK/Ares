class_name Firmware
extends RefCounted
## Bewegungs-Firmware. Wird im Shop gekauft und ist persoenlich. "max" ist die
## Zahl der Stapel (1 = einmalig).

const DATA := {
	"double_jump": {"name": "Double Jump", "text": "ein Sprung mehr in der Luft", "max": 3},
	"wall_jump": {"name": "Wall Jump", "text": "an Wänden abspringen und rutschen", "max": 1},
	"glide": {"name": "Glider", "text": "Sprung halten bremst den Fall", "max": 1},
	"slam": {"name": "Ground Slam", "text": "in der Luft runter + Sprung: Aufprall mit Schaden", "max": 1},
	"hook": {"name": "Grapple Hook", "text": "Haken (L2) zieht dich zum Zielpunkt", "max": 1},
	"dash_charge": {"name": "Dash Cell", "text": "eine Dash-Aufladung mehr", "max": 3},
	"jet": {"name": "Jet Boots", "text": "in der Luft Sprung halten: Schub nach oben, der Tank füllt sich am Boden", "max": 1},
	"sprint": {"name": "Turbo Legs", "text": "10 Prozent mehr Lauftempo", "max": 3},
	"spring": {"name": "Spring Legs", "text": "Sprünge werden 12 Prozent höher", "max": 2},
	"blade": {"name": "Blade Dash", "text": "der Dash verletzt Gegner auf dem Weg", "max": 1},
	"long_dash": {"name": "Long Dash", "text": "der Dash trägt 30 Prozent weiter", "max": 2},
}

const BLADE_DAMAGE := 22.0
const BLADE_REACH := 54.0
const SPRINT_BONUS := 0.1
const SPRING_BONUS := 0.12
const LONG_DASH_BONUS := 0.3

const SHORT := {
	"double_jump": "Double Jump", "wall_jump": "Wall Jump", "glide": "Glider",
	"slam": "Slam", "hook": "Grapple", "dash_charge": "Dash+",
	"jet": "Jet", "sprint": "Turbo", "spring": "Spring", "blade": "Blade", "long_dash": "Reach",
}
