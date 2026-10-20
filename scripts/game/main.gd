extends Node2D
## Hauptszene: Arena mit Plattformen, zwei Spielern, Gegnern (Director),
## Kamera, HUD und Spielablauf. Alles wird im Code gebaut, damit sich das
## Layout leicht anpassen laesst.

const ARENA_SIZE := Vector2(3200.0, 1350.0)
const FLOOR_Y := 1250.0
## Schacht rechts: Bereich des Aufwinds und seine Steiggeschwindigkeit.
const SHAFT_LIFT := Rect2(2645.0, 610.0, 190.0, 640.0)
const SHAFT_LIFT_SPEED := 560.0
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
const CLEAR_DELAY := 3.6
## Einstieg in eine Welle: Titel und Countdown, die Gegner kommen erst danach.
const WAVE_INTRO := 3.2
const HEALTH_DROP_CHANCE := 0.07
const HEALTH_DROP_HEAL := 0.25

enum Phase { WAVE, CLEARING, SHOP, BOSS, VICTORY }

## Tests koennen diese Werte vor dem Einhaengen der Szene setzen.
var use_dummies := false
var director_enabled := true
## Wellenstart-Animation mit Countdown (Tests schalten sie ab).
var intro_enabled := true
## Wenn gesetzt, starten die Spieler mit allen Testwaffen und Modulen.
## Sonst nur mit der Klassenwaffe, der Rest kommt aus dem Shop. F3 gibt das Testset.
var test_loadout := false
## Wellen: Dauer in Sekunden und Anzahl bis zum Sieg.
var wave_duration := 120.0
var max_waves := 10
## Nach der letzten Welle folgt der Endboss. Ohne Boss endet der Lauf mit dem Sieg.
var boss_enabled := true
## Aufwind im Schacht (Tests schalten ihn ab, wenn sie Wandmechanik dort pruefen).
var shaft_lift := true
## Sandbox-Lauf: keine Chips, Einstellung aus dem Titelbildschirm.
var sandbox := false

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
var contract_menu: ContractMenu
## Vertragswahl vor jeder Welle ab Welle 2 (nur mit Wellen-Einstieg, damit alte Tests unveraendert laufen).
var contracts_enabled := true
## Gold-Praemie des gewaehlten Vertrags in dieser Welle (0 = kein riskanter Vertrag gewaehlt).
var contract_bonus := 0.0
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
## Karte: "" = Zufallsreihenfolge pro Lauf (alle drei Wellen eine neue), eine Id aus Stages.IDS oder
## "classic" fuer die alte flache Halle (Tests). arena_size ist die Groesse der aktuellen Welt.
var stage_id := ""
var stage_layout: Dictionary = {}
var arena_size := ARENA_SIZE
var stage_banner_time := 0.0
var _stage_order: Array = []
const TETHER := Vector2(3000.0, 1500.0)
var gates: GateOverlay
## Waechter: Mini-Boss in der letzten Welle jeder Karte (Welle 3, 6, 9), mit Belohnung bei Sieg.
var guardian: Enemy = null
var guardian_enabled := true
var guardian_banner_time := 0.0
var _guardian_spawned := false
## Verlaengerung: Ist die Wellenzeit um, aber der Waechter lebt noch, geht der Kampf weiter (ohne neue Gegner, hoechstens 90 s).
var overtime := 0.0
const OVERTIME_MAX := 90.0
## Kisten auf der Karte (Gold gegen Item): Behaelter, Schalter und Zaehler der geoeffneten Kisten auf dieser Karte.
var chests: Node2D
var chests_enabled := true
var chests_opened := 0
## Wahrscheinlichkeit, dass der Gluecksaltar ein Item gibt (Tests koennen den Wurf festlegen).
const CHANCE_ODDS := 0.55
var chance_roll_override := -1.0
var _large_chest_placed := false
var wave_intro := 0.0
## Gewaehlte Team-Perks (id -> Anzahl) und das Banner nach der Wahl.
var perks_taken := {}
var perk_banner_id := ""
var perk_banner_time := 0.0
var wave_go := 0.0
## Beim Wellenende: besiegte Gegner der Welle und Bonus-Gold, fuer die Anzeige.
var wave_kills := 0
var wave_bonus := 0
var _wave_kills_start := 0
var _intro_beat := 0


func _ready() -> void:
	RenderingServer.set_default_clear_color(BG_COLOR)
	_read_sandbox_early()
	_pick_stage(wave)
	_build_arena()
	projectiles = Node2D.new()
	add_child(projectiles)
	enemy_projectiles = Node2D.new()
	add_child(enemy_projectiles)
	pickups = Node2D.new()
	add_child(pickups)
	chests = Node2D.new()
	add_child(chests)
	fx = Fx.new()
	fx.floor_y = _ground_fallback()
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
	contract_menu = ContractMenu.new()
	contract_menu.chosen.connect(_on_contract_chosen)
	add_child(contract_menu)
	gates = GateOverlay.new()
	add_child(gates)
	add_child(Vignette.new())
	hud = Hud.new()
	hud.main = self
	add_child(hud)
	pause_menu = PauseMenu.new()
	pause_menu.main = self
	add_child(pause_menu)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_apply_sandbox()
	_begin_wave_intro()
	_refresh_chests()
	if not stage_layout.is_empty() and intro_enabled:
		stage_banner_time = 3.2


func _physics_process(delta: float) -> void:
	wave_banner_time = maxf(0.0, wave_banner_time - delta)
	wave_go = maxf(0.0, wave_go - delta)
	perk_banner_time = maxf(0.0, perk_banner_time - delta)
	stage_banner_time = maxf(0.0, stage_banner_time - delta)
	_apply_tether()
	Music.set_layer_level(1.0 if phase == Phase.BOSS else clampf(0.2 + 0.08 * float(wave), 0.2, 0.9))
	_check_level_up()
	_update_wave(delta)
	_apply_shaft_lift(delta)
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


func _begin_wave_intro() -> void:
	_wave_kills_start = kills
	if not director_enabled or not intro_enabled:
		return
	wave_intro = WAVE_INTRO
	_intro_beat = 4
	director.enabled = false


func _update_intro(delta: float) -> void:
	wave_intro = maxf(0.0, wave_intro - delta)
	# Countdown 3, 2, 1 in den letzten drei Sekunden, dann LOS.
	var beat := int(ceil(wave_intro)) if wave_intro > 0.0 else 0
	if beat != _intro_beat and beat <= 3:
		_intro_beat = beat
		if beat > 0:
			Sfx.play("switch")
		else:
			Sfx.play("ability")
			camera.add_shake(6.0)
			if Fx.instance:
				for player in players:
					Fx.instance.ring(player.global_position, 120.0, Color(1.0, 0.9, 0.5))
	if wave_intro <= 0.0:
		director.enabled = director_enabled
		wave_go = 0.7


func _update_wave(delta: float) -> void:
	guardian_banner_time = maxf(0.0, guardian_banner_time - delta)
	match phase:
		Phase.WAVE:
			if not director_enabled or game_over:
				return
			if wave_intro > 0.0:
				_update_intro(delta)
				return
			_update_guardian()
			wave_time_left -= delta
			director.wave_progress = 1.0 - maxf(wave_time_left, 0.0) / wave_duration
			if wave_time_left <= 0.0:
				if guardian != null and is_instance_valid(guardian) and overtime < OVERTIME_MAX:
					if overtime == 0.0:
						director.enabled = false
						Sfx.play("telegraph")
					wave_time_left = 0.0
					overtime += delta
				else:
					_end_wave()
		Phase.CLEARING:
			_clear_time -= delta
			if _clear_time <= 0.0 and not game_over and not levelup_menu.is_open:
				if intro_enabled and not (wave >= max_waves and not boss_enabled):
					# Erst schliessen sich die Metalltore (laeuft weiter, auch wenn ein Level-Up dazwischenkommt),
					# dann oeffnet sich der Shop dahinter.
					if gates.is_closed:
						_open_shop()
					else:
						gates.close()
				else:
					_open_shop()


## Letzte Welle einer Karte (3, 6, 9): nach etwas Anlauf erscheint ein Waechter.
func is_guardian_wave() -> bool:
	return guardian_enabled and not stage_layout.is_empty() and wave % Stages.WAVES_PER_STAGE == 0 and wave < max_waves


func _update_guardian() -> void:
	if _guardian_spawned or not is_guardian_wave() or director.wave_progress < 0.35:
		return
	_guardian_spawned = true
	guardian = director.spawn("brute", null, true, "", true)
	guardian_banner_time = 3.4
	camera.add_shake(9.0)
	Sfx.play("levelup")
	if Fx.instance:
		Fx.instance.ring(guardian.global_position, 240.0, Color(1.0, 0.4, 0.3))


## Sieg ueber den Waechter: eine gratis Goldkiste an seiner Stelle, Reparatur fuer beide und Beute.
func _guardian_defeated(pos: Vector2, radius: float) -> void:
	guardian = null
	if phase != Phase.WAVE:
		return
	var ground := GroundProbe.ground_y(self, pos, pos + Vector2(0.0, radius + 120.0))
	var spot := Vector2(pos.x, ground if ground != INF else pos.y + radius)
	var chest := Chest.new()
	chest.players = players
	chest.large = true
	chest.bounty = true
	chest.price = 0
	chest.position = spot
	chest.opened.connect(_on_chest_opened)
	chests.add_child(chest)
	for player in players:
		if player.downed:
			player.revive(0.5)
		else:
			player.hp = minf(player.max_health(), player.hp + player.max_health() * 0.4)
		if Fx.instance:
			Fx.instance.number_text(player.global_position + Vector2(0.0, -float(player.stats.size.y) * 0.5 - 40.0), "Wächter besiegt", Color(1.0, 0.85, 0.4), 24)
	for i in 10:
		_spawn_pickup("gold", 1 + int(director.difficulty() * 1.1), pos)
	hitstop(0.14)
	camera.add_shake(14.0)
	Sfx.play("levelup")


func _end_wave() -> void:
	phase = Phase.CLEARING
	_clear_time = CLEAR_DELAY
	director.enabled = false
	Sfx.play("levelup")
	wave_kills = kills - _wave_kills_start
	# Bonus fuer die geschaffte Welle, fuer jeden Spieler.
	wave_bonus = 4 + 2 * wave
	for player in players:
		player.gold += wave_bonus
	# Nicht abgeholte Waechterbeute geht an den naechsten Spieler.
	for chest in chests.get_children():
		if chest is Chest and chest.bounty and not chest.is_open:
			var nearest: Player = players[0]
			for player in players:
				if player.global_position.distance_to(chest.global_position) < nearest.global_position.distance_to(chest.global_position):
					nearest = player
			chest.force_open(nearest)
	camera.add_shake(10.0)
	hitstop(0.12)
	if hud != null:
		hud.flash(Color(1.0, 1.0, 0.85, 0.35))
	if Fx.instance:
		for player in players:
			Fx.instance.ring(player.global_position, 260.0, Color(1.0, 0.9, 0.4))
			Fx.instance.spark(player.global_position, Color(1.0, 0.9, 0.4), 18, 420.0)
	# Restliche Gegner zerfallen und lassen ihre Beute fallen, die zu den Spielern fliegt.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy:
			enemy.take_damage(1.0e9, null, Vector2.ZERO, "", true)
	for bullet in enemy_projectiles.get_children():
		bullet.queue_free()
	for pickup in pickups.get_children():
		if pickup is Pickup:
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
		if gates != null and gates.is_closed:
			gates.open()
		_start_boss()
		return
	wave += 1
	wave_time_left = wave_duration
	if stage_id != "classic" and (wave - 1) % Stages.WAVES_PER_STAGE == 0:
		# Hinter den geschlossenen Toren: neue Karte aufbauen.
		_change_stage()
	if contracts_enabled and intro_enabled and wave >= 2 and wave < max_waves:
		# Vertragswahl: erst entscheiden, dann oeffnen sich die Tore.
		contract_menu.open_contracts(players, WaveModifiers.offers(wave_modifier), wave)
		return
	_begin_new_wave("")


func _on_contract_chosen(contract_id: String) -> void:
	_begin_new_wave(contract_id)


## Die neue Welle beginnt: Tore auf, Modifikator (gewaehlt oder zufaellig), Gegner, Kisten.
func _begin_new_wave(contract_id: String) -> void:
	if gates != null and gates.is_closed:
		gates.open()
	_apply_modifier(contract_id)
	phase = Phase.WAVE
	director.enabled = director_enabled
	_guardian_spawned = false
	guardian = null
	overtime = 0.0
	_begin_wave_intro()
	_refresh_chests()


## Endkampf: Die Arena wird zur Ofenhalle mit Laufband, der Boss tritt auf.
func _start_boss() -> void:
	phase = Phase.BOSS
	director.enabled = false
	_clear_chests()
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
	_update_camera_limits()
	fx.floor_y = FLOOR_Y
	director.stage = {}
	camera.bias = Vector2(350.0, -80.0)
	camera.max_zoom = 1.0
	camera.global_position = (players[0].global_position + players[1].global_position) * 0.5 + camera.bias
	Sfx.play("levelup")


## Verbucht den Lauf einmal im Spielstand (Chips, Bestwerte).
func _record_run(victory: bool) -> void:
	if run_recorded:
		return
	run_recorded = true
	if sandbox:
		return
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


func _apply_modifier(forced := "") -> void:
	wave_modifier = forced if forced != "" else WaveModifiers.pick(wave, max_waves, wave_modifier)
	# Die Praemie gibt es nur, wenn man den Vertrag selbst gewaehlt hat.
	contract_bonus = float(WaveModifiers.DATA[wave_modifier].get("bonus", 0.0)) if forced != "" else 0.0
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


## Sandbox: Karte und Startwelle muessen vor dem Aufbau der Welt feststehen.
func _read_sandbox_early() -> void:
	var config: Dictionary = Engine.get_meta("sandbox", {})
	if config.is_empty():
		return
	var chosen := String(config.get("stage", "random"))
	if chosen != "random":
		stage_id = chosen
	if int(config.wave) < SandboxConfig.BOSS_WAVE:
		wave = int(config.wave)


## Waehlt die Karte fuer die Welle (leeres Layout = alte flache Halle).
func _pick_stage(wave_number: int) -> void:
	if stage_id == "classic":
		stage_layout = {}
		arena_size = ARENA_SIZE
		return
	if _stage_order.is_empty():
		_stage_order = Stages.random_order() if stage_id == "" else [stage_id]
	stage_layout = Stages.build(Stages.id_for_wave(wave_number, _stage_order), randf() < 0.5)
	arena_size = stage_layout.size


## Hoehe, ab der Beute und Truemmer ohne echten Boden liegen bleiben.
func _ground_fallback() -> float:
	return arena_size.y if not stage_layout.is_empty() else FLOOR_Y


## Neue Karte (alle drei Wellen): Welt neu bauen, Spieler an den Start, Beute und Geschosse weg.
func _change_stage() -> void:
	for bullet in enemy_projectiles.get_children():
		bullet.queue_free()
	for bullet in projectiles.get_children():
		bullet.queue_free()
	for pickup in pickups.get_children():
		pickup.queue_free()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy:
			enemy.queue_free()
	_clear_chests()
	_clear_arena()
	_pick_stage(wave)
	_build_arena()
	for i in players.size():
		_place_at_start(players[i], i)
		players[i].velocity = Vector2.ZERO
	_update_camera_limits()
	director.stage = stage_layout
	fx.floor_y = _ground_fallback()
	stage_banner_time = 3.2
	camera.global_position = (players[0].global_position + players[1].global_position) * 0.5


func _place_at_start(player: Player, index: int) -> void:
	var half: float = float(player.stats.size.y) * 0.5
	if stage_layout.is_empty():
		player.teleport(Vector2(300.0 + index * 110.0, FLOOR_Y - half - 2.0))
	else:
		var start: Vector2 = stage_layout.starts[index]
		player.teleport(Vector2(start.x, start.y - half - 2.0))


func _update_camera_limits() -> void:
	camera.limit_right = int(arena_size.x)
	camera.limit_bottom = int(arena_size.y)


## Die Kamera muss beide Spieler im Bild halten: Wer sich zu weit vom Partner entfernt, kommt nicht weiter weg.
func _apply_tether() -> void:
	if players.size() < 2:
		return
	for i in 2:
		var player := players[i]
		var other := players[1 - i]
		var offset := player.global_position - other.global_position
		if absf(offset.x) > TETHER.x:
			player.global_position.x = other.global_position.x + signf(offset.x) * TETHER.x
			if signf(player.velocity.x) == signf(offset.x):
				player.velocity.x = 0.0
		if absf(offset.y) > TETHER.y:
			player.global_position.y = other.global_position.y + signf(offset.y) * TETHER.y
			if signf(player.velocity.y) == signf(offset.y):
				player.velocity.y = 0.0


## Wendet die Sandbox-Einstellung (Engine-Meta "sandbox") auf Spieler und Startwelle an.
func _apply_sandbox() -> void:
	var config: Dictionary = Engine.get_meta("sandbox", {})
	if config.is_empty():
		return
	sandbox = true
	for i in players.size():
		var player := players[i]
		var data: Dictionary = config.players[i]
		player.weapons.clear()
		player.modules.clear()
		for j in data.weapons.size():
			player.weapons.append(data.weapons[j])
			player.modules.append(data.modules[j])
		player.weapon_index = 0
		for id in data.firmware:
			for k in int(data.firmware[id]):
				player.add_firmware(id)
		for id in data.perks:
			for k in int(data.perks[id]):
				# Als persoenliche Items, damit sie unter dem Spielerpanel stehen.
				player.add_item(id)
		player.gold = int(config.gold)
		player.invulnerable = bool(config.god)
		player.hp = player.max_health()
		player.dash_charges = player.dash_max()
	if int(config.wave) >= SandboxConfig.BOSS_WAVE:
		wave = max_waves
		_start_boss.call_deferred()
	else:
		wave = int(config.wave)
		wave_time_left = wave_duration
		_apply_modifier()


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
		_place_at_start(player, i)
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
	if amount >= 15.0:
		hitstop(0.06)
	# Der Treffer ist am getroffenen Roboter zu sehen (roter Ring, Zahl, Aufblitzen), nicht auf dem ganzen Bild.
	Fx.instance.spark(player.global_position, Color(1.0, 0.4, 0.3), 10, 400.0)
	Fx.instance.ring(player.global_position, 70.0, Color(1.0, 0.25, 0.2))
	Fx.instance.number(player.global_position + Vector2(0.0, -float(player.stats.size.y) * 0.5 - 24.0), amount, Color(1.0, 0.3, 0.25), 32)


func _on_slam_landed(player: Player, pos: Vector2) -> void:
	_explode(pos, 150.0, 35.0 * player.damage_mult(), player, Color(0.9, 0.9, 1.0))
	camera.add_shake(14.0)
	hitstop(0.05)
	if Fx.instance:
		Fx.instance.ring(pos, 190.0, Color(0.9, 0.93, 1.0))
		Fx.instance.spark(pos, Color(0.8, 0.82, 0.88, 0.8), 14, 280.0)


func _on_player_down(_player: Player) -> void:
	# Waehrend der Sterbeanimation des Bosses ist der Kampf gewonnen.
	if boss != null and is_instance_valid(boss) and boss.dying:
		return
	for player in players:
		if not player.downed:
			return
	game_over = true
	_game_over_time = 0.0
	if gates != null:
		gates.reset()
	_record_run(false)
	Sfx.play("kill")


func _setup_director() -> void:
	director = Director.new()
	director.enabled = director_enabled
	director.arena_size = arena_size
	director.floor_y = FLOOR_Y
	director.stage = stage_layout
	director.players = players
	director.parent_node = self
	director.enemy_spawned.connect(_on_enemy_spawned)
	director.projectile_requested.connect(_on_enemy_projectile_requested)
	director.strike_requested.connect(_on_strike_requested)
	add_child(director)


func _on_enemy_spawned(enemy: Enemy) -> void:
	enemy.died.connect(_on_enemy_died)


func _on_enemy_died(enemy: Enemy) -> void:
	if enemy.suicide:
		# Selbstgesprengt: keine Beute und kein Kill, die Gefahr ist vorbei.
		return
	kills += 1
	var info: Dictionary = enemy.data
	_spawn_pickup("xp", int(info.xp) * (3 if enemy.elite else 1), enemy.global_position)
	var gold_value := 1 + int(director.difficulty() * 1.1)
	var coins := int(float(info.gold_chance)) + (1 if randf() < fmod(float(info.gold_chance), 1.0) else 0)
	if enemy.elite:
		coins += 3
	coins = int(round(float(coins) * float(WaveModifiers.DATA[wave_modifier].get("gold", 1.0)) * (1.0 + contract_bonus)))
	for i in coins:
		_spawn_pickup("gold", gold_value, enemy.global_position)
	for player in players:
		if not player.downed and float(player.mods.kill_heal) > 0.0:
			player.hp = minf(player.max_health(), player.hp + float(player.mods.kill_heal))
	for player in players:
		player.ability.reduce_cooldown(float(player.stats.get("kill_cooldown", 0.0)) + Perks.RECYCLE_SECONDS * float(player.mods.recycle))
		player.register_kill()
	_spawn_scrap(enemy)
	var blast := 0.0
	for player in players:
		blast = maxf(blast, float(player.mods.death_blast))
	if blast > 0.0:
		_death_blast(enemy.global_position, blast)
	if enemy.elite or randf() < HEALTH_DROP_CHANCE:
		_spawn_pickup("hp", 1, enemy.global_position)
	if enemy.champion:
		_guardian_defeated(enemy.global_position, enemy.radius())
	elif enemy.elite:
		hitstop(0.09)
		camera.add_shake(12.0)


# ---------------------------------------------------------------- Kisten

func _clear_chests() -> void:
	for chest in chests.get_children():
		# Sofort aus dem Baum nehmen, damit ein gleichzeitiges _refresh_chests sie nicht mehr zaehlt.
		chests.remove_child(chest)
		chest.queue_free()
	chests_opened = 0
	_large_chest_placed = false


func chest_price(large := false) -> int:
	# Steigt etwas schneller als linear, weil die Einnahmen mit der Welle ebenfalls anziehen (Beute wird mit der Schwierigkeit mehr wert).
	var base := (12.0 + 5.0 * float(wave)) * (1.0 + 0.06 * float(wave)) * (1.0 + 0.1 * float(chests_opened)) * (2.4 if large else 1.0)
	return int(round(base))


func _update_chest_prices() -> void:
	for chest in chests.get_children():
		if chest is Altar:
			# Gluecksaltar: halber Kistenpreis, jede Nutzung macht ihn teurer.
			chest.price = int(round(float(chest_price(false)) * 0.5 * pow(1.4, float(Altar.MAX_USES - chest.uses_left))))
		elif chest is Chest and not chest.is_open and not chest.bounty:
			chest.price = chest_price(chest.large)


## Haelt die Karte mit Kisten bestueckt: zwei bis vier ungeoeffnete, dazu einmal pro Karte eine grosse Goldkiste.
## Nur auf den grossen Karten, in der flachen Testhalle und im Bosskampf gibt es keine.
func _refresh_chests() -> void:
	if not chests_enabled or stage_layout.is_empty() or phase == Phase.BOSS or stage_layout.ground.is_empty():
		return
	_update_chest_prices()
	var live: Array[Vector2] = []
	var normal := 0
	var altar_kinds: Array[String] = []
	for chest in chests.get_children():
		if chest is Altar:
			if not chest.is_open:
				live.append(chest.position)
				altar_kinds.append(chest.kind)
		elif chest is Chest and not chest.is_open and not chest.bounty:
			live.append(chest.position)
			if not chest.large:
				normal += 1
	if not _large_chest_placed:
		var spot := _chest_spot(live, true)
		if spot != Vector2.INF:
			_add_chest(spot, true)
			live.append(spot)
			_large_chest_placed = true
	var target := mini(4, 2 + (wave - 1) / 2)
	var tries := 0
	while normal < target and tries < 12:
		tries += 1
		var spot := _chest_spot(live, false)
		if spot == Vector2.INF:
			continue
		_add_chest(spot, false)
		live.append(spot)
		normal += 1
	# Altaere: einer pro Karte, ab Welle 4 zwei verschiedene.
	var altar_target := 1 if wave < 4 else 2
	tries = 0
	while altar_kinds.size() < altar_target and tries < 12:
		tries += 1
		var spot := _chest_spot(live, false)
		if spot == Vector2.INF:
			continue
		var kind := "chance" if altar_kinds.has("blood") else ("blood" if altar_kinds.has("chance") else ("blood" if randf() < 0.5 else "chance"))
		_add_altar(spot, kind)
		live.append(spot)
		altar_kinds.append(kind)


## Ort fuer eine Kiste auf einer begehbaren Flaeche: weit weg von den Spielern und anderen Kisten.
## Die grosse Kiste kommt an den entlegensten, hoechsten Punkt der Karte (Belohnung fuers Erkunden).
func _chest_spot(taken: Array[Vector2], large: bool) -> Vector2:
	var ground: Array = stage_layout.ground
	# Erst mit grossem Abstand suchen, wird es eng (viele Kisten und Altaere), mit kleinerem.
	for spacing in [900.0, 650.0, 450.0, 300.0]:
		var best := Vector2.INF
		var best_score := -INF
		for k in 40:
			var point: Vector2 = ground[randi() % ground.size()]
			var ok := true
			for other in taken:
				if other.distance_to(point) < spacing:
					ok = false
			for player in players:
				if player.global_position.distance_to(point) < 600.0:
					ok = false
			for start: Vector2 in stage_layout.starts:
				if start.distance_to(point) < 500.0:
					ok = false
			if not ok:
				continue
			var score := randf() * 300.0
			if large:
				var start_distance := 0.0
				for start: Vector2 in stage_layout.starts:
					start_distance = maxf(start_distance, start.distance_to(point))
				score += start_distance + (arena_size.y - point.y) * 0.6
			if score > best_score:
				best_score = score
				best = point
		if best != Vector2.INF:
			return best
	return Vector2.INF


func _add_chest(pos: Vector2, large: bool) -> void:
	var chest := Chest.new()
	chest.players = players
	chest.large = large
	chest.price = chest_price(large)
	chest.position = pos
	chest.opened.connect(_on_chest_opened)
	chests.add_child(chest)


func _add_altar(pos: Vector2, kind: String) -> void:
	var altar := Altar.new()
	altar.players = players
	altar.kind = kind
	altar.price = int(round(float(chest_price(false)) * 0.5))
	altar.position = pos
	altar.opened.connect(_on_chest_opened)
	chests.add_child(altar)


## Altar benutzt: Blut gibt Gold, Glueck gibt mit Chance ein Item.
func _on_altar_used(altar: Altar, player: Player) -> void:
	var at := altar.global_position + Vector2(0.0, -130.0)
	if altar.kind == "blood":
		var gold := 16 + 6 * wave
		player.gold += gold
		player.gold_flash()
		Sfx.play("coin")
		if Fx.instance:
			Fx.instance.ring(player.global_position, 130.0, Color(1.0, 0.3, 0.35))
			Fx.instance.spark(player.global_position, Color(0.9, 0.15, 0.2), 14, 320.0)
			Fx.instance.number_text(at, "+%d Gold" % gold, Color(1.0, 0.85, 0.3), 28, 2.4)
			Fx.instance.number_text(at + Vector2(0.0, 24.0), "Blutzoll", Color(1.0, 0.45, 0.5), 17, 2.4)
		camera.add_shake(4.0)
	else:
		var roll := chance_roll_override if chance_roll_override >= 0.0 else randf()
		if roll < CHANCE_ODDS:
			_grant_item(player, altar.global_position, Perks.RARE_IDS if randf() < 0.25 else Perks.DATA.keys(), 3.2)
		else:
			Sfx.play("hurt", 0.05)
			if Fx.instance:
				Fx.instance.number_text(at, "Niete", Color(0.7, 0.7, 0.78), 26, 2.0)
				Fx.instance.spark(altar.global_position + Vector2(0.0, -56.0), Color(0.6, 0.55, 0.7), 8, 200.0)
	_update_chest_prices()


## Zufaelliges Item aus dem Pool fuer den Spieler, mit Symbol, Name und Wirkung.
func _grant_item(player: Player, from: Vector2, pool: Array, life: float) -> void:
	# Moeglichst etwas, das der Spieler noch nicht hat.
	var options: Array = pool.filter(func(id: String) -> bool: return int(player.items.get(id, 0)) == 0)
	if options.is_empty():
		options = pool
	var id: String = options[randi() % options.size()]
	player.add_item(id)
	var color := PerkArt.color_of(id)
	var at := from + Vector2(0.0, -118.0)
	if Fx.instance:
		Fx.instance.ring(from + Vector2(0.0, -20.0), 130.0, color)
		Fx.instance.spark(from + Vector2(0.0, -30.0), color, 16, 420.0)
		Fx.instance.perk_icon(at + Vector2(0.0, -46.0), id)
		Fx.instance.number_text(at, String(Perks.DATA[id].name), color, 30, life)
		Fx.instance.number_text(at + Vector2(0.0, 26.0), Perks.describe(id, player.class_id), Color(0.92, 0.94, 1.0), 17, life)
	Sfx.play("levelup")


func _on_chest_opened(chest: Chest, player: Player) -> void:
	if chest is Altar:
		_on_altar_used(chest, player)
		return
	if not chest.bounty:
		chests_opened += 1
	var pool: Array = Perks.RARE_IDS if chest.large else Perks.DATA.keys()
	_grant_item(player, chest.global_position, pool, 3.2)
	camera.add_shake(7.0 if chest.large else 4.0)
	Sfx.play("levelup")
	_update_chest_prices()


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


const MAX_SCRAP := 22
## Schrott pro Gegnertyp (Brute und Elite lassen mehr fallen).
const SCRAP_DROPS := {"walker": 0.5, "shooter": 0.6, "flyer": 0.5, "charger": 1.2, "mortar": 1.2, "brute": 3.0}


## Zerstoerte Gegner lassen Schrott fallen, den nur der Roomba aufsaugt. Ohne Roomba gibt es keinen.
func _spawn_scrap(enemy: Enemy) -> void:
	var has_vacuum := false
	for player in players:
		if bool(player.stats.get("vacuum", false)):
			has_vacuum = true
	if not has_vacuum or not enemy.on_screen:
		return
	var amount: float = float(SCRAP_DROPS.get(enemy.kind, 0.5)) * (3.0 if enemy.elite else 1.0)
	var count := int(amount) + (1 if randf() < fmod(amount, 1.0) else 0)
	for i in count:
		var existing := get_tree().get_nodes_in_group("scrap")
		if existing.size() >= MAX_SCRAP:
			existing[0].queue_free()
		var scrap := Scrap.new()
		scrap.players = players
		scrap.floor_y = _ground_fallback()
		scrap.tint = Color(enemy.data.color).darkened(0.2)
		scrap.position = enemy.global_position + Vector2(randf_range(-10.0, 10.0), 0.0)
		scrap.collected.connect(_on_scrap_collected)
		pickups.add_child(scrap)


func _on_scrap_collected(_scrap: Scrap, player: Player) -> void:
	xp += maxi(1, int(round(Meta.xp_multiplier())))
	player.hp = minf(player.max_health(), player.hp + 1.0)
	player.ability.reduce_cooldown(0.4)
	player.gold_flash()
	Sfx.play("scrap", 0.05)
	if Fx.instance:
		Fx.instance.spark(player.global_position + Vector2(float(player.facing) * 24.0, 8.0), Color(0.6, 1.0, 0.9), 3, 120.0)


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
	pickup.floor_y = _ground_fallback()
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


## Aufwind im Schacht rechts: Spieler im Schacht werden nach oben getragen (zur Plattform oben).
func _apply_shaft_lift(_delta: float) -> void:
	if phase == Phase.BOSS or not shaft_lift or not stage_layout.is_empty():
		return
	for player in players:
		if player.downed:
			continue
		var p := player.global_position
		if p.x > SHAFT_LIFT.position.x and p.x < SHAFT_LIFT.end.x and p.y > SHAFT_LIFT.position.y and p.y < SHAFT_LIFT.end.y:
			player.velocity.y = minf(player.velocity.y, -SHAFT_LIFT_SPEED)
			if Fx.instance and randf() < 0.15:
				Fx.instance.spark(p + Vector2(randf_range(-30.0, 30.0), 40.0), Color(0.3, 0.9, 0.6, 0.7), 1, 90.0)


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
	perks_taken[perk_id] = int(perks_taken.get(perk_id, 0)) + 1
	perk_banner_id = perk_id
	perk_banner_time = 3.0
	# Rueckmeldung am Roboter: Ring, Funken und was der Perk fuer genau diese Klasse bewirkt.
	var color := PerkArt.color_of(perk_id)
	for player in players:
		if Fx.instance:
			Fx.instance.ring(player.global_position, 150.0, color)
			Fx.instance.spark(player.global_position, color, 16, 380.0)
			Fx.instance.number_text(player.global_position + Vector2(0.0, -float(player.stats.size.y) * 0.5 - 40.0), Perks.describe(perk_id, player.class_id), color, 24)
	camera.add_shake(6.0)
	Sfx.play("revive")


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
		# Sofort aus dem Baum nehmen: bliebe die alte Welt bis zum Frameende in der Physik, schiebt sie Spieler,
		# die gerade an den neuen Start gesetzt wurden, aus dem Boden hinaus.
		remove_child(_arena_root)
		_arena_root.queue_free()
		_arena_root = null


func _build_arena(boss_mode := false) -> void:
	_arena_root = Node2D.new()
	add_child(_arena_root)
	move_child(_arena_root, 0)
	if boss_mode:
		arena_size = ARENA_SIZE
		stage_layout = {}
		_build_boss_layout()
	elif stage_layout.is_empty():
		_build_wave_layout()
	else:
		StageBuilder.build(_arena_root, stage_layout, randi())
	if boss_mode or stage_layout.is_empty():
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
		Rect2(1000.0, 1020.0, 1100.0, 24.0),
		# Trittplatten, damit die hohe Mittelplattform vom Boden aus erreichbar bleibt.
		Rect2(840.0, 1140.0, 130.0, 24.0),
		Rect2(2130.0, 1140.0, 130.0, 24.0),
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
	# Unten bleibt ein Durchgang (130 px), damit man durch den Schacht auf die andere Seite kommt.
	_add_block(Rect2(2600.0, 600.0, 40.0, 520.0), "wall")
	_add_block(Rect2(2840.0, 600.0, 40.0, 520.0), "wall")
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
	camera.limit_right = int(arena_size.x)
	camera.limit_bottom = int(arena_size.y)
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
		var spread := float(weapon.spread) + float(weapon.get("spread_heat", 0.0)) * player.heat_level()
		bullet.direction = direction.rotated(randf_range(-spread, spread))
		bullet.speed = float(weapon.speed) * randf_range(0.9, 1.0) if weapon.pellets > 1 else float(weapon.speed)
		bullet.homing = float(weapon.get("homing", 0.0))
		bullet.accel = float(weapon.get("accel", 0.0))
		bullet.speed_max = float(weapon.get("speed_max", 0.0))
		bullet.push = float(weapon.get("push", 1.0))
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
	bullet.damage = 4.0 * player.damage_mult()
	bullet.lifetime = 1.0
	bullet.size = 4.0
	bullet.color = Color(1.0, 0.65, 0.25)
	var element := player.current_module()
	if element != "":
		bullet.element = element
		bullet.color = Elements.COLORS[element]
	bullet.shooter = player
	bullet.explosion_radius = 50.0
	bullet.explosion_damage = 6.0 * player.damage_mult()
	bullet.hit.connect(_on_projectile_hit)
	projectiles.add_child(bullet)


func _fire_hitscan(player: Player, weapon: Dictionary, origin: Vector2, direction: Vector2, damage: float, element: String, color: Color) -> void:
	var space := get_world_2d().direct_space_state
	var target := origin + direction * float(weapon.range)
	var end := target
	var exclude: Array[RID] = []
	var hits_left := int(weapon.pierce) + int(player.mods.pierce) + 1
	# Dauerstrahl: je laenger gehalten, desto mehr Schaden.
	if weapon.has("ramp_max"):
		damage *= lerpf(1.0, float(weapon.ramp_max), player.channel_ratio())
	var push := float(weapon.get("push", 1.0))
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
			collider.take_damage(damage, player, direction * push, element)
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


