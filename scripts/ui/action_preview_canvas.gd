class_name PetActionPreviewCanvas
extends Control

var _texture: Texture2D
var _clip: Dictionary = {}
var _frame_index := 0
var _show_guides := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(340.0, 340.0)
	resized.connect(queue_redraw)

func set_preview(texture: Texture2D, clip: Dictionary, frame_index: int) -> void:
	_texture = texture
	_clip = clip
	_frame_index = frame_index
	queue_redraw()

func set_guides_visible(value: bool) -> void:
	_show_guides = value
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#11161d"))
	var canvas: Dictionary = _clip.get("canvas", {"width": 512.0, "height": 512.0})
	var canvas_size := Vector2(
		maxf(1.0, float(canvas.get("width", 512.0))),
		maxf(1.0, float(canvas.get("height", 512.0))),
	)
	var available := Vector2(maxf(1.0, size.x - 36.0), maxf(1.0, size.y - 36.0))
	var preview_scale := minf(available.x / canvas_size.x, available.y / canvas_size.y)
	var preview_size := canvas_size * preview_scale
	var preview_rect := Rect2((size - preview_size) * 0.5, preview_size)
	_draw_checkerboard(preview_rect)
	if _texture != null:
		draw_texture_rect(_texture, preview_rect, false)
	if _show_guides:
		_draw_guides(preview_rect, canvas_size, preview_scale)
	draw_rect(preview_rect, Color("#4d5968"), false, 1.0)

func _draw_checkerboard(rect: Rect2) -> void:
	var cell := 16.0
	var columns := ceili(rect.size.x / cell)
	var rows := ceili(rect.size.y / cell)
	for row in rows:
		for column in columns:
			var cell_position := rect.position + Vector2(column * cell, row * cell)
			var cell_size := Vector2(
				minf(cell, rect.end.x - cell_position.x),
				minf(cell, rect.end.y - cell_position.y),
			)
			var color := Color("#202833") if (row + column) % 2 == 0 else Color("#18202a")
			draw_rect(Rect2(cell_position, cell_size), color)

func _draw_guides(preview_rect: Rect2, canvas_size: Vector2, preview_scale: float) -> void:
	var visual_bounds: Dictionary = _clip.get("visualBounds", {})
	if not visual_bounds.is_empty():
		var bounds := Rect2(
			_to_preview_point(Vector2(float(visual_bounds.get("x", 0.0)), float(visual_bounds.get("y", 0.0))), preview_rect, preview_scale),
			Vector2(float(visual_bounds.get("width", 0.0)), float(visual_bounds.get("height", 0.0))) * preview_scale,
		)
		draw_rect(bounds, Color("#ffd166"), false, 1.5)
	var hit_points := PackedVector2Array()
	for point_value in _clip.get("hitArea", []):
		if point_value is Dictionary:
			hit_points.append(_to_preview_point(Vector2(float(point_value.get("x", 0.0)), float(point_value.get("y", 0.0))), preview_rect, preview_scale))
	if hit_points.size() >= 3:
		hit_points.append(hit_points[0])
		draw_polyline(hit_points, Color("#ff6b8a"), 1.5, true)
	var anchor: Dictionary = _clip.get("anchor", {"x": 0.5, "y": 0.96})
	var anchor_texture := Vector2(
		float(anchor.get("x", 0.5)) * canvas_size.x,
		float(anchor.get("y", 0.96)) * canvas_size.y,
	)
	var anchor_point := _to_preview_point(anchor_texture, preview_rect, preview_scale)
	draw_line(anchor_point - Vector2(8.0, 0.0), anchor_point + Vector2(8.0, 0.0), Color("#55d6ff"), 1.5)
	draw_line(anchor_point - Vector2(0.0, 8.0), anchor_point + Vector2(0.0, 8.0), Color("#55d6ff"), 1.5)
	var support_texture := anchor_texture
	var support_x: Array = _clip.get("supportContactX", [])
	var support_y: Array = _clip.get("supportContactY", [])
	if not support_x.is_empty():
		support_texture.x = float(support_x[clampi(_frame_index, 0, support_x.size() - 1)])
	if not support_y.is_empty():
		support_texture.y = float(support_y[clampi(_frame_index, 0, support_y.size() - 1)])
	if not support_x.is_empty() or not support_y.is_empty():
		var support_point := _to_preview_point(support_texture, preview_rect, preview_scale)
		draw_line(
			Vector2(preview_rect.position.x, support_point.y),
			Vector2(preview_rect.end.x, support_point.y),
			Color("#72e6a1", 0.7),
			1.0,
		)
		draw_circle(support_point, 4.0, Color("#72e6a1"))

func _to_preview_point(texture_point: Vector2, preview_rect: Rect2, preview_scale: float) -> Vector2:
	return preview_rect.position + texture_point * preview_scale
