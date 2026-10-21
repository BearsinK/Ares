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
	# Waffen-Upgrades: wirken auf alle Waffen des Spielers.
	"extmag": {
		"name": "Extended Mag",
		"mods": {
			"default": {"mag": 0.3},
			"vending": {"mag": 0.4},
		},
	},
	"speedloader": {
		"name": "Speed Loader",
		"mods": {
			"default": {"reload": 0.35},
			"hexapod": {"reload": 0.5},
		},
	},
	"splitter": {
		"name": "Split Barrel",
		"mods": {
			"default": {"proj": 1.0},
		},
	},
	"velocoil": {
		"name": "Velocity Coil",
		"mods": {
			"default": {"proj_speed": 0.25},
		},
	},
	"longbarrel": {
		"name": "Long Barrel",
		"mods": {
			"default": {"range": 0.25},
			"hexapod": {"range": 0.35},
		},
	},
	"stabilizer": {
		"name": "Stabilizer",
		"mods": {
			"default": {"accuracy": 0.3},
			"printer": {"accuracy": 0.4},
		},
	},
	"blastcore": {
		"name": "Blast Core",
		"mods": {
			"default": {"blast": 0.25},
			"vending": {"blast": 0.35},
			"printer": {"blast": 0.3},
		},
	},
	"killshot": {
		"name": "Killshot",
		"mods": {
			"default": {"crit_dmg": 0.5, "crit": 0.05},
			"hexapod": {"crit_dmg": 0.7, "crit": 0.05},
		},
	},
	"ecochip": {
		"name": "Eco Chip",
		"mods": {
			"default": {"ammo_save": 0.15},
		},
	},
	"heavyslugs": {
		"name": "Heavy Slugs",
		"mods": {
			"default": {"knock": 0.5},
			"vending": {"knock": 0.7},
		},
	},
	"ricochet": {
		"name": "Ricochet",
		"mods": {
			"default": {"bounce": 1.0},
		},
	},
	"seeker": {
		"name": "Seeker Chip",
		"mods": {
			"default": {"seek": 1.0},
		},
	},
}

## Verhaltens-Items: die grosse Goldkiste enthaelt immer eines davon.
const RARE_IDS: Array[String] = ["frenzy", "arccoil", "dashblast", "thorns", "laststand", "shieldcell", "recycler", "executioner", "splitter", "ricochet", "seeker"]
## Ziehgewicht seltener Items gegen 1,0 bei normalen: aus Kisten faellt etwa jedes sechste Item selten.
const RARE_WEIGHT := 0.4


## Zieht eine Item-Id aus der Liste. Seltene Items zaehlen mit rare_weight, normale mit 1.
static func weighted_pick(pool: Array, rare_weight := RARE_WEIGHT) -> String:
	var total := 0.0
	for id in pool:
		total += rare_weight if RARE_IDS.has(String(id)) else 1.0
	var roll := randf() * total
	for id in pool:
		roll -= rare_weight if RARE_IDS.has(String(id)) else 1.0
		if roll <= 0.0:
			return String(id)
	return String(pool[0])

const LABELS := {
	"damage": "Schaden", "fire_rate": "Feuerrate", "speed": "Tempo",
	"dash_cd": "Dash-Ladezeit", "pickup": "Sammelradius", "gold": "Gold",
	"dmg_taken": "weniger Schaden", "max_hp": "Leben",
	"ability_cd": "Fähigkeits-Ladezeit", "crit": "Crit-Chance", "kill_heal": "Leben pro Kill",
	"pierce": "Durchschlag", "death_blast": "Explosionsschaden", "link": "Cable Link",
	"frenzy": "Frenzy", "arc": "Arc", "dash_blast": "Dash Blast", "thorns": "Thorns", "rage": "Last Stand",
	"shield": "Schild", "recycle": "Recycler", "execute": "Executioner", "close": "Nahkampf", "far": "Fernkampf",
	"mag": "Magazin", "reload": "Nachladetempo", "proj": "Projektile", "proj_speed": "Projektiltempo", "range": "Reichweite",
	"accuracy": "Präzision", "blast": "Explosion", "crit_dmg": "Crit-Schaden", "knock": "Wucht", "bounce": "Abpraller",
	"seek": "Zielsuche", "ammo_save": "Munition sparen",
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
## Waffen-Upgrades. Ein zusaetzliches Projektil zaehlt nur zu diesem Anteil zum Gesamtschaden, der Rest wird auf alle verteilt.
const PROJ_EXTRA_VALUE := 0.6
## Streuwinkel zwischen den Projektilen eines Faechers (Einzelschuss-Waffen mit +Projektil), in rad.
const FAN_ANGLE := 0.1
## Lenkrate je Stapel Zielsuche (rad/s) und Blickfeld der Zielhilfe fuer Strahlen (rad).
const SEEK_TURN := 2.6
const SEEK_CONE := 0.14
## Anteil des Explosions-Zuwachses, der als Schaden dazukommt (der Rest geht in den Radius).
const BLAST_DAMAGE_SHARE := 0.5
## Mindest-Streuung nach Praezision (Anteil der Grundstreuung).
const ACCURACY_FLOOR := 0.1


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
		elif key == "proj":
			parts.append("+%d Projektil pro Schuss" % int(value))
		elif key == "reload":
			parts.append("+%d%% Nachladetempo" % int(round(value * 100.0)))
		elif key == "accuracy":
			parts.append("-%d%% Streuung" % int(round(value * 100.0)))
		elif key == "blast":
			parts.append("+%d%% Explosionsradius, +%d%% Explosionsschaden" % [int(round(value * 100.0)), int(round(value * BLAST_DAMAGE_SHARE * 100.0))])
		elif key == "bounce":
			parts.append("Kugeln, Strahlen und Raketen prallen %dx von Wänden ab" % int(value))
		elif key == "seek":
			parts.append("Schüsse lenken auf Gegner (Strahlen: Zielhilfe)")
		elif key == "ammo_save":
			parts.append("%d%% Chance: Schuss kostet keine Munition" % int(round(value * 100.0)))
		else:
			parts.append("+%d%% %s" % [int(value * 100.0), LABELS[key]])
	return ", ".join(parts)


## Solo: Perks, die nur mit Partner wirken, werden nicht angeboten (Main setzt das Flag beim Spawn der Spieler).
static var solo := false
const PARTNER_ONLY: Array[String] = ["cablelink"]


## Alle Perk-Ids, die im aktuellen Modus sinnvoll sind.
static func pool() -> Array[String]:
	var ids: Array[String] = []
	for id in DATA:
		if solo and PARTNER_ONLY.has(id):
			continue
		ids.append(id)
	return ids


static func random_ids(count: int) -> Array[String]:
	var ids: Array[String] = pool()
	ids.shuffle()
	return ids.slice(0, count)
