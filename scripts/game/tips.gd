class_name Tips
extends RefCounted
## Einmalige Hinweise: Beim ersten Auftauchen von etwas Neuem blendet das HUD unten in der Mitte
## eine kurze Erklaerung ein. Gesehene Hinweise merkt der Spielstand, in den Optionen lassen sie
## sich abschalten. Spielcode meldet nur ueber Tips.request, das HUD zeigt sie nacheinander.

const DATA := {
	"chest": {"title": "KISTE", "text": "Gold zahlen und Kreis / G / L drücken. Drin steckt ein Item für den, der sie öffnet."},
	"altar_blood": {"title": "BLUTALTAR", "text": "Tauscht 30 % deiner Leben gegen Gold. Bis zu dreimal pro Karte, nur mit genug Leben."},
	"altar_chance": {"title": "GLÜCKSALTAR", "text": "Gold gegen ein Item, doch nicht jeder Versuch gewinnt. Bis zu dreimal pro Karte."},
	"revive": {"title": "PARTNER AM BODEN", "text": "Geh nah ran und halte Kreis / G / L, dann steht er wieder auf. Fallen beide, ist der Lauf vorbei."},
	"dash": {"title": "DASH", "text": "R1 / Shift / Strich: kurzer Sprint, dabei unverwundbar. Die Ladung füllt sich von selbst wieder auf."},
	"medic": {"title": "MEDIC", "text": "Heilt andere Gegner in seiner Nähe. Zuerst ausschalten."},
	"bomber": {"title": "SPRENGI", "text": "Rennt auf euch zu und explodiert. Auf Abstand erledigen oder wegdashen."},
	"aegis": {"title": "AEGIS", "text": "Sein Frontschild fängt Schüsse ab. Trefft ihn von hinten, von oben oder mit Sprengungen."},
	"nest": {"title": "NEST", "text": "Setzt laufend Buzzer in die Welt. Zerstört das Nest, dann stürzen seine Buzzer mit ab."},
	"reload": {"title": "MAGAZIN LEER", "text": "Die Waffe lädt von selbst nach. Mit Kreuz / T / B lädst du vorher nach, Feuer unterbricht ein angefangenes Nachladen."},
	"combo": {"title": "ELEMENT-KOMBO", "text": "Zwei Elemente auf einem Gegner lösen eine Kombo aus. Vom Partner gesetzt, wirkt sie viel stärker."},
	"elite": {"title": "ELITE", "text": "Größer, zäher und mit eigener Fähigkeit. Dafür dreifache Beute und oft eine Reparatur."},
}

## Wartende Hinweise, die das HUD der Reihe nach zeigt.
static var queue: Array[String] = []


static func request(id: String) -> void:
	if not DATA.has(id) or not SaveData.tips_enabled() or SaveData.tip_seen(id) or queue.has(id):
		return
	queue.append(id)
