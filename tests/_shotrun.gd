extends Node
func _ready() -> void:
	var gallery: Node = load("res://tests/art_gallery.tscn").instantiate()
	add_child(gallery)
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
	get_tree().quit()
