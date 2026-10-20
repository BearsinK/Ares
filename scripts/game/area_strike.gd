class_name AreaStrike
extends Node2D
## Angekuendigter Flaechenschlag (Moerser): Ein Warnkreis fuellt sich, dann
## schlaegt eine Granate ein und verletzt Spieler im Radius. Wer sich rechtzeitig
## bewegt (oder dasht), bleibt unversehrt.

signal exploded(position: Vector2)

var radius := 90.0
var delay := 1.2
var damage := 20.0
var players: Array[Player] = []

var _age := 0.0
var _done := false
var _after := 0.0


func _ready() -> void:
	z_index = 2


func _physics_process(delta: float) -> void:
	_age += delta
	if _done:
		_after += delta
		if _after > 0.35:
			queue_free()
		queue_redraw()
		return
	if _age >= delay:
		_explode()
	queue_redraw()


func _explode() -> void:
	_done = true
	if Fx.instance:
		Fx.instance.explosion(global_position, radius, Color(1.0, 0.5, 0.25))
	for player in players:
		if player.downed:
			continue
		if player.global_position.distance_to(global_position) <= radius + float(player.stats.radius) * 0.5:
			player.take_hit(damage, global_position)
	exploded.emit(global_position)


func _draw() -> void:
	if _done:
		return
	var progress := clampf(_age / delay, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_age * 18.0)
	draw_circle(Vector2.ZERO, radius * progress, Color(1.0, 0.3, 0.2, 0.12 + 0.25 * progress))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 0.35, 0.25, 0.5 + 0.4 * pulse * progress), 3.0, true)
	# Fadenkreuz und fallende Granate kurz vor dem Einschlag.
	draw_line(Vector2(-radius * 0.3, 0), Vector2(radius * 0.3, 0), Color(1.0, 0.5, 0.4, 0.7), 2.0)
	draw_line(Vector2(0, -radius * 0.3), Vector2(0, radius * 0.3), Color(1.0, 0.5, 0.4, 0.7), 2.0)
	var fall := clampf((progress - 0.65) / 0.35, 0.0, 1.0)
	if fall > 0.0:
		var shell := Vector2(0.0, -900.0 * (1.0 - fall))
		draw_line(shell + Vector2(0, -30), shell, Color(1.0, 0.8, 0.5, 0.6), 3.0)
		Art.disc(self, shell, 7.0, Color(0.35, 0.36, 0.45))
