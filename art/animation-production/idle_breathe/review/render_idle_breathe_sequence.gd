extends Node2D

const OUTPUT_DIR := "res://art/animation-production/idle_breathe/frames"
const FRAME_COUNT := 8

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	get_window().size = Vector2i(512, 512)
	get_viewport().transparent_bg = true
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var error := DirAccess.make_dir_recursive_absolute(output_dir)
	if error != OK:
		push_error("无法创建呼吸动画输出目录：%s" % error_string(error))
		get_tree().quit(1)
		return
	var material := sprite.material as ShaderMaterial
	if material == null:
		push_error("呼吸动画渲染器缺少 ShaderMaterial")
		get_tree().quit(1)
		return
	await get_tree().process_frame
	for frame_index in range(FRAME_COUNT):
		var phase := float(frame_index) / float(FRAME_COUNT)
		var pose_amount := 0.5 - 0.5 * cos(TAU * phase)
		material.set_shader_parameter("pose_amount", pose_amount)
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		RenderingServer.force_sync()
		var image := get_viewport().get_texture().get_image()
		if image.get_size() != Vector2i(512, 512):
			push_error("呼吸动画帧尺寸错误：%s" % image.get_size())
			get_tree().quit(1)
			return
		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)
		var frame_path := output_dir.path_join("frame_%03d.png" % frame_index)
		error = image.save_png(frame_path)
		if error != OK:
			push_error("无法写入呼吸动画帧：%s" % error_string(error))
			get_tree().quit(1)
			return
		print("rendered idle_breathe frame %03d at phase %.3f" % [frame_index, phase])
	get_tree().quit(0)
