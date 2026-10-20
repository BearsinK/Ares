class_name RobotClasses
extends RefCounted
## Basiswerte der Klassen. Alle Klassen starten mit demselben Grundkit
## (laufen, springen, Hauptangriff), unterscheiden sich in den Werten.
## Jede Klasse hat eine Faehigkeit auf L2 (siehe Ability).

const DATA := {
	"roomba": {
		"name": "Roomba",
		"color": Color(0.35, 0.85, 0.85),
		"eye_color": Color(0.4, 1.0, 0.5),
		"radius": 32.0,
		"size": Vector2(68, 26),
		"muzzle": Vector2(-25, -14),
		"speed": 300.0,
		"accel": 2600.0,
		"air_accel": 1800.0,
		"jump_speed": 900.0,
		"max_hp": 100.0,
		"dash_charges": 2,
		"dash_cooldown": 1.3,
		"stationary_fire": false,
		"weapons": ["dust"],
		"pickup_bonus": 0.5,
		"step": "glide",
		"damage_mult": 1.0,
		"ability": {"id": "suck", "name": "Vortex", "cooldown": 9.0, "duration": 1.4},
	},
	"hexapod": {
		"name": "Hexapod",
		"color": Color(0.92, 0.92, 0.95),
		"eye_color": Color(0.4, 0.8, 1.0),
		"radius": 28.0,
		"size": Vector2(56, 46),
		"muzzle": Vector2(2, -18),
		"speed": 390.0,
		"accel": 3000.0,
		"air_accel": 2000.0,
		"jump_speed": 900.0,
		"max_hp": 80.0,
		"dash_charges": 2,
		"dash_cooldown": 1.3,
		# Geschuetz: die Klassenwaffe (erste Waffe) schiesst nur im Stand (am Boden oder
		# an der Wand), nach kurzer Aufbauzeit. Dafuer klettert er Waende hoch.
		"stationary_fire": true,
		"step": "step",
		"wall_climb": true,
		"weapons": ["turret"],
		"damage_mult": 1.0,
		"ability": {"id": "overwatch", "name": "Overwatch", "cooldown": 14.0, "duration": 4.0},
	},
	"vending": {
		"name": "Vendor",
		"color": Color(0.35, 0.75, 0.4),
		"eye_color": Color(1.0, 0.9, 0.4),
		"radius": 34.0,
		"size": Vector2(68, 108),
		"muzzle": Vector2(-8, 30),
		"speed": 220.0,
		"accel": 1400.0,
		"air_accel": 1000.0,
		"jump_speed": 800.0,
		"max_hp": 160.0,
		"heavy": true,
		"tips_over": true,
		"knockback_resist": 0.5,
		"step": "tread",
		"dash_charges": 2,
		"dash_cooldown": 1.3,
		"stationary_fire": false,
		"weapons": ["can"],
		"damage_mult": 1.2,
		"ability": {"id": "roll", "name": "Steamroller", "cooldown": 12.0, "duration": 3.0},
	},
	"printer": {
		"name": "Printbot",
		"color": Color(0.2, 0.2, 0.25),
		"eye_color": Color(1.0, 0.55, 0.2),
		"radius": 29.0,
		"size": Vector2(58, 74),
		"muzzle": Vector2(0, -40),
		"speed": 300.0,
		"accel": 2400.0,
		"air_accel": 1700.0,
		"jump_speed": 900.0,
		"max_hp": 90.0,
		"tips_over": true,
		"step": "step",
		"kill_cooldown": 0.3,
		"escort_drones": 2,
		"dash_charges": 2,
		"dash_cooldown": 1.3,
		"stationary_fire": false,
		"weapons": ["rapid"],
		"damage_mult": 1.0,
		"ability": {"id": "print", "name": "Drone Drop", "cooldown": 15.0, "duration": 9.0},
	},
}

const PLAYER_COLORS := [Color(0.3, 0.7, 1.0), Color(1.0, 0.6, 0.2)]


static func get_stats(class_id: String) -> Dictionary:
	return DATA[class_id]
