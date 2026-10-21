class_name EnemyProjectile
extends Area2D
## Geschoss eines Gegners. Trifft Spieler (Ebene 2) und Welt (Ebene 1).
## Wer gerade durch Iframes geschuetzt ist (z.B. im Dash), wird durchflogen.
## Optik: alle Gegnergeschosse teilen eine Sprache (magentafarbener Stachelball mit weissem Kern,
## dunkler Kontur und Schweif), damit man sie von den warmen Spielerschuessen sofort trennt.

const RADIUS := 9.0

var direction := Vector2.RIGHT
var speed := 500.0
var damage := 8.0
var lifetime := 3.8
var color := Color(1.0, 0.18, 0.5)
var _age := 0.0


func _ready() -> void:
	collision_layer = 1 << 4
	collision_mask = (1 << 0) | (1 << 1)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS - 1.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	# Die Form zeigt nach vorn, der Schweif nach hinten.
	rotation = direction.angle()
	z_index = 4


func _physics_process(delta: float) -> void:
	_age += delta
	# Pulsiert leicht (nur Skalierung, kein Neuzeichnen).
	scale = Vector2.ONE * (1.0 + 0.1 * sin(_age * 22.0))
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	for minion in Minion.active:
		if not minion.is_dead() and minion.global_position.distance_to(global_position) <= RADIUS + minion.radius():
			if minion.take_hit(damage, global_position):
				queue_free()
				return
	if get_overlapping_bodies().size() > 0:
		# Faengt Faelle ab, in denen ein Spieler nach den Iframes im Geschoss steht.
		for body in get_overlapping_bodies():
			_on_body_entered(body)


func _draw() -> void:
	var hot := color.lerp(Color(1.0, 0.85, 0.6), 0.35)
	# Schweif: spitz zulaufend, nach hinten ausblendend.
	var tail := clampf(speed * 0.075, 20.0, 46.0)
	for k in 4:
		var f := float(k) / 4.0
		var length := tail * (1.0 - f * 0.55)
		var half := RADIUS * (0.95 - f * 0.55)
		draw_colored_polygon(PackedVector2Array([Vector2(-2.0, -half), Vector2(-2.0 - length, 0.0), Vector2(-2.0, half)]), Color(color, 0.17))
	# Leuchthof.
	draw_circle(Vector2.ZERO, RADIUS * 2.0, Color(color, 0.14))
	draw_circle(Vector2.ZERO, RADIUS * 1.45, Color(color, 0.28))
	# Dunkle Kontur und Stacheln: fuer den Kontrast auf hellem und dunklem Grund.
	var star := PackedVector2Array()
	for k in 8:
		var angle := TAU * float(k) / 8.0
		star.append(Vector2(cos(angle), sin(angle)) * (RADIUS * 1.5 if k % 2 == 0 else RADIUS * 0.95))
	draw_colored_polygon(_grown(star, 2.2), Color(0.06, 0.02, 0.08, 0.9))
	draw_colored_polygon(star, color)
	draw_circle(Vector2.ZERO, RADIUS * 0.72, hot)
	draw_circle(Vector2.ZERO, RADIUS * 0.4, Color(1.0, 1.0, 0.95))


## Vergroesserte Kopie eines um den Ursprung liegenden Vielecks (fuer die Kontur).
func _grown(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point + point.normalized() * amount)
	return result


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		if body.take_hit(damage, global_position):
			queue_free()
	else:
		queue_free()
