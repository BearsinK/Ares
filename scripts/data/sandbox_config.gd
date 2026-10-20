class_name SandboxConfig
extends RefCounted
## Sandbox-Modus: Beide Spieler stellen vor dem Lauf Waffen, Module, Firmware und Team-Perks
## ein und waehlen Startwelle, Startgold und Unverwundbarkeit. Die Einstellung liegt als
## Dictionary in Engine-Meta "sandbox", die Hauptszene wendet sie an. Es gibt keine Chips.
##
## Aufbau: {"wave": int, "gold": int, "god": bool,
##          "players": [{"weapons": [id, ...], "modules": [element oder "", ...],
##                       "firmware": {id: Anzahl}, "perks": {id: Anzahl}}, ...]}

const MAX_WEAPONS := 3
const MAX_PERK_STACK := 5
const GOLD_STEPS := [0, 100, 250, 500, 1000, 5000]
## Startwelle 11 steht fuer den Endboss.
const BOSS_WAVE := 11


static func default_config(class_ids: Array) -> Dictionary:
	var players: Array = []
	for class_id in class_ids:
		var stats: Dictionary = RobotClasses.get_stats(class_id)
		players.append({"weapons": [stats.weapons[0]], "modules": [""], "firmware": {}, "perks": {}})
	return {"wave": 1, "gold": 500, "god": false, "players": players}


## Waffen, die diese Klasse waehlen darf (Klassenwaffe zuerst, dann der Rest).
static func weapon_choices(class_id: String) -> Array[String]:
	var list: Array[String] = []
	var own: String = RobotClasses.get_stats(class_id).weapons[0]
	list.append(own)
	for id in Weapons.ALL_IDS:
		if id != own and Weapons.usable_by(id, class_id):
			list.append(id)
	return list


## Zeilen der Einstellungsliste fuer einen Spieler: gemeinsame Werte, Waffen, Firmware, Perks, Bereit.
static func rows(config: Dictionary, index: int, class_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append({"kind": "wave", "label": "Startwelle", "value": "Endboss" if int(config.wave) >= BOSS_WAVE else str(int(config.wave))})
	result.append({"kind": "gold", "label": "Startgold", "value": str(int(config.gold))})
	result.append({"kind": "god", "label": "Unverwundbar", "value": "An" if bool(config.god) else "Aus"})
	var data: Dictionary = config.players[index]
	for slot in MAX_WEAPONS:
		var weapons: Array = data.weapons
		var has: bool = slot < weapons.size()
		result.append({"kind": "weapon", "slot": slot, "label": "Waffe %d" % (slot + 1), "value": Weapons.get_weapon(weapons[slot]).name if has else "-"})
		var module: String = data.modules[slot] if has else ""
		result.append({"kind": "module", "slot": slot, "label": "  Modul %d" % (slot + 1), "value": Elements.NAMES[module] if module != "" else "-", "disabled": not has})
	for id in Firmware.DATA:
		result.append({"kind": "firmware", "id": id, "label": Firmware.DATA[id].name, "value": "%d / %d" % [int(data.firmware.get(id, 0)), int(Firmware.DATA[id].max)]})
	for id in Perks.DATA:
		result.append({"kind": "perk", "id": id, "label": Perks.DATA[id].name, "value": "x%d" % int(data.perks.get(id, 0)),
			"text": Perks.describe(id, class_id)})
	result.append({"kind": "ready", "label": "BEREIT", "value": ""})
	return result


## Aendert den Wert einer Zeile um delta (-1 oder +1).
static func change(config: Dictionary, index: int, class_id: String, row: Dictionary, delta: int) -> void:
	var data: Dictionary = config.players[index]
	match row.kind:
		"wave":
			config.wave = clampi(int(config.wave) + delta, 1, BOSS_WAVE)
		"gold":
			var at := GOLD_STEPS.find(int(config.gold))
			config.gold = GOLD_STEPS[clampi(maxi(at, 0) + delta, 0, GOLD_STEPS.size() - 1)]
		"god":
			config.god = not bool(config.god)
		"weapon":
			_change_weapon(data, class_id, int(row.slot), delta)
		"module":
			var slot: int = row.slot
			if slot >= data.weapons.size():
				return
			var options: Array = [""]
			options.append_array(Elements.IDS)
			var at: int = options.find(data.modules[slot])
			data.modules[slot] = options[posmod(at + delta, options.size())]
		"firmware":
			var maximum: int = Firmware.DATA[row.id].max
			data.firmware[row.id] = clampi(int(data.firmware.get(row.id, 0)) + delta, 0, maximum)
		"perk":
			data.perks[row.id] = clampi(int(data.perks.get(row.id, 0)) + delta, 0, MAX_PERK_STACK)


static func _change_weapon(data: Dictionary, class_id: String, slot: int, delta: int) -> void:
	var choices := weapon_choices(class_id)
	var weapons: Array = data.weapons
	# Reihenfolge der Auswahl: "-" (leer, nur Slot 2 und 3), dann alle Waffen.
	var options: Array = ["-"] if slot > 0 else []
	options.append_array(choices)
	var current: String = weapons[slot] if slot < weapons.size() else "-"
	var next: String = options[posmod(options.find(current) + delta, options.size())]
	if next == "-":
		# Leerer Slot: dieser und alle folgenden fallen weg.
		while weapons.size() > slot:
			weapons.pop_back()
			data.modules.pop_back()
		return
	# Slots davor muessen belegt sein.
	while weapons.size() < slot:
		weapons.append(choices[0])
		data.modules.append("")
	if slot < weapons.size():
		weapons[slot] = next
	else:
		weapons.append(next)
		data.modules.append("")
