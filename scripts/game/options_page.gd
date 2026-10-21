class_name OptionsPage
extends RefCounted
## Optionen-Seite fuer Titelbild und Pausemenue: Lautstaerke, Bildschirmwackeln, Schadenszahlen,
## Vibration und Vollbild. Alles wird sofort uebernommen und im Spielstand gemerkt.

const ROWS: Array[Dictionary] = [
	{"id": "master", "label": "Gesamtlautstärke", "kind": "volume"},
	{"id": "music", "label": "Musik", "kind": "volume"},
	{"id": "sfx", "label": "Effekte", "kind": "volume"},
	{"id": "shake", "label": "Bildschirmwackeln", "kind": "choice"},
	{"id": "numbers", "label": "Schadenszahlen", "kind": "toggle"},
	{"id": "rumble", "label": "Vibration", "kind": "toggle"},
	{"id": "tips", "label": "Hinweise", "kind": "toggle"},
	{"id": "fullscreen", "label": "Vollbild", "kind": "toggle"},
	{"id": "back", "label": "Zurück", "kind": "back"},
]
const SHAKE_NAMES: Array[String] = ["Aus", "Wenig", "Normal", "Stark"]

var cursor := 0

var _horizontal := HoldRepeat.new()
var _vertical := HoldRepeat.new()


## Eine Eingaberunde. Gibt true zurueck, wenn die Seite geschlossen werden soll.
func update(delta: float) -> bool:
	var step := _vertical.step(delta, "up", "down")
	if step != 0:
		cursor = (cursor + step + ROWS.size()) % ROWS.size()
		Sfx.play("switch")
	if UiKit.back():
		return true
	# Gehaltene Richtung wiederholt sich (Lautstaerke schnell verstellen).
	var direction := _horizontal.step(delta, "left", "right")
	var row := ROWS[cursor]
	if direction != 0 and row.kind != "back":
		change(String(row.id), direction)
	if UiKit.confirm():
		if row.kind == "back":
			return true
		if row.kind != "volume":
			change(String(row.id), 1)
	return false


## Stellt eine Zeile um eine Stufe weiter (Lautstaerke begrenzt, Auswahl und Schalter laufen im Kreis).
func change(id: String, direction: int) -> void:
	match id:
		"master", "music", "sfx":
			var before := SaveData.volume_step(id)
			var step := clampi(before + direction, 0, SaveData.VOLUME_STEPS)
			if step == before:
				return
			SaveData.set_volume_step(id, step)
			Music.apply_settings()
			# Beim Verstellen der Effekte und der Gesamtlautstaerke hoert man gleich die Probe.
			if id != "music":
				Sfx.play("pickup", 0.0)
		"shake":
			var count := SaveData.SHAKE_SCALES.size()
			SaveData.set_shake_level((SaveData.shake_level() + direction + count) % count)
			Sfx.play("switch")
		"numbers":
			SaveData.set_numbers(not SaveData.numbers_enabled())
			Sfx.play("switch")
		"rumble":
			SaveData.set_rumble(not SaveData.rumble_enabled())
			Sfx.play("switch")
			InputSetup.rumble(1, 0.4, 0.6, 0.25)
			InputSetup.rumble(2, 0.4, 0.6, 0.25)
		"tips":
			SaveData.set_tips(not SaveData.tips_enabled())
			Sfx.play("switch")
		"fullscreen":
			InputSetup.toggle_fullscreen()
			Sfx.play("switch")


func value_text(id: String) -> String:
	match id:
		"master", "music", "sfx":
			return "%d %%" % (SaveData.volume_step(id) * 10)
		"shake":
			return SHAKE_NAMES[SaveData.shake_level()]
		"numbers":
			return "An" if SaveData.numbers_enabled() else "Aus"
		"rumble":
			return "An" if SaveData.rumble_enabled() else "Aus"
		"tips":
			return "An" if SaveData.tips_enabled() else "Aus"
		"fullscreen":
			return "An" if InputSetup.is_fullscreen() else "Aus"
	return ""


func draw(c: CanvasItem, view: Vector2) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.78))
	var row_height := 62.0
	var panel := Rect2(Vector2(view.x * 0.5 - 400.0, 170.0), Vector2(800.0, ROWS.size() * row_height + 30.0))
	UiKit.text(c, Vector2(0, 130), "OPTIONEN", 52, Color(1.0, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	Art.panel(c, panel, Color(0.09, 0.11, 0.18), 18.0, Color(1, 1, 1, 0.28))
	for i in ROWS.size():
		var row := ROWS[i]
		var rect := Rect2(panel.position + Vector2(14.0, 14.0 + i * row_height), Vector2(panel.size.x - 28.0, row_height - 6.0))
		var selected := i == cursor
		if selected:
			Art.rrect(c, rect, Color(0.2, 0.25, 0.38), 12.0)
			Art.rrect_line(c, rect, Color(0.4, 0.75, 1.0), 12.0, 2.0)
		if row.kind == "back":
			UiKit.text(c, rect.position + Vector2(0, 36), String(row.label), 24, Color.WHITE if selected else Color(0.8, 0.83, 0.93), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
			continue
		UiKit.text(c, rect.position + Vector2(22, 36), String(row.label), 24, Color.WHITE if selected else Color(0.8, 0.83, 0.93))
		var right := rect.end.x - 22.0
		var value := value_text(String(row.id))
		if row.kind == "volume":
			var steps := SaveData.volume_step(String(row.id))
			for k in SaveData.VOLUME_STEPS:
				# Treppe: die Saeulen werden nach rechts hoeher, die Grundlinie liegt in der Zeilenmitte.
				var height := 10.0 + k * 2.2
				var cell := Rect2(Vector2(rect.end.x - 330.0 + k * 20.0, rect.position.y + rect.size.y * 0.5 + 14.0 - height), Vector2(14.0, height))
				c.draw_rect(cell, Color(0.5, 0.9, 1.0) if k < steps else Color(1, 1, 1, 0.14))
			UiKit.text(c, Vector2(rect.end.x - 120.0, rect.position.y + 36), value, 22, Color(1.0, 0.9, 0.5), HORIZONTAL_ALIGNMENT_RIGHT, 98.0)
		else:
			if selected:
				value = "<  %s  >" % value
			UiKit.text(c, Vector2(right - 260.0, rect.position.y + 36), value, 24, Color(1.0, 0.9, 0.5), HORIZONTAL_ALIGNMENT_RIGHT, 260.0)
	UiKit.text(c, Vector2(0, view.y - 40.0), "Hoch/Runter wählen, Links/Rechts ändern, Kreis zurück", 18, Color(0.65, 0.68, 0.8), HORIZONTAL_ALIGNMENT_CENTER, view.x)
