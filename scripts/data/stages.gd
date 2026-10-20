class_name Stages
extends RefCounted
## Handgebaute Karten im Stil von Risk of Rain: grosse, mehrstoeckige Hallen mit dicken
## Felsmassen, Rampen, Durchsprung-Plattformen und Seilen. Struktur fest, Variante zufaellig
## (Spiegelung). Koordinaten: Ursprung links oben, y waechst nach unten, Welt 6400 x 2200.
##
## Ein Layout ist ein Dictionary:
##   id, name, size
##   solids      Array[Rect2]   feste Bloecke (Ebene 1)
##   ramps       Array[PackedVector2Array]  konvexe Keile (Ebene 1), Oberkante zuerst
##   platforms   Array[Rect2]   von unten durchlaessige Stege (Ebene 6)
##   ropes       Array[Rect2]   Kletterseile (Breite 20)
##   starts      Array[Vector2] Standpunkte (Fussmitte) der beiden Spieler
##   ground      Array[Vector2] Stellen, an denen Bodengegner erscheinen duerfen (erreichbar zu Fuss)
##   air         Array[Rect2]   Bereiche fuer Flieger
##   steam       Array[Vector2] Dampfauslaesse

const SIZE := Vector2(6400.0, 2200.0)
const IDS: Array[String] = ["basin", "caverns", "zigzag"]
const NAMES := {"basin": "Rostbecken", "caverns": "Kavernen", "zigzag": "Zickzack", "classic": "Halle"}
## Charakter jeder Karte: Kurztext fuers Banner und Gewichte, mit denen der Director Gegnertypen bevorzugt.
const INFO := {
	"basin": {"text": "Weite Hallen, viele Bodengegner", "bias": {"walker": 1.4, "charger": 1.6, "brute": 1.2, "bomber": 1.2}},
	"caverns": {"text": "Enge Gänge, viele Flieger und Sprengis", "bias": {"flyer": 1.9, "bomber": 1.5, "shooter": 0.8}},
	"zigzag": {"text": "Lange Rampen, Schützen und Mörser", "bias": {"shooter": 1.7, "mortar": 1.7, "medic": 1.4, "walker": 0.8}},
}
const ROPE_WIDTH := 20.0
## Wie oft ein Stage-Wechsel stattfindet: alle drei Wellen eine neue Karte.
const WAVES_PER_STAGE := 3


## Liefert das Layout. mirrored spiegelt die Karte links/rechts.
static func build(id: String, mirrored := false) -> Dictionary:
	var layout := _empty(id)
	match id:
		"basin":
			_basin(layout)
		"caverns":
			_caverns(layout)
		"zigzag":
			_zigzag(layout)
		_:
			_basin(layout)
	_add_ground_points(layout)
	if mirrored:
		_mirror(layout)
	return layout


## Welche Karte in welcher Welle laeuft: pro Lauf eine feste Reihenfolge, alle drei Wellen wechselt sie.
static func id_for_wave(wave: int, order: Array) -> String:
	var index := ((maxi(wave, 1) - 1) / WAVES_PER_STAGE) % order.size()
	return String(order[index])


static func random_order() -> Array:
	var order: Array = IDS.duplicate()
	order.shuffle()
	return order


static func _empty(id: String) -> Dictionary:
	return {"id": id, "name": NAMES.get(id, id), "text": INFO.get(id, {}).get("text", ""), "bias": INFO.get(id, {}).get("bias", {}), "size": SIZE, "solids": [] as Array[Rect2], "ramps": [] as Array[PackedVector2Array],
		"platforms": [] as Array[Rect2], "ropes": [] as Array[Rect2], "starts": [] as Array[Vector2], "ground": [] as Array[Vector2],
		"air": [] as Array[Rect2], "steam": [] as Array[Vector2], "island": [] as Array[int], "surface_hint": []}


# ---------------------------------------------------------------- Bausteine

static func _solid(l: Dictionary, x: float, y: float, w: float, h: float) -> void:
	l.solids.append(Rect2(x, y, w, h))


## Keil mit Oberkante von (xa, ya) nach (xb, yb), unten aufgefuellt bis fill_to.
static func _ramp(l: Dictionary, xa: float, ya: float, xb: float, yb: float, fill_to: float) -> void:
	var points := PackedVector2Array([Vector2(xa, ya), Vector2(xb, yb), Vector2(xb, fill_to), Vector2(xa, fill_to)])
	var cleaned := PackedVector2Array()
	for point in points:
		if cleaned.is_empty() or cleaned[cleaned.size() - 1].distance_to(point) > 0.5:
			cleaned.append(point)
	if cleaned.size() > 1 and cleaned[0].distance_to(cleaned[cleaned.size() - 1]) <= 0.5:
		cleaned.remove_at(cleaned.size() - 1)
	l.ramps.append(cleaned)


static func _platform(l: Dictionary, x: float, y: float, w: float) -> void:
	l.platforms.append(Rect2(x, y, w, 24.0))


## Seil mit Oberkante y0 und Unterkante y1 an der Mittelachse x.
static func _rope(l: Dictionary, x: float, y0: float, y1: float) -> void:
	l.ropes.append(Rect2(x - ROPE_WIDTH * 0.5, y0, ROPE_WIDTH, y1 - y0))


static func _frame(l: Dictionary) -> void:
	var size: Vector2 = l.size
	# Aussenwaende und Decke (dick, damit nichts durchrutscht).
	_solid(l, -200.0, -400.0, 200.0, size.y + 800.0)
	_solid(l, size.x, -400.0, 200.0, size.y + 800.0)
	_solid(l, -200.0, -400.0, size.x + 400.0, 400.0)


# ---------------------------------------------------------------- Rostbecken

## Breites Tal (unten), zwei Hochebenen mit Felsvorspruengen, Stege ueber dem Tal, eine schwebende
## Insel mit Seilen und ein Steg darueber. Bodengegner laufen ueber die Rampen zwischen Tal und Ebenen.
static func _basin(l: Dictionary) -> void:
	_frame(l)
	_solid(l, 0.0, 1420.0, 800.0, 780.0)
	_ramp(l, 800.0, 1420.0, 1500.0, 1900.0, 2200.0)
	_solid(l, 1500.0, 1900.0, 3400.0, 300.0)
	_ramp(l, 4900.0, 1900.0, 5600.0, 1420.0, 2200.0)
	_solid(l, 5600.0, 1420.0, 800.0, 780.0)
	# Felsvorspruenge auf den Hochebenen, oben ein Steg, dazu ein langes Seil.
	_solid(l, 0.0, 1060.0, 420.0, 360.0)
	l.island.append(l.solids.size() - 1)
	_platform(l, 0.0, 820.0, 420.0)
	_rope(l, 470.0, 820.0, 1420.0)
	_solid(l, 5980.0, 1060.0, 420.0, 360.0)
	l.island.append(l.solids.size() - 1)
	_platform(l, 5980.0, 820.0, 420.0)
	_rope(l, 5930.0, 820.0, 1420.0)
	# Stege ueber dem Tal, jeweils etwa 140 Pixel hoeher.
	_platform(l, 1750.0, 1760.0, 300.0)
	_platform(l, 2350.0, 1620.0, 320.0)
	_platform(l, 3050.0, 1760.0, 300.0)
	_platform(l, 3650.0, 1620.0, 320.0)
	_platform(l, 4300.0, 1760.0, 320.0)
	# Schwebende Insel in der Mitte, Seile an beiden Seiten, darueber ein hoher Steg.
	_solid(l, 2700.0, 1260.0, 1000.0, 120.0)
	l.island.append(l.solids.size() - 1)
	_rope(l, 2640.0, 1260.0, 1900.0)
	_rope(l, 3760.0, 1260.0, 1900.0)
	_platform(l, 2950.0, 1010.0, 500.0)
	_rope(l, 2860.0, 1010.0, 1260.0)
	l.starts.append(Vector2(2300.0, 1900.0))
	l.starts.append(Vector2(2420.0, 1900.0))
	l.air.append(Rect2(300.0, 350.0, 5800.0, 950.0))
	l.steam.append(Vector2(1800.0, 1900.0))
	l.steam.append(Vector2(4400.0, 1900.0))
	l.steam.append(Vector2(500.0, 1420.0))


# ---------------------------------------------------------------- Kavernen

## Ein durchgehender Boden, in der Mitte eine grosse Felsmasse mit Tunnel darunter und einem Weg obendrauf.
## Links und rechts fuehren Rampen und Terrassen hinauf, ein Rundgang um den Fels.
static func _caverns(l: Dictionary) -> void:
	_frame(l)
	_solid(l, 0.0, 1900.0, 6400.0, 300.0)
	_solid(l, 2050.0, 900.0, 2300.0, 750.0)
	# Linke Seite.
	_ramp(l, 300.0, 1900.0, 900.0, 1500.0, 1900.0)
	_solid(l, 900.0, 1500.0, 400.0, 70.0)
	_ramp(l, 1300.0, 1500.0, 2050.0, 900.0, 1500.0)
	# Rechte Seite (gespiegelt).
	_ramp(l, 6100.0, 1900.0, 5500.0, 1500.0, 1900.0)
	_solid(l, 5100.0, 1500.0, 400.0, 70.0)
	_ramp(l, 5100.0, 1500.0, 4350.0, 900.0, 1500.0)
	# Stege in den Kammern und ueber den Terrassen.
	_platform(l, 100.0, 1700.0, 300.0)
	_platform(l, 1000.0, 1360.0, 300.0)
	_platform(l, 6000.0, 1700.0, 300.0)
	_platform(l, 5100.0, 1360.0, 300.0)
	# Hohe Randstege mit langen Seilen vom Boden.
	_platform(l, 0.0, 1100.0, 420.0)
	_rope(l, 180.0, 1100.0, 1900.0)
	_platform(l, 5980.0, 1100.0, 420.0)
	_rope(l, 6220.0, 1100.0, 1900.0)
	# Auf dem Fels: ein Steg darueber und ein noch hoeherer.
	_platform(l, 2800.0, 750.0, 800.0)
	_platform(l, 3100.0, 600.0, 200.0)
	_rope(l, 2700.0, 750.0, 900.0)
	l.starts.append(Vector2(1700.0, 1900.0))
	l.starts.append(Vector2(1850.0, 1900.0))
	l.air.append(Rect2(200.0, 350.0, 1700.0, 1200.0))
	l.air.append(Rect2(4500.0, 350.0, 1700.0, 1200.0))
	l.air.append(Rect2(2100.0, 250.0, 2200.0, 450.0))
	l.steam.append(Vector2(700.0, 1900.0))
	l.steam.append(Vector2(5700.0, 1900.0))
	l.steam.append(Vector2(3200.0, 1900.0))


# ---------------------------------------------------------------- Zickzack

## Drei Etagen im Z: unten ein langer Boden, darueber eine dicke Platte mit Durchgang, oben Stege.
## Die Rampe rechts verbindet unten und Mitte, links fuehrt ein langes Seil nach oben.
static func _zigzag(l: Dictionary) -> void:
	_frame(l)
	_solid(l, 0.0, 1900.0, 5300.0, 300.0)
	_ramp(l, 5300.0, 1900.0, 6000.0, 1450.0, 2200.0)
	_solid(l, 6000.0, 1450.0, 400.0, 750.0)
	# Mittlere Etage: dicke Platte mit einem Durchsprung-Spalt (Seil) bei 4100 bis 4500.
	_solid(l, 1000.0, 1450.0, 3100.0, 110.0)
	_platform(l, 4100.0, 1450.0, 400.0)
	_solid(l, 4500.0, 1450.0, 800.0, 110.0)
	# Ueber der Rampe liegt die Platte nur als Steg, sonst wuerde die Rampe in ihrer Unterseite enden.
	_platform(l, 5300.0, 1450.0, 700.0)
	_rope(l, 4300.0, 1450.0, 1900.0)
	# Obere Etage: Stege mit Luecken, Seile von unten und von der Mittelplatte.
	_platform(l, 300.0, 950.0, 1800.0)
	_platform(l, 2500.0, 950.0, 1400.0)
	_platform(l, 4300.0, 950.0, 1100.0)
	_rope(l, 580.0, 950.0, 1900.0)
	_rope(l, 2300.0, 950.0, 1450.0)
	_rope(l, 4100.0, 950.0, 1450.0)
	# Ein Zwischensteg im Eingangsbereich.
	_platform(l, 150.0, 1700.0, 300.0)
	l.starts.append(Vector2(500.0, 1900.0))
	l.starts.append(Vector2(650.0, 1900.0))
	l.air.append(Rect2(1200.0, 300.0, 4600.0, 600.0))
	l.air.append(Rect2(200.0, 350.0, 800.0, 1300.0))
	l.steam.append(Vector2(1500.0, 1900.0))
	l.steam.append(Vector2(3500.0, 1900.0))
	l.steam.append(Vector2(2600.0, 1450.0))


# ---------------------------------------------------------------- Oberflaechen

## Oberkanten aller begehbaren Flaechen als Strecken: {x0, y0, x1, y1, kind, island}.
static func surfaces(l: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in l.solids.size():
		var rect: Rect2 = l.solids[i]
		# Aussenwaende und Decke zaehlen nicht.
		if rect.position.x < 0.0 or rect.end.x > float(l.size.x) or rect.position.y < 0.0:
			continue
		result.append({"x0": rect.position.x, "y0": rect.position.y, "x1": rect.end.x, "y1": rect.position.y, "kind": "solid", "island": (l.island as Array).has(i)})
	for rect in l.platforms:
		result.append({"x0": rect.position.x, "y0": rect.position.y, "x1": rect.end.x, "y1": rect.position.y, "kind": "platform", "island": false})
	for points in l.ramps:
		var a: Vector2 = points[0]
		var b: Vector2 = points[1]
		result.append({"x0": minf(a.x, b.x), "y0": a.y if a.x < b.x else b.y, "x1": maxf(a.x, b.x), "y1": b.y if a.x < b.x else a.y, "kind": "ramp", "island": false})
	return result


## Bodengegner-Startpunkte: auf allen Flaechen, die kein Steg und keine Insel sind, alle 260 Pixel.
static func _add_ground_points(l: Dictionary) -> void:
	for surface in surfaces(l):
		if surface.kind == "platform" or surface.island:
			continue
		var x: float = surface.x0 + 90.0
		while x <= float(surface.x1) - 90.0:
			var t := 0.0 if absf(float(surface.x1) - float(surface.x0)) < 0.1 else (x - float(surface.x0)) / (float(surface.x1) - float(surface.x0))
			var y: float = lerpf(float(surface.y0), float(surface.y1), t)
			# Nicht dort, wo ein anderer Block darauf oder darueber sitzt.
			var covered := false
			for rect: Rect2 in l.solids:
				if rect.grow(-2.0).has_point(Vector2(x, y - 24.0)):
					covered = true
			for points: PackedVector2Array in l.ramps:
				if Geometry2D.is_point_in_polygon(Vector2(x, y - 24.0), points):
					covered = true
			if not covered:
				l.ground.append(Vector2(x, y))
			x += 260.0


## Liegt der Punkt in einem Block oder Keil (ohne Aussenrahmen)?
static func point_in_terrain(l: Dictionary, point: Vector2) -> bool:
	for rect: Rect2 in l.solids:
		if rect.position.x >= 0.0 and rect.end.x <= float(l.size.x) and rect.position.y >= 0.0 and rect.grow(4.0).has_point(point):
			return true
	for points: PackedVector2Array in l.ramps:
		if Geometry2D.is_point_in_polygon(point, points):
			return true
	return false


static func _mirror(l: Dictionary) -> void:
	var width: float = l.size.x
	var solids: Array[Rect2] = []
	for rect in l.solids:
		solids.append(Rect2(width - rect.end.x, rect.position.y, rect.size.x, rect.size.y))
	l.solids = solids
	var ramps: Array[PackedVector2Array] = []
	for points in l.ramps:
		var mirrored := PackedVector2Array()
		for point in points:
			mirrored.append(Vector2(width - point.x, point.y))
		ramps.append(mirrored)
	l.ramps = ramps
	for key in ["platforms", "ropes"]:
		var list: Array[Rect2] = []
		for rect in l[key]:
			list.append(Rect2(width - rect.end.x, rect.position.y, rect.size.x, rect.size.y))
		l[key] = list
	var air: Array[Rect2] = []
	for rect in l.air:
		air.append(Rect2(width - rect.end.x, rect.position.y, rect.size.x, rect.size.y))
	l.air = air
	for key in ["starts", "ground", "steam"]:
		var points_list: Array[Vector2] = []
		for point in l[key]:
			points_list.append(Vector2(width - point.x, point.y))
		l[key] = points_list
