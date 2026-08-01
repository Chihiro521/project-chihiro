class_name WindowPlatformService
extends RefCounted

const WindowPlatformData = preload("res://scripts/platform/window_platform.gd")

const DEFAULT_MINIMUM_WIDTH := 160
const DEFAULT_MAX_SOURCE_WINDOWS := 12
const DEFAULT_TELEPORT_DISTANCE := 300.0

const SHELL_CLASSES := {
	"progman": true,
	"workerw": true,
	"shell_traywnd": true,
	"shell_secondarytraywnd": true,
}

var minimum_width := DEFAULT_MINIMUM_WIDTH
var maximum_source_windows := DEFAULT_MAX_SOURCE_WINDOWS
var teleport_distance := DEFAULT_TELEPORT_DISTANCE
var capture_titles := true

var _native_bridge: Variant = null
var _self_process_id := -1
var _last_snapshots: Array = []
var _last_platforms: Array[WindowPlatform] = []


func _init(native_bridge: Variant = null) -> void:
	set_native_bridge(native_bridge if native_bridge != null else _create_native_bridge())


func set_native_bridge(native_bridge: Variant) -> void:
	_native_bridge = native_bridge
	_self_process_id = -1
	if _native_bridge != null and _native_bridge.has_method("get_current_process_id"):
		_self_process_id = int(_native_bridge.call("get_current_process_id"))


func native_available() -> bool:
	return _native_bridge != null


func enumerate_snapshots(max_count := 0) -> Array:
	if _native_bridge == null or not _native_bridge.has_method("enumerate_windows"):
		return []
	var result: Variant = _native_bridge.call("enumerate_windows", maxi(0, max_count), capture_titles)
	return result if result is Array else []


func refresh() -> Array[WindowPlatform]:
	_last_snapshots = enumerate_snapshots(maximum_source_windows)
	_last_platforms = build_platforms(
		_last_snapshots,
		_self_process_id,
		minimum_width,
		maximum_source_windows,
	)
	return _last_platforms.duplicate()


func last_platforms() -> Array[WindowPlatform]:
	return _last_platforms.duplicate()

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
) -> Array[WindowPlatform]:
	var windows := _normalize_occluding_snapshots(snapshots, self_pid)
	windows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("z_order", 0)) < int(b.get("z_order", 0))
	)

	var result: Array[WindowPlatform] = []
	var emitted_sources := 0
	for index in range(windows.size()):
		var snapshot: Dictionary = windows[index]
		if not is_snapshot_eligible(snapshot, self_pid):
			continue
		if bool(snapshot.get("maximized", false)) and not include_maximized:
			continue
		if max_source_windows > 0 and emitted_sources >= max_source_windows:
			break
		var rect := WindowPlatformData.rect_from_value(snapshot.get("rect", Rect2i()))
		var intervals: Array[Vector2i] = [Vector2i(rect.position.x, rect.position.x + rect.size.x)]
		for occluder_index in range(index):
			var occluder: Dictionary = windows[occluder_index]
			var occluder_rect := WindowPlatformData.rect_from_value(occluder.get("rect", Rect2i()))
			if not _covers_y(occluder_rect, rect.position.y):
				continue
			intervals = _subtract_interval(
				intervals,
				occluder_rect.position.x,
				occluder_rect.position.x + occluder_rect.size.x,
			)
			if intervals.is_empty():
				break
		var emitted := false
		for interval in intervals:
			if interval.y - interval.x < maxi(1, min_width):
				continue
			result.append(WindowPlatformData.from_snapshot(snapshot, interval.x, interval.y))
			emitted = true
		if emitted:
			emitted_sources += 1
	return result


static func is_snapshot_eligible(snapshot: Dictionary, self_pid := -1) -> bool:
	if not is_foreground_snapshot_valid(snapshot, self_pid):
		return false
	if bool(snapshot.get("tool_window", false)) or int(snapshot.get("owner_handle", 0)) != 0:
		return false
	return true

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
## than `teleport_distance` is treated as platform loss instead of normal motion.
func track_platform(current: WindowPlatform, snapshots: Variant = null, standing_x: float = NAN) -> Dictionary:
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
	if Vector2(delta).length() > teleport_distance:
		return _lost_result("teleported", matching_snapshot, delta)

	var candidates := build_platforms(
		source_snapshots,
		_self_process_id,
		minimum_width,
		maximum_source_windows,
	)
	var same_window: Array[WindowPlatform] = []
	for candidate in candidates:
		if candidate.handle == current.handle:
			same_window.append(candidate)
	if same_window.is_empty():
		return _lost_result("top_edge_unavailable", matching_snapshot, delta)

	var expected_x := (standing_x if is_finite(standing_x) else current.center().x) + delta.x
	var selected: WindowPlatform = null
	for candidate in same_window:
		if candidate.contains_x(expected_x):
			selected = candidate
			break
	if selected == null:
		return _lost_result("standing_point_occluded", matching_snapshot, delta)
	var changed := delta != Vector2i.ZERO or next_rect.size != current.rect.size or selected.top_edge != current.top_edge
	return {
		"status": "moved" if changed else "stable",
		"lost": false,
		"reason": "",
		"delta": delta,
		"platform": selected,
		"snapshot": matching_snapshot,
	}


## Deterministically selects the closest different source window. Vertical
## separation is weighted so nearby ledges are preferred over distant rows.
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


static func _covers_y(rect: Rect2i, y: int) -> bool:
	return rect.position.y <= y and rect.position.y + rect.size.y > y


static func _subtract_interval(intervals: Array[Vector2i], cut_left: int, cut_right: int) -> Array[Vector2i]:
	if cut_right <= cut_left:
		return intervals
	var result: Array[Vector2i] = []
	for interval in intervals:
		if cut_right <= interval.x or cut_left >= interval.y:
			result.append(interval)
			continue
		if cut_left > interval.x:
			result.append(Vector2i(interval.x, mini(cut_left, interval.y)))
		if cut_right < interval.y:
			result.append(Vector2i(maxi(cut_right, interval.x), interval.y))
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
