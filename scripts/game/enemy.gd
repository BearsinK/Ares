class_name Enemy
extends CharacterBody2D
## Gegner der Fabrik. Kein Kontaktschaden: Schaden entsteht nur durch Angriffe
## (Nahkampfschlag oder Geschoss), die vorher sichtbar angekuendigt werden.
## Gegner kollidieren nur mit der Welt, nicht mit Spielern oder anderen Gegnern.

signal died(enemy: Enemy)
signal fire_projectile(enemy: Enemy, origin: Vector2, direction: Vector2, speed: float, damage: float)
signal stuck(enemy: Enemy)
signal strike_requested(enemy: Enemy, position: Vector2, radius: float, delay: float, damage: float)
## Nest: bittet den Director, count Gegner der Art kind in die Welt zu setzen.
signal spawn_requested(enemy: Enemy, kind: String, count: int)

enum State { CHASE, WINDUP, COOLDOWN, CHARGE }

const GRAVITY := 2000.0
const MAX_FALL_SPEED := 1400.0
const SEPARATION_DISTANCE := 30.0
const ELITE_HP_MULT := 3.5
const ELITE_SCALE := 1.35
## Waechter (Mini-Boss am Ende jeder Karte): noch groesser und deutlich zaeher als eine Elite.
const CHAMPION_HP_MULT := 5.0
const CHAMPION_SCALE := 1.9
const FROST_RADIUS := 230.0
## Anteil des Schadens, der durch einen Frontschild kommt.
const BLOCK_PASS := 0.2

var kind := "walker"
var data: Dictionary = {}
var hp := 1.0
var max_hp := 1.0
var damage_scale := 1.0
## Elite: groesser, zaeher, gefaehrlicher, laesst mehr Beute und ein Reparaturkit fallen.
var elite := false
## Waechter: Elite mit eigener Lebensleiste im HUD und garantierter Belohnung.
var champion := false
## Hat sich selbst gesprengt (Sprengi): keine Beute.
var suicide := false
## Von einem Nest gesetzt: keine Beute und kein Kill.
var minion := false
var _minions: Array = []
var _block_flash := 0.0
var _wounded_cache: Array = []
var _wounded_stamp := -1000
## Art der Elite (fire, shield, storm, frost), siehe EnemyTypes.ELITE_KINDS.
var elite_kind := ""
var shield := 0.0
## Vom Director gesetzt: false, wenn der Gegner ausserhalb des Bildes ist (spart Zeichenzeit).
var on_screen := true
## Tempo-Faktor aus dem Wellen-Modifikator.
var speed_mult := 1.0
var max_shield := 0.0
var body_scale := 1.0
var players: Array[Player] = []
var siblings: Array[Enemy] = []
var grid: EnemyGrid = null

var _state := State.CHASE
var _state_time := 0.0
var _cooldown := 0.0
var _target: Player = null
var _aim := Vector2.RIGHT
var _flash := 0.0
var _phase := 0.0
var _time := 0.0
var _dead := false
var _slam_flash := 0.0
var statuses: StatusEffects
var _facing := 1.0
var _walk_phase := 0.0
var _charge_dir := 1.0
var _elite_timer := 2.0
var _elite_warn := 0.0
var _charge_hit: Array[Player] = []
var _hurt_time := 0.0
var _fire_flash := 0.0
var _squash := 0.0
var _jump_cooldown := 0.0
var _stuck_time := 0.0
## Betaeubt (z.B. im Roomba-Wirbel): keine Angriffe, keine eigene Bewegung.
var stunned_time := 0.0
var _fall_speed := 0.0
var _was_grounded := false


func setup(new_kind: String, hp_scale: float, new_damage_scale: float, new_players: Array[Player], new_elite := false, new_elite_kind := "", new_champion := false) -> void:
	kind = new_kind
	data = EnemyTypes.get_type(kind)
	champion = new_champion
	elite = new_elite or champion
	elite_kind = (new_elite_kind if new_elite_kind != "" else EnemyTypes.random_elite_kind()) if elite else ""
	body_scale = CHAMPION_SCALE if champion else (ELITE_SCALE if elite else 1.0)
	if champion:
		# Waechter haben einen festen Lebenswert je Typ (Rammtank und Moerser sind von Haus aus zerbrechlicher als der Brute).
		max_hp = float(data.get("champion_hp", float(data.hp) * CHAMPION_HP_MULT)) * hp_scale
	else:
		max_hp = float(data.hp) * hp_scale * (ELITE_HP_MULT if elite else 1.0)
	hp = max_hp
	if elite_kind == "shield":
		max_shield = max_hp * 0.6
		shield = max_shield
	damage_scale = new_damage_scale * (1.25 if elite else 1.0)
	players = new_players
	_phase = randf() * TAU
	_cooldown = randf_range(0.3, 1.2)
	statuses = StatusEffects.new(self)


func _ready() -> void:
	floor_snap_length = 12.0
	floor_max_angle = deg_to_rad(52.0)
	collision_layer = 0
	collision_mask = (1 << 0) | (1 << 5) if data.movement == "ground" else (1 << 0)
	add_to_group("enemies")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius()
	shape.shape = circle
	add_child(shape)

	var hurtbox := EnemyHurtbox.new()
	hurtbox.enemy = self
	hurtbox.collision_layer = 1 << 2
	hurtbox.collision_mask = 0
	var hurt_shape := CollisionShape2D.new()
	var hurt_circle := CircleShape2D.new()
	hurt_circle.radius = radius() + 3.0
	hurt_shape.shape = hurt_circle
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)


## element: Element der Waffe ("" = neutral). from_effect: Schaden aus einem Status
## oder einer Kombo, loest selbst keine weiteren Element-Effekte aus.
func take_damage(amount: float, source: Node, direction := Vector2.ZERO, element := "", from_effect := false) -> void:
	if _dead:
		return
	if source is Player and not from_effect:
		amount *= source.hit_multiplier(self)
	if element != "" and not from_effect:
		amount = statuses.process_hit(element, source, amount)
		if _dead:
			return
	# Schild schluckt Schaden, bis er gebrochen ist.
	if shield > 0.0:
		shield -= amount
		amount = 0.0
		if shield <= 0.0:
			amount = -shield
			shield = 0.0
			if Fx.instance:
				Fx.instance.ring(global_position, radius() + 20.0, Color(0.5, 0.85, 1.0))
			Sfx.play("freeze")
	hp -= amount
	_flash = 0.08
	_hurt_time = 0.25
	velocity += direction * 140.0 * float(data.knockback)
	Sfx.play("hit")
	if Fx.instance:
		Fx.instance.number(global_position + Vector2(0.0, -radius() - 8.0), amount, Elements.color_of(element, Color(1, 1, 0.5)))
	if hp > 0.0 and source is Player and not from_effect and float(source.mods.arc) > 0.0:
		_arc_proc(source, amount)
	if hp <= 0.0:
		_die()


## Frontschild (Aegis): Ein Direkttreffer von vorn wird abgefangen. Gemeint ist Flugrichtung gegen die Blickrichtung,
## nicht steil von oben oder unten. Ohne Richtung (Sprengung, Faehigkeit, Effekt) und im Betaeubt-Zustand geht alles durch.
func is_blocking(direction: Vector2) -> bool:
	if not bool(data.get("frontal_shield", false)) or stunned_time > 0.0 or _dead or direction.length_squared() < 0.0001:
		return false
	var heading := direction.normalized()
	return heading.x * _facing < -0.35 and absf(heading.y) < 0.8


func on_blocked(direction: Vector2) -> void:
	_block_flash = 1.0
	Sfx.play("block", 0.1)
	if Fx.instance:
		Fx.instance.spark(global_position + Vector2(_facing * radius() * 0.9, -radius() * 0.2), Color(0.6, 0.9, 1.0), 4, 260.0)
		Fx.instance.number_text(global_position + Vector2(0.0, -radius() - 14.0), "Block", Color(0.6, 0.85, 1.0), 15, 0.45)


## Lebende Buzzer dieses Nests.
func alive_minions() -> int:
	_minions = _minions.filter(func(m: Variant) -> bool: return is_instance_valid(m) and not m._dead)
	return _minions.size()


func adopt(minion_enemy: Enemy) -> void:
	minion_enemy.minion = true
	_minions.append(minion_enemy)


## Arc Coil: ein Treffer springt auf den naechsten Gegner in der Naehe.
func _arc_proc(source: Player, amount: float) -> void:
	if randf() >= Perks.ARC_CHANCE * float(source.mods.arc):
		return
	var best: Enemy = null
	var best_distance := Perks.ARC_RANGE
	for other in siblings:
		if other == self or not is_instance_valid(other) or other._dead:
			continue
		var distance := other.global_position.distance_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = other
	if best == null:
		return
	if Fx.instance:
		Fx.instance.tracer(global_position, best.global_position, Color(0.95, 0.9, 0.35), 3.0, 0.15)
	Sfx.play("zap", 0.1)
	best.take_damage(maxf(1.0, amount * Perks.ARC_DAMAGE), source, Vector2.ZERO, "", true)


func stun(duration: float) -> void:
	stunned_time = maxf(stunned_time, duration)


func radius() -> float:
	return float(data.radius) * body_scale


func reach() -> float:
	return float(data.reach) * body_scale


func _die() -> void:
	_dead = true
	for follower in _minions:
		if is_instance_valid(follower) and not follower._dead:
			follower.take_damage(1.0e9, null, Vector2.ZERO, "", true)
	Sfx.play("kill")
	if Fx.instance:
		Fx.instance.spark(global_position, data.color, 36 if elite else 14, 520.0 if elite else 380.0)
		_spawn_gibs()
		if elite:
			Fx.instance.explosion(global_position, 90.0, Color(1.0, 0.85, 0.3))
	died.emit(self)
	queue_free()


## Truemmer beim Tod: Platten in Gegnerfarbe, Raeder und Schrauben fliegen davon.
func _spawn_gibs() -> void:
	if not on_screen or Fx.instance == null:
		return
	var r := radius()
	var crowded := siblings.size() > 30
	var plates := (2 if crowded else ((7 if elite else 4) + (3 if kind == "brute" else 0)))
	for i in plates:
		Fx.instance.gib(global_position, Color(data.color).darkened(randf_range(0.0, 0.35)), "plate", randf_range(0.5, 0.9) * r, 420.0 + r * 4.0)
	if kind != "flyer":
		for i in 2:
			Fx.instance.gib(global_position + Vector2((i * 2 - 1) * r * 0.5, r * 0.4), Color.WHITE, "wheel", r * 0.8, 300.0)
	for i in (2 if crowded else 5):
		Fx.instance.gib(global_position, Color.WHITE, "bolt", 6.0, 500.0)


func _physics_process(delta: float) -> void:
	_time += delta
	_hurt_time = maxf(0.0, _hurt_time - delta)
	_fire_flash = maxf(0.0, _fire_flash - delta * 5.0)
	_squash = maxf(0.0, _squash - delta * 6.0)
	_jump_cooldown = maxf(0.0, _jump_cooldown - delta)
	stunned_time = maxf(0.0, stunned_time - delta)
	if stunned_time > 0.0 and (_state == State.WINDUP or _state == State.CHARGE):
		_state = State.COOLDOWN
		_cooldown = maxf(_cooldown, 0.6)
	_flash = maxf(0.0, _flash - delta)
	_block_flash = maxf(0.0, _block_flash - delta * 6.0)
	_slam_flash = maxf(0.0, _slam_flash - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	statuses.update(delta)
	if _dead:
		return
	_pick_target()
	if _target != null:
		var to_target := _target.global_position - global_position
		if absf(to_target.x) > 4.0:
			_facing = signf(to_target.x)
		if _state != State.WINDUP and _state != State.CHARGE:
			_aim = to_target.normalized()
	_walk_phase += velocity.x * _facing * delta * 0.12
	if statuses.is_frozen():
		_frozen_physics(delta)
		return

	if data.movement == "fly":
		_fly_movement(delta)
	else:
		_ground_movement(delta)
	_apply_separation(delta)
	_update_attack(delta)
	_update_elite(delta)
	if not is_on_floor():
		_fall_speed = maxf(_fall_speed, velocity.y)
	move_and_slide()
	if is_on_floor() and not _was_grounded and _fall_speed > 350.0 and data.movement == "ground":
		_squash = clampf(_fall_speed / 900.0, 0.3, 1.0)
		if Fx.instance and on_screen:
			Fx.instance.spark(global_position + Vector2(0.0, radius()), Color(0.75, 0.77, 0.82, 0.7), 3, 120.0)
	if is_on_floor():
		_fall_speed = 0.0
	_was_grounded = is_on_floor()
	_maybe_redraw()


func _frozen_physics(delta: float) -> void:
	# Eingefroren: steht still, ein laufender Angriff wird abgebrochen.
	if _state == State.WINDUP or _state == State.CHARGE:
		_state = State.COOLDOWN
		_cooldown = float(data.cooldown) * 0.5
	if data.movement == "fly":
		velocity = velocity.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * delta))
	else:
		velocity.x = move_toward(velocity.x, 0.0, 2500.0 * delta)
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	move_and_slide()
	_maybe_redraw()


## Zeichnet nur, was im Bild ist. Je mehr Gegner da sind, desto seltener wird ihre Figur neu
## gezeichnet (Position und Bewegung laufen weiter jeden Frame, nur die Innenanimation wird
## gröber). Bei Angriffen, Treffern und Zustandswechseln wird immer sofort gezeichnet.
func _maybe_redraw() -> void:
	if not on_screen:
		return
	var count := siblings.size()
	var interval := 1 if count <= 12 else (2 if count <= 25 else (3 if count <= 45 else 4))
	if interval > 1 and not _needs_smooth_redraw():
		if (Engine.get_physics_frames() + get_instance_id()) % interval != 0:
			return
	queue_redraw()


func _needs_smooth_redraw() -> bool:
	return _flash > 0.0 or _hurt_time > 0.0 or _fire_flash > 0.0 or _slam_flash > 0.0 or _squash > 0.0 or _block_flash > 0.0 \
		or stunned_time > 0.0 or _state == State.WINDUP or _state == State.CHARGE or elite


func _pick_target() -> void:
	_target = null
	var best := INF
	for player in players:
		if player.downed:
			continue
		var distance := global_position.distance_squared_to(player.global_position)
		if distance < best:
			best = distance
			_target = player


func _ground_movement(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	if _state == State.CHARGE:
		velocity.x = _charge_dir * float(data.charge_speed)
		return
	var desired := 0.0
	if _target != null and _state != State.WINDUP and stunned_time <= 0.0:
		var offset := _target.global_position - global_position
		var direction := signf(offset.x)
		var distance := absf(offset.x)
		if data.attack != "melee":
			var keep: float = data.keep_distance
			if distance > keep + 40.0:
				desired = direction
			elif distance < keep - 100.0:
				desired = -direction
			if data.attack == "heal":
				# Medic: zu verwundeten Verbuendeten laufen, solange der Spieler nicht zu nah ist.
				var patient := _nearest_wounded(900.0)
				if patient != null and absf(patient.global_position.x - global_position.x) > float(data.range) * 0.55 and distance > keep - 220.0:
					desired = signf(patient.global_position.x - global_position.x)
		elif distance > reach() * 0.7:
			desired = direction
		# Springen: ueber Hindernisse und zu hoeher liegenden Spielern.
		# Nur selten und nur, wenn es wirklich noetig ist (Hindernis oder Spieler deutlich hoeher).
		if is_on_floor() and desired != 0.0 and _jump_cooldown <= 0.0:
			var player_above := offset.y < -120.0 and distance < 220.0
			if is_on_wall() or player_above:
				velocity.y = -float(data.jump)
				_jump_cooldown = randf_range(1.0, 1.8)
				_squash = 0.0
		# Steckt unter einem Spieler auf einer hoeheren Ebene fest: nach einigen Sekunden woanders neu starten.
		if offset.y < -170.0 and absf(offset.x) < 320.0 and is_on_floor():
			_stuck_time += delta
			if _stuck_time > 5.0:
				_stuck_time = 0.0
				stuck.emit(self)
		else:
			_stuck_time = maxf(0.0, _stuck_time - delta)
	velocity.x = move_toward(velocity.x, desired * float(data.speed) * speed_mult * statuses.speed_factor(), 1400.0 * delta)


func _fly_movement(delta: float) -> void:
	var desired := Vector2.ZERO
	if _target != null and _state != State.WINDUP and stunned_time <= 0.0:
		var keep: float = data.keep_distance
		var orbit := Vector2(sin(_time * 0.8 + _phase) * keep, -170.0 + cos(_time * 1.3 + _phase) * 50.0)
		var goal := _target.global_position + orbit
		desired = (goal - global_position).limit_length(float(data.speed) * speed_mult * statuses.speed_factor())
	velocity = velocity.lerp(desired, 1.0 - exp(-4.0 * delta))


func _apply_separation(delta: float) -> void:
	# Etwas Abstand zu anderen Gegnern, damit sie nicht zu einem Punkt verschmelzen.
	# Nur jeden dritten Frame pro Gegner, das spart Rechenzeit bei vielen Gegnern.
	if (Engine.get_physics_frames() + get_instance_id()) % 3 != 0:
		return
	var push := Vector2.ZERO
	var neighbors: Array = grid.near(global_position) if grid != null and siblings.size() > 8 else siblings
	for other: Enemy in neighbors:
		if other == self or not is_instance_valid(other):
			continue
		var offset: Vector2 = global_position - other.global_position
		var distance: float = offset.length()
		if distance < SEPARATION_DISTANCE and distance > 0.01:
			push += offset / distance * (SEPARATION_DISTANCE - distance)
	if data.movement == "fly":
		velocity += push * 20.0
	else:
		velocity.x += push.x * 20.0


func _update_attack(delta: float) -> void:
	if stunned_time > 0.0:
		return
	match _state:
		State.CHASE:
			if _target == null or _cooldown > 0.0:
				return
			if _in_attack_range():
				_state = State.WINDUP
				_state_time = float(data.windup)
				_aim = (_target.global_position - global_position).normalized()
				Sfx.play("fuse" if data.get("suicide", false) else "telegraph")
		State.WINDUP:
			_state_time -= delta
			# Zielrichtung folgt dem Spieler, friert aber kurz vor dem Angriff ein.
			var lock: float = data.get("lock_time", 0.0)
			if _target != null and _state_time > lock:
				_aim = (_target.global_position - global_position).normalized()
			if _state_time <= 0.0:
				if data.attack == "charge":
					_start_charge()
					return
				_execute_attack()
				_state = State.COOLDOWN
				_cooldown = float(data.cooldown)
				_state_time = 0.0
		State.CHARGE:
			_update_charge(delta)
		State.COOLDOWN:
			if _cooldown <= 0.0:
				_state = State.CHASE


## Eigene Mechanik der Elite-Art.
func _update_elite(delta: float) -> void:
	if not elite or _target == null or stunned_time > 0.0:
		return
	match elite_kind:
		"fire":
			_elite_timer -= delta
			if _elite_timer <= 0.0:
				_elite_timer = 3.5
				strike_requested.emit(self, global_position + Vector2(0.0, radius() * 0.6), 70.0, 0.9, 12.0 * damage_scale)
		"storm":
			_elite_timer -= delta
			if _elite_timer <= 0.0 and _state != State.WINDUP:
				_elite_timer = 4.2
				_elite_warn = 0.7
			if _elite_warn > 0.0:
				_elite_warn -= delta
				if _elite_warn <= 0.0:
					var base := (_target.global_position - global_position).normalized()
					for k in 3:
						var dir := base.rotated((k - 1) * 0.28)
						fire_projectile.emit(self, global_position + dir * (radius() + 8.0), dir, 320.0, 7.0 * damage_scale)
					Sfx.play("zap")
		"frost":
			for player in players:
				if not player.downed and player.global_position.distance_to(global_position) <= FROST_RADIUS:
					player.slow_time = 0.25


func _in_attack_range() -> bool:
	if data.attack == "heal":
		return not _wounded_allies().is_empty()
	var distance := global_position.distance_to(_target.global_position)
	if data.attack == "melee":
		return distance <= reach() + 10.0
	if data.attack == "charge":
		# Nur, wenn der Spieler ungefaehr auf gleicher Hoehe steht.
		return distance <= float(data.range) and absf(_target.global_position.y - global_position.y) < 110.0
	return distance <= float(data.range)


func _start_charge() -> void:
	_state = State.CHARGE
	_state_time = float(data.charge_time)
	_charge_dir = signf(_aim.x) if absf(_aim.x) > 0.01 else _facing
	_facing = _charge_dir
	_charge_hit.clear()
	Sfx.play("dash")


func _update_charge(delta: float) -> void:
	_state_time -= delta
	var damage := float(data.damage) * damage_scale
	for player in players:
		if player.downed or _charge_hit.has(player):
			continue
		var offset := player.global_position - global_position
		if absf(offset.x) <= radius() + float(player.stats.size.x) * 0.5 + 4.0 and absf(offset.y) <= radius() + float(player.stats.size.y) * 0.5:
			_charge_hit.append(player)
			player.take_hit(damage, global_position)
	if Fx.instance and fmod(_time, 0.06) < delta:
		Fx.instance.spark(global_position + Vector2(-_charge_dir * radius(), radius() * 0.8), Color(1.0, 0.7, 0.3), 2, 160.0)
	# Gegen eine Wand zu laufen beendet den Ansturm sofort.
	if _state_time <= 0.0 or is_on_wall():
		_state = State.COOLDOWN
		_cooldown = float(data.cooldown)
		velocity.x *= 0.2
		if Fx.instance and on_screen:
			Fx.instance.spark(global_position + Vector2(_charge_dir * radius() * 0.6, radius() * 0.9), Color(0.8, 0.78, 0.72, 0.8), 8, 220.0)


## Verwundete Verbuendete in Reichweite (ohne mich selbst), die meisten fehlenden Leben zuerst.
func _wounded_allies() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for other in _wounded_list():
		if other.global_position.distance_to(global_position) <= float(data.range):
			result.append(other)
	return result.slice(0, int(data.heal_targets))


## Verwundete Verbuendete im weiteren Umkreis, hoechstens alle 0,25 s neu gesucht (spart Zeit bei vielen Gegnern).
func _wounded_list() -> Array[Enemy]:
	var now := Time.get_ticks_msec()
	if now - _wounded_stamp < 250:
		# Zwischen zwei Suchen koennen Eintraege gestorben und freigegeben sein.
		var alive: Array[Enemy] = []
		for cached in _wounded_cache:
			if is_instance_valid(cached) and not cached._dead:
				alive.append(cached)
		return alive
	_wounded_stamp = now
	var found: Array[Enemy] = []
	for other in siblings:
		if other == self or not is_instance_valid(other) or other._dead or other.hp >= other.max_hp * 0.8:
			continue
		if other.global_position.distance_to(global_position) <= 900.0:
			found.append(other)
	found.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.max_hp - a.hp > b.max_hp - b.hp)
	_wounded_cache = found
	return found


func _nearest_wounded(max_distance: float) -> Enemy:
	var best: Enemy = null
	var best_distance := max_distance
	for other in _wounded_list():
		var distance := other.global_position.distance_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = other
	return best


func _execute_attack() -> void:
	var damage := float(data.damage) * damage_scale
	if data.attack == "heal":
		Sfx.play("heal")
		_fire_flash = 1.0
		for ally in _wounded_allies():
			var amount := ally.max_hp * float(data.heal_amount) * (0.35 if ally.champion else 1.0)
			ally.hp = minf(ally.max_hp, ally.hp + amount)
			ally._flash = 0.1
			if Fx.instance:
				Fx.instance.tracer(global_position + Vector2(0.0, -radius() * 0.5), ally.global_position, Color(0.4, 1.0, 0.55), 3.0, 0.3)
				Fx.instance.number(ally.global_position + Vector2(0.0, -ally.radius() - 14.0), amount, Color(0.5, 1.0, 0.6))
		if Fx.instance:
			Fx.instance.ring(global_position, float(data.range) * 0.5, Color(0.4, 1.0, 0.55))
		return
	if data.attack == "spawn":
		Sfx.play("heal", 0.2)
		_fire_flash = 1.0
		spawn_requested.emit(self, String(data.spawn_kind), int(data.spawn_count))
		return
	if data.attack == "strike":
		Sfx.play("enemy_shoot")
		# Zielt leicht vor den Spieler, damit stehenbleiben bestraft wird.
		var lead := _target.velocity * 0.35 if _target != null else Vector2.ZERO
		var spot := (_target.global_position if _target != null else global_position + _aim * 300.0) + Vector2(lead.x, 0.0)
		strike_requested.emit(self, spot, float(data.strike_radius), float(data.strike_delay), damage)
		_fire_flash = 1.0
		return
	if data.attack == "ranged":
		Sfx.play("enemy_shoot")
		fire_projectile.emit(self, global_position + _aim * (radius() + 6.0), _aim, float(data.projectile_speed), damage)
		_fire_flash = 1.0
		return

	_slam_flash = 0.12
	if data.melee_shape == "circle":
		Sfx.play("slam")
	for player in players:
		if player.downed:
			continue
		var to_player := player.global_position - global_position
		var in_reach := to_player.length() <= reach() + float(player.stats.radius)
		var in_front: bool = data.melee_shape == "circle" or _aim.dot(to_player.normalized()) > 0.2
		if in_reach and in_front:
			player.take_hit(damage, global_position)
	if Fx.instance:
		Fx.instance.ring(global_position + _aim * 20.0, reach(), Color(data.color, 0.9))
	if bool(data.get("suicide", false)):
		# Sprengi: Selbstsprengung, dabei fliegen die Teile. Elites geben ihre Beute trotzdem her.
		suicide = not elite
		if Fx.instance:
			Fx.instance.explosion(global_position, reach(), Color(1.0, 0.6, 0.2))
		Sfx.play("explosion", 0.1)
		_die()


func _draw() -> void:
	var r := radius()
	_draw_telegraph(r)
	statuses.draw_overlay(self, r, _time)
	var windup := -1.0
	if _state == State.WINDUP:
		windup = 1.0 - _state_time / float(data.windup)
	var charging := _state == State.CHARGE
	if elite:
		_draw_elite_aura(r)
	var grow := 1.0 - pow(1.0 - clampf(_time / 0.3, 0.0, 1.0), 3.0)
	RobotArt.draw_enemy(self, kind, {
		"facing": _facing, "aim": _aim, "t": _time, "walk": _walk_phase,
		"flash": _flash > 0.0, "windup": windup, "slam": _slam_flash > 0.0 or charging,
		"vx": velocity.x, "grounded": is_on_floor(), "hurt": _hurt_time / 0.25, "fire": _fire_flash,
		"hp_frac": hp / max_hp, "foot": float(data.radius), "lod": siblings.size() > 40 and not elite,
		"squash": _draw_squash(), "block": _block_flash,
	}, Vector2.ZERO, body_scale * maxf(grow, 0.05))
	if elite:
		_draw_crown(r)
	if windup >= 0.0 and stunned_time <= 0.0 and data.attack != "strike" and data.attack != "heal" and data.attack != "spawn":
		_draw_alert(r, windup)
	if stunned_time > 0.0:
		# Betaeubt: drei Sterne kreisen ueber dem Kopf.
		for k in 3:
			var ang := _time * 7.0 + k * TAU / 3.0
			var star := Vector2(cos(ang) * r * 0.7, -r - 12.0 + sin(ang) * 4.0)
			draw_circle(star, 3.0, Color(0.6, 1.0, 0.95))
			draw_circle(star, 5.0, Color(0.6, 1.0, 0.95, 0.3))
	if elite or (hp < max_hp and (kind == "brute" or hp < max_hp * 0.99)):
		var width := maxf(r * 2.0, 30.0)
		var top := -r - (22.0 if kind == "brute" or elite else 14.0) - (10.0 if elite else 0.0)
		draw_rect(Rect2(-width * 0.5, top, width, 5.0), Color(0.08, 0.08, 0.1, 0.85))
		draw_rect(Rect2(-width * 0.5, top, width * clampf(hp / max_hp, 0.0, 1.0), 5.0), Color(0.9, 0.3, 0.3))
		if shield > 0.0:
			draw_rect(Rect2(-width * 0.5, top, width * clampf(shield / max_shield, 0.0, 1.0), 5.0), Color(0.45, 0.8, 1.0))
		draw_rect(Rect2(-width * 0.5, top, width, 5.0), Color(1, 1, 1, 0.3), false, 1.0)
		if elite and elite_kind != "":
			draw_string(ThemeDB.fallback_font, Vector2(-60.0, top - 4.0), EnemyTypes.ELITE_KINDS[elite_kind].name, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 11, Color(_elite_color(), 0.95))


## Landen staucht, in der Luft streckt sich der Gegner leicht.
func _draw_squash() -> Vector2:
	if _squash > 0.0:
		return Vector2(1.0 + 0.2 * _squash, 1.0 - 0.24 * _squash)
	if data.movement == "ground" and not is_on_floor():
		var stretch := clampf(absf(velocity.y) / 1500.0, 0.0, 0.12)
		return Vector2(1.0 - 0.6 * stretch, 1.0 + stretch)
	return Vector2.ONE


func _elite_color() -> Color:
	return EnemyTypes.ELITE_KINDS[elite_kind].color if elite_kind != "" else Color(1.0, 0.8, 0.25)


func _draw_elite_aura(r: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	var color := _elite_color()
	Art.glow(self, Vector2.ZERO, r * 2.2, color)
	draw_arc(Vector2.ZERO, r + 8.0 + pulse * 3.0, 0.0, TAU, 36, Color(color, 0.55 + 0.3 * pulse), 2.5, true)
	if elite_kind == "frost":
		draw_arc(Vector2.ZERO, FROST_RADIUS, 0.0, TAU, 64, Color(color, 0.3), 2.0, true)
		draw_circle(Vector2.ZERO, FROST_RADIUS, Color(color, 0.05))
	elif elite_kind == "storm" and _elite_warn > 0.0:
		var k := 1.0 - _elite_warn / 0.7
		draw_arc(Vector2.ZERO, r + 10.0 + 40.0 * k, 0.0, TAU, 32, Color(color, 0.9 * (1.0 - k)), 3.0, true)
	elif elite_kind == "shield" and shield > 0.0:
		var alpha := 0.18 + 0.3 * (shield / max_shield)
		draw_circle(Vector2.ZERO, r + 12.0, Color(color, alpha * 0.6))
		draw_arc(Vector2.ZERO, r + 12.0, 0.0, TAU, 36, Color(color, 0.5 + alpha), 3.0, true)


func _draw_crown(r: float) -> void:
	var y := -r - 14.0
	var gold := _elite_color().lerp(Color(1.0, 0.85, 0.3), 0.5)
	var points := PackedVector2Array([Vector2(-10, y), Vector2(-10, y - 10), Vector2(-5, y - 5), Vector2(0, y - 13), Vector2(5, y - 5), Vector2(10, y - 10), Vector2(10, y)])
	draw_colored_polygon(points, gold)
	draw_polyline(points, Art.OUTLINE, 1.5, true)


## Warndreieck ueber dem Kopf: dieser Gegner greift gleich an.
func _draw_alert(r: float, progress: float) -> void:
	var top := -r - (50.0 if elite or kind == "brute" else 36.0)
	var pulse := 1.0 + 0.18 * sin(_time * 18.0) * progress
	var c := Vector2(0.0, top)
	var tri := PackedVector2Array([c + Vector2(0.0, -11.0) * pulse, c + Vector2(-10.0, 7.0) * pulse, c + Vector2(10.0, 7.0) * pulse])
	var outline := PackedVector2Array([c + Vector2(0.0, -15.0) * pulse, c + Vector2(-14.0, 10.0) * pulse, c + Vector2(14.0, 10.0) * pulse])
	draw_colored_polygon(outline, Color(0.05, 0.02, 0.08, 0.85))
	draw_colored_polygon(tri, Color(1.0, 0.82, 0.15).lerp(Color(1.0, 0.3, 0.2), progress))
	draw_rect(Rect2(c + Vector2(-1.2, -5.0), Vector2(2.4, 7.0)), Color(0.08, 0.04, 0.1))
	draw_rect(Rect2(c + Vector2(-1.2, 3.5), Vector2(2.4, 2.4)), Color(0.08, 0.04, 0.1))


func _draw_telegraph(r: float) -> void:
	if _state != State.WINDUP:
		return
	var progress := 1.0 - _state_time / float(data.windup)
	if data.attack == "charge":
		var dir := Vector2(signf(_aim.x) if absf(_aim.x) > 0.01 else _facing, 0.0)
		var length := float(data.charge_speed) * float(data.charge_time)
		var rect := Rect2(Vector2(0.0 if dir.x > 0.0 else -length, -r * 0.9), Vector2(length, r * 1.8))
		draw_rect(rect, Color(1.0, 0.3, 0.2, 0.08 + 0.2 * progress))
		draw_rect(rect, Color(1.0, 0.35, 0.25, 0.4 + 0.4 * progress), false, 2.0)
	elif data.attack == "strike":
		return
	elif data.attack == "spawn":
		# Ring waechst um das Nest, bis die Luke aufspringt.
		draw_arc(Vector2(0.0, -r), (r + 14.0) * progress + 6.0, 0.0, TAU, 28, Color(0.7, 1.0, 0.35, 0.3 + 0.5 * progress), 3.0, true)
	elif data.attack == "heal":
		# Heilkreis waechst, gruene Linien zu den Verbuendeten, die gleich geheilt werden.
		var heal_range := float(data.range)
		draw_arc(Vector2.ZERO, heal_range * progress, 0.0, TAU, 40, Color(0.4, 1.0, 0.55, 0.35 + 0.4 * progress), 3.0, true)
		for ally in _wounded_allies():
			draw_line(Vector2(0.0, -r * 0.5), to_local(ally.global_position), Color(0.4, 1.0, 0.55, 0.25 + 0.45 * progress), 2.5, true)
		var plus := Vector2(0.0, -r - 30.0 - 4.0 * sin(_time * 10.0))
		draw_rect(Rect2(plus + Vector2(-9, -3), Vector2(18, 6)), Color(0.4, 1.0, 0.55))
		draw_rect(Rect2(plus + Vector2(-3, -9), Vector2(6, 18)), Color(0.4, 1.0, 0.55))
	elif data.attack == "ranged":
		# Schusslinie in der Farbe der Geschosse: wird kraeftiger, kurz vor dem Schuss weiss (Ziel verriegelt).
		var length := minf(float(data.range), 900.0)
		var locked := _state_time <= float(data.get("lock_time", 0.0))
		var alpha := 0.3 + 0.6 * progress
		var line_color := Color(1.0, 0.18, 0.5, alpha) if not locked else Color(1.0, 0.85, 0.9, 1.0)
		draw_line(_aim * r, _aim * length, Color(0.05, 0.02, 0.08, 0.45 * alpha), 5.0 + 3.0 * progress, true)
		draw_line(_aim * r, _aim * length, line_color, 2.0 + 3.0 * progress, true)
		# Laufende Pfeilspitzen zeigen die Flugrichtung.
		var offset := fposmod(_time * 260.0, 70.0)
		var d := r + 14.0 + offset
		while d < length:
			var tip := _aim * d
			var side := _aim.orthogonal() * 6.0
			draw_colored_polygon(PackedVector2Array([tip + _aim * 8.0, tip - side - _aim * 4.0, tip + side - _aim * 4.0]), Color(line_color, alpha * (1.0 - d / length)))
			d += 70.0
	elif data.melee_shape == "circle":
		var reach := reach()
		draw_circle(Vector2.ZERO, reach * progress, Color(1.0, 0.2, 0.2, 0.25))
		draw_arc(Vector2.ZERO, reach, 0.0, TAU, 48, Color(1.0, 0.3, 0.3, 0.8), 3.0)
	else:
		var reach := reach()
		var angle := _aim.angle()
		var fill := Color(1.0, 0.3, 0.3, 0.15 + 0.35 * progress)
		var points := PackedVector2Array([Vector2.ZERO])
		for i in 9:
			var a := angle - 0.9 + 1.8 * i / 8.0
			points.append(Vector2(cos(a), sin(a)) * reach * (0.4 + 0.6 * progress))
		draw_colored_polygon(points, fill)
