extends Node2D
## Hauptszene: Arena mit Plattformen, zwei Spielern, Gegnern (Director),
## Kamera, HUD und Spielablauf. Alles wird im Code gebaut, damit sich das
## Layout leicht anpassen laesst.

const ARENA_SIZE := Vector2(3200.0, 1350.0)
const FLOOR_Y := 1250.0
const WORLD_COLOR := Color(0.2, 0.22, 0.3)
const BG_COLOR := Color(0.08, 0.09, 0.13)

# Welche Klassen die beiden Spieler spielen (roomba, hexapod, vending, printer).
const PLAYER_CLASSES: Array[String] = ["roomba", "hexapod"]

# Testausstattung: jeder Spieler bekommt drei Waffen zum Ausprobieren.
# Mit Dreieck (Controller) oder der Waffen-Taste wechselt man durch.
# Debug: F1 / F2 tauschen die aktuelle Waffe von Spieler 1 / 2 gegen die naechste.
const TEST_LOADOUTS := [
	["dust", "shotgun", "rocket"],
	["sniper", "beam", "rapid"],
]
# Elementmodule der Testwaffen (gleiche Reihenfolge). Spaeter kauft man sie im Shop.
# Beispiel Coop: P1 macht mit Staubkugeln nass, P2 schockt mit dem Sniper.
const TEST_MODULES := [
	["water", "ice", "fire"],
	["lightning", "fire", "water"],
]

const DUMMY_RESPAWN_TIME := 4.0
const RESTART_DELAY := 1.0

## Tests koennen diese Werte vor dem Einhaengen der Szene setzen.
var use_dummies := false
var director_enabled := true

var players: Array[Player] = []
var camera: CoopCamera
var fx: Fx
var hud: Hud
var director: Director
var projectiles: Node2D
var enemy_projectiles: Node2D
var pickups: Node2D
var levelup_menu: LevelUpMenu

var level := 1
var xp := 0
var xp_needed := 10
var kills := 0
var game_over := false
var last_pad_event := "-"

var _respawns: Array[Dictionary] = []
var _game_over_time := 0.0


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
	_setup_director()
	if use_dummies:
		_spawn_dummies()
	levelup_menu = LevelUpMenu.new()
	levelup_menu.chosen.connect(_on_perk_chosen)
	add_child(levelup_menu)
	hud = Hud.new()
	hud.main = self
	add_child(hud)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _physics_process(delta: float) -> void:
	_check_level_up()
	for entry in _respawns:
		entry.t -= delta
		if entry.t <= 0.0:
			_spawn_dummy(entry.pos)
	_respawns = _respawns.filter(func(entry: Dictionary) -> bool: return entry.t > 0.0)

	if game_over:
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


func _cycle_weapon(index: int) -> void:
	var player := players[index]
	var current := Weapons.ALL_IDS.find(player.current_weapon_id())
	player.weapons[player.weapon_index] = Weapons.ALL_IDS[(current + 1) % Weapons.ALL_IDS.size()]
	Sfx.play("switch")


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	print("Controller %d %s: %s" % [device, "verbunden" if connected else "getrennt", Input.get_joy_name(device)])


func _spawn_players() -> void:
	for i in 2:
		var player := Player.new()
		player.setup(i + 1, PLAYER_CLASSES[i])
		player.weapons.clear()
		player.modules.clear()
		for j in TEST_LOADOUTS[i].size():
			player.weapons.append(TEST_LOADOUTS[i][j])
			player.modules.append(TEST_MODULES[i][j])
		player.position = Vector2(300.0 + i * 90.0, FLOOR_Y - 40.0)
		player.fired.connect(_on_player_fired)
		player.went_down.connect(_on_player_down)
		add_child(player)
		players.append(player)
	players[0].partner = players[1]
	players[1].partner = players[0]


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
	_add_block(Rect2(0.0, FLOOR_Y, ARENA_SIZE.x, 100.0))
	_add_block(Rect2(-100.0, -100.0, 100.0, ARENA_SIZE.y + 200.0))
	_add_block(Rect2(ARENA_SIZE.x, -100.0, 100.0, ARENA_SIZE.y + 200.0))
	_add_block(Rect2(0.0, -100.0, ARENA_SIZE.x, 100.0))

	# Plattformen in versetzten Hoehen fuer Sprung und spaeter Doppelsprung.
	var platforms: Array[Rect2] = [
		Rect2(350.0, 1120.0, 300.0, 24.0),
		Rect2(800.0, 990.0, 300.0, 24.0),
		Rect2(1250.0, 860.0, 300.0, 24.0),
		Rect2(1700.0, 990.0, 300.0, 24.0),
		Rect2(2150.0, 1120.0, 300.0, 24.0),
	]
	for rect in platforms:
		_add_block(rect)

	# Hoher Schacht mit Belohnungs-Plattform: gedacht fuer Wandsprung und Haken.
	_add_block(Rect2(2600.0, 700.0, 40.0, 550.0))
	_add_block(Rect2(2840.0, 700.0, 40.0, 550.0))
	_add_block(Rect2(2580.0, 676.0, 320.0, 24.0))


func _add_block(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1 << 0
	body.collision_mask = 0
	body.position = rect.get_center()

	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)

	var half := rect.size * 0.5
	var visual := Polygon2D.new()
	visual.color = WORLD_COLOR
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	body.add_child(visual)
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


func _on_player_fired(player: Player, weapon_id: String, origin: Vector2, direction: Vector2) -> void:
	var weapon := Weapons.get_weapon(weapon_id)
	var damage := float(weapon.damage) * player.damage_mult()
	var element := player.current_module()
	var color := Elements.color_of(element, weapon.color)
	Sfx.play(weapon.sound)
	camera.add_shake(float(weapon.shake))
	fx.muzzle(origin, direction, color)
	if weapon.kind == "hitscan":
		_fire_hitscan(player, weapon, origin, direction, damage, element, color)
	else:
		_fire_projectiles(player, weapon, origin, direction, damage, element, color)


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
		_explode(pos, projectile.explosion_radius, projectile.explosion_damage, projectile.shooter, projectile.color, projectile.element)


func _explode(pos: Vector2, radius: float, damage: float, shooter: Node, color: Color, element := "") -> void:
	fx.explosion(pos, radius, color)
	camera.add_shake(10.0)
	Sfx.play("explosion")
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var distance: float = enemy.global_position.distance_to(pos)
		if distance <= radius + 25.0:
			var falloff := 1.0 - 0.5 * clampf(distance / radius, 0.0, 1.0)
			var away: Vector2 = (enemy.global_position - pos).normalized()
			enemy.take_damage(damage * falloff, shooter, away, element)


