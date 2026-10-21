class_name Elements
extends RefCounted
## Die vier Elemente. Sie kommen ueber Module in Waffen, nicht ueber Klassen.

const IDS: Array[String] = ["fire", "water", "ice", "lightning"]

const NAMES := {
	"fire": "Pyro", "water": "Hydro", "ice": "Cryo", "lightning": "Volt",
}

## Was ein Modul macht, kurz fuer Shop-Karten und Sandbox.
const INFO := {
	"fire": "Brennt Gegner an. Kombos: Hydro = Dampf, Cryo = Schmelze, Volt = Überlast.",
	"water": "Macht Gegner nass. Kombos: Pyro = Dampf, Cryo = Einfrieren, Volt = Stromschlag.",
	"ice": "Verlangsamt Gegner. Kombos: Hydro = Einfrieren, Pyro = Schmelze, Volt = Kurzschluss.",
	"lightning": "Funken springen über. Kombos: Hydro = Stromschlag, Pyro = Überlast, Cryo = Kurzschluss.",
}

## Kombos aus zwei Elementen: Anzeigename, Farbe und was sie tun. Ist der Ausloeser ein anderer Spieler als der, der den
## Status gesetzt hat, wirkt die Kombo staerker (Koop).
const COMBOS := {
	"steam": {"text": "DAMPF", "color": Color(0.9, 0.95, 1.0), "pair": ["water", "fire"], "info": "Dampfexplosion im Umkreis"},
	"freeze": {"text": "EINGEFROREN", "color": Color(0.7, 0.95, 1.0), "pair": ["water", "ice"], "info": "Ziel steht still, nimmt mehr Schaden und zersplittert beim Tod"},
	"shock": {"text": "STROMSCHLAG", "color": Color(1.0, 0.95, 0.3), "pair": ["water", "lightning"], "info": "Mehrfacher Schaden, Blitz auf nasse Nachbarn, kurze Lähmung"},
	"melt": {"text": "SCHMELZE", "color": Color(1.0, 0.75, 0.5), "pair": ["fire", "ice"], "info": "Hebt beide Zustände auf"},
	"overload": {"text": "ÜBERLAST", "color": Color(1.0, 0.6, 0.2), "pair": ["fire", "lightning"], "info": "Brennendes Ziel explodiert"},
	"short": {"text": "KURZSCHLUSS", "color": Color(0.5, 0.95, 1.0), "pair": ["ice", "lightning"], "info": "Gefrorenes Ziel wird gelähmt und nimmt Schaden"},
}

const COLORS := {
	"fire": Color(1.0, 0.5, 0.2),
	"water": Color(0.3, 0.6, 1.0),
	"ice": Color(0.7, 0.95, 1.0),
	"lightning": Color(1.0, 0.95, 0.3),
}


static func color_of(element: String, fallback := Color.WHITE) -> Color:
	return COLORS.get(element, fallback)
