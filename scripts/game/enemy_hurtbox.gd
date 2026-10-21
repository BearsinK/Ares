class_name EnemyHurtbox
extends Area2D
## Trefferzone eines Gegners. Leitet Schaden an den Gegner weiter, damit
## Geschosse und Strahlen (die Areas treffen) ihn erreichen.

var enemy: Node = null


## Zustand aus einer Waffe an den Gegner weitergeben.
func apply_status(status_name: String, duration: float, source: Node = null) -> void:
	if is_instance_valid(enemy):
		enemy.apply_status(status_name, duration, source)


func take_damage(amount: float, source: Node, direction := Vector2.ZERO, element := "") -> void:
	if not is_instance_valid(enemy):
		return
	# Direkttreffer (Geschosse, Strahlen) laufen hier durch: ein Frontschild faengt sie ab, Elemente wirken dann nicht.
	if enemy.is_blocking(direction):
		enemy.on_blocked()
		enemy.take_damage(amount * Enemy.BLOCK_PASS, source, direction * 0.3, "")
		return
	enemy.take_damage(amount, source, direction, element)
