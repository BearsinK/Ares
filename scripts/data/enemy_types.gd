class_name EnemyTypes
extends RefCounted
## Werte der Gegnertypen. Gegner verursachen keinen Kontaktschaden, nur ihre
## Angriffe tun weh. Jeder Angriff hat eine Vorwarnung (windup).

const DATA := {
	"walker": {
		"name": "Grunt", "color": Color(0.85, 0.3, 0.35), "radius": 14.0,
		"hp": 30.0, "speed": 150.0, "movement": "ground", "jump": 640.0,
		"attack": "melee", "melee_shape": "cone", "reach": 46.0,
		"windup": 0.5, "cooldown": 1.3, "damage": 10.0, "knockback": 1.0,
		"xp": 1, "gold_chance": 0.4, "cost": 1.0, "from_time": 0.0,
	},
	"shooter": {
		"name": "Gunner", "color": Color(0.7, 0.35, 0.85), "radius": 13.0,
		"hp": 25.0, "speed": 80.0, "movement": "ground", "jump": 600.0,
		"attack": "ranged", "keep_distance": 450.0, "range": 700.0,
		"windup": 0.8, "lock_time": 0.25, "cooldown": 2.2, "damage": 8.0,
		"projectile_speed": 360.0, "knockback": 1.0,
		"xp": 2, "gold_chance": 0.5, "cost": 2.0, "from_time": 30.0,
	},
	"flyer": {
		"name": "Buzzer", "color": Color(0.95, 0.65, 0.25), "radius": 11.0,
		"hp": 18.0, "speed": 190.0, "movement": "fly",
		"attack": "ranged", "keep_distance": 320.0, "range": 650.0,
		"windup": 0.7, "lock_time": 0.25, "cooldown": 2.6, "damage": 7.0,
		"projectile_speed": 340.0, "knockback": 1.5,
		"xp": 2, "gold_chance": 0.5, "cost": 2.0, "from_time": 70.0,
	},
	"charger": {
		"name": "Ramtank", "color": Color(0.9, 0.5, 0.15), "radius": 18.0,
		"hp": 70.0, "speed": 110.0, "movement": "ground", "jump": 520.0,
		"attack": "charge", "keep_distance": 280.0, "range": 480.0,
		"windup": 0.8, "lock_time": 0.2, "cooldown": 2.6, "damage": 18.0,
		"charge_speed": 820.0, "charge_time": 0.5, "knockback": 0.5, "champion_hp": 1000.0,
		"xp": 3, "gold_chance": 0.7, "cost": 3.0, "from_time": 110.0,
	},
	"mortar": {
		"name": "Mortar", "color": Color(0.3, 0.7, 0.6), "radius": 16.0,
		"hp": 45.0, "speed": 60.0, "movement": "ground", "jump": 450.0,
		"attack": "strike", "keep_distance": 650.0, "range": 1000.0,
		"windup": 0.6, "lock_time": 0.0, "cooldown": 3.8, "damage": 20.0,
		"strike_radius": 95.0, "strike_delay": 1.2, "knockback": 0.8, "champion_hp": 800.0,
		"xp": 3, "gold_chance": 0.7, "cost": 4.0, "from_time": 190.0,
	},
	"brute": {
		"name": "Brute", "color": Color(0.55, 0.2, 0.25), "radius": 26.0,
		"hp": 240.0, "speed": 65.0, "movement": "ground", "jump": 540.0,
		"attack": "melee", "melee_shape": "circle", "reach": 105.0,
		"windup": 0.9, "cooldown": 2.6, "damage": 25.0, "knockback": 0.2, "champion_hp": 1200.0,
		"xp": 6, "gold_chance": 1.0, "cost": 6.0, "from_time": 150.0,
	},
	# Sprengi: rennt los und sprengt sich nach kurzer Warnung selbst. Ohne Beute, wenn er sich sprengt: abschiessen, bevor er da ist.
	"bomber": {
		"name": "Sprengi", "color": Color(0.95, 0.55, 0.15), "radius": 12.0,
		"hp": 22.0, "speed": 215.0, "movement": "ground", "jump": 640.0,
		"attack": "melee", "melee_shape": "circle", "reach": 80.0, "suicide": true,
		"windup": 0.55, "cooldown": 1.0, "damage": 22.0, "knockback": 1.0,
		"xp": 2, "gold_chance": 0.6, "cost": 2.0, "from_time": 90.0,
	},
	# Medic: haelt Abstand und heilt verwundete Gegner in der Naehe. Zuerst ausschalten.
	"medic": {
		"name": "Medic", "color": Color(0.4, 0.85, 0.55), "radius": 14.0,
		"hp": 40.0, "speed": 85.0, "movement": "ground", "jump": 560.0,
		"attack": "heal", "keep_distance": 560.0, "range": 340.0, "heal_amount": 0.3, "heal_targets": 5,
		"windup": 0.9, "cooldown": 4.5, "damage": 0.0, "knockback": 1.0,
		"xp": 4, "gold_chance": 0.9, "cost": 4.0, "from_time": 170.0,
	},
	# Aegis: Frontschild fangt Direkttreffer von vorn weitgehend ab. Von hinten, von oben, mit Sprengungen und Faehigkeiten
	# oder im Zangengriff mit dem Partner ist er verwundbar (Gegner kollidieren nicht mit Spielern: durchdashen geht).
	"aegis": {
		"name": "Aegis", "color": Color(0.3, 0.6, 0.9), "radius": 17.0,
		"hp": 95.0, "speed": 68.0, "movement": "ground", "jump": 500.0,
		"attack": "melee", "melee_shape": "cone", "reach": 62.0, "frontal_shield": true,
		"windup": 0.75, "cooldown": 2.3, "damage": 16.0, "knockback": 0.3,
		"xp": 4, "gold_chance": 0.8, "cost": 5.0, "from_time": 180.0,
	},
	# Nest: bleibt auf Abstand und setzt alle paar Sekunden Buzzer in die Welt (hoechstens max_minions gleichzeitig).
	# Zerstoert man es, stuerzen seine Buzzer mit ab. Die Buzzer geben keine Beute.
	"nest": {
		"name": "Nest", "color": Color(0.5, 0.75, 0.25), "radius": 20.0,
		"hp": 150.0, "speed": 50.0, "movement": "ground", "jump": 400.0,
		"attack": "spawn", "keep_distance": 600.0, "range": 1000.0, "spawn_kind": "flyer", "spawn_count": 2, "max_minions": 6,
		"windup": 1.0, "cooldown": 6.5, "damage": 0.0, "knockback": 0.2,
		"xp": 5, "gold_chance": 0.9, "cost": 6.0, "from_time": 240.0,
	},
}


## Wächter pro Karte (Welle 3, 6, 9): jeder Typ spielt sich anders.
const GUARDIANS := {3: "brute", 6: "charger", 9: "mortar"}


## Elite-Arten: jede hat eine eigene Farbe, einen Namen und eine Mechanik (siehe Enemy._update_elite).
const ELITE_KINDS := {
	"fire": {"name": "INFERNO", "color": Color(1.0, 0.5, 0.15), "text": "legt Feuerherde"},
	"shield": {"name": "BULWARK", "color": Color(0.45, 0.8, 1.0), "text": "trägt einen Schild"},
	"storm": {"name": "STORMER", "color": Color(0.95, 0.85, 0.3), "text": "feuert Blitzfächer"},
	"frost": {"name": "FROSTBITE", "color": Color(0.75, 0.92, 1.0), "text": "bremst in der Nähe"},
}


static func random_elite_kind() -> String:
	var ids: Array = ELITE_KINDS.keys()
	return ids[randi() % ids.size()]


static func get_type(kind: String) -> Dictionary:
	return DATA[kind]
