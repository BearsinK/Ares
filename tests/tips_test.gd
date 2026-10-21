extends Node
## Test der einmaligen Hinweise: Anforderung, Merken, Ausloeser im Spiel, Anzeige im HUD.
## Ausfuehren: godot --headless --path . res://tests/tips_test.tscn

var failures := 0
var main: Node
var p1: Player
var p2: Player


func _check(condition: bool, message: String) -> void:
	if condition:
		print("OK    ", message)
	else:
		print("FEHLER ", message)
		failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## Wartet auf Bildframes (das HUD arbeitet in _process), hoechstens timeout Sekunden Echtzeit.
func _until(condition: Callable, timeout := 3.0) -> void:
	var start := Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec() - start < int(timeout * 1000.0):
		await get_tree().process_frame


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_queue_rules()
	await _in_game()
	print("Fertig, Fehler: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


func _queue_rules() -> void:
	SaveData.reset()
	Tips.queue.clear()
	Tips.request("chest")
	Tips.request("chest")
	_check(Tips.queue == ["chest"], "Ein Hinweis steht nur einmal in der Warteschlange")
	Tips.request("gibtsnicht")
	_check(Tips.queue.size() == 1, "Unbekannte Hinweise werden ignoriert")
	SaveData.mark_tip("revive")
	Tips.request("revive")
	_check(Tips.queue.size() == 1 and SaveData.tip_seen("revive"), "Gesehene Hinweise kommen nicht wieder")
	SaveData.set_tips(false)
	Tips.request("dash")
	_check(Tips.queue.size() == 1, "Mit ausgeschalteten Hinweisen kommt nichts Neues")
	SaveData.reset()
	Tips.queue.clear()
	for id in Tips.DATA:
		var info: Dictionary = Tips.DATA[id]
		_check(String(info.title) != "" and String(info.text).length() > 20 and String(info.text).length() < 120, "Hinweis %s hat Titel und kurzen Text" % id)


func _in_game() -> void:
	SaveData.reset()
	Engine.set_meta("classes", ["roomba", "hexapod"])
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	main.stage_id = "classic"
	add_child(main)
	await _frames(5)
	p1 = main.players[0]
	p2 = main.players[1]
	var hud: Hud = main.hud
	hud._age = 30.0
	Tips.queue.clear()

	# Kiste in der Naehe loest den Hinweis aus und das HUD zeigt ihn.
	var chest := Chest.new()
	chest.players = main.players
	chest.position = p1.global_position + Vector2(200.0, 0.0)
	main.add_child(chest)
	await _until(func() -> bool: return hud._tip_id == "chest")
	_check(hud._tip_id == "chest" and hud._tip_time > 0.0, "Kiste in der Naehe zeigt den Kisten-Hinweis")
	_check(SaveData.tip_seen("chest"), "Angezeigter Hinweis gilt als gesehen")
	chest.queue_free()

	# Zweiter Hinweis wartet, bis der erste vorbei ist.
	var altar := Altar.new()
	altar.kind = "blood"
	altar.players = main.players
	altar.position = p1.global_position + Vector2(220.0, 0.0)
	main.add_child(altar)
	await _until(func() -> bool: return Tips.queue.has("altar_blood"))
	_check(Tips.queue.has("altar_blood") and hud._tip_id == "chest", "Der Altar-Hinweis wartet auf den Kisten-Hinweis")
	hud._tip_time = 0.01
	await _until(func() -> bool: return hud._tip_id == "altar_blood")
	_check(hud._tip_id == "altar_blood", "Danach erscheint der Altar-Hinweis")
	altar.queue_free()
	hud._tip_time = 0.0
	await _frames(2)

	# Erster Treffer ohne Dash.
	p1.iframes = 0.0
	p1.take_hit(5.0, p1.global_position + Vector2(30.0, 0.0))
	await _frames(3)
	_check(hud._tip_id == "dash" or Tips.queue.has("dash") or SaveData.tip_seen("dash"), "Erster Treffer ohne Dash meldet den Dash-Hinweis")
	hud._tip_time = 0.0
	await _frames(2)

	# Wer schon gedasht hat, braucht den Hinweis nicht.
	SaveData.reset()
	Tips.queue.clear()
	p2.dash_count = 1
	p2.iframes = 0.0
	p2.take_hit(5.0, p2.global_position + Vector2(30.0, 0.0))
	await _frames(3)
	_check(not Tips.queue.has("dash"), "Mit Dash-Erfahrung kein Dash-Hinweis")

	# Partner am Boden: Wiederbeleben-Hinweis.
	Tips.queue.clear()
	p1.iframes = 0.0
	p1.take_hit(9999.0, p1.global_position + Vector2(30.0, 0.0))
	await _frames(3)
	_check(p1.downed and (hud._tip_id == "revive" or Tips.queue.has("revive")), "Spieler am Boden meldet den Wiederbeleben-Hinweis")
	p1.revive()

	# Gegner: Medic, Sprengi, Elite.
	hud._tip_time = 0.0
	Tips.queue.clear()
	SaveData.reset()
	main.director.spawn("medic", p2.global_position + Vector2(500.0, 0.0))
	main.director.spawn("bomber", p2.global_position + Vector2(-500.0, 0.0))
	main.director.spawn("walker", p2.global_position + Vector2(700.0, 0.0), true)
	await _frames(3)
	var seen: Array[String] = []
	if hud._tip_id != "":
		seen.append(hud._tip_id)
	for id in Tips.queue:
		seen.append(id)
	_check(seen.has("medic") and seen.has("bomber") and seen.has("elite"), "Medic, Sprengi und Elite melden ihre Hinweise (%s)" % ", ".join(seen))

	# Auch im Bosskampf erscheinen Hinweise.
	hud._tip_time = 0.0
	hud._tip_id = ""
	Tips.queue.clear()
	SaveData.reset()
	main.phase = main.Phase.BOSS
	Tips.request("bomber")
	await _until(func() -> bool: return hud._tip_id == "bomber")
	_check(hud._tip_id == "bomber", "Im Bosskampf wird der Hinweis gezeigt")
	main.phase = main.Phase.WAVE

	# Waehrend der Pause laeuft die Anzeige nicht weiter.
	hud._tip_id = "medic"
	hud._tip_time = 5.0
	get_tree().paused = true
	await get_tree().create_timer(0.3, true, false, true).timeout
	_check(is_equal_approx(hud._tip_time, 5.0), "In der Pause bleibt der Hinweis stehen")
	get_tree().paused = false
	main.queue_free()
	await get_tree().process_frame
	SaveData.reset()
