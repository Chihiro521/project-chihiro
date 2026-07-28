extends Control

const OUTPUT_PATH := "res://art/animation-production/idle_breathe/key-poses/key-pose-review.png"

func _ready() -> void:
	get_window().size = Vector2i(1100, 640)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path(OUTPUT_PATH)
	var error := DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	if error == OK:
		error = get_viewport().get_texture().get_image().save_png(output)
	if error != OK:
		push_error("无法写入关键姿势评审图：%s" % error_string(error))
	get_tree().quit(0 if error == OK else 1)
