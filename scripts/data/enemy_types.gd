class_name EnemyTypes
extends RefCounted
## Werte der Gegnertypen. Gegner verursachen keinen Kontaktschaden, nur ihre
## Angriffe tun weh. Jeder Angriff hat eine Vorwarnung (windup).

const DATA := {
	"walker": {
		"name": "Laeufer", "color": Color(0.85, 0.3, 0.35), "radius": 14.0,
		"hp": 30.0, "speed": 150.0, "movement": "ground", "jump": 720.0,
		"attack": "melee", "melee_shape": "cone", "reach": 46.0,
		"windup": 0.5, "cooldown": 1.3, "damage": 10.0, "knockback": 1.0,
		"xp": 1, "gold_chance": 0.4, "cost": 1.0, "from_time": 0.0,
	},
	"shooter": {
		"name": "Schuetze", "color": Color(0.7, 0.35, 0.85), "radius": 13.0,
		"hp": 25.0, "speed": 80.0, "movement": "ground", "jump": 720.0,
		"attack": "ranged", "keep_distance": 450.0, "range": 700.0,
		"windup": 0.8, "lock_time": 0.25, "cooldown": 2.2, "damage": 8.0,
		"projectile_speed": 520.0, "knockback": 1.0,
		"xp": 2, "gold_chance": 0.5, "cost": 2.0, "from_time": 30.0,
	},
	"flyer": {
		"name": "Flieger", "color": Color(0.95, 0.65, 0.25), "radius": 11.0,
		"hp": 18.0, "speed": 190.0, "movement": "fly",
		"attack": "ranged", "keep_distance": 320.0, "range": 650.0,
		"windup": 0.7, "lock_time": 0.25, "cooldown": 2.6, "damage": 7.0,
		"projectile_speed": 480.0, "knockback": 1.5,
		"xp": 2, "gold_chance": 0.5, "cost": 2.0, "from_time": 70.0,
	},
	"charger": {
		"name": "Rammbock", "color": Color(0.9, 0.5, 0.15), "radius": 18.0,
		"hp": 70.0, "speed": 110.0, "movement": "ground", "jump": 600.0,
		"attack": "charge", "keep_distance": 280.0, "range": 480.0,
		"windup": 0.8, "lock_time": 0.2, "cooldown": 2.6, "damage": 18.0,
		"charge_speed": 820.0, "charge_time": 0.5, "knockback": 0.5,
		"xp": 3, "gold_chance": 0.7, "cost": 3.0, "from_time": 110.0,
	},
	"mortar": {
		"name": "Moerser", "color": Color(0.3, 0.7, 0.6), "radius": 16.0,
		"hp": 45.0, "speed": 60.0, "movement": "ground", "jump": 500.0,
		"attack": "strike", "keep_distance": 650.0, "range": 1000.0,
		"windup": 0.6, "lock_time": 0.0, "cooldown": 3.8, "damage": 20.0,
		"strike_radius": 95.0, "strike_delay": 1.2, "knockback": 0.8,
		"xp": 3, "gold_chance": 0.7, "cost": 4.0, "from_time": 190.0,
	},
	"brute": {
		"name": "Brute", "color": Color(0.55, 0.2, 0.25), "radius": 26.0,
		"hp": 240.0, "speed": 65.0, "movement": "ground", "jump": 650.0,
		"attack": "melee", "melee_shape": "circle", "reach": 105.0,
		"windup": 0.9, "cooldown": 2.6, "damage": 25.0, "knockback": 0.2,
		"xp": 6, "gold_chance": 1.0, "cost": 6.0, "from_time": 150.0,
	},
}


static func get_type(kind: String) -> Dictionary:
	return DATA[kind]
