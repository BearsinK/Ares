extends Node2D
## Hauptszene: Arena mit Plattformen, zwei Spielern, Gegnern (Director),
## Kamera, HUD und Spielablauf. Alles wird im Code gebaut, damit sich das
## Layout leicht anpassen laesst.

const ARENA_SIZE := Vector2(3200.0, 1350.0)
const FLOOR_Y := 1250.0
const WORLD_COLOR := Color(0.2, 0.22, 0.3)
const BG_COLOR := Color(0.08, 0.09, 0.13)

# Standardklassen (roomba, hexapod, vending, printer). F4 / F5 wechseln sie im Spiel.
const DEFAULT_CLASSES: Array = ["roomba", "hexapod"]
const ALL_CLASSES: Array = ["roomba", "hexapod", "vending", "printer"]

# Testausstattung: jeder Spieler bekommt drei Waffen zum Ausprobieren.
# Mit Dreieck (Controller) oder der Waffen-Taste wechselt man durch.
# Debug: F1 / F2 tauschen die aktuelle Waffe von Spieler 1 / 2 gegen die naechste.
const TEST_LOADOUTS := [
	["dust", "shotgun", "rocket"],
	["turret", "sniper", "beam"],
]
# Elementmodule der Testwaffen (gleiche Reihenfolge). Spaeter kauft man sie im Shop.
# Beispiel Coop: P1 macht mit Staubkugeln nass, P2 schockt mit dem Sniper.
const TEST_MODULES := [
	["water", "ice", "fire"],
	["lightning", "lightning", "fire"],
]

const DUMMY_RESPAWN_TIME := 4.0
const RESULT_DELAY := 1.4
const CLEAR_DELAY := 3.0
const HEALTH_DROP_CHANCE := 0.07
const HEALTH_DROP_HEAL := 0.25

enum Phase { WAVE, CLEARING, SHOP, BOSS, VICTORY }

## Tests koennen diese Werte vor dem Einhaengen der Szene setzen.
var use_dummies := false
var director_enabled := true
## Wenn gesetzt, starten die Spieler mit allen Testwaffen und Modulen.
## Sonst nur mit der Klassenwaffe, der Rest kommt aus dem Shop. F3 gibt das Testset.
var test_loadout := false
## Wellen: Dauer in Sekunden und Anzahl bis zum Sieg.
var wave_duration := 120.0
var max_waves := 10
## Nach der letzten Welle folgt der Endboss. Ohne Boss endet der Lauf mit dem Sieg.
var boss_enabled := true

var players: Array[Player] = []
var camera: CoopCamera
var fx: Fx
var hud: Hud
var backdrop: Backdrop
var director: Director
var projectiles: Node2D
var enemy_projectiles: Node2D
var pickups: Node2D
var levelup_menu: LevelUpMenu
var shop_menu: ShopMenu
var boss: Boss
var boss_arena: BossArena
var pause_menu: PauseMenu

var level := 1
var xp := 0
var xp_needed := 10
var kills := 0
var game_over := false
var wave := 1
var wave_time_left := 120.0
var phase := Phase.WAVE
var last_pad_event := "-"

var _respawns: Array[Dictionary] = []
var _game_over_time := 0.0
var _clear_time := 0.0
var _blast_depth := 0
var _arena_root: Node2D
## Chips, die der Lauf eingebracht hat (nach dem Ende gesetzt), und ob er schon verbucht ist.
var run_chips := 0
var run_recorded := false
## Modifikator der aktuellen Welle (Id) und Einblendung beim Wellenstart.
var wave_modifier := "normal"
var wave_banner_time := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(BG_COLOR)
	_build_arena()
	projectiles = Node2D.new()
	add_child(projectiles)
	enemy_projectiles = Node2D.new()
	add_child(enemy_projectiles)
	pickups = Node2D.new()
	add_child(pickups)
	fx = Fx.new()
	add_child(fx)
	_spawn_players()
	_setup_camera()
	backdrop.camera = camera
	_setup_director()
	if use_dummies:
		_spawn_dummies()
	wave_time_left = wave_duration
	shop_menu = ShopMenu.new()
	shop_menu.closed.connect(_on_shop_closed)
	add_child(shop_menu)
	levelup_menu = LevelUpMenu.new()
	levelup_menu.chosen.connect(_on_perk_chosen)
	add_child(levelup_menu)
	add_child(Vignette.new())
	hud = Hud.new()
	hud.main = self
	add_child(hud)
	pause_menu = PauseMenu.new()
	pause_menu.main = self
	add_child(pause_menu)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _physics_process(delta: float) -> void:
	wave_banner_time = maxf(0.0, wave_banner_time - delta)
	Music.set_layer_level(1.0 if phase == Phase.BOSS else clampf(0.2 + 0.08 * float(wave), 0.2, 0.9))
	_check_level_up()
	_update_wave(delta)
	for entry in _respawns:
		entry.t -= delta
		if entry.t <= 0.0:
			_spawn_dummy(entry.pos)
	_respawns = _respawns.filter(func(entry: Dictionary) -> bool: return entry.t > 0.0)

	if (game_over or phase == Phase.VICTORY) and not pause_menu.is_open():
		_game_over_time += delta
		if _game_over_time >= RESULT_DELAY:
			pause_menu.open_result(phase == Phase.VICTORY)


func _input(event: InputEvent) -> void:
	# Diagnose: zeigt im HUD, welcher Controller-Input zuletzt ankam.
	if event is InputEventJoypadButton and event.pressed:
		last_pad_event = "Controller %d Taste %d" % [event.device, event.button_index]
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		last_pad_event = "Controller %d Achse %d (%.1f)" % [event.device, event.axis, event.axis_value]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _can_pause():
		pause_menu.open_pause()
		get_viewport().set_input_as_handled()
		return
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			_cycle_weapon(0)
		elif event.keycode == KEY_F2:
			_cycle_weapon(1)
		elif event.keycode == KEY_F3:
			_grant_test_loadout()
		elif event.keycode == KEY_F4:
			_switch_class(0)
		elif event.keycode == KEY_F5:
			_switch_class(1)


func _can_pause() -> bool:
	return not (game_over or phase == Phase.VICTORY or phase == Phase.SHOP or levelup_menu.is_open or shop_menu.is_open or pause_menu.is_open())


func _grant_test_loadout() -> void:
	for i in players.size():
		var player := players[i]
		player.weapons.clear()
		player.modules.clear()
		for j in TEST_LOADOUTS[i].size():
			player.weapons.append(TEST_LOADOUTS[i][j])
			player.modules.append(TEST_MODULES[i][j])
		player.weapon_index = 0
	Sfx.play("levelup")


func _update_wave(delta: float) -> void:
	match phase:
		Phase.WAVE:
			if not director_enabled or game_over:
				return
			wave_time_left -= delta
			director.wave_progress = 1.0 - wave_time_left / wave_duration
			if wave_time_left <= 0.0:
				_end_wave()
		Phase.CLEARING:
			_clear_time -= delta
			if _clear_time <= 0.0 and not game_over and not levelup_menu.is_open:
				_open_shop()


func _end_wave() -> void:
	phase = Phase.CLEARING
	_clear_time = CLEAR_DELAY
	director.enabled = false
	Sfx.play("levelup")
	# Restliche Gegner zerfallen und lassen ihre Beute fallen, die zu den Spielern fliegt.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy:
			enemy.take_damage(1.0e9, null, Vector2.ZERO, "", true)
	for bullet in enemy_projectiles.get_children():
		bullet.queue_free()
	for pickup in pickups.get_children():
		pickup.force_pull = true
	# Alle stehen wieder auf und erholen sich etwas.
	for player in players:
		if player.downed:
			player.revive(0.5)
		else:
			player.hp = minf(player.max_health(), player.hp + player.max_health() * 0.3)


func _open_shop() -> void:
	if wave >= max_waves and not boss_enabled:
		phase = Phase.VICTORY
		_game_over_time = 0.0
		_record_run(true)
		return
	phase = Phase.SHOP
	shop_menu.before_boss = wave >= max_waves
	shop_menu.open(players, wave)


func _on_shop_closed() -> void:
	if wave >= max_waves:
		_start_boss()
		return
	wave += 1
	wave_time_left = wave_duration
	_apply_modifier()
	phase = Phase.WAVE
	director.enabled = director_enabled


## Endkampf: Die Arena wird zur Ofenhalle mit Laufband, der Boss tritt auf.
func _start_boss() -> void:
	phase = Phase.BOSS
	director.enabled = false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy:
			enemy.queue_free()
	for bullet in enemy_projectiles.get_children():
		bullet.queue_free()
	for pickup in pickups.get_children():
		pickup.queue_free()
	_clear_arena()
	_build_arena(true)
	boss_arena = BossArena.new()
	add_child(boss_arena)
	boss_arena.setup(self, players)
	boss = boss_arena.boss
	boss.died.connect(_on_boss_died)
	for i in players.size():
		var player := players[i]
		player.global_position = Vector2(1650.0 + i * 120.0, FLOOR_Y - float(player.stats.size.y) * 0.5 - 2.0)
		player.velocity = Vector2.ZERO
		if player.downed:
			player.revive(0.6)
		else:
			player.hp = minf(player.max_health(), player.hp + player.max_health() * 0.4)
		player.iframes = 1.5
	camera.bias = Vector2(350.0, -80.0)
	camera.max_zoom = 0.8
	camera.global_position = (players[0].global_position + players[1].global_position) * 0.5 + camera.bias
	Sfx.play("levelup")


## Verbucht den Lauf einmal im Spielstand (Chips, Bestwerte).
func _record_run(victory: bool) -> void:
	if run_recorded:
		return
	run_recorded = true
	var cleared := wave if victory else wave - 1
	run_chips = SaveData.record_run(maxi(cleared, 0), kills, level, int(director.time), victory and boss != null and boss.dying)


## Wird beim Verlassen per Pausemenue aufgerufen, damit auch abgebrochene Laeufe zaehlen.
func abandon_run() -> void:
	_record_run(false)


func _on_boss_died() -> void:
	phase = Phase.VICTORY
	_game_over_time = 0.0
	_record_run(true)
	for player in players:
		if player.downed:
			player.revive(0.5)


func _apply_modifier() -> void:
	wave_modifier = WaveModifiers.pick(wave, max_waves, wave_modifier)
	director.start_wave(wave, WaveModifiers.DATA[wave_modifier])
	wave_banner_time = 3.5 if wave_modifier != "normal" else 0.0
	if wave_modifier != "normal":
		Sfx.play("telegraph")


func _cycle_weapon(index: int) -> void:
	var player := players[index]
	var current := Weapons.ALL_IDS.find(player.current_weapon_id())
	player.weapons[player.weapon_index] = Weapons.ALL_IDS[(current + 1) % Weapons.ALL_IDS.size()]
	Sfx.play("switch")


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	print("Controller %d %s: %s" % [device, "verbunden" if connected else "getrennt", Input.get_joy_name(device)])


## Gewaehlte Klassen bleiben ueber Neustarts erhalten (F4 / F5 wechseln sie).
func _class_for(index: int) -> String:
	return Engine.get_meta("classes", DEFAULT_CLASSES)[index]


func _switch_class(index: int) -> void:
	var classes: Array = Engine.get_meta("classes", DEFAULT_CLASSES).duplicate()
	classes[index] = ALL_CLASSES[(ALL_CLASSES.find(classes[index]) + 1) % ALL_CLASSES.size()]
	Engine.set_meta("classes", classes)
	get_tree().reload_current_scene()


func _spawn_players() -> void:
	for i in 2:
		var player := Player.new()
		player.setup(i + 1, _class_for(i))
		if test_loadout:
			player.weapons.clear()
			player.modules.clear()
			for j in TEST_LOADOUTS[i].size():
				player.weapons.append(TEST_LOADOUTS[i][j])
				player.modules.append(TEST_MODULES[i][j])
		player.position = Vector2(300.0 + i * 110.0, FLOOR_Y - float(player.stats.size.y) * 0.5 - 2.0)
		player.fired.connect(_on_player_fired)
		player.went_down.connect(_on_player_down)
		player.hurt.connect(_on_player_hurt)
		player.heavy_landed.connect(func(_p: Player, strength: float) -> void: camera.add_shake(5.0 + 8.0 * strength))
		player.slam_landed.connect(_on_slam_landed)
		player.add_mods(Meta.player_mods())
		player.gold = Meta.start_gold()
		add_child(player)
		players.append(player)
	players[0].partner = players[1]
	players[1].partner = players[0]


## Kurzer Stillstand bei harten Treffern (laeuft in Echtzeit, nicht in Spielzeit).
func hitstop(duration: float) -> void:
	if Engine.time_scale < 1.0 or game_over:
		return
	Engine.time_scale = 0.08
	get_tree().create_timer(duration, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


func _on_player_hurt(player: Player, amount: float) -> void:
	camera.add_shake(minf(8.0 + amount * 0.5, 18.0))
	hud.flash(Color(1.0, 0.15, 0.1, 0.35))
	if amount >= 15.0:
		hitstop(0.06)
	Fx.instance.spark(player.global_position, Color(1.0, 0.4, 0.3), 10, 400.0)


func _on_slam_landed(player: Player, pos: Vector2) -> void:
	_explode(pos, 150.0, 35.0 * player.damage_mult(), player, Color(0.9, 0.9, 1.0))


func _on_player_down(_player: Player) -> void:
	# Waehrend der Sterbeanimation des Bosses ist der Kampf gewonnen.
	if boss != null and is_instance_valid(boss) and boss.dying:
		return
	for player in players:
		if not player.downed:
			return
	game_over = true
	_game_over_time = 0.0
	_record_run(false)
	Sfx.play("kill")


func _setup_director() -> void:
	director = Director.new()
	director.enabled = director_enabled
	director.arena_size = ARENA_SIZE
	director.floor_y = FLOOR_Y
	director.players = players
	director.parent_node = self
	director.enemy_spawned.connect(_on_enemy_spawned)
	director.projectile_requested.connect(_on_enemy_projectile_requested)
	director.strike_requested.connect(_on_strike_requested)
	add_child(director)


func _on_enemy_spawned(enemy: Enemy) -> void:
	enemy.died.connect(_on_enemy_died)


func _on_enemy_died(enemy: Enemy) -> void:
	kills += 1
	var info: Dictionary = enemy.data
	_spawn_pickup("xp", int(info.xp) * (3 if enemy.elite else 1), enemy.global_position)
	var gold_value := 1 + int(director.difficulty() * 1.1)
	var coins := int(float(info.gold_chance)) + (1 if randf() < fmod(float(info.gold_chance), 1.0) else 0)
	if enemy.elite:
		coins += 3
	coins = int(round(float(coins) * float(WaveModifiers.DATA[wave_modifier].get("gold", 1.0))))
	for i in coins:
		_spawn_pickup("gold", gold_value, enemy.global_position)
	for player in players:
		if not player.downed and float(player.mods.kill_heal) > 0.0:
			player.hp = minf(player.max_health(), player.hp + float(player.mods.kill_heal))
	for player in players:
		player.ability.reduce_cooldown(float(player.stats.get("kill_cooldown", 0.0)))
	var blast := 0.0
	for player in players:
		blast = maxf(blast, float(player.mods.death_blast))
	if blast > 0.0:
		_death_blast(enemy.global_position, blast)
	if enemy.elite or randf() < HEALTH_DROP_CHANCE:
		_spawn_pickup("hp", 1, enemy.global_position)
	if enemy.elite:
		hitstop(0.09)
		camera.add_shake(12.0)


## Kleine Kettenexplosion beim Tod eines Gegners (Perk Sprengkapsel).
func _death_blast(pos: Vector2, damage: float) -> void:
	if _blast_depth >= 5:
		return
	_blast_depth += 1
	if Fx.instance:
		Fx.instance.ring(pos, 80.0, Color(1.0, 0.6, 0.25))
		Fx.instance.spark(pos, Color(1.0, 0.6, 0.25), 6, 300.0)
	for other in get_tree().get_nodes_in_group("enemies"):
		if other.global_position.distance_to(pos) <= 85.0:
			other.take_damage(damage, null, (other.global_position - pos).normalized(), "", true)
	_blast_depth -= 1


func _spawn_pickup(kind: String, value: int, pos: Vector2) -> void:
	if pickups.get_child_count() > 150 and kind != "hp":
		# Zu viele Objekte: Wert direkt gutschreiben statt ein weiteres zu erzeugen.
		if kind == "xp":
			xp += maxi(1, int(round(value * Meta.xp_multiplier())))
		elif kind == "gold":
			var receiver: Player = players[kills % players.size()]
			receiver.gold += maxi(1, int(round(value * (1.0 + float(receiver.mods.gold)))))
		return
	var pickup := Pickup.new()
	pickup.kind = kind
	pickup.value = value
	pickup.players = players
	pickup.floor_y = FLOOR_Y
	pickup.force_pull = phase == Phase.CLEARING
	pickup.position = pos
	pickup.collected.connect(_on_pickup_collected)
	pickups.add_child(pickup)


func _on_pickup_collected(pickup: Pickup, player: Player) -> void:
	if pickup.kind == "xp":
		xp += maxi(1, int(round(pickup.value * Meta.xp_multiplier())))
		Sfx.play("pickup")
	elif pickup.kind == "hp":
		var heal := player.max_health() * HEALTH_DROP_HEAL
		player.hp = minf(player.max_health(), player.hp + heal)
		Sfx.play("revive")
		if Fx.instance:
			Fx.instance.number(player.global_position + Vector2(0.0, -70.0), heal, Color(0.5, 1.0, 0.6), 24)
	else:
		player.gold_flash()
		player.gold += maxi(1, int(round(pickup.value * (1.0 + float(player.mods.gold)))))
		Sfx.play("coin")


func _check_level_up() -> void:
	if game_over or levelup_menu.is_open or xp < xp_needed:
		return
	# Nie ueber dem Shop oder dem Ergebnisbildschirm: zwei offene Menues wuerden sich gegenseitig entpausieren.
	if shop_menu.is_open or phase == Phase.SHOP or phase == Phase.VICTORY:
		return
	xp -= xp_needed
	level += 1
	xp_needed = 10 + 6 * (level - 1) + 2 * (level - 1) * (level - 1)
	levelup_menu.open(players, Perks.random_ids(3), level)


func _on_perk_chosen(perk_id: String) -> void:
	for player in players:
		player.add_mods(Perks.mods_for(perk_id, player.class_id))


func _on_enemy_projectile_requested(_enemy: Enemy, origin: Vector2, direction: Vector2, speed: float, damage: float) -> void:
	var bullet := EnemyProjectile.new()
	bullet.position = origin
	bullet.direction = direction
	bullet.speed = speed
	bullet.damage = damage
	enemy_projectiles.add_child(bullet)


func _on_strike_requested(_enemy: Enemy, pos: Vector2, radius: float, delay: float, damage: float) -> void:
	var strike := AreaStrike.new()
	strike.position = pos
	strike.radius = radius
	strike.delay = delay
	strike.damage = damage
	strike.players = players
	strike.exploded.connect(func(_at: Vector2) -> void:
		camera.add_shake(7.0)
		Sfx.play("explosion"))
	enemy_projectiles.add_child(strike)


func _spawn_dummies() -> void:
	for x in [1300.0, 1900.0, 2400.0]:
		_spawn_dummy(Vector2(x, FLOOR_Y - 40.0))


func _spawn_dummy(pos: Vector2) -> void:
	var dummy := TestDummy.new()
	dummy.position = pos
	dummy.died.connect(_on_dummy_died)
	add_child(dummy)


func _on_dummy_died(pos: Vector2) -> void:
	_respawns.append({"pos": pos, "t": DUMMY_RESPAWN_TIME})


func _clear_arena() -> void:
	if _arena_root != null:
		_arena_root.queue_free()
		_arena_root = null


func _build_arena(boss_mode := false) -> void:
	_arena_root = Node2D.new()
	add_child(_arena_root)
	move_child(_arena_root, 0)
	if boss_mode:
		_build_boss_layout()
	else:
		_build_wave_layout()
	var props := Props.new()
	props.boss_mode = boss_mode
	if not boss_mode:
		props.shaft = Rect2(2640.0, 600.0, 200.0, 650.0)
	_arena_root.add_child(props)
	if backdrop == null:
		backdrop = Backdrop.new()
		add_child(backdrop)
		move_child(backdrop, 0)


func _build_wave_layout() -> void:
	# Boden, Waende, Decke.
	_add_block(Rect2(0.0, FLOOR_Y, ARENA_SIZE.x, 100.0), "floor")
	_add_block(Rect2(-100.0, -100.0, 100.0, ARENA_SIZE.y + 200.0), "wall")
	_add_block(Rect2(ARENA_SIZE.x, -100.0, 100.0, ARENA_SIZE.y + 200.0), "wall")
	_add_block(Rect2(0.0, -100.0, ARENA_SIZE.x, 100.0), "ceiling")

	# Stege. Links eine Treppe aus Plattformen, in der Mitte mehrere Ebenen,
	# rechts der Schacht. Alle sind von unten durchlaessig.
	var platforms: Array[Rect2] = [
		Rect2(110.0, 1130.0, 280.0, 24.0),
		Rect2(470.0, 1010.0, 260.0, 24.0),
		Rect2(150.0, 890.0, 260.0, 24.0),
		Rect2(520.0, 770.0, 240.0, 24.0),
		Rect2(1000.0, 1100.0, 1100.0, 24.0),
		Rect2(1200.0, 930.0, 320.0, 24.0),
		Rect2(1680.0, 930.0, 320.0, 24.0),
		Rect2(1440.0, 760.0, 320.0, 24.0),
		Rect2(2250.0, 1120.0, 260.0, 24.0),
		Rect2(2330.0, 970.0, 220.0, 24.0),
		Rect2(2920.0, 1010.0, 240.0, 24.0),
		Rect2(2960.0, 820.0, 200.0, 24.0),
	]
	for rect in platforms:
		_add_block(rect, "platform")

	# Hoher Schacht mit Belohnungs-Plattform: gedacht fuer Wandsprung, Klettern und Haken.
	_add_block(Rect2(2600.0, 600.0, 40.0, 650.0), "wall")
	_add_block(Rect2(2840.0, 600.0, 40.0, 650.0), "wall")
	_add_block(Rect2(2570.0, 600.0, 340.0, 24.0), "platform")


## Ofenhalle: links die Verbrennungsgrube, ueber den Boden laeuft das Band.
## Die Plattformen liegen ueber dem Band und sind der Ausweichweg.
func _build_boss_layout() -> void:
	_add_block(Rect2(BossArena.PIT_WIDTH, FLOOR_Y, ARENA_SIZE.x - BossArena.PIT_WIDTH, 100.0), "floor")
	_add_block(Rect2(0.0, FLOOR_Y + 90.0, BossArena.PIT_WIDTH, 60.0), "floor")
	_add_block(Rect2(-100.0, -100.0, 100.0, ARENA_SIZE.y + 200.0), "wall")
	_add_block(Rect2(ARENA_SIZE.x, -100.0, 100.0, ARENA_SIZE.y + 200.0), "wall")
	_add_block(Rect2(0.0, -100.0, ARENA_SIZE.x, 100.0), "ceiling")
	# Der Boss steht in seiner Nische: eine unsichtbare Wand haelt die Spieler davor.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1 << 7
	wall.collision_mask = 0
	wall.position = Vector2(BossArena.BOSS_WALL_X + 100.0, ARENA_SIZE.y * 0.5)
	var wall_shape := CollisionShape2D.new()
	var wall_box := RectangleShape2D.new()
	wall_box.size = Vector2(200.0, ARENA_SIZE.y + 400.0)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	_arena_root.add_child(wall)
	var platforms: Array[Rect2] = [
		Rect2(360.0, 1070.0, 300.0, 24.0),
		Rect2(930.0, 1070.0, 300.0, 24.0),
		Rect2(1500.0, 1070.0, 300.0, 24.0),
		Rect2(2070.0, 1070.0, 300.0, 24.0),
		Rect2(650.0, 890.0, 260.0, 24.0),
		Rect2(1230.0, 890.0, 260.0, 24.0),
		Rect2(1810.0, 890.0, 260.0, 24.0),
		Rect2(2380.0, 890.0, 220.0, 24.0),
	]
	for rect in platforms:
		_add_block(rect, "platform")


func _add_block(rect: Rect2, kind := "platform") -> void:
	var one_way := kind == "platform"
	var body := StaticBody2D.new()
	# Plattformen liegen auf Ebene 6 und lassen sich von unten durchspringen.
	body.collision_layer = (1 << 5) if one_way else (1 << 0)
	body.collision_mask = 0
	body.position = rect.get_center()

	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.one_way_collision = one_way
	shape.one_way_collision_margin = 10.0
	body.add_child(shape)

	# Unterseiten, an denen der Hexapod haengen kann (Plattformen und Decke).
	if kind == "platform" or kind == "ceiling":
		body.add_to_group("ceilings")
		body.set_meta("rect", rect)
	var art := BlockArt.new()
	art.kind = kind
	art.size = rect.size
	body.add_child(art)
	_arena_root.add_child(body)


func _setup_camera() -> void:
	camera = CoopCamera.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(ARENA_SIZE.x)
	camera.limit_bottom = int(ARENA_SIZE.y)
	for player in players:
		camera.targets.append(player)
	add_child(camera)
	camera.global_position = (players[0].global_position + players[1].global_position) * 0.5


func _on_player_fired(player: Player, weapon_id: String, origin: Vector2, direction: Vector2, charge := 0.0) -> void:
	var weapon := Weapons.get_weapon(weapon_id)
	var damage := float(weapon.damage) * player.damage_mult()
	if randf() < float(player.mods.crit):
		damage *= 2.0
	var element := player.current_module()
	var color := Elements.color_of(element, weapon.color)
	var sound: String = weapon.sound
	if sound == "turret" and player.ability.is_active("overwatch"):
		sound = "turret_over"
	Sfx.play(sound)
	camera.add_shake(float(weapon.shake))
	fx.muzzle(origin, direction, color)
	if weapon.kind == "lob":
		_fire_lob(player, weapon, origin, direction, damage, element, color, charge)
	elif weapon.kind == "hitscan":
		_fire_hitscan(player, weapon, origin, direction, damage, element, color)
	else:
		_fire_projectiles(player, weapon, origin, direction, damage, element, color)


func _fire_lob(player: Player, weapon: Dictionary, origin: Vector2, direction: Vector2, damage: float, element: String, color: Color, charge: float) -> void:
	var can := Projectile.new()
	can.position = origin
	can.direction = direction
	can.speed = lerpf(float(weapon.speed), float(weapon.speed_max), charge)
	can.arc_gravity = float(weapon.gravity)
	can.damage = damage
	can.lifetime = float(weapon.lifetime)
	can.size = float(weapon.size)
	can.color = color
	can.element = element
	can.shooter = player
	can.collide_platforms = true
	can.charge = charge
	# Nur geschuettelte Dosen explodieren, Staerke und Radius wachsen mit dem Schuetteln.
	if charge >= float(weapon.min_shake):
		can.shaken = true
		can.explosion_radius = lerpf(float(weapon.explosion_radius), float(weapon.explosion_radius_max), charge)
		can.explosion_damage = lerpf(float(weapon.explosion_damage), float(weapon.explosion_damage_max), charge) * player.damage_mult()
	can.hit.connect(_on_projectile_hit)
	projectiles.add_child(can)


func _fire_projectiles(player: Player, weapon: Dictionary, origin: Vector2, direction: Vector2, damage: float, element: String, color: Color) -> void:
	for i in int(weapon.pellets):
		var bullet := Projectile.new()
		bullet.position = origin
		bullet.direction = direction.rotated(randf_range(-float(weapon.spread), float(weapon.spread)))
		bullet.speed = float(weapon.speed) * randf_range(0.9, 1.0) if weapon.pellets > 1 else float(weapon.speed)
		bullet.damage = damage
		bullet.lifetime = float(weapon.lifetime)
		bullet.pierce = int(weapon.pierce) + int(player.mods.pierce)
		bullet.size = float(weapon.size)
		bullet.color = color
		bullet.element = element
		bullet.shooter = player
		bullet.explosion_radius = float(weapon.get("explosion_radius", 0.0))
		bullet.explosion_damage = float(weapon.get("explosion_damage", 0.0)) * player.damage_mult()
		bullet.hit.connect(_on_projectile_hit)
		projectiles.add_child(bullet)


## Explosivgeschoss einer Drucker-Drohne.
func spawn_drone_shot(player: Player, origin: Vector2, direction: Vector2) -> void:
	var bullet := Projectile.new()
	bullet.position = origin
	bullet.direction = direction
	bullet.speed = 750.0
	bullet.damage = 6.0 * player.damage_mult()
	bullet.lifetime = 1.0
	bullet.size = 4.0
	bullet.color = Color(1.0, 0.65, 0.25)
	var element := player.current_module()
	if element != "":
		bullet.element = element
		bullet.color = Elements.COLORS[element]
	bullet.shooter = player
	bullet.explosion_radius = 55.0
	bullet.explosion_damage = 9.0 * player.damage_mult()
	bullet.hit.connect(_on_projectile_hit)
	projectiles.add_child(bullet)


func _fire_hitscan(player: Player, weapon: Dictionary, origin: Vector2, direction: Vector2, damage: float, element: String, color: Color) -> void:
	var space := get_world_2d().direct_space_state
	var target := origin + direction * float(weapon.range)
	var end := target
	var exclude: Array[RID] = []
	var hits_left := int(weapon.pierce) + int(player.mods.pierce) + 1
	while hits_left > 0:
		var query := PhysicsRayQueryParameters2D.create(origin, target, (1 << 0) | (1 << 2))
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.exclude = exclude
		var result := space.intersect_ray(query)
		if result.is_empty():
			break
		var collider: Object = result.collider
		if collider.has_method("take_damage"):
			collider.take_damage(damage, player, direction, element)
			fx.spark(result.position, color, 4)
			exclude.append(result.rid)
			hits_left -= 1
		else:
			end = result.position
			fx.spark(end, color, 3)
			break
	fx.tracer(origin, end, color, float(weapon.width), float(weapon.tracer_life))


func _on_projectile_hit(projectile: Projectile, pos: Vector2, _target: Node) -> void:
	fx.spark(pos, projectile.color, 4)
	if projectile.explosion_radius > 0.0:
		var shake_amount := 10.0 if projectile.arc_gravity <= 0.0 else 4.0 + 8.0 * projectile.charge
		_explode(pos, projectile.explosion_radius, projectile.explosion_damage, projectile.shooter, projectile.color, projectile.element, shake_amount)
	elif projectile.arc_gravity > 0.0:
		Sfx.play("pop")


func _explode(pos: Vector2, radius: float, damage: float, shooter: Node, color: Color, element := "", shake_amount := 10.0) -> void:
	fx.explosion(pos, radius, color)
	camera.add_shake(shake_amount)
	Sfx.play("explosion")
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var distance: float = enemy.global_position.distance_to(pos)
		if distance <= radius + 25.0:
			var falloff := 1.0 - 0.5 * clampf(distance / radius, 0.0, 1.0)
			var away: Vector2 = (enemy.global_position - pos).normalized()
			enemy.take_damage(damage * falloff, shooter, away, element)


