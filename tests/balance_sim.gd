extends Node
## Entwickler-Werkzeug (nicht Teil der Testsuite): Ein einfacher Bot spielt eine
## ganze Partie schneller als Echtzeit und meldet pro Welle Kennzahlen. Er zielt,
## schiesst, haelt Abstand, dasht gegen Angriffe und kauft im Shop ein. Er ist
## nicht so gut wie ein Mensch, zeigt aber grobe Balance-Probleme.
## Ausfuehren: SIM_CLASSES=roomba,hexapod SIM_SCALE=6 godot --headless --path . res://tests/balance_sim.tscn

var main: Node
var scale := 6.0
var _lob_timer := [0.0, 0.0]
var _last_wave := 0
var _log_next := 0.0
var _jump_timer := [0.0, 0.0]
var _jump_hold := [0.0, 0.0]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var classes := OS.get_environment("SIM_CLASSES")
	Engine.set_meta("classes", classes.split(",") if classes != "" else ["roomba", "hexapod"])
	scale = float(OS.get_environment("SIM_SCALE")) if OS.get_environment("SIM_SCALE") != "" else 6.0
	main = load("res://scenes/main.tscn").instantiate()
	main.stage_id = OS.get_environment("SIM_STAGE") if OS.get_environment("SIM_STAGE") != "" else "classic"
	if OS.get_environment("SIM_WAVES") != "":
		main.max_waves = int(OS.get_environment("SIM_WAVES"))
	if OS.get_environment("SIM_BOSS") != "":
		main.test_loadout = true
	add_child(main)
	if OS.get_environment("SIM_BOSS") != "":
		_boss_start.call_deferred()
	print("Klassen: ", Engine.get_meta("classes"), "  Tempo x", scale)


func _boss_start() -> void:
	for i in 20:
		await get_tree().physics_frame
	for p in main.players:
		p.add_mods({"damage": 0.5, "fire_rate": 0.25, "max_hp": 60.0})
		p.hp = p.max_health()
	main.wave = main.max_waves
	main._start_boss()
	for p in main.players:
		p.hurt.connect(func(pl: Player, amount: float) -> void: print("TREFFER P%d -%d bei x=%d y=%d vy %d %s" % [pl.player_index, amount, pl.global_position.x, pl.global_position.y, pl.velocity.y, str(get_tree().get_nodes_in_group("belt_obstacles").map(func(o): return "%s@%d" % [o.kind, o.global_position.x]))]))
	print("Bosskampf gestartet (Testausstattung mit Modulen)")


var _status_next := 0.0


func _physics_process(delta: float) -> void:
	Engine.time_scale = scale
	# SIM_STATUS=1: alle 15 s Echtzeit eine Statuszeile (hilft bei Haengern).
	if OS.get_environment("SIM_STATUS") != "" and Time.get_ticks_msec() / 1000.0 > _status_next:
		_status_next = Time.get_ticks_msec() / 1000.0 + 15.0
		print("STATUS Welle %d Phase %d Rest %.0f Zeit %d pausiert %s Menues L%s S%s C%s Gegner %d Tore %s" % [main.wave, main.phase, main.wave_time_left, int(main.director.time), get_tree().paused, main.levelup_menu.is_open, main.shop_menu.is_open, main.contract_menu.is_open, main.director.alive_count(), main.gates.is_closed if main.gates != null else "-"])
	if main.game_over:
		_report("GAME OVER")
		get_tree().quit()
		return
	if main.phase == main.Phase.VICTORY:
		_report("SIEG")
		get_tree().quit()
		return
	if main.contract_menu.is_open:
		var contracts: ContractMenu = main.contract_menu
		contracts._finish(contracts.perk_ids[randi() % contracts.perk_ids.size()])
		return
	if main.levelup_menu.is_open:
		var menu: LevelUpMenu = main.levelup_menu
		menu._finish(menu.perk_ids[randi() % menu.perk_ids.size()])
		return
	if main.shop_menu.is_open:
		_shop()
		return
	if main.phase == main.Phase.BOSS and main.boss != null:
		if OS.get_environment("SIM_NOOBS") != "":
			main.boss_arena.clear_obstacles()
		if Time.get_ticks_msec() / 1000.0 > _log_next:
			_log_next = Time.get_ticks_msec() / 1000.0 + 2.0
			print("Boss HP %d Phase %d offen %s Attacke %s | P1 %d P2 %d" % [main.boss.hp, main.boss.phase, main.boss.open, main.boss._attack, main.players[0].hp, main.players[main.players.size() - 1].hp])
	if main.wave != _last_wave:
		_last_wave = main.wave
		_report("Welle %d beginnt" % main.wave)
	for i in main.players.size():
		_bot(i, delta)


func _report(title: String) -> void:
	var p1: Player = main.players[0]
	var t := int(main.director.time)
	var line := "%s | Zeit %02d:%02d Stufe %d Kills %d | P1 %s %d/%d Gold %d" % [title, t / 60, t % 60, main.level, main.kills, p1.class_id, p1.hp, p1.max_health(), p1.gold]
	if main.players.size() > 1:
		var p2: Player = main.players[1]
		line += " | P2 %s %d/%d Gold %d" % [p2.class_id, p2.hp, p2.max_health(), p2.gold]
	print("%s | Gegner %d | Waffen %s" % [line, main.director.alive_count(), p1.weapons])


func _shop() -> void:
	var shop: ShopMenu = main.shop_menu
	for i in main.players.size():
		var player: Player = main.players[i]
		var spent := true
		while spent:
			spent = false
			var offers: Array = shop._offers[i]
			# Teuerste leistbare zuerst: Waffen und Firmware vor Buffs.
			var best := -1
			var best_price := -1
			for slot in offers.size():
				var offer: Dictionary = offers[slot]
				if offer.bought or player.gold < offer.price:
					continue
				if offer.type == "module" and player.current_module() != "":
					continue
				if offer.type == "weapon" and player.weapons.size() >= 3:
					continue
				if offer.price > best_price:
					best = slot
					best_price = offer.price
			if best >= 0:
				shop._cursor[i] = best
				shop._activate(i)
				spent = true
		shop._cursor[i] = ShopMenu.READY_SLOT
		shop._activate(i)


func _bot(i: int, delta: float) -> void:
	var p: Player = main.players[i]
	var prefix := "p%d_" % (i + 1)
	for action in ["left", "right", "aim_left", "aim_right", "aim_up", "aim_down", "fire", "dash", "ability", "interact", "down"]:
		Input.action_release(prefix + action)
	var want_jump := false
	if p.downed:
		Input.action_release(prefix + "jump")
		return
	var partner: Player = p.partner
	# Partner wiederbeleben.
	if partner != null and partner.downed:
		var gap := partner.global_position.x - p.global_position.x
		if absf(gap) > 40.0:
			Input.action_press(prefix + ("right" if gap > 0.0 else "left"))
		else:
			Input.action_press(prefix + "interact")
		Input.action_release(prefix + "jump")
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var best := INF
	var close := 0
	var threat := false
	for enemy in enemies:
		var d: float = p.global_position.distance_to(enemy.global_position)
		if d < best:
			best = d
			nearest = enemy
		if d < 450.0:
			close += 1
		if enemy is Enemy and enemy._state == Enemy.State.WINDUP and d < 220.0:
			threat = true
	for bullet in main.enemy_projectiles.get_children():
		if bullet.global_position.distance_to(p.global_position) < 110.0:
			threat = true
	var move := 0.0
	var boss_fight: bool = main.phase == main.Phase.BOSS
	if boss_fight:
		# Hindernisse rollen von links auf den Boss zu: gegen das Band anlaufen (nach links), Kiste, Stapel und Saege
		# ueberspringen, unter Traegern durchlaufen (dort nicht springen). Vom Schredder und vom Boss fernhalten.
		var jump_now := false
		var beam_near := false
		var obstacle_ahead := false
		for ob in get_tree().get_nodes_in_group("belt_obstacles"):
			var dx: float = p.global_position.x - ob.global_position.x
			var closing: float = ob.speed + maxf(0.0, -p.velocity.x)
			var edge := dx - 45.0 - float(p.stats.size.x) * 0.5
			if p.global_position.y < 1100.0 or edge < -40.0 or edge > 300.0:
				continue
			obstacle_ahead = true
			if ob.kind == "beam":
				beam_near = beam_near or edge < 140.0
			elif p.is_on_floor() and dx < closing * 0.42 + 10.0:
				jump_now = true
		if OS.get_environment("SIM_DEBUG") != "" and i == 0 and obstacle_ahead:
			var info := ""
			for ob in get_tree().get_nodes_in_group("belt_obstacles"):
				info += " %s@%d" % [ob.kind, ob.global_position.x - p.global_position.x]
			print("TRACE x %d y %d vx %d vy %d floor %s jump %s |%s" % [p.global_position.x, p.global_position.y, p.velocity.x, p.velocity.y, p.is_on_floor(), jump_now, info])
		if obstacle_ahead and not p.is_on_floor():
			move = -1.0
		if jump_now and not beam_near:
			_jump_hold[i] = 0.5
		if _jump_hold[i] > 0.0 and not beam_near:
			want_jump = true
		_jump_hold[i] = maxf(0.0, _jump_hold[i] - delta)
		# Auf Abstand zum Boss halten und gegen das Band anlaufen.
		var target_x := 1900.0
		if p.global_position.x > target_x:
			move = -1.0
		elif p.global_position.x < target_x - 250.0:
			move = 1.0
		for strike in main.enemy_projectiles.get_children():
			if strike is AreaStrike and absf(strike.global_position.x - p.global_position.x) < strike.radius + 40.0:
				move = signf(p.global_position.x - strike.global_position.x)
	if nearest != null:
		var offset := nearest.global_position - p.global_position
		var dir := offset.normalized()
		var vertical_ok := absf(offset.y) < 400.0
		Input.action_press(prefix + ("aim_right" if dir.x > 0.0 else "aim_left"), absf(dir.x))
		Input.action_press(prefix + ("aim_down" if dir.y > 0.0 else "aim_up"), absf(dir.y))
		var weapon := Weapons.get_weapon(p.current_weapon_id())
		var reach := 700.0 if weapon.kind != "lob" else 650.0
		if boss_fight:
			reach = 1100.0
		if best < reach:
			if weapon.kind == "lob":
				# Dose: kurz schuetteln, dann werfen.
				_lob_timer[i] += delta
				if _lob_timer[i] < 0.5:
					Input.action_press(prefix + "fire")
				elif _lob_timer[i] > 0.6:
					_lob_timer[i] = 0.0
			else:
				Input.action_press(prefix + "fire")
		# Abstand halten: zu nah weg, zu fern hin. Der Hexapod bleibt stehen, um zu schiessen.
		var keep := 330.0
		if boss_fight:
			pass
		elif best < keep * 0.7:
			move = -signf(offset.x)
		elif best > keep * 1.6 and best < 1500.0:
			move = signf(offset.x)
		if boss_fight:
			var hold_x := 2300.0
			if p.global_position.x < hold_x:
				move = 1.0
			for strike in main.enemy_projectiles.get_children():
				if strike is AreaStrike and absf(strike.global_position.x - p.global_position.x) < strike.radius + 40.0:
					move = signf(p.global_position.x - strike.global_position.x)
		if close >= 3 and p.ability.is_ready():
			Input.action_press(prefix + "ability")
		if offset.y < -90.0 and best < 500.0 and vertical_ok:
			want_jump = true
	else:
		# Ohne Gegner dem Partner naehern.
		if partner != null:
			var gap := partner.global_position.x - p.global_position.x
			move = signf(gap) if absf(gap) > 250.0 else 0.0
	# Beieinander bleiben.
	if partner != null:
		var partner_gap := partner.global_position.x - p.global_position.x
		if absf(partner_gap) > 1100.0:
			move = signf(partner_gap)
	if move != 0.0:
		Input.action_press(prefix + ("right" if move > 0.0 else "left"))
	if p.is_on_wall() and move != 0.0:
		want_jump = true
	if threat and p.dash_charges > 0:
		Input.action_press(prefix + "dash")
		Input.action_press(prefix + ("right" if move >= 0.0 else "left"))
	# Gelegentlich springen, um Beute und Plattformen zu erreichen.
	_jump_timer[i] -= delta
	if _jump_timer[i] <= 0.0:
		_jump_timer[i] = randf_range(1.5, 3.5)
		if not boss_fight:
			want_jump = true
	if want_jump:
		Input.action_press(prefix + "jump")
	else:
		Input.action_release(prefix + "jump")
