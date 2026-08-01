class_name PetSpeechBubble
extends Window

signal message_finished(id: String)

const WINDOW_SIZE := Vector2i(384, 146)
const CARD_MARGIN := 6.0
const CARD_HEIGHT := 112.0
const TAIL_DEPTH := 28.0
const ANCHOR_GAP := 8.0
const EDGE_PADDING := 8.0

const COLOR_INK := Color("#252839")
const COLOR_MUTED := Color("#6e6b73")
const COLOR_ACCENT := Color("#c87539")
const COLOR_PAPER := Color(1.0, 0.985, 0.945, 0.98)
const COLOR_BORDER := Color(0.12, 0.13, 0.18, 0.92)
const COLOR_SHADOW := Color(0.05, 0.055, 0.08, 0.20)

var current_id := ""
var _generation := 0
var _hiding := false
var _transition_tween: Tween
var _placement := "above"
var _anchor_rect := Rect2()
var _work_area := Rect2()
var _has_layout := false
var _tail_anchor_x := -1000000.0
var _layout_revision := 0

var _surface: Control
var _shadow: PanelContainer
var _card: PanelContainer
var _tail_border: Polygon2D
var _tail_fill: Polygon2D
var _label: Label

func _init() -> void:
	# Native and display flags must be set before the child Window is attached
	# to the visible scene tree. This also keeps direct test instances valid.
	visible = false
	force_native = true
	transparent = true
	mouse_passthrough = true

func _ready() -> void:
	title = "千寻气泡"
	transparent_bg = true
	borderless = true
	always_on_top = true
	unfocusable = true
	min_size = WINDOW_SIZE
	max_size = WINDOW_SIZE
	size = WINDOW_SIZE
	_build_surface()
	hide()

func show_message(
	id: String,
	text: String,
	duration_seconds := -1.0,
	anchor_rect := Rect2(),
	available_work_area := Rect2(),
) -> void:
	if text.strip_edges().is_empty():
		hide_message()
		return
	_generation += 1
	var generation := _generation
	var was_visible := visible and _surface.visible
	_kill_transition_tween()
	_hiding = false
	current_id = id
	_label.text = text.strip_edges()
	_anchor_rect = anchor_rect
	_work_area = available_work_area if available_work_area.size.x > 0.0 and available_work_area.size.y > 0.0 else _default_work_area()
	_place_window()
	_surface.visible = true
	_surface.pivot_offset = Vector2(WINDOW_SIZE) / 2.0
	if was_visible:
		# Replacing a live line must not blank the native window for one frame.
		_surface.modulate.a = 1.0
		_surface.scale = Vector2.ONE
	else:
		# Prepare the first rendered frame before exposing the native window.
		_surface.modulate.a = 0.0
		_surface.scale = Vector2(0.96, 0.96)
		show()
		await get_tree().process_frame
		if generation != _generation:
			return
		_transition_tween = create_tween().set_parallel(true)
		_transition_tween.tween_property(_surface, "modulate:a", 1.0, 0.14)
		_transition_tween.tween_property(_surface, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var seconds := duration_seconds if duration_seconds > 0.0 else suggested_duration(text)
	await get_tree().create_timer(seconds).timeout
	if generation == _generation:
		hide_message()

func update_anchor(anchor_rect: Rect2, available_work_area: Rect2) -> void:
	if not is_showing():
		return
	var next_work_area := _work_area
	if available_work_area.size.x > 0.0 and available_work_area.size.y > 0.0:
		next_work_area = available_work_area
	if _rect_is_equal_approx(anchor_rect, _anchor_rect) and _rect_is_equal_approx(next_work_area, _work_area):
		return
	_anchor_rect = anchor_rect
	_work_area = next_work_area
	_place_window()

func hide_message(immediate := false) -> void:
	if not visible:
		return
	_generation += 1
	var generation := _generation
	var completed_id := current_id
	_hiding = true
	_kill_transition_tween()
	if immediate:
		_finish_hide(generation, completed_id)
		return
	_transition_tween = create_tween().set_parallel(true)
	_transition_tween.tween_property(_surface, "modulate:a", 0.0, 0.12)
	_transition_tween.tween_property(_surface, "scale", Vector2(0.985, 0.985), 0.12)
	_transition_tween.finished.connect(_finish_hide.bind(generation, completed_id), CONNECT_ONE_SHOT)

func is_showing() -> bool:
	return visible

func placement() -> String:
	return _placement

func layout_revision() -> int:
	return _layout_revision

func snapshot() -> Dictionary:
	return {
		"visible": is_showing(),
		"id": current_id,
		"text": _label.text if _label != null else "",
		"placement": _placement,
		"layout_revision": _layout_revision,
	}

static func resolve_placement(anchor_rect: Rect2, work_area: Rect2, bubble_size := Vector2(WINDOW_SIZE)) -> String:
	if anchor_rect.size.x <= 0.0 or anchor_rect.size.y <= 0.0 or work_area.size.y <= 0.0:
		return "above"
	var required := bubble_size.y + ANCHOR_GAP
	var room_above := anchor_rect.position.y - work_area.position.y
	var room_below := work_area.end.y - anchor_rect.end.y
	if room_above >= required:
		return "above"
	if room_below >= required:
		return "below"
	return "above" if room_above >= room_below else "below"

static func resolve_position(
	anchor_rect: Rect2,
	work_area: Rect2,
	placement_name: String,
	bubble_size := Vector2(WINDOW_SIZE),
) -> Vector2:
	var center_x := anchor_rect.position.x + anchor_rect.size.x / 2.0
	var desired := Vector2(center_x - bubble_size.x / 2.0, anchor_rect.position.y - bubble_size.y - ANCHOR_GAP)
	if placement_name == "below":
		desired.y = anchor_rect.end.y + ANCHOR_GAP
	var minimum := work_area.position + Vector2(EDGE_PADDING, EDGE_PADDING)
	var maximum := work_area.end - bubble_size - Vector2(EDGE_PADDING, EDGE_PADDING)
	return Vector2(
		minimum.x if maximum.x < minimum.x else clampf(desired.x, minimum.x, maximum.x),
		minimum.y if maximum.y < minimum.y else clampf(desired.y, minimum.y, maximum.y),
	)

static func suggested_duration(text: String) -> float:
	return clampf(2.8 + text.length() * 0.085, 3.2, 7.0)

func _build_surface() -> void:
	_surface = Control.new()
	_surface.name = "Surface"
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_surface)
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_tail_border = Polygon2D.new()
	_tail_border.name = "TailBorder"
	_tail_border.color = COLOR_BORDER
	_surface.add_child(_tail_border)
	_tail_fill = Polygon2D.new()
	_tail_fill.name = "TailFill"
	_tail_fill.color = COLOR_PAPER
	_surface.add_child(_tail_fill)

	_shadow = PanelContainer.new()
	_shadow.name = "Shadow"
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.add_theme_stylebox_override("panel", _panel_style(COLOR_SHADOW, Color.TRANSPARENT, 19, 0))
	_surface.add_child(_shadow)

	_card = PanelContainer.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", _panel_style(COLOR_PAPER, COLOR_BORDER, 19, 2))
	_surface.add_child(_card)

	var margins := MarginContainer.new()
	margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margins.add_theme_constant_override("margin_left", 16)
	margins.add_theme_constant_override("margin_right", 16)
	margins.add_theme_constant_override("margin_top", 10)
	margins.add_theme_constant_override("margin_bottom", 11)
	_card.add_child(margins)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	margins.add_child(column)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 6)
	column.add_child(header)
	var dot := Label.new()
	dot.text = "●"
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.add_theme_font_size_override("font_size", 11)
	dot.add_theme_color_override("font_color", COLOR_ACCENT)
	header.add_child(dot)
	var speaker := Label.new()
	speaker.text = "千寻"
	speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker.add_theme_font_size_override("font_size", 14)
	speaker.add_theme_color_override("font_color", COLOR_MUTED)
	header.add_child(speaker)

	_label = Label.new()
	_label.name = "Text"
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 17)
	_label.add_theme_color_override("font_color", COLOR_INK)
	column.add_child(_label)

func _place_window() -> void:
	var next_placement := resolve_placement(_anchor_rect, _work_area)
	var resolved := resolve_position(_anchor_rect, _work_area, next_placement)
	var next_position := Vector2i(roundi(resolved.x), roundi(resolved.y))
	var next_tail_anchor_x := clampf(
		roundf(_anchor_rect.position.x + _anchor_rect.size.x / 2.0 - float(next_position.x)),
		38.0,
		float(WINDOW_SIZE.x) - 38.0,
	)
	var placement_changed := not _has_layout or next_placement != _placement
	var position_changed := not _has_layout or next_position != position
	var tail_changed := not _has_layout or not is_equal_approx(next_tail_anchor_x, _tail_anchor_x)
	if not placement_changed and not position_changed and not tail_changed:
		return
	_placement = next_placement
	if position_changed:
		position = next_position
	if placement_changed or tail_changed:
		_tail_anchor_x = next_tail_anchor_x
		_layout_surface(next_tail_anchor_x)
	_has_layout = true
	_layout_revision += 1

func _layout_surface(anchor_x: float) -> void:
	var card_y := CARD_MARGIN if _placement == "above" else TAIL_DEPTH
	var card_position := Vector2(CARD_MARGIN, card_y)
	var card_size := Vector2(float(WINDOW_SIZE.x) - CARD_MARGIN * 2.0, CARD_HEIGHT)
	_shadow.position = card_position + Vector2(0.0, 4.0)
	_shadow.size = card_size
	_card.position = card_position
	_card.size = card_size
	if _placement == "above":
		_tail_border.polygon = PackedVector2Array([
			Vector2(anchor_x - 18.0, card_position.y + card_size.y - 7.0),
			Vector2(anchor_x + 18.0, card_position.y + card_size.y - 7.0),
			Vector2(anchor_x, float(WINDOW_SIZE.y) - 2.0),
		])
		_tail_fill.polygon = PackedVector2Array([
			Vector2(anchor_x - 13.0, card_position.y + card_size.y - 7.0),
			Vector2(anchor_x + 13.0, card_position.y + card_size.y - 7.0),
			Vector2(anchor_x, float(WINDOW_SIZE.y) - 7.0),
		])
	else:
		_tail_border.polygon = PackedVector2Array([
			Vector2(anchor_x, 2.0),
			Vector2(anchor_x + 18.0, card_position.y + 7.0),
			Vector2(anchor_x - 18.0, card_position.y + 7.0),
		])
		_tail_fill.polygon = PackedVector2Array([
			Vector2(anchor_x, 7.0),
			Vector2(anchor_x + 13.0, card_position.y + 7.0),
			Vector2(anchor_x - 13.0, card_position.y + 7.0),
		])

func _finish_hide(generation: int, completed_id: String) -> void:
	if generation != _generation:
		return
	_transition_tween = null
	_surface.visible = false
	hide()
	_hiding = false
	current_id = ""
	_label.text = ""
	message_finished.emit(completed_id)

func _kill_transition_tween() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null

func _default_work_area() -> Rect2:
	return Rect2(DisplayServer.screen_get_usable_rect(current_screen))

func _rect_is_equal_approx(left: Rect2, right: Rect2) -> bool:
	return left.position.is_equal_approx(right.position) and left.size.is_equal_approx(right.size)

func _panel_style(fill: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
