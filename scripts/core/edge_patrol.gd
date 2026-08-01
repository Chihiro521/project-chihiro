class_name EdgePatrolPlanner
extends RefCounted

const EPSILON := 0.001

const VARIANT_A_CLIPS := {
	"ground_left": "patrol_floor_left",
	"ground_right": "patrol_floor_right",
	"wall_left": "patrol_wall_left_a",
	"wall_right": "patrol_wall_right_a",
	"flight_left": "patrol_flight_left",
	"flight_right": "patrol_flight_right",
	"balloon_depart_left": "patrol_balloon_depart_left",
	"balloon_depart_right": "patrol_balloon_depart_right",
	"balloon_arrive_left": "patrol_balloon_arrive_left_a",
	"balloon_arrive_right": "patrol_balloon_arrive_right",
	"floor_to_wall_left": "patrol_floor_to_wall_left_a",
	"floor_to_wall_right": "patrol_floor_to_wall_right_a",
	"wall_left_to_floor_right": "patrol_wall_left_to_floor_right_a",
	"wall_right_to_floor_left": "patrol_wall_right_to_floor_left_a",
}

const VARIANT_B_CLIPS := {
	"ground_left": "patrol_floor_left",
	"ground_right": "patrol_floor_right",
	"wall_left": "patrol_wall_left_b",
	"wall_right": "patrol_wall_right_b",
	"flight_left": "patrol_flight_left",
	"flight_right": "patrol_flight_right",
	"balloon_depart_left": "patrol_balloon_depart_left_b",
	"balloon_depart_right": "patrol_balloon_depart_right_b",
	"balloon_arrive_left": "patrol_balloon_arrive_left_b",
	"balloon_arrive_right": "patrol_balloon_arrive_right_b",
	"floor_to_wall_left": "patrol_floor_to_wall_left_b",
	"floor_to_wall_right": "patrol_floor_to_wall_right_b",
	"wall_left_to_floor_right": "patrol_wall_left_to_floor_right_b",
	"wall_right_to_floor_left": "patrol_wall_right_to_floor_left_b",
}

static func clips_for_variant(variant: String) -> Dictionary:
	return (VARIANT_B_CLIPS if variant == "b" else VARIANT_A_CLIPS).duplicate(true)

static func resolve_bounds(work_area: Rect2, box_side: float, coordinate_scale := 1.0) -> Dictionary:
	var side := maxf(0.0, box_side)
	var scale := coordinate_scale if coordinate_scale > 0.0 else 1.0
	var side_px := side * scale
	var horizontal_span := maxf(0.0, work_area.size.x - side_px)
	var vertical_span := maxf(0.0, work_area.size.y - side_px)
	return {
		"min_x": work_area.position.x,
		"max_x": work_area.position.x + horizontal_span,
		"min_y": work_area.position.y,
		"max_y": work_area.position.y + vertical_span,
		"box_side": side,
		"box_side_px": side_px,
		"horizontal_span": horizontal_span,
		"vertical_span": vertical_span,
		"fits": side_px > 0.0 and work_area.size.x + EPSILON >= side_px and work_area.size.y + EPSILON >= side_px,
	}

static func edge_position(bounds: Dictionary, edge: String, progress: float) -> Vector2:
	var value := clampf(progress, 0.0, 1.0)
	match edge:
		"bottom": return Vector2(lerpf(bounds.min_x, bounds.max_x, value), bounds.max_y)
		"left": return Vector2(bounds.min_x, lerpf(bounds.max_y, bounds.min_y, value))
		"top": return Vector2(lerpf(bounds.min_x, bounds.max_x, value), bounds.min_y)
		"right": return Vector2(bounds.max_x, lerpf(bounds.min_y, bounds.max_y, value))
	return Vector2(bounds.min_x, bounds.max_y)

static func corner_position(bounds: Dictionary, corner_name: String) -> Vector2:
	match corner_name:
		"bottom-left": return Vector2(bounds.min_x, bounds.max_y)
		"top-left": return Vector2(bounds.min_x, bounds.min_y)
		"top-right": return Vector2(bounds.max_x, bounds.min_y)
		"bottom-right": return Vector2(bounds.max_x, bounds.max_y)
	return Vector2(bounds.min_x, bounds.max_y)

static func inspect_capabilities(available_names: Array[String], clips: Dictionary) -> Dictionary:
	var available := {}
	for name in available_names:
		available[name] = true
	var missing_full: Array[String] = []
	for name in clips.values():
		if not available.has(str(name)):
			missing_full.append(str(name))
	var both_ground := available.has(str(clips.ground_left)) and available.has(str(clips.ground_right))
	var wall_left := both_ground and available.has(str(clips.wall_left)) and available.has(str(clips.floor_to_wall_left)) and available.has(str(clips.wall_left_to_floor_right))
	var wall_right := both_ground and available.has(str(clips.wall_right)) and available.has(str(clips.floor_to_wall_right)) and available.has(str(clips.wall_right_to_floor_left))
	return {
		"full": missing_full.is_empty(),
		"wall": wall_left or wall_right,
		"wall_left": wall_left,
		"wall_right": wall_right,
		"ground_left": available.has(str(clips.ground_left)),
		"ground_right": available.has(str(clips.ground_right)),
		"missing_for_full_route": missing_full,
	}

static func plan(options: Dictionary) -> Dictionary:
	var work_area: Rect2 = options.get("work_area", Rect2(0, 0, 1920, 1040))
	var clips: Dictionary = options.get("clips", VARIANT_A_CLIPS).duplicate()
	var bounds := resolve_bounds(work_area, float(options.get("box_side", 360.0)), float(options.get("coordinate_scale", 1.0)))
	var available: Array[String] = []
	for clip_name in options.get("available_clips", []):
		available.append(str(clip_name))
	var capabilities := inspect_capabilities(available, clips)
	var random := RandomNumberGenerator.new()
	random.seed = abs(str(options.get("seed", "CHIHIRO")).hash())
	var source: Vector2 = options.get("start", Vector2.ZERO)
	var start := Vector2(clampf(source.x, bounds.min_x, bounds.max_x), bounds.max_y)
	if bounds.fits and bounds.horizontal_span > EPSILON and bounds.vertical_span > EPSILON and capabilities.full:
		var direction := "via-left" if random.randf() < 0.5 else "via-right"
		return _result("full", direction, bounds, _build_full_route(direction, start, bounds, clips, random), capabilities)
	if bounds.fits and bounds.horizontal_span > EPSILON and bounds.vertical_span > EPSILON and capabilities.wall:
		var candidates: Array[String] = []
		if capabilities.wall_left: candidates.append("via-left")
		if capabilities.wall_right: candidates.append("via-right")
		var direction := candidates[random.randi_range(0, candidates.size() - 1)]
		var requested = options.get("wall_climb_progress", null)
		var climb := clampf(float(requested), 0.35, 0.65) if requested != null else 0.35 + random.randf() * 0.3
		return _result("wall", direction, bounds, _build_wall_route(direction, start, bounds, clips, random, climb), capabilities)
	var fallback := _ground_fallback(start, bounds, clips, capabilities, random)
	return _result("ground" if not fallback.is_empty() else "none", "", bounds, fallback, capabilities)

static func _build_full_route(direction: String, start: Vector2, bounds: Dictionary, clips: Dictionary, random: RandomNumberGenerator) -> Array[Dictionary]:
	var bottom_left := corner_position(bounds, "bottom-left")
	var top_left := corner_position(bounds, "top-left")
	var top_right := corner_position(bounds, "top-right")
	var bottom_right := corner_position(bounds, "bottom-right")
	var finish_inset := 0.22 + random.randf() * 0.22
	if direction == "via-left":
		return [
			_traverse("bottom", "left", clips.ground_left, false, start, bottom_left),
			_corner("bottom-left", "bottom", "left", clips.floor_to_wall_left, false, bottom_left),
			_traverse("left", "up", clips.wall_left, false, bottom_left, top_left),
			_corner("top-left", "left", "top", clips.balloon_depart_left, false, top_left),
			_traverse("top", "right", clips.flight_right, false, top_left, top_right),
			_corner("top-right", "top", "right", clips.balloon_arrive_right, false, top_right),
			_traverse("right", "down", clips.wall_right, true, top_right, bottom_right),
			_corner("bottom-right", "right", "bottom", clips.wall_right_to_floor_left, false, bottom_right),
			_traverse("bottom", "left", clips.ground_left, false, bottom_right, edge_position(bounds, "bottom", 1.0 - finish_inset)),
		]
	return [
		_traverse("bottom", "right", clips.ground_right, false, start, bottom_right),
		_corner("bottom-right", "bottom", "right", clips.floor_to_wall_right, false, bottom_right),
		_traverse("right", "up", clips.wall_right, false, bottom_right, top_right),
		_corner("top-right", "right", "top", clips.balloon_depart_right, false, top_right),
		_traverse("top", "left", clips.flight_left, false, top_right, top_left),
		_corner("top-left", "top", "left", clips.balloon_arrive_left, false, top_left),
		_traverse("left", "down", clips.wall_left, true, top_left, bottom_left),
		_corner("bottom-left", "left", "bottom", clips.wall_left_to_floor_right, false, bottom_left),
		_traverse("bottom", "right", clips.ground_right, false, bottom_left, edge_position(bounds, "bottom", finish_inset)),
	]

static func _build_wall_route(direction: String, start: Vector2, bounds: Dictionary, clips: Dictionary, random: RandomNumberGenerator, climb: float) -> Array[Dictionary]:
	var finish_inset := 0.22 + random.randf() * 0.22
	if direction == "via-left":
		var bottom_left := corner_position(bounds, "bottom-left")
		var target := edge_position(bounds, "left", climb)
		return [
			_traverse("bottom", "left", clips.ground_left, false, start, bottom_left),
			_corner("bottom-left", "bottom", "left", clips.floor_to_wall_left, false, bottom_left),
			_traverse("left", "up", clips.wall_left, false, bottom_left, target),
			_traverse("left", "down", clips.wall_left, true, target, bottom_left),
			_corner("bottom-left", "left", "bottom", clips.wall_left_to_floor_right, false, bottom_left),
			_traverse("bottom", "right", clips.ground_right, false, bottom_left, edge_position(bounds, "bottom", finish_inset)),
		]
	var bottom_right := corner_position(bounds, "bottom-right")
	var target := edge_position(bounds, "right", 1.0 - climb)
	return [
		_traverse("bottom", "right", clips.ground_right, false, start, bottom_right),
		_corner("bottom-right", "bottom", "right", clips.floor_to_wall_right, false, bottom_right),
		_traverse("right", "up", clips.wall_right, false, bottom_right, target),
		_traverse("right", "down", clips.wall_right, true, target, bottom_right),
		_corner("bottom-right", "right", "bottom", clips.wall_right_to_floor_left, false, bottom_right),
		_traverse("bottom", "left", clips.ground_left, false, bottom_right, edge_position(bounds, "bottom", 1.0 - finish_inset)),
	]

static func _ground_fallback(start: Vector2, bounds: Dictionary, clips: Dictionary, capabilities: Dictionary, random: RandomNumberGenerator) -> Array[Dictionary]:
	if not bounds.fits or bounds.horizontal_span <= EPSILON:
		return []
	var left_room: float = start.x - bounds.min_x
	var right_room: float = bounds.max_x - start.x
	var candidates: Array[String] = []
	if capabilities.ground_left and left_room > EPSILON: candidates.append("left")
	if capabilities.ground_right and right_room > EPSILON: candidates.append("right")
	if candidates.is_empty(): return []
	var direction := candidates[random.randi_range(0, candidates.size() - 1)]
	var distance_ratio := 0.35 + random.randf() * 0.55
	var target := Vector2(start.x - left_room * distance_ratio, bounds.max_y) if direction == "left" else Vector2(start.x + right_room * distance_ratio, bounds.max_y)
	return [_traverse("bottom", direction, clips.ground_left if direction == "left" else clips.ground_right, false, start, target)]

static func _traverse(edge: String, direction: String, clip_name: String, reverse: bool, from: Vector2, to: Vector2) -> Dictionary:
	return {"kind": "traverse", "edge": edge, "direction": direction, "clip_name": clip_name, "reverse": reverse, "from": from, "to": to}

static func _corner(corner_name: String, from_edge: String, to_edge: String, clip_name: String, reverse: bool, position: Vector2) -> Dictionary:
	return {"kind": "corner", "corner": corner_name, "from_edge": from_edge, "to_edge": to_edge, "clip_name": clip_name, "reverse": reverse, "position": position}

static func _result(mode: String, direction: String, bounds: Dictionary, poses: Array[Dictionary], capabilities: Dictionary) -> Dictionary:
	return {"mode": mode, "direction": direction, "bounds": bounds, "poses": poses, "capabilities": capabilities}
