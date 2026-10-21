class_name EnemyHurtbox
extends Area2D
## Trefferzone eines Gegners. Leitet Schaden an den Gegner weiter, damit
## Geschosse und Strahlen (die Areas treffen) ihn erreichen.

var enemy: Node = null


func take_damage(amount: float, source: Node, direction := Vector2.ZERO, element := "") -> void:
	if not is_instance_valid(enemy):
		return
	# Direkttreffer (Geschosse, Strahlen) laufen hier durch: ein Frontschild faengt sie ab, Elemente wirken dann nicht.
	if enemy.is_blocking(direction):
		enemy.on_blocked(direction)
		enemy.take_damage(amount * Enemy.BLOCK_PASS, source, direction * 0.3, "")
		return
	enemy.take_damage(amount, source, direction, element)
