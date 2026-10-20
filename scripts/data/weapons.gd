class_name Weapons
extends RefCounted
## Waffenwerte. Waffen sind neutral, Elemente kommen spaeter ueber Module.
## kind "projectile": fliegende Geschosse (auch Schrot und Raketen)
## kind "hitscan": sofortiger Treffer entlang einer Linie (Strahl, Sniper)
## kind "lob": Bogenwurf mit Schuettel-Aufladung (Feuer halten = schuetteln, loslassen = werfen)

const ALL_IDS: Array[String] = ["dust", "rapid", "shotgun", "rocket", "beam", "sniper", "can", "turret"]

## Klassenwaffen, die nur ihre Klasse im Shop angeboten bekommt.
const EXCLUSIVE := {"can": "vending", "turret": "hexapod"}


static func usable_by(weapon_id: String, class_id: String) -> bool:
	return not EXCLUSIVE.has(weapon_id) or EXCLUSIVE[weapon_id] == class_id


const DATA := {
	"dust": {
		"name": "Dustgun", "kind": "projectile", "color": Color(0.8, 0.92, 1.0),
		"fire_rate": 6.0, "damage": 8.0, "pellets": 1, "spread": 0.04,
		"speed": 950.0, "lifetime": 0.9, "pierce": 0, "size": 4.0, "push": 0.8,
		"recoil": 40.0, "shake": 1.0, "sound": "shoot", "barrel": 14.0,
	},
	"dronegun": {
		"name": "Drone Pulse", "kind": "projectile", "color": Color(1.0, 0.65, 0.3),
		"fire_rate": 3.6, "damage": 5.0, "pellets": 1, "spread": 0.07,
		"speed": 900.0, "lifetime": 0.8, "pierce": 0, "size": 3.5,
		"recoil": 0.0, "shake": 0.3, "sound": "drone_shot", "barrel": 14.0,
	},
	"rapid": {
		"name": "Rapid", "kind": "projectile", "color": Color(1.0, 0.9, 0.4),
		"fire_rate": 14.0, "damage": 4.0, "pellets": 1, "spread": 0.04, "spread_heat": 0.1,
		"speed": 1100.0, "lifetime": 0.8, "pierce": 0, "size": 3.0, "push": 0.2,
		"recoil": 25.0, "shake": 0.6, "sound": "shoot_rapid", "barrel": 16.0,
	},
	"shotgun": {
		"name": "Scatter", "kind": "projectile", "color": Color(1.0, 0.7, 0.3),
		"fire_rate": 1.3, "damage": 6.0, "pellets": 9, "spread": 0.3,
		"speed": 900.0, "lifetime": 0.32, "pierce": 0, "size": 3.0, "push": 2.4,
		"recoil": 320.0, "shake": 6.0, "sound": "shotgun", "barrel": 12.0,
	},
	"rocket": {
		"name": "Rocket", "kind": "projectile", "color": Color(1.0, 0.45, 0.2),
		"fire_rate": 1.0, "damage": 20.0, "pellets": 1, "spread": 0.0,
		# Verfolgungsrakete: startet langsam, beschleunigt und lenkt auf den naechsten Gegner.
		"speed": 380.0, "speed_max": 780.0, "accel": 1100.0, "homing": 4.2, "lifetime": 2.2, "pierce": 0, "size": 7.0, "push": 1.6,
		"explosion_radius": 120.0, "explosion_damage": 45.0,
		"recoil": 260.0, "shake": 7.0, "sound": "rocket", "barrel": 18.0,
	},
	"beam": {
		"name": "Beam", "kind": "hitscan", "color": Color(0.4, 1.0, 1.0),
		# Dauerstrahl: Schaden waechst, je laenger er auf dem Ziel liegt (bis 2x nach 1,4 s), trifft bis zu vier
		# Gegner in einer Linie und verlangsamt den Schuetzen beim Halten.
		"fire_rate": 20.0, "damage": 1.7, "range": 650.0, "pierce": 3,
		"ramp_time": 1.4, "ramp_max": 2.0, "slow": 0.55, "push": 0.1,
		"width": 5.0, "tracer_life": 0.06,
		"recoil": 15.0, "shake": 0.6, "sound": "beam", "barrel": 16.0,
	},
	"can": {
		"name": "Soda Bomb", "kind": "lob", "color": Color(0.72, 0.86, 0.8),
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
		"name": "Turret", "kind": "hitscan", "color": Color(0.75, 0.9, 1.0),
		"fire_rate": 2.8, "damage": 34.0, "range": 1500.0, "pierce": 3,
		"width": 3.0, "tracer_life": 0.12,
		"recoil": 0.0, "shake": 3.0, "sound": "turret", "barrel": 26.0,
	},
	"sniper": {
		"name": "Sniper", "kind": "hitscan", "color": Color(1.0, 1.0, 1.0),
		"fire_rate": 0.9, "damage": 90.0, "range": 1900.0, "pierce": 6,
		"width": 3.0, "tracer_life": 0.2, "push": 4.0,
		"recoil": 340.0, "shake": 7.0, "sound": "sniper", "barrel": 28.0,
	},
}


## Kurzbeschreibung fuer Shop-Karten: Waffenart und grober Schaden pro Sekunde.
static func summary(weapon_id: String) -> String:
	var weapon: Dictionary = DATA[weapon_id]
	var damage := float(weapon.damage) * float(weapon.get("pellets", 1))
	var kind := "Projektil"
	if weapon.kind == "hitscan":
		kind = "Dauerstrahl, wächst" if weapon.has("ramp_time") else "Strahl, trifft sofort"
	elif weapon.kind == "lob":
		kind = "Wurf, schütteln = Explosion"
		damage = float(weapon.explosion_damage)
	elif weapon.has("homing"):
		kind = "Lenkrakete"
		damage = float(weapon.explosion_damage)
	elif weapon.has("explosion_radius"):
		kind = "Explosiv"
		damage = float(weapon.explosion_damage)
	elif int(weapon.get("pellets", 1)) > 1:
		kind = "Streuschuss"
	return "%s, ca. %d Schaden/s" % [kind, int(round(damage * float(weapon.fire_rate)))]


static func get_weapon(id: String) -> Dictionary:
	return DATA[id]
