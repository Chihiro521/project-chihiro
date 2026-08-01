class_name PetSpeechBubble
extends PanelContainer

signal message_finished(id: String)

const MIN_WINDOW_SIZE := Vector2i(520, 480)
const TOP_RESERVE_PX := 104

@export var label_path := NodePath("Text")

var current_id := ""
var _generation := 0
var _label: Label
var _hiding := false
var _transition_tween: Tween

func _ready() -> void:
	z_index = 20
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
	if text.strip_edges().is_empty():
		hide_message()
		return
	_generation += 1
	var generation := _generation
	_kill_transition_tween()
	_hiding = false
	current_id = id
	_label.text = text
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.94, 0.94)
	await get_tree().process_frame
	if generation != _generation:
		return
	pivot_offset = size / 2.0
	_transition_tween = create_tween().set_parallel(true)
	_transition_tween.tween_property(self, "modulate:a", 1.0, 0.16)
	_transition_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var seconds := duration_seconds if duration_seconds > 0.0 else suggested_duration(text)
	await get_tree().create_timer(seconds).timeout
	if generation == _generation:
		hide_message()

func hide_message() -> void:
	if not visible or _hiding:
		return
	_generation += 1
	var generation := _generation
	var completed_id := current_id
	_hiding = true
	_kill_transition_tween()
	_transition_tween = create_tween().set_parallel(true)
	_transition_tween.tween_property(self, "modulate:a", 0.0, 0.14)
	_transition_tween.tween_property(self, "scale", Vector2(0.97, 0.97), 0.14)
	_transition_tween.finished.connect(_finish_hide.bind(generation, completed_id), CONNECT_ONE_SHOT)

func _finish_hide(generation: int, completed_id: String) -> void:
	if generation != _generation:
		return
	_transition_tween = null
	visible = false
	_hiding = false
	current_id = ""
	_label.text = ""
	message_finished.emit(completed_id)

func is_showing() -> bool:
	# Keep the expanded transparent host until the panel has fully faded out.
	return visible

func snapshot() -> Dictionary:
	return {
		"visible": is_showing(),
		"id": current_id,
		"text": _label.text if _label != null else "",
	}

static func required_window_size(content_size: Vector2i) -> Vector2i:
	return Vector2i(
		maxi(content_size.x, MIN_WINDOW_SIZE.x),
		maxi(MIN_WINDOW_SIZE.y, content_size.y + TOP_RESERVE_PX),
	)

func _kill_transition_tween() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null

static func suggested_duration(text: String) -> float:
	return clampf(2.8 + text.length() * 0.085, 3.2, 7.0)
