class_name Elements
extends RefCounted
## Die vier Elemente. Sie kommen ueber Module in Waffen, nicht ueber Klassen.

const IDS: Array[String] = ["fire", "water", "ice", "lightning"]

const NAMES := {
	"fire": "Pyro", "water": "Hydro", "ice": "Cryo", "lightning": "Volt",
}

## Was ein Modul macht, kurz fuer Shop-Karten und Sandbox.
const INFO := {
	"fire": "Brennt Gegner an (Schaden über Zeit). Nasse Gegner: Dampfexplosion.",
	"water": "Macht Gegner nass. Mit Pyro Dampf, mit Cryo Eis, mit Volt Stromschlag.",
	"ice": "Verlangsamt Gegner. Nasse Gegner frieren ein, Brand wird gelöscht.",
	"lightning": "Nasse Gegner: 1,5-facher Schaden und Blitz auf Nachbarn.",
}

const COLORS := {
	"fire": Color(1.0, 0.5, 0.2),
	"water": Color(0.3, 0.6, 1.0),
	"ice": Color(0.7, 0.95, 1.0),
	"lightning": Color(1.0, 0.95, 0.3),
}


static func color_of(element: String, fallback := Color.WHITE) -> Color:
	return COLORS.get(element, fallback)
