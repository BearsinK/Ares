extends Node
## Test von Magazin, Nachladen und den Waffen-Upgrades (Projektile, Tempo, Reichweite, Praezision, Explosion, Abpraller ...).
## Ausfuehren: godot --headless --path . res://tests/arsenal_test.tscn

var failures := 0
var main: Node
var p1: Player
var p2: Player
var shots := [0]


func _check(condition: bool, message: String) -> void:
	if condition:
		print("OK    ", message)
	else:
		print("FEHLER ", message)
		failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _until(test: Callable, max_frames := 600) -> bool:
	for i in max_frames:
		if test.call():
			return true
		await get_tree().physics_frame
	return test.call()


func _ready() -> void:
	_run.call_deferred()


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
	p1.global_position = Vector2(600.0, 1210.0)
	p2.global_position = Vector2(200.0, 1210.0)
	p1.invulnerable = true
	p2.invulnerable = true
	p1.fired.connect(func(_p: Player, _id: String, _o: Vector2, _d: Vector2, _c: float) -> void: shots[0] += 1)
	_data()
	await _magazine()
	await _upgrades()
	await _rays()
	_perks()
	print("Fertig, Fehler: ", failures)
	main.queue_free()
	get_tree().quit(1 if failures > 0 else 0)


func _clear_projectiles() -> void:
	for child in main.projectiles.get_children():
		child.free()


func _data() -> void:
	var ok := true
	for id in Weapons.ALL_IDS:
		var weapon := Weapons.get_weapon(id)
		ok = ok and int(weapon.get("mag", 0)) > 0 and float(weapon.get("reload", 0.0)) > 0.0
	_check(ok, "Jede Waffe hat Magazin und Nachladezeit")


func _magazine() -> void:
	p1.weapons = ["dust"]
	p1.modules = [""]
	p1.weapon_index = 0
	await _frames(2)
	_check(p1.ammo_of(0) == 36 and p1.ammo_max_of(0) == 36, "Startmagazin der Dustgun ist voll (36)")
	p1.ammo[0] = 3
	shots[0] = 0
	Input.action_press("p1_fire")
	await _frames(48)
	_check(shots[0] == 3, "Mit drei Schuss im Magazin fallen genau drei Schuesse (%d)" % shots[0])
	_check(p1.is_reloading() and p1.ammo_of(0) == 0, "Leeres Magazin laedt von selbst nach")
	await _frames(20)
	_check(shots[0] == 3, "Waehrend des Nachladens fallen keine Schuesse")
	Input.action_release("p1_fire")
	var done := await _until(func() -> bool: return not p1.is_reloading(), 300)
	_check(done and p1.ammo_of(0) == 36, "Nach dem Nachladen ist das Magazin wieder voll")
	shots[0] = 0
	Input.action_press("p1_fire")
	await _frames(20)
	Input.action_release("p1_fire")
	_check(shots[0] >= 1 and p1.ammo_of(0) == 36 - shots[0], "Schuesse verbrauchen je ein Magazin-Schuss (%d)" % p1.ammo_of(0))
	# Leerlauf: nach kurzer Pause laedt ein angebrochenes Magazin von selbst nach.
	_check(not p1.is_reloading(), "Direkt nach dem Schiessen wird noch nicht nachgeladen")
	var topped := await _until(func() -> bool: return p1.ammo_of(0) == 36, 300)
	_check(topped, "Angebrochenes Magazin fuellt sich nach einer Pause")

	# Von Hand nachladen: sofort, auch mit teilweise gefuelltem Magazin, und nur wenn es sich lohnt.
	p1.ammo[0] = 12
	p1._since_shot = 0.0
	p1.reload_now()
	_check(p1.is_reloading() and p1.ammo_of(0) == 12, "Nachladen von Hand startet sofort (ohne Pause)")
	var manual := await _until(func() -> bool: return not p1.is_reloading(), 300)
	_check(manual and p1.ammo_of(0) == 36, "und fuellt das Magazin")
	p1.reload_now()
	_check(not p1.is_reloading(), "Bei vollem Magazin passiert nichts")
	Input.action_press("p1_reload")
	await _frames(2)
	Input.action_release("p1_reload")
	_check(not p1.is_reloading(), "Die Taste tut bei vollem Magazin nichts")
	p1.ammo[0] = 5
	Input.action_press("p1_reload")
	await _frames(2)
	Input.action_release("p1_reload")
	_check(p1.is_reloading(), "Die Nachladetaste loest es aus (Kreuz, T, B)")
	await _until(func() -> bool: return not p1.is_reloading(), 300)

	# Upgrades: Magazin waechst mit dem Item und fuellt um den Zuwachs auf.
	p1.ammo[0] = 20
	p1.add_item("extmag")
	_check(p1.ammo_max_of(0) == 47, "Extended Mag: 36 wird 47 (%d)" % p1.ammo_max_of(0))
	_check(p1.ammo_of(0) == 31, "Das Magazin fuellt sich um den Zuwachs (%d)" % p1.ammo_of(0))
	var base_reload := Weapons.get_weapon("dust").reload as float
	var before := p1.reload_time_of("dust")
	p1.add_item("speedloader")
	_check(absf(before - base_reload) < 0.001 and p1.reload_time_of("dust") < base_reload * 0.8, "Speed Loader verkuerzt das Nachladen (%.2f s)" % p1.reload_time_of("dust"))
	# Kleine Magazine wachsen mindestens um 1.
	p1.weapons = ["rocket"]
	p1.modules = [""]
	await _frames(2)
	_check(p1.ammo_max_of(0) >= 5, "Auch ein 4er-Magazin waechst (%d)" % p1.ammo_max_of(0))
	# Waffe tauschen: neue Waffe startet voll.
	p1.add_weapon("shotgun")
	await _frames(2)
	_check(p1.ammo_of(p1.weapon_index) == p1.ammo_max_of(p1.weapon_index) and p1.ammo_max_of(p1.weapon_index) > 6, "Neue Waffe startet mit vollem Magazin")
	# Eco Chip: ein Teil der Schuesse kostet keine Munition (gedeckelt auf 75 Prozent).
	p1.weapons = ["dust"]
	p1.modules = [""]
	p1.weapon_index = 0
	p1.mods.mag = 20.0
	await _frames(2)
	p1.ammo[0] = 700
	p1.mods.ammo_save = 0.5
	for i in 200:
		p1._spend_ammo(0, Weapons.get_weapon("dust"))
	var spent := 700 - p1.ammo_of(0)
	_check(spent > 60 and spent < 140, "Eco Chip mit 50 Prozent spart etwa die Haelfte (%d von 200 verbraucht)" % spent)
	p1.ammo[0] = 700
	p1.mods.ammo_save = 5.0
	for i in 200:
		p1._spend_ammo(0, Weapons.get_weapon("dust"))
	spent = 700 - p1.ammo_of(0)
	_check(spent > 20, "Die Ersparnis ist gedeckelt (%d von 200 verbraucht)" % spent)
	p1.mods.ammo_save = 0.0
	p1.mods.mag = 0.0
	p1.mods.reload = 0.0
	p1.items.clear()


func _bullets() -> Array[Projectile]:
	var result: Array[Projectile] = []
	for child in main.projectiles.get_children():
		if child is Projectile:
			result.append(child)
	return result


func _fire(player: Player, weapon_id: String, direction := Vector2.RIGHT) -> void:
	main._on_player_fired(player, weapon_id, player.global_position + direction * 20.0, direction, 0.0)


func _upgrades() -> void:
	p1.mods.mag = 0.0
	p1.mods.reload = 0.0
	_clear_projectiles()
	_fire(p1, "dust")
	var plain := _bullets()
	_check(plain.size() == 1, "Ohne Upgrade: ein Projektil")
	var base_damage := plain[0].damage
	var base_speed := plain[0].speed
	var base_life := plain[0].lifetime
	_clear_projectiles()

	p1.mods.proj = 1.0
	_fire(p1, "dust")
	var two := _bullets()
	_check(two.size() == 2, "Split Barrel: +1 Projektil (%d)" % two.size())
	_check(absf(two[0].damage - base_damage * 0.8) < 0.01, "Jedes der zwei Projektile macht 80 Prozent Schaden (Gesamt 160)")
	_check(absf(two[0].direction.angle() - two[1].direction.angle()) > 0.05, "Die Projektile fliegen als Faecher")
	_clear_projectiles()
	p1.mods.proj = 0.0

	p1.mods.proj_speed = 0.25
	p1.mods.range = 0.5
	_fire(p1, "dust")
	var fast := _bullets()[0]
	_check(absf(fast.speed - base_speed * 1.25) < 0.5, "Velocity Coil: 25 Prozent schneller")
	_check(absf(fast.lifetime - base_life * 1.5) < 0.001, "Long Barrel: 50 Prozent laenger in der Luft")
	_clear_projectiles()
	p1.mods.proj_speed = 0.0
	p1.mods.range = 0.0

	p1.mods.accuracy = 0.5
	_check(absf(main._spread_scale(p1) - 0.5) < 0.001, "Stabilizer halbiert die Streuung")
	p1.mods.accuracy = 5.0
	_check(main._spread_scale(p1) >= Perks.ACCURACY_FLOOR, "Streuung faellt nie auf null")
	p1.mods.accuracy = 0.0

	p1.mods.knock = 1.0
	_fire(p1, "dust")
	_check(absf(_bullets()[0].knock - 2.0) < 0.001, "Heavy Slugs: doppelte Wucht")
	_clear_projectiles()
	p1.mods.knock = 0.0

	p1.mods.seek = 1.0
	_fire(p1, "dust")
	var seeker := _bullets()[0]
	_check(seeker.homing > 0.0 and seeker.style == "bullet", "Seeker Chip: Kugel lenkt, bleibt aber eine Kugel")
	_clear_projectiles()
	p1.mods.seek = 0.0

	_fire(p1, "rocket")
	var rocket := _bullets()[0]
	var rocket_radius := rocket.explosion_radius
	var rocket_blast := rocket.explosion_damage
	_check(rocket.style == "rocket", "Rakete bleibt eine Rakete")
	_clear_projectiles()
	p1.mods.blast = 0.4
	_fire(p1, "rocket")
	var big := _bullets()[0]
	_check(absf(big.explosion_radius - rocket_radius * 1.4) < 0.01, "Blast Core: 40 Prozent mehr Radius")
	_check(absf(big.explosion_damage - rocket_blast * 1.2) < 0.01, "und halb so viel mehr Schaden (%.1f)" % big.explosion_damage)
	_clear_projectiles()
	p1.mods.blast = 0.0

	# Abpraller: ein Geschoss, das auf die linke Wand zufliegt, kommt zurueck.
	var bullet := Projectile.new()
	bullet.position = Vector2(300.0, 1100.0)
	bullet.direction = Vector2.LEFT
	bullet.speed = 900.0
	bullet.lifetime = 3.0
	bullet.bounces = 1
	bullet.shooter = p1
	main.projectiles.add_child(bullet)
	var ref: WeakRef = weakref(bullet)
	var turned := await _until(func() -> bool:
		var live: Projectile = ref.get_ref()
		return live != null and live.direction.x > 0.0, 120)
	var after: Projectile = ref.get_ref()
	_check(turned and after != null and after.bounces == 0, "Ricochet: das Geschoss prallt an der Wand ab")
	var survives := await _until(func() -> bool: return ref.get_ref() == null, 240)
	_check(survives, "und verschwindet nach der zweiten Wand oder Flugzeit")
	_clear_projectiles()

	# Dose: Zusatzprojektile und Wurfweite.
	p1.mods.proj = 1.0
	main._on_player_fired(p1, "can", p1.global_position + Vector2(20, -10), Vector2.RIGHT, 0.5)
	var cans := _bullets()
	_check(cans.size() == 2 and cans[0].style == "can", "Split Barrel gilt auch fuer Dosen (%d)" % cans.size())
	_clear_projectiles()
	p1.mods.proj = 0.0


func _hurtbox_hp(enemy: Enemy) -> float:
	return enemy.hp


func _rays() -> void:
	# Strahl-Waffen: Geschuetz des Hexapods.
	p2.weapons = ["turret"]
	p2.modules = [""]
	p2.weapon_index = 0
	var a: Enemy = main.director.spawn("brute", Vector2(1100.0, 1100.0))
	a.set_physics_process(false)
	a.hp = 5000.0
	a.max_hp = 5000.0
	p2.global_position = Vector2(600.0, 1100.0)
	await _frames(2)
	var hp_before := a.hp
	_fire(p2, "turret", Vector2.RIGHT)
	_check(a.hp < hp_before, "Geschuetz trifft den Gegner geradeaus")
	hp_before = a.hp
	p2.mods.proj = 1.0
	_fire(p2, "turret", Vector2.RIGHT)
	_check(a.hp < hp_before, "Mit Split Barrel trifft mindestens ein Strahl")
	p2.mods.proj = 0.0

	# Zielhilfe: ein Gegner knapp neben dem Fadenkreuz wird erfasst.
	var origin := Vector2(600.0, 1100.0)
	var dir := Vector2.RIGHT.rotated(0.08)
	var assisted: Vector2 = main._assist_aim(origin, dir, 1.0)
	_check(absf(assisted.angle()) < 0.03, "Seeker Chip dreht den Strahl auf den Gegner (%.3f)" % assisted.angle())
	var far_off: Vector2 = main._assist_aim(origin, Vector2.RIGHT.rotated(0.6), 1.0)
	_check(absf(far_off.angle() - 0.6) < 0.001, "Weit daneben bleibt die Richtung")

	# Ricochet fuer Strahlen: nach links auf die Wand, der Strahl kommt zurueck und trifft den Gegner rechts.
	a.global_position = Vector2(760.0, 1100.0)
	await _frames(2)
	hp_before = a.hp
	p2.mods.bounce = 1.0
	_fire(p2, "turret", Vector2.LEFT)
	_check(a.hp < hp_before, "Ein Strahl prallt an der Wand ab und trifft dahinter (%.0f)" % (hp_before - a.hp))
	p2.mods.bounce = 0.0
	a.queue_free()


func _perks() -> void:
	var new_ids := ["extmag", "speedloader", "splitter", "velocoil", "longbarrel", "stabilizer", "blastcore", "killshot", "ecochip", "heavyslugs", "ricochet", "seeker"]
	var ok := true
	var described := true
	var colored := true
	for id in new_ids:
		ok = ok and Perks.DATA.has(id)
		for class_id in ["roomba", "hexapod", "vending", "printer"]:
			described = described and Perks.describe(id, class_id) != ""
		colored = colored and PerkArt.COLORS.has(id)
	_check(ok, "Alle zwoelf Waffen-Upgrades sind definiert")
	_check(described, "Jedes hat in jeder Klasse eine Beschreibung")
	_check(colored, "Jedes hat ein Symbol")
	var keys_ok := true
	for id in new_ids:
		for class_id in ["roomba", "hexapod", "vending", "printer"]:
			for key in Perks.mods_for(id, class_id):
				keys_ok = keys_ok and p1.mods.has(key)
	_check(keys_ok, "Alle Upgrade-Werte haben einen Platz im Spieler")
	_check(Perks.RARE_IDS.has("splitter") and Perks.RARE_IDS.has("ricochet") and Perks.RARE_IDS.has("seeker"), "Split Barrel, Ricochet und Seeker sind selten")
	_check(Perks.describe("splitter", "roomba") == "+1 Projektil pro Schuss", "Beschreibung: %s" % Perks.describe("splitter", "roomba"))
