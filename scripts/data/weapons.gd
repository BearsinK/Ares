class_name Weapons
extends RefCounted
## Waffenwerte. Waffen sind neutral, Elemente kommen spaeter ueber Module.
## kind "projectile": fliegende Geschosse (auch Schrot und Raketen)
## kind "hitscan": sofortiger Treffer entlang einer Linie (Strahl, Sniper)
## kind "lob": Bogenwurf mit Schuettel-Aufladung (Feuer halten = schuetteln, loslassen = werfen)

const ALL_IDS: Array[String] = ["dust", "rapid", "shotgun", "rocket", "beam", "sniper", "can", "turret"]

const DATA := {
	"dust": {
		"name": "Staubkugeln", "kind": "projectile", "color": Color(0.8, 0.92, 1.0),
		"fire_rate": 6.0, "damage": 7.0, "pellets": 1, "spread": 0.04,
		"speed": 950.0, "lifetime": 0.9, "pierce": 0, "size": 4.0,
		"recoil": 40.0, "shake": 1.0, "sound": "shoot", "barrel": 14.0,
	},
	"rapid": {
		"name": "Schnellfeuer", "kind": "projectile", "color": Color(1.0, 0.9, 0.4),
		"fire_rate": 14.0, "damage": 4.0, "pellets": 1, "spread": 0.1,
		"speed": 1100.0, "lifetime": 0.8, "pierce": 0, "size": 3.0,
		"recoil": 25.0, "shake": 0.6, "sound": "shoot", "barrel": 16.0,
	},
	"shotgun": {
		"name": "Schrot", "kind": "projectile", "color": Color(1.0, 0.7, 0.3),
		"fire_rate": 1.3, "damage": 6.0, "pellets": 9, "spread": 0.3,
		"speed": 900.0, "lifetime": 0.32, "pierce": 0, "size": 3.0,
		"recoil": 320.0, "shake": 6.0, "sound": "shotgun", "barrel": 12.0,
	},
	"rocket": {
		"name": "Rakete", "kind": "projectile", "color": Color(1.0, 0.45, 0.2),
		"fire_rate": 1.0, "damage": 20.0, "pellets": 1, "spread": 0.0,
		"speed": 650.0, "lifetime": 1.6, "pierce": 0, "size": 7.0,
		"explosion_radius": 120.0, "explosion_damage": 45.0,
		"recoil": 260.0, "shake": 7.0, "sound": "rocket", "barrel": 18.0,
	},
	"beam": {
		"name": "Strahl", "kind": "hitscan", "color": Color(0.4, 1.0, 1.0),
		"fire_rate": 20.0, "damage": 3.5, "range": 650.0, "pierce": 99,
		"width": 5.0, "tracer_life": 0.06,
		"recoil": 15.0, "shake": 0.6, "sound": "beam", "barrel": 16.0,
	},
	"can": {
		"name": "Dose", "kind": "lob", "color": Color(0.4, 0.95, 0.55),
		"fire_rate": 2.8, "damage": 12.0, "pellets": 1, "spread": 0.0,
		"speed": 700.0, "speed_max": 1000.0, "gravity": 1400.0, "lifetime": 4.0,
		"pierce": 0, "size": 9.0,
		# Schuetteln: Aufladezeit bis voll, ab min_shake explodiert die Dose beim Aufprall.
		"shake_time": 1.2, "min_shake": 0.2,
		"explosion_radius": 70.0, "explosion_radius_max": 190.0,
		"explosion_damage": 30.0, "explosion_damage_max": 100.0,
		"recoil": 60.0, "shake": 2.0, "sound": "can_throw", "barrel": 16.0,
	},
	"turret": {
		"name": "Geschuetz", "kind": "hitscan", "color": Color(0.75, 0.9, 1.0),
		"fire_rate": 2.8, "damage": 34.0, "range": 1500.0, "pierce": 3,
		"width": 3.0, "tracer_life": 0.12,
		"recoil": 0.0, "shake": 3.0, "sound": "turret", "barrel": 26.0,
	},
	"sniper": {
		"name": "Sniper", "kind": "hitscan", "color": Color(1.0, 1.0, 1.0),
		"fire_rate": 0.9, "damage": 90.0, "range": 1900.0, "pierce": 6,
		"width": 3.0, "tracer_life": 0.2,
		"recoil": 340.0, "shake": 7.0, "sound": "sniper", "barrel": 28.0,
	},
}


## Kurzbeschreibung fuer Shop-Karten: Waffenart und grober Schaden pro Sekunde.
static func summary(weapon_id: String) -> String:
	var weapon: Dictionary = DATA[weapon_id]
	var damage := float(weapon.damage) * float(weapon.get("pellets", 1))
	var kind := "Projektil"
	if weapon.kind == "hitscan":
		kind = "Strahl, trifft sofort"
	elif weapon.kind == "lob":
		kind = "Wurf, schuetteln = Explosion"
		damage = float(weapon.explosion_damage)
	elif weapon.has("explosion_radius"):
		kind = "Explosiv"
		damage = float(weapon.explosion_damage)
	elif int(weapon.get("pellets", 1)) > 1:
		kind = "Streuschuss"
	return "%s, ca. %d Schaden/s" % [kind, int(round(damage * float(weapon.fire_rate)))]


static func get_weapon(id: String) -> Dictionary:
	return DATA[id]
