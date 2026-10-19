class_name EnemyHurtbox
extends Area2D
## Trefferzone eines Gegners. Leitet Schaden an den Gegner weiter, damit
## Geschosse und Strahlen (die Areas treffen) ihn erreichen.

var enemy: Node = null


func take_damage(amount: float, source: Node, direction := Vector2.ZERO, element := "") -> void:
	if is_instance_valid(enemy):
		enemy.take_damage(amount, source, direction, element)
