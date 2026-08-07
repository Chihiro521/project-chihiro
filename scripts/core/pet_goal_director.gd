class_name PetGoalDirector
extends RefCounted

const RECENT_LIMIT := 3

var errors: Array[String] = []
var last_candidates: Array[Dictionary] = []
var _goals: Array[Dictionary] = []
var _by_id: Dictionary = {}
var _cooldowns: Dictionary = {}
var _recent: Array[String] = []
var _rng := RandomNumberGenerator.new()


func _init(profile: Dictionary = {}, seed := 22013) -> void:
	_rng.seed = seed
	configure(profile)


func configure(profile: Dictionary) -> void:
	errors.clear()
	_goals.clear()
	_by_id.clear()
	var source: Variant = profile.get("goals", [])
	if not source is Array:
		errors.append("生态配置缺少 goals 数组")
		return
	for value in source:
		if not value is Dictionary:
			continue
		var definition: Dictionary = value.duplicate(true)
		var goal_id := str(definition.get("id", ""))
		if goal_id.is_empty() or _by_id.has(goal_id):
			errors.append("生态目标 id 无效或重复：%s" % goal_id)
			continue
		if not definition.get("steps", []) is Array or definition.get("steps", []).is_empty():
			errors.append("生态目标缺少步骤：%s" % goal_id)
			continue
		_goals.append(definition)
		_by_id[goal_id] = definition


func is_valid() -> bool:
	return errors.is_empty() and not _goals.is_empty()


func create_goal(goal_id: String, context: Dictionary = {}, now_ms := -1) -> Dictionary:
	if not _by_id.has(goal_id):
		return {}
	var definition: Dictionary = _by_id[goal_id]
	if not _eligible(definition, context, _resolve_now(now_ms)):
		return {}
	return _make_goal(definition, 0.0, context, _resolve_now(now_ms))


func select_goal(needs: PetNeedsModel, context: Dictionary, now_ms := -1, commit := true) -> Dictionary:
	var now := _resolve_now(now_ms)
	var candidates: Array[Dictionary] = []
	last_candidates.clear()
	for definition in _goals:
		var eligible := _eligible(definition, context, now)
		var score := _score(definition, needs, context) if eligible else 0.0
		var goal_id := str(definition.get("id", ""))
		var recent_penalty := 0.0
		if goal_id in _recent:
			recent_penalty = float(definition.get("recent_penalty", 1000.0))
			score -= recent_penalty
		var diagnostic := {
			"id": goal_id,
			"name": str(definition.get("name", goal_id)),
			"eligible": eligible,
			"score": score,
			"cooldown_ms": cooldown_remaining_ms(goal_id, now),
			"recent_penalty": recent_penalty,
		}
		last_candidates.append(diagnostic)
		if eligible:
			candidates.append(_make_goal(definition, score, context, now))
	if candidates.is_empty():
		return {}
	var non_recent: Array[Dictionary] = []
	for candidate in candidates:
		if str(candidate.get("id", "")) not in _recent:
			non_recent.append(candidate)
	var pool := non_recent if not non_recent.is_empty() else candidates
	var selected := _weighted_choice(pool)
	if commit:
		_commit(selected, now)
	return selected


func cooldown_remaining_ms(goal_id: String, now_ms: int) -> int:
	return maxi(0, int(_cooldowns.get(goal_id, 0)) - now_ms)


func recent_goals() -> Array[String]:
	return _recent.duplicate()


func _eligible(definition: Dictionary, context: Dictionary, now_ms: int) -> bool:
	var goal_id := str(definition.get("id", ""))
	if cooldown_remaining_ms(goal_id, now_ms) > 0:
		return false
	if float(context.get("familiarity", 0.0)) < float(definition.get("min_familiarity", 0.0)):
		return false
	var requires: Variant = definition.get("requires", [])
	if requires is Array:
		for key in requires:
			if not bool(context.get(str(key), false)):
				return false
	var forbids: Variant = definition.get("forbids", [])
	if forbids is Array:
		for key in forbids:
			if bool(context.get(str(key), false)):
				return false
	return true


func _score(definition: Dictionary, needs: PetNeedsModel, context: Dictionary) -> float:
	var score := float(definition.get("base_weight", 1.0))
	var need_weights: Variant = definition.get("need_weights", {})
	if need_weights is Dictionary:
		for key in need_weights.keys():
			score += needs.get_need(str(key)) * float(need_weights[key])
	var context_weights: Variant = definition.get("context_weights", {})
	if context_weights is Dictionary:
		for key in context_weights.keys():
			var current: Variant = context.get(str(key), false)
			if current is bool and current:
				score += float(context_weights[key])
			elif current is int or current is float:
				score += float(current) * float(context_weights[key])
	var habit_stages: Variant = context.get("habit_stages", {})
	if habit_stages is Dictionary:
		for habit_id in definition.get("habit_ids", []):
			score += float(habit_stages.get(str(habit_id), 0)) * float(definition.get("habit_stage_bonus", 2.0))
	return maxf(0.01, score)


func _make_goal(definition: Dictionary, score: float, context: Dictionary, now_ms: int) -> Dictionary:
	var result := definition.duplicate(true)
	result["score"] = score
	result["selected_at_ms"] = now_ms
	result["context"] = {
		"time_period": str(context.get("time_period", "")),
		"app_category": str(context.get("app_category", "")),
		"pet_screen": int(context.get("pet_screen", -1)),
	}
	return result


func _weighted_choice(candidates: Array[Dictionary]) -> Dictionary:
	var total := 0.0
	for candidate in candidates:
		total += maxf(0.01, float(candidate.get("score", 0.0)))
	var roll := _rng.randf() * total
	var accumulated := 0.0
	for candidate in candidates:
		accumulated += maxf(0.01, float(candidate.get("score", 0.0)))
		if roll <= accumulated:
			return candidate.duplicate(true)
	return candidates.back().duplicate(true)


func _commit(goal: Dictionary, now_ms: int) -> void:
	var goal_id := str(goal.get("id", ""))
	_cooldowns[goal_id] = now_ms + int(goal.get("cooldown_ms", 0))
	_recent.append(goal_id)
	while _recent.size() > RECENT_LIMIT:
		_recent.pop_front()


func _resolve_now(value: int) -> int:
	return value if value >= 0 else Time.get_ticks_msec()
