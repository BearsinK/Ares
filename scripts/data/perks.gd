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
		"name": "Oil Change",
		"mods": {
			"default": {"max_hp": 25.0},
			"hexapod": {"max_hp": 15.0, "speed": 0.1},
			"vending": {"dmg_taken": 0.15},
		},
	},
	"grease": {
		"name": "Nitro Spray",
		"mods": {
			"default": {"speed": 0.1},
			"hexapod": {"speed": 0.15},
			"vending": {"speed": 0.2},
		},
	},
	"coolant": {
		"name": "Coolant",
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
		"name": "Piggy Bank",
		"mods": {
			"default": {"gold": 0.25},
			"roomba": {"gold": 0.4},
		},
	},
	"plating": {
		"name": "Armor Plate",
		"mods": {
			"default": {"dmg_taken": 0.1},
			"vending": {"dmg_taken": 0.2},
		},
	},
	"chillloop": {
		"name": "Heatsink",
		"mods": {
			"default": {"ability_cd": 0.2},
			"hexapod": {"ability_cd": 0.25},
		},
	},
	"luckychip": {
		"name": "Lucky Chip",
		"mods": {
			"default": {"crit": 0.12},
			"hexapod": {"crit": 0.2},
		},
	},
	"scavenger": {
		"name": "Backup Power",
		"mods": {
			"default": {"kill_heal": 1.0},
			"vending": {"kill_heal": 1.5},
		},
	},
	"piercer": {
		"name": "Piercer",
		"mods": {
			"default": {"pierce": 1.0},
			"hexapod": {"pierce": 2.0},
		},
	},
	"boomchip": {
		"name": "Blast Cap",
		"mods": {
			"default": {"death_blast": 10.0},
			"printer": {"death_blast": 14.0},
		},
	},
	"cablelink": {
		"name": "Cable Link",
		"mods": {
			"default": {"link": 1.0},
		},
	},
	"sharpchip": {
		"name": "Sharp Chip",
		"mods": {
			"default": {"damage": 0.15},
			"roomba": {"damage": 0.25, "fire_rate": 0.1},
		},
	},
	"frenzy": {
		"name": "Frenzy",
		"mods": {
			"default": {"frenzy": 0.05},
			"hexapod": {"frenzy": 0.07},
		},
	},
	"arccoil": {
		"name": "Arc Coil",
		"mods": {
			"default": {"arc": 1.0},
			"printer": {"arc": 1.5},
		},
	},
	"dashblast": {
		"name": "Dash Blast",
		"mods": {
			"default": {"dash_blast": 1.0},
			"vending": {"dash_blast": 1.6},
		},
	},
	"thorns": {
		"name": "Thorns",
		"mods": {
			"default": {"thorns": 1.0},
			"vending": {"thorns": 1.5},
		},
	},
	"laststand": {
		"name": "Last Stand",
		"mods": {
			"default": {"rage": 1.0},
		},
	},
	"shieldcell": {
		"name": "Shield Cell",
		"mods": {
			"default": {"shield": 18.0},
			"printer": {"shield": 24.0},
			"hexapod": {"shield": 16.0},
		},
	},
	"recycler": {
		"name": "Recycler",
		"mods": {
			"default": {"recycle": 1.0},
		},
	},
	"executioner": {
		"name": "Executioner",
		"mods": {
			"default": {"execute": 0.5},
		},
	},
	"closequarters": {
		"name": "Close Quarters",
		"mods": {
			"default": {"close": 0.25},
			"roomba": {"close": 0.35},
			"vending": {"close": 0.4},
		},
	},
	"longshot": {
		"name": "Long Shot",
		"mods": {
			"default": {"far": 0.3},
			"hexapod": {"far": 0.45},
		},
	},
}

## Verhaltens-Items: die grosse Goldkiste enthaelt immer eines davon.
const RARE_IDS: Array[String] = ["frenzy", "arccoil", "dashblast", "thorns", "laststand", "shieldcell", "recycler", "executioner"]

const LABELS := {
	"damage": "Schaden", "fire_rate": "Feuerrate", "speed": "Tempo",
	"dash_cd": "Dash-Ladezeit", "pickup": "Sammelradius", "gold": "Gold",
	"dmg_taken": "weniger Schaden", "max_hp": "Leben",
	"ability_cd": "Fähigkeits-Ladezeit", "crit": "Crit-Chance", "kill_heal": "Leben pro Kill",
	"pierce": "Durchschlag", "death_blast": "Explosionsschaden", "link": "Cable Link",
	"frenzy": "Frenzy", "arc": "Arc", "dash_blast": "Dash Blast", "thorns": "Thorns", "rage": "Last Stand",
	"shield": "Schild", "recycle": "Recycler", "execute": "Executioner", "close": "Nahkampf", "far": "Fernkampf",
}

## Stapelbare Verhaltens-Perks (nicht nur Zahlen): Anteil pro Stapel und Schwellen, einmal definiert fuer Spiel und Text.
const FRENZY_STACKS := 5
const FRENZY_TIME := 4.0
const ARC_CHANCE := 0.15
const ARC_DAMAGE := 0.7
const ARC_RANGE := 260.0
const DASH_BLAST_DAMAGE := 14.0
const DASH_BLAST_RADIUS := 120.0
const THORNS_DAMAGE := 12.0
const THORNS_RADIUS := 170.0
const RAGE_THRESHOLD := 0.35
const RAGE_DAMAGE := 0.35
const RAGE_SPEED := 0.15
const SHIELD_DELAY := 4.0
const SHIELD_RATE := 24.0
const RECYCLE_SECONDS := 0.6
const EXECUTE_THRESHOLD := 0.3
const CLOSE_RANGE := 240.0
const FAR_RANGE := 650.0


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
		elif key == "frenzy":
			parts.append("Kill: +%d%% Feuerrate, %d s (bis %dx)" % [int(round(value * 100.0)), int(FRENZY_TIME), FRENZY_STACKS])
		elif key == "arc":
			parts.append("%d%% Chance: Treffer springt weiter (%d%% Schaden)" % [int(round(ARC_CHANCE * value * 100.0)), int(ARC_DAMAGE * 100.0)])
		elif key == "dash_blast":
			parts.append("Dash sprengt an Start und Ziel (%d Schaden)" % int(round(DASH_BLAST_DAMAGE * value)))
		elif key == "thorns":
			parts.append("Getroffen: Schockwelle (%d Schaden)" % int(round(THORNS_DAMAGE * value)))
		elif key == "rage":
			parts.append("Unter %d%% Leben: +%d%% Schaden, +%d%% Tempo" % [int(RAGE_THRESHOLD * 100.0), int(RAGE_DAMAGE * value * 100.0), int(RAGE_SPEED * value * 100.0)])
		elif key == "shield":
			parts.append("+%d Schild, lädt nach %d s ohne Treffer auf" % [int(value), int(SHIELD_DELAY)])
		elif key == "recycle":
			parts.append("Kill verkürzt Fähigkeits-Ladezeit um %s s" % ("%.1f" % (RECYCLE_SECONDS * value)).trim_suffix(".0"))
		elif key == "execute":
			parts.append("+%d%% Schaden auf Gegner unter %d%% Leben" % [int(value * 100.0), int(EXECUTE_THRESHOLD * 100.0)])
		elif key == "close":
			parts.append("+%d%% Schaden auf unter %d px" % [int(value * 100.0), int(CLOSE_RANGE)])
		elif key == "far":
			parts.append("+%d%% Schaden auf über %d px" % [int(value * 100.0), int(FAR_RANGE)])
		else:
			parts.append("+%d%% %s" % [int(value * 100.0), LABELS[key]])
	return ", ".join(parts)


static func random_ids(count: int) -> Array[String]:
	var ids: Array[String] = []
	for id in DATA:
		ids.append(id)
	ids.shuffle()
	return ids.slice(0, count)
