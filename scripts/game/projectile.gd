class_name Projectile
extends Area2D
## Spielergeschoss. Trifft Welt (Ebene 1) und Gegner (Ebene 3). Meldet jeden
## Treffer ueber das Signal hit, damit die Hauptszene Effekte und Explosionen
## erzeugen kann.

signal hit(projectile: Projectile, position: Vector2, target: Node)

var direction := Vector2.RIGHT
var speed := 900.0
var damage := 10.0
var lifetime := 1.2
var pierce := 0
var size := 5.0
var color := Color.WHITE
var shooter: Node = null
var explosion_radius := 0.0
var explosion_damage := 0.0
var element := ""
## Bogenwurf: Schwerkraft in px/s^2. Dosen landen auch auf Plattformen.
var arc_gravity := 0.0
var collide_platforms := false
var shaken := false
var charge := 0.0
## Verfolgungsrakete: Lenkrate in rad/s (0 = ungelenkt), Beschleunigung bis speed_max, Wucht beim Treffer.
var homing := 0.0
var accel := 0.0
var speed_max := 0.0
var push := 1.0
## Aussehen: "bullet", "rocket" oder "can". Raketen zuenden am Ende der Flugzeit, wenn sie nichts getroffen haben.
var style := "bullet"
## Verbleibende Abpraller an Waennen (Ricochet) und Wucht-Faktor fuer Treffer und Explosionen (Heavy Slugs).
var bounces := 0
var knock := 1.0
## Zustand beim Treffer (Gespinst, Markierung, Betaeubung ...) und seine Dauer.
var status := ""
var status_time := 0.0
## Wurfscheibe: nach so vielen Sekunden dreht sie um und fliegt zum Schuetzen zurueck (0 = kein Boomerang).
var boomerang := 0.0
## Wolke beim Aufprall (Toner): Radius, Dauer, Schaden pro Sekunde, Zustand. Leer = keine.
var zone: Dictionary = {}
## Zuendet (Explosion oder Wolke) auch dann, wenn die Flugzeit ohne Treffer ablaeuft: Raketen, Drohnen, Kartuschen.
var detonate_on_timeout := false

var _returning := false

var _prev_pos := Vector2.ZERO
var _life0 := 1.0
var _hit_targets: Array[Node] = []
var _velocity := Vector2.ZERO
var _trail_timer := 0.0
var _target: Node2D = null
var _retarget_timer := 0.0
var _age := 0.0


func _ready() -> void:
	_life0 = lifetime
	collision_layer = 1 << 3
	collision_mask = (1 << 0) | (1 << 2) | ((1 << 5) if collide_platforms else 0)
	_velocity = direction * speed
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = size
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	_prev_pos = global_position
	if boomerang > 0.0:
		_step_boomerang()
	elif homing > 0.0:
		_steer(delta)
	if style in ["disc", "web", "flame", "coin", "drone", "canister", "paper"]:
		queue_redraw()
	_velocity.y += arc_gravity * delta
	position += _velocity * delta
	if arc_gravity > 0.0:
		direction = _velocity.normalized()
		queue_redraw()
		_trail_timer -= delta
		if shaken and _trail_timer <= 0.0 and Fx.instance:
			_trail_timer = 0.03
			Fx.instance.spark(global_position, Color(1.0, 1.0, 1.0), 1, 90.0)
	lifetime -= delta
	if lifetime <= 0.0:
		if (style == "rocket" or detonate_on_timeout) and not is_queued_for_deletion():
			# Eine Rakete, die ihr Ziel verfehlt, zuendet am Ende ihrer Flugzeit.
			hit.emit(self, global_position, null)
		queue_free()


## Wurfscheibe: erst geradeaus, dann Umkehr und gerade zurueck zum Schuetzen (Waende stoeren dabei nicht mehr).
func _step_boomerang() -> void:
	if not _returning:
		if _age >= boomerang:
			_begin_return()
		return
	if shooter == null or not is_instance_valid(shooter):
		queue_free()
		return
	var back: Vector2 = (shooter as Node2D).global_position - global_position
	if back.length() < 44.0:
		if Fx.instance:
			Fx.instance.spark(global_position, color, 3, 120.0)
		queue_free()
		return
	_velocity = back.normalized() * speed * 1.3
	direction = _velocity.normalized()


func _begin_return() -> void:
	_returning = true
	_hit_targets.clear()
	set_deferred("collision_mask", 1 << 2)


## Lenkt auf den naechsten Gegner vor der Rakete und beschleunigt bis zur Hoechstgeschwindigkeit.
func _steer(delta: float) -> void:
	if accel > 0.0:
		var now := minf(_velocity.length() + accel * delta, speed_max if speed_max > 0.0 else speed)
		_velocity = _velocity.normalized() * now
	if _age < 0.12:
		return
	_retarget_timer -= delta
	var lost := _target == null or not is_instance_valid(_target) or _target.is_queued_for_deletion()
	if lost or _retarget_timer <= 0.0:
		_retarget_timer = 0.2
		# Verlorenes Ziel oder keine freie Sicht mehr: naechsten sichtbaren Gegner vor der Rakete suchen.
		if lost or not _has_line_of_sight(_target):
			_target = _find_target()
	if _target != null:
		var wanted := (_target.global_position - global_position).angle()
		var diff := angle_difference(_velocity.angle(), wanted)
		_velocity = _velocity.rotated(clampf(diff, -homing * delta, homing * delta))
	direction = _velocity.normalized()
	queue_redraw()
	_trail_timer -= delta
	if _trail_timer <= 0.0 and Fx.instance:
		_trail_timer = 0.025 if style == "rocket" else 0.07
		Fx.instance.spark(global_position - direction * 10.0, Color(1.0, 0.7, 0.3, 0.8) if style == "rocket" else Color(color, 0.7), 1, 70.0)


## Naechster Gegner einigermassen in Flugrichtung (sonst dreht die Rakete Kreise), ohne Wand dazwischen.
func _find_target() -> Node2D:
	var best := 1100.0
	var result: Node2D = null
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector2 = enemy.global_position - global_position
		var distance := offset.length()
		if distance < best and offset.normalized().dot(_velocity.normalized()) > -0.15 and _has_line_of_sight(enemy):
			best = distance
			result = enemy
	return result


func _has_line_of_sight(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _draw() -> void:
	match style:
		"rocket":
			_draw_rocket()
			return
		"can":
			_draw_can()
			return
		"disc":
			_draw_disc()
			return
		"web":
			_draw_web()
			return
		"flame":
			_draw_flame()
			return
		"drone":
			_draw_drone()
			return
		"canister":
			_draw_canister()
			return
		"label":
			_draw_label()
			return
		"paper":
			_draw_paper()
			return
		"coin":
			_draw_coin()
			return
	var streak := clampf(speed * 0.02, 6.0, 40.0)
	draw_line(-direction * streak, Vector2.ZERO, Color(color, 0.5), size * 1.2)
	draw_circle(Vector2.ZERO, size, color)
	draw_circle(Vector2.ZERO, size * 1.8, Color(color, 0.25))


func _draw_rocket() -> void:
	# Rakete: Rumpf mit Spitze, Leitwerk und Flamme, zeigt in Flugrichtung.
	draw_set_transform(Vector2.ZERO, _velocity.angle())
	var flame := 8.0 + 6.0 * absf(sin(_age * 40.0))
	draw_colored_polygon(PackedVector2Array([Vector2(-size * 1.4, -size * 0.45), Vector2(-size * 1.4 - flame, 0.0), Vector2(-size * 1.4, size * 0.45)]), Color(1.0, 0.7, 0.2, 0.9))
	draw_colored_polygon(PackedVector2Array([Vector2(-size * 1.4, -size * 0.25), Vector2(-size * 1.4 - flame * 0.6, 0.0), Vector2(-size * 1.4, size * 0.25)]), Color(1.0, 0.95, 0.7))
	draw_rect(Rect2(-size * 1.4, -size * 0.55, size * 2.2, size * 1.1), Color(0.75, 0.78, 0.85))
	draw_colored_polygon(PackedVector2Array([Vector2(size * 0.8, -size * 0.55), Vector2(size * 1.8, 0.0), Vector2(size * 0.8, size * 0.55)]), color)
	draw_colored_polygon(PackedVector2Array([Vector2(-size * 1.4, -size * 0.55), Vector2(-size * 1.9, -size * 1.1), Vector2(-size * 0.8, -size * 0.55)]), color.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(-size * 1.4, size * 0.55), Vector2(-size * 1.9, size * 1.1), Vector2(-size * 0.8, size * 0.55)]), color.darkened(0.2))
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2.ZERO, size * 2.2, Color(color, 0.2))


func _draw_disc() -> void:
	# Scheibe mit Zaehnen, dreht sich schnell. Beim Rueckflug leuchtet sie heller.
	var spin := _age * 16.0
	var radius := size
	var tint := color if _returning else color.darkened(0.05)
	draw_circle(Vector2.ZERO, radius * 2.0, Color(tint, 0.22))
	for i in 8:
		var a := spin + TAU * i / 8.0
		var tip := Vector2(cos(a), sin(a)) * radius * 1.35
		var left := Vector2(cos(a - 0.24), sin(a - 0.24)) * radius * 0.9
		var right := Vector2(cos(a + 0.24), sin(a + 0.24)) * radius * 0.9
		draw_colored_polygon(PackedVector2Array([left, tip, right]), tint)
		draw_polyline(PackedVector2Array([left, tip, right]), Color(0.1, 0.12, 0.2), 1.5, true)
	draw_circle(Vector2.ZERO, radius * 0.95, Color(0.16, 0.2, 0.3))
	draw_arc(Vector2.ZERO, radius * 0.95, 0.0, TAU, 20, tint, 2.5, true)
	draw_circle(Vector2.ZERO, radius * 0.32, tint)


func _draw_drone() -> void:
	# Kleine Sprengdrohne: Koerper, zwei Rotoren (verwischt) und ein blinkendes Licht.
	draw_circle(Vector2.ZERO, size * 2.2, Color(color, 0.2))
	draw_rect(Rect2(-size * 0.9, -size * 0.55, size * 1.8, size * 1.1), Color(0.2, 0.2, 0.26))
	draw_rect(Rect2(-size * 0.9, -size * 0.55, size * 1.8, size * 1.1), color, false, 1.5)
	for side in [-1.0, 1.0]:
		var spin := absf(sin(_age * 45.0 + side))
		draw_line(Vector2(side * size * 0.6, -size * 0.55), Vector2(side * size * 1.4, -size * 1.0), Color(0.55, 0.57, 0.65), 1.5, true)
		draw_rect(Rect2(side * size * 1.4 - size * (0.5 + 0.9 * spin), -size * 1.15, size * (1.0 + 1.8 * spin), size * 0.25), Color(0.85, 0.88, 0.95, 0.75))
	draw_circle(Vector2(0.0, size * 0.1), size * 0.35, Color(1.0, 0.3, 0.2, 0.5 + 0.5 * sin(_age * 18.0)))


func _draw_canister() -> void:
	# Tonerkartusche: dunkler Zylinder mit heller Kappe, dreht sich im Flug.
	draw_set_transform(Vector2.ZERO, _age * 9.0)
	draw_rect(Rect2(-size * 0.75, -size, size * 1.5, size * 2.0), Color(0.16, 0.13, 0.25))
	draw_rect(Rect2(-size * 0.75, -size, size * 1.5, size * 2.0), color.lightened(0.25), false, 2.0)
	draw_rect(Rect2(-size * 0.5, -size * 1.25, size, size * 0.4), color.lightened(0.4))
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2.ZERO, size * 1.7, Color(color, 0.2))


func _draw_label() -> void:
	# Etikett: gelber Streifen mit dunkler Linie, zeigt in Flugrichtung.
	draw_set_transform(Vector2.ZERO, direction.angle())
	draw_line(Vector2(-26.0, 0.0), Vector2.ZERO, Color(color, 0.35), 3.0)
	draw_rect(Rect2(-size * 1.6, -size * 0.9, size * 3.2, size * 1.8), color)
	draw_rect(Rect2(-size * 1.6, -size * 0.9, size * 3.2, size * 1.8), Color(0.25, 0.2, 0.05), false, 1.5)
	draw_line(Vector2(-size, 0.0), Vector2(size * 0.8, 0.0), Color(0.25, 0.2, 0.05), 1.5)
	draw_set_transform(Vector2.ZERO)


func _draw_paper() -> void:
	# Papierblatt: weisses Rechteck, wirbelt im Flug.
	draw_set_transform(Vector2.ZERO, _age * 14.0 + float(get_instance_id() % 7))
	draw_rect(Rect2(-size * 1.1, -size * 1.5, size * 2.2, size * 3.0), color)
	draw_rect(Rect2(-size * 1.1, -size * 1.5, size * 2.2, size * 3.0), Color(0.5, 0.5, 0.55), false, 1.2)
	for i in 3:
		draw_line(Vector2(-size * 0.7, -size * 0.8 + i * size * 0.8), Vector2(size * 0.7, -size * 0.8 + i * size * 0.8), Color(0.55, 0.6, 0.75), 1.0)
	draw_set_transform(Vector2.ZERO)


func _draw_flame() -> void:
	# Flamme: waechst, verblasst von Weiss ueber Gelb und Orange zu dunklem Rauch.
	var t := clampf(_age / maxf(_life0, 0.01), 0.0, 1.0)
	var r := size * (0.55 + 1.3 * t)
	var hot := Color(1.0, 0.95, 0.7).lerp(Color(1.0, 0.45, 0.12), minf(1.0, t * 1.6)).lerp(Color(0.25, 0.1, 0.08), clampf(t * 2.0 - 1.0, 0.0, 1.0))
	draw_circle(Vector2.ZERO, r * 1.5, Color(hot, 0.16 * (1.0 - t)))
	draw_circle(Vector2.ZERO, r, Color(hot, 0.85 * (1.0 - 0.7 * t)))
	draw_circle(Vector2.ZERO, r * 0.45, Color(1.0, 1.0, 0.85, 0.7 * (1.0 - t)))


func _draw_coin() -> void:
	# Muenze: dreht sich um die Laengsachse, daher schmal und breit im Wechsel.
	var squash := 0.25 + 0.75 * absf(cos(_age * 22.0))
	draw_line(-direction * 22.0, Vector2.ZERO, Color(color, 0.35), size * 0.9, true)
	draw_set_transform(Vector2.ZERO, direction.angle() + PI / 2.0, Vector2(squash, 1.0))
	draw_circle(Vector2.ZERO, size * 1.15, Color(0.55, 0.4, 0.08))
	draw_circle(Vector2.ZERO, size, color)
	draw_arc(Vector2.ZERO, size * 0.6, 0.0, TAU, 12, Color(0.7, 0.5, 0.1), 1.5, true)
	draw_set_transform(Vector2.ZERO)


func _draw_web() -> void:
	# Spinnenseide: Kugel mit Speichen, dahinter ein duenner Faden.
	draw_line(-direction * 28.0, Vector2.ZERO, Color(color, 0.45), 1.5, true)
	draw_circle(Vector2.ZERO, size * 1.8, Color(color, 0.18))
	draw_circle(Vector2.ZERO, size * 0.8, color)
	for i in 6:
		var a := _age * 5.0 + TAU * i / 6.0
		draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * size * 1.5, color, 1.2, true)


func _draw_can() -> void:
	# Dose: Koerper, Deckel und Boden, geschuettelte Dosen schaeumen.
	var body_color := color
	draw_set_transform(Vector2.ZERO, _velocity.angle() + PI / 2.0)
	draw_rect(Rect2(-size * 0.7, -size, size * 1.4, size * 2.0), body_color)
	draw_rect(Rect2(-size * 0.7, -size, size * 1.4, size * 2.0), Color(0.1, 0.3, 0.15), false, 2.0)
	draw_rect(Rect2(-size * 0.7, -size, size * 1.4, size * 0.4), Color(0.85, 0.85, 0.9))
	draw_set_transform(Vector2.ZERO)
	if shaken:
		draw_circle(Vector2.ZERO, size * (1.4 + 0.6 * charge), Color(1.0, 1.0, 1.0, 0.25))


func _on_body_entered(body: Node2D) -> void:
	if is_queued_for_deletion():
		return
	# Plattformen sind von unten durchlaessig, ein aufsteigender Wurf fliegt hindurch.
	if body is CollisionObject2D and (body.collision_layer & (1 << 5)) != 0 and _velocity.y <= 0.0:
		return
	if boomerang > 0.0:
		# Die Scheibe prallt an der Wand ab und kommt zurueck.
		if not _returning:
			_begin_return()
			Sfx.play("block", 0.2)
		return
	if bounces > 0 and explosion_radius <= 0.0 and arc_gravity <= 0.0 and _bounce_off():
		return
	hit.emit(self, global_position, null)
	queue_free()


## Prallt von der Wand ab (Ricochet): Normale per Strahl vom letzten Ort, Geschwindigkeit gespiegelt.
## Gibt false zurueck, wenn keine Wand gefunden wurde (dann verhaelt sich das Geschoss wie sonst).
func _bounce_off() -> bool:
	var heading := _velocity.normalized()
	var query := PhysicsRayQueryParameters2D.create(_prev_pos, global_position + heading * (size + 6.0), 1 << 0)
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	var normal: Vector2 = result.normal
	# Beginnt der Strahl schon in der Wand, liefert die Physik keine Normale: dann zurueck, woher das Geschoss kam.
	if normal.length_squared() < 0.25:
		normal = -heading
	_velocity = _velocity.bounce(normal)
	direction = _velocity.normalized()
	global_position = result.position + normal * (size + 2.0)
	bounces -= 1
	_hit_targets.clear()
	if Fx.instance:
		Fx.instance.spark(result.position, color, 3, 140.0)
	Sfx.play("block", 0.2)
	queue_redraw()
	return true


func _on_area_entered(area: Area2D) -> void:
	if is_queued_for_deletion():
		return
	if not area.has_method("take_damage") or area in _hit_targets:
		return
	_hit_targets.append(area)
	area.take_damage(damage, shooter, direction * push * knock, element)
	if status != "" and is_instance_valid(area) and area.has_method("apply_status"):
		area.apply_status(status, status_time, shooter)
	hit.emit(self, global_position, area)
	if pierce <= 0:
		queue_free()
	else:
		pierce -= 1
