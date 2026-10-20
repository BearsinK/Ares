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
const RESTART_DELAY := 1.0
const CLEAR_DELAY := 3.0

enum Phase { WAVE, CLEARING, SHOP, VICTORY }

## Tests koennen diese Werte vor dem Einhaengen der Szene setzen.
var use_dummies := false
var director_enabled := true
## Wenn gesetzt, starten die Spieler mit allen Testwaffen und Modulen.
## Sonst nur mit der Klassenwaffe, der Rest kommt aus dem Shop. F3 gibt das Testset.
var test_loadout := false
## Wellen: Dauer in Sekunden und Anzahl bis zum Sieg.
var wave_duration := 120.0
var max_waves := 10

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
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _physics_process(delta: float) -> void:
	_check_level_up()
	_update_wave(delta)
	for entry in _respawns:
		entry.t -= delta
		if entry.t <= 0.0:
			_spawn_dummy(entry.pos)
	_respawns = _respawns.filter(func(entry: Dictionary) -> bool: return entry.t > 0.0)

	if game_over or phase == Phase.VICTORY:
		_game_over_time += delta
		if _game_over_time >= RESTART_DELAY and _any_restart_pressed():
			get_tree().reload_current_scene()


func _any_restart_pressed() -> bool:
	for i in [1, 2]:
		for action in ["confirm", "jump", "fire"]:
			if Input.is_action_just_pressed("p%d_%s" % [i, action]):
				return true
	return false


func _input(event: InputEvent) -> void:
	# Diagnose: zeigt im HUD, welcher Controller-Input zuletzt ankam.
	if event is InputEventJoypadButton and event.pressed:
		last_pad_event = "Controller %d Taste %d" % [event.device, event.button_index]
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		last_pad_event = "Controller %d Achse %d (%.1f)" % [event.device, event.axis, event.axis_value]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
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
			if wave_time_left <= 0.0:
				_end_wave()
		Phase.CLEARING:
			_clear_time -= delta
			if _clear_time <= 0.0 and not game_over:
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
	if wave >= max_waves:
		phase = Phase.VICTORY
		_game_over_time = 0.0
		return
	phase = Phase.SHOP
	shop_menu.open(players, wave)


func _on_shop_closed() -> void:
	wave += 1
	wave_time_left = wave_duration
	phase = Phase.WAVE
	director.enabled = director_enabled


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
		player.slam_landed.connect(_on_slam_landed)
		add_child(player)
		players.append(player)
	players[0].partner = players[1]
	players[1].partner = players[0]


func _on_slam_landed(player: Player, pos: Vector2) -> void:
	_explode(pos, 150.0, 35.0 * player.damage_mult(), player, Color(0.9, 0.9, 1.0))


func _on_player_down(_player: Player) -> void:
	for player in players:
		if not player.downed:
			return
	game_over = true
	_game_over_time = 0.0
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
	add_child(director)


func _on_enemy_spawned(enemy: Enemy) -> void:
	enemy.died.connect(_on_enemy_died)


func _on_enemy_died(enemy: Enemy) -> void:
	kills += 1
	var info: Dictionary = enemy.data
	_spawn_pickup("xp", int(info.xp), enemy.global_position)
	var gold_value := 1 + int(director.time / 90.0)
	var coins := int(float(info.gold_chance)) + (1 if randf() < fmod(float(info.gold_chance), 1.0) else 0)
	for i in coins:
		_spawn_pickup("gold", gold_value, enemy.global_position)


func _spawn_pickup(kind: String, value: int, pos: Vector2) -> void:
	if pickups.get_child_count() > 150:
		# Zu viele Objekte: Wert direkt gutschreiben statt ein weiteres zu erzeugen.
		if kind == "xp":
			xp += value
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
		xp += pickup.value
		Sfx.play("pickup")
	else:
		player.gold += maxi(1, int(round(pickup.value * (1.0 + float(player.mods.gold)))))
		Sfx.play("coin")


func _check_level_up() -> void:
	if game_over or levelup_menu.is_open or xp < xp_needed:
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


func _build_arena() -> void:
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

	var props := Props.new()
	props.shaft = Rect2(2640.0, 600.0, 200.0, 650.0)
	add_child(props)
	backdrop = Backdrop.new()
	add_child(backdrop)


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

	var art := BlockArt.new()
	art.kind = kind
	art.size = rect.size
	body.add_child(art)
	add_child(body)


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
	var element := player.current_module()
	var color := Elements.color_of(element, weapon.color)
	Sfx.play(weapon.sound)
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
		bullet.pierce = int(weapon.pierce)
		bullet.size = float(weapon.size)
		bullet.color = color
		bullet.element = element
		bullet.shooter = player
		bullet.explosion_radius = float(weapon.get("explosion_radius", 0.0))
		bullet.explosion_damage = float(weapon.get("explosion_damage", 0.0)) * player.damage_mult()
		bullet.hit.connect(_on_projectile_hit)
		projectiles.add_child(bullet)


func _fire_hitscan(player: Player, weapon: Dictionary, origin: Vector2, direction: Vector2, damage: float, element: String, color: Color) -> void:
	var space := get_world_2d().direct_space_state
	var target := origin + direction * float(weapon.range)
	var end := target
	var exclude: Array[RID] = []
	var hits_left := int(weapon.pierce) + 1
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


