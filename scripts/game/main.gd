extends Node2D
## Testszene: eine Arena mit Plattformen, zwei Spielern, Uebungspuppen und
## einer Kamera, die beide im Bild haelt. Alles wird im Code gebaut, damit
## sich das Layout leicht anpassen laesst.

const ARENA_SIZE := Vector2(3200.0, 1350.0)
const FLOOR_Y := 1250.0
const WORLD_COLOR := Color(0.2, 0.22, 0.3)
const BG_COLOR := Color(0.08, 0.09, 0.13)

# Welche Klassen die beiden Spieler spielen (roomba, hexapod, vending, printer).
const PLAYER_CLASSES: Array[String] = ["roomba", "hexapod"]

var players: Array[Player] = []
var camera: CoopCamera
var hud_label: Label
var projectiles: Node2D

const DUMMY_RESPAWN_TIME := 4.0
var _respawns: Array[Dictionary] = []
var _last_pad_event := "-"


func _ready() -> void:
	RenderingServer.set_default_clear_color(BG_COLOR)
	_build_arena()
	projectiles = Node2D.new()
	add_child(projectiles)
	_spawn_dummies()
	_spawn_players()
	_setup_camera()
	_build_hud()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _process(_delta: float) -> void:
	_update_hud()


func _physics_process(delta: float) -> void:
	for entry in _respawns:
		entry.t -= delta
		if entry.t <= 0.0:
			_spawn_dummy(entry.pos)
	_respawns = _respawns.filter(func(entry: Dictionary) -> bool: return entry.t > 0.0)


func _input(event: InputEvent) -> void:
	# Diagnose: zeigt im HUD, welcher Controller-Input zuletzt ankam.
	if event is InputEventJoypadButton and event.pressed:
		_last_pad_event = "Controller %d Taste %d" % [event.device, event.button_index]
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		_last_pad_event = "Controller %d Achse %d (%.1f)" % [event.device, event.axis, event.axis_value]


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	print("Controller %d %s: %s" % [device, "verbunden" if connected else "getrennt", Input.get_joy_name(device)])


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


func _spawn_players() -> void:
	for i in 2:
		var player := Player.new()
		player.setup(i + 1, PLAYER_CLASSES[i])
		player.position = Vector2(300.0 + i * 90.0, FLOOR_Y - 40.0)
		player.fired.connect(_on_player_fired)
		add_child(player)
		players.append(player)


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


func _on_player_fired(origin: Vector2, direction: Vector2, damage: float, shooter: Player) -> void:
	var bullet := Projectile.new()
	bullet.position = origin
	bullet.direction = direction
	bullet.damage = damage
	bullet.shooter = shooter
	bullet.color = RobotClasses.PLAYER_COLORS[shooter.player_index - 1]
	projectiles.add_child(bullet)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	hud_label = Label.new()
	hud_label.position = Vector2(16.0, 12.0)
	hud_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(hud_label)
	add_child(layer)


func _update_hud() -> void:
	var lines: Array[String] = []
	for player in players:
		lines.append("P%d %s | Dash %d/%d" % [
			player.player_index, player.stats.name, player.dash_charges, player.stats.dash_charges])

	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		lines.append("Kein Controller erkannt (Tastatur aktiv)")
	for pad in pads:
		lines.append("Controller %d: %s" % [pad, Input.get_joy_name(pad)])
	lines.append("Letzter Controller-Input: %s" % _last_pad_event)
	lines.append("FPS: %d" % Engine.get_frames_per_second())
	hud_label.text = "\n".join(lines)
