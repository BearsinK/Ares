class_name RobotClasses
extends RefCounted
## Basiswerte der Klassen. Alle Klassen starten mit demselben Grundkit
## (laufen, springen, Hauptangriff), unterscheiden sich in den Werten.
## Die Klassenfaehigkeiten kommen spaeter.

const DATA := {
	"roomba": {
		"name": "Roomba",
		"color": Color(0.35, 0.85, 0.85),
		"eye_color": Color(0.4, 1.0, 0.5),
		"radius": 20.0,
		"speed": 300.0,
		"accel": 2600.0,
		"air_accel": 1800.0,
		"jump_speed": 900.0,
		"dash_charges": 2,
		"dash_cooldown": 1.3,
		"stationary_fire": false,
		"weapons": ["dust"],
		"damage_mult": 1.0,
	},
	"hexapod": {
		"name": "Hexapod",
		"color": Color(0.92, 0.92, 0.95),
		"eye_color": Color(0.4, 0.8, 1.0),
		"radius": 22.0,
		"speed": 390.0,
		"accel": 3000.0,
		"air_accel": 2000.0,
		"jump_speed": 900.0,
		"dash_charges": 2,
		"dash_cooldown": 1.3,
		# Sniper: die Klassenwaffe (erste Waffe) schiesst nur im Stand.
		"stationary_fire": true,
		"weapons": ["sniper"],
		"damage_mult": 1.0,
	},
	"vending": {
		"name": "Automat",
		"color": Color(0.35, 0.75, 0.4),
		"eye_color": Color(1.0, 0.9, 0.4),
		"radius": 26.0,
		"speed": 220.0,
		"accel": 1400.0,
		"air_accel": 1000.0,
		"jump_speed": 800.0,
		"dash_charges": 2,
		"dash_cooldown": 1.3,
		"stationary_fire": false,
		"weapons": ["rocket"],
		"damage_mult": 1.2,
	},
	"printer": {
		"name": "Drucker",
		"color": Color(0.2, 0.2, 0.25),
		"eye_color": Color(1.0, 0.55, 0.2),
		"radius": 22.0,
		"speed": 300.0,
		"accel": 2400.0,
		"air_accel": 1700.0,
		"jump_speed": 900.0,
		"dash_charges": 2,
		"dash_cooldown": 1.3,
		"stationary_fire": false,
		"weapons": ["rapid"],
		"damage_mult": 1.0,
	},
}

const PLAYER_COLORS := [Color(0.3, 0.7, 1.0), Color(1.0, 0.6, 0.2)]


static func get_stats(class_id: String) -> Dictionary:
	return DATA[class_id]
