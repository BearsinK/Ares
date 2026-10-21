class_name SaveData
extends RefCounted
## Spielstand auf der Platte (user://ares_save.json): Chips, Werkstatt-Stufen,
## Freischaltungen, Bestwerte und Einstellungen. Im Headless-Modus (Tests) wird
## nichts gelesen oder geschrieben, dann gilt ein frischer Spielstand im Speicher.

const PATH := "user://ares_save.json"
## Lautstaerke in Stufen 0..10. Bei den Standardstufen (8 mal 8) klingt alles wie vorher.
const VOLUME_STEPS := 10
const VOLUME_DEFAULT := 8
## Bildschirmwackeln: Aus, Wenig, Normal, Stark (Faktor auf jeden Kameraruck).
const SHAKE_SCALES: Array[float] = [0.0, 0.5, 1.0, 1.5]
const SHAKE_DEFAULT := 2

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
		# Alter Spielstand: Musik aus wird zur Musiklautstaerke 0.
		if not parsed.has("volume") and parsed.get("music", true) == false:
			_data.volume = {"music": 0}


static func _defaults() -> Dictionary:
	return {
		"chips": 0, "levels": {}, "classes": [], "weapons": [],
		"stats": {"runs": 0, "best_wave": 0, "kills": 0, "boss_kills": 0, "best_time": 0},
		"fullscreen": false, "difficulty": 1,
		"volume": {}, "shake": SHAKE_DEFAULT, "numbers": true, "rumble": true, "tips_on": true, "tips": [],
		"archive": {"items": [], "weapons": [], "enemies": {}, "achievements": []},
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


## Stufe 0..10 fuer "master", "music" oder "sfx".
static func volume_step(bus: String) -> int:
	_ensure()
	var volumes: Dictionary = _data.get("volume", {})
	return clampi(int(volumes.get(bus, VOLUME_DEFAULT)), 0, VOLUME_STEPS)


## write = false: nur im Speicher aendern, der Aufrufer ruft spaeter save() (beim Halten einer Taste).
static func set_volume_step(bus: String, step: int, write := true) -> void:
	_ensure()
	var volumes: Dictionary = _data.get("volume", {})
	volumes[bus] = clampi(step, 0, VOLUME_STEPS)
	_data.volume = volumes
	if write:
		save()


## Verstaerkung in dB fuer einen Bus mit Gesamtlautstaerke: 0 dB bei den Standardstufen, -80 bei Stumm.
static func gain_db(bus: String) -> float:
	var product := volume_step("master") * volume_step(bus)
	if product <= 0:
		return -80.0
	return linear_to_db(float(product) / float(VOLUME_DEFAULT * VOLUME_DEFAULT))


static func shake_level() -> int:
	_ensure()
	return clampi(int(_data.get("shake", SHAKE_DEFAULT)), 0, SHAKE_SCALES.size() - 1)


static func set_shake_level(level: int) -> void:
	_ensure()
	_data.shake = clampi(level, 0, SHAKE_SCALES.size() - 1)
	save()


static func shake_scale() -> float:
	return SHAKE_SCALES[shake_level()]


static func numbers_enabled() -> bool:
	_ensure()
	return bool(_data.get("numbers", true))


static func set_numbers(enabled: bool) -> void:
	_ensure()
	_data.numbers = enabled
	save()


## Einmalige Hinweise: an oder aus, und welche schon gezeigt wurden.
static func tips_enabled() -> bool:
	_ensure()
	return bool(_data.get("tips_on", true))


static func set_tips(enabled: bool) -> void:
	_ensure()
	_data.tips_on = enabled
	save()


static func tip_seen(id: String) -> bool:
	_ensure()
	return (_data.get("tips", []) as Array).has(id)


static func mark_tip(id: String) -> void:
	_ensure()
	var seen: Array = _data.get("tips", [])
	if not seen.has(id):
		seen.append(id)
		_data.tips = seen
		save()


## Archiv: entdeckte Items und Waffen (Listen) und gesehene Gegner mit Anzahl der Besiegten (Dictionary).
## kind: "items", "weapons" oder "enemies".
static func archive_has(kind: String, id: String) -> bool:
	_ensure()
	var archive: Dictionary = _data.get("archive", {})
	var entry: Variant = archive.get(kind, [])
	return entry.has(id)


## Traegt einen Eintrag ein. Gibt true zurueck, wenn er neu ist.
static func archive_discover(kind: String, id: String) -> bool:
	if archive_has(kind, id):
		return false
	var archive: Dictionary = _data.get("archive", {})
	if kind == "enemies":
		var seen: Dictionary = archive.get("enemies", {})
		seen[id] = 0
		archive.enemies = seen
	else:
		var list: Array = archive.get(kind, [])
		list.append(id)
		archive[kind] = list
	_data.archive = archive
	save()
	return true


## Zaehlt einen besiegten Gegner (nur im Speicher, gespeichert wird mit dem Lauf-Ende).
static func archive_add_kill(id: String) -> void:
	_ensure()
	var archive: Dictionary = _data.get("archive", {})
	var seen: Dictionary = archive.get("enemies", {})
	seen[id] = int(seen.get(id, 0)) + 1
	archive.enemies = seen
	_data.archive = archive


static func archive_kills(id: String) -> int:
	_ensure()
	var archive: Dictionary = _data.get("archive", {})
	return int((archive.get("enemies", {}) as Dictionary).get(id, 0))


static func archive_count(kind: String) -> int:
	_ensure()
	var archive: Dictionary = _data.get("archive", {})
	return (archive.get(kind, []) as Variant).size()


static func rumble_enabled() -> bool:
	_ensure()
	return bool(_data.get("rumble", true))


static func set_rumble(enabled: bool) -> void:
	_ensure()
	_data.rumble = enabled
	save()


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
