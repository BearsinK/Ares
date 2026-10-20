class_name WaveModifiers
extends RefCounted
## Besondere Bedingungen einzelner Wellen, damit nicht jede Welle gleich ablaeuft.
## Werte sind Faktoren auf den Director: credits (Spawnrate), cap (Obergrenze),
## hp, elite (Elite-Anteil), gold (Beute), speed (Gegnertempo) und optional kinds
## (nur diese Gegnertypen).

const DATA := {
	"normal": {"name": "", "text": ""},
	"swarm": {"name": "SCHWARM", "text": "Viel mehr Gegner, dafür schwächer", "credits": 1.7, "cap": 1.5, "hp": 0.6},
	"elites": {"name": "ELITE-WELLE", "text": "Viele Elites mit besonderen Fähigkeiten", "elite": 3.5, "credits": 0.8},
	"armor": {"name": "PANZERWELLE", "text": "Gegner sind zäher, lassen aber doppelt Gold fallen", "hp": 1.5, "gold": 2.0, "credits": 0.85},
	"air": {"name": "LUFTALARM", "text": "Flieger, Schützen und Mörser greifen an", "kinds": ["flyer", "shooter", "mortar"]},
	"rush": {"name": "STURM", "text": "Alle Gegner sind schneller", "speed": 1.4, "credits": 0.9},
}

const POOL := ["swarm", "elites", "armor", "air", "rush"]


## Waehlt den Modifikator fuer eine Welle. Welle 1 ist immer normal, die letzte Welle
## ist die Elite-Welle, sonst zufaellig ohne direkte Wiederholung.
static func pick(wave: int, max_waves: int, previous: String) -> String:
	if wave <= 1:
		return "normal"
	if wave >= max_waves:
		return "elites"
	var options: Array = POOL.filter(func(id: String) -> bool: return id != previous)
	return options[randi() % options.size()]
