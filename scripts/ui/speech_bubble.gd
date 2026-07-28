class_name PetSpeechBubble
extends PanelContainer

signal message_finished(id: String)

@export var label_path := NodePath("Text")

var current_id := ""
var _generation := 0
var _label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = get_node(label_path) as Label
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color("#242633"))
	_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.85))
	_label.add_theme_constant_override("outline_size", 2)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.97, 0.92, 0.96)
	style.border_color = Color(0.15, 0.16, 0.22, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(15)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 11.0
	style.content_margin_bottom = 12.0
	add_theme_stylebox_override("panel", style)
	modulate.a = 0.0
	visible = false

func show_message(id: String, text: String, duration_seconds := -1.0) -> void:
	_generation += 1
	var generation := _generation
	current_id = id
	_label.text = text
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.94, 0.94)
	await get_tree().process_frame
	pivot_offset = size / 2.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.16)
	tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var seconds := duration_seconds if duration_seconds > 0.0 else suggested_duration(text)
	await get_tree().create_timer(seconds).timeout
	if generation == _generation:
		hide_message()

func hide_message() -> void:
	if not visible:
		return
	_generation += 1
	var completed_id := current_id
	current_id = ""
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.14)
	tween.tween_property(self, "scale", Vector2(0.97, 0.97), 0.14)
	await tween.finished
	visible = false
	message_finished.emit(completed_id)

func is_showing() -> bool:
	return visible and not current_id.is_empty()

static func suggested_duration(text: String) -> float:
	return clampf(2.8 + text.length() * 0.085, 3.2, 7.0)
