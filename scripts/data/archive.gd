class_name Archive
extends RefCounted
## Archiv (wie das Logbuch in Risk of Rain): Items, Gegner und Waffen, die man in einem Lauf
## entdeckt hat, lassen sich im Titelmenue nachlesen. Hier stehen die Eintraege; was entdeckt ist,
## merkt SaveData.

const KINDS: Array[String] = ["items", "enemies", "weapons", "achievements"]
const KIND_NAMES := {"items": "Items", "enemies": "Gegner", "weapons": "Waffen", "achievements": "Erfolge"}
const HINTS := {
	"items": "Finde dieses Item in einem Lauf: aus Kisten, Altären oder dem Level-Up.",
	"enemies": "Begegne diesem Gegner in einem Lauf.",
	"weapons": "Rüste diese Waffe in einem Lauf aus (Shop).",
}

const ENEMY_ORDER: Array[String] = ["walker", "shooter", "flyer", "charger", "mortar", "brute", "bomber", "medic", "aegis", "nest", "elite", "guardian", "boss"]
const ENEMY_TEXT := {
	"walker": "Läuft auf euch zu und schlägt zu. Dutzendware, in Gruppen aber gefährlich.",
	"shooter": "Hält Abstand und feuert langsame Stachelkugeln. Auf die Warnung achten, dann ausweichen.",
	"flyer": "Schwebt über euch und beschießt euch von oben. Zerbrechlich, aber schwer zu treffen.",
	"charger": "Zielt kurz und rammt dann los. Beim Aufleuchten wegdashen oder zur Seite springen.",
	"mortar": "Beschießt aus großer Entfernung mit Granaten. Der Kreis am Boden zeigt, wo es einschlägt.",
	"brute": "Langsam und enorm zäh, schlägt in einem großen Kreis. Auf Abstand bleiben und Feuer halten.",
	"bomber": "Rennt los und sprengt sich selbst. Vorher abschießen, dann gibt es keinen Schaden. Sprengt er sich, lässt er keine Beute fallen.",
	"medic": "Hält Abstand und heilt verwundete Gegner in der Nähe. Zuerst ausschalten.",
	"aegis": "Trägt einen Frontschild, der Schüsse von vorn fast ganz abfängt. Von hinten, von oben, mit Sprengungen und Fähigkeiten oder zu zweit von beiden Seiten verwundbar.",
	"nest": "Hält Abstand und setzt alle paar Sekunden Buzzer in die Welt. Wer das Nest zerstört, schickt auch seine Buzzer in den Schrott. Die Buzzer geben keine Beute.",
	"elite": "Größer und zäher, mit eigener Fähigkeit: Inferno legt Feuerherde, Bulwark trägt einen Schild, Stormer feuert Blitzfächer, Frostbite bremst in der Nähe. Dafür dreifache Beute.",
	"guardian": "Mini-Boss am Ende jeder Karte als Brute, Ramtank oder Mörser in Riesenform. Wer ihn besiegt, bekommt eine Goldkiste und eine Reparatur.",
	"boss": "Der Smelter, Herr der Gießerei. Der Endboss: Wer ihn besiegt, stoppt die Fabrik.",
}
const ENEMY_NAMES := {"elite": "Elite", "guardian": "Wächter", "boss": "Smelter"}
const ENEMY_ART := {"elite": "walker", "guardian": "brute", "boss": "brute"}

const WEAPON_TEXT := {
	"dust": "Zuverlässige Standardwaffe. Mittlere Feuerrate, trifft genau.",
	"rapid": "Sehr hohe Feuerrate, dafür wenig Schaden pro Schuss. Streut beim Dauerfeuer stärker.",
	"shotgun": "Neun Schrotkugeln auf kurze Distanz. Stößt Gegner weit zurück, den Schützen auch.",
	"rocket": "Lenkrakete: startet langsam, beschleunigt und verfolgt den nächsten Gegner. Explodiert im Umkreis.",
	"beam": "Dauerstrahl, der stärker wird, je länger er auf dem Ziel liegt. Trifft mehrere Gegner in einer Linie und bremst beim Halten.",
	"sniper": "Langsames Gewehr mit sehr hohem Schaden. Trifft sofort und durchschlägt mehrere Gegner.",
	"can": "Wirft Dosen. Feuer halten schüttelt sie auf, beim Aufprall explodieren sie, und je länger geschüttelt, desto größer.",
	"turret": "Präzise Kanone des Hexapods: schnelle Schüsse, die Gegner in einer Linie durchschlagen.",
	"dronegun": "Die Begleitdrohnen des Printbots feuern leichte Impulsschüsse. Allein schwach, mit Upgrades und Markierungen stark.",
	"sweeper": "Roomba schwingt seinen Besen: trifft alle Gegner vor ihm, schleudert sie weg und fegt gegnerische Schüsse aus der Luft.",
	"disc": "Wurfscheibe, die sich durch Gegner schneidet, umkehrt und auf dem Rückweg erneut trifft.",
	"vacuum": "Saugkegel, der Gegner vor dem Roomba zu einem Punkt zusammenzieht. Wenig Schaden, aber ideal für Explosionen des Partners.",
	"zapper": "Kettenblitz: trifft den Gegner am Fadenkreuz und springt auf bis zu drei weitere. Nasse Gegner erleiden den vollen Volt-Effekt.",
}


static var _cache := {}


## Alle Eintraege einer Art als Dictionary: id, name, color, text, tag (Kurzlabel), stats (Zeilen), art (Gegnerbild).
## Die Liste wird nur einmal gebaut und darf nicht veraendert werden.
static func entries(kind: String) -> Array[Dictionary]:
	if not _cache.has(kind):
		_cache[kind] = _build(kind)
	return _cache[kind]


static func _build(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match kind:
		"items":
			for id in Perks.DATA:
				var rare := Perks.RARE_IDS.has(id)
				result.append({
					"id": id, "name": String(Perks.DATA[id].name), "color": PerkArt.color_of(id),
					"text": Perks.describe(id, "default"), "tag": "SELTEN" if rare else "ITEM", "rare": rare, "stats": [],
				})
		"enemies":
			for id in ENEMY_ORDER:
				result.append(_enemy_entry(id))
		"achievements":
			for id in Achievements.DATA:
				var info: Dictionary = Achievements.DATA[id]
				result.append({
					"id": id, "name": String(info.name), "color": Color(1.0, 0.82, 0.3), "text": String(info.text),
					"tag": "ERFOLG", "stats": ["Belohnung: %d Chips" % int(info.chips)],
				})
		"weapons":
			for id in Weapons.ALL_IDS:
				var weapon: Dictionary = Weapons.DATA[id]
				var stats: Array = [Weapons.summary(id), "Feuerrate %s pro Sekunde" % ("%.1f" % float(weapon.fire_rate)).trim_suffix(".0")]
				var tag := "WAFFE"
				if Weapons.owner_of(id) != "":
					tag = "NUR %s" % String(RobotClasses.get_stats(Weapons.owner_of(id)).name).to_upper()
				result.append({"id": id, "name": String(weapon.name), "color": weapon.color, "text": WEAPON_TEXT[id], "tag": tag, "stats": stats})
	return result


static func _enemy_entry(id: String) -> Dictionary:
	var entry := {"id": id, "text": ENEMY_TEXT[id], "tag": "GEGNER", "stats": [], "art": String(ENEMY_ART.get(id, id))}
	if EnemyTypes.DATA.has(id):
		var info: Dictionary = EnemyTypes.DATA[id]
		entry.name = String(info.name)
		entry.color = info.color
		entry.stats = ["Leben %d" % int(info.hp), "Tempo %d" % int(info.speed), "Schaden %d" % int(info.damage) if float(info.damage) > 0.0 else "Heilt Verbündete"]
	else:
		entry.name = String(ENEMY_NAMES[id])
		entry.color = Color(1.0, 0.45, 0.3) if id != "elite" else Color(0.95, 0.85, 0.3)
		entry.tag = "ELITE" if id == "elite" else ("MINI-BOSS" if id == "guardian" else "ENDBOSS")
	return entry


## Archiv ohne Erfolge: entdeckte und alle Items, Gegner und Waffen zusammen.
static func collection_progress() -> Vector2i:
	var found := 0
	var total := 0
	for kind in ["items", "enemies", "weapons"]:
		var p := progress(kind)
		found += p.x
		total += p.y
	return Vector2i(found, total)


## Anzahl entdeckter und aller Eintraege einer Art.
static func progress(kind: String) -> Vector2i:
	var found := 0
	var all := entries(kind)
	for entry in all:
		if is_found(kind, String(entry.id)):
			found += 1
	return Vector2i(found, all.size())


static func is_found(kind: String, id: String) -> bool:
	return SaveData.archive_has(kind, id)


## Namen eines Eintrags (fuer Hinweise im Spiel).
static func entry_name(kind: String, id: String) -> String:
	for entry in entries(kind):
		if entry.id == id:
			return String(entry.name)
	return id
