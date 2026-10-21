class_name Deployable
extends Node2D
## Etwas, das ein Spieler wirft und das dann liegen bleibt (Mine, Geschuetzturm): faellt mit Schwerkraft,
## prallt an Waenden ab, bleibt auf dem Boden oder einer Plattform liegen und verfaellt nach einer Weile.
## Unterklassen ueberschreiben _tick_planted und _draw.

const GRAVITY := 1500.0

var owner_player: Node = null
var kind := "mine"
var velocity := Vector2.ZERO
var life := 25.0
var color := Color(1.0, 0.55, 0.25)
var element := ""
var knock := 1.0
var age := 0.0

var planted := false
var _flight := 0.0
var _normal := Vector2.UP


func _ready() -> void:
	add_to_group("deployables")


func _physics_process(delta: float) -> void:
	age += delta
	if not planted:
		_fly(delta)
		queue_redraw()
		return
	life -= delta
	if life <= 0.0:
		if Fx.instance:
			Fx.instance.spark(global_position, color, 5, 160.0)
		queue_free()
		return
	_tick_planted(delta)
	queue_redraw()


func _tick_planted(_delta: float) -> void:
	pass


func _fly(delta: float) -> void:
	_flight += delta
	velocity.y += GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	# Boden, Waende und Plattformen (Plattformen nur von oben).
	var query := PhysicsRayQueryParameters2D.create(from, to, (1 << 0) | (1 << 5))
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		if _flight > 2.5:
			_plant(Vector2.UP)
		return
	var normal: Vector2 = hit.normal
	var platform: bool = hit.collider is CollisionObject2D and ((hit.collider as CollisionObject2D).collision_layer & (1 << 5)) != 0
	if platform and velocity.y <= 0.0:
		global_position = to
		return
	global_position = hit.position + normal * 3.0
	if normal.y < -0.6:
		_plant(normal)
	else:
		# Wand oder Decke: abprallen und weiter fallen.
		velocity = velocity.bounce(normal) * 0.35


func _plant(normal: Vector2) -> void:
	planted = true
	_normal = normal
	velocity = Vector2.ZERO
	age = 0.0
	if Fx.instance:
		Fx.instance.spark(global_position, color, 3, 90.0)
	Sfx.play("mine_place", 0.1)
	_on_planted()


func _on_planted() -> void:
	pass
