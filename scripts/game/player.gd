class_name Player
extends CharacterBody2D
## Ein Spieler-Roboter. Steuerung ueber die Aktionen p1_* oder p2_*
## (siehe input_setup.gd). Die Darstellung ist ein Platzhalter aus Formen:
## Koerperform und Farbe zeigen die Klasse, der Rand zeigt den Spieler.

signal fired(player: Player, weapon_id: String, origin: Vector2, direction: Vector2, charge: float)
signal hurt(player: Player, amount: float)
signal went_down(player: Player)
signal revived(player: Player)
signal slam_landed(player: Player, position: Vector2)
signal heavy_landed(player: Player, strength: float)

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
const CLIMB_SPEED := 300.0
const DEPLOY_TIME := 0.2
# Ebene 8: unsichtbare Waende, die nur Spieler aufhalten (z.B. vor dem Boss), Geschosse fliegen durch.
const WORLD_MASK := (1 << 0) | (1 << 5) | (1 << 7)

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
## Schuettel-Aufladung der Dose (0 bis 1), solange Schiessen gehalten wird.
var shake_charge := 0.0
## Zug eines Laufbands in px/s (negativ = nach links), wirkt nur am Boden.
var belt_push := 0.0
## Solange > 0, ist der Spieler verlangsamt (Frostwache).
var slow_time := 0.0
## Anzahl Shop-Kaeufe in diesem Lauf (macht weitere Kaeufe teurer).
var purchases := 0
# Dauerhafte Boni aus Perks und Items (Anteile, ausser max_hp als fester Wert).
var mods := {"damage": 0.0, "fire_rate": 0.0, "speed": 0.0, "max_hp": 0.0, "dmg_taken": 0.0,
	"dash_cd": 0.0, "pickup": 0.0, "gold": 0.0, "ability_cd": 0.0, "crit": 0.0, "kill_heal": 0.0,
	"pierce": 0.0, "death_blast": 0.0, "link": 0.0}

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
var _lob_charging := false
var _clinging := false
var _cling_dir := 0.0
var _stand_time := 0.0
var _shake_tick := 0.0
var _art_time := 0.0
var _walk_phase := 0.0
var _fire_flash := 0.0
var _hurt_timer := 0.0
var _happy_timer := 0.0
var _arm_deploy := 0.0
# Animationszustand (siehe _update_juice): Landestauchung, Rueckstoss, Hitze, Aufstellen, Klettern.
var _land_squash := 0.0
var _was_grounded := true
var _fall_speed := 0.0
var _recoil := 0.0
var _heat := 0.0
var _deploy_amount := 0.0
var _deployed_flag := false
var _climb_phase := 0.0
var _step_acc := 0.0
var _cling_amount := 0.0
var _ceiling := false
var _ceiling_amount := 0.0
var _ceiling_cooldown := 0.0
var _coin_flash := 0.0
var _down_amount := 0.0
## Begleitdrohnen des Druckers: aus ihnen kommen die Schüsse.
var escorts: Array[Drone] = []
var _escort_turn := 0

var ability: Ability


func setup(index: int, new_class_id: String) -> void:
	player_index = index
	class_id = new_class_id
	stats = RobotClasses.get_stats(class_id)
	_prefix = "p%d_" % index
	dash_charges = stats.dash_charges
	hp = stats.max_hp
	mods.pickup = float(stats.get("pickup_bonus", 0.0))
	for weapon_id in stats.weapons:
		weapons.append(weapon_id)
		modules.append("")


func is_clinging() -> bool:
	return _clinging


func fw(firmware_id: String) -> int:
	return int(firmware.get(firmware_id, 0))


func firmware_count() -> int:
	var total := 0
	for id in firmware:
		total += int(firmware[id])
	return total


func add_firmware(firmware_id: String) -> void:
	firmware[firmware_id] = fw(firmware_id) + 1


func dash_max() -> int:
	return int(stats.dash_charges) + fw("dash_charge")


func max_health() -> float:
	return float(stats.max_hp) + float(mods.max_hp)


func move_speed() -> float:
	var rolling := 1.7 if ability != null and ability.is_active("roll") else 1.0
	var slowed := 0.6 if slow_time > 0.0 else 1.0
	return float(stats.speed) * (1.0 + float(mods.speed)) * rolling * slowed


## Feuerrate-Faktor aus Perks und Overwatch.
func fire_rate_mult() -> float:
	var boost := 2.0 if ability != null and ability.is_active("overwatch") else 1.0
	return (1.0 + float(mods.fire_rate)) * boost


## Kabelbaum: aktiv, solange der Partner steht und nah genug ist.
func link_active() -> bool:
	return float(mods.link) > 0.0 and not downed and partner != null and not partner.downed \
		and partner.global_position.distance_to(global_position) <= 450.0


func damage_mult() -> float:
	var link := 0.15 * float(mods.link) if link_active() else 0.0
	return float(stats.damage_mult) * (1.0 + float(mods.damage) + link)


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
	if ability != null and ability.is_active("roll"):
		final_amount *= 0.5
	# Stellung: Ein aufgestellter Hexapod steckt Treffer besser weg.
	if bool(stats.stationary_fire) and _deploy_amount > 0.8:
		final_amount *= 0.8
	hp -= final_amount
	iframes = HIT_IFRAMES
	_hurt_timer = 0.45
	var away := (global_position - from).normalized()
	var push := 1.0 - float(stats.get("knockback_resist", 0.0))
	velocity += Vector2(away.x * 320.0, -260.0) * push
	Sfx.play("hurt")
	hurt.emit(self, final_amount)
	if hp <= 0.0:
		hp = 0.0
		downed = true
		_ceiling = false
		revive_progress = 0.0
		shake_charge = 0.0
		_lob_charging = false
		velocity = Vector2(velocity.x * 0.3, velocity.y)
		went_down.emit(self)
	return true


func revive(health_fraction := 0.5) -> void:
	downed = false
	revive_progress = 0.0
	hp = max_health() * health_fraction
	iframes = 1.5
	_happy_timer = 1.5
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
	ability = Ability.new()
	add_child(ability)
	ability.setup(self)
	if int(stats.get("escort_drones", 0)) > 0:
		_spawn_escorts.call_deferred()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = stats.size
	shape.shape = rect
	add_child(shape)


func _input(event: InputEvent) -> void:
	# Nur Spieler 1 kann mit der Maus zielen.
	if player_index == 1 and event is InputEventMouseMotion:
		_mouse_timer = MOUSE_AIM_TIMEOUT


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	if downed:
		_process_downed(delta)
		_update_juice(delta)
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
	if Input.is_action_just_pressed(_prefix + "ability"):
		ability.try_use()
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
	if belt_push != 0.0 and is_on_floor():
		move_and_collide(Vector2(belt_push * delta, 0.0))
	var still := ((is_on_floor() or _ceiling) and absf(velocity.x) < 30.0) or (_clinging and absf(velocity.y) < 30.0)
	if still and _dash_time_left <= 0.0 and not hook_active:
		_stand_time += delta
	else:
		_stand_time = 0.0
	_update_juice(delta)
	_handle_fire(delta)
	queue_redraw()


## Aufgestellt: der Hexapod steht im Geschuetzmodus (Stand oder Overwatch).
## Kurzes Aufleuchten (Muenzschlitz des Automaten) beim Einsammeln von Gold.
func gold_flash() -> void:
	_coin_flash = 1.0


func is_deployed() -> bool:
	return bool(stats.stationary_fire) and (_stand_time >= DEPLOY_TIME or ability.is_active("overwatch")) and not downed


## Staub am Boden unter dem Spieler.
func _puff(offset: Vector2, count: int, speed := 110.0) -> void:
	if Fx.instance:
		Fx.instance.spark(global_position + offset, Color(0.75, 0.77, 0.82, 0.75), count, speed)


## Rein optische Zustaende: Landen, Aufstellen, Rueckstoss, Hitze, Klettern, Schritte.
func _update_juice(delta: float) -> void:
	var grounded := is_on_floor()
	if not grounded:
		_fall_speed = maxf(_fall_speed, velocity.y)
	elif not _was_grounded and _fall_speed > 260.0 and not _clinging:
		_land_squash = clampf(_fall_speed / 900.0, 0.25, 1.0)
		_puff(Vector2(0.0, float(stats.size.y) * 0.5), 4 + int(4.0 * _land_squash), 140.0)
		if bool(stats.get("heavy", false)) and _fall_speed > 550.0:
			# Schwere Klassen lassen beim harten Aufprall den Boden beben.
			_puff(Vector2(-22.0, float(stats.size.y) * 0.5), 4, 170.0)
			_puff(Vector2(22.0, float(stats.size.y) * 0.5), 4, 170.0)
			Sfx.play("land_heavy", 0.1)
			heavy_landed.emit(self, _land_squash)
		else:
			Sfx.play("land", 0.15)
	if grounded:
		_fall_speed = 0.0
	_was_grounded = grounded
	_land_squash = move_toward(_land_squash, 0.0, delta * 5.0)
	_recoil = maxf(0.0, _recoil - delta * 9.0)
	_coin_flash = maxf(0.0, _coin_flash - delta * 2.0)
	_heat = maxf(0.0, _heat - delta * 0.45)

	var planted := is_deployed()
	_deploy_amount = move_toward(_deploy_amount, 1.0 if planted else 0.0, delta * (8.0 if planted else 5.0))
	if planted and not _deployed_flag:
		_deployed_flag = true
		Sfx.play("deploy", 0.05)
		_puff(Vector2(-18.0, float(stats.size.y) * 0.5), 3, 90.0)
		_puff(Vector2(18.0, float(stats.size.y) * 0.5), 3, 90.0)
	elif not planted and _deployed_flag:
		_deployed_flag = false

	_cling_amount = move_toward(_cling_amount, 1.0 if _clinging else 0.0, delta * 7.0)
	_ceiling_amount = move_toward(_ceiling_amount, 1.0 if _ceiling else 0.0, delta * 8.0)
	_down_amount = move_toward(_down_amount, 1.0 if downed else 0.0, delta * (3.0 if downed else 2.2))
	if _clinging:
		_climb_phase += velocity.y * delta * 0.045
	if grounded and not _clinging and absf(velocity.x) > 70.0 and stats.get("step", "") != "":
		_step_acc += absf(velocity.x) * delta
		if _step_acc >= 52.0:
			_step_acc = 0.0
			Sfx.play(String(stats.step), 0.2)
			_puff(Vector2(-facing * 10.0, float(stats.size.y) * 0.5), 1, 60.0)


func _update_timers(delta: float) -> void:
	iframes = maxf(0.0, iframes - delta)
	slow_time = maxf(0.0, slow_time - delta)
	if link_active() and hp < max_health():
		hp = minf(max_health(), hp + float(mods.link) * delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_mouse_timer = maxf(0.0, _mouse_timer - delta)
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_wall_lock = maxf(0.0, _wall_lock - delta)
	_hook_cooldown = maxf(0.0, _hook_cooldown - delta)
	_drop_time = maxf(0.0, _drop_time - delta)
	collision_mask = ((1 << 0) | (1 << 7)) if _drop_time > 0.0 else WORLD_MASK
	_switch_cooldown = maxf(0.0, _switch_cooldown - delta)
	_art_time += delta
	_fire_flash = maxf(0.0, _fire_flash - delta * 6.0)
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	_happy_timer = maxf(0.0, _happy_timer - delta)
	var arm_target := 1.0 if (Input.is_action_pressed(_prefix + "fire") or _fire_flash > 0.05) and not downed else 0.0
	_arm_deploy = move_toward(_arm_deploy, arm_target, delta * 8.0)
	_walk_phase += velocity.x * facing * delta * 0.12 if is_on_floor() or _clinging or _ceiling else 0.0

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

	if stats.get("wall_climb", false) and _process_ceiling(delta, move, down):
		return
	if stats.get("wall_climb", false) and _process_climb(move, down):
		return
	if _slamming:
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
		velocity.y = SLAM_SPEED
		if on_floor:
			_slamming = false
			slam_landed.emit(self, global_position + Vector2(0.0, float(stats.size.y) * 0.5))
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


## Wandklettern (Hexapod): Gegen die Wand druecken haelt ihn fest, hoch/runter klettert.
## Gibt true zurueck, wenn die Bewegung dieses Frames damit erledigt ist.
## Unterseite einer Plattform oder der Decke direkt ueber dem Kopf (leer, wenn keine in Reichweite).
func _ceiling_above() -> Dictionary:
	var size: Vector2 = stats.size
	var head_y: float = global_position.y - size.y * 0.5
	for body in get_tree().get_nodes_in_group("ceilings"):
		var rect: Rect2 = body.get_meta("rect")
		var bottom := rect.end.y
		if global_position.x < rect.position.x + 6.0 or global_position.x > rect.end.x - 6.0:
			continue
		# Der Spieler muss unter der Platte sein (Mitte darunter) und der Kopf nahe an der Unterseite.
		if global_position.y > bottom and absf(head_y - bottom) < 24.0:
			return {"y": bottom, "rect": rect}
	return {}


## Deckenklettern (Hexapod): Hoch gedrueckt haelt er sich an der Unterseite fest, laeuft dort
## kopfueber entlang und laesst sich mit Runter oder Sprung fallen.
func _process_ceiling(delta: float, move: float, vertical: float) -> bool:
	_ceiling_cooldown = maxf(0.0, _ceiling_cooldown - delta)
	var info := _ceiling_above()
	if _ceiling:
		if info.is_empty() or vertical > 0.3 or _jump_buffer > 0.0 or _dash_time_left > 0.0:
			_ceiling = false
			_ceiling_cooldown = 0.3
			if _jump_buffer > 0.0:
				_jump_buffer = 0.0
			velocity = Vector2(velocity.x * 0.5, 140.0)
			return false
	elif vertical < -0.4 and _ceiling_cooldown <= 0.0 and not info.is_empty() and velocity.y < 400.0 and _dash_time_left <= 0.0:
		_ceiling = true
		_clinging = false
		_air_jumps_left = fw("double_jump")
		Sfx.play("deploy", 0.05)
		_puff(Vector2(0.0, -float(stats.size.y) * 0.5), 3, 80.0)
	else:
		return false
	global_position.y = float(info.y) + float(stats.size.y) * 0.5 + 1.0
	velocity.y = 0.0
	if _wall_lock <= 0.0:
		velocity.x = move_toward(velocity.x, move * move_speed() * 0.85, float(stats.accel) * delta)
	return true


func _process_climb(move: float, vertical: float) -> bool:
	if _wall_lock > 0.0 or _slamming:
		_clinging = false
		return false
	var touching := is_on_wall()
	var wall_dir := -signf(get_wall_normal().x) if touching else 0.0
	var pushing := touching and move != 0.0 and signf(move) == wall_dir
	var on_floor := is_on_floor()

	if _clinging and not touching:
		# Oberkante erreicht: kleiner Hopser auf den Rand.
		_clinging = false
		if vertical < -0.3 and signf(move) == _cling_dir:
			velocity = Vector2(_cling_dir * 240.0, -430.0)
			Sfx.play("jump")
			return true
		return false
	if _clinging and on_floor and vertical >= 0.0:
		_clinging = false
		return false

	var start := pushing and (not on_floor or vertical < -0.4)
	if not (start or (_clinging and pushing)):
		_clinging = false
		return false

	_clinging = true
	_cling_dir = wall_dir
	velocity.x = wall_dir * 80.0
	velocity.y = vertical * CLIMB_SPEED
	_air_jumps_left = fw("double_jump")
	if _jump_buffer > 0.0:
		# Von der Wand abspringen.
		velocity = Vector2(-wall_dir * WALL_JUMP_PUSH, -float(stats.jump_speed) * 0.95)
		facing = -wall_dir
		_wall_lock = WALL_LOCK_TIME
		_jump_buffer = 0.0
		_clinging = false
		Sfx.play("jump")
	return true


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
	_ceiling = false
	_ceiling_cooldown = 0.3
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
		return _stand_time >= DEPLOY_TIME or ability.is_active("overwatch")
	return true


func _rotate_weapon() -> void:
	if weapons.size() <= 1:
		return
	weapon_index = (weapon_index + 1) % weapons.size()
	_switch_cooldown = 0.2
	shake_charge = 0.0
	_lob_charging = false
	Sfx.play("switch")


## Dosenwurf: Feuer halten schuettelt die Dose (laedt auf), Loslassen wirft sie
## im Bogen. Je laenger geschuettelt, desto weiter, schneller und explosiver.
func _handle_lob(weapon_id: String, weapon: Dictionary, delta: float) -> void:
	var held := Input.is_action_pressed(_prefix + "fire")
	if held and _fire_cooldown <= 0.0 and _switch_cooldown <= 0.0 and _can_fire(weapon_id):
		_lob_charging = true
		shake_charge = minf(1.0, shake_charge + delta / float(weapon.shake_time))
		_shake_tick -= delta
		if _shake_tick <= 0.0:
			_shake_tick = 0.07
			Sfx.play("shake", 0.2)
	elif _lob_charging and not held:
		_lob_charging = false
		_fire_cooldown = 1.0 / (float(weapon.fire_rate) * fire_rate_mult())
		var origin: Vector2 = global_position + _muzzle_offset() + aim_dir * float(weapon.barrel)
		if escorts.is_empty():
			velocity -= aim_dir * float(weapon.recoil) * (0.35 if is_on_floor() else 1.0)
		var thrown_charge := shake_charge
		shake_charge = 0.0
		_fire_flash = 1.0
		_recoil = 0.5 + 0.5 * thrown_charge
		if Fx.instance and thrown_charge > 0.2:
			# Schaum spritzt aus dem Ausgabefach.
			Fx.instance.spark(origin, Color(1.0, 1.0, 1.0, 0.9), 4 + int(8.0 * thrown_charge), 220.0)
		fired.emit(self, weapon_id, origin, aim_dir, thrown_charge)
		_after_shot()
	elif not held:
		shake_charge = 0.0


func _handle_fire(_delta: float) -> void:
	if Input.is_action_just_pressed(_prefix + "weapon"):
		_rotate_weapon()
	var current := Weapons.get_weapon(current_weapon_id())
	if current.kind == "lob":
		_handle_lob(current_weapon_id(), current, _delta)
		return
	shake_charge = 0.0
	if not Input.is_action_pressed(_prefix + "fire"):
		return
	if _fire_cooldown > 0.0 or _switch_cooldown > 0.0:
		return
	var weapon_id := current_weapon_id()
	if not _can_fire(weapon_id):
		return
	var weapon := Weapons.get_weapon(weapon_id)
	if weapon.kind == "lob":
		return
	_fire_cooldown = 1.0 / (float(weapon.fire_rate) * fire_rate_mult())
	var origin: Vector2 = global_position + _muzzle_offset() + aim_dir * float(weapon.barrel)
	# Rueckstoss: am Boden schwaecher, in der Luft staerker. Drohnenschuesse stossen den Koerper nicht.
	var kick := float(weapon.recoil) * (0.35 if is_on_floor() else 1.0)
	if not (stats.stationary_fire and weapon_id == stats.weapons[0]) and escorts.is_empty():
		velocity -= aim_dir * kick
	_fire_flash = 1.0
	_recoil = 1.0 if escorts.is_empty() else 0.0
	_heat = minf(1.0, _heat + 0.2)
	if class_id == "hexapod":
		# Huelse fliegt seitlich aus dem Gehaeuse.
		if Fx.instance:
			Fx.instance.spark(global_position + Vector2(-5.0 * facing, -14.0), Color(1.0, 0.82, 0.4), 1, 150.0)
	fired.emit(self, weapon_id, origin, aim_dir, 0.0)
	_after_shot()


## Zustand fuer die Zeichenfunktionen (siehe RobotArt).
func _art_state() -> Dictionary:
	var weapon_color: Color = Weapons.get_weapon(current_weapon_id()).color
	var element := current_module()
	if element != "":
		weapon_color = Elements.COLORS[element]
	var mood := "normal"
	if downed:
		mood = "dead"
	elif _hurt_timer > 0.0:
		mood = "hurt"
	elif ability.is_active("roll"):
		mood = "angry"
	elif _coin_flash > 0.3:
		mood = "happy"
	elif _fire_flash > 0.3 or shake_charge > 0.0 or _deploy_amount > 0.85:
		mood = "focus"
	elif _happy_timer > 0.0:
		mood = "happy"
	var print_progress := 0.6
	var launch := -1.0
	if ability != null and ability.id() == "print":
		print_progress = ability.readiness()
		var since_use := ability.cooldown_total - ability.cooldown
		if ability.cooldown > 0.0 and since_use < 0.7:
			launch = since_use / 0.7
	var squash := Vector2.ONE
	if _land_squash > 0.0:
		squash = Vector2(1.0 + 0.2 * _land_squash, 1.0 - 0.24 * _land_squash)
	elif not is_on_floor() and not _clinging:
		var stretch := clampf(absf(velocity.y) / 1600.0, 0.0, 0.14)
		squash = Vector2(1.0 - stretch * 0.6, 1.0 + stretch)
	elif _dash_time_left > 0.0:
		squash = Vector2(1.12, 0.9)
	# Neigung: Walze lehnt sich nach vorn, ausgeschaltete schwere Klassen kippen um.
	var tilt := 0.0
	if bool(stats.get("tips_over", false)):
		tilt = (0.1 if ability.is_active("roll") else 0.0) * facing
	# Kletternder Spinnenroboter dreht sich mit dem Bauch zur Wand.
	var cling_rotation := -_cling_dir * PI / 2.0 * _cling_amount if bool(stats.get("wall_climb", false)) else 0.0
	return {
		"ceiling": _ceiling_amount, "cling": _cling_amount, "rot": cling_rotation, "down": _down_amount, "vy": velocity.y,
		"squash": squash, "deploy": _deploy_amount, "recoil": _recoil, "heat": _heat, "climb": _climb_phase,
		"hurt": _hurt_timer / 0.45, "downed": downed, "overdrive": 1.0 if ability.is_active() else 0.0,
		"coin": _coin_flash, "low": clampf((0.3 - hp / max_health()) / 0.3, 0.0, 1.0) if not downed else 0.0, "tilt": tilt,
		"print": print_progress, "launch": launch,
		"facing": facing, "aim": aim_dir, "t": _art_time, "vx": 0.0 if downed else velocity.x,
		"walk": _walk_phase, "grounded": is_on_floor(), "clinging": _clinging, "cling_dir": _cling_dir,
		"planted": bool(stats.stationary_fire) and (_stand_time >= DEPLOY_TIME or ability.is_active("overwatch")),
		"mood": mood, "firing": _fire_flash, "charge": shake_charge, "arm": _arm_deploy,
		"weapon_color": weapon_color, "accent": RobotClasses.PLAYER_COLORS[player_index - 1],
		"eye_color": stats.eye_color,
	}


func _draw() -> void:
	var size: Vector2 = stats.size
	var accent: Color = RobotClasses.PLAYER_COLORS[player_index - 1]

	ability.draw_aura(self, _art_time)
	if slow_time > 0.0:
		draw_arc(Vector2.ZERO, maxf(stats.size.x, stats.size.y) * 0.5 + 6.0, 0.0, TAU, 28, Color(0.75, 0.92, 1.0, 0.7), 2.5, true)

	# Nachbilder vom Dash.
	for entry in _trail:
		var ghost := accent
		ghost.a = 0.3 * (entry.t / TRAIL_LIFETIME)
		draw_rect(Rect2(to_local(entry.pos) - size * 0.5, size), ghost)

	if hook_active:
		draw_line(Vector2.ZERO, to_local(hook_anchor), Color(0.95, 0.9, 0.5), 2.5, true)
		draw_circle(to_local(hook_anchor), 5.0, Color(0.95, 0.9, 0.5))
		draw_arc(to_local(hook_anchor), 8.0, 0.0, TAU, 12, Color(1, 1, 1, 0.6), 1.5, true)

	# Blinken waehrend der Unverwundbarkeit nach einem Treffer.
	var blink := iframes > 0.0 and _dash_time_left <= 0.0 and not downed and fmod(iframes, 0.12) < 0.06
	modulate = Color(1, 1, 1, 0.45) if blink else (Color(0.6, 0.6, 0.66) if downed else Color.WHITE)

	var jitter := Vector2.ZERO
	if shake_charge > 0.0:
		jitter = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_charge * 3.0
	RobotArt.draw_player(self, class_id, _art_state(), jitter)

	if downed:
		_draw_downed(size)
		return
	_draw_marker(size, accent)
	if _deploy_amount > 0.9 and weapon_has_sight():
		_draw_sight()
	if shake_charge > 0.0:
		_draw_lob_preview(size)


func weapon_has_sight() -> bool:
	return bool(stats.stationary_fire) and Weapons.get_weapon(current_weapon_id()).kind == "hitscan"


## Duenner Zielstrahl des aufgestellten Geschuetzes.
func _draw_sight() -> void:
	var from := _muzzle_offset() + aim_dir * 26.0
	var pulse := 0.5 + 0.5 * sin(_art_time * 6.0)
	draw_line(from, from + aim_dir * 520.0, Color(1.0, 0.3, 0.25, 0.1 + 0.06 * pulse), 1.5, true)
	draw_circle(from + aim_dir * 520.0, 3.0, Color(1.0, 0.3, 0.25, 0.25))


func _draw_marker(size: Vector2, accent: Color) -> void:
	# Spielermarke ueber dem Kopf und Dash-Aufladungen.
	var y := -size.y * 0.5 - 20.0
	var font := ThemeDB.fallback_font
	draw_colored_polygon(PackedVector2Array([Vector2(-6, y - 6), Vector2(6, y - 6), Vector2(0, y + 3)]), accent)
	draw_polyline(PackedVector2Array([Vector2(-6, y - 6), Vector2(6, y - 6), Vector2(0, y + 3), Vector2(-6, y - 6)]), Art.OUTLINE, 1.5, true)
	draw_string(font, Vector2(-20, y - 9), "P%d" % player_index, HORIZONTAL_ALIGNMENT_CENTER, 40.0, 12, Color(1, 1, 1, 0.9))
	var total := dash_max()
	for i in total:
		var pos := Vector2((i - (total - 1) * 0.5) * 11.0, -size.y * 0.5 - 8.0)
		var filled := i < dash_charges
		draw_circle(pos, 3.5, Color(1, 1, 1, 0.9) if filled else Color(1, 1, 1, 0.18))
		if filled:
			draw_arc(pos, 3.5, 0.0, TAU, 10, accent, 1.2, true)


func _draw_downed(size: Vector2) -> void:
	# Ausgeschaltet: Rauch steigt auf, der Wiederbelebungs-Ring fuellt sich.
	for i in 3:
		var life := fposmod(_art_time * 0.8 + i * 0.33, 1.0)
		draw_circle(Vector2(sin(_art_time * 2.0 + i) * 6.0, -size.y * 0.5 - life * 28.0), 3.0 + life * 5.0, Color(0.7, 0.7, 0.75, 0.4 * (1.0 - life)))
	var ring_radius := maxf(size.x, size.y) * 0.5 + 8.0
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 40, Color(1, 1, 1, 0.15), 3.0, true)
	if revive_progress > 0.0:
		draw_arc(Vector2.ZERO, ring_radius, -PI / 2.0, -PI / 2.0 + TAU * revive_progress, 40, Color(0.4, 1.0, 0.5), 5.0, true)


func _draw_lob_preview(size: Vector2) -> void:
	# Ladering und gepunktete Flugbahn der Dose.
	var weapon := Weapons.get_weapon(current_weapon_id())
	var ring_color := Color(0.4, 0.95, 0.55).lerp(Color(1, 1, 1), shake_charge)
	var ring_radius := maxf(size.x, size.y) * 0.5 + 10.0
	draw_arc(Vector2.ZERO, ring_radius, -PI / 2.0, -PI / 2.0 + TAU * shake_charge, 40, ring_color, 4.0, true)
	var speed := lerpf(float(weapon.speed), float(weapon.speed_max), shake_charge)
	var gravity: float = weapon.gravity
	var pos := _muzzle_offset() + aim_dir * float(weapon.barrel)
	var vel := aim_dir * speed
	var step := 0.06
	for i in 24:
		vel.y += gravity * step
		pos += vel * step
		if global_position.y + pos.y > 1250.0:
			break
		draw_circle(pos, 3.0, Color(ring_color, 0.55))


## Position des Waffenansatzes relativ zum Koerpermittelpunkt (beruecksichtigt die Blickrichtung).
func _spawn_escorts() -> void:
	for i in int(stats.escort_drones):
		var drone := Drone.new()
		drone.escort = true
		drone.owner_player = self
		drone.slot = i
		get_parent().add_child(drone)
		drone.global_position = global_position + Vector2(0.0, -30.0)
		escorts.append(drone)


## Drohne, aus der der nächste Schuss kommt (abwechselnd), oder null.
func _escort_gun() -> Drone:
	for i in escorts.size():
		var drone := escorts[(_escort_turn + i) % escorts.size()]
		if is_instance_valid(drone):
			return drone
	return null


func _after_shot() -> void:
	var drone := _escort_gun()
	if drone != null:
		drone.kick()
		_escort_turn = (_escort_turn + 1) % escorts.size()


func _muzzle_offset() -> Vector2:
	var gun := _escort_gun()
	if gun != null:
		return gun.global_position - global_position
	var muzzle: Vector2 = stats.muzzle
	var local := Vector2(muzzle.x * facing, muzzle.y)
	if _ceiling:
		# Kopfueber sitzt das Geschuetz unten am Koerper.
		return Vector2(muzzle.x * facing, -muzzle.y)
	if _clinging:
		return local.rotated(-_cling_dir * PI / 2.0)
	return local
