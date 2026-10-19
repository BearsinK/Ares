class_name Elements
extends RefCounted
## Die vier Elemente. Sie kommen ueber Module in Waffen, nicht ueber Klassen.

const IDS: Array[String] = ["fire", "water", "ice", "lightning"]

const NAMES := {
	"fire": "Feuer", "water": "Wasser", "ice": "Eis", "lightning": "Blitz",
}

const COLORS := {
	"fire": Color(1.0, 0.5, 0.2),
	"water": Color(0.3, 0.6, 1.0),
	"ice": Color(0.7, 0.95, 1.0),
	"lightning": Color(1.0, 0.95, 0.3),
}


static func color_of(element: String, fallback := Color.WHITE) -> Color:
	return COLORS.get(element, fallback)
