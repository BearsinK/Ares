class_name ShopMenu
extends CanvasLayer
## Shop zwischen den Wellen. Beide Spieler kaufen gleichzeitig und persoenlich
## mit ihrem eigenen Gold. Links/Rechts waehlt (vier Angebote, Reroll, Fertig),
## Bestaetigen fuehrt die Aktion aus. Sind beide fertig, geht es weiter.

signal closed

const CARD_WIDTH := 168.0
const CARD_HEIGHT := 262.0
const CARD_GAP := 12.0
const GRACE_TIME := 0.5
const READY_SLOT := 5
const REROLL_SLOT := 4

var players: Array[Player] = []
var wave := 1
## Letzter Shop vor dem Endboss (andere Ueberschrift).
var before_boss := false
var is_open := false

var _offers: Array = [[], []]
var _cursor := [0, 0]
## Auswahl des Waffen-Slots beim Kauf: {} oder {offer, slot_cursor, kind}
var _pick: Array[Dictionary] = [{}, {}]
var _ready_flags := [false, false]
var _rerolls := [0, 0]
var _messages := ["", ""]
var _message_time := [0.0, 0.0]
var _age := 0.0
var _canvas: Node2D


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_menu)
	add_child(_canvas)
	visible = false


func open(new_players: Array[Player], new_wave: int) -> void:
	players = new_players
	wave = new_wave
	_offers = [ShopItems.make_offers(players[0], wave), ShopItems.make_offers(players[1], wave)]
	_cursor = [0, 0]
	_pick = [{}, {}]
	_ready_flags = [false, false]
	_rerolls = [0, 0]
	_messages = ["", ""]
	_age = 0.0
	is_open = true
	visible = true
	get_tree().paused = true
	Sfx.play("levelup")


func _process(delta: float) -> void:
	if not is_open:
		return
	_age += delta
	for i in 2:
		_message_time[i] = maxf(0.0, _message_time[i] - delta)
	if _age >= GRACE_TIME:
		for i in 2:
			_handle_player(i)
		if _ready_flags[0] and _ready_flags[1]:
			_finish()
	_canvas.queue_redraw()


func _handle_pick(i: int) -> void:
	var prefix := "p%d_" % (i + 1)
	var player := players[i]
	var count: int = player.weapons.size()
	var move := 0
	if Input.is_action_just_pressed(prefix + "left"):
		move -= 1
	if Input.is_action_just_pressed(prefix + "right"):
		move += 1
	if move != 0:
		_pick[i].slot = posmod(int(_pick[i].slot) + move, count)
		Sfx.play("switch")
	if Input.is_action_just_pressed(prefix + "interact"):
		_pick[i] = {}
		Sfx.play("switch")
		return
	if Input.is_action_just_pressed(prefix + "confirm"):
		var offer: Dictionary = _pick[i].offer
		if player.gold < offer.price:
			_say(i, "Zu wenig Gold")
			_pick[i] = {}
			return
		player.gold -= offer.price
		offer.bought = true
		ShopItems.apply(player, offer, int(_pick[i].slot))
		_pick[i] = {}
		Sfx.play("coin")


func _handle_player(i: int) -> void:
	var prefix := "p%d_" % (i + 1)
	if not _pick[i].is_empty():
		_handle_pick(i)
		return
	if _ready_flags[i]:
		# Wer fertig ist, kann mit Interagieren zurueckgehen.
		if Input.is_action_just_pressed(prefix + "interact"):
			_ready_flags[i] = false
		return
	var move := 0
	if Input.is_action_just_pressed(prefix + "left"):
		move -= 1
	if Input.is_action_just_pressed(prefix + "right"):
		move += 1
	var vertical := 0
	if Input.is_action_just_pressed(prefix + "up"):
		vertical -= 1
	if Input.is_action_just_pressed(prefix + "down"):
		vertical += 1
	var before: int = _cursor[i]
	var slot: int = _cursor[i]
	if vertical != 0:
		# Zwei Zeilen: Angebote oben, Reroll und Fertig unten.
		if vertical > 0 and slot < REROLL_SLOT:
			slot = REROLL_SLOT if slot <= 1 else READY_SLOT
		elif vertical < 0 and slot >= REROLL_SLOT:
			slot = 1 if slot == REROLL_SLOT else 2
	elif move != 0:
		if slot >= REROLL_SLOT:
			slot = clampi(slot + move, REROLL_SLOT, READY_SLOT)
		else:
			slot = clampi(slot + move, 0, REROLL_SLOT - 1)
	_cursor[i] = slot
	if slot != before:
		Sfx.play("switch")
	if Input.is_action_just_pressed(prefix + "confirm"):
		_activate(i)


func _activate(i: int) -> void:
	var slot: int = _cursor[i]
	var player := players[i]
	if slot == READY_SLOT:
		_ready_flags[i] = true
		Sfx.play("pickup")
	elif slot == REROLL_SLOT:
		var price := _reroll_price(i)
		if player.gold < price:
			_say(i, "Zu wenig Gold")
			return
		player.gold -= price
		_rerolls[i] += 1
		_offers[i] = ShopItems.make_offers(player, wave)
		Sfx.play("coin")
	else:
		var offers: Array = _offers[i]
		if slot >= offers.size():
			return
		var offer: Dictionary = offers[slot]
		if offer.bought:
			return
		if player.gold < offer.price:
			_say(i, "Zu wenig Gold")
			return
		# Waffe bei vollen Slots und Modul bei mehreren Waffen: erst waehlen, welcher Slot gemeint ist.
		var needs_slot: bool = (offer.type == "weapon" and player.weapons.size() >= 3) or (offer.type == "module" and player.weapons.size() > 1)
		if needs_slot:
			_pick[i] = {"offer": offer, "slot": player.weapon_index}
			Sfx.play("switch")
			return
		player.gold -= offer.price
		offer.bought = true
		ShopItems.apply(player, offer)
		Sfx.play("coin")


func _reroll_price(i: int) -> int:
	if _rerolls[i] == 0 and SaveData.level("dealer") > 0:
		return 0
	return ShopItems.reroll_price(_rerolls[i])


func _say(i: int, text: String) -> void:
	_messages[i] = text
	_message_time[i] = 1.5
	Sfx.play("deny")


func _finish() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	closed.emit()


func _draw_menu() -> void:
	var view := _canvas.get_viewport_rect().size
	var font := ThemeDB.fallback_font
	_canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.78))
	UiKit.text(_canvas, Vector2(0, 110), ("LETZTER SHOP  vor dem Endboss" if before_boss else "SHOP  nach Welle %d" % wave), 48, Color(1.0, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	UiKit.text(_canvas, Vector2(0, 144), "Pfeile oder Stick: wählen (runter: Reroll und Fertig), Kreuz: kaufen. Wenn beide FERTIG sind, geht es weiter.", 17, Color(0.78, 0.8, 0.92), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	for i in 2:
		_draw_player_column(i, Vector2(40.0 + i * (view.x * 0.5), 190.0), view.x * 0.5 - 80.0, font)


func _draw_player_column(i: int, origin: Vector2, width: float, font: Font) -> void:
	var player := players[i]
	var color: Color = RobotClasses.PLAYER_COLORS[i]
	_canvas.draw_string(font, origin + Vector2(0, 24), "P%d  %s" % [i + 1, player.stats.name], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, color)
	_canvas.draw_string(font, origin + Vector2(0, 24), "Gold %d" % player.gold, HORIZONTAL_ALIGNMENT_RIGHT, width, 24, Color(1.0, 0.85, 0.3))
	var weapon_names: Array[String] = []
	for j in player.weapons.size():
		var label: String = Weapons.get_weapon(player.weapons[j]).name
		if player.modules[j] != "":
			label += " (%s)" % Elements.NAMES[player.modules[j]]
		weapon_names.append(("[%s]" if j == player.weapon_index else "%s") % label)
	_canvas.draw_string(font, origin + Vector2(0, 52), "  ".join(weapon_names), HORIZONTAL_ALIGNMENT_LEFT, width, 16, Color(0.8, 0.8, 0.9))

	var offers: Array = _offers[i]
	for slot in 4:
		var pos := origin + Vector2(slot * (CARD_WIDTH + CARD_GAP), 80.0)
		_draw_offer(i, slot, pos, offers[slot] if slot < offers.size() else {}, font)

	var button_y := origin.y + 80.0 + CARD_HEIGHT + 24.0
	var reroll_pos := Vector2(origin.x, button_y)
	var ready_pos := Vector2(origin.x + 300.0, button_y)
	_draw_button(i, REROLL_SLOT, reroll_pos, Vector2(280.0, 50.0), "Reroll  (%s)" % (("gratis" if _reroll_price(i) == 0 else "%d Gold" % _reroll_price(i))), font)
	_draw_button(i, READY_SLOT, ready_pos, Vector2(280.0, 50.0), "FERTIG" if not _ready_flags[i] else "BEREIT", font)
	if _message_time[i] > 0.0:
		_canvas.draw_string(font, Vector2(origin.x, button_y + 80.0), _messages[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.5, 0.4))
	if not _pick[i].is_empty():
		_draw_pick(i, Rect2(origin + Vector2(0, 70.0), Vector2(width, CARD_HEIGHT + 90.0)), font)


## Overlay: welcher Waffen-Slot bekommt die Waffe (ersetzt) oder das Modul.
func _draw_pick(i: int, rect: Rect2, font: Font) -> void:
	var player := players[i]
	var offer: Dictionary = _pick[i].offer
	var accent: Color = RobotClasses.PLAYER_COLORS[i]
	Art.panel(_canvas, rect, Color(0.07, 0.08, 0.14), 14.0, accent)
	var title := "Welche Waffe ersetzen?" if offer.type == "weapon" else "Welche Waffe bekommt das Modul?"
	UiKit.text(_canvas, rect.position + Vector2(0, 40), title, 26, Color(1.0, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	UiKit.text(_canvas, rect.position + Vector2(0, 74), "%s  (%d Gold)" % [offer.name, int(offer.price)], 20, offer.color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	if offer.type == "module":
		UiKit.text(_canvas, rect.position + Vector2(30, 106), String(offer.text), 16, Color(0.82, 0.85, 0.95), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 60.0, true)
	var count: int = player.weapons.size()
	var width := (rect.size.x - 40.0 - (count - 1) * 12.0) / float(count)
	for k in count:
		var slot_rect := Rect2(rect.position + Vector2(20.0 + k * (width + 12.0), 150.0), Vector2(width, 150.0))
		var selected: bool = int(_pick[i].slot) == k
		Art.panel(_canvas, slot_rect, Color(0.2, 0.24, 0.36) if selected else Color(0.11, 0.12, 0.18), 12.0, accent if selected else Color(1, 1, 1, 0.2))
		var weapon: Dictionary = Weapons.get_weapon(player.weapons[k])
		UiKit.text(_canvas, slot_rect.position + Vector2(0, 34), "Slot %d" % (k + 1), 15, Color(0.7, 0.74, 0.88), HORIZONTAL_ALIGNMENT_CENTER, width)
		UiKit.text(_canvas, slot_rect.position + Vector2(0, 66), String(weapon.name), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, width)
		var module: String = player.modules[k]
		if module != "":
			_canvas.draw_circle(slot_rect.position + Vector2(width * 0.5 - 40.0, 96.0), 7.0, Elements.COLORS[module])
			UiKit.text(_canvas, slot_rect.position + Vector2(width * 0.5 - 28.0, 102.0), String(Elements.NAMES[module]), 16, Color(0.9, 0.92, 1.0))
		else:
			UiKit.text(_canvas, slot_rect.position + Vector2(0, 102), "kein Modul", 15, Color(0.55, 0.58, 0.7), HORIZONTAL_ALIGNMENT_CENTER, width)
		if selected:
			UiKit.text(_canvas, slot_rect.position + Vector2(0, 136), "<  wählen  >", 15, accent, HORIZONTAL_ALIGNMENT_CENTER, width)
	UiKit.text(_canvas, rect.position + Vector2(0, rect.size.y - 24.0), "Links/Rechts: Slot, Kreuz: kaufen, Kreis: abbrechen", 16, Color(0.75, 0.78, 0.9), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


func _draw_offer(i: int, slot: int, pos: Vector2, offer: Dictionary, font: Font) -> void:
	var selected: bool = _cursor[i] == slot and not _ready_flags[i]
	var rect := Rect2(pos, Vector2(CARD_WIDTH, CARD_HEIGHT))
	var border: Color = RobotClasses.PLAYER_COLORS[i] if selected else Color(1, 1, 1, 0.2)
	Art.panel(_canvas, rect, Color(0.2, 0.22, 0.32) if selected else Color(0.12, 0.13, 0.19), 12.0, border)
	if offer.is_empty():
		return
	if offer.bought:
		_canvas.draw_string(font, pos + Vector2(0, 120), "GEKAUFT", HORIZONTAL_ALIGNMENT_CENTER, CARD_WIDTH, 22, Color(0.5, 1.0, 0.5))
		return
	var type_labels := {"perk": "BUFF", "module": "MODUL", "weapon": "WAFFE", "firmware": "FIRMWARE", "repair": "SERVICE"}
	var accent: Color = PerkArt.color_of(offer.id) if offer.type == "perk" else offer.color
	_canvas.draw_rect(Rect2(pos + Vector2(12, 0), Vector2(48, 4)), accent)
	UiKit.text(_canvas, pos + Vector2(12, 24), type_labels[offer.type], 13, accent)
	_draw_offer_icon(offer, pos + Vector2(CARD_WIDTH * 0.5, 66.0), accent)
	UiKit.text(_canvas, pos + Vector2(0, 124), offer.name, 19, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, CARD_WIDTH)
	UiKit.text(_canvas, pos + Vector2(12, 150), offer.text, 14, Color(0.85, 0.86, 0.92), HORIZONTAL_ALIGNMENT_LEFT, CARD_WIDTH - 24.0, true)
	var affordable: bool = players[i].gold >= offer.price
	_canvas.draw_string(font, pos + Vector2(0, CARD_HEIGHT - 16), "%d Gold" % offer.price, HORIZONTAL_ALIGNMENT_CENTER, CARD_WIDTH, 22,
		Color(1.0, 0.85, 0.3) if affordable else Color(0.6, 0.4, 0.4))


func _draw_offer_icon(offer: Dictionary, center: Vector2, accent: Color) -> void:
	match offer.type:
		"perk":
			PerkArt.draw(_canvas, offer.id, center, 54.0)
		"module":
			Art.glow(_canvas, center, 40.0, accent)
			Art.disc(_canvas, center, 20.0, accent.darkened(0.1), Color(1, 1, 1, 0.8))
			_canvas.draw_circle(center + Vector2(-6, -7), 6.0, Color(1, 1, 1, 0.55))
		"weapon":
			Art.glow(_canvas, center, 40.0, accent)
			Art.rrect(_canvas, Rect2(center + Vector2(-24, -8), Vector2(48, 16)), Color(0.35, 0.38, 0.48), 5.0)
			Art.rrect(_canvas, Rect2(center + Vector2(10, -5), Vector2(22, 10)), accent, 4.0)
			Art.rrect(_canvas, Rect2(center + Vector2(-20, 6), Vector2(12, 14)), Color(0.28, 0.3, 0.4), 4.0)
		"repair":
			Art.glow(_canvas, center, 40.0, accent)
			Art.disc(_canvas, center, 22.0, Color(0.9, 0.97, 0.92), Color(0.2, 0.6, 0.35))
			_canvas.draw_rect(Rect2(center + Vector2(-11, -3.5), Vector2(22, 7)), Color(0.2, 0.75, 0.35))
			_canvas.draw_rect(Rect2(center + Vector2(-3.5, -11), Vector2(7, 22)), Color(0.2, 0.75, 0.35))
		_:
			Art.glow(_canvas, center, 40.0, accent)
			PerkArt.draw_firmware(_canvas, offer.id, center, 54.0, accent)


func _draw_button(i: int, slot: int, pos: Vector2, size: Vector2, text: String, font: Font) -> void:
	var selected: bool = _cursor[i] == slot
	var active: bool = slot == READY_SLOT and _ready_flags[i]
	var fill := Color(0.2, 0.5, 0.3) if active else (Color(0.2, 0.22, 0.32) if selected else Color(0.12, 0.13, 0.19))
	var border: Color = RobotClasses.PLAYER_COLORS[i] if selected else Color(1, 1, 1, 0.2)
	Art.panel(_canvas, Rect2(pos, size), fill, 12.0, border)
	_canvas.draw_string(font, pos + Vector2(0, 33), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color.WHITE)
