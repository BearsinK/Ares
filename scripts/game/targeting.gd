class_name Targeting
extends RefCounted
## Hilfen fuer Waffen, die ein Ziel suchen (Sicht, Reichweite, Kegel). Ein Gegner ist ein Punkt (seine Mitte),
## der Boss ein grosser Rumpf, dessen Ursprung am Boden liegt: Dort muss der naechste Punkt des Rumpfes gelten.


## Naechster Punkt des Ziels zu from (Boss: auf dem Rumpf, sonst die Mitte).
static func point_of(target: Node2D, from: Vector2) -> Vector2:
	return target.closest_point(from) if target.has_method("closest_point") else target.global_position


## Zusatzradius des Ziels: Gegner haben einen Kreis um die Mitte, beim Boss steckt die Groesse schon im Rumpfpunkt (nur ein kleiner Spielraum).
static func slack_of(target: Node2D) -> float:
	if target is Boss:
		return 30.0
	return float(target.radius()) if target.has_method("radius") else 40.0
