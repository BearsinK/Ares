class_name ContractMenu
extends LevelUpMenu
## Vertragswahl vor jeder Welle: ein sicherer Standard und zwei Vertraege mit Risiko und Gold-Praemie.
## Gleiche Bedienung wie das Level-Up (beide waehlen dieselbe Karte, bei Streit entscheidet der Zufall).


func open_contracts(new_players: Array[Player], ids: Array[String], wave_number: int) -> void:
	players = new_players
	_solo = players.size() < 2
	perk_ids = ids
	_cursor = [0, 0]
	_locked = [-1, -1]
	_age = 0.0
	_split_time = 0.0
	_roulette = false
	_title = "NÄCHSTER AUFTRAG  Welle %d" % wave_number
	_hint = "Sicher oder riskant? Links/Rechts: wählen, Kreuz: bestätigen, Kreis: zurück" if _solo else "Sicher oder riskant? Beide wählen denselben Vertrag. Links/Rechts: wählen, Kreuz: bestätigen, Kreis: zurück"
	is_open = true
	visible = true
	get_tree().paused = true
	Sfx.play("telegraph")


func _card_color(id: String) -> Color:
	return WaveModifiers.DATA[id].color


func _draw_card_content(rect: Rect2, id: String) -> void:
	var info: Dictionary = WaveModifiers.DATA[id]
	var color: Color = info.color
	ContractArt.draw(_canvas, id, rect.position + Vector2(CARD_SIZE.x * 0.5, 84.0), 88.0)
	var title := "STANDARD" if id == "normal" else String(info.name)
	UiKit.text(_canvas, rect.position + Vector2(0, 176), title, 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, CARD_SIZE.x)
	_canvas.draw_line(rect.position + Vector2(30, 196), rect.position + Vector2(CARD_SIZE.x - 30, 196), Color(1, 1, 1, 0.15), 2.0)
	var text := "Keine Besonderheiten. Die sichere Wahl." if id == "normal" else String(info.text)
	UiKit.text(_canvas, rect.position + Vector2(24, 232), text, 19, Color(0.92, 0.93, 0.98), HORIZONTAL_ALIGNMENT_LEFT, CARD_SIZE.x - 48.0, true)
	# Praemie: je mehr Risiko, desto mehr Gold.
	var bonus := float(info.get("bonus", 0.0))
	var gold := float(info.get("gold", 1.0))
	var reward := "Keine Prämie"
	if id == "armor":
		reward = "Doppeltes Gold"
	elif bonus > 0.0:
		reward = "Prämie: +%d%% Gold" % int(round(bonus * 100.0))
	var plate := Rect2(rect.position + Vector2(24, CARD_SIZE.y - 70.0), Vector2(CARD_SIZE.x - 48.0, 44.0))
	Art.rrect(_canvas, plate, Color(0.04, 0.05, 0.09, 0.8), 10.0)
	Art.rrect_line(_canvas, plate, Color(color, 0.7 if (bonus > 0.0 or gold > 1.0) else 0.25), 10.0, 2.0)
	UiKit.text(_canvas, plate.position + Vector2(0, 29), reward, 22, Color(1.0, 0.85, 0.3) if (bonus > 0.0 or gold > 1.0) else Color(0.7, 0.74, 0.85), HORIZONTAL_ALIGNMENT_CENTER, plate.size.x)
