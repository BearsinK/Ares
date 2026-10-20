class_name Meta
extends RefCounted
## Dauerhafte Verbesserungen und Freischaltungen der Werkstatt. Bezahlt wird mit
## Gesichts-Chips, die man am Ende jedes Laufs bekommt (siehe SaveData).

const UPGRADES := {
	"vitality": {
		"name": "Heavy Frame", "text": "+8 Leben pro Stufe", "max": 5,
		"costs": [20, 30, 45, 65, 90],
	},
	"firepower": {
		"name": "Overcharge", "text": "+4% Schaden pro Stufe", "max": 5,
		"costs": [25, 35, 50, 70, 95],
	},
	"capital": {
		"name": "Starter Cash", "text": "+12 Gold zu Beginn pro Stufe", "max": 5,
		"costs": [15, 25, 35, 50, 70],
	},
	"scholar": {
		"name": "Brain Chip", "text": "+8% Erfahrung pro Stufe", "max": 4,
		"costs": [20, 35, 55, 80],
	},
	"joints": {
		"name": "Turbo Joints", "text": "+3% Tempo pro Stufe", "max": 3,
		"costs": [25, 45, 70],
	},
	"dealer": {
		"name": "Black Market", "text": "Erster Reroll im Shop ist gratis", "max": 1,
		"costs": [60],
	},
}

## Schwierigkeitsgrade (Titelmenue): Faktoren auf Gegner-Leben, -Schaden und Spawnrate, dazu Chips-Faktor am Laufende.
const DIFFICULTIES := [
	{"id": "easy", "name": "Rookie", "hp": 0.75, "damage": 0.7, "credits": 0.85, "chips": 0.6,
		"text": "Gegner haben weniger Leben und machen weniger Schaden. Chips x0,6"},
	{"id": "normal", "name": "Normal", "hp": 1.0, "damage": 1.0, "credits": 1.0, "chips": 1.0,
		"text": "So ist das Spiel gedacht."},
	{"id": "hard", "name": "Hardcore", "hp": 1.35, "damage": 1.3, "credits": 1.15, "chips": 1.7,
		"text": "Zähere, härtere Gegner und mehr davon. Chips x1,7"},
]


static func difficulty_data() -> Dictionary:
	return DIFFICULTIES[clampi(SaveData.difficulty(), 0, DIFFICULTIES.size() - 1)]


# Freischaltungen: Klassen und Waffen, die im Shop erscheinen duerfen.
const CLASS_UNLOCKS := {"vending": 50, "printer": 80}
const WEAPON_UNLOCKS := {"shotgun": 30, "rocket": 40, "beam": 40, "sniper": 60}


static func cost_of(upgrade_id: String, level: int) -> int:
	var costs: Array = UPGRADES[upgrade_id].costs
	return int(costs[mini(level, costs.size() - 1)])


## Startboni eines Spielers aus den Werkstatt-Stufen (als Mods fuer Player.add_mods).
static func player_mods() -> Dictionary:
	return {
		"max_hp": 8.0 * SaveData.level("vitality"),
		"damage": 0.04 * SaveData.level("firepower"),
		"speed": 0.03 * SaveData.level("joints"),
	}


static func xp_multiplier() -> float:
	return 1.0 + 0.08 * SaveData.level("scholar")


static func start_gold() -> int:
	return 12 * SaveData.level("capital")


## Chips fuer einen Lauf: Fortschritt, Kills, Stufe und ein Bonus fuer den Boss.
static func chips_for_run(waves_cleared: int, kills: int, level: int, boss_defeated: bool) -> int:
	var total := waves_cleared * 6 + kills / 25 + level * 2 + (100 if boss_defeated else 0)
	return maxi(5, int(round(float(total) * float(difficulty_data().chips))))
