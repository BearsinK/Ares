class_name CoopCamera
extends Camera2D
## Kamera, die beide Spieler im Bild haelt: sie zentriert sich zwischen ihnen
## und zoomt heraus, wenn sie weit auseinander sind. Eine harte Maximaldistanz
## zwischen den Spielern kommt spaeter.

@export var margin := Vector2(360.0, 230.0)
@export var min_zoom := 0.45
@export var max_zoom := 1.3

var targets: Array[Node2D] = []
## Verschiebt den Bildmittelpunkt, z.B. nach rechts im Bosskampf.
var bias := Vector2.ZERO

var _shake := 0.0


## Schuettelt die Kamera. Der staerkste aktuelle Wert gewinnt und klingt ab.
func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount * SaveData.shake_scale())


func _process(delta: float) -> void:
	_shake = move_toward(_shake, 0.0, 40.0 * delta)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	if targets.is_empty():
		return
	# Gefallene Spieler lassen wir los: die Kamera folgt nur denen, die noch stehen (der Rand-Marker im HUD zeigt, wo der Gefallene liegt).
	var followed: Array[Node2D] = []
	for target in targets:
		if not (target is Player and target.downed):
			followed.append(target)
	if followed.is_empty():
		followed = targets
	var min_pos := followed[0].global_position
	var max_pos := min_pos
	for target in followed:
		min_pos = min_pos.min(target.global_position)
		max_pos = max_pos.max(target.global_position)

	var center := (min_pos + max_pos) * 0.5
	# Leichter Vorlauf in Laufrichtung, damit man mehr von dem sieht, worauf man zuläuft.
	var look := 0.0
	for target in followed:
		if target is Player and not target.downed:
			look += clampf(target.velocity.x * 0.18, -110.0, 110.0)
	center.x += look / followed.size()
	center += bias
	var needed := (max_pos - min_pos) + margin * 2.0
	var view := get_viewport_rect().size
	var zoom_value := clampf(minf(view.x / needed.x, view.y / needed.y), min_zoom, max_zoom)

	zoom = zoom.lerp(Vector2(zoom_value, zoom_value), 1.0 - exp(-4.0 * delta))
	global_position = global_position.lerp(center, 1.0 - exp(-8.0 * delta))
