class_name PetRenderBox
extends RefCounted

const DEFAULT_BASE_SIZE := 360.0
const EDGE_INSET := 8.0

static func character_scale(manifest: PetManifestData) -> float:
	var canvas := manifest.canvas()
	return float(canvas.get("displayWidth", 328.0)) / maxf(1.0, float(canvas.get("width", 512.0)))

static func render_dock(clip: Dictionary) -> String:
	var placement: Dictionary = clip.get("placement", {})
	return str(placement.get("dock", "bottom"))

static func render_dock_inset(clip: Dictionary) -> float:
	var placement: Dictionary = clip.get("placement", {})
	return maxf(0.0, float(placement.get("inset", EDGE_INSET)))

static func dock_point(size: Vector2, dock := "bottom", inset := EDGE_INSET) -> Vector2:
	var horizontal := "center"
	var vertical := "center"
	if dock == "left" or str(dock).ends_with("-left"):
		horizontal = "start"
	elif dock == "right" or str(dock).ends_with("-right"):
		horizontal = "end"
	if dock == "top" or str(dock).begins_with("top-"):
		vertical = "start"
	elif dock == "bottom" or str(dock).begins_with("bottom-"):
		vertical = "end"
	return Vector2(
		_axis_point(size.x, horizontal, inset),
		_axis_point(size.y, vertical, inset),
	)

static func support_texture_point(clip: Dictionary, frame_index: int) -> Vector2:
	var canvas: Dictionary = clip.get("canvas", {"width": 512.0, "height": 512.0})
	var anchor: Dictionary = clip.get("anchor", {"x": 0.5, "y": 0.96})
	var point := Vector2(
		float(anchor.get("x", 0.5)) * float(canvas.get("width", 512.0)),
		float(anchor.get("y", 0.96)) * float(canvas.get("height", 512.0)),
	)
	var support_x: Array = clip.get("supportContactX", [])
	var support_y: Array = clip.get("supportContactY", [])
	if not support_x.is_empty():
		point.x = float(support_x[clampi(frame_index, 0, support_x.size() - 1)])
	if not support_y.is_empty():
		point.y = float(support_y[clampi(frame_index, 0, support_y.size() - 1)])
	return point


## Y distance from the pet box top to the foot for a clip+frame. Riding pins the
## foot with this LIVE pose offset: standing/walking clips resolve to the standing
## constant (WINDOW_FOOT_OFFSET_Y = 356), but riding poses like the window sit keep
## their feet at a different supportContactY offset, and a hardcoded standing pin
## fights the per-frame foot correction (vertical 鬼畜 while sitting on a window).
static func foot_offset_y(clip: Dictionary, frame_index: int, box_size: Vector2, scale: float) -> float:
	var canvas: Dictionary = clip.get("canvas", {"width": 512.0, "height": 512.0})
	var anchor: Dictionary = clip.get("anchor", {"x": 0.5, "y": 0.96})
	var anchor_point := Vector2(
		float(anchor.get("x", 0.5)) * float(canvas.get("width", 512.0)),
		float(anchor.get("y", 0.96)) * float(canvas.get("height", 512.0)),
	)
	var support_point := support_texture_point(clip, frame_index)
	var dock := dock_point(box_size, render_dock(clip), render_dock_inset(clip))
	var legacy_inset := 0.0 if not (clip.get("supportContactY", []) as Array).is_empty() else 4.0
	return dock.y + (support_point.y - anchor_point.y) * scale + legacy_inset

static func resolve_size(manifest: PetManifestData, clip: Dictionary = {}) -> Vector2i:
	var base_canvas := manifest.canvas()
	var clip_canvas: Dictionary = clip.get("canvas", base_canvas)
	var base_canvas_side := maxf(float(base_canvas.get("width", 512.0)), float(base_canvas.get("height", 512.0)))
	var clip_canvas_side := maxf(float(clip_canvas.get("width", 512.0)), float(clip_canvas.get("height", 512.0)))
	var render_box := manifest.render_box()
	var minimum_base := ceilf(maxf(
		float(render_box.get("baseSize", DEFAULT_BASE_SIZE)),
		maxf(float(base_canvas.get("displayWidth", 328.0)), float(base_canvas.get("displayHeight", 328.0))),
	))
	var scale := character_scale(manifest)
	var raw_side := minimum_base + maxf(0.0, clip_canvas_side - base_canvas_side) * scale
	var visual_bounds: Dictionary = clip.get("visualBounds", {})
	if not visual_bounds.is_empty():
		var anchor: Dictionary = clip.get("anchor", {"x": 0.5, "y": 0.96})
		var anchor_x := float(anchor.get("x", 0.5)) * float(clip_canvas.get("width", 512.0))
		var anchor_y := float(anchor.get("y", 0.96)) * float(clip_canvas.get("height", 512.0))
		var safe_margin := float(render_box.get("safeMargin", 0.0))
		var minimum_x := (float(visual_bounds.get("x", 0.0)) - anchor_x) * scale
		var maximum_x := (float(visual_bounds.get("x", 0.0)) + float(visual_bounds.get("width", 0.0)) - anchor_x) * scale
		var minimum_y := (float(visual_bounds.get("y", 0.0)) - anchor_y) * scale
		var maximum_y := (float(visual_bounds.get("y", 0.0)) + float(visual_bounds.get("height", 0.0)) - anchor_y) * scale
		var dock := render_dock(clip)
		var inset := render_dock_inset(clip)
		var horizontal := "center"
		var vertical := "center"
		if dock == "left" or dock.ends_with("-left"):
			horizontal = "start"
		elif dock == "right" or dock.ends_with("-right"):
			horizontal = "end"
		if dock == "top" or dock.begins_with("top-"):
			vertical = "start"
		elif dock == "bottom" or dock.begins_with("bottom-"):
			vertical = "end"
		var horizontal_side := _required_side(minimum_x, maximum_x, horizontal, inset, safe_margin)
		var vertical_side := _required_side(minimum_y, maximum_y, vertical, inset, safe_margin)
		# visualBounds is authoritative when present, matching the original
		# runtime: transparent canvas headroom must not enlarge the native host.
		raw_side = maxf(minimum_base, maxf(horizontal_side, vertical_side))
	var step := maxf(1.0, float(render_box.get("resizeStep", 1.0)))
	var side := int(ceilf(raw_side / step) * step)
	return Vector2i(side, side)

static func _axis_point(length: float, alignment: String, inset: float) -> float:
	if alignment == "start":
		return inset
	if alignment == "end":
		return length - inset
	return length / 2.0

static func _required_side(minimum_offset: float, maximum_offset: float, alignment: String, inset: float, safe_margin: float) -> float:
	if alignment == "start":
		return safe_margin + inset + maximum_offset
	if alignment == "end":
		return safe_margin + inset - minimum_offset
	return maxf(2.0 * (safe_margin - minimum_offset), 2.0 * (safe_margin + maximum_offset))
