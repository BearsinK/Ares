class_name GroundProbe
extends RefCounted
## Boden unter Beute, Schrott und Truemmern: Strahl gegen feste Bloecke und Stege. Gibt die
## Trefferhoehe zurueck oder INF, wenn nichts getroffen wird (dann gilt der Notboden).

const MASK := (1 << 0) | (1 << 5)


static func ground_y(node: Node2D, from: Vector2, to: Vector2) -> float:
	var query := PhysicsRayQueryParameters2D.create(from, to, MASK)
	var result := node.get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return INF
	return result.position.y
