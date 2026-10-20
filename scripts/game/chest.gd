class_name Chest
extends Node2D
## Kiste auf der Karte (wie in Risk of Rain): Mit Gold und Interagieren oeffnen, drin steckt ein zufaelliges
## Item fuer den, der sie aufmacht. Sie zu finden lohnt den Weg ueber die grosse Karte. Die grosse
## Goldkiste kostet mehr und enthaelt immer ein Verhaltens-Item.

signal opened(chest: Chest, player: Player)

const USE_RANGE := 85.0
const BODY := Vector2(58.0, 38.0)

var players: Array[Player] = []
var price := 20
var large := false
var is_open := false

var _age := 0.0
var _lid := 0.0
var _deny := 0.0
var _fade := 1.0
var _near := -1


func _ready() -> void:
	add_to_group("chests")
	z_index = 1


func can_afford(player: Player) -> bool:
	return player.gold >= price


func _physics_process(delta: float) -> void:
	_age += delta
	_deny = maxf(0.0, _deny - delta * 3.0)
	if is_open:
		_lid = minf(1.0, _lid + delta * 4.0)
		if _age > 4.0:
			_fade -= delta
			modulate.a = clampf(_fade, 0.0, 1.0)
			if _fade <= 0.0:
				queue_free()
		queue_redraw()
		return
	_near = -1
	var best := USE_RANGE
	for i in players.size():
		var player := players[i]
		if player.downed:
			continue
		var distance := player.global_position.distance_to(global_position + Vector2(0.0, -BODY.y * 0.5))
		if distance < best:
			best = distance
			_near = i
	if _near >= 0:
		var player := players[_near]
		if Input.is_action_just_pressed("p%d_interact" % player.player_index) and not _reviving(player):
			_try_open(player)
	queue_redraw()


## Liegt der Partner am Boden und in Reichweite, hat Wiederbeleben Vorrang (gleiche Taste).
func _reviving(player: Player) -> bool:
	for other in players:
		if other != player and other.downed and other.global_position.distance_to(player.global_position) <= Player.REVIVE_RANGE * 1.5:
			return true
	return false


func _try_open(player: Player) -> void:
	if not can_afford(player):
		_deny = 1.0
		Sfx.play("hurt", 0.05)
		return
	player.gold -= price
	is_open = true
	_age = 0.0
	Sfx.play("deploy", 0.05)
	opened.emit(self, player)


func _draw() -> void:
	var gold := Color(1.0, 0.82, 0.3)
	var steel := Color(0.36, 0.4, 0.5)
	var trim := Color(0.95, 0.6, 0.2) if not large else Color(1.0, 0.82, 0.3)
	var scale_factor := 1.35 if large else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_factor)
	var bob := 0.0 if is_open else sin(_age * 2.4) * 1.5
	# Lichtsaeule und Schein: von weitem als Beute zu erkennen.
	if not is_open:
		var glow := Color(trim, 0.07 + 0.03 * sin(_age * 3.0))
		draw_colored_polygon(PackedVector2Array([Vector2(-16, -BODY.y), Vector2(16, -BODY.y), Vector2(34, -230), Vector2(-34, -230)]), glow)
		Art.glow(self, Vector2(0, -BODY.y * 0.5), 46.0, trim)
	Art.shadow(self, Vector2(0, 1), 34.0, 4.5, 0.4)
	var offset := Vector2(randf_range(-1.0, 1.0), 0.0) * 3.0 * _deny
	# Korpus.
	var body := Rect2(Vector2(-BODY.x * 0.5, -BODY.y) + offset + Vector2(0, bob * 0.3), BODY)
	Art.panel(self, body, steel, 5.0)
	draw_rect(Rect2(body.position + Vector2(0, 12), Vector2(BODY.x, 5)), trim)
	for k in 2:
		draw_rect(Rect2(body.position + Vector2(8 + k * (BODY.x - 22), 0), Vector2(6, BODY.y)), trim.darkened(0.25))
	# Deckel: sitzt auf einem Scharnier hinten links und klappt beim Oeffnen nach hinten.
	var lid_h := 14.0
	draw_set_transform(Vector2(-BODY.x * 0.5, -BODY.y + 2.0) * scale_factor + offset, -_lid * 1.6, Vector2.ONE * scale_factor)
	var lid := Rect2(Vector2(0.0, -lid_h), Vector2(BODY.x, lid_h))
	Art.panel(self, lid, steel.lightened(0.1), 6.0)
	draw_rect(Rect2(lid.position + Vector2(0, lid_h - 4), Vector2(BODY.x, 4)), trim)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_factor)
	if not is_open:
		# Schloss, leuchtet auf, solange jemand nah ist.
		var lock_on := _near >= 0
		Art.led(self, Vector2(0, -BODY.y + 8.0) + offset, 3.5, gold if lock_on else Color(0.9, 0.35, 0.25), true)
	else:
		# Offen: Lichtschein aus dem Inneren.
		Art.glow(self, Vector2(0, -BODY.y - 8.0), 36.0, gold)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if is_open:
		return
	# Preis ueber der Kiste, gruen wenn der naechste Spieler ihn zahlen kann, sonst rot.
	var font := ThemeDB.fallback_font
	var tag_y := -BODY.y * scale_factor - 40.0
	var affordable := _near < 0 or can_afford(players[_near])
	var tag_color := gold if affordable else Color(1.0, 0.45, 0.4)
	var label := "%d" % price
	var tag := Rect2(Vector2(-36.0, tag_y - 16.0), Vector2(72.0, 26.0))
	Art.rrect(self, tag, Color(0.04, 0.05, 0.09, 0.85), 8.0)
	Art.rrect_line(self, tag, Color(tag_color, 0.9), 8.0, 1.5)
	draw_circle(tag.position + Vector2(15, 13), 6.0, gold)
	draw_arc(tag.position + Vector2(15, 13), 6.0, 0.0, TAU, 14, Color(0.6, 0.4, 0.05), 1.5, true)
	draw_string(font, tag.position + Vector2(26, 19), label, HORIZONTAL_ALIGNMENT_LEFT, 44.0, 16, tag_color)
	if _near >= 0:
		var prompt := "Kreis / G / L: öffnen" if affordable else "zu wenig Gold"
		draw_string_outline(font, Vector2(-100.0, tag_y + 30.0), prompt, HORIZONTAL_ALIGNMENT_CENTER, 200.0, 15, 5, Color(0.03, 0.03, 0.07, 0.9))
		draw_string(font, Vector2(-100.0, tag_y + 30.0), prompt, HORIZONTAL_ALIGNMENT_CENTER, 200.0, 15, Color(0.9, 0.95, 1.0) if affordable else Color(1.0, 0.55, 0.5))
