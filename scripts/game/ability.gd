class_name Ability
extends Node
## Klassenfaehigkeit auf Quadrat mit Abklingzeit. Wird vom Spieler erzeugt und
## steuert Dauer, Wirkung auf Gegner und die Zeichnung der Aura.
##   suck: Roomba zieht Gegner und Beute zu einem Brennpunkt vor sich, betaeubt sie und sprengt sie am Ende weg.
##   overwatch: Hexapod schiesst mit doppelter Rate, auch in Bewegung.
##   roll: Automat rollt als Walze, schneller, nimmt weniger Schaden und rammt Gegner.
##   print: Drucker druckt zwei Drohnen, die automatisch Gegner beschiessen.

const SUCK_RADIUS := 560.0
const SUCK_BITE_RADIUS := 150.0
const VORTEX_DISTANCE := 190.0
const BURST_DAMAGE := 22.0
const TICK := 0.2
const DRONES := 2

var player: Player
var data: Dictionary = {}
var cooldown := 0.0
var time := 0.0
var cooldown_total := 1.0

var _tick := 0.0
var _was_ready := true


func setup(new_player: Player) -> void:
	player = new_player
	data = player.stats.ability


func id() -> String:
	return data.id


func is_active(ability_id: String = "") -> bool:
	return time > 0.0 and (ability_id == "" or data.id == ability_id)


func is_ready() -> bool:
	return cooldown <= 0.0


## 0 = gerade benutzt, 1 = wieder bereit.
func readiness() -> float:
	return 1.0 - clampf(cooldown / cooldown_total, 0.0, 1.0)


## Verkuerzt die laufende Abklingzeit (z.B. pro Kill beim Druckbot).
func reduce_cooldown(seconds: float) -> void:
	if seconds > 0.0 and cooldown > 0.0:
		cooldown = maxf(0.0, cooldown - seconds)


func try_use() -> bool:
	if player.downed or cooldown > 0.0:
		return false
	cooldown_total = float(data.cooldown) * maxf(0.3, 1.0 - float(player.mods.ability_cd))
	cooldown = cooldown_total
	time = float(data.duration)
	_tick = 0.0
	_was_ready = false
	Sfx.play("suck" if data.id == "suck" else "ability")
	if data.id == "print":
		_spawn_drones()
	var main := player.get_parent()
	if "camera" in main and main.camera != null:
		main.camera.add_shake(6.0)
	return true


func _physics_process(delta: float) -> void:
	if player.downed:
		time = 0.0
	var was_active := time > 0.0
	time = maxf(0.0, time - delta)
	if was_active and time <= 0.0 and data.id == "suck" and not player.downed:
		_vortex_burst()
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown <= 0.0 and not _was_ready:
		_was_ready = true
		Sfx.play("ready")
	if time <= 0.0:
		return
	match data.id:
		"suck":
			_update_suck(delta)
		"roll":
			_update_roll(delta)


func _enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies")


## Brennpunkt des Wirbels: ein Stueck vor dem Roomba. Gegner werden dorthin gezogen und
## betaeubt, sie kommen also nie in sein Gesicht und koennen nicht zuschlagen.
func vortex_focus() -> Vector2:
	return player.global_position + Vector2(float(player.facing) * VORTEX_DISTANCE, -8.0)


func _update_suck(delta: float) -> void:
	_tick -= delta
	var bite := _tick <= 0.0
	if bite:
		_tick = TICK
	var focus := vortex_focus()
	for enemy in _enemies():
		var offset: Vector2 = focus - enemy.global_position
		var distance := offset.length()
		if enemy.global_position.distance_to(player.global_position) > SUCK_RADIUS:
			continue
		if enemy is Enemy:
			enemy.stun(0.3)
			var direction := offset / maxf(distance, 1.0)
			# Zug wird schwaecher, je naeher sie dem Brennpunkt kommen, und endet dort.
			var pull := clampf(distance * 7.0, 0.0, 900.0)
			if enemy.data.knockback < 0.5:
				pull *= 0.5
			if enemy.data.movement == "fly":
				enemy.velocity = enemy.velocity.move_toward(direction * pull, 8000.0 * delta)
			else:
				enemy.velocity.x = move_toward(enemy.velocity.x, direction.x * pull, 8000.0 * delta)
		if bite and distance <= SUCK_BITE_RADIUS:
			enemy.take_damage(6.0 * player.damage_mult(), player, Vector2.ZERO, "")
	var pickups := player.get_parent().get("pickups") as Node2D
	if pickups != null:
		for pickup in pickups.get_children():
			if pickup is Pickup and pickup.global_position.distance_to(player.global_position) <= SUCK_RADIUS * 1.6:
				pickup.force_pull = true


## Am Ende des Wirbels: Druckwelle am Brennpunkt, die alles wegschleudert.
func _vortex_burst() -> void:
	var focus := vortex_focus()
	if Fx.instance:
		Fx.instance.ring(focus, 220.0, Color(0.5, 1.0, 0.9))
		Fx.instance.explosion(focus, 120.0, Color(0.4, 1.0, 0.9))
	Sfx.play("explosion")
	var main := player.get_parent()
	if "camera" in main and main.camera != null:
		main.camera.add_shake(8.0)
	for enemy in _enemies():
		var offset: Vector2 = enemy.global_position - focus
		if offset.length() <= 230.0:
			enemy.take_damage(BURST_DAMAGE * player.damage_mult(), player, offset.normalized() * 2.5, "")


func _update_roll(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	var reach := float(player.stats.size.x) * 0.5 + 34.0
	var hit_any := false
	for enemy in _enemies():
		var offset: Vector2 = enemy.global_position - player.global_position
		# Hoehe des Automaten zaehlt: Gegner auf Koerperhoehe werden gerammt.
		if absf(offset.x) <= reach + 8.0 and absf(offset.y) <= float(player.stats.size.y) * 0.5 + 10.0:
			var away := Vector2(signf(offset.x) if absf(offset.x) > 1.0 else player.facing, -0.3)
			enemy.take_damage(20.0 * player.damage_mult(), player, away * 3.0, "")
			hit_any = true
	if hit_any:
		var main := player.get_parent()
		if "camera" in main and main.camera != null:
			main.camera.add_shake(3.0)


func _spawn_drones() -> void:
	var main := player.get_parent()
	for i in DRONES:
		var drone := Drone.new()
		drone.owner_player = player
		drone.slot = i
		drone.life = float(data.duration)
		main.add_child(drone)
		# Die Drohnen starten aus der Druckkammer und fliegen von dort zu ihrer Bahn.
		drone.global_position = player.global_position + Vector2(-6.0 * player.facing, -20.0)


# ---------------------------------------------------------------- Zeichnen

## Aura in lokalen Koordinaten des Spielers.
func draw_aura(c: CanvasItem, t: float) -> void:
	if time <= 0.0:
		return
	var size: Vector2 = player.stats.size
	var radius := maxf(size.x, size.y) * 0.5
	var fade := clampf(time / 0.3, 0.0, 1.0)
	match data.id:
		"suck":
			var focus_local := Vector2(float(player.facing) * VORTEX_DISTANCE, -8.0)
			for i in 3:
				var phase := fposmod(t * 1.6 + i / 3.0, 1.0)
				var r := lerpf(SUCK_RADIUS, 40.0, phase)
				c.draw_arc(focus_local, r, 0.0, TAU, 64, Color(0.5, 1.0, 0.9, 0.3 * phase * fade), 3.0, true)
			# Brennpunkt: drehende Spiralarme und heller Kern.
			for arm in 4:
				var base := t * 7.0 + arm * TAU / 4.0
				var points := PackedVector2Array()
				for k in 10:
					var f := float(k) / 9.0
					var ang := base + f * 2.4
					points.append(focus_local + Vector2(cos(ang), sin(ang)) * (14.0 + 54.0 * f))
				c.draw_polyline(points, Color(0.6, 1.0, 0.95, 0.7 * fade), 3.0, true)
			c.draw_circle(focus_local, 12.0, Color(0.05, 0.2, 0.2, 0.9 * fade))
			Art.glow(c, focus_local, 60.0, Color(0.4, 1.0, 0.9))
			Art.glow(c, Vector2.ZERO, radius + 30.0, Color(0.4, 1.0, 0.9))
		"overwatch":
			var pulse := 0.5 + 0.5 * sin(t * 10.0)
			var from: Vector2 = player._muzzle_offset()
			c.draw_line(from, from + player.aim_dir * 1100.0, Color(player.laser_color(), (0.25 + 0.15 * pulse) * fade), 2.5, true)
			c.draw_arc(Vector2.ZERO, radius + 12.0, 0.0, TAU, 32, Color(1.0, 0.3, 0.25, 0.55 * fade), 2.5, true)
			Art.glow(c, Vector2.ZERO, radius + 20.0, Color(1.0, 0.3, 0.25))
		"roll":
			for i in 3:
				var a := t * 9.0 + i * TAU / 3.0
				c.draw_arc(Vector2.ZERO, radius + 10.0, a, a + 0.9, 10, Color(1.0, 0.85, 0.3, 0.8 * fade), 4.0, true)
			Art.glow(c, Vector2.ZERO, radius + 24.0, Color(1.0, 0.8, 0.3))
		"print":
			Art.glow(c, Vector2.ZERO, radius + 14.0, Color(1.0, 0.6, 0.2))
