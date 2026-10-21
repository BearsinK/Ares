extends Node
## Test der Verhaltens-Perks (Items): Frenzy, Arc Coil, Dash Blast, Thorns, Last Stand, Shield Cell,
## Recycler, Executioner, Close Quarters, Long Shot und der persoenlichen Item-Liste.
## Ausfuehren: godot --headless --path . res://tests/items_test.tscn

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


func _fresh_enemy(at: Vector2, kind := "brute") -> Enemy:
	var enemy: Enemy = main.director.spawn(kind, at)
	enemy._cooldown = 99.0
	enemy.hp = enemy.max_hp
	return enemy


func _loss(enemy: Enemy, source: Player) -> float:
	var before := enemy.hp
	enemy.take_damage(10.0, source, Vector2.ZERO)
	return before - enemy.hp


func _run() -> void:
	# Datenpruefung: jeder Perk hat Symbol, Text und nur bekannte Wirkwerte.
	var probe := Player.new()
	for id in Perks.DATA:
		_check(PerkArt.COLORS.has(id), "Perk %s hat ein Symbol" % id)
		for class_id in ["roomba", "hexapod", "vending", "printer"]:
			var mods := Perks.mods_for(id, class_id)
			_check(Perks.describe(id, class_id) != "", "Perk %s hat einen Text (%s)" % [id, class_id])
			for key in mods:
				_check(probe.mods.has(key), "Wirkwert %s von %s existiert im Spieler" % [key, id])
	probe.free()

	Engine.set_meta("classes", ["roomba", "hexapod"])
	main = load("res://scenes/main.tscn").instantiate()
	main.director_enabled = false
	main.intro_enabled = false
	main.stage_id = "classic"
	add_child(main)
	await _frames(20)
	p1 = main.players[0]
	p2 = main.players[1]
	p1.global_position = Vector2(1200.0, 1210.0)
	p2.global_position = Vector2(300.0, 1210.0)
	p1.iframes = 0.0

	# Persoenliche Items: Shop-Kauf landet in der Liste und wirkt.
	ShopItems.apply(p1, {"type": "perk", "id": "frenzy"})
	ShopItems.apply(p1, {"type": "perk", "id": "frenzy"})
	_check(int(p1.items.get("frenzy", 0)) == 2 and is_equal_approx(float(p1.mods.frenzy), 0.10), "Items zaehlen Stapel (%s)" % str(p1.items))
	_check(p2.items.is_empty(), "Der Partner bekommt das persoenliche Item nicht")

	# Frenzy: jeder Kill gibt Feuerrate, die nach Ablauf wieder verfaellt.
	var base_rate := p1.fire_rate_mult()
	for i in 3:
		p1.register_kill()
	_check(p1.frenzy_stacks == 3 and is_equal_approx(p1.fire_rate_mult(), base_rate + 0.10 * 3.0), "Frenzy: 3 Kills = +30%% Feuerrate (%.2f)" % p1.fire_rate_mult())
	for i in 10:
		p1.register_kill()
	_check(p1.frenzy_stacks == Perks.FRENZY_STACKS, "Frenzy stapelt bis %d" % Perks.FRENZY_STACKS)
	await _frames(int((Perks.FRENZY_TIME + 0.5) * 60.0))
	_check(p1.frenzy_stacks == 0 and is_equal_approx(p1.fire_rate_mult(), base_rate), "Frenzy verfaellt ohne Kills")
	p1.mods.frenzy = 0.0

	# Executioner / Close Quarters / Long Shot: Schadensfaktoren.
	var target := _fresh_enemy(Vector2(1300.0, 1225.0))
	var plain := _loss(target, p1)
	target.hp = target.max_hp
	p1.add_item("executioner")
	target.hp = target.max_hp * 0.2
	var finish := _loss(target, p1)
	_check(finish > plain * 1.4, "Executioner: mehr Schaden auf schwache Gegner (%.1f statt %.1f)" % [finish, plain])
	target.hp = target.max_hp
	var healthy := _loss(target, p1)
	_check(is_equal_approx(healthy, plain), "Executioner wirkt nicht auf gesunde Gegner")
	p1.mods.execute = 0.0

	target.global_position = p1.global_position + Vector2(100.0, 0.0)
	target.hp = target.max_hp
	p1.add_item("closequarters")
	var near := _loss(target, p1)
	_check(near > plain * 1.2, "Close Quarters: mehr Schaden aus der Naehe (%.1f)" % near)
	target.global_position = p1.global_position + Vector2(500.0, 0.0)
	target.hp = target.max_hp
	_check(is_equal_approx(_loss(target, p1), plain), "Close Quarters wirkt nicht auf Distanz")
	p1.mods.close = 0.0
	p1.add_item("longshot")
	target.global_position = p1.global_position + Vector2(800.0, 0.0)
	target.hp = target.max_hp
	_check(_loss(target, p1) > plain * 1.2, "Long Shot: mehr Schaden aus der Ferne")
	p1.mods.far = 0.0
	target.queue_free()
	await _frames(3)

	# Arc Coil: Treffer springt auf einen Nachbarn (mit hoher Chance erzwungen).
	var a := _fresh_enemy(Vector2(1500.0, 1225.0))
	var b := _fresh_enemy(Vector2(1620.0, 1225.0))
	p1.mods.arc = 100.0
	a.take_damage(20.0, p1, Vector2.ZERO)
	_check(b.hp < b.max_hp, "Arc Coil: Treffer springt auf den Nachbarn (%.1f / %.1f)" % [b.hp, b.max_hp])
	var far_enemy := _fresh_enemy(Vector2(2300.0, 1225.0))
	a.take_damage(1.0, p1, Vector2.ZERO)
	_check(is_equal_approx(far_enemy.hp, far_enemy.max_hp), "Arc Coil erreicht keine fernen Gegner")
	p1.mods.arc = 0.0
	for e in [a, b, far_enemy]:
		e.queue_free()
	await _frames(3)

	# Thorns: Wird der Spieler getroffen, bekommen Nahe Schaden.
	var close_enemy := _fresh_enemy(p1.global_position + Vector2(90.0, 0.0))
	p1.add_item("thorns")
	p1.iframes = 0.0
	var hp_before := close_enemy.hp
	p1.take_hit(5.0, p1.global_position + Vector2(40.0, 0.0))
	_check(close_enemy.hp < hp_before, "Thorns: Schockwelle trifft den Gegner (%.1f)" % (hp_before - close_enemy.hp))
	p1.mods.thorns = 0.0
	close_enemy.queue_free()
	await _frames(3)

	# Dash Blast: der Dash sprengt am Start.
	var dash_enemy := _fresh_enemy(p1.global_position + Vector2(80.0, -10.0))
	p1.add_item("dashblast")
	p1.iframes = 0.0
	p1.dash_charges = 2
	hp_before = dash_enemy.hp
	p1._try_dash()
	_check(dash_enemy.hp < hp_before, "Dash Blast: Explosion beim Dash (%.1f)" % (hp_before - dash_enemy.hp))
	p1.mods.dash_blast = 0.0
	dash_enemy.queue_free()
	await _frames(40)

	# Last Stand: unter der Schwelle mehr Schaden und Tempo.
	p1.hp = p1.max_health()
	var normal_damage := p1.damage_mult()
	var normal_speed := p1.base_speed()
	p1.add_item("laststand")
	_check(is_equal_approx(p1.damage_mult(), normal_damage), "Last Stand: bei vollem Leben kein Bonus")
	p1.hp = p1.max_health() * 0.2
	_check(p1.damage_mult() > normal_damage * 1.3 and p1.base_speed() > normal_speed * 1.1, "Last Stand: unter %d%% Leben mehr Schaden und Tempo" % int(Perks.RAGE_THRESHOLD * 100.0))
	p1.mods.rage = 0.0
	p1.hp = p1.max_health()

	# Shield Cell: Schild schluckt Schaden und laedt wieder auf.
	p1.add_item("shieldcell")
	_check(p1.shield > 0.0 and is_equal_approx(p1.shield, p1.max_shield()), "Shield Cell: Schild ist voll (%.0f)" % p1.shield)
	p1.iframes = 0.0
	hp_before = p1.hp
	p1.take_hit(10.0, p1.global_position + Vector2(40.0, 0.0))
	_check(is_equal_approx(p1.hp, hp_before) and p1.shield < p1.max_shield(), "Schild schluckt kleinen Schaden (HP %.0f, Schild %.0f)" % [p1.hp, p1.shield])
	p1.iframes = 0.0
	p1.take_hit(50.0, p1.global_position + Vector2(40.0, 0.0))
	_check(p1.hp < hp_before and is_equal_approx(p1.shield, 0.0), "Grosser Treffer bricht den Schild, der Rest geht durch (HP %.0f)" % p1.hp)
	await _frames(int((Perks.SHIELD_DELAY + 1.5) * 60.0))
	_check(p1.shield > 0.0, "Schild laedt nach einer Weile ohne Treffer wieder auf (%.0f)" % p1.shield)
	p1.mods.shield = 0.0
	p1.shield = 0.0

	# Recycler: Kills verkuerzen die Faehigkeits-Ladezeit.
	p1.add_item("recycler")
	p1.ability.cooldown = 10.0
	var victim := _fresh_enemy(Vector2(1700.0, 1225.0), "walker")
	victim.take_damage(9999.0, p1, Vector2.ZERO)
	_check(p1.ability.cooldown < 10.0 - 0.5, "Recycler: Kill verkuerzt die Ladezeit (%.1f)" % p1.ability.cooldown)

	# Seltenheit: Seltene Items fallen seltener (Gewicht 0,4), am Altar jedes dritte (Gewicht 1).
	var all_ids: Array = Perks.DATA.keys()
	var rare_draws := 0
	var luck_draws := 0
	for i in 6000:
		if Perks.RARE_IDS.has(Perks.weighted_pick(all_ids)):
			rare_draws += 1
		if Perks.RARE_IDS.has(Perks.weighted_pick(all_ids, 1.0)):
			luck_draws += 1
	var chest_share := float(rare_draws) / 6000.0
	var luck_share := float(luck_draws) / 6000.0
	_check(chest_share > 0.13 and chest_share < 0.21, "Kisten: etwa jedes sechste Item ist selten (%.0f %%)" % (chest_share * 100.0))
	_check(luck_share > 0.29 and luck_share < 0.38, "Gluecksaltar: etwa jedes dritte Item ist selten (%.0f %%)" % (luck_share * 100.0))
	_check(Perks.weighted_pick(["frenzy"]) == "frenzy" and Perks.weighted_pick(Perks.RARE_IDS) != "", "Auch Listen nur aus Seltenem liefern etwas")

	# Herzschlag: nur bei einem lebenden Spieler unter 30 Prozent.
	var beats_before: int = Sfx._next
	p1.hp = p1.max_health()
	p2.hp = p2.max_health()
	main._heartbeat = 0.0
	main._update_heartbeat(0.016)
	_check(Sfx._next == beats_before, "Bei vollem Leben kein Herzschlag")
	p1.hp = p1.max_health() * 0.2
	Sfx._last_played.clear()
	main._heartbeat = 0.0
	main._update_heartbeat(0.016)
	_check(Sfx._next != beats_before and main._heartbeat > 0.5, "Unter 30 Prozent Leben schlaegt das Herz")
	p1.hp = p1.max_health()

	print("Fertig, Fehler: ", failures)
	main.queue_free()
	get_tree().quit(1 if failures > 0 else 0)
