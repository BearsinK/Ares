class_name Weapons
extends RefCounted
## Waffenwerte. Waffen sind neutral, Elemente kommen ueber Module (oder fest in manchen Waffen).
## kind "projectile": fliegende Geschosse (auch Schrot, Raketen, Drohnen, Scheiben)
## kind "hitscan": sofortiger Treffer entlang einer Linie (Strahl, Sniper)
## kind "lob": Bogenwurf mit Schuettel-Aufladung (Feuer halten = schuetteln, loslassen = werfen)
## kind "sweep": Schwung vor dem Spieler, trifft alle im Bogen und raeumt gegnerische Schuesse ab
## kind "stream": Sog-Kegel, der Gegner zu einem Punkt vor dem Spieler zieht und schwach verletzt
## kind "chain": Kettenblitz, springt von Gegner zu Gegner
## kind "deploy": legt etwas ab (entity "mine" oder "sentry")
## Jede Waffe hat ein Magazin ("mag" Schuss) und eine Nachladezeit ("reload" Sekunden). Optional "ammo_cost" (Standard 1).
## Optional: "element" (fester Standard-Effekt, ein Modul ersetzt ihn), "burst" (Schuesse pro Druck) und "burst_gap",
## "status" und "status_time" (Zustand beim Treffer), "gravity" (Bogenflug), "bounces", "boomerang" (Sekunden bis zur Umkehr),
## "zone" (Wolke beim Aufprall), "slow" (bremst den Schuetzen beim Halten), "tag" (Kurztext), "dps" (Schaetzung fuer die Karte).

## Waffen, die nur eine Klasse benutzen darf. Alles andere (rapid, shotgun, rocket, beam) darf jeder.
const OWNER := {
	"dust": "roomba", "sweeper": "roomba", "disc": "roomba", "vacuum": "roomba", "zapper": "roomba",
	"turret": "hexapod", "sniper": "hexapod",
	"can": "vending",
	"dronegun": "printer",
}

## Die fuenf Waffen jeder Klasse, in Anzeigereihenfolge (Klassenwaffe zuerst).
const CLASS_SETS := {
	"roomba": ["dust", "sweeper", "disc", "vacuum", "zapper"],
	"hexapod": ["turret", "sniper"],
	"vending": ["can"],
	"printer": ["dronegun"],
}

const ALL_IDS: Array[String] = ["dust", "sweeper", "disc", "vacuum", "zapper", "turret", "sniper", "can", "dronegun", "rapid", "shotgun", "rocket", "beam"]


## Klasse, der die Waffe gehoert ("" = darf jeder).
static func owner_of(weapon_id: String) -> String:
	return String(OWNER.get(weapon_id, ""))


static func usable_by(weapon_id: String, class_id: String) -> bool:
	return not OWNER.has(weapon_id) or OWNER[weapon_id] == class_id


const DATA := {
	"dust": {
		"mag": 36, "reload": 1.1,
		"name": "Dustgun", "kind": "projectile", "color": Color(0.8, 0.92, 1.0),
		"fire_rate": 6.0, "damage": 8.0, "pellets": 1, "spread": 0.04,
		"speed": 950.0, "lifetime": 0.9, "pierce": 0, "size": 4.0, "push": 0.8,
		"recoil": 40.0, "shake": 1.0, "sound": "shoot", "barrel": 14.0,
	},
	"sweeper": {
		"mag": 16, "reload": 1.3,
		"name": "Sweeper", "kind": "sweep", "color": Color(0.55, 1.0, 0.75),
		"tag": "Schwung im Nahbereich, räumt Schüsse ab",
		"fire_rate": 3.0, "damage": 26.0, "range": 175.0, "arc": 1.9, "push": 3.4,
		"recoil": 0.0, "shake": 2.0, "sound": "sweep", "barrel": 10.0,
	},
	"disc": {
		"mag": 8, "reload": 1.4,
		"name": "Razor Disc", "kind": "projectile", "style": "disc", "color": Color(0.9, 0.95, 1.0),
		"tag": "Wurfscheibe, kehrt zurück und trifft zweimal",
		"fire_rate": 1.8, "damage": 15.0, "pellets": 1, "spread": 0.02,
		"speed": 820.0, "lifetime": 3.0, "pierce": 99, "size": 12.0, "push": 0.6, "boomerang": 0.5,
		"recoil": 30.0, "shake": 1.5, "sound": "disc", "barrel": 14.0, "dps": 54,
	},
	"vacuum": {
		"mag": 90, "reload": 1.8,
		"name": "Suction", "kind": "stream", "color": Color(0.7, 0.85, 1.0),
		"tag": "Sog, zieht Gegner zusammen",
		"fire_rate": 14.0, "damage": 2.4, "range": 360.0, "cone": 0.5, "focus": 0.55, "pull": 0.9, "slow": 0.7,
		"recoil": 0.0, "shake": 0.3, "sound": "suck_tick", "barrel": 14.0,
	},
	"zapper": {
		"mag": 24, "reload": 1.5,
		"name": "Zapper", "kind": "chain", "color": Color(1.0, 0.95, 0.35), "element": "lightning",
		"tag": "Kettenblitz, springt auf vier Ziele",
		"fire_rate": 4.0, "damage": 12.0, "range": 480.0, "cone": 0.4, "jumps": 3, "jump_range": 230.0, "falloff": 0.85,
		"recoil": 10.0, "shake": 1.0, "sound": "zap_gun", "barrel": 14.0, "dps": 48,
	},
	"dronegun": {
		"mag": 24, "reload": 1.2,
		"name": "Drone Pulse", "kind": "projectile", "color": Color(1.0, 0.65, 0.3),
		"fire_rate": 3.6, "damage": 5.0, "pellets": 1, "spread": 0.07,
		"speed": 900.0, "lifetime": 0.8, "pierce": 0, "size": 3.5,
		"recoil": 0.0, "shake": 0.3, "sound": "drone_shot", "barrel": 14.0,
	},
	"rapid": {
		"mag": 70, "reload": 1.5,
		"name": "Rapid", "kind": "projectile", "color": Color(1.0, 0.9, 0.4),
		"fire_rate": 14.0, "damage": 4.0, "pellets": 1, "spread": 0.04, "spread_heat": 0.1,
		"speed": 1100.0, "lifetime": 0.8, "pierce": 0, "size": 3.0, "push": 0.2,
		"recoil": 25.0, "shake": 0.6, "sound": "shoot_rapid", "barrel": 16.0,
	},
	"shotgun": {
		"mag": 6, "reload": 1.7,
		"name": "Scatter", "kind": "projectile", "color": Color(1.0, 0.7, 0.3),
		"fire_rate": 1.3, "damage": 6.0, "pellets": 9, "spread": 0.3,
		"speed": 900.0, "lifetime": 0.32, "pierce": 0, "size": 3.0, "push": 2.4,
		"recoil": 320.0, "shake": 6.0, "sound": "shotgun", "barrel": 12.0,
	},
	"rocket": {
		"mag": 4, "reload": 2.0,
		"name": "Rocket", "kind": "projectile", "color": Color(1.0, 0.45, 0.2),
		"fire_rate": 1.0, "damage": 20.0, "pellets": 1, "spread": 0.0,
		# Verfolgungsrakete: startet langsam, beschleunigt und lenkt auf den naechsten Gegner.
		"speed": 380.0, "speed_max": 780.0, "accel": 1100.0, "homing": 4.2, "lifetime": 2.2, "pierce": 0, "size": 7.0, "push": 1.6,
		"explosion_radius": 120.0, "explosion_damage": 45.0,
		"recoil": 260.0, "shake": 7.0, "sound": "rocket", "barrel": 18.0,
	},
	"beam": {
		"mag": 90, "reload": 1.6,
		"name": "Beam", "kind": "hitscan", "color": Color(0.4, 1.0, 1.0),
		# Dauerstrahl: Schaden waechst, je laenger er auf dem Ziel liegt (bis 2x nach 1,4 s), trifft bis zu vier
		# Gegner in einer Linie und verlangsamt den Schuetzen beim Halten.
		"fire_rate": 20.0, "damage": 1.7, "range": 650.0, "pierce": 3,
		"ramp_time": 1.4, "ramp_max": 2.0, "slow": 0.55, "push": 0.1,
		"width": 5.0, "tracer_life": 0.06,
		"recoil": 15.0, "shake": 0.6, "sound": "beam", "barrel": 16.0,
	},
	"can": {
		"mag": 8, "reload": 1.6,
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
		"mag": 14, "reload": 1.4,
		"name": "Turret", "kind": "hitscan", "color": Color(0.75, 0.9, 1.0),
		"fire_rate": 2.8, "damage": 34.0, "range": 1500.0, "pierce": 3,
		"width": 3.0, "tracer_life": 0.12,
		"recoil": 0.0, "shake": 3.0, "sound": "turret", "barrel": 26.0,
	},
	"sniper": {
		"mag": 5, "reload": 2.0,
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
	if weapon.has("tag"):
		kind = String(weapon.tag)
	elif weapon.kind == "hitscan":
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
	var burst := float(weapon.get("burst", 1))
	var per_second := damage * burst * float(weapon.fire_rate)
	if weapon.has("dps"):
		per_second = float(weapon.dps)
	return "%s, ca. %d Schaden/s" % [kind, int(round(per_second))]


static func get_weapon(id: String) -> Dictionary:
	return DATA[id]
