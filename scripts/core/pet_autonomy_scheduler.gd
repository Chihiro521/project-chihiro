class_name PetAutonomyScheduler
extends RefCounted

const CHANNEL_ORDER := ["ecology", "behavior", "movement"]
const CHANNEL_WEIGHTS := {"ecology": 50.0, "behavior": 35.0, "movement": 15.0}
const CHANNEL_MISS_LIMITS := {"ecology": 2, "behavior": 3, "movement": 6}
const SPECIAL_WAIT_MS := {"cursor_play_chase": 120000.0, "icon_collect": 180000.0}
const RECENT_FACTOR := 0.35
const RECENT_LIMIT := 3

var _rng := RandomNumberGenerator.new()
var _clock_ms := 0.0
var _channel_state: Dictionary = {}
var _candidate_state: Dictionary = {}
var _last_channels: Dictionary = {}
var _pending_selection: Dictionary = {}
var _last_selection: Dictionary = {}
var _recent_ids: Array[String] = []
var _forced_queue: Array[Dictionary] = []


func _init(seed := 23013) -> void:
	_rng.seed = seed
	for channel in CHANNEL_ORDER:
		_channel_state[channel] = {
			"missed_rounds": 0,
			"last_selected_clock_ms": -1.0,
			"available_count": 0,
			"effective_weight": float(CHANNEL_WEIGHTS[channel]),
		}


func advance_clock(delta_ms: float, autonomy_active: bool) -> void:
	if autonomy_active:
		_clock_ms += maxf(delta_ms, 0.0)


## Refreshes eligibility without making a choice. Main calls this during long
## autonomous routines so the 120/180-second guarantees measure real eligible
## waiting time rather than starting only after the routine returns to idle.
func observe(channels: Dictionary) -> void:
	var normalized := _normalize_channels(channels)
	_sync_eligibility(normalized)
	_last_channels = normalized


func choose(channels: Dictionary, recent_ids: Array = []) -> Dictionary:
	var normalized := _normalize_channels(channels)
	_sync_eligibility(normalized)
	_last_channels = normalized
	_pending_selection.clear()
	_forced_queue.clear()

	var available_channels: Array[String] = []
	for channel in CHANNEL_ORDER:
		if not (normalized.get(channel, []) as Array).is_empty():
			available_channels.append(channel)
	if available_channels.is_empty():
		return {}

	var all_recent: Array[String] = _recent_ids.duplicate()
	for value in recent_ids:
		var intent_id := str(value)
		if not intent_id.is_empty() and intent_id not in all_recent:
			all_recent.append(intent_id)
	for channel in CHANNEL_ORDER:
		for candidate in normalized.get(channel, []):
			if candidate is Dictionary:
				_effective_candidate_score(channel, candidate, all_recent)

	var forced_special := _oldest_due_special(normalized)
	var selected_channel := ""
	var selected_candidate: Dictionary = {}
	var forced := false
	var reason := "weighted"
	if not forced_special.is_empty():
		selected_channel = "behavior"
		selected_candidate = forced_special
		forced = true
		reason = "special_deadline"
	else:
		selected_channel = _forced_channel(available_channels, normalized)
		if not selected_channel.is_empty():
			forced = true
			reason = "channel_miss_limit"
		else:
			selected_channel = _weighted_channel(available_channels)
		selected_candidate = _choose_candidate(selected_channel, normalized[selected_channel], all_recent)
		if bool(selected_candidate.get("scheduler_forced", false)):
			forced = true
			reason = "candidate_miss_limit"
	if selected_candidate.is_empty():
		return {}
	if forced and _forced_queue.is_empty():
		_forced_queue.append({"channel": selected_channel, "id": str(selected_candidate.get("id", "")), "reason": reason})

	var intent_id := str(selected_candidate.get("id", ""))
	var state := _candidate_record(selected_channel, intent_id)
	selected_candidate["scheduler_wait_ms"] = maxf(0.0, _clock_ms - float(state.get("eligible_since_clock_ms", _clock_ms)))
	selected_candidate["scheduler_missed_rounds"] = int(state.get("missed_channel_rounds", 0))
	selected_candidate["scheduler_effective_score"] = _effective_candidate_score(selected_channel, selected_candidate, all_recent)
	selected_candidate["scheduler_forced"] = forced
	_pending_selection = {
		"channel": selected_channel,
		"candidate": selected_candidate.duplicate(true),
		"forced": forced,
		"reason": reason,
	}
	return _pending_selection.duplicate(true)


func mark_executed(channel: String, candidate_id: String) -> void:
	if channel.is_empty() or candidate_id.is_empty():
		return
	var pending_matches := (
		str(_pending_selection.get("channel", "")) == channel
		and str((_pending_selection.get("candidate", {}) as Dictionary).get("id", "")) == candidate_id
	)
	if pending_matches:
		for channel_name in CHANNEL_ORDER:
			var available := not (_last_channels.get(channel_name, []) as Array).is_empty()
			var channel_record: Dictionary = _channel_state[channel_name]
			if not available:
				channel_record["missed_rounds"] = 0
			elif channel_name == channel:
				channel_record["missed_rounds"] = 0
				channel_record["last_selected_clock_ms"] = _clock_ms
			else:
				channel_record["missed_rounds"] = int(channel_record.get("missed_rounds", 0)) + 1
			_channel_state[channel_name] = channel_record
		for candidate in _last_channels.get(channel, []):
			if not candidate is Dictionary:
				continue
			var current_id := str(candidate.get("id", ""))
			var candidate_record := _candidate_record(channel, current_id)
			if current_id == candidate_id:
				candidate_record["missed_channel_rounds"] = 0
				candidate_record["eligible_since_clock_ms"] = _clock_ms
				candidate_record["last_selected_clock_ms"] = _clock_ms
			else:
				candidate_record["missed_channel_rounds"] = int(candidate_record.get("missed_channel_rounds", 0)) + 1
			_candidate_state[_candidate_key(channel, current_id)] = candidate_record

	var selected_candidate: Dictionary = _pending_selection.get("candidate", {}) if pending_matches else {}
	_last_selection = {
		"channel": channel,
		"candidate_id": candidate_id,
		"forced": bool(_pending_selection.get("forced", false)) if pending_matches else false,
		"reason": str(_pending_selection.get("reason", "routine_step")) if pending_matches else "routine_step",
		"clock_ms": _clock_ms,
		"wait_ms": float(selected_candidate.get("scheduler_wait_ms", 0.0)),
	}
	var direct_key := _candidate_key(channel, candidate_id)
	if _candidate_state.has(direct_key):
		var direct_record: Dictionary = _candidate_state[direct_key]
		direct_record["missed_channel_rounds"] = 0
		direct_record["eligible_since_clock_ms"] = _clock_ms
		direct_record["last_selected_clock_ms"] = _clock_ms
		_candidate_state[direct_key] = direct_record
	_recent_ids.append(candidate_id)
	while _recent_ids.size() > RECENT_LIMIT:
		_recent_ids.pop_front()
	_pending_selection.clear()


## A selected target can become invalid between the final desktop re-check and
## action start. Drop its waiting age without counting that failed attempt as a
## successful scheduling round.
func mark_unavailable(channel: String, candidate_id: String) -> void:
	_candidate_state.erase(_candidate_key(channel, candidate_id))
	_pending_selection.clear()


func snapshot() -> Dictionary:
	var channel_snapshot: Dictionary = {}
	for channel in CHANNEL_ORDER:
		var record: Dictionary = (_channel_state[channel] as Dictionary).duplicate(true)
		record["base_weight"] = float(CHANNEL_WEIGHTS[channel])
		record["max_missed_rounds"] = int(CHANNEL_MISS_LIMITS[channel])
		channel_snapshot[channel] = record
	var candidates: Array[Dictionary] = []
	for key in _candidate_state.keys():
		var record: Dictionary = (_candidate_state[key] as Dictionary).duplicate(true)
		record["wait_ms"] = maxf(0.0, _clock_ms - float(record.get("eligible_since_clock_ms", _clock_ms)))
		candidates.append(record)
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left.get("missed_channel_rounds", 0)) != int(right.get("missed_channel_rounds", 0)):
			return int(left.get("missed_channel_rounds", 0)) > int(right.get("missed_channel_rounds", 0))
		return float(left.get("wait_ms", 0.0)) > float(right.get("wait_ms", 0.0))
	)
	return {
		"clock_ms": _clock_ms,
		"last_selection": _last_selection.duplicate(true),
		"channels": channel_snapshot,
		"candidates": candidates,
		"forced_queue": _forced_queue.duplicate(true),
		"next_guarantee": _next_special_guarantee(),
		"recent_ids": _recent_ids.duplicate(),
	}


func _normalize_channels(channels: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for channel in CHANNEL_ORDER:
		var normalized: Array[Dictionary] = []
		var seen: Dictionary = {}
		var source: Variant = channels.get(channel, [])
		if source is Array:
			for value in source:
				if not value is Dictionary:
					continue
				var candidate: Dictionary = value
				var intent_id := str(candidate.get("id", ""))
				if intent_id.is_empty() or seen.has(intent_id):
					continue
				seen[intent_id] = true
				normalized.append(candidate.duplicate(true))
		result[channel] = normalized
	return result


func _sync_eligibility(channels: Dictionary) -> void:
	var active_keys: Dictionary = {}
	for channel in CHANNEL_ORDER:
		var candidates: Array = channels.get(channel, [])
		var channel_record: Dictionary = _channel_state[channel]
		channel_record["available_count"] = candidates.size()
		if candidates.is_empty():
			channel_record["missed_rounds"] = 0
		var missed := int(channel_record.get("missed_rounds", 0))
		channel_record["effective_weight"] = float(CHANNEL_WEIGHTS[channel]) * (1.0 + 0.4 * missed * missed)
		_channel_state[channel] = channel_record
		for candidate in candidates:
			var intent_id := str(candidate.get("id", ""))
			var key := _candidate_key(channel, intent_id)
			active_keys[key] = true
			if not _candidate_state.has(key):
				_candidate_state[key] = {
					"channel": channel,
					"id": intent_id,
					"eligible_since_clock_ms": _clock_ms,
					"missed_channel_rounds": 0,
					"last_selected_clock_ms": -1.0,
					"effective_score": maxf(float(candidate.get("score", 0.0)), 0.01),
				}
	for key in _candidate_state.keys():
		if not active_keys.has(key):
			_candidate_state.erase(key)


func _oldest_due_special(channels: Dictionary) -> Dictionary:
	var due: Array[Dictionary] = []
	for candidate in channels.get("behavior", []):
		if not candidate is Dictionary:
			continue
		var intent_id := str(candidate.get("id", ""))
		if not SPECIAL_WAIT_MS.has(intent_id):
			continue
		var record := _candidate_record("behavior", intent_id)
		var wait_ms := maxf(0.0, _clock_ms - float(record.get("eligible_since_clock_ms", _clock_ms)))
		if wait_ms >= float(SPECIAL_WAIT_MS[intent_id]):
			var item: Dictionary = (candidate as Dictionary).duplicate(true)
			item["scheduler_wait_ms"] = wait_ms
			due.append(item)
	if due.is_empty():
		return {}
	var longest := 0.0
	for candidate in due:
		longest = maxf(longest, float(candidate.get("scheduler_wait_ms", 0.0)))
	var tied: Array[Dictionary] = []
	for candidate in due:
		if is_equal_approx(float(candidate.get("scheduler_wait_ms", 0.0)), longest):
			tied.append(candidate)
	return tied[_rng.randi_range(0, tied.size() - 1)].duplicate(true)


func _forced_channel(available: Array[String], channels: Dictionary) -> String:
	# Reserve enough future idle decisions for every channel before any of their
	# miss deadlines collide. This one-step feasibility check prevents two channels
	# from reaching their hard limit on the same round, where serving either one
	# would necessarily starve the other.
	var safe_choices: Array[String] = []
	for channel in available:
		if _channel_choice_keeps_deadlines(channel, available):
			safe_choices.append(channel)
	if not safe_choices.is_empty() and safe_choices.size() < available.size():
		return _weighted_channel(safe_choices)
	var forced: Array[String] = []
	var largest_debt := -1
	for channel in available:
		var missed := int((_channel_state[channel] as Dictionary).get("missed_rounds", 0))
		if missed < int(CHANNEL_MISS_LIMITS[channel]):
			continue
		if missed > largest_debt:
			forced.clear()
			largest_debt = missed
		if missed == largest_debt:
			forced.append(channel)
	if forced.size() <= 1:
		return forced[0] if not forced.is_empty() else ""
	var oldest_wait := -1.0
	var oldest: Array[String] = []
	for channel in forced:
		var wait_ms := _oldest_channel_wait(channel, channels[channel])
		if wait_ms > oldest_wait + 0.01:
			oldest.clear()
			oldest_wait = wait_ms
		if is_equal_approx(wait_ms, oldest_wait):
			oldest.append(channel)
	return oldest[_rng.randi_range(0, oldest.size() - 1)]


func _channel_choice_keeps_deadlines(selected: String, available: Array[String]) -> bool:
	var remaining_slots: Array[int] = []
	for channel in available:
		var missed := 0 if channel == selected else int((_channel_state[channel] as Dictionary).get("missed_rounds", 0)) + 1
		var limit := int(CHANNEL_MISS_LIMITS[channel])
		if missed > limit:
			return false
		remaining_slots.append(limit - missed)
	remaining_slots.sort()
	for index in range(remaining_slots.size()):
		if remaining_slots[index] < index:
			return false
	return true


func _weighted_channel(available: Array[String]) -> String:
	var total := 0.0
	for channel in available:
		total += float((_channel_state[channel] as Dictionary).get("effective_weight", CHANNEL_WEIGHTS[channel]))
	var roll := _rng.randf() * total
	for channel in available:
		roll -= float((_channel_state[channel] as Dictionary).get("effective_weight", CHANNEL_WEIGHTS[channel]))
		if roll <= 0.0:
			return channel
	return available.back()


func _choose_candidate(channel: String, candidates: Array, recent_ids: Array[String]) -> Dictionary:
	if candidates.is_empty():
		return {}
	var threshold := maxi(4, candidates.size() * 2)
	var forced: Array[Dictionary] = []
	var largest_missed := -1
	for value in candidates:
		if not value is Dictionary:
			continue
		var candidate: Dictionary = value
		var record := _candidate_record(channel, str(candidate.get("id", "")))
		var missed := int(record.get("missed_channel_rounds", 0))
		if missed < threshold:
			continue
		if missed > largest_missed:
			forced.clear()
			largest_missed = missed
		if missed == largest_missed:
			forced.append(candidate)
	if not forced.is_empty():
		var oldest_wait := -1.0
		var oldest: Array[Dictionary] = []
		for candidate in forced:
			var record := _candidate_record(channel, str(candidate.get("id", "")))
			var wait_ms := _clock_ms - float(record.get("eligible_since_clock_ms", _clock_ms))
			if wait_ms > oldest_wait + 0.01:
				oldest.clear()
				oldest_wait = wait_ms
			if is_equal_approx(wait_ms, oldest_wait):
				oldest.append(candidate)
		var result: Dictionary = oldest[_rng.randi_range(0, oldest.size() - 1)].duplicate(true)
		result["scheduler_forced"] = true
		_forced_queue = forced.duplicate(true)
		return result

	var total := 0.0
	var scored: Array[Dictionary] = []
	for value in candidates:
		if not value is Dictionary:
			continue
		var candidate: Dictionary = value
		var score := _effective_candidate_score(channel, candidate, recent_ids)
		var entry := {"candidate": candidate, "score": score}
		scored.append(entry)
		total += score
	var roll := _rng.randf() * total
	for entry in scored:
		roll -= float(entry.get("score", 0.0))
		if roll <= 0.0:
			return (entry.get("candidate", {}) as Dictionary).duplicate(true)
	return (scored.back().get("candidate", {}) as Dictionary).duplicate(true)


func _effective_candidate_score(channel: String, candidate: Dictionary, recent_ids: Array[String]) -> float:
	var intent_id := str(candidate.get("id", ""))
	var record := _candidate_record(channel, intent_id)
	var missed := int(record.get("missed_channel_rounds", 0))
	var recent_factor := RECENT_FACTOR if intent_id in recent_ids else 1.0
	var result := maxf(float(candidate.get("score", 0.0)), 0.01) * (1.0 + 0.35 * missed * missed) * recent_factor
	record["effective_score"] = result
	_candidate_state[_candidate_key(channel, intent_id)] = record
	return result


func _oldest_channel_wait(channel: String, candidates: Array) -> float:
	var result := 0.0
	for candidate in candidates:
		if candidate is Dictionary:
			var record := _candidate_record(channel, str(candidate.get("id", "")))
			result = maxf(result, _clock_ms - float(record.get("eligible_since_clock_ms", _clock_ms)))
	return result


func _next_special_guarantee() -> Dictionary:
	var next: Dictionary = {}
	for intent_id in SPECIAL_WAIT_MS.keys():
		var key := _candidate_key("behavior", str(intent_id))
		if not _candidate_state.has(key):
			continue
		var record: Dictionary = _candidate_state[key]
		var wait_ms := maxf(0.0, _clock_ms - float(record.get("eligible_since_clock_ms", _clock_ms)))
		var remaining := maxf(0.0, float(SPECIAL_WAIT_MS[intent_id]) - wait_ms)
		if next.is_empty() or remaining < float(next.get("remaining_ms", INF)):
			next = {"id": str(intent_id), "wait_ms": wait_ms, "remaining_ms": remaining, "due": remaining <= 0.0}
	return next


func _candidate_record(channel: String, candidate_id: String) -> Dictionary:
	var key := _candidate_key(channel, candidate_id)
	if not _candidate_state.has(key):
		_candidate_state[key] = {
			"channel": channel,
			"id": candidate_id,
			"eligible_since_clock_ms": _clock_ms,
			"missed_channel_rounds": 0,
			"last_selected_clock_ms": -1.0,
			"effective_score": 0.01,
		}
	return _candidate_state[key]


func _candidate_key(channel: String, candidate_id: String) -> String:
	return "%s::%s" % [channel, candidate_id]
