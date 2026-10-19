class_name Enemy
extends CharacterBody2D
## Gegner der Fabrik. Kein Kontaktschaden: Schaden entsteht nur durch Angriffe
## (Nahkampfschlag oder Geschoss), die vorher sichtbar angekuendigt werden.
## Gegner kollidieren nur mit der Welt, nicht mit Spielern oder anderen Gegnern.

signal died(enemy: Enemy)
signal fire_projectile(enemy: Enemy, origin: Vector2, direction: Vector2, speed: float, damage: float)

enum State { CHASE, WINDUP, COOLDOWN }

const GRAVITY := 2000.0
const MAX_FALL_SPEED := 1400.0
const SEPARATION_DISTANCE := 30.0

var kind := "walker"
var data: Dictionary = {}
var hp := 1.0
var max_hp := 1.0
var damage_scale := 1.0
var players: Array[Player] = []
var siblings: Array[Enemy] = []

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


func setup(new_kind: String, hp_scale: float, new_damage_scale: float, new_players: Array[Player]) -> void:
	kind = new_kind
	data = EnemyTypes.get_type(kind)
	max_hp = float(data.hp) * hp_scale
	hp = max_hp
	damage_scale = new_damage_scale
	players = new_players
	_phase = randf() * TAU
	_cooldown = randf_range(0.3, 1.2)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 0
	add_to_group("enemies")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = data.radius
	shape.shape = circle
	add_child(shape)

	var hurtbox := EnemyHurtbox.new()
	hurtbox.enemy = self
	hurtbox.collision_layer = 1 << 2
	hurtbox.collision_mask = 0
	var hurt_shape := CollisionShape2D.new()
	var hurt_circle := CircleShape2D.new()
	hurt_circle.radius = float(data.radius) + 3.0
	hurt_shape.shape = hurt_circle
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)


func take_damage(amount: float, _source: Node, direction := Vector2.ZERO) -> void:
	if _dead:
		return
	hp -= amount
	_flash = 0.08
	velocity += direction * 140.0 * float(data.knockback)
	Sfx.play("hit")
	if Fx.instance:
		Fx.instance.number(global_position + Vector2(0.0, -float(data.radius) - 8.0), amount)
	if hp <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	Sfx.play("kill")
	if Fx.instance:
		Fx.instance.spark(global_position, data.color, 14, 380.0)
	died.emit(self)
	queue_free()


func _physics_process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta)
	_slam_flash = maxf(0.0, _slam_flash - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	_pick_target()

	if data.movement == "fly":
		_fly_movement(delta)
	else:
		_ground_movement(delta)
	_apply_separation(delta)
	_update_attack(delta)
	move_and_slide()
	queue_redraw()


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
	var desired := 0.0
	if _target != null and _state != State.WINDUP:
		var offset := _target.global_position - global_position
		var direction := signf(offset.x)
		var distance := absf(offset.x)
		if data.attack == "ranged":
			var keep: float = data.keep_distance
			if distance > keep + 40.0:
				desired = direction
			elif distance < keep - 100.0:
				desired = -direction
		elif distance > float(data.reach) * 0.7:
			desired = direction
		# Springen: ueber Hindernisse und zu hoeher liegenden Spielern.
		if is_on_floor() and desired != 0.0:
			var player_above := offset.y < -70.0 and distance < 280.0
			if is_on_wall() or player_above:
				velocity.y = -float(data.jump)
	velocity.x = move_toward(velocity.x, desired * float(data.speed), 1400.0 * delta)


func _fly_movement(delta: float) -> void:
	var desired := Vector2.ZERO
	if _target != null and _state != State.WINDUP:
		var keep: float = data.keep_distance
		var orbit := Vector2(sin(_time * 0.8 + _phase) * keep, -170.0 + cos(_time * 1.3 + _phase) * 50.0)
		var goal := _target.global_position + orbit
		desired = (goal - global_position).limit_length(float(data.speed))
	velocity = velocity.lerp(desired, 1.0 - exp(-4.0 * delta))


func _apply_separation(delta: float) -> void:
	# Etwas Abstand zu anderen Gegnern, damit sie nicht zu einem Punkt verschmelzen.
	# Nur jeden dritten Frame pro Gegner, das spart Rechenzeit bei vielen Gegnern.
	if (Engine.get_physics_frames() + get_instance_id()) % 3 != 0:
		return
	var push := Vector2.ZERO
	for other in siblings:
		if other == self or not is_instance_valid(other):
			continue
		var offset := global_position - other.global_position
		var distance := offset.length()
		if distance < SEPARATION_DISTANCE and distance > 0.01:
			push += offset / distance * (SEPARATION_DISTANCE - distance)
	if data.movement == "fly":
		velocity += push * 20.0
	else:
		velocity.x += push.x * 20.0


func _update_attack(delta: float) -> void:
	match _state:
		State.CHASE:
			if _target == null or _cooldown > 0.0:
				return
			if _in_attack_range():
				_state = State.WINDUP
				_state_time = float(data.windup)
				_aim = (_target.global_position - global_position).normalized()
				Sfx.play("telegraph")
		State.WINDUP:
			_state_time -= delta
			# Zielrichtung folgt dem Spieler, friert aber kurz vor dem Angriff ein.
			var lock: float = data.get("lock_time", 0.0)
			if _target != null and _state_time > lock:
				_aim = (_target.global_position - global_position).normalized()
			if _state_time <= 0.0:
				_execute_attack()
				_state = State.COOLDOWN
				_cooldown = float(data.cooldown)
				_state_time = 0.0
		State.COOLDOWN:
			if _cooldown <= 0.0:
				_state = State.CHASE


func _in_attack_range() -> bool:
	var distance := global_position.distance_to(_target.global_position)
	if data.attack == "melee":
		return distance <= float(data.reach) + 10.0
	return distance <= float(data.range)


func _execute_attack() -> void:
	var damage := float(data.damage) * damage_scale
	if data.attack == "ranged":
		Sfx.play("enemy_shoot")
		fire_projectile.emit(self, global_position + _aim * (float(data.radius) + 6.0), _aim, float(data.projectile_speed), damage)
		return

	_slam_flash = 0.12
	if data.melee_shape == "circle":
		Sfx.play("slam")
	for player in players:
		if player.downed:
			continue
		var to_player := player.global_position - global_position
		var in_reach := to_player.length() <= float(data.reach) + float(player.stats.radius)
		var in_front: bool = data.melee_shape == "circle" or _aim.dot(to_player.normalized()) > 0.2
		if in_reach and in_front:
			player.take_hit(damage, global_position)
	if Fx.instance:
		Fx.instance.ring(global_position + _aim * 20.0, float(data.reach), Color(data.color, 0.9))


func _draw() -> void:
	var r: float = data.radius
	var color: Color = data.color
	if _flash > 0.0:
		color = Color.WHITE
	_draw_telegraph(r)
	match kind:
		"flyer":
			var points := PackedVector2Array([Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])
			draw_colored_polygon(points, color)
			var wing := sin(_time * 40.0) * 4.0
			draw_line(Vector2(-r - 6.0, -r * 0.6 + wing), Vector2(r + 6.0, -r * 0.6 - wing), Color(1, 1, 1, 0.6), 2.0)
		"brute":
			draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), color)
			draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), Color(0.25, 0.05, 0.1), false, 4.0)
		_:
			draw_circle(Vector2.ZERO, r, color)
			if kind == "shooter":
				draw_line(Vector2.ZERO, _aim * (r + 10.0), Color(0.3, 0.1, 0.4), 5.0)
	# Boese Augen der Fabrik-Roboter.
	var eye_dir := Vector2(signf(_aim.x) * 2.0, 0.0)
	draw_circle(Vector2(-r * 0.35, -r * 0.2) + eye_dir, r * 0.15, Color(1.0, 0.15, 0.15))
	draw_circle(Vector2(r * 0.35, -r * 0.2) + eye_dir, r * 0.15, Color(1.0, 0.15, 0.15))
	if hp < max_hp and (kind == "brute" or hp < max_hp * 0.99):
		var width := r * 2.0
		draw_rect(Rect2(-r, -r - 12.0, width, 4.0), Color(0.15, 0.15, 0.15))
		draw_rect(Rect2(-r, -r - 12.0, width * clampf(hp / max_hp, 0.0, 1.0), 4.0), Color(0.9, 0.3, 0.3))


func _draw_telegraph(r: float) -> void:
	if _state != State.WINDUP:
		return
	var progress := 1.0 - _state_time / float(data.windup)
	if data.attack == "ranged":
		# Schusslinie, die kurz vor dem Schuss aufleuchtet.
		var length := float(data.range)
		var alpha := 0.2 + 0.6 * progress
		draw_line(_aim * r, _aim * length, Color(1.0, 0.3, 0.3, alpha), 2.0 + 3.0 * progress)
	elif data.melee_shape == "circle":
		var reach: float = data.reach
		draw_circle(Vector2.ZERO, reach * progress, Color(1.0, 0.2, 0.2, 0.25))
		draw_arc(Vector2.ZERO, reach, 0.0, TAU, 48, Color(1.0, 0.3, 0.3, 0.8), 3.0)
	else:
		var reach: float = data.reach
		var angle := _aim.angle()
		var fill := Color(1.0, 0.3, 0.3, 0.15 + 0.35 * progress)
		var points := PackedVector2Array([Vector2.ZERO])
		for i in 9:
			var a := angle - 0.9 + 1.8 * i / 8.0
			points.append(Vector2(cos(a), sin(a)) * reach * (0.4 + 0.6 * progress))
		draw_colored_polygon(points, fill)
