class_name ShopItems
extends RefCounted
## Angebote im Shop zwischen den Wellen. Jeder Spieler bekommt eigene Angebote
## und kauft mit seinem eigenen Gold.
##
## Typen:
##   perk    persoenlicher Buff (Werte der Klassenvariante aus Perks)
##   module  Elementmodul fuer die aktive Waffe (ersetzt ein vorhandenes Modul)
##   weapon  neue Waffe (freier Slot, sonst ersetzt sie die aktive Waffe)

const OFFER_COUNT := 4
const MAX_WEAPONS := 3

const BASE_PRICE := {"perk": 12, "module": 25, "weapon": 30, "firmware": 35}


static func make_offers(player: Player, wave: int) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	var tries := 0
	while offers.size() < OFFER_COUNT and tries < 50:
		tries += 1
		var offer := _random_offer(player, wave)
		if offer.is_empty() or _is_duplicate(offers, offer):
			continue
		offers.append(offer)
	return offers


static func price_for(type: String, wave: int) -> int:
	return int(round(float(BASE_PRICE[type]) * (1.0 + 0.25 * float(wave - 1))))


static func reroll_price(rerolls: int) -> int:
	return 5 + 3 * rerolls


static func _is_duplicate(offers: Array[Dictionary], offer: Dictionary) -> bool:
	for existing in offers:
		if existing.type == offer.type and existing.id == offer.id:
			return true
	return false


static func _random_offer(player: Player, wave: int) -> Dictionary:
	var roll := randf()
	var type := "perk"
	# In den ersten Wellen erscheint Bewegungs-Firmware haeufiger.
	var firmware_chance := 0.3 if wave <= 3 else 0.12
	if roll < firmware_chance:
		type = "firmware"
	elif roll > 0.8:
		type = "weapon"
	elif roll > 0.5:
		type = "module"

	match type:
		"firmware":
			var available: Array[String] = []
			for firmware_id in Firmware.DATA:
				if player.fw(firmware_id) < int(Firmware.DATA[firmware_id].max):
					available.append(firmware_id)
			if available.is_empty():
				return {}
			var chosen: String = available[randi() % available.size()]
			return {"type": "firmware", "id": chosen, "name": Firmware.DATA[chosen].name,
				"text": Firmware.DATA[chosen].text, "price": price_for("firmware", wave), "bought": false,
				"color": Color(0.5, 0.95, 0.65)}
		"module":
			var element: String = Elements.IDS[randi() % Elements.IDS.size()]
			return {"type": "module", "id": element, "name": "%s-Modul" % Elements.NAMES[element],
				"text": "in die aktive Waffe", "price": price_for("module", wave), "bought": false,
				"color": Elements.COLORS[element]}
		"weapon":
			var candidates: Array[String] = []
			for weapon_id in Weapons.ALL_IDS:
				if not player.weapons.has(weapon_id):
					candidates.append(weapon_id)
			if candidates.is_empty():
				return {}
			var weapon_id: String = candidates[randi() % candidates.size()]
			var slot_text := "neuer Slot" if player.weapons.size() < MAX_WEAPONS else "ersetzt aktive Waffe"
			return {"type": "weapon", "id": weapon_id, "name": Weapons.get_weapon(weapon_id).name,
				"text": "%s\n%s" % [Weapons.summary(weapon_id), slot_text], "price": price_for("weapon", wave), "bought": false,
				"color": Weapons.get_weapon(weapon_id).color}
		_:
			var perk_id: String = Perks.DATA.keys()[randi() % Perks.DATA.size()]
			return {"type": "perk", "id": perk_id, "name": Perks.DATA[perk_id].name,
				"text": Perks.describe(perk_id, player.class_id), "price": price_for("perk", wave),
				"bought": false, "color": Color(0.8, 0.8, 0.9)}


## Fuehrt den Kauf aus (Gold wurde schon abgezogen).
static func apply(player: Player, offer: Dictionary) -> void:
	match offer.type:
		"perk":
			player.add_mods(Perks.mods_for(offer.id, player.class_id))
		"module":
			player.set_module(offer.id)
		"weapon":
			player.add_weapon(offer.id)
		"firmware":
			player.add_firmware(offer.id)
