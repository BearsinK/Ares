class_name Minions
extends RefCounted
## Diener des Printbots. Sie greifen selbststaendig an, haben Leben und eine Lebensdauer: Sie sterben, wenn Gegner sie treffen
## oder die Zeit ablaeuft. Gegner greifen nahe Diener bevorzugt an (sie lenken ab).
##   style "gunner": schwebt beim Besitzer und beschiesst den naechsten Gegner in Reichweite
##   style "biter": fliegt in Gegner hinein und beisst
## "cap" ist die Hoechstzahl je Besitzer und Art, "scale" die Groesse der Zeichnung.
const DATA := {
	"printling": {
		"name": "Printling", "style": "gunner", "hp": 30.0, "life": 26.0, "radius": 13.0, "cap": 3,
		"range": 650.0, "interval": 1.0, "damage": 4.0, "orbit": 92.0, "scale": 1.0,
	},
	"gnat": {
		"name": "Gnat", "style": "biter", "hp": 10.0, "life": 7.0, "radius": 9.0, "cap": 6,
		"range": 620.0, "speed": 470.0, "damage": 4.0, "interval": 0.35, "scale": 0.62,
	},
	"warbot": {
		"name": "Warbot", "style": "gunner", "hp": 80.0, "life": 13.0, "radius": 16.0, "cap": 3,
		"range": 720.0, "interval": 0.42, "damage": 6.0, "orbit": 140.0, "scale": 1.3,
	},
}

## Der Drucker druckt von selbst nach: alle "interval" Sekunden ein Printling, bis "cap" erreicht ist.
const AUTO_PRINT := {"kind": "printling", "interval": 6.0}
