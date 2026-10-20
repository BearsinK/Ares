extends Node2D
## Entwickler-Werkzeug: zeigt eine Klasse (POSE_CLASS, Standard hexapod) in allen Zustaenden nebeneinander.

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.16, 0.18, 0.24))


func _base() -> Dictionary:
	return {
		"facing": 1.0, "aim": Vector2(1, -0.15), "t": 1.0, "vx": 0.0, "walk": 0.0, "grounded": true,
		"clinging": false, "cling_dir": 0.0, "planted": false, "mood": "normal", "firing": 0.0, "charge": 0.0, "arm": 0.0,
		"weapon_color": Color(0.8, 0.92, 1.0), "accent": Color(0.3, 0.7, 1.0), "eye_color": Color(0.4, 0.8, 1.0),
		"cling": 0.0, "rot": 0.0, "down": 0.0, "vy": 0.0, "deploy": 0.0, "recoil": 0.0, "heat": 0.0, "climb": 0.0, "hurt": 0.0, "downed": false, "overdrive": 0.0, "squash": Vector2.ONE,
	}


func _draw() -> void:
	var poses: Array = [
		["Idle", {}],
		["Lauf 1", {"vx": 300.0, "walk": 0.0}],
		["Lauf 2", {"vx": 300.0, "walk": 4.5}],
		["Lauf 3", {"vx": 300.0, "walk": 9.0}],
		["Aufgestellt", {"deploy": 1.0, "planted": true, "mood": "focus"}],
		["Schuss", {"deploy": 1.0, "planted": true, "mood": "focus", "firing": 1.0, "recoil": 1.0, "heat": 0.8}],
		["Overwatch", {"deploy": 1.0, "planted": true, "mood": "focus", "overdrive": 1.0, "heat": 1.0}],
		["Sprung", {"grounded": false, "squash": Vector2(0.92, 1.1), "vx": 200.0}],
		["Landung", {"squash": Vector2(1.18, 0.78)}],
		["Klettern 1", {"clinging": true, "cling_dir": 1.0, "climb": 0.0, "cling": 1.0, "rot": -PI / 2.0, "vy": -300.0, "grounded": false}],
		["Klettern 2", {"clinging": true, "cling_dir": 1.0, "climb": 2.0, "cling": 1.0, "rot": -PI / 2.0, "vy": -300.0, "grounded": false}],
		["Aufstehen", {"mood": "happy", "down": 0.5, "downed": false}],
		["Treffer", {"mood": "hurt", "hurt": 1.0}],
		["Am Boden", {"mood": "dead", "downed": true, "down": 1.0}],
	]
	var font := ThemeDB.fallback_font
	for i in poses.size():
		var s := _base()
		for key in poses[i][1]:
			s[key] = poses[i][1][key]
		var col := i % 5
		var row := i / 5
		var center := Vector2(160.0 + col * 310.0, 150.0 + row * 290.0)
		draw_line(center + Vector2(-120, 23 * 3.2), center + Vector2(120, 23 * 3.2), Color(1, 1, 1, 0.12))
		RobotArt.draw_player(self, OS.get_environment("POSE_CLASS") if OS.get_environment("POSE_CLASS") != "" else "hexapod", s, center, 3.2)
		draw_string(font, center + Vector2(-100, 100), poses[i][0], HORIZONTAL_ALIGNMENT_CENTER, 200.0, 20, Color.WHITE)
