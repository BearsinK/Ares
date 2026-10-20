class_name Boss
extends Area2D
## Endboss "Der Schmelzer": ein Hochofen-Koloss am rechten Ende des Laufbands.
## Sein Panzer schluckt den Grossteil des Schadens, nur wenn der Kern offen ist
## (Vent-Phase) richtet man vollen Schaden an. Wasser und Eis schwaechen ihn,
## Feuer prallt ab. Er schickt Hindernisse aufs Band, feuert auf Spieler und
## laesst Glut regnen. Bei 66 und 33 Prozent Leben wechselt die Phase und das
## Band wird schneller.

signal died
signal phase_changed(phase: int)

const MAX_HP := 8000.0
const DAMAGE_SCALE := 1.6
const ARMOR := 0.25
const START_DELAY := 3.5
const TRANSITION_TIME := 2.2
const BELT_SPEEDS := [100.0, 135.0, 170.0]
const VENT_TIMES := [7.0, 6.0, 5.0]
const GAPS := [1.4, 1.0, 0.7]
const MUZZLE := Vector2(-250.0, -333.0)
const WEAK := {"water": 1.5, "ice": 1.25, "fire": 0.6}

const CYCLES := [
	["obstacles", "fire", "obstacles", "vent"],
	["obstacles", "rain", "obstacles", "fire", "vent"],
	["obstacles", "rain", "adds", "obstacles", "fire", "rain", "vent"],
]
# Hindernismuster pro Phase: Paare aus Typ und Zeitpunkt (Sekunden nach Start).
const PATTERNS := [
	[
		[["crate", 0.0], ["crate", 1.8], ["beam", 3.6]],
		[["stack", 0.0], ["beam", 2.2], ["crate", 4.2]],
		[["saw", 0.0], ["crate", 2.4], ["beam", 4.0]],
	],
	[
		[["crate", 0.0], ["beam", 1.4], ["crate", 2.8], ["beam", 4.2]],
		[["saw", 0.0], ["stack", 1.6], ["beam", 3.0]],
		[["beam", 0.0], ["crate", 1.3], ["saw", 2.6], ["stack", 4.0]],
	],
	[
		[["crate", 0.0], ["beam", 1.0], ["crate", 2.0], ["beam", 3.0], ["stack", 4.2]],
		[["saw", 0.0], ["beam", 1.2], ["saw", 2.4], ["crate", 3.6]],
		[["stack", 0.0], ["beam", 1.3], ["crate", 2.4], ["beam", 3.4], ["saw", 4.6]],
	],
]

var main: Node
var arena: BossArena
var hp := MAX_HP
var phase := 1
var open := false
var dying := false
var boss_name := "DER SCHMELZER"
var banner := ""
var banner_time := 0.0
var statuses: StatusEffects

var _time := 0.0
var _flash := 0.0
var _open_amount := 0.0
var _delay := START_DELAY
var _transition := 0.0
var _attack := ""
var _attack_time := 0.0
var _attack_length := 1.0
var _gap := 1.0
var _queue: Array[String] = []
var _steps: Array = []
var _shots: Array = []
var _look := Vector2.LEFT
var _death_time := 0.0
var _boom_timer := 0.0


func _ready() -> void:
	collision_layer = 1 << 2
	collision_mask = 0
	add_to_group("enemies")
	statuses = StatusEffects.new(self)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(340.0, 600.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -310.0)
	add_child(shape)
	_say("ENDBOSS: DER SCHMELZER", 3.2)
	if arena != null:
		arena.belt_speed = BELT_SPEEDS[0]


func is_invulnerable() -> bool:
	return _delay > 0.0 or _transition > 0.0 or dying


func _say(text: String, seconds := 2.0) -> void:
	banner = text
	banner_time = seconds


func take_damage(amount: float, source: Node, direction := Vector2.ZERO, element := "", from_effect := false) -> void:
	if dying:
		return
	if is_invulnerable():
		if Fx.instance:
			Fx.instance.spark(global_position + Vector2(-150.0, -300.0), Color(0.8, 0.8, 0.9), 2, 200.0)
		return
	if element != "" and not from_effect:
		amount = statuses.process_hit(element, source, amount)
	amount *= 1.0 if open else ARMOR
	amount *= float(WEAK.get(element, 1.0))
	hp -= amount
	_flash = 0.06
	Sfx.play("hit")
	if Fx.instance:
		var color := Elements.color_of(element, Color(1, 1, 0.5)) if open else Color(0.65, 0.68, 0.78)
		Fx.instance.number(global_position + Vector2(randf_range(-170.0, -60.0), randf_range(-420.0, -200.0)), amount, color, 24 if open else 18)
	if hp <= 0.0:
		_die()
		return
	var wanted := 1 if hp > MAX_HP * 0.66 else (2 if hp > MAX_HP * 0.33 else 3)
	if wanted > phase:
		_start_transition(wanted)


func _start_transition(new_phase: int) -> void:
	phase = new_phase
	_transition = TRANSITION_TIME
	open = false
	_attack = ""
	_queue.clear()
	_shots.clear()
	_gap = 1.0
	if arena != null:
		arena.belt_speed = BELT_SPEEDS[phase - 1]
	_say("PHASE %d: DAS BAND WIRD SCHNELLER!" % phase, 2.6)
	Sfx.play("explosion")
	if main != null and "camera" in main and main.camera != null:
		main.camera.add_shake(18.0)
	if Fx.instance:
		for i in 4:
			Fx.instance.explosion(global_position + Vector2(randf_range(-150.0, 150.0), randf_range(-560.0, -100.0)), 90.0, Color(1.0, 0.5, 0.2))
	phase_changed.emit(phase)


func _die() -> void:
	dying = true
	open = false
	hp = 0.0
	_attack = ""
	_shots.clear()
	_death_time = 3.2
	_say("BESIEGT!", 4.0)
	remove_from_group("enemies")
	set_deferred("monitorable", false)
	if arena != null:
		arena.clear_obstacles()
		arena.running = false
	Sfx.play("kill")


func _physics_process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta)
	banner_time = maxf(0.0, banner_time - delta)
	statuses.update(delta)
	_open_amount = move_toward(_open_amount, 1.0 if open else 0.0, delta * 2.5)
	_update_look()
	if dying:
		_update_dying(delta)
		queue_redraw()
		return
	if _delay > 0.0:
		_delay -= delta
	elif _transition > 0.0:
		_transition -= delta
	else:
		_update_attack(delta)
	_update_shots(delta)
	queue_redraw()


func _update_look() -> void:
	if main == null:
		return
	var best := INF
	for player in main.players:
		if player.downed:
			continue
		var offset: Vector2 = player.global_position - (global_position + Vector2(0.0, -480.0))
		if offset.length() < best:
			best = offset.length()
			_look = offset.normalized()


func _alive_players() -> Array[Player]:
	var result: Array[Player] = []
	if main == null:
		return result
	for player in main.players:
		if not player.downed:
			result.append(player)
	return result


# ---------------------------------------------------------------- Angriffe

func _update_attack(delta: float) -> void:
	if _attack == "":
		_gap -= delta
		if _gap > 0.0:
			return
		if _queue.is_empty():
			for id in CYCLES[phase - 1]:
				_queue.append(id)
		_begin(_queue.pop_front())
		return
	_attack_time -= delta
	match _attack:
		"obstacles":
			while not _steps.is_empty() and _steps[0][1] <= _elapsed():
				var step: Array = _steps.pop_front()
				if arena != null:
					arena.spawn_obstacle(step[0])
	if _attack_time <= 0.0:
		_end_attack()



func _elapsed() -> float:
	return _attack_length - _attack_time


func _begin(id: String) -> void:
	_attack = id
	match id:
		"obstacles":
			var patterns: Array = PATTERNS[phase - 1]
			_steps = (patterns[randi() % patterns.size()] as Array).duplicate()
			_attack_length = float(_steps[-1][1]) + 2.5
			_say("HINDERNISSE!", 1.6)
		"fire":
			var count := 2 + phase
			for k in count:
				_shots.append({"t": 0.9 + k * 0.55, "pick": k, "dir": Vector2.LEFT})
			_attack_length = 0.9 + count * 0.55 + 0.8
			_say("FEUER!", 1.4)
		"rain":
			_rain()
			_attack_length = 3.2
			_say("ASCHEREGEN! BEWEGEN!", 1.8)
		"adds":
			_adds()
			_attack_length = 1.5
			_say("SCHWEISSDROHNEN!", 1.6)
		"vent":
			open = true
			_attack_length = float(VENT_TIMES[phase - 1])
			_say("KERN OFFEN! ANGREIFEN!", 2.4)
			Sfx.play("ability")
	_attack_time = _attack_length


func _end_attack() -> void:
	if _attack == "vent":
		open = false
	_attack = ""
	_gap = float(GAPS[phase - 1])


func _rain() -> void:
	if main == null:
		return
	var count := 3 + phase * 1
	var alive := _alive_players()
	for k in count:
		var x := randf_range(350.0, 2650.0)
		var y := 1235.0
		if k < alive.size():
			x = alive[k].global_position.x + randf_range(-50.0, 50.0)
			y = alive[k].global_position.y
		main._on_strike_requested(null, Vector2(x, y), 100.0, 1.4 + k * 0.2, 28.0 * DAMAGE_SCALE)


func _adds() -> void:
	if main == null or main.director.alive_count() >= 8:
		return
	for k in 2:
		main.director.spawn("flyer", Vector2(2500.0 + k * 90.0, 800.0))
	for k in 2:
		main.director.spawn("walker", Vector2(2600.0 + k * 70.0, 1225.0))


func _update_shots(delta: float) -> void:
	var alive := _alive_players()
	for shot in _shots:
		shot.t -= delta
		if alive.is_empty():
			continue
		var target: Player = alive[int(shot.pick) % alive.size()]
		# Zielt bis kurz vor dem Schuss, dann ist die Richtung fix.
		if shot.t > 0.25:
			shot.dir = (target.global_position - (global_position + MUZZLE)).normalized()
	var due := _shots.filter(func(shot: Dictionary) -> bool: return shot.t <= 0.0)
	_shots = _shots.filter(func(shot: Dictionary) -> bool: return shot.t > 0.0)
	for shot in due:
		if main != null:
			var dir: Vector2 = shot.dir
			var origin: Vector2 = global_position + MUZZLE + dir * 40.0
			main._on_enemy_projectile_requested(null, origin, dir, 480.0 + 50.0 * phase, 14.0 * DAMAGE_SCALE)
			Sfx.play("enemy_shoot")


func _update_dying(delta: float) -> void:
	_death_time -= delta
	_boom_timer -= delta
	if _boom_timer <= 0.0:
		_boom_timer = 0.22
		if Fx.instance:
			Fx.instance.explosion(global_position + Vector2(randf_range(-170.0, 170.0), randf_range(-580.0, -60.0)), randf_range(60.0, 120.0), Color(1.0, 0.55, 0.2))
		Sfx.play("explosion")
		if main != null and main.camera != null:
			main.camera.add_shake(10.0)
	if _death_time <= 0.0:
		set_physics_process(false)
		died.emit()


# ---------------------------------------------------------------- Zeichnen

func _draw() -> void:
	if _flash > 0.0:
		modulate = Color(1.7, 1.7, 1.7)
	else:
		modulate = Color.WHITE
	var wreck := dying
	var base := Color(0.42, 0.2, 0.2) if not wreck else Color(0.2, 0.17, 0.17)
	var dark := Color(0.17, 0.1, 0.12)
	var heat := clampf(0.25 + 0.25 * (phase - 1) + 0.4 * _open_amount, 0.0, 1.0)
	Art.shadow(self, Vector2(0.0, 6.0), 230.0, 14.0, 0.45)
	_draw_chimneys(dark)
	# Rumpf.
	var body := Rect2(-180.0, -600.0, 360.0, 560.0)
	Art.panel(self, body, base, 18.0)
	for y in [-520.0, -190.0]:
		draw_line(Vector2(-176.0, y), Vector2(176.0, y), Color(0, 0, 0, 0.4), 4.0)
		for k in 8:
			Art.rivet(self, Vector2(-156.0 + k * 45.0, y + 12.0), 2.5)
	# Sockel mit Warnstreifen.
	var plinth := Rect2(-205.0, -52.0, 410.0, 52.0)
	Art.panel(self, plinth, Color(0.24, 0.24, 0.3), 6.0)
	for i in 14:
		var x := plinth.position.x + 10.0 + i * 29.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, -8), Vector2(x + 12, -8), Vector2(x + 22, -26), Vector2(x + 10, -26)]), Color(0.95, 0.75, 0.12))
	_draw_screen(wreck)
	_draw_furnace_door(heat, wreck)
	_draw_cannon()
	# Schaeden: Risse und Qualm bei wenig Leben.
	if hp < MAX_HP * 0.66:
		draw_polyline(PackedVector2Array([Vector2(120, -560), Vector2(95, -500), Vector2(125, -450), Vector2(100, -380)]), Color(1.0, 0.5, 0.15, 0.8), 3.0, true)
	if hp < MAX_HP * 0.33:
		draw_polyline(PackedVector2Array([Vector2(-130, -150), Vector2(-100, -200), Vector2(-140, -250)]), Color(1.0, 0.5, 0.15, 0.8), 3.0, true)
		draw_polyline(PackedVector2Array([Vector2(60, -150), Vector2(90, -230), Vector2(50, -300)]), Color(1.0, 0.5, 0.15, 0.8), 3.0, true)


func _draw_chimneys(dark: Color) -> void:
	for x in [-110.0, 80.0]:
		Art.panel(self, Rect2(x - 26.0, -700.0, 52.0, 110.0), dark, 6.0)
		draw_rect(Rect2(x - 28.0, -706.0, 56.0, 12.0), Color(0.35, 0.36, 0.44))
		for k in 5:
			var life := fposmod(_time * 0.5 + k * 0.2 + x * 0.001, 1.0)
			draw_circle(Vector2(x + sin(_time + k) * 14.0 * life, -712.0 - life * 130.0), 14.0 + life * 26.0, Color(0.25, 0.25, 0.28, 0.5 * (1.0 - life)))


func _draw_screen(wreck: bool) -> void:
	var screen := Rect2(-125.0, -578.0, 250.0, 96.0)
	Art.panel(self, screen, Color(0.05, 0.07, 0.1), 10.0, Color(0.7, 0.72, 0.8, 0.8))
	var mood := "angry"
	if open:
		mood = "hurt"
	if wreck:
		mood = "dead"
	var color := Color(1.0, 0.3, 0.15) if not wreck else Color(0.4, 0.4, 0.45)
	Art.face(self, screen.get_center(), Vector2(200.0, 72.0), color, Vector2(_look.x, _look.y), mood, _time)


func _draw_furnace_door(heat: float, wreck: bool) -> void:
	var center := Vector2(0.0, -300.0)
	var radius := 112.0
	Art.disc(self, center, radius + 12.0, Color(0.12, 0.12, 0.16), Color(0.7, 0.72, 0.8, 0.8))
	# Glut im Inneren.
	var glow := Color(1.0, 0.45, 0.1)
	if wreck:
		glow = Color(0.3, 0.12, 0.08)
	draw_circle(center, radius, glow.darkened(0.45 - 0.4 * heat))
	if _open_amount > 0.02 or heat > 0.4:
		var pulse := 0.5 + 0.5 * sin(_time * 8.0)
		draw_circle(center, radius * (0.55 + 0.15 * pulse) * maxf(_open_amount, 0.3), Color(1.0, 0.85, 0.35, 0.85))
		Art.glow(self, center, radius * 1.5 * (0.5 + _open_amount), Color(1.0, 0.5, 0.15))
	# Zwei Tuerhaelften, die beim Oeffnen auseinanderfahren.
	var shift := _open_amount * 118.0
	var door_color := Color(0.3, 0.3, 0.38)
	var left := Rect2(-radius - 12.0 - shift, center.y - radius - 12.0, radius + 12.0, (radius + 12.0) * 2.0)
	var right := Rect2(shift, center.y - radius - 12.0, radius + 12.0, (radius + 12.0) * 2.0)
	for rect in [left, right]:
		Art.panel(self, rect, door_color, 8.0)
		draw_rect(Rect2(rect.position.x + 6.0, rect.position.y + rect.size.y * 0.5 - 8.0, rect.size.x - 12.0, 16.0), Color(0.95, 0.75, 0.12))
		for i in 6:
			var sx: float = rect.position.x + 10.0 + i * ((rect.size.x - 20.0) / 6.0)
			draw_colored_polygon(PackedVector2Array([Vector2(sx, rect.position.y + rect.size.y * 0.5 + 8.0), Vector2(sx + 10.0, rect.position.y + rect.size.y * 0.5 + 8.0), Vector2(sx + 4.0, rect.position.y + rect.size.y * 0.5 - 8.0), Vector2(sx - 6.0, rect.position.y + rect.size.y * 0.5 - 8.0)]), Color(0.1, 0.1, 0.13))
		Art.rivet(self, rect.position + Vector2(14.0, 14.0), 3.0)
		Art.rivet(self, rect.position + Vector2(14.0, rect.size.y - 14.0), 3.0)
	if open:
		Art.led(self, center + Vector2(0.0, -radius - 30.0), 7.0, Color(1.0, 0.9, 0.3), fmod(_time, 0.4) < 0.2)


func _draw_cannon() -> void:
	var telegraphing := false
	var strongest := 0.0
	for shot in _shots:
		if shot.t < 0.9:
			telegraphing = true
			strongest = maxf(strongest, 1.0 - shot.t / 0.9)
	Art.panel(self, Rect2(MUZZLE.x + 20.0, MUZZLE.y - 22.0, 100.0, 44.0), Color(0.24, 0.24, 0.3), 8.0)
	Art.panel(self, Rect2(MUZZLE.x - 20.0, MUZZLE.y - 17.0, 60.0, 34.0), Color(0.15, 0.15, 0.2), 6.0)
	if telegraphing:
		Art.glow(self, MUZZLE, 26.0 + 22.0 * strongest, Color(1.0, 0.3, 0.2))
	for shot in _shots:
		if shot.t < 0.9:
			var alpha: float = 0.15 + 0.55 * (1.0 - float(shot.t) / 0.9)
			var aim: Vector2 = shot.dir
			draw_line(MUZZLE, MUZZLE + aim * 1500.0, Color(1.0, 0.3, 0.2, alpha), 2.0 + 3.0 * (1.0 - float(shot.t) / 0.9), true)
