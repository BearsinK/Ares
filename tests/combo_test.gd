extends Node
## Test der Element-Kombos (Ueberlast, Kurzschluss, Stromschlag, Einfrieren mit Zersplittern) und der Element-Effekte.
## Ausfuehren: godot --headless --path . res://tests/combo_test.tscn

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


func _ready() -> void:
	_run.call_deferred()


func _dummy(pos: Vector2, hp := 5000.0) -> Enemy:
	var e: Enemy = main.director.spawn("brute", pos)
	e.set_physics_process(false)
	e.hp = hp
	e.max_hp = hp
	e._cooldown = 99.0
	return e


func _clear() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy:
			enemy.free()
	for child in main.projectiles.get_children():
		child.free()


func _texts() -> Array:
	var result: Array = []
	for item in Fx.instance._items:
		if item.type == "number":
			result.append(String(item.text))
	return result


func _run() -> void:
	Engine.set_meta("classes", ["roomba", "hexapod"])
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	main.stage_id = "classic"
	add_child(main)
	await _frames(15)
	p1 = main.players[0]
	p2 = main.players[1]
	p1.invulnerable = true
	p2.invulnerable = true
	_data()
	await _overload()
	await _short_circuit()
	await _shock()
	await _freeze()
	await _spark()
	await _stun_limits()
	await _bosses()
	await _popups()
	await _particles()
	print("Fertig, Fehler: ", failures)
	main.queue_free()
	get_tree().quit(1 if failures > 0 else 0)


func _data() -> void:
	_check(Elements.COMBOS.size() == 6, "Sechs Kombos")
	var pairs := {}
	for id in Elements.COMBOS:
		var pair: Array = Elements.COMBOS[id].pair
		pairs["%s+%s" % [minf(Elements.IDS.find(pair[0]), Elements.IDS.find(pair[1])), maxf(Elements.IDS.find(pair[0]), Elements.IDS.find(pair[1]))]] = true
	_check(pairs.size() == 6, "Jedes Elementpaar hat genau eine Kombo")
	var infos := true
	for element in Elements.IDS:
		for other in Elements.IDS:
			if other != element:
				infos = infos and String(Elements.INFO[element]).contains(String(Elements.NAMES[other]))
	_check(infos, "Jede Modulbeschreibung nennt die Kombos mit allen anderen Elementen")


func _overload() -> void:
	_clear()
	var target := _dummy(Vector2(800.0, 1200.0))
	var near := _dummy(Vector2(870.0, 1200.0))
	var far := _dummy(Vector2(1300.0, 1200.0))
	await _frames(2)
	target.take_damage(5.0, p1, Vector2.ZERO, "fire")
	_check(target.statuses.has("burning"), "Feuer setzt in Brand")
	var near_before := near.hp
	var target_before := target.hp
	target.take_damage(10.0, p1, Vector2.ZERO, "lightning")
	_check(not target.statuses.has("burning"), "Ueberlast verbraucht den Brand")
	_check(near_before - near.hp >= StatusEffects.OVERLOAD_DAMAGE_SOLO * 0.9, "Der Nachbar bekommt die Explosion ab (%.0f)" % (near_before - near.hp))
	_check(far.hp == 5000.0, "Weit entfernte Gegner nicht")
	_check(target_before - target.hp >= 10.0 + StatusEffects.OVERLOAD_DAMAGE_SOLO * 0.9, "Das Ziel selbst nimmt Blitz und Explosion (%.0f)" % (target_before - target.hp))
	# Koop: anderer Spieler loest aus, staerker.
	near.hp = 5000.0
	target.hp = 5000.0
	target.take_damage(5.0, p1, Vector2.ZERO, "fire")
	target.take_damage(10.0, p2, Vector2.ZERO, "lightning")
	_check(5000.0 - near.hp >= StatusEffects.OVERLOAD_DAMAGE_COOP * 0.9, "Koop-Ueberlast ist staerker (%.0f)" % (5000.0 - near.hp))
	_check("ÜBERLAST" in _texts() and "KOOP" in _texts(), "Die Kombo meldet sich mit Namen und Koop-Zeile")
	_clear()


func _short_circuit() -> void:
	_clear()
	var target := _dummy(Vector2(800.0, 1200.0))
	await _frames(2)
	target.take_damage(5.0, p1, Vector2.ZERO, "ice")
	_check(target.statuses.has("chilled"), "Eis kuehlt")
	var before := target.hp
	target.take_damage(10.0, p1, Vector2.ZERO, "lightning")
	_check(target.stunned_time >= StatusEffects.SHORT_STUN_SOLO - 0.01, "Kurzschluss laehmt (%.1f s)" % target.stunned_time)
	_check(not target.statuses.has("chilled"), "und verbraucht die Kaelte")
	_check(before - target.hp >= 10.0 + StatusEffects.SHORT_DAMAGE_SOLO - 0.5, "mit Zusatzschaden (%.0f)" % (before - target.hp))
	_check("KURZSCHLUSS" in _texts(), "Die Kombo wird gemeldet")
	_clear()


func _shock() -> void:
	_clear()
	var target := _dummy(Vector2(800.0, 1200.0))
	await _frames(2)
	target.take_damage(1.0, p1, Vector2.ZERO, "water")
	var before := target.hp
	target.take_damage(20.0, p1, Vector2.ZERO, "lightning")
	_check(is_equal_approx(before - target.hp, 30.0), "Stromschlag: Blitz auf Nass macht weiter x1,5 (%.1f)" % (before - target.hp))
	_check(target.stunned_time > 0.3, "und laehmt kurz (%.1f s)" % target.stunned_time)
	_check(target.statuses.has("shocked"), "Funken zucken ueber dem Ziel")
	_clear()


func _freeze() -> void:
	_clear()
	var target := _dummy(Vector2(800.0, 1200.0), 200.0)
	var neighbor := _dummy(Vector2(880.0, 1200.0))
	var far := _dummy(Vector2(1400.0, 1200.0))
	await _frames(2)
	target.take_damage(1.0, p1, Vector2.ZERO, "water")
	target.take_damage(1.0, p1, Vector2.ZERO, "ice")
	_check(target.statuses.is_frozen(), "Wasser und Eis frieren ein")
	var before := target.hp
	target.take_damage(10.0, p1, Vector2.ZERO, "")
	_check(is_equal_approx(before - target.hp, 10.0 * StatusEffects.BRITTLE_MULT), "Gefrorene Ziele sind sproede (%.1f statt 10)" % (before - target.hp))
	var neighbor_before := neighbor.hp
	target.take_damage(9999.0, p1, Vector2.ZERO, "")
	await _frames(2)
	_check(neighbor_before - neighbor.hp >= StatusEffects.SHATTER_DAMAGE * 0.9, "Stirbt ein gefrorenes Ziel, zersplittert es und trifft Nachbarn (%.0f)" % (neighbor_before - neighbor.hp))
	_check(far.hp == 5000.0, "Weit entfernte nicht")
	_clear()


func _spark() -> void:
	_clear()
	var target := _dummy(Vector2(800.0, 1200.0))
	var neighbor := _dummy(Vector2(950.0, 1200.0))
	await _frames(2)
	var exact := true
	for i in 120:
		var before := target.hp
		target.take_damage(10.0, p1, Vector2.ZERO, "lightning")
		exact = exact and is_equal_approx(before - target.hp, 10.0)
		target.statuses.update(1.0)
	_check(exact, "Ein trockener Blitz macht dem Ziel immer genau den normalen Schaden")
	_check(neighbor.hp < 5000.0, "Manche Blitze springen auf den Nachbarn ueber (%.0f Schaden)" % (5000.0 - neighbor.hp))
	_clear()


func _popups() -> void:
	_clear()
	Fx.instance._items.clear()
	var target := _dummy(Vector2(800.0, 1200.0))
	await _frames(2)
	target.take_damage(1.0, p1, Vector2.ZERO, "water")
	_check("Nass" in _texts(), "Neuer Zustand: Meldung Nass")
	target.take_damage(1.0, p1, Vector2.ZERO, "water")
	var count := 0
	for text in _texts():
		if text == "Nass":
			count += 1
	_check(count == 1, "Die Meldung kommt nur beim ersten Mal (%d)" % count)
	target.statuses.update(10.0)
	target.take_damage(1.0, p1, Vector2.ZERO, "fire")
	_check("Brennt" in _texts(), "Meldung Brennt")
	_clear()


func _particles() -> void:
	var fx: Fx = Fx.instance
	fx._items.clear()
	var all_ok := true
	for element in Elements.IDS:
		var before := fx._items.size()
		fx.element_hit(Vector2(900.0, 1000.0), element)
		fx.element_trail(Vector2(900.0, 1000.0), element)
		fx.element_muzzle(Vector2(900.0, 1000.0), Vector2.RIGHT, element)
		fx.element_beam(Vector2(600.0, 1000.0), Vector2(1100.0, 1000.0), element)
		all_ok = all_ok and fx._items.size() > before
	_check(all_ok, "Jedes Element erzeugt Treffer-, Spur-, Muendungs- und Strahlteilchen")
	fx._items.clear()
	var before_calm := fx._items.size()
	fx.element_hit(Vector2(900.0, 1000.0), "ice", 2.0)
	var normal := fx._items.size() - before_calm
	SaveData.set_calm_effects(true)
	fx._items.clear()
	before_calm = fx._items.size()
	fx.element_hit(Vector2(900.0, 1000.0), "ice", 2.0)
	var calm := fx._items.size() - before_calm
	SaveData.set_calm_effects(false)
	_check(calm < normal, "Ruhige Effekte zeigen weniger Teilchen (%d gegen %d)" % [calm, normal])
	for i in 600:
		fx.element_hit(Vector2(900.0, 1000.0), "fire", 3.0)
	_check(fx._items.size() <= Fx.MAX_ITEMS, "Die Teilchenzahl bleibt begrenzt (%d)" % fx._items.size())


func _stun_limits() -> void:
	_clear()
	var target := _dummy(Vector2(800.0, 1200.0))
	await _frames(2)
	target.take_damage(1.0, p1, Vector2.ZERO, "water")
	var stunned_frames := 0
	for i in 150:
		target.take_damage(1.0, p1, Vector2.ZERO, "water")
		target.take_damage(2.0, p1, Vector2.ZERO, "lightning")
		target.statuses.update(1.0 / 60.0)
		target.stunned_time = maxf(0.0, target.stunned_time - 1.0 / 60.0)
		target._stun_immunity = maxf(0.0, target._stun_immunity - 1.0 / 60.0)
		if target.stunned_time > 0.0:
			stunned_frames += 1
	_check(stunned_frames < 150 * 0.5, "Stromschlag haelt einen Gegner nicht dauerhaft fest (%d von 150 Frames)" % stunned_frames)
	_clear()
	# Tote Gegner sind kein Sprungziel mehr.
	target = _dummy(Vector2(800.0, 1200.0))
	var corpse := _dummy(Vector2(900.0, 1200.0), 1.0)
	var alive := _dummy(Vector2(1000.0, 1200.0))
	await _frames(2)
	corpse.take_damage(99999.0, p1, Vector2.ZERO, "")
	var arc_before := alive.hp
	for i in 200:
		target.take_damage(2.0, p1, Vector2.ZERO, "lightning")
		target.statuses.update(1.0)
	_check(alive.hp < arc_before, "Der Funkenschlag springt auf Lebende, nicht auf die Leiche (%.0f)" % (arc_before - alive.hp))
	_clear()


func _bosses() -> void:
	_clear()
	Fx.instance._items.clear()
	main._start_boss()
	await _frames(20)
	var boss: Boss = main.boss
	boss.hp = 99999.0
	boss.max_hp = 99999.0
	boss._delay = 0.0
	_check(boss.has_method("radius") and boss.radius() > 100.0, "Der Boss hat eine Koerpergroesse fuer Minen und Wolken")
	boss.take_damage(1.0, p1, Vector2.ZERO, "water")
	boss.take_damage(1.0, p2, Vector2.ZERO, "ice")
	_check(not boss.statuses.is_frozen() and boss.statuses.has("chilled"), "Wasser und Eis frieren den Boss nicht ein, kuehlen ihn nur")
	_check(not ("EINGEFROREN" in _texts()), "und melden deshalb keine Einfrier-Kombo")
	boss.apply_status("tagged", 3.0, p1)
	_check(is_equal_approx(boss.statuses.damage_factor(), StatusEffects.TAG_MULT), "Die Markierung wirkt auch am Boss")
	main.boss.queue_free()
