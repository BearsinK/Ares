class_name Perks
extends RefCounted
## Team-Perks fuer Level-Ups. Beide Spieler bekommen den gewaehlten Perk, die
## Wirkung haengt aber von der Klasse ab (Eintrag "default" gilt, wenn eine
## Klasse keine eigene Variante hat).
##
## Moegliche Werte: damage, fire_rate, speed, dash_cd, pickup, gold, dmg_taken
## (Anteile, 0.2 = 20 Prozent) und max_hp (fester Wert).

const DATA := {
	"overclock": {
		"name": "Overclock",
		"mods": {
			"default": {"fire_rate": 0.2},
			"hexapod": {"damage": 0.3},
			"vending": {"damage": 0.25},
		},
	},
	"oilchange": {
		"name": "Ölwechsel",
		"mods": {
			"default": {"max_hp": 25.0},
			"hexapod": {"max_hp": 15.0, "speed": 0.1},
			"vending": {"dmg_taken": 0.15},
		},
	},
	"grease": {
		"name": "Fettspray",
		"mods": {
			"default": {"speed": 0.1},
			"hexapod": {"speed": 0.15},
			"vending": {"speed": 0.2},
		},
	},
	"coolant": {
		"name": "Kühlmittel",
		"mods": {
			"default": {"dash_cd": 0.2},
			"hexapod": {"dash_cd": 0.3},
		},
	},
	"magnet": {
		"name": "Magnet",
		"mods": {
			"default": {"pickup": 0.5},
			"roomba": {"pickup": 1.0},
		},
	},
	"piggy": {
		"name": "Sparschwein",
		"mods": {
			"default": {"gold": 0.25},
			"roomba": {"gold": 0.4},
		},
	},
	"plating": {
		"name": "Panzerplatte",
		"mods": {
			"default": {"dmg_taken": 0.1},
			"vending": {"dmg_taken": 0.2},
		},
	},
	"chillloop": {
		"name": "Kühlkreislauf",
		"mods": {
			"default": {"ability_cd": 0.2},
			"hexapod": {"ability_cd": 0.25},
		},
	},
	"luckychip": {
		"name": "Glückschip",
		"mods": {
			"default": {"crit": 0.12},
			"hexapod": {"crit": 0.2},
		},
	},
	"scavenger": {
		"name": "Notstrom",
		"mods": {
			"default": {"kill_heal": 1.0},
			"vending": {"kill_heal": 1.5},
		},
	},
	"piercer": {
		"name": "Durchschlag",
		"mods": {
			"default": {"pierce": 1.0},
			"hexapod": {"pierce": 2.0},
		},
	},
	"boomchip": {
		"name": "Sprengkapsel",
		"mods": {
			"default": {"death_blast": 10.0},
			"printer": {"death_blast": 14.0},
		},
	},
	"cablelink": {
		"name": "Kabelbaum",
		"mods": {
			"default": {"link": 1.0},
		},
	},
	"sharpchip": {
		"name": "Scharfer Chip",
		"mods": {
			"default": {"damage": 0.15},
			"roomba": {"damage": 0.25, "fire_rate": 0.1},
		},
	},
}

const LABELS := {
	"damage": "Schaden", "fire_rate": "Feuerrate", "speed": "Tempo",
	"dash_cd": "Dash-Ladezeit", "pickup": "Sammelradius", "gold": "Gold",
	"dmg_taken": "weniger Schaden", "max_hp": "Leben",
	"ability_cd": "Fähigkeits-Ladezeit", "crit": "Crit-Chance", "kill_heal": "Leben pro Kill",
	"pierce": "Durchschlag", "death_blast": "Explosionsschaden", "link": "Kabelbaum",
}


static func mods_for(perk_id: String, class_id: String) -> Dictionary:
	var variants: Dictionary = DATA[perk_id].mods
	return variants.get(class_id, variants.default)


static func describe(perk_id: String, class_id: String) -> String:
	var parts: Array[String] = []
	var mods := mods_for(perk_id, class_id)
	for key in mods:
		var value: float = mods[key]
		if key == "max_hp":
			parts.append("+%d %s" % [int(value), LABELS[key]])
		elif key == "dash_cd" or key == "ability_cd":
			parts.append("-%d%% %s" % [int(value * 100.0), LABELS[key]])
		elif key == "kill_heal":
			parts.append("+%s %s" % [("%.1f" % value).trim_suffix(".0"), LABELS[key]])
		elif key == "link":
			parts.append("Nah beim Partner (unter 450 px): +15% Schaden, 1 Leben pro Sekunde")
		elif key == "pierce":
			parts.append("Schüsse durchschlagen +%d Gegner" % int(value))
		elif key == "death_blast":
			parts.append("Besiegte Gegner explodieren (%d Schaden)" % int(value))
		elif key == "dmg_taken":
			parts.append("%d%% %s" % [int(value * 100.0), LABELS[key]])
		else:
			parts.append("+%d%% %s" % [int(value * 100.0), LABELS[key]])
	return ", ".join(parts)


static func random_ids(count: int) -> Array[String]:
	var ids: Array[String] = []
	for id in DATA:
		ids.append(id)
	ids.shuffle()
	return ids.slice(0, count)
