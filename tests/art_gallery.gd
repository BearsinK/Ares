extends Node2D
## Entwickler-Werkzeug: zeichnet alle Roboter und Gegner nebeneinander in
## verschiedenen Zustaenden zur optischen Pruefung. Ausfuehren als Szene.

var t := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.16, 0.18, 0.24))


func _draw() -> void:
	var scale_factor := 2.0
	var classes := ["roomba", "hexapod", "vending", "printer"]
	var moods := ["normal", "focus", "hurt", "happy"]
	for i in 4:
		var s := _state(moods[i])
		s["arm"] = 0.0 if i == 0 else (0.5 if i == 1 else 1.0)
		RobotArt.draw_player(self, classes[i], s, Vector2(160 + i * 300, 190), scale_factor)
	# Zustaende: gehend, aufgebaut/klettern, schuettelnd, feuernd, in der Luft
	var variants := [
		{"class": "roomba", "vx": 300.0, "firing": 1.0, "arm": 1.0, "aim": Vector2(0.8, -0.6)},
		{"class": "printer", "vx": 300.0, "aim": Vector2(1, -0.2)},
		{"class": "vending", "charge": 0.8, "aim": Vector2(0.7, -0.7)},
		{"class": "vending", "firing": 1.0, "aim": Vector2(1, 0.3)},
	]
	for i in 4:
		var s := _state("normal")
		for key in variants[i]:
			if key != "class":
				s[key] = variants[i][key]
		s["facing"] = 1.0
		RobotArt.draw_player(self, variants[i]["class"], s, Vector2(160 + i * 300, 470), scale_factor)
	var kinds := ["walker", "shooter", "flyer", "brute", "charger", "mortar"]
	for i in 6:
		var s := {"facing": 1.0, "aim": Vector2(1, 0), "t": t, "walk": t * 4.0, "flash": false, "windup": -1.0, "slam": false}
		if i == 0 or i == 3 or i == 4 or i == 5:
			s["windup"] = 0.8
		RobotArt.draw_enemy(self, kinds[i], s, Vector2(120 + i * 250, 700), scale_factor)
		var s2 := s.duplicate()
		s2["facing"] = -1.0
		s2["aim"] = Vector2(-1, 0)
		s2["windup"] = -1.0
		RobotArt.draw_enemy(self, kinds[i], s2, Vector2(120 + i * 250, 860), 1.0)


func _state(mood: String) -> Dictionary:
	return {
		"facing": 1.0, "aim": Vector2(1, 0), "t": t, "vx": 0.0, "walk": t * 3.0, "grounded": true,
		"clinging": false, "cling_dir": 0.0, "planted": false, "mood": mood, "firing": 0.0, "charge": 0.0, "arm": 1.0,
		"weapon_color": Color(0.8, 0.92, 1.0), "accent": Color(0.3, 0.7, 1.0), "eye_color": Color(0.4, 1.0, 0.5),
	}


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
