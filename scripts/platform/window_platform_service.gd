class_name WindowPlatformService
extends RefCounted

const WindowPlatformData = preload("res://scripts/platform/window_platform.gd")
const WindowBodyData = preload("res://scripts/platform/window_body.gd")
const ManualControlModelScript = preload("res://scripts/core/manual_control_model.gd")

const DEFAULT_MINIMUM_WIDTH := 160
const DEFAULT_MAX_SOURCE_WINDOWS := 12
## Native enumeration collects MORE windows than the source cap: the native bridge
## only skips invisible/shell/own-process/zero-size windows, so tool and owner
## windows still consume slots and would crowd real windows out of a tight cap.
## `maximum_source_windows` stays the true collision-source cap in the occlusion
## pass; this wider raw cap guarantees that many ineligible-on-top windows cannot
## starve the visible ones behind them.
const NATIVE_ENUMERATION_CAP := 64
## Teleport detection thresholds come from the ONE source of truth — the model's
## TELEPORT_MIN_PX / TELEPORT_MIN_SPEED_PX_S — so riding and manual standing can
## never drift apart on what counts as a teleport.
const DEFAULT_TELEPORT_DISTANCE := ManualControlModelScript.TELEPORT_MIN_PX
## Speed (px/s) beyond which a same-window rect change is a genuine teleport
## instead of a drag. Windows report their rect asynchronously (DWM composition)
## and frame hitches stretch the gap between tracking ticks, so a fixed per-tick
## distance drops riders during perfectly continuous fast drags. Any speed a
## human can drag lands far below this; an instant reposition (handle recycled,
## programmatic jump) exceeds it.
const DEFAULT_TELEPORT_SPEED_PX_PER_SEC := ManualControlModelScript.TELEPORT_MIN_SPEED_PX_S
const DEFAULT_MAX_BODY_AREA_RATIO := 0.7

const SHELL_CLASSES := {
	"progman": true,
	"workerw": true,
	"shell_traywnd": true,
	"shell_secondarytraywnd": true,
}

var minimum_width := DEFAULT_MINIMUM_WIDTH
var maximum_source_windows := DEFAULT_MAX_SOURCE_WINDOWS
var teleport_distance := DEFAULT_TELEPORT_DISTANCE
var teleport_speed_px_per_sec := DEFAULT_TELEPORT_SPEED_PX_PER_SEC
var max_body_area_ratio := DEFAULT_MAX_BODY_AREA_RATIO
var capture_titles := true

var _native_bridge: Variant = null
var _self_process_id := -1
var _last_snapshots: Array = []
var _last_platforms: Array[WindowPlatform] = []
var _last_bodies: Array[WindowBody] = []
var _work_area := Rect2i()
var _collision_enabled := true


func _init(native_bridge: Variant = null) -> void:
	set_native_bridge(native_bridge if native_bridge != null else _create_native_bridge())


func set_native_bridge(native_bridge: Variant) -> void:
	_native_bridge = native_bridge
	_self_process_id = -1
	if _native_bridge != null and _native_bridge.has_method("get_current_process_id"):
		_self_process_id = int(_native_bridge.call("get_current_process_id"))


func native_available() -> bool:
	return _native_bridge != null


func native_bridge() -> Variant:
	return _native_bridge


func enumerate_snapshots(max_count := 0) -> Array:
	if _native_bridge == null or not _native_bridge.has_method("enumerate_windows"):
		return []
	var result: Variant = _native_bridge.call("enumerate_windows", maxi(0, max_count), capture_titles)
	return result if result is Array else []


func refresh() -> Array[WindowPlatform]:
	_last_snapshots = enumerate_snapshots(NATIVE_ENUMERATION_CAP)
	_rebuild_from_snapshots()
	return _last_platforms.duplicate()


func refresh_bodies() -> Array[WindowBody]:
	if _last_snapshots.is_empty():
		_last_snapshots = enumerate_snapshots(NATIVE_ENUMERATION_CAP)
	_rebuild_from_snapshots()
	return _last_bodies.duplicate()


func last_platforms() -> Array[WindowPlatform]:
	return _last_platforms.duplicate()


func last_bodies() -> Array[WindowBody]:
	return _last_bodies.duplicate()


func set_collision_enabled(value: bool) -> void:
	_collision_enabled = value


func set_work_area(value: Rect2i) -> void:
	_work_area = value


## One refresh rebuilds both platforms and solid bodies from the same fragment
## pass, so a window that disappears from the platforms also disappears from the
## collision world (and vice versa).
func _rebuild_from_snapshots() -> void:
	var entries := compute_visible_fragments(
		_last_snapshots,
		_self_process_id,
		minimum_width,
		maximum_source_windows,
		false,
		max_body_area_ratio if _work_area.size.x > 0 and _work_area.size.y > 0 else 0.0,
		_work_area,
	)
	_last_platforms = _platforms_from_entries(entries)
	_last_bodies = _bodies_from_entries(entries) if _collision_enabled else []

func foreground_snapshot() -> Dictionary:
	if _native_bridge != null and _native_bridge.has_method("get_foreground_window_snapshot"):
		var foreground: Variant = _native_bridge.call("get_foreground_window_snapshot", capture_titles)
		if foreground is Dictionary and is_foreground_snapshot_valid(foreground, _self_process_id):
			return (foreground as Dictionary).duplicate(true)
	for value in _last_snapshots:
		if value is Dictionary and is_foreground_snapshot_valid(value, _self_process_id):
			return (value as Dictionary).duplicate(true)
	return {}


## Produces visible top-edge segments from front-to-back snapshots.
## Lower z_order values are in front. Higher windows subtract from lower ones.
static func build_platforms(
	snapshots: Array,
	self_pid := -1,
	min_width := DEFAULT_MINIMUM_WIDTH,
	max_source_windows := DEFAULT_MAX_SOURCE_WINDOWS,
	include_maximized := false,
	max_area_ratio := 0.0,
	work_area := Rect2i(),
) -> Array[WindowPlatform]:
	return _platforms_from_entries(
		compute_visible_fragments(snapshots, self_pid, min_width, max_source_windows, include_maximized, max_area_ratio, work_area)
	)


## Solid collision bodies from the same occlusion pass as build_platforms. When
## `collision_enabled` is false no bodies are produced; the platform pass is
## unaffected (independent toggle).
static func build_bodies(
	snapshots: Array,
	self_pid := -1,
	min_width := DEFAULT_MINIMUM_WIDTH,
	max_source_windows := DEFAULT_MAX_SOURCE_WINDOWS,
	work_area := Rect2i(),
	max_area_ratio := 0.0,
	collision_enabled := true,
) -> Array[WindowBody]:
	if not collision_enabled:
		return []
	var entries := compute_visible_fragments(snapshots, self_pid, min_width, max_source_windows, false, max_area_ratio, work_area)
	return _bodies_from_entries(entries)


## One occlusion pass that produces the visible 2D fragments of every eligible
## source window. The same entries feed both the existing top-edge platforms and
## the new solid collision bodies, so a window's fragments ARE its volume.
## Fully occluded windows yield no fragments and therefore no platform or body.
static func compute_visible_fragments(
	snapshots: Array,
	self_pid := -1,
	min_width := DEFAULT_MINIMUM_WIDTH,
	max_source_windows := DEFAULT_MAX_SOURCE_WINDOWS,
	include_maximized := false,
	max_area_ratio := 0.0,
	work_area := Rect2i(),
) -> Array[Dictionary]:
	var windows := _normalize_occluding_snapshots(snapshots, self_pid)
	windows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("z_order", 0)) < int(b.get("z_order", 0))
	)
	var cap_area := 0
	if max_area_ratio > 0.0 and work_area.size.x > 0 and work_area.size.y > 0:
		cap_area = int(work_area.size.x) * int(work_area.size.y)

	var entries: Array[Dictionary] = []
	var emitted_sources := 0
	for index in range(windows.size()):
		var snapshot: Dictionary = windows[index]
		if not is_snapshot_eligible(snapshot, self_pid):
			continue
		if bool(snapshot.get("maximized", false)) and not include_maximized:
			continue
		var rect := WindowPlatformData.rect_from_value(snapshot.get("rect", Rect2i()))
		if cap_area > 0 and int(rect.size.x) * int(rect.size.y) > int(float(cap_area) * max_area_ratio):
			continue
		if max_source_windows > 0 and emitted_sources >= max_source_windows:
			break
		var fragments: Array[Rect2i] = [rect]
		for occluder_index in range(index):
			var occluder: Dictionary = windows[occluder_index]
			var occluder_rect := WindowPlatformData.rect_from_value(occluder.get("rect", Rect2i()))
			fragments = _subtract_rect(fragments, occluder_rect, maxi(1, min_width))
			if fragments.is_empty():
				break
		var top_segments: Array[Rect2i] = []
		for fragment in fragments:
			if fragment.position.y == rect.position.y:
				top_segments.append(fragment)
		if not top_segments.is_empty():
			emitted_sources += 1
		entries.append({"snapshot": snapshot, "fragments": fragments, "top_segments": top_segments})
	return entries


static func _platforms_from_entries(entries: Array) -> Array[WindowPlatform]:
	var result: Array[WindowPlatform] = []
	for entry in entries:
		if not entry is Dictionary:
			continue
		var snapshot: Dictionary = (entry as Dictionary).get("snapshot", {})
		for segment in (entry as Dictionary).get("top_segments", []):
			if not segment is Rect2i:
				continue
			result.append(WindowPlatformData.from_snapshot(snapshot, segment.position.x, segment.end.x))
	return result


static func _bodies_from_entries(entries: Array) -> Array[WindowBody]:
	var result: Array[WindowBody] = []
	for entry in entries:
		if not entry is Dictionary:
			continue
		var fragments: Array = (entry as Dictionary).get("fragments", [])
		if fragments.is_empty():
			continue
		result.append(WindowBodyData.from_snapshot(
			(entry as Dictionary).get("snapshot", {}),
			fragments,
			(entry as Dictionary).get("top_segments", []),
		))
	return result


## 2D slab subtraction: removes `cut` from every fragment, splitting it into the
## standard top / bottom / left / right bands. Slivers narrower than `min_width`
## (or with no height) are dropped so the body pass stays in lock-step with the
## platform pass, which discards the same top-edge intervals.
static func _subtract_rect(fragments: Array[Rect2i], cut: Rect2i, min_width: int) -> Array[Rect2i]:
	if cut.size.x <= 0 or cut.size.y <= 0:
		return fragments
	var result: Array[Rect2i] = []
	for fragment in fragments:
		if (
			cut.end.x <= fragment.position.x
			or cut.position.x >= fragment.end.x
			or cut.end.y <= fragment.position.y
			or cut.position.y >= fragment.end.y
		):
			result.append(fragment)
			continue
		if cut.position.y > fragment.position.y:
			result.append(Rect2i(fragment.position.x, fragment.position.y, fragment.size.x, cut.position.y - fragment.position.y))
		if cut.end.y < fragment.end.y:
			result.append(Rect2i(fragment.position.x, cut.end.y, fragment.size.x, fragment.end.y - cut.end.y))
		if cut.position.x > fragment.position.x:
			var band_top := maxi(fragment.position.y, cut.position.y)
			var band_bottom := mini(fragment.end.y, cut.end.y)
			if band_bottom > band_top:
				result.append(Rect2i(fragment.position.x, band_top, cut.position.x - fragment.position.x, band_bottom - band_top))
		if cut.end.x < fragment.end.x:
			var band_top := maxi(fragment.position.y, cut.position.y)
			var band_bottom := mini(fragment.end.y, cut.end.y)
			if band_bottom > band_top:
				result.append(Rect2i(cut.end.x, band_top, fragment.end.x - cut.end.x, band_bottom - band_top))
	var filtered: Array[Rect2i] = []
	for fragment in result:
		if fragment.size.x < min_width or fragment.size.y < 1:
			continue
		filtered.append(fragment)
	return filtered


static func is_snapshot_eligible(snapshot: Dictionary, self_pid := -1) -> bool:
	if not is_foreground_snapshot_valid(snapshot, self_pid):
		return false
	if bool(snapshot.get("tool_window", false)) or int(snapshot.get("owner_handle", 0)) != 0:
		return false
	return true

## Filters a standable-plane list down to windows that have existed for at least
## `min_age_ms` (a transient popup's top is never stood on). Windows absent from
## `first_seen_ms` (never observed) are treated as brand new and excluded, so the
## gate is conservative. Purely a standing-surface rule — occlusion and walls are
## NOT gated (visible rendering always wins). Static so it is unit-testable.
static func gate_transient_planes(planes: Array, first_seen_ms: Dictionary, now_ms: float, min_age_ms: float) -> Array:
	var result: Array = []
	for value in planes:
		if not value is Dictionary:
			continue
		var plane := value as Dictionary
		var handle := int(plane.get("handle", 0))
		if not first_seen_ms.has(handle):
			continue
		if now_ms - float(first_seen_ms[handle]) < min_age_ms:
			continue
		result.append(plane)
	return result


static func is_foreground_snapshot_valid(snapshot: Dictionary, self_pid := -1) -> bool:
	if int(snapshot.get("handle", 0)) == 0:
		return false
	if self_pid >= 0 and int(snapshot.get("process_id", -2)) == self_pid:
		return false
	if not bool(snapshot.get("visible", true)):
		return false
	if bool(snapshot.get("minimized", false)) or bool(snapshot.get("cloaked", false)):
		return false
	if bool(snapshot.get("shell_window", false)):
		return false
	if SHELL_CLASSES.has(str(snapshot.get("class_name", "")).to_lower()):
		return false
	var rect := WindowPlatformData.rect_from_value(snapshot.get("rect", Rect2i()))
	return rect.size.x > 0 and rect.size.y > 0


## Tracks a ridden platform against a fresh snapshot set. A single update farther
## than `teleport_distance` at a speed beyond any human drag is treated as platform
## loss instead of normal motion. `elapsed_ms` (wall-clock gap since the previous
## tracking tick) scales the threshold by speed: a continuous drag covers a lot of
## pixels across a hitched/stale-rect gap and must keep following, while an instant
## reposition still reads as a teleport. With no timing info (first tick after a
## mount) the pet follows rather than dropping on distance alone.
##
## While the window itself remains valid (handle found, eligible, not maximized),
## occlusion of the top edge at the standing point makes the rider fall: the foot
## is not on any visible segment, so the riding semantic is "stand on what you can
## see". The caller applies its own grace window before the drop so a transient
## mid-drag occlusion (cached occluder rects stale) does not eject the rider
## instantly; the occlusion pass re-runs every tick, so once the overlap clears the
## pet is back on a real segment before the grace expires.
func track_platform(current: WindowPlatform, snapshots: Variant = null, standing_x: float = NAN, elapsed_ms: float = -1.0) -> Dictionary:
	if current == null:
		return _lost_result("invalid_platform")
	var source_snapshots: Array = _snapshots_for_tracking(current.handle) if snapshots == null else snapshots
	var matching_snapshot: Dictionary = {}
	for value in source_snapshots:
		if (
			value is Dictionary
			and int((value as Dictionary).get("handle", 0)) == current.handle
			and int((value as Dictionary).get("process_id", -1)) == current.process_id
		):
			matching_snapshot = value
			break
	if matching_snapshot.is_empty():
		return _lost_result("missing")
	if not is_snapshot_eligible(matching_snapshot, _self_process_id):
		return _lost_result("filtered", matching_snapshot)
	if bool(matching_snapshot.get("maximized", false)):
		return _lost_result("maximized", matching_snapshot)

	var next_rect := WindowPlatformData.rect_from_value(matching_snapshot.get("rect", Rect2i()))
	var delta := next_rect.position - current.rect.position
	var magnitude := Vector2(delta).length()
	# Teleport detection is speed-aware: a continuous drag covers a lot of pixels
	# across a hitched/stale-rect tick and must keep following, while an instant
	# reposition (handle recycled, programmatic jump) exceeds any human drag speed.
	# With no timing info (the first tick after a mount, when the rect may be
	# catching up from a stale snapshot) the pet follows instead of dropping.
	var teleported := false
	if elapsed_ms > 0.0:
		var seconds := maxf(elapsed_ms / 1000.0, 1.0 / 1000.0)
		teleported = magnitude > teleport_distance and magnitude > teleport_speed_px_per_sec * seconds
	if teleported:
		return _lost_result("teleported", matching_snapshot, delta)

	var candidates := build_platforms(
		source_snapshots,
		_self_process_id,
		minimum_width,
		maximum_source_windows,
		false,
		max_body_area_ratio if _work_area.size.x > 0 and _work_area.size.y > 0 else 0.0,
		_work_area,
	)
	var expected_x := (standing_x if is_finite(standing_x) else current.center().x) + delta.x
	var selected: WindowPlatform = null
	for candidate in candidates:
		if candidate.handle == current.handle and candidate.contains_x(expected_x):
			selected = candidate
			break
	if selected == null:
		# The ridden window still exists but its top edge at the standing point is
		# covered by a front window: the foot is on no visible segment, so under the
		# visible-geometry semantics the rider must drop. Return the current platform
		# (no motion, no y-pin) with an "occluded" status; the caller's grace window
		# decides the drop so a transient mid-drag occlusion (cached occluder rects
		# stale) does not eject the rider instantly.
		return {
			"status": "occluded",
			"lost": false,
			"reason": "occluded",
			"delta": delta,
			"platform": current,
			"snapshot": matching_snapshot,
		}
	var changed := delta != Vector2i.ZERO or next_rect.size != current.rect.size or selected.top_edge != current.top_edge
	return {
		"status": "moved" if changed else "stable",
		"lost": false,
		"reason": "",
		"delta": delta,
		"platform": selected,
		"snapshot": matching_snapshot,
	}


## Per-frame visible top-edge segments for a standing window: the window's LIVE
## rect (native single-window query) minus the cached FRONT occluders from the last
## full refresh. The refresh-built segments only move at the window-refresh cadence,
## so during a drag the live rect is the authoritative edge; subtracting the cached
## front occluders keeps the standing point occlusion-aware frame by frame (an
## occluded top segment is not standable, matching the riding semantic). Returns []
## when the window is absent/not eligible/maximized or its top edge is fully
## covered. Planes carry the (handle, process_id) identity in the model's foot space
## (window top minus the foot offset), matching standable_planes().
func live_top_segment_planes(handle: int, pid: int, foot_offset_y: float, snapshots: Variant = null) -> Array:
	var source_snapshots: Array = _snapshots_for_tracking(handle) if snapshots == null else snapshots
	var matching_snapshot: Dictionary = {}
	for value in source_snapshots:
		if (
			value is Dictionary
			and int((value as Dictionary).get("handle", 0)) == handle
			and int((value as Dictionary).get("process_id", -1)) == pid
		):
			matching_snapshot = value
			break
	if matching_snapshot.is_empty():
		return []
	if not is_snapshot_eligible(matching_snapshot, _self_process_id):
		return []
	if bool(matching_snapshot.get("maximized", false)):
		return []
	var rect := WindowPlatformData.rect_from_value(matching_snapshot.get("rect", Rect2i()))
	var target_z := int(matching_snapshot.get("z_order", 0))
	var fragments: Array[Rect2i] = [rect]
	# Subtract the cached front occluders in the same slab pass the refresh uses
	# (lower z_order covers, front-to-back), dropping slivers below the min width so
	# the platform pass and the standing point stay in lock-step.
	for value in source_snapshots:
		if not value is Dictionary:
			continue
		var occluder := value as Dictionary
		if int(occluder.get("handle", 0)) == handle:
			continue
		if int(occluder.get("z_order", 0)) >= target_z:
			continue
		if not is_foreground_snapshot_valid(occluder, _self_process_id):
			continue
		fragments = _subtract_rect(fragments, WindowPlatformData.rect_from_value(occluder.get("rect", Rect2i())), maxi(1, minimum_width))
		if fragments.is_empty():
			break
	var planes: Array = []
	for fragment in fragments:
		if fragment.position.y != rect.position.y:
			continue
		planes.append({
			"left": float(fragment.position.x),
			"right": float(fragment.end.x),
			"y": float(rect.position.y) - foot_offset_y,
			"handle": handle,
			"process_id": pid,
		})
	return planes


## Horizontal displacement of the standing window's live rect center relative to the
## cached refresh rect center, i.e. whether the window is being dragged right now.
## Segment-center deltas are polluted by occlusion reshuffles, so the window rect
## itself is the reliable "moving" signal: a nonzero delta gates the model's perch
## continuity during a drag, a zero delta under static occlusion means the foot is
## really uncovered.
func live_rect_delta_x(handle: int, snapshots: Variant = null) -> float:
	var source_snapshots: Array = _snapshots_for_tracking(handle) if snapshots == null else snapshots
	var live_rect := Rect2i()
	var found := false
	for value in source_snapshots:
		if not value is Dictionary:
			continue
		if int((value as Dictionary).get("handle", 0)) != handle:
			continue
		live_rect = WindowPlatformData.rect_from_value((value as Dictionary).get("rect", Rect2i()))
		found = true
		break
	if not found:
		return 0.0
	var cached_rect := Rect2i()
	var cached_found := false
	for value in _last_snapshots:
		if not value is Dictionary:
			continue
		if int((value as Dictionary).get("handle", 0)) != handle:
			continue
		cached_rect = WindowPlatformData.rect_from_value((value as Dictionary).get("rect", Rect2i()))
		cached_found = true
		break
	if not cached_found:
		# No cached reference for this window (live-only, or filtered from the last
		# refresh). It is NOT being dragged — a zero baseline would otherwise read the
		# live center (hundreds of px) as motion, the model would set window_moving and
		# the drag-hold would pin the pet mid-air forever instead of letting it fall.
		return 0.0
	return float(live_rect.get_center().x) - float(cached_rect.get_center().x)


## Vertical displacement of the standing window's live rect center relative to the
## cached refresh rect center, mirroring live_rect_delta_x for the Y axis. During a
## VERTICAL drag the X center does not move (live_rect_delta_x stays ~0), so without
## this the model would read an upward-dragged window as STATIC and commit to the
## occlusion-grace fall the moment the top segment is transiently sliced (a stale
## front occluder or a live-query hiccup) — the pet gets "pushed off" (被挤下去).
## Same no-cached-reference fallback as the X axis: no baseline means not moving.
func live_rect_delta_y(handle: int, snapshots: Variant = null) -> float:
	var source_snapshots: Array = _snapshots_for_tracking(handle) if snapshots == null else snapshots
	var live_rect := Rect2i()
	var found := false
	for value in source_snapshots:
		if not value is Dictionary:
			continue
		if int((value as Dictionary).get("handle", 0)) != handle:
			continue
		live_rect = WindowPlatformData.rect_from_value((value as Dictionary).get("rect", Rect2i()))
		found = true
		break
	if not found:
		return 0.0
	var cached_rect := Rect2i()
	var cached_found := false
	for value in _last_snapshots:
		if not value is Dictionary:
			continue
		if int((value as Dictionary).get("handle", 0)) != handle:
			continue
		cached_rect = WindowPlatformData.rect_from_value((value as Dictionary).get("rect", Rect2i()))
		cached_found = true
		break
	if not cached_found:
		return 0.0
	return float(live_rect.get_center().y) - float(cached_rect.get_center().y)


## Deterministically selects the closest different source window. Vertical
## separation is weighted so nearby ledges are preferred over distant rows.
## Per-frame wall edge for a window being climbed, mirroring the fragment edge
## semantics (side == the motion direction the edge blocks) but from the window's
## live rect rather than the refresh-built collision world. The host feeds this to
## the climb model so a dragged window carries the pet smoothly; the next refresh
## corrects any occlusion-subtracted difference. Returns {} when the window is
## absent, not eligible, or maximized.
func live_wall_edge(handle: int, pid: int, side: int, snapshots: Variant = null) -> Dictionary:
	var source_snapshots: Array = _snapshots_for_tracking(handle) if snapshots == null else snapshots
	var matching_snapshot: Dictionary = {}
	for value in source_snapshots:
		if (
			value is Dictionary
			and int((value as Dictionary).get("handle", 0)) == handle
			and int((value as Dictionary).get("process_id", -1)) == pid
		):
			matching_snapshot = value
			break
	if matching_snapshot.is_empty():
		return {}
	if not is_snapshot_eligible(matching_snapshot, _self_process_id):
		return {}
	if bool(matching_snapshot.get("maximized", false)):
		return {}
	var rect := WindowPlatformData.rect_from_value(matching_snapshot.get("rect", Rect2i()))
	# Same edge convention as fragment_wall_edges: side=+1 is the left face (solid
	# body on +x, x = rect.position.x) and side=-1 is the right face (solid body on
	# -x, x = rect.end.x). Feeding the opposite edge parks the pet on the far side.
	return {
		"x": float(rect.position.x) if side == 1 else float(rect.end.x),
		"top_y": float(rect.position.y),
		"bottom_y": float(rect.end.y),
		"side": side,
		"handle": handle,
		"process_id": pid,
	}


static func choose_nearby_platform(
	current: WindowPlatform,
	candidates: Array[WindowPlatform],
	max_distance := 900.0,
	max_vertical_distance := 480.0,
) -> Variant:
	if current == null:
		return null
	var selected: WindowPlatform = null
	var best_score := INF
	for candidate in candidates:
		if candidate == null or candidate.handle == current.handle:
			continue
		var offset := candidate.center() - current.center()
		if absf(offset.y) > max_vertical_distance or offset.length() > max_distance:
			continue
		var score := offset.length() + absf(offset.y) * 0.35 + maxf(0.0, candidate.z_order) * 0.001
		if score < best_score:
			best_score = score
			selected = candidate
	return selected


## Refreshes only the ridden HWND between the slower full enumerations. The
## cached z-order remains authoritative until the next `refresh()` call.
func _snapshots_for_tracking(handle: int) -> Array:
	if _native_bridge == null or not _native_bridge.has_method("get_window_snapshot"):
		return enumerate_snapshots(0)
	var value: Variant = _native_bridge.call("get_window_snapshot", handle, capture_titles)
	if not value is Dictionary or (value as Dictionary).is_empty():
		return []
	var fresh := (value as Dictionary).duplicate()
	var snapshots := _last_snapshots.duplicate(true)
	for index in range(snapshots.size()):
		if not snapshots[index] is Dictionary:
			continue
		var cached := snapshots[index] as Dictionary
		if int(cached.get("handle", 0)) != handle:
			continue
		fresh["z_order"] = int(cached.get("z_order", index))
		snapshots[index] = fresh
		return snapshots
	if not fresh.has("z_order"):
		fresh["z_order"] = 0
	snapshots.append(fresh)
	return snapshots


static func _normalize_occluding_snapshots(snapshots: Array, self_pid: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(snapshots.size()):
		var value: Variant = snapshots[index]
		if not value is Dictionary:
			continue
		var snapshot := (value as Dictionary).duplicate()
		if not snapshot.has("z_order"):
			snapshot["z_order"] = index
		if is_foreground_snapshot_valid(snapshot, self_pid):
			result.append(snapshot)
	return result


func _lost_result(reason: String, snapshot := {}, delta := Vector2i.ZERO) -> Dictionary:
	return {
		"status": "lost",
		"lost": true,
		"reason": reason,
		"delta": delta,
		"platform": null,
		"snapshot": snapshot,
	}


static func _create_native_bridge() -> Variant:
	if not ClassDB.class_exists("WindowsWindowEnumerator"):
		return null
	return ClassDB.instantiate("WindowsWindowEnumerator")
