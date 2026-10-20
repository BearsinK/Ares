class_name Altar
extends Chest
## Altar (wie die Schreine in Risk of Rain), dreimal nutzbar:
##   blood   tauscht 30 Prozent der maximalen Leben gegen Gold, ist nur mit genug Leben ueber der Schwelle moeglich
##   chance  kostet Gold, mit etwas Glueck faellt ein Item heraus, sonst eine Niete

const HP_COST := 0.3
const HP_RESERVE := 0.1
const MAX_USES := 3

var kind := "blood"
var uses_left := MAX_USES

var _flash := 0.0


func can_afford(player: Player) -> bool:
	if kind == "blood":
		return player.hp > player.max_health() * (HP_COST + HP_RESERVE)
	return player.gold >= price


func _try_open(player: Player) -> void:
	if not can_afford(player):
		_deny = 1.0
		Sfx.play("hurt", 0.05)
		return
	if kind == "blood":
		player.pay_health(player.max_health() * HP_COST)
	else:
		player.gold -= price
	uses_left -= 1
	_flash = 1.0
	Sfx.play("deploy", 0.05)
	opened.emit(self, player)
	if uses_left <= 0:
		is_open = true
		_age = 0.0


func _physics_process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 2.5)
	super._physics_process(delta)


func _color() -> Color:
	return Color(1.0, 0.3, 0.35) if kind == "blood" else Color(0.75, 0.55, 1.0)


func _draw() -> void:
	var color := _color()
	var stone := Color(0.34, 0.33, 0.4)
	var spent := is_open
	# Lichtsaeule in der Farbe des Altars.
	if not spent:
		var glow := Color(color, 0.08 + 0.03 * sin(_age * 3.0) + 0.1 * _flash)
		draw_colored_polygon(PackedVector2Array([Vector2(-14, -48), Vector2(14, -48), Vector2(32, -240), Vector2(-32, -240)]), glow)
		Art.glow(self, Vector2(0, -50), 44.0, color)
	Art.shadow(self, Vector2(0, 1), 32.0, 4.5, 0.4)
	var offset := Vector2(randf_range(-1.0, 1.0), 0.0) * 3.0 * _deny
	# Sockel: abgestufter Stein.
	Art.panel(self, Rect2(Vector2(-30, -14) + offset, Vector2(60, 14)), stone.darkened(0.1), 4.0)
	Art.panel(self, Rect2(Vector2(-22, -34) + offset, Vector2(44, 22)), stone, 4.0)
	draw_rect(Rect2(Vector2(-22, -34) + offset, Vector2(44, 4)), Color(color, 0.9 if not spent else 0.25))
	if kind == "blood":
		# Schale mit Blut: Pegel sinkt mit den Nutzungen, Tropfen fallen.
		var level := 0.35 + 0.65 * float(uses_left) / float(MAX_USES) if not spent else 0.1
		Art.panel(self, Rect2(Vector2(-18, -46) + offset, Vector2(36, 14)), stone.lightened(0.08), 6.0)
		draw_rect(Rect2(Vector2(-14, -44 + (1.0 - level) * 7.0) + offset, Vector2(28, 3.0 + level * 4.0)), Color(0.8, 0.1, 0.15) if not spent else Color(0.3, 0.1, 0.12))
		if not spent:
			var drop := fmod(_age * 1.3, 1.0)
			draw_circle(Vector2(sin(_age * 2.0) * 6.0, -62 + drop * 14.0) + offset, 2.4 * (1.0 - drop * 0.4), Color(0.9, 0.15, 0.2, 1.0 - drop))
	else:
		# Schwebender Wuerfel, dreht sich.
		var turn := _age * 1.8
		var center := Vector2(0, -60 + sin(_age * 2.4) * 3.0) + offset
		var half := 11.0
		var points := PackedVector2Array()
		for k in 4:
			var a := turn + PI * 0.25 + k * PI * 0.5
			points.append(center + Vector2(cos(a) * half * 1.2, sin(a) * half * 0.9))
		draw_colored_polygon(points, Color(0.18, 0.12, 0.28) if spent else Color(0.9, 0.85, 1.0))
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), color, 2.5, true)
		for pip in [Vector2(-0.3, -0.3), Vector2(0.3, 0.3), Vector2(0.3, -0.3), Vector2(-0.3, 0.3)]:
			draw_circle(center + pip * half, 1.6, color if not spent else Color(0.3, 0.25, 0.4))
	if _flash > 0.0:
		Art.glow(self, Vector2(0, -56), 56.0 * _flash, color)
	if is_open:
		return
	# Schild mit Preis und Nutzungen, rot wenn nicht moeglich.
	var font := ThemeDB.fallback_font
	var affordable := _near < 0 or can_afford(players[_near])
	var tag_color := color if affordable else Color(0.6, 0.6, 0.66)
	var tag := Rect2(Vector2(-52.0, -112.0), Vector2(104.0, 26.0))
	Art.rrect(self, tag, Color(0.04, 0.05, 0.09, 0.85), 8.0)
	Art.rrect_line(self, tag, Color(tag_color, 0.9), 8.0, 1.5)
	var label := "%d%% Leben" % int(HP_COST * 100.0) if kind == "blood" else "%d" % price
	if kind == "blood":
		draw_string(font, tag.position + Vector2(0, 19), label, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x - 22.0, 15, tag_color)
	else:
		draw_circle(tag.position + Vector2(15, 13), 6.0, Color(1.0, 0.82, 0.3))
		draw_string(font, tag.position + Vector2(27, 19), label, HORIZONTAL_ALIGNMENT_LEFT, 46.0, 16, tag_color)
	draw_string(font, tag.position + Vector2(tag.size.x - 28.0, 19), "x%d" % uses_left, HORIZONTAL_ALIGNMENT_RIGHT, 24.0, 14, Color(0.85, 0.88, 0.97))
	if _near >= 0:
		var prompt := ("Kreis / G / L: opfern" if kind == "blood" else "Kreis / G / L: würfeln") if affordable else ("zu wenig Leben" if kind == "blood" else "zu wenig Gold")
		draw_string_outline(font, Vector2(-100.0, -120.0), prompt, HORIZONTAL_ALIGNMENT_CENTER, 200.0, 15, 5, Color(0.03, 0.03, 0.07, 0.9))
		draw_string(font, Vector2(-100.0, -120.0), prompt, HORIZONTAL_ALIGNMENT_CENTER, 200.0, 15, Color(0.9, 0.95, 1.0) if affordable else Color(1.0, 0.55, 0.5))
