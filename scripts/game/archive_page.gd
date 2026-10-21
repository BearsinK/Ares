class_name ArchivePage
extends RefCounted
## Archiv-Seite im Titelmenue: links die Liste einer Art (Items, Gegner, Waffen), rechts die Beschreibung.
## Links/Rechts wechselt die Art, Hoch/Runter den Eintrag. Unentdeckte Eintraege bleiben "???".

const ROW_HEIGHT := 40.0

var tab := 0
var cursor := 0

var _horizontal := HoldRepeat.new()
var _vertical := HoldRepeat.new()
var _cache: Array[Dictionary] = []
var _cache_tab := -1
var _time := 0.0


func kind() -> String:
	return Archive.KINDS[tab]


func entries() -> Array[Dictionary]:
	if _cache_tab != tab:
		_cache = Archive.entries(kind())
		_cache_tab = tab
	return _cache


func open() -> void:
	tab = 0
	cursor = 0
	_cache_tab = -1


## Eine Eingaberunde. Gibt true zurueck, wenn die Seite geschlossen werden soll.
func update(delta: float) -> bool:
	_time += delta
	if UiKit.back():
		return true
	var side := _horizontal.step(delta, "left", "right")
	if side != 0:
		tab = (tab + side + Archive.KINDS.size()) % Archive.KINDS.size()
		cursor = 0
		Sfx.play("switch")
	var step := _vertical.step(delta, "up", "down")
	if step != 0:
		var count := entries().size()
		cursor = (cursor + step + count) % count
		Sfx.play("switch")
	return false


func draw(c: CanvasItem, view: Vector2) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.8))
	var total := 0
	var found := 0
	for k in Archive.KINDS:
		var p := Archive.progress(k)
		found += p.x
		total += p.y
	UiKit.text(c, Vector2(0, 80), "ARCHIV", 52, Color(1.0, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	UiKit.text(c, Vector2(0, 108), "%d von %d Einträgen entdeckt" % [found, total], 18, Color(0.7, 0.74, 0.88), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	# Reiter.
	for i in Archive.KINDS.size():
		var p := Archive.progress(Archive.KINDS[i])
		var rect := Rect2(Vector2(view.x * 0.5 - 330.0 + i * 230.0, 124.0), Vector2(210.0, 44.0))
		UiKit.button(c, rect, "%s  %d/%d" % [Archive.KIND_NAMES[Archive.KINDS[i]], p.x, p.y], i == tab, Color(0.4, 0.75, 1.0), 20)
	var panel := Rect2(Vector2(view.x * 0.5 - 640.0, 184.0), Vector2(1280.0, 620.0))
	Art.panel(c, panel, Color(0.09, 0.11, 0.18), 18.0, Color(1, 1, 1, 0.28))
	_draw_list(c, Rect2(panel.position + Vector2(16.0, 16.0), Vector2(440.0, panel.size.y - 32.0)))
	_draw_detail(c, Rect2(panel.position + Vector2(480.0, 16.0), Vector2(panel.size.x - 496.0, panel.size.y - 32.0)))
	UiKit.text(c, Vector2(0, view.y - 40.0), "Links/Rechts: Art wechseln, Hoch/Runter: Eintrag, Kreis zurück", 18, Color(0.65, 0.68, 0.8), HORIZONTAL_ALIGNMENT_CENTER, view.x)


func _draw_list(c: CanvasItem, area: Rect2) -> void:
	var list := entries()
	var visible_rows := int(area.size.y / ROW_HEIGHT)
	var first := clampi(cursor - visible_rows / 2, 0, maxi(0, list.size() - visible_rows))
	for k in visible_rows:
		var index := first + k
		if index >= list.size():
			break
		var entry := list[index]
		var found := Archive.is_found(kind(), String(entry.id))
		var rect := Rect2(area.position + Vector2(0.0, k * ROW_HEIGHT), Vector2(area.size.x, ROW_HEIGHT - 4.0))
		var selected := index == cursor
		if selected:
			Art.rrect(c, rect, Color(0.2, 0.25, 0.38), 8.0)
			Art.rrect_line(c, rect, Color(0.4, 0.75, 1.0), 8.0, 2.0)
		_draw_icon(c, entry, rect.position + Vector2(24.0, rect.size.y * 0.5), 26.0, found)
		var label := String(entry.name) if found else "???"
		UiKit.text(c, rect.position + Vector2(52.0, 26.0), label, 20, (Color.WHITE if selected else Color(0.82, 0.85, 0.95)) if found else Color(0.5, 0.52, 0.62))
		if found and kind() == "enemies":
			UiKit.text(c, rect.position + Vector2(0.0, 26.0), "x%d" % SaveData.archive_kills(String(entry.id)), 16, Color(0.7, 0.74, 0.88), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 12.0)
		elif found and entry.get("rare", false):
			UiKit.text(c, rect.position + Vector2(0.0, 26.0), "selten", 15, Color(1.0, 0.85, 0.4), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 12.0)
	if list.size() > visible_rows:
		var track := Rect2(area.end.x + 6.0, area.position.y, 4.0, area.size.y)
		c.draw_rect(track, Color(1, 1, 1, 0.1))
		var thumb_h := track.size.y * float(visible_rows) / float(list.size())
		c.draw_rect(Rect2(track.position.x, track.position.y + (track.size.y - thumb_h) * float(first) / float(list.size() - visible_rows), 4.0, thumb_h), Color(0.5, 0.8, 1.0, 0.7))


func _draw_detail(c: CanvasItem, area: Rect2) -> void:
	var list := entries()
	var entry := list[cursor]
	var found := Archive.is_found(kind(), String(entry.id))
	var color: Color = entry.color if found else Color(0.4, 0.42, 0.52)
	Art.rrect(c, Rect2(area.position, Vector2(area.size.x, 200.0)), Color(0.06, 0.07, 0.13), 14.0)
	Art.glow(c, area.position + Vector2(110.0, 100.0), 90.0, color)
	_draw_icon(c, entry, area.position + Vector2(110.0, 104.0), 120.0, found)
	if not found:
		UiKit.text(c, area.position + Vector2(230.0, 90.0), "???", 52, Color(0.55, 0.57, 0.68))
		UiKit.text(c, area.position + Vector2(230.0, 130.0), "Noch nicht entdeckt", 22, Color(0.7, 0.72, 0.85))
		UiKit.text(c, area.position + Vector2(0.0, 250.0), String(Archive.HINTS[kind()]), 22, Color(0.8, 0.83, 0.93), HORIZONTAL_ALIGNMENT_LEFT, area.size.x, true)
		return
	UiKit.text(c, area.position + Vector2(230.0, 76.0), String(entry.tag), 17, Color(color, 1.0).lightened(0.2))
	UiKit.text(c, area.position + Vector2(230.0, 124.0), String(entry.name), 44, Color.WHITE)
	if kind() == "enemies" and EnemyTypes.DATA.has(String(entry.id)):
		UiKit.text(c, area.position + Vector2(230.0, 164.0), "Besiegt: %d" % SaveData.archive_kills(String(entry.id)), 18, Color(0.7, 0.74, 0.88))
	c.draw_rect(Rect2(area.position + Vector2(0.0, 214.0), Vector2(90.0, 4.0)), color)
	UiKit.text(c, area.position + Vector2(0.0, 258.0), String(entry.text), 23, Color(0.92, 0.94, 1.0), HORIZONTAL_ALIGNMENT_LEFT, area.size.x, true)
	var y := area.position.y + 360.0
	for line in entry.stats:
		UiKit.text(c, Vector2(area.position.x, y), String(line), 20, Color(1.0, 0.9, 0.5))
		y += 32.0


## Bild eines Eintrags: Item-Symbol, Gegnerfigur oder Waffenfarbe. Unentdeckt als graues Fragezeichen.
func _draw_icon(c: CanvasItem, entry: Dictionary, center: Vector2, size: float, found: bool) -> void:
	if not found:
		UiKit.text(c, center + Vector2(-size * 0.2, size * 0.2), "?", int(size * 0.8), Color(0.4, 0.42, 0.52))
		return
	match kind():
		"items":
			PerkArt.draw(c, String(entry.id), center, size)
		"enemies":
			var art := String(entry.art)
			var info: Dictionary = EnemyTypes.DATA[art]
			var zoom := size / (48.0 if size > 60.0 else 34.0)
			if String(entry.id) == "elite":
				zoom *= 1.2
			RobotArt.draw_enemy(c, art, {
				"facing": 1.0, "aim": Vector2.RIGHT, "t": _time, "walk": _time * 3.0, "flash": false, "windup": -1.0,
				"slam": false, "vx": 0.0, "grounded": true, "hurt": 0.0, "fire": 0.0, "hp_frac": 1.0,
				"foot": float(info.radius), "lod": false, "squash": Vector2.ONE,
			}, center + Vector2(0.0, size * 0.18), zoom)
		"weapons":
			var color: Color = entry.color
			var half := size * 0.42
			Art.rrect(c, Rect2(center + Vector2(-half, -half * 0.28), Vector2(half * 2.0, half * 0.56)), color.darkened(0.45), half * 0.18)
			Art.rrect(c, Rect2(center + Vector2(-half * 0.2, -half * 0.28), Vector2(half * 1.2, half * 0.3)), color, half * 0.1)
			c.draw_rect(Rect2(center + Vector2(half * 0.9, -half * 0.12), Vector2(half * 0.5, half * 0.24)), color.lightened(0.3))
