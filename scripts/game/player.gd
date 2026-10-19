class_name Player
extends CharacterBody2D
## Ein Spieler-Roboter. Steuerung ueber die Aktionen p1_* oder p2_*
## (siehe input_setup.gd). Die Darstellung ist ein Platzhalter aus Formen:
## Koerperform und Farbe zeigen die Klasse, der Rand zeigt den Spieler.

signal fired(player: Player, weapon_id: String, origin: Vector2, direction: Vector2)

const GRAVITY := 2000.0
const FALL_GRAVITY_MULT := 1.35
const JUMP_CUT_GRAVITY_MULT := 2.2
const MAX_FALL_SPEED := 1400.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.1
const DASH_TIME := 0.16
const DASH_SPEED := 1000.0
const DASH_END_MOMENTUM := 1.35
const DASH_IFRAMES := 0.22
const AIM_MEMORY := 0.25
const AIM_THRESHOLD := 0.3
const MOUSE_AIM_TIMEOUT := 3.0
const TRAIL_LIFETIME := 0.25

var player_index := 1
var class_id := "roomba"
var stats: Dictionary = {}
var aim_dir := Vector2.RIGHT
var facing := 1.0
var iframes := 0.0
var dash_charges := 0
var weapons: Array[String] = []
var weapon_index := 0

var _prefix := "p1_"
var _coyote := 0.0
var _jump_buffer := 0.0
var _air_jumps_left := 0
var _dash_time_left := 0.0
var _dash_dir := Vector2.RIGHT
var _dash_recharge := 0.0
var _fire_cooldown := 0.0
var _switch_cooldown := 0.0
var _aim_memory := 0.0
var _mouse_timer := 0.0
var _trail_timer := 0.0
var _trail: Array[Dictionary] = []


func setup(index: int, new_class_id: String) -> void:
	player_index = index
	class_id = new_class_id
	stats = RobotClasses.get_stats(class_id)
	_prefix = "p%d_" % index
	dash_charges = stats.dash_charges
	for weapon_id in stats.weapons:
		weapons.append(weapon_id)


func _ready() -> void:
	collision_layer = 1 << 1
	# Spieler kollidieren nur mit der Welt, nicht mit Gegnern oder dem Partner.
	collision_mask = 1 << 0
	floor_snap_length = 8.0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = stats.radius
	shape.shape = circle
	add_child(shape)


func _input(event: InputEvent) -> void:
	# Nur Spieler 1 kann mit der Maus zielen.
	if player_index == 1 and event is InputEventMouseMotion:
		_mouse_timer = MOUSE_AIM_TIMEOUT


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_update_aim(delta)

	var move := Input.get_axis(_prefix + "left", _prefix + "right")
	if absf(move) > 0.1:
		facing = signf(move)

	if Input.is_action_just_pressed(_prefix + "jump"):
		_jump_buffer = JUMP_BUFFER_TIME
	if Input.is_action_just_pressed(_prefix + "dash"):
		_try_dash()

	if _dash_time_left > 0.0:
		_process_dash(delta)
	else:
		_process_movement(delta, move)

	move_and_slide()
	_handle_fire(delta)
	queue_redraw()


func _update_timers(delta: float) -> void:
	iframes = maxf(0.0, iframes - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_mouse_timer = maxf(0.0, _mouse_timer - delta)
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_switch_cooldown = maxf(0.0, _switch_cooldown - delta)

	if dash_charges < stats.dash_charges:
		_dash_recharge += delta
		if _dash_recharge >= stats.dash_cooldown:
			_dash_recharge = 0.0
			dash_charges += 1
	else:
		_dash_recharge = 0.0

	for entry in _trail:
		entry.t -= delta
	_trail = _trail.filter(func(entry: Dictionary) -> bool: return entry.t > 0.0)


func _update_aim(delta: float) -> void:
	var stick := Input.get_vector(
		_prefix + "aim_left", _prefix + "aim_right",
		_prefix + "aim_up", _prefix + "aim_down")
	if stick.length() > AIM_THRESHOLD:
		aim_dir = stick.normalized()
		_aim_memory = AIM_MEMORY
	elif _aim_memory > 0.0:
		# Aim-Gedaechtnis: Zielrichtung bleibt kurz erhalten, falls der Daumen
		# fuer eine andere Taste den Stick verlaesst.
		_aim_memory -= delta
	elif _mouse_timer > 0.0:
		aim_dir = (get_global_mouse_position() - global_position).normalized()
	else:
		aim_dir = Vector2(facing, 0.0)

	if absf(aim_dir.x) > 0.2:
		facing = signf(aim_dir.x)


func _process_movement(delta: float, move: float) -> void:
	var on_floor := is_on_floor()
	var accel: float = stats.accel if on_floor else stats.air_accel
	velocity.x = move_toward(velocity.x, move * stats.speed, accel * delta)

	var gravity := GRAVITY
	if velocity.y > 0.0:
		gravity *= FALL_GRAVITY_MULT
	elif velocity.y < 0.0 and not Input.is_action_pressed(_prefix + "jump"):
		gravity *= JUMP_CUT_GRAVITY_MULT
	velocity.y = minf(velocity.y + gravity * delta, MAX_FALL_SPEED)

	if on_floor:
		_coyote = COYOTE_TIME
		_air_jumps_left = int(stats.get("air_jumps", 0))
	else:
		_coyote = maxf(0.0, _coyote - delta)

	if _jump_buffer > 0.0:
		if _coyote > 0.0:
			velocity.y = -stats.jump_speed
			_jump_buffer = 0.0
			_coyote = 0.0
			Sfx.play("jump")
		elif _air_jumps_left > 0:
			velocity.y = -stats.jump_speed
			_jump_buffer = 0.0
			_air_jumps_left -= 1
			Sfx.play("jump")


func _try_dash() -> void:
	if dash_charges <= 0 or _dash_time_left > 0.0:
		return
	var stick := Input.get_vector(
		_prefix + "left", _prefix + "right", _prefix + "up", _prefix + "down")
	var dir := stick
	if dir.length() < AIM_THRESHOLD:
		dir = Vector2(facing, 0.0)
	_dash_dir = dir.normalized()
	_dash_time_left = DASH_TIME
	dash_charges -= 1
	iframes = maxf(iframes, DASH_IFRAMES)
	Sfx.play("dash")


func _process_dash(delta: float) -> void:
	_dash_time_left -= delta
	velocity = _dash_dir * DASH_SPEED
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.025
		_trail.append({"pos": global_position, "t": TRAIL_LIFETIME})
	if _dash_time_left <= 0.0:
		# Momentum: nach dem Dash bleibt etwas Schwung erhalten.
		velocity = _dash_dir * stats.speed * DASH_END_MOMENTUM
		velocity.y = minf(velocity.y, 0.0)


func current_weapon_id() -> String:
	return weapons[weapon_index]


func _can_fire(weapon_id: String) -> bool:
	# Klassenregel Hexapod: Die Klassenwaffe (erste Waffe) schiesst nur im Stand.
	if stats.stationary_fire and weapon_id == stats.weapons[0]:
		return is_on_floor() and absf(velocity.x) < 30.0 and _dash_time_left <= 0.0
	return true


func _rotate_weapon() -> void:
	if weapons.size() <= 1:
		return
	weapon_index = (weapon_index + 1) % weapons.size()
	_switch_cooldown = 0.2
	Sfx.play("switch")


func _handle_fire(_delta: float) -> void:
	if Input.is_action_just_pressed(_prefix + "weapon"):
		_rotate_weapon()
	if not Input.is_action_pressed(_prefix + "fire"):
		return
	if _fire_cooldown > 0.0 or _switch_cooldown > 0.0:
		return
	var weapon_id := current_weapon_id()
	if not _can_fire(weapon_id):
		return
	var weapon := Weapons.get_weapon(weapon_id)
	_fire_cooldown = 1.0 / float(weapon.fire_rate)
	var origin: Vector2 = global_position + aim_dir * (float(stats.radius) + float(weapon.barrel))
	# Rueckstoss: am Boden schwaecher, in der Luft staerker.
	var kick := float(weapon.recoil) * (0.35 if is_on_floor() else 1.0)
	if not (stats.stationary_fire and weapon_id == stats.weapons[0]):
		velocity -= aim_dir * kick
	fired.emit(self, weapon_id, origin, aim_dir)


func _draw() -> void:
	var alpha := 1.0
	if iframes > 0.0 and _dash_time_left <= 0.0 and fmod(iframes, 0.1) < 0.05:
		alpha = 0.4
	var r: float = stats.radius
	var body_color: Color = stats.color
	body_color.a = alpha
	var outline: Color = RobotClasses.PLAYER_COLORS[player_index - 1]
	outline.a = alpha

	for entry in _trail:
		var ghost := body_color
		ghost.a = 0.35 * (entry.t / TRAIL_LIFETIME)
		draw_circle(to_local(entry.pos), r * 0.8, ghost)

	_draw_body(r, body_color, outline)
	_draw_face(r, alpha)
	_draw_weapon(r, outline)
	_draw_dash_pips(r)


func _draw_body(r: float, color: Color, outline: Color) -> void:
	match class_id:
		"roomba":
			# Flache Scheibe mit Arm.
			draw_circle(Vector2.ZERO, r, color)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, outline, 3.0)
			draw_line(Vector2(-facing * 4.0, -r * 0.6), Vector2(-facing * 16.0, -r * 1.5), outline, 4.0)
		"hexapod":
			# Sechseck mit Beinen.
			for i in 6:
				var angle := i * TAU / 6.0 + PI / 6.0
				var leg_end := Vector2(cos(angle), sin(angle) * 0.5 + 0.7) * (r * 1.5)
				draw_line(Vector2.ZERO, leg_end, outline, 3.0)
			var points := PackedVector2Array()
			for i in 6:
				var angle := i * TAU / 6.0
				points.append(Vector2(cos(angle), sin(angle)) * r)
			draw_colored_polygon(points, color)
			points.append(points[0])
			draw_polyline(points, outline, 3.0)
		"vending":
			var rect := Rect2(Vector2(-r, -r * 1.4), Vector2(r * 2.0, r * 2.4))
			draw_rect(rect, color)
			draw_rect(rect, outline, false, 3.0)
			draw_rect(Rect2(Vector2(-r * 1.2, r * 0.7), Vector2(r * 2.4, r * 0.7)), Color(0.15, 0.15, 0.15, color.a))
		"printer":
			var rect := Rect2(Vector2(-r, -r), Vector2(r * 2.0, r * 2.0))
			draw_rect(rect, color)
			draw_rect(rect, outline, false, 3.0)
			draw_rect(Rect2(Vector2(r * 0.4, -r), Vector2(r * 0.6, r * 2.0)), Color(1.0, 0.55, 0.2, color.a))
		_:
			draw_circle(Vector2.ZERO, r, color)


func _draw_face(r: float, alpha: float) -> void:
	# LCD-Gesicht: zwei leuchtende Augen, die in Zielrichtung schauen.
	var eye_color: Color = stats.eye_color
	eye_color.a = alpha
	var look := Vector2(aim_dir.x * 2.0, aim_dir.y * 2.0)
	var eye_y := -r * 0.15
	draw_circle(Vector2(-r * 0.35, eye_y) + look, r * 0.14, eye_color)
	draw_circle(Vector2(r * 0.35, eye_y) + look, r * 0.14, eye_color)


func _draw_weapon(r: float, outline: Color) -> void:
	var weapon_id := current_weapon_id()
	var weapon := Weapons.get_weapon(weapon_id)
	var length: float = r + float(weapon.barrel) - 6.0
	var color := outline
	if not _can_fire(weapon_id):
		color = Color(0.5, 0.5, 0.5, outline.a)
	draw_line(aim_dir * (r * 0.5), aim_dir * length, color, 6.0)
	draw_circle(aim_dir * length, 3.5, weapon.color)


func _draw_dash_pips(r: float) -> void:
	var total: int = stats.dash_charges
	for i in total:
		var x := (i - (total - 1) * 0.5) * 12.0
		var pos := Vector2(x, -r * 1.9)
		var filled := i < dash_charges
		draw_circle(pos, 4.0, Color(1, 1, 1, 0.9 if filled else 0.2))
