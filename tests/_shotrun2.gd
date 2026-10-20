extends Node
func _ready() -> void:
	var scene: Node = load(OS.get_environment("SHOT_SCENE")).instantiate()
	add_child(scene)
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
	get_tree().quit()
