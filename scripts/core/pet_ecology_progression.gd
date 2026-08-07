class_name PetEcologyProgression
extends RefCounted

const MAX_VALUE := 100.0
const DEFAULT_EVENT_LIMIT := 50
const DEFAULT_CREDIT_WINDOW_MS := 600000

var _profile: Dictionary = {}
var _habits_by_id: Dictionary = {}
var _discoveries_by_id: Dictionary = {}
var _familiarity := 0.0
var _habits: Dictionary = {}
var _discoveries: Dictionary = {}
var _goal_stats: Dictionary = {}
var _request_stats := {"accepted": 0, "deferred": 0, "refused": 0, "completed": 0}
var _recent_events: Array[Dictionary] = []
var _session_credits: Dictionary = {}


func _init(profile: Dictionary = {}) -> void:
	configure(profile)


func configure(profile: Dictionary) -> void:
	_profile = profile.duplicate(true)
	_habits_by_id.clear()
	_discoveries_by_id.clear()
	for value in _profile.get("habits", []):
		if value is Dictionary:
			var habit_id := str(value.get("id", ""))
			if not habit_id.is_empty():
				_habits_by_id[habit_id] = value.duplicate(true)
	for value in _profile.get("discoveries", []):
		if value is Dictionary:
			var discovery_id := str(value.get("id", ""))
			if not discovery_id.is_empty():
				_discoveries_by_id[discovery_id] = value.duplicate(true)


func restore_persistent(state: Dictionary) -> void:
	_familiarity = clampf(float(state.get("habitat_familiarity", 0.0)), 0.0, MAX_VALUE)
	_habits = _normalize_habits(state.get("habits", {}))
	_discoveries = _normalize_discoveries(state.get("discoveries", {}))
	_goal_stats = _normalize_nonnegative_counts(state.get("goal_stats", {}), _goal_ids())
	_request_stats = _normalize_nonnegative_counts(state.get("request_stats", {}), ["accepted", "deferred", "refused", "completed"])
	_recent_events.clear()
	var source_events: Variant = state.get("recent_ecology_events", [])
	if source_events is Array:
		for value in source_events:
			if value is Dictionary:
				_recent_events.append(_safe_event(value))
	_trim_events()


func persistent_snapshot() -> Dictionary:
	return {
		"habitat_familiarity": _familiarity,
		"habits": _habits.duplicate(true),
		"discoveries": _discoveries.duplicate(true),
		"goal_stats": _goal_stats.duplicate(true),
		"request_stats": _request_stats.duplicate(true),
		"recent_ecology_events": _recent_events.duplicate(true),
	}


func familiarity() -> float:
	return _familiarity


func familiarity_tier() -> int:
	var thresholds := _float_array(_profile.get("progression", {}).get("familiarity_thresholds", [0, 20, 40, 60, 80]))
	var tier := 0
	for index in range(thresholds.size()):
		if _familiarity >= thresholds[index]:
			tier = index
	return tier


func record_goal(goal_id: String, context: Dictionary, now_unix: int, now_ms: int) -> Array[Dictionary]:
	var emitted: Array[Dictionary] = []
	var first_completion := int(_goal_stats.get(goal_id, 0)) == 0
	_goal_stats[goal_id] = int(_goal_stats.get(goal_id, 0)) + 1
	var progression: Dictionary = _profile.get("progression", {})
	var reward := float(progression.get("first_goal_familiarity", 1.0)) if first_completion else float(progression.get("repeat_goal_familiarity", 0.25))
	var credit_key := "goal:%s:%s:%s" % [goal_id, str(context.get("time_period", "")), str(context.get("app_category", ""))]
	if _claim_credit(credit_key, now_ms):
		var previous := _familiarity
		_familiarity = clampf(_familiarity + reward, 0.0, MAX_VALUE)
		if not is_equal_approx(previous, _familiarity):
			emitted.append(_progress_event("familiarity", goal_id, now_unix, {"from": previous, "to": _familiarity}))
	_append_event("goal_completed", goal_id, now_unix, context)
	emitted.append_array(_credit_habits(goal_id, context, now_unix, now_ms))
	emitted.append_array(observe_event("goal_completed", context.merged({"goal_id": goal_id}, true), now_unix, now_ms))
	return emitted


func observe_event(event_type: String, context: Dictionary, now_unix: int, now_ms: int) -> Array[Dictionary]:
	var emitted: Array[Dictionary] = []
	for discovery_id in _discoveries_by_id.keys():
		if _discoveries.has(discovery_id):
			continue
		var definition: Dictionary = _discoveries_by_id[discovery_id]
		if str(definition.get("event", "")) != event_type or not _matches_context(definition, context):
			continue
		_discoveries[discovery_id] = {"unlocked_unix": maxi(0, now_unix)}
		var reward := float(definition.get("familiarity_reward", _profile.get("progression", {}).get("discovery_familiarity", 2.0)))
		var previous := _familiarity
		_familiarity = clampf(_familiarity + reward, 0.0, MAX_VALUE)
		var event := _progress_event("discovery", str(discovery_id), now_unix, {
			"name": str(definition.get("name", discovery_id)),
			"familiarity_from": previous,
			"familiarity_to": _familiarity,
		})
		emitted.append(event)
		_append_event("discovery", str(discovery_id), now_unix, context)
	return emitted


func record_request(request_id: String, outcome: String, now_unix: int) -> Dictionary:
	var normalized := outcome if outcome in ["accepted", "deferred", "refused", "completed"] else "refused"
	_request_stats[normalized] = int(_request_stats.get(normalized, 0)) + 1
	_append_event("request_%s" % normalized, request_id, now_unix, {})
	return _progress_event("request", request_id, now_unix, {"outcome": normalized})


func habit_stages() -> Dictionary:
	var result := {}
	for habit_id in _habits_by_id.keys():
		var entry: Dictionary = _habits.get(habit_id, {})
		result[habit_id] = int(entry.get("stage", 0))
	return result


func habits_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition_value in _profile.get("habits", []):
		if not definition_value is Dictionary:
			continue
		var definition: Dictionary = definition_value
		var habit_id := str(definition.get("id", ""))
		var state: Dictionary = _habits.get(habit_id, {"count": 0, "stage": 0})
		result.append({
			"id": habit_id,
			"name": str(definition.get("name", habit_id)),
			"description": str(definition.get("description", "")),
			"count": int(state.get("count", 0)),
			"stage": int(state.get("stage", 0)),
			"next_threshold": _next_habit_threshold(int(state.get("count", 0))),
		})
	return result


func discoveries_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition_value in _profile.get("discoveries", []):
		if not definition_value is Dictionary:
			continue
		var definition: Dictionary = definition_value
		var discovery_id := str(definition.get("id", ""))
		var state: Dictionary = _discoveries.get(discovery_id, {})
		result.append({
			"id": discovery_id,
			"name": str(definition.get("name", discovery_id)),
			"description": str(definition.get("description", "")),
			"unlocked": not state.is_empty(),
			"unlocked_unix": int(state.get("unlocked_unix", 0)),
		})
	return result


func snapshot() -> Dictionary:
	return {
		"familiarity": _familiarity,
		"familiarity_tier": familiarity_tier(),
		"habits": habits_snapshot(),
		"habit_stages": habit_stages(),
		"discoveries": discoveries_snapshot(),
		"discovery_count": _discoveries.size(),
		"discovery_total": _discoveries_by_id.size(),
		"goal_stats": _goal_stats.duplicate(true),
		"request_stats": _request_stats.duplicate(true),
		"recent_events": _recent_events.duplicate(true),
	}


func _credit_habits(goal_id: String, context: Dictionary, now_unix: int, now_ms: int) -> Array[Dictionary]:
	var emitted: Array[Dictionary] = []
	for habit_id in _habits_by_id.keys():
		var definition: Dictionary = _habits_by_id[habit_id]
		if goal_id not in _string_array(definition.get("goal_ids", [])) or not _matches_context(definition, context):
			continue
		var credit_key := "habit:%s:%s:%s" % [habit_id, str(context.get("time_period", "")), str(context.get("app_category", ""))]
		if not _claim_credit(credit_key, now_ms):
			continue
		var state: Dictionary = _habits.get(habit_id, {"count": 0, "stage": 0, "last_credit_unix": 0})
		var previous_stage := int(state.get("stage", 0))
		state["count"] = int(state.get("count", 0)) + 1
		state["stage"] = _habit_stage(int(state.count))
		state["last_credit_unix"] = maxi(0, now_unix)
		_habits[habit_id] = state
		var event_kind := "habit_stage" if int(state.stage) > previous_stage else "habit_progress"
		emitted.append(_progress_event(event_kind, str(habit_id), now_unix, {
			"name": str(definition.get("name", habit_id)),
			"count": int(state.count),
			"stage": int(state.stage),
		}))
		_append_event(event_kind, str(habit_id), now_unix, context)
	return emitted


func _matches_context(definition: Dictionary, context: Dictionary) -> bool:
	for pair in [
		["goal_ids", "goal_id"],
		["time_periods", "time_period"],
		["app_categories", "app_category"],
		["request_ids", "request_id"],
	]:
		var allowed := _string_array(definition.get(str(pair[0]), []))
		if not allowed.is_empty() and str(context.get(str(pair[1]), "")) not in allowed:
			return false
	if definition.has("min_platform_count") and int(context.get("platform_count", 0)) < int(definition.min_platform_count):
		return false
	if bool(definition.get("requires_multi_monitor", false)) and int(context.get("screen_count", 1)) < 2:
		return false
	return true


func _claim_credit(key: String, now_ms: int) -> bool:
	var window := int(_profile.get("progression", {}).get("credit_window_ms", DEFAULT_CREDIT_WINDOW_MS))
	if now_ms - int(_session_credits.get(key, -window)) < window:
		return false
	_session_credits[key] = now_ms
	return true


func _habit_stage(count: int) -> int:
	var stage := 0
	for threshold in _profile.get("progression", {}).get("habit_stage_thresholds", [3, 8, 18]):
		if count >= int(threshold):
			stage += 1
	return stage


func _next_habit_threshold(count: int) -> int:
	for threshold in _profile.get("progression", {}).get("habit_stage_thresholds", [3, 8, 18]):
		if count < int(threshold):
			return int(threshold)
	return -1


func _append_event(kind: String, event_id: String, now_unix: int, context: Dictionary) -> void:
	_recent_events.append(_safe_event({
		"kind": kind,
		"id": event_id,
		"unix": maxi(0, now_unix),
		"time_period": str(context.get("time_period", "")),
		"app_category": str(context.get("app_category", "")),
		"goal_id": str(context.get("goal_id", "")),
		"request_id": str(context.get("request_id", "")),
	}))
	_trim_events()


func _trim_events() -> void:
	var limit := int(_profile.get("progression", {}).get("event_history_limit", DEFAULT_EVENT_LIMIT))
	while _recent_events.size() > maxi(1, limit):
		_recent_events.pop_front()


func _safe_event(value: Dictionary) -> Dictionary:
	return {
		"kind": str(value.get("kind", "")).left(64),
		"id": str(value.get("id", "")).left(96),
		"unix": maxi(0, int(value.get("unix", 0))),
		"time_period": str(value.get("time_period", "")).left(32),
		"app_category": str(value.get("app_category", "")).left(32),
		"goal_id": str(value.get("goal_id", "")).left(64),
		"request_id": str(value.get("request_id", "")).left(64),
	}


func _progress_event(kind: String, event_id: String, now_unix: int, details: Dictionary) -> Dictionary:
	return {"kind": kind, "id": event_id, "unix": maxi(0, now_unix), "details": details.duplicate(true)}


func _normalize_habits(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for habit_id in _habits_by_id.keys():
		var raw: Variant = source.get(habit_id, {})
		var entry: Dictionary = raw if raw is Dictionary else {}
		var count := maxi(0, int(entry.get("count", 0)))
		result[habit_id] = {
			"count": count,
			"stage": mini(_habit_stage(count), 3),
			"last_credit_unix": maxi(0, int(entry.get("last_credit_unix", 0))),
		}
	return result


func _normalize_discoveries(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for discovery_id in _discoveries_by_id.keys():
		if not source.has(discovery_id):
			continue
		var entry: Variant = source[discovery_id]
		if entry is Dictionary:
			result[discovery_id] = {"unlocked_unix": maxi(0, int(entry.get("unlocked_unix", 0)))}
		else:
			result[discovery_id] = {"unlocked_unix": 0}
	return result


func _normalize_nonnegative_counts(value: Variant, allowed: Array) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for key in allowed:
		result[str(key)] = maxi(0, int(source.get(str(key), 0)))
	return result


func _goal_ids() -> Array[String]:
	var result: Array[String] = []
	for value in _profile.get("goals", []):
		if value is Dictionary:
			result.append(str(value.get("id", "")))
	return result


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


func _float_array(value: Variant) -> Array[float]:
	var result: Array[float] = []
	if value is Array:
		for item in value:
			result.append(float(item))
	return result
