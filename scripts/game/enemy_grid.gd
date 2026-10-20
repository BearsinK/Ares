class_name EnemyGrid
extends RefCounted
## Raster fuer schnelle Nachbarsuche (Gegner-Abstand), statt jeden Gegner mit jedem zu vergleichen.

const CELL := 40.0

var _cells := {}


func rebuild(list: Array[Enemy]) -> void:
	_cells.clear()
	for enemy in list:
		if not is_instance_valid(enemy):
			continue
		var key := _key(enemy.global_position)
		if _cells.has(key):
			_cells[key].append(enemy)
		else:
			_cells[key] = [enemy]


## Gegner in der Zelle von pos und den acht Nachbarzellen.
func near(pos: Vector2) -> Array:
	var center := _key(pos)
	var result: Array = []
	for dx in 3:
		for dy in 3:
			var key := Vector2i(center.x + dx - 1, center.y + dy - 1)
			if _cells.has(key):
				result.append_array(_cells[key])
	return result


func _key(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / CELL)), int(floor(pos.y / CELL)))
