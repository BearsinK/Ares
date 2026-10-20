extends Node2D
## Entwickler-Werkzeug: zeigt eine Klasse (POSE_CLASS, Standard hexapod) in allen Zustaenden nebeneinander.

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.16, 0.18, 0.24))


func _base() -> Dictionary:
	return {
		"facing": 1.0, "aim": Vector2(1, -0.15), "t": 1.0, "vx": 0.0, "walk": 0.0, "grounded": true,
		"clinging": false, "cling_dir": 0.0, "planted": false, "mood": "normal", "firing": 0.0, "charge": 0.0, "arm": 0.0,
		"weapon_color": Color(0.8, 0.92, 1.0), "accent": Color(0.3, 0.7, 1.0), "eye_color": Color(0.4, 0.8, 1.0),
		"cling": 0.0, "ceiling": 0.0, "rot": 0.0, "down": 0.0, "coin": 0.0, "low": 0.0, "tilt": 0.0, "vy": 0.0, "deploy": 0.0, "recoil": 0.0, "heat": 0.0, "climb": 0.0, "hurt": 0.0, "downed": false, "overdrive": 0.0, "squash": Vector2.ONE,
	}


func _vending_poses() -> Array:
	return [
		["Idle", {}],
		["Fahren 1", {"vx": 220.0, "walk": 0.0}],
		["Fahren 2", {"vx": 220.0, "walk": 3.0}],
		["Schütteln", {"charge": 0.6, "mood": "focus"}],
		["Voll geschüttelt", {"charge": 1.0, "mood": "focus"}],
		["Wurf", {"firing": 1.0, "recoil": 1.0, "mood": "focus", "aim": Vector2(1, -0.4)}],
		["Walze", {"overdrive": 1.0, "vx": 370.0, "walk": 2.0, "mood": "angry", "tilt": 0.1}],
		["Sprung", {"grounded": false, "squash": Vector2(0.95, 1.06)}],
		["Landung", {"squash": Vector2(1.2, 0.78)}],
		["Treffer", {"mood": "hurt", "hurt": 1.0}],
		["Wenig Leben", {"low": 1.0}],
		["Münze", {"coin": 1.0, "mood": "happy"}],
		["Am Boden", {"mood": "dead", "downed": true, "down": 1.0}],
	]


func _printer_poses() -> Array:
	return [
		["Idle", {"print": 0.35}],
		["Druckt", {"print": 0.7}],
		["Fertig", {"print": 1.0}],
		["Lauf 1", {"vx": 300.0, "walk": 0.0, "print": 0.5}],
		["Lauf 2", {"vx": 300.0, "walk": 3.0, "print": 0.5}],
		["Schuss", {"firing": 1.0, "recoil": 1.0, "heat": 0.8, "print": 0.5, "mood": "focus", "aim": Vector2(1, -0.3)}],
		["Tür auf", {"launch": 0.3}],
		["Drohne startet", {"launch": 0.6}],
		["Sprung", {"grounded": false, "squash": Vector2(0.94, 1.08), "print": 0.5}],
		["Landung", {"squash": Vector2(1.18, 0.8), "print": 0.5}],
		["Treffer", {"mood": "hurt", "hurt": 1.0, "print": 0.5}],
		["Wenig Leben", {"low": 1.0, "print": 0.5}],
		["Am Boden", {"mood": "dead", "downed": true, "down": 1.0, "print": 0.5}],
	]


func _draw() -> void:
	var cls := OS.get_environment("POSE_CLASS") if OS.get_environment("POSE_CLASS") != "" else "hexapod"
	if cls == "enemies":
		_draw_enemy_sheet()
		return
	if cls == "down":
		_draw_down_sheet()
		return
	var poses: Array = _hexapod_poses()
	match cls:
		"printer":
			poses = _printer_poses()
		"vending":
			poses = _vending_poses()
		"roomba":
			poses = _roomba_poses()
	_draw_poses(cls, poses)


func _roomba_poses() -> Array:
	return [
		["Idle", {}],
		["Fahren 1", {"vx": 300.0, "walk": 0.0}],
		["Fahren 2", {"vx": 300.0, "walk": 3.0}],
		["Schuss", {"arm": 1.0, "firing": 1.0, "recoil": 1.0, "heat": 0.4, "mood": "focus", "aim": Vector2(1, -0.3)}],
		["Dauerfeuer", {"arm": 1.0, "firing": 0.5, "heat": 1.0, "mood": "angry", "aim": Vector2(1, 0.1)}],
		["Wirbel", {"overdrive": 1.0, "mood": "focus", "walk": 2.0}],
		["Sprung", {"grounded": false, "squash": Vector2(0.95, 1.06)}],
		["Landung", {"squash": Vector2(1.2, 0.78)}],
		["Treffer", {"mood": "hurt", "hurt": 1.0}],
		["Wenig Leben", {"low": 1.0}],
		["Münze", {"coin": 1.0, "mood": "happy"}],
		["Am Boden", {"mood": "dead", "downed": true, "down": 1.0}],
	]


func _hexapod_poses() -> Array:
	return [
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
		["Decke", {"ceiling": 1.0, "grounded": false, "aim": Vector2(0.4, 1.0)}],
		["Decke Lauf", {"ceiling": 1.0, "grounded": false, "vx": 200.0, "walk": 3.0, "aim": Vector2(0.4, 1.0)}],
		["Aufstehen", {"mood": "happy", "down": 0.5, "downed": false}],
		["Treffer", {"mood": "hurt", "hurt": 1.0}],
		["Am Boden", {"mood": "dead", "downed": true, "down": 1.0}],
	]


func _draw_poses(cls: String, poses: Array) -> void:
	var font := ThemeDB.fallback_font
	for i in poses.size():
		var s := _base()
		for key in poses[i][1]:
			s[key] = poses[i][1][key]
		var col := i % 5
		var row := i / 5
		var center := Vector2(160.0 + col * 310.0, 150.0 + row * 290.0)
		draw_line(center + Vector2(-120, 23 * 3.2 if cls == "hexapod" else 54 * 2.2), center + Vector2(120, 23 * 3.2 if cls == "hexapod" else 54 * 2.2), Color(1, 1, 1, 0.12))
		RobotArt.draw_player(self, cls, s, center, 3.2 if cls == "hexapod" else 2.4)
		draw_string(font, center + Vector2(-100, 100), poses[i][0], HORIZONTAL_ALIGNMENT_CENTER, 200.0, 20, Color.WHITE)


## Alle vier Klassen im Zustand "am Boden" (Uebergang und liegend).
func _draw_down_sheet() -> void:
	var font := ThemeDB.fallback_font
	var classes := ["roomba", "hexapod", "vending", "printer"]
	for row in 3:
		var amount: float = [0.0, 0.5, 1.0][row]
		for i in classes.size():
			var s := _base()
			s.merge({"mood": "dead", "downed": amount > 0.0, "down": amount}, true)
			var center := Vector2(200.0 + i * 360.0, 150.0 + row * 270.0)
			var zoom := 2.6 if classes[i] != "hexapod" else 3.0
			var stats: Dictionary = RobotClasses.get_stats(classes[i])
			var floor_y: float = center.y + stats.size.y * 0.5 * zoom
			draw_line(Vector2(center.x - 150.0, floor_y), Vector2(center.x + 150.0, floor_y), Color(1, 1, 1, 0.25))
			RobotArt.draw_player(self, classes[i], s, center, zoom)
			draw_string(font, Vector2(center.x - 100.0, floor_y + 24.0), "%s %.1f" % [classes[i], amount], HORIZONTAL_ALIGNMENT_CENTER, 200.0, 18, Color.WHITE)


## Alle Gegner in ihren Zustaenden: eine Zeile pro Typ.
func _draw_enemy_sheet() -> void:
	var font := ThemeDB.fallback_font
	var states := [
		["Idle", {}],
		["Lauf", {"vx": 150.0, "walk": 2.0}],
		["Vorwarnung", {"windup": 0.8}],
		["Angriff", {"slam": true}],
		["Schuss", {"fire": 1.0}],
		["Treffer", {"hurt": 1.0, "flash": true}],
		["Wenig Leben", {"hp_frac": 0.15}],
		["Landung", {"squash": Vector2(1.2, 0.76)}],
	]
	var kinds := ["walker", "shooter", "flyer", "charger", "mortar", "brute"]
	for row in kinds.size():
		var data: Dictionary = EnemyTypes.get_type(kinds[row])
		for col in states.size():
			var s := {"facing": 1.0, "aim": Vector2(1, -0.2), "t": 1.3, "walk": 0.0, "flash": false, "windup": -1.0, "slam": false,
				"vx": 0.0, "grounded": true, "hurt": 0.0, "fire": 0.0, "hp_frac": 1.0, "foot": float(data.radius), "squash": Vector2.ONE}
			for key in states[col][1]:
				s[key] = states[col][1][key]
			var center := Vector2(110.0 + col * 195.0, 85.0 + row * 145.0)
			RobotArt.draw_enemy(self, kinds[row], s, center, 2.0)
			if row == 0:
				draw_string(font, center + Vector2(-90, -60), states[col][0], HORIZONTAL_ALIGNMENT_CENTER, 180.0, 16, Color.WHITE)
