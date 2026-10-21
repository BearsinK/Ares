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
	"turret": "hexapod", "sniper": "hexapod", "burst": "hexapod", "mine": "hexapod", "silk": "hexapod",
	"can": "vending", "flamer": "vending", "sixpack": "vending", "coinshot": "vending", "dispenser": "vending",
	"dronegun": "printer", "boomdrone": "printer", "toner": "printer", "label": "printer", "paperjam": "printer",
}

## Die fuenf Waffen jeder Klasse, in Anzeigereihenfolge (Klassenwaffe zuerst).
const CLASS_SETS := {
	"roomba": ["dust", "sweeper", "disc", "vacuum", "zapper"],
	"hexapod": ["turret", "sniper", "burst", "mine", "silk"],
	"vending": ["can", "flamer", "sixpack", "coinshot", "dispenser"],
	"printer": ["dronegun", "boomdrone", "toner", "label", "paperjam"],
}

const ALL_IDS: Array[String] = ["dust", "sweeper", "disc", "vacuum", "zapper", "turret", "sniper", "burst", "mine", "silk", "can", "flamer", "sixpack", "coinshot", "dispenser", "dronegun", "boomdrone", "toner", "label", "paperjam", "rapid", "shotgun", "rocket", "beam"]


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
		"fire_rate": 3.0, "damage": 22.0, "range": 175.0, "arc": 1.9, "push": 3.4,
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
	"burst": {
		"mag": 24, "reload": 1.6,
		"name": "Burst", "kind": "projectile", "color": Color(0.7, 0.95, 1.0),
		"tag": "Dreiersalve, präzise",
		"fire_rate": 2.4, "burst": 3, "burst_gap": 0.065, "damage": 14.0, "pellets": 1, "spread": 0.02,
		"speed": 1500.0, "lifetime": 0.75, "pierce": 1, "size": 3.5, "push": 0.7,
		"recoil": 30.0, "shake": 1.5, "sound": "burst_shot", "barrel": 24.0,
	},
	"mine": {
		"mag": 5, "reload": 2.4,
		"name": "Proxy Mine", "kind": "deploy", "entity": "mine", "color": Color(1.0, 0.55, 0.25),
		"tag": "Legt Minen, die bei Gegnern explodieren",
		"fire_rate": 1.6, "damage": 60.0, "radius": 120.0, "trigger": 95.0, "arm": 0.5, "life": 25.0, "max_active": 4, "throw": 560.0, "lift": 260.0,
		"recoil": 0.0, "shake": 1.0, "sound": "mine_place", "barrel": 18.0, "dps": 60,
	},
	"silk": {
		"mag": 20, "reload": 1.6,
		"name": "Webshot", "kind": "projectile", "style": "web", "color": Color(0.92, 0.96, 1.0),
		"tag": "Gespinst, bremst Gegner stark",
		"fire_rate": 3.0, "damage": 6.0, "pellets": 1, "spread": 0.03,
		"speed": 900.0, "lifetime": 0.9, "pierce": 0, "size": 6.0, "push": 0.2,
		"status": "webbed", "status_time": 3.0,
		"recoil": 0.0, "shake": 0.8, "sound": "web_shot", "barrel": 22.0,
	},
	"flamer": {
		"mag": 120, "reload": 2.2,
		"name": "Flamer", "kind": "projectile", "style": "flame", "color": Color(1.0, 0.6, 0.2), "element": "fire",
		"tag": "Flammenstrahl, brennt, durchdringt alles",
		"fire_rate": 16.0, "damage": 3.2, "pellets": 1, "spread": 0.11,
		"speed": 560.0, "lifetime": 0.38, "pierce": 99, "size": 9.0, "push": 0.15, "slow": 0.7, "dps": 51,
		"recoil": 0.0, "shake": 0.4, "sound": "flame", "barrel": 22.0,
	},
	"sixpack": {
		"mag": 3, "reload": 2.4,
		"name": "Six Pack", "kind": "projectile", "style": "can", "color": Color(0.72, 0.9, 0.82),
		"tag": "Sechs Dosen im Bogen, jede explodiert",
		"fire_rate": 0.8, "damage": 6.0, "pellets": 6, "spread": 0.3,
		"speed": 640.0, "lifetime": 3.0, "pierce": 0, "size": 6.0, "push": 0.6, "gravity": 1000.0,
		"explosion_radius": 58.0, "explosion_damage": 20.0,
		"recoil": 140.0, "shake": 3.5, "sound": "volley", "barrel": 22.0,
	},
	"coinshot": {
		"mag": 30, "reload": 1.5,
		"name": "Coinshot", "kind": "projectile", "style": "coin", "color": Color(1.0, 0.85, 0.3),
		"tag": "Münzen, prallen ab, stärker mit Gold",
		"fire_rate": 5.0, "damage": 9.0, "pellets": 1, "spread": 0.05,
		"speed": 1000.0, "lifetime": 1.4, "pierce": 0, "size": 5.0, "push": 0.6, "bounces": 3, "gold_scale": 0.0008,
		"recoil": 60.0, "shake": 0.8, "sound": "coin_shot", "barrel": 22.0,
	},
	"dispenser": {
		"mag": 3, "reload": 3.0,
		"name": "Dispenser", "kind": "deploy", "entity": "sentry", "color": Color(0.6, 1.0, 0.75),
		"tag": "Stellt einen Geschützturm auf",
		"fire_rate": 0.8, "damage": 12.0, "life": 14.0, "max_active": 2, "range": 700.0, "rate": 2.4, "throw": 420.0, "lift": 200.0,
		"recoil": 0.0, "shake": 1.0, "sound": "mine_place", "barrel": 18.0, "dps": 58,
	},
	"boomdrone": {
		"mag": 10, "reload": 2.2, "ammo_cost": 2,
		"name": "Boomdrone", "kind": "projectile", "style": "drone", "color": Color(1.0, 0.65, 0.3),
		"tag": "Zwei Sprengdrohnen, jagen Gegner",
		"fire_rate": 1.3, "damage": 5.0, "pellets": 2, "spread": 0.35,
		"speed": 440.0, "lifetime": 2.4, "pierce": 0, "size": 6.0, "push": 0.8, "homing": 3.2,
		"explosion_radius": 78.0, "explosion_damage": 22.0,
		"recoil": 0.0, "shake": 2.0, "sound": "drone_launch", "barrel": 18.0,
	},
	"toner": {
		"mag": 6, "reload": 2.2,
		"name": "Toner Bomb", "kind": "projectile", "style": "canister", "color": Color(0.62, 0.48, 0.95),
		"tag": "Tonerwolke, verletzt und verlangsamt",
		"fire_rate": 0.9, "damage": 8.0, "pellets": 1, "spread": 0.02,
		"speed": 620.0, "lifetime": 3.0, "pierce": 0, "size": 8.0, "push": 0.5, "gravity": 900.0,
		"zone": {"radius": 115.0, "time": 4.5, "dps": 14.0, "status": "inked"}, "dps": 18,
		"recoil": 0.0, "shake": 2.0, "sound": "toner_pop", "barrel": 18.0,
	},
	"label": {
		"mag": 30, "reload": 1.4,
		"name": "Labeler", "kind": "projectile", "style": "label", "color": Color(1.0, 0.88, 0.35),
		"tag": "Markiert Ziele, alle machen mehr Schaden",
		"fire_rate": 4.0, "damage": 4.0, "pellets": 1, "spread": 0.03,
		"speed": 1200.0, "lifetime": 0.7, "pierce": 0, "size": 5.0, "push": 0.3,
		"status": "tagged", "status_time": 6.0,
		"recoil": 0.0, "shake": 0.5, "sound": "label_shot", "barrel": 18.0,
	},
	"paperjam": {
		"mag": 5, "reload": 1.8,
		"name": "Paper Jam", "kind": "projectile", "style": "paper", "color": Color(0.96, 0.96, 0.9),
		"tag": "Papierwelle, betäubt kurz",
		"fire_rate": 1.1, "damage": 5.0, "pellets": 7, "spread": 0.5,
		"speed": 760.0, "lifetime": 0.4, "pierce": 2, "size": 5.0, "push": 1.2,
		"status": "stun", "status_time": 0.7,
		"recoil": 0.0, "shake": 2.5, "sound": "paper_burst", "barrel": 18.0,
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
	return "%s, ca. %d DPS" % [kind, int(round(per_second))]


## Nicht waehlbare Waffenwerte fuer Dinge, die selbst schiessen (Geschuetzturm).
const AUX := {
	"sentry_gun": {
		"name": "Sentry", "kind": "projectile", "color": Color(0.6, 1.0, 0.75),
		"fire_rate": 2.4, "damage": 12.0, "pellets": 1, "spread": 0.05,
		"speed": 1000.0, "lifetime": 0.9, "pierce": 0, "size": 4.0, "push": 0.6,
		"recoil": 0.0, "shake": 0.0, "sound": "shoot", "barrel": 0.0,
	},
}


static func get_weapon(id: String) -> Dictionary:
	return DATA[id] if DATA.has(id) else AUX[id]
