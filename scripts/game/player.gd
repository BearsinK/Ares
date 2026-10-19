class_name Player
extends CharacterBody2D
## Ein Spieler-Roboter. Steuerung ueber die Aktionen p1_* oder p2_*
## (siehe input_setup.gd). Die Darstellung ist ein Platzhalter aus Formen:
## Koerperform und Farbe zeigen die Klasse, der Rand zeigt den Spieler.

signal fired(player: Player, weapon_id: String, origin: Vector2, direction: Vector2)
signal hurt(player: Player, amount: float)
signal went_down(player: Player)
signal revived(player: Player)
signal slam_landed(player: Player, position: Vector2)

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
const HIT_IFRAMES := 0.8
const REVIVE_TIME := 3.0
const REVIVE_RANGE := 90.0
const WALL_SLIDE_SPEED := 140.0
const GLIDE_SPEED := 160.0
const WALL_JUMP_PUSH := 520.0
const WALL_LOCK_TIME := 0.18
const SLAM_SPEED := 1600.0
const HOOK_RANGE := 650.0
const HOOK_SPEED := 1400.0
const HOOK_COOLDOWN := 0.8
const HOOK_MAX_TIME := 0.7
const DROP_TIME := 0.25
const WORLD_MASK := (1 << 0) | (1 << 5)

var player_index := 1
var class_id := "roomba"
var stats: Dictionary = {}
var aim_dir := Vector2.RIGHT
var facing := 1.0
var iframes := 0.0
var dash_charges := 0
var weapons: Array[String] = []
var weapon_index := 0
# Elementmodul pro Waffe (gleicher Index wie weapons), "" = kein Modul.
var modules: Array[String] = []
var hp := 100.0
var gold := 0
var downed := false
var revive_progress := 0.0
var partner: Player = null
# Bewegungs-Firmware: id -> Anzahl Stapel (siehe Firmware).
var firmware: Dictionary = {}
var hook_active := false
var hook_anchor := Vector2.ZERO
# Dauerhafte Boni aus Perks und Items (Anteile, ausser max_hp als fester Wert).
var mods := {"damage": 0.0, "fire_rate": 0.0, "speed": 0.0, "max_hp": 0.0, "dmg_taken": 0.0,
	"dash_cd": 0.0, "pickup": 0.0, "gold": 0.0}

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
var _wall_lock := 0.0
var _slamming := false
var _hook_time := 0.0
var _hook_cooldown := 0.0
var _drop_time := 0.0


func setup(index: int, new_class_id: String) -> void:
	player_index = index
	class_id = new_class_id
	stats = RobotClasses.get_stats(class_id)
	_prefix = "p%d_" % index
	dash_charges = stats.dash_charges
	hp = stats.max_hp
	for weapon_id in stats.weapons:
		weapons.append(weapon_id)
		modules.append("")


func fw(firmware_id: String) -> int:
	return int(firmware.get(firmware_id, 0))


func add_firmware(firmware_id: String) -> void:
	firmware[firmware_id] = fw(firmware_id) + 1


func dash_max() -> int:
	return int(stats.dash_charges) + fw("dash_charge")


func max_health() -> float:
	return float(stats.max_hp) + float(mods.max_hp)


func move_speed() -> float:
	return float(stats.speed) * (1.0 + float(mods.speed))


func damage_mult() -> float:
	return float(stats.damage_mult) * (1.0 + float(mods.damage))


func add_mods(new_mods: Dictionary) -> void:
	for key in new_mods:
		mods[key] = float(mods[key]) + float(new_mods[key])
	if new_mods.has("max_hp"):
		hp += float(new_mods.max_hp)


## Gibt true zurueck, wenn der Treffer ankam (nicht unverwundbar oder am Boden).
func take_hit(amount: float, from: Vector2) -> bool:
	if downed or iframes > 0.0:
		return false
	var final_amount := amount * maxf(0.1, 1.0 - float(mods.dmg_taken))
	hp -= final_amount
	iframes = HIT_IFRAMES
	var away := (global_position - from).normalized()
	velocity += Vector2(away.x * 320.0, -260.0)
	Sfx.play("hurt")
	hurt.emit(self, final_amount)
	if hp <= 0.0:
		hp = 0.0
		downed = true
		revive_progress = 0.0
		velocity = Vector2(velocity.x * 0.3, velocity.y)
		went_down.emit(self)
	return true


func revive(health_fraction := 0.5) -> void:
	downed = false
	revive_progress = 0.0
	hp = max_health() * health_fraction
	iframes = 1.5
	Sfx.play("revive")
	revived.emit(self)


func _process_downed(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	move_and_slide()
	# Der Partner belebt durch Halten von Interagieren in der Naehe.
	var reviving := false
	if partner != null and not partner.downed:
		var close := partner.global_position.distance_to(global_position) <= REVIVE_RANGE
		reviving = close and Input.is_action_pressed(partner._prefix + "interact")
	if reviving:
		revive_progress += delta / REVIVE_TIME
		if revive_progress >= 1.0:
			revive()
	else:
		revive_progress = maxf(0.0, revive_progress - delta * 0.5)


func _ready() -> void:
	collision_layer = 1 << 1
	# Spieler kollidieren nur mit der Welt, nicht mit Gegnern oder dem Partner.
	collision_mask = WORLD_MASK
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
	if downed:
		_process_downed(delta)
		queue_redraw()
		return
	_update_aim(delta)

	var move := Input.get_axis(_prefix + "left", _prefix + "right")
	if absf(move) > 0.1:
		facing = signf(move)

	if Input.is_action_just_pressed(_prefix + "jump"):
		_jump_buffer = JUMP_BUFFER_TIME
	if Input.is_action_just_pressed(_prefix + "dash"):
		_try_dash()
	if Input.is_action_just_pressed(_prefix + "hook"):
		if hook_active:
			_release_hook()
		else:
			_try_hook()

	if hook_active:
		_process_hook(delta)
	elif _dash_time_left > 0.0:
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
	_wall_lock = maxf(0.0, _wall_lock - delta)
	_hook_cooldown = maxf(0.0, _hook_cooldown - delta)
	_drop_time = maxf(0.0, _drop_time - delta)
	collision_mask = (1 << 0) if _drop_time > 0.0 else WORLD_MASK
	_switch_cooldown = maxf(0.0, _switch_cooldown - delta)

	if dash_charges < dash_max():
		_dash_recharge += delta
		if _dash_recharge >= float(stats.dash_cooldown) * (1.0 - float(mods.dash_cd)):
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
	var down := Input.get_axis(_prefix + "up", _prefix + "down")
	var accel: float = stats.accel if on_floor else stats.air_accel

	if _slamming:
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
		velocity.y = SLAM_SPEED
		if on_floor:
			_slamming = false
			slam_landed.emit(self, global_position + Vector2(0.0, float(stats.radius)))
		return
	if _wall_lock <= 0.0:
		velocity.x = move_toward(velocity.x, move * move_speed(), accel * delta)

	var on_wall := is_on_wall_only() and not on_floor
	var wall_normal := get_wall_normal() if on_wall else Vector2.ZERO
	var pushing_wall := on_wall and move != 0.0 and signf(move) == -signf(wall_normal.x)
	var jump_held := Input.is_action_pressed(_prefix + "jump")

	var gravity := GRAVITY
	if velocity.y > 0.0:
		gravity *= FALL_GRAVITY_MULT
	elif velocity.y < 0.0 and not jump_held:
		gravity *= JUMP_CUT_GRAVITY_MULT
	velocity.y = minf(velocity.y + gravity * delta, MAX_FALL_SPEED)

	# Wandrutschen und Gleiten bremsen den Fall.
	if velocity.y > 0.0:
		if fw("wall_jump") > 0 and pushing_wall:
			velocity.y = minf(velocity.y, WALL_SLIDE_SPEED)
		elif fw("glide") > 0 and jump_held and not on_floor:
			velocity.y = minf(velocity.y, GLIDE_SPEED)

	if on_floor:
		_coyote = COYOTE_TIME
		_air_jumps_left = fw("double_jump")
	else:
		_coyote = maxf(0.0, _coyote - delta)

	if _jump_buffer <= 0.0:
		return
	if on_floor and down > 0.6 and _is_on_one_way():
		# Nach unten durch eine Plattform fallen.
		_drop_time = DROP_TIME
		_jump_buffer = 0.0
	elif not on_floor and down > 0.6 and fw("slam") > 0:
		_slamming = true
		_jump_buffer = 0.0
		Sfx.play("slam")
	elif _coyote > 0.0:
		velocity.y = -stats.jump_speed
		_jump_buffer = 0.0
		_coyote = 0.0
		Sfx.play("jump")
	elif on_wall and fw("wall_jump") > 0:
		velocity = Vector2(wall_normal.x * WALL_JUMP_PUSH, -float(stats.jump_speed) * 0.95)
		facing = signf(wall_normal.x)
		_wall_lock = WALL_LOCK_TIME
		_jump_buffer = 0.0
		Sfx.play("jump")
	elif _air_jumps_left > 0:
		velocity.y = -stats.jump_speed
		_jump_buffer = 0.0
		_air_jumps_left -= 1
		Sfx.play("jump")


## True, wenn der Spieler auf einer durchlaessigen Plattform steht.
func _is_on_one_way() -> bool:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is CollisionObject2D and (collider.collision_layer & (1 << 5)) != 0:
			return true
	return false


func _try_hook() -> void:
	if fw("hook") <= 0 or _hook_cooldown > 0.0 or _dash_time_left > 0.0:
		return
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + aim_dir * HOOK_RANGE, WORLD_MASK)
	query.exclude = [get_rid()]
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		_hook_cooldown = 0.3
		Sfx.play("switch")
		return
	hook_active = true
	hook_anchor = result.position
	_hook_time = HOOK_MAX_TIME
	_slamming = false
	Sfx.play("dash")


func _process_hook(delta: float) -> void:
	_hook_time -= delta
	var to_anchor := hook_anchor - global_position
	if to_anchor.length() < 36.0 or _hook_time <= 0.0 or _jump_buffer > 0.0:
		_release_hook()
		return
	velocity = to_anchor.normalized() * HOOK_SPEED


func _release_hook() -> void:
	hook_active = false
	_hook_cooldown = HOOK_COOLDOWN
	velocity *= 0.65


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
		velocity = _dash_dir * move_speed() * DASH_END_MOMENTUM
		velocity.y = minf(velocity.y, 0.0)


func current_weapon_id() -> String:
	return weapons[weapon_index]


## Setzt das Elementmodul der aktiven Waffe (ersetzt ein vorhandenes).
func set_module(element: String) -> void:
	modules[weapon_index] = element


## Neue Waffe: freier Slot, sonst ersetzt sie die aktive Waffe (inklusive Modul).
func add_weapon(weapon_id: String) -> void:
	if weapons.size() < 3:
		weapons.append(weapon_id)
		modules.append("")
		weapon_index = weapons.size() - 1
	else:
		weapons[weapon_index] = weapon_id
		modules[weapon_index] = ""


func current_module() -> String:
	return modules[weapon_index] if weapon_index < modules.size() else ""


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
	_fire_cooldown = 1.0 / (float(weapon.fire_rate) * (1.0 + float(mods.fire_rate)))
	var origin: Vector2 = global_position + aim_dir * (float(stats.radius) + float(weapon.barrel))
	# Rueckstoss: am Boden schwaecher, in der Luft staerker.
	var kick := float(weapon.recoil) * (0.35 if is_on_floor() else 1.0)
	if not (stats.stationary_fire and weapon_id == stats.weapons[0]):
		velocity -= aim_dir * kick
	fired.emit(self, weapon_id, origin, aim_dir)


func _draw() -> void:
	if downed:
		_draw_downed()
		return
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

	if hook_active:
		draw_line(Vector2.ZERO, to_local(hook_anchor), Color(0.9, 0.9, 0.5), 2.0)
		draw_circle(to_local(hook_anchor), 5.0, Color(0.9, 0.9, 0.5))
	_draw_body(r, body_color, outline)
	_draw_face(r, alpha)
	_draw_weapon(r, outline)
	_draw_dash_pips(r)


func _draw_downed() -> void:
	var r: float = stats.radius
	var outline: Color = RobotClasses.PLAYER_COLORS[player_index - 1]
	draw_circle(Vector2(0.0, r * 0.3), r, Color(0.3, 0.3, 0.35))
	draw_arc(Vector2(0.0, r * 0.3), r, 0.0, TAU, 32, outline, 3.0)
	# Ausgeschaltete Augen (X) und Wiederbelebungs-Fortschritt.
	for side in [-1.0, 1.0]:
		var c := Vector2(side * r * 0.35, 0.0)
		draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), Color(0.8, 0.3, 0.3), 2.0)
		draw_line(c + Vector2(-4, 4), c + Vector2(4, -4), Color(0.8, 0.3, 0.3), 2.0)
	if revive_progress > 0.0:
		draw_arc(Vector2.ZERO, r + 10.0, -PI / 2.0, -PI / 2.0 + TAU * revive_progress, 32, Color(0.4, 1.0, 0.5), 5.0)


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
	var total: int = dash_max()
	for i in total:
		var x := (i - (total - 1) * 0.5) * 12.0
		var pos := Vector2(x, -r * 1.9)
		var filled := i < dash_charges
		draw_circle(pos, 4.0, Color(1, 1, 1, 0.9 if filled else 0.2))
