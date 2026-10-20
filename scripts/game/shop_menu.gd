class_name ShopMenu
extends CanvasLayer
## Shop zwischen den Wellen. Beide Spieler kaufen gleichzeitig und persoenlich
## mit ihrem eigenen Gold. Links/Rechts waehlt (vier Angebote, Reroll, Fertig),
## Bestaetigen fuehrt die Aktion aus. Sind beide fertig, geht es weiter.

signal closed

const CARD_WIDTH := 168.0
const CARD_HEIGHT := 230.0
const CARD_GAP := 12.0
const GRACE_TIME := 0.5
const READY_SLOT := 5
const REROLL_SLOT := 4

var players: Array[Player] = []
var wave := 1
var is_open := false

var _offers: Array = [[], []]
var _cursor := [0, 0]
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


func _handle_player(i: int) -> void:
	var prefix := "p%d_" % (i + 1)
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
	if move != 0:
		_cursor[i] = clampi(_cursor[i] + move, 0, READY_SLOT)
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
		var price := ShopItems.reroll_price(_rerolls[i])
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
		player.gold -= offer.price
		offer.bought = true
		ShopItems.apply(player, offer)
		Sfx.play("coin")


func _say(i: int, text: String) -> void:
	_messages[i] = text
	_message_time[i] = 1.5
	Sfx.play("hurt")


func _finish() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	closed.emit()


func _draw_menu() -> void:
	var view := _canvas.get_viewport_rect().size
	var font := ThemeDB.fallback_font
	_canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.78))
	_canvas.draw_string(font, Vector2(0, 90), "SHOP  nach Welle %d" % wave, HORIZONTAL_ALIGNMENT_CENTER, view.x, 44, Color(1.0, 0.9, 0.4))
	_canvas.draw_string(font, Vector2(0, 124), "Links/Rechts waehlen, Bestaetigen kauft. Rechts aussen: Reroll und Fertig. Wenn beide fertig sind, geht es weiter.",
		HORIZONTAL_ALIGNMENT_CENTER, view.x, 16, Color(0.8, 0.8, 0.9))
	for i in 2:
		_draw_player_column(i, Vector2(40.0 + i * (view.x * 0.5), 170.0), view.x * 0.5 - 80.0, font)


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
	_draw_button(i, REROLL_SLOT, reroll_pos, Vector2(280.0, 50.0), "Reroll  (%d Gold)" % ShopItems.reroll_price(_rerolls[i]), font)
	_draw_button(i, READY_SLOT, ready_pos, Vector2(280.0, 50.0), "FERTIG" if not _ready_flags[i] else "BEREIT", font)
	if _message_time[i] > 0.0:
		_canvas.draw_string(font, Vector2(origin.x, button_y + 80.0), _messages[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.5, 0.4))


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
	var type_labels := {"perk": "BUFF", "module": "MODUL", "weapon": "WAFFE", "firmware": "FIRMWARE"}
	_canvas.draw_string(font, pos + Vector2(10, 22), type_labels[offer.type], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, offer.color)
	_canvas.draw_circle(pos + Vector2(CARD_WIDTH - 16, 16), 7.0, offer.color)
	_canvas.draw_string(font, pos + Vector2(0, 70), offer.name, HORIZONTAL_ALIGNMENT_CENTER, CARD_WIDTH, 20, Color.WHITE)
	_canvas.draw_string(font, pos + Vector2(10, 110), offer.text, HORIZONTAL_ALIGNMENT_LEFT, CARD_WIDTH - 20.0, 15, Color(0.85, 0.85, 0.9))
	var affordable: bool = players[i].gold >= offer.price
	_canvas.draw_string(font, pos + Vector2(0, CARD_HEIGHT - 16), "%d Gold" % offer.price, HORIZONTAL_ALIGNMENT_CENTER, CARD_WIDTH, 22,
		Color(1.0, 0.85, 0.3) if affordable else Color(0.6, 0.4, 0.4))


func _draw_button(i: int, slot: int, pos: Vector2, size: Vector2, text: String, font: Font) -> void:
	var selected: bool = _cursor[i] == slot
	var active: bool = slot == READY_SLOT and _ready_flags[i]
	var fill := Color(0.2, 0.5, 0.3) if active else (Color(0.2, 0.22, 0.32) if selected else Color(0.12, 0.13, 0.19))
	var border: Color = RobotClasses.PLAYER_COLORS[i] if selected else Color(1, 1, 1, 0.2)
	Art.panel(_canvas, Rect2(pos, size), fill, 12.0, border)
	_canvas.draw_string(font, pos + Vector2(0, 33), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color.WHITE)
