class_name WaveModifiers
extends RefCounted
## Besondere Bedingungen einzelner Wellen, damit nicht jede Welle gleich ablaeuft.
## Werte sind Faktoren auf den Director: credits (Spawnrate), cap (Obergrenze),
## hp, elite (Elite-Anteil), gold (Beute), speed (Gegnertempo) und optional kinds
## (nur diese Gegnertypen).

## bonus: zusaetzliche Gold-Praemie, wenn man diesen Vertrag waehlt (0,3 = 30 Prozent mehr Gold in der Welle).
## color: Farbe der Vertragskarte.
const DATA := {
	"normal": {"name": "", "text": "", "bonus": 0.0, "color": Color(0.7, 0.8, 0.95)},
	"swarm": {"name": "SWARM", "text": "Viel mehr Gegner, dafür schwächer", "credits": 1.7, "cap": 1.5, "hp": 0.6, "bonus": 0.3, "color": Color(1.0, 0.75, 0.3)},
	"elites": {"name": "ELITE RUSH", "text": "Viele Elites mit besonderen Fähigkeiten", "elite": 3.5, "credits": 0.8, "bonus": 0.5, "color": Color(1.0, 0.45, 0.35)},
	"armor": {"name": "HEAVY METAL", "text": "Gegner sind zäher, lassen aber doppelt Gold fallen", "hp": 1.5, "gold": 2.0, "credits": 0.85, "bonus": 0.0, "color": Color(0.65, 0.75, 0.95)},
	"air": {"name": "AIR RAID", "text": "Buzzer, Gunner und Mortar greifen an", "kinds": ["flyer", "shooter", "mortar"], "bonus": 0.25, "color": Color(0.55, 0.9, 1.0)},
	"rush": {"name": "OVERDRIVE", "text": "Alle Gegner sind schneller", "speed": 1.4, "credits": 0.9, "bonus": 0.35, "color": Color(1.0, 0.6, 0.8)},
}

const POOL := ["swarm", "elites", "armor", "air", "rush"]


## Gold-Faktor einer Welle: Modifikator mal Vertragspraemie.
static func gold_factor(id: String) -> float:
	var info: Dictionary = DATA[id]
	return float(info.get("gold", 1.0)) * (1.0 + float(info.get("bonus", 0.0)))


## Drei Vertraege fuer die naechste Welle: sicher (Standard) und zwei zufaellige mit Risiko und Praemie.
static func offers(previous: String) -> Array[String]:
	var options: Array = POOL.filter(func(id: String) -> bool: return id != previous)
	options.shuffle()
	var result: Array[String] = ["normal"]
	result.append(options[0])
	result.append(options[1])
	return result


## Waehlt den Modifikator fuer eine Welle. Welle 1 ist immer normal, die letzte Welle
## ist die Elite-Welle, sonst zufaellig ohne direkte Wiederholung.
static func pick(wave: int, max_waves: int, previous: String) -> String:
	if wave <= 1:
		return "normal"
	if wave >= max_waves:
		return "elites"
	var options: Array = POOL.filter(func(id: String) -> bool: return id != previous)
	return options[randi() % options.size()]
