class_name WindowHopPlanner
extends RefCounted

const WindowPlatformServiceScript := preload("res://scripts/platform/window_platform_service.gd")
const WindowPlatformData := preload("res://scripts/platform/window_platform.gd")

const MIN_RISE_PX := 16.0
const MAX_RISE_PX := 120.0
const MAX_HORIZONTAL_PX := 900.0
const TARGET_SAFE_MARGIN_PX := 48.0
const SOURCE_SAFE_MARGIN_PX := 54.0
const MIN_VISIBLE_WIDTH_PX := 160
const MAX_WINDOW_AREA_RATIO := 0.70
const TARGET_MISSING_GRACE_MS := 250.0


## Bespoke hop sessions do not use PetActionSession, so their total deadline is
## the configured post-approach allowance plus the time needed to reach the
## planned takeoff point. A distant takeoff point therefore remains reachable,
## while a stalled phase is still bounded.
static func session_budget_ms(configured_max_ms: float, approach_distance_px: float, approach_speed_px_s: float) -> float:
	var approach_ms := maxf(0.0, approach_distance_px) / maxf(1.0, approach_speed_px_s) * 1000.0
	return maxf(0.0, configured_max_ms) + approach_ms


## Timeout recovery preserves the strongest physical invariant for each phase:
## keep the source before launch, fall naturally in flight, and keep the target
## after the feet have already landed.
static func timeout_recovery_for_phase(phase: String) -> String:
	if phase == "airborne":
		return "fall"
	if phase in ["land", "recover"]:
		return "finish"
	return "cancel"


## A PLATFORM_LOST transition can prepare its fall before the state-machine
## signal clears the hop session. Preserve that prepared motion just like the
## dedicated airborne-failure handoff, but never preserve an unrelated stale arc.
static func should_preserve_fall_motion(next_state: String, event: Dictionary, falling_out: bool, has_motion: bool) -> bool:
	return (
		next_state == "drag_fall"
		and has_motion
		and (falling_out or str(event.get("type", "")) == "PLATFORM_LOST")
	)


## Selects exactly the frontmost rendered foreign application window, then asks
## whether that SAME window is a safe upward-hop target. An unsuitable frontmost
## window intentionally blocks selection; windows behind it are never substituted.
static func select_frontmost_target(
	source: WindowPlatform,
	platforms: Array,
	snapshots: Array,
	self_pid: int,
	self_z_order: int,
	screen_rect: Rect2i,
	work_area: Rect2i,
	preferred_foot_x: float,
) -> Dictionary:
	if source == null:
		return {"eligible": false, "reason": "no_source"}
	if self_z_order < 0:
		return {"eligible": false, "reason": "pet_z_unknown"}
	var rendered: Array[Dictionary] = []
	for value in snapshots:
		if not value is Dictionary:
			continue
		var snapshot := value as Dictionary
		if WindowPlatformServiceScript.is_foreground_snapshot_valid(snapshot, self_pid):
			rendered.append(snapshot)
	rendered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("z_order", 0)) < int(right.get("z_order", 0))
	)
	if rendered.is_empty():
		return {"eligible": false, "reason": "no_rendered_window"}

	var target_snapshot := rendered[0]
	var handle := int(target_snapshot.get("handle", 0))
	var pid := int(target_snapshot.get("process_id", 0))
	if handle == source.handle and pid == source.process_id:
		return {"eligible": false, "reason": "frontmost_is_source", "snapshot": target_snapshot}
	if not WindowPlatformServiceScript.is_snapshot_eligible(target_snapshot, self_pid):
		return {"eligible": false, "reason": "frontmost_not_standable", "snapshot": target_snapshot}
	if bool(target_snapshot.get("maximized", false)):
		return {"eligible": false, "reason": "frontmost_maximized", "snapshot": target_snapshot}

	var target_z := int(target_snapshot.get("z_order", 0))
	if self_z_order >= 0 and target_z < self_z_order:
		return {"eligible": false, "reason": "in_front_of_pet", "snapshot": target_snapshot}
	if target_z >= source.z_order:
		return {"eligible": false, "reason": "not_in_front_of_source", "snapshot": target_snapshot}

	var target_rect := WindowPlatformData.rect_from_value(target_snapshot.get("rect", Rect2i()))
	if work_area.size.x > 0 and work_area.size.y > 0:
		var work_area_pixels := float(work_area.size.x) * float(work_area.size.y)
		var target_pixels := float(target_rect.size.x) * float(target_rect.size.y)
		if target_pixels > work_area_pixels * MAX_WINDOW_AREA_RATIO:
			return {"eligible": false, "reason": "frontmost_too_large", "snapshot": target_snapshot}
	if screen_rect.size.x > 0 and screen_rect.size.y > 0:
		if not screen_rect.has_point(target_rect.get_center()) or not screen_rect.has_point(source.rect.get_center()):
			return {"eligible": false, "reason": "different_screen", "snapshot": target_snapshot}

	var best: Dictionary = {}
	var best_distance := INF
	var best_horizontal := INF
	for value in platforms:
		if not value is WindowPlatform:
			continue
		var platform := value as WindowPlatform
		if platform.handle != handle or platform.process_id != pid:
			continue
		var visible_left := platform.segment_left()
		var visible_right := platform.segment_right()
		if screen_rect.size.x > 0 and screen_rect.size.y > 0:
			if platform.top_edge.position.y < screen_rect.position.y or platform.top_edge.position.y >= screen_rect.end.y:
				continue
			visible_left = maxi(visible_left, screen_rect.position.x)
			visible_right = mini(visible_right, screen_rect.end.x)
		if visible_right - visible_left < MIN_VISIBLE_WIDTH_PX:
			continue
		var visible_platform := WindowPlatformData.from_snapshot(target_snapshot, visible_left, visible_right)
		var plan := plan_between(source, visible_platform, preferred_foot_x)
		if not bool(plan.get("eligible", false)):
			continue
		var landing_distance := absf(float(plan.get("landing_x", preferred_foot_x)) - preferred_foot_x)
		var horizontal := float(plan.get("horizontal_px", INF))
		if landing_distance < best_distance or (is_equal_approx(landing_distance, best_distance) and horizontal < best_horizontal):
			best_distance = landing_distance
			best_horizontal = horizontal
			best = plan
	if best.is_empty():
		return {"eligible": false, "reason": "no_safe_visible_top", "snapshot": target_snapshot}
	best["snapshot"] = target_snapshot
	best["identity"] = "%d:%d" % [handle, pid]
	return best


## Computes the closest safe takeoff/landing pair for two visible top segments.
static func plan_between(source: WindowPlatform, target: WindowPlatform, preferred_foot_x: float) -> Dictionary:
	if source == null or target == null:
		return {"eligible": false, "reason": "missing_platform"}
	var rise := float(source.top_edge.position.y - target.top_edge.position.y)
	if rise < MIN_RISE_PX or rise > MAX_RISE_PX:
		return {"eligible": false, "reason": "rise_out_of_range", "rise_px": rise}
	var source_left := float(source.segment_left()) + SOURCE_SAFE_MARGIN_PX
	var source_right := float(source.segment_right()) - SOURCE_SAFE_MARGIN_PX
	var target_left := float(target.segment_left()) + TARGET_SAFE_MARGIN_PX
	var target_right := float(target.segment_right()) - TARGET_SAFE_MARGIN_PX
	if source_right <= source_left or target_right <= target_left:
		return {"eligible": false, "reason": "segment_too_narrow"}

	var takeoff_x := 0.0
	var landing_x := 0.0
	var overlap_left := maxf(source_left, target_left)
	var overlap_right := minf(source_right, target_right)
	if overlap_right >= overlap_left:
		landing_x = clampf(preferred_foot_x, overlap_left, overlap_right)
		takeoff_x = landing_x
	elif source_right < target_left:
		takeoff_x = source_right
		landing_x = target_left
	else:
		takeoff_x = source_left
		landing_x = target_right
	var horizontal := absf(landing_x - takeoff_x)
	if horizontal > MAX_HORIZONTAL_PX:
		return {"eligible": false, "reason": "too_far", "horizontal_px": horizontal, "rise_px": rise}
	return {
		"eligible": true,
		"reason": "",
		"source": source,
		"platform": target,
		"takeoff_x": takeoff_x,
		"landing_x": landing_x,
		"horizontal_px": horizontal,
		"rise_px": rise,
	}


## Missing native samples are ambiguous and receive a short grace; every explicit
## invalidation and an occluded visible top is authoritative immediately.
static func resolve_tracking(result: Dictionary, missing_since_ms: float, now_ms: float, grace_ms := TARGET_MISSING_GRACE_MS) -> Dictionary:
	if bool(result.get("lost", false)):
		var reason := str(result.get("reason", "missing"))
		if reason == "missing":
			var since := now_ms if missing_since_ms < 0.0 else missing_since_ms
			return {
				"status": "failed" if now_ms - since >= grace_ms else "waiting",
				"reason": reason,
				"missing_since_ms": since,
			}
		return {"status": "failed", "reason": reason, "missing_since_ms": -1.0}
	if str(result.get("status", "")) == "occluded":
		return {"status": "failed", "reason": "occluded", "missing_since_ms": -1.0}
	return {"status": "valid", "reason": "", "missing_since_ms": -1.0}


## Swept landing in the pet-window coordinate space. Unlike the legacy point-X
## test this interpolates horizontal contact at the exact crossed plane, so a long
## frame cannot tunnel through a narrow platform while descending diagonally.
static func swept_platform_contact(previous: Vector2, current: Vector2, planes: Array, required_handle := 0, required_pid := 0) -> Dictionary:
	var dy := current.y - previous.y
	if dy < 0.0:
		return {}
	var best: Dictionary = {}
	var best_t := INF
	for value in planes:
		if not value is Dictionary:
			continue
		var plane := value as Dictionary
		if required_handle != 0 and int(plane.get("handle", 0)) != required_handle:
			continue
		if required_pid != 0 and int(plane.get("process_id", 0)) != required_pid:
			continue
		var plane_y := float(plane.get("y", 0.0))
		var t := 0.0
		if absf(dy) <= 0.0001:
			if absf(plane_y - previous.y) > 0.5:
				continue
		else:
			t = (plane_y - previous.y) / dy
			if t < 0.0 or t > 1.0:
				continue
		var contact_x := lerpf(previous.x, current.x, t)
		if contact_x < float(plane.get("left", 0.0)) or contact_x > float(plane.get("right", 0.0)):
			continue
		if t < best_t:
			best_t = t
			best = plane.duplicate(true)
			best["contact_x"] = contact_x
			best["contact_t"] = t
	return best
