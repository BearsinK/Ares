class_name UiKit
extends RefCounted
## Gemeinsame Hilfen fuer Menues: Eingabe (beide Spieler), Buttons, Klasseninfos.

const CLASS_ORDER: Array[String] = ["roomba", "hexapod", "vending", "printer"]

const CLASS_INFO := {
	"roomba": {
		"tags": ["Vacuum", "Support", "Agile"],
		"blurb": "Flache Scheibe mit Roboterarm. Schwacher Dauerbeschuss, großer Sammelradius, saugt Beute und Gegner heran.",
		"ability": "Vortex: zieht Gegner und Beute heran",
		"damage": 3, "difficulty": 2,
	},
	"hexapod": {
		"tags": ["Sniper", "Climber", "Turret"],
		"blurb": "Klettert Wände und Decken wie eine Spinne und schießt schnell, aber nur im Stand. Aufgestellt steckt er 20 % weniger ein. Positionierung ist alles.",
		"ability": "Overwatch: kurz doppelte Feuerrate ohne Aufbauzeit",
		"damage": 4, "difficulty": 4,
	},
	"vending": {
		"tags": ["Tank", "AoE", "Heavy"],
		"blurb": "Groß und robust. Wirft geschüttelte Dosen, die beim Aufprall explodieren.",
		"ability": "Steamroller: rollt durch Gegner, macht Schaden und nimmt weniger",
		"damage": 4, "difficulty": 2,
	},
	"printer": {
		"tags": ["Swarm", "Utility", "Flex"],
		"blurb": "Läuft auf gedruckten Beinen, druckt Drohnen als zusätzliche Waffen.",
		"ability": "Drone Drop: zwei explosive Drohnen jagen Gegner",
		"damage": 2, "difficulty": 3,
	},
}

const CONTROLS_LINES: Array[String] = [
	"Linker Stick / WASD / Pfeile: Bewegen und Klettern",
	"Rechter Stick / Maus: Zielen",
	"L1 / Leertaste / Pfeil hoch: Sprung (nach unten + Sprung: durch Plattform fallen)",
	"R1 / Shift / Schrägstrich: Dash mit Unverwundbarkeit",
	"R2 / Linke Maustaste, F / Punkt: Schießen",
	"L2 / E / Komma: Klassenfähigkeit",
	"Dreieck / Q / M: Waffe wechseln",
	"Quadrat / R / N: Greifhaken (Firmware)",
	"Kreis / G / L: Partner wiederbeleben (halten), im Menü zurück",
	"Kreuz / Enter: Bestätigen im Menü",
	"Options / Escape: Pause",
]


static func pressed(suffix: String) -> bool:
	return Input.is_action_just_pressed("p1_" + suffix) or Input.is_action_just_pressed("p2_" + suffix)


static func confirm() -> bool:
	return pressed("confirm")


static func back() -> bool:
	return pressed("interact") or Input.is_action_just_pressed("pause")


static func button(c: CanvasItem, rect: Rect2, text: String, selected: bool, accent := Color(0.4, 0.75, 1.0), size := 24) -> void:
	var fill := Color(0.2, 0.24, 0.36) if selected else Color(0.1, 0.12, 0.19)
	Art.panel(c, rect, fill, 14.0, accent if selected else Color(1, 1, 1, 0.2))
	if selected:
		Art.glow(c, rect.position + Vector2(18, rect.size.y * 0.5), 14.0, accent)
	var font := ThemeDB.fallback_font
	c.draw_string(font, rect.position + Vector2(0, rect.size.y * 0.5 + size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, Color.WHITE if selected else Color(0.75, 0.78, 0.88))


## wrap: bei gesetzter Breite mehrzeilig umbrechen statt abschneiden.
static func text(c: CanvasItem, pos: Vector2, string: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, wrap := false) -> void:
	var font := ThemeDB.fallback_font
	if wrap and width > 0.0:
		c.draw_multiline_string(font, pos + Vector2(2, 2), string, align, width, size, -1, Color(0, 0, 0, 0.6))
		c.draw_multiline_string(font, pos, string, align, width, size, -1, color)
		return
	c.draw_string(font, pos + Vector2(2, 2), string, align, width, size, Color(0, 0, 0, 0.6))
	c.draw_string(font, pos, string, align, width, size, color)


static func stat_bar(c: CanvasItem, pos: Vector2, width: float, label: String, fraction: float, color: Color) -> void:
	text(c, pos, label, 16, Color(0.8, 0.82, 0.92))
	var bar := Rect2(pos + Vector2(110, -13), Vector2(width - 110.0, 14))
	Art.rrect(c, bar, Color(0.06, 0.07, 0.12), 6.0)
	Art.rrect_grad(c, Rect2(bar.position, Vector2(maxf(bar.size.x * clampf(fraction, 0.0, 1.0), 8.0), bar.size.y)), color.lightened(0.2), color.darkened(0.2), 6.0)
	Art.rrect_line(c, bar, Color(1, 1, 1, 0.25), 6.0, 1.5)


static func controls_panel(c: CanvasItem, view: Vector2) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.72))
	var panel := Rect2(Vector2(view.x * 0.5 - 520, 130), Vector2(1040, 600))
	Art.panel(c, panel, Color(0.1, 0.12, 0.19), 18.0, Color(1, 1, 1, 0.3))
	text(c, Vector2(0, 190), "STEUERUNG", 44, Color(1.0, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	for i in CONTROLS_LINES.size():
		text(c, Vector2(panel.position.x + 40, 260 + i * 38), CONTROLS_LINES[i], 20, Color(0.88, 0.9, 0.98))
	text(c, Vector2(0, panel.end.y - 24), "Zurück: Kreis oder Escape", 18, Color(0.7, 0.72, 0.85), HORIZONTAL_ALIGNMENT_CENTER, view.x)


## Ruhezustand fuer die Darstellung von Robotern in Menues.
static func idle_state(accent: Color, class_id: String, t: float) -> Dictionary:
	var eye: Color = RobotClasses.get_stats(class_id).eye_color
	return {
		"facing": 1.0, "aim": Vector2(1, -0.1), "t": t, "vx": 0.0, "walk": t * 1.2, "grounded": true,
		"clinging": false, "cling_dir": 0.0, "planted": false, "mood": "normal", "firing": 0.0, "charge": 0.0, "arm": 0.0,
		"weapon_color": Color(0.8, 0.92, 1.0), "accent": accent, "eye_color": eye,
	}
