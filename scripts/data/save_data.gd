class_name SaveData
extends RefCounted
## Spielstand auf der Platte (user://ares_save.json): Chips, Werkstatt-Stufen,
## Freischaltungen, Bestwerte und Einstellungen. Im Headless-Modus (Tests) wird
## nichts gelesen oder geschrieben, dann gilt ein frischer Spielstand im Speicher.

const PATH := "user://ares_save.json"

static var persist := DisplayServer.get_name() != "headless"
## Testphase: Alle Klassen und Waffen sind freigeschaltet (Tests im Headless-Modus pruefen die Sperren weiter).
static var unlock_all := DisplayServer.get_name() != "headless"
static var _data: Dictionary = {}
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_data = _defaults()
	if not persist or not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for key in parsed:
			_data[key] = parsed[key]


static func _defaults() -> Dictionary:
	return {
		"chips": 0, "levels": {}, "classes": [], "weapons": [],
		"stats": {"runs": 0, "best_wave": 0, "kills": 0, "boss_kills": 0, "best_time": 0},
		"music": true, "fullscreen": false, "difficulty": 1,
	}


## Setzt den Speicher auf einen frischen Stand zurueck (fuer Tests).
static func reset() -> void:
	_loaded = true
	_data = _defaults()


static func save() -> void:
	if not persist:
		return
	_ensure()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_data))


static func chips() -> int:
	_ensure()
	return int(_data.chips)


static func add_chips(amount: int) -> void:
	_ensure()
	_data.chips = chips() + amount
	save()


static func level(upgrade_id: String) -> int:
	_ensure()
	return int(_data.levels.get(upgrade_id, 0))


## Kauft die naechste Stufe. Gibt false zurueck bei zu wenig Chips oder Maximalstufe.
static func buy_upgrade(upgrade_id: String) -> bool:
	var current := level(upgrade_id)
	if current >= int(Meta.UPGRADES[upgrade_id].max):
		return false
	var cost := Meta.cost_of(upgrade_id, current)
	if chips() < cost:
		return false
	_data.chips = chips() - cost
	_data.levels[upgrade_id] = current + 1
	save()
	return true


static func class_unlocked(class_id: String) -> bool:
	_ensure()
	return unlock_all or not Meta.CLASS_UNLOCKS.has(class_id) or (_data.classes as Array).has(class_id)


static func weapon_unlocked(weapon_id: String) -> bool:
	_ensure()
	return unlock_all or not Meta.WEAPON_UNLOCKS.has(weapon_id) or (_data.weapons as Array).has(weapon_id)


## kind: "class" oder "weapon".
static func buy_unlock(kind: String, id: String) -> bool:
	_ensure()
	var table: Dictionary = Meta.CLASS_UNLOCKS if kind == "class" else Meta.WEAPON_UNLOCKS
	var list: Array = _data.classes if kind == "class" else _data.weapons
	if not table.has(id) or list.has(id) or chips() < int(table[id]):
		return false
	_data.chips = chips() - int(table[id])
	list.append(id)
	save()
	return true


static func stats() -> Dictionary:
	_ensure()
	return _data.stats


static func music_enabled() -> bool:
	_ensure()
	return bool(_data.music)


## 0 = Rookie, 1 = Normal, 2 = Hardcore (siehe Meta.DIFFICULTIES).
static func difficulty() -> int:
	_ensure()
	return clampi(int(_data.get("difficulty", 1)), 0, 2)


static func set_difficulty(value: int) -> void:
	_ensure()
	_data.difficulty = clampi(value, 0, 2)
	save()


static func fullscreen_enabled() -> bool:
	_ensure()
	return bool(_data.get("fullscreen", false))


static func set_fullscreen(enabled: bool) -> void:
	_ensure()
	_data.fullscreen = enabled
	save()


static func set_music(enabled: bool) -> void:
	_ensure()
	_data.music = enabled
	save()


## Verbucht einen Lauf und gibt die erhaltenen Chips zurueck.
static func record_run(waves_cleared: int, kills: int, level_reached: int, seconds: int, boss_defeated: bool) -> int:
	_ensure()
	var earned := Meta.chips_for_run(waves_cleared, kills, level_reached, boss_defeated)
	var s: Dictionary = _data.stats
	s.runs = int(s.runs) + 1
	s.kills = int(s.kills) + kills
	s.best_wave = maxi(int(s.best_wave), waves_cleared)
	if boss_defeated:
		s.boss_kills = int(s.boss_kills) + 1
		var best := int(s.best_time)
		s.best_time = seconds if best == 0 else mini(best, seconds)
	add_chips(earned)
	return earned
