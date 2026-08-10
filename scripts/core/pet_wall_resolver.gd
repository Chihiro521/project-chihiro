class_name PetWallResolver
extends RefCounted

## Pure horizontal-collision resolver between the pet's body and window walls.
## No node dependencies — the caller supplies absolute-desktop wall edges and the
## pet's foot positions.
##
## Geometry: the pet's collision body is a PET_COLLISION_SIZE box anchored at the
## feet (foot point sits on the bottom-center). A wall edge at `x` with
## `side == movement-dx` blocks the pet when the moving body edge would cross it,
## but only while the wall's vertical extent reaches the pet's body band — a
## window raised high enough to walk under does not block, and a short wall is
## flagged `short` so the caller can hop instead of climb.

const PET_COLLISION_SIZE := Vector2(110.0, 170.0)
const WALL_HOP_REACH_PX := 120.0
const BODY_HALF_WIDTH := PET_COLLISION_SIZE.x / 2.0


## The body box for a foot position. `foot` is the absolute ground-contact point;
## the box rises PET_COLLISION_SIZE.y above it and is centered horizontally.
static func collision_rect(foot: Vector2) -> Rect2:
	return Rect2(foot.x - BODY_HALF_WIDTH, foot.y - PET_COLLISION_SIZE.y, PET_COLLISION_SIZE.x, PET_COLLISION_SIZE.y)


## Finds the first wall the moving body edge would cross during the foot segment
## [foot_from, foot_to]. Returns {} when nothing blocks, otherwise the wall dict
## enriched with `short` (true when the wall top is within `hop_reach` of the
## pet's floor). `floor_y` is the FOOT-space ground plane (pet feet on the floor).
static func find_blocking_wall(
	foot_from: Vector2,
	foot_to: Vector2,
	wall_edges: Array,
	floor_y: float,
	hop_reach := WALL_HOP_REACH_PX,
) -> Dictionary:
	var dx := signf(foot_to.x - foot_from.x)
	if dx == 0.0:
		return {}
	var body_top := foot_from.y - PET_COLLISION_SIZE.y
	var foot_y := foot_from.y
	var best_wall: Dictionary = {}
	var best_distance := INF
	for entry in wall_edges:
		if not entry is Dictionary:
			continue
		var side := int((entry as Dictionary).get("side", 0))
		if side != int(dx):
			continue
		var wall_x := float((entry as Dictionary).get("x", 0.0))
		var top_y := float((entry as Dictionary).get("top_y", 0.0))
		var bottom_y := float((entry as Dictionary).get("bottom_y", 0.0))
		# Only walls that rise above the pet's feet AND reach down to the body
		# band block: below the feet = cleared, above the head = walk under.
		if top_y >= foot_y or bottom_y < body_top:
			continue
		var moving_edge_from := foot_from.x + BODY_HALF_WIDTH * dx
		var moving_edge_to := foot_to.x + BODY_HALF_WIDTH * dx
		var crossed := moving_edge_from <= wall_x and moving_edge_to >= wall_x if dx > 0.0 \
			else moving_edge_from >= wall_x and moving_edge_to <= wall_x
		if not crossed:
			continue
		var distance := absf(moving_edge_from - wall_x)
		if distance < best_distance:
			best_distance = distance
			best_wall = {
				"x": wall_x,
				"side": side,
				"top_y": top_y,
				"bottom_y": bottom_y,
				"handle": int((entry as Dictionary).get("handle", 0)),
				"process_id": int((entry as Dictionary).get("process_id", 0)),
				"short": (floor_y - top_y) <= hop_reach,
			}
	return best_wall


## resolve_horizontal returns the clamped foot position and the blocking wall.
## When the path is clear the returned position is `foot_to` with an empty wall;
## when a wall blocks, the foot is clamped so the moving body edge sits flush
## against the wall (foot.x = wall_x -/+ BODY_HALF_WIDTH by direction).
static func resolve_horizontal(
	foot_from: Vector2,
	foot_to: Vector2,
	wall_edges: Array,
	floor_y: float,
	hop_reach := WALL_HOP_REACH_PX,
) -> Dictionary:
	var wall := find_blocking_wall(foot_from, foot_to, wall_edges, floor_y, hop_reach)
	if wall.is_empty():
		return {"position": foot_to, "wall": {}}
	var dx := signf(foot_to.x - foot_from.x)
	var wall_x := float(wall.get("x", 0.0))
	var clamped_x := wall_x - BODY_HALF_WIDTH if dx > 0.0 else wall_x + BODY_HALF_WIDTH
	return {"position": Vector2(clamped_x, foot_to.y), "wall": wall}


## Convenience: true when the foot segment would cross a blocking wall.
static func is_blocked(
	foot_from: Vector2,
	foot_to: Vector2,
	wall_edges: Array,
	floor_y: float,
	hop_reach := WALL_HOP_REACH_PX,
) -> bool:
	return not find_blocking_wall(foot_from, foot_to, wall_edges, floor_y, hop_reach).is_empty()
