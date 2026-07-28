class_name PetBehaviorDirector
extends RefCounted

const DEFAULT_SEED := 21013
const DEFAULT_RECENT_HISTORY_SIZE := 3
const DEFAULT_SCORE_FLOOR := 0.01

var errors: Array[String] = []
var last_candidates: Array[Dictionary] = []

var _profile: Dictionary = {}
var _director_config: Dictionary = {}
var _definitions: Array = []
var _definitions_by_id: Dictionary = {}
var _cooldown_until_ms: Dictionary = {}
var _recent_history: Array[String] = []
var _rng := RandomNumberGenerator.new()
var _seed := DEFAULT_SEED

func _init(profile: Dictionary = {}, seed_override: int = -1) -> void:
	configure(profile, seed_override)

static func load_from_file(path: String, seed_override: int = -1) -> PetBehaviorDirector:
	var result := PetBehaviorDirector.new()
	if not FileAccess.file_exists(path):
		result.errors.append("找不到行为配置：%s" % path)
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		result.errors.append("无法读取行为配置：%s" % path)
		return result
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		result.errors.append("behavior_profile.json 不是有效的 JSON 对象")
		return result
	result.configure(parsed, seed_override)
	return result

func configure(profile: Dictionary, seed_override: int = -1) -> void:
	errors.clear()
	_profile = profile.duplicate(true)
	var director_value: Variant = _profile.get("director", {})
	_director_config = director_value.duplicate(true) if director_value is Dictionary else {}
	var definitions_value: Variant = _director_config.get("behaviors", [])
	_definitions = definitions_value.duplicate(true) if definitions_value is Array else []
	_definitions_by_id.clear()
	for value in _definitions:
		if not value is Dictionary:
			errors.append("行为定义必须是对象")
			continue
		var intent_id := str(value.get("id", ""))
		if intent_id.is_empty():
			errors.append("行为定义缺少 id")
			continue
		if _definitions_by_id.has(intent_id):
			errors.append("行为 id 重复：%s" % intent_id)
			continue
		_definitions_by_id[intent_id] = value.duplicate(true)
	if int(_profile.get("schema_version", 0)) != 1 and not _profile.is_empty():
		errors.append("只支持 behavior_profile schema_version: 1")
	var configured_seed := int(_director_config.get("default_seed", DEFAULT_SEED))
	set_seed(seed_override if seed_override >= 0 else configured_seed)
	reset_runtime(false)

func is_valid() -> bool:
	return errors.is_empty() and not _definitions_by_id.is_empty()

func set_seed(seed_value: int) -> void:
	_seed = seed_value
	_rng.seed = seed_value

func seed_value() -> int:
	return _seed

func reset_runtime(reset_rng: bool = true) -> void:
	_cooldown_until_ms.clear()
	_recent_history.clear()
	last_candidates.clear()
	if reset_rng:
		_rng.seed = _seed

func intent_definition(intent_id: String) -> Dictionary:
	var value: Variant = _definitions_by_id.get(intent_id, {})
	return value.duplicate(true) if value is Dictionary else {}

func create_intent(intent_id: String, needs: PetNeedsModel, context: Dictionary = {}, now_ms: int = -1) -> Dictionary:
	var definition := intent_definition(intent_id)
	if definition.is_empty() or needs == null:
		return {}
	var resolved_now := _resolve_now(now_ms, context)
	return _make_intent(definition, _score_definition(definition, needs, context), needs, context, resolved_now)

func candidate_scores(needs: PetNeedsModel, context: Dictionary = {}, now_ms: int = -1) -> Array[Dictionary]:
	var resolved_now := _resolve_now(now_ms, context)
	var result: Array[Dictionary] = []
	if needs == null or _is_globally_blocked(context):
		last_candidates = result
		return result
	for value in _definitions:
		if not value is Dictionary:
			continue
		var definition: Dictionary = value
		if not _passes_gates(definition, needs, context, resolved_now):
			continue
		var score := _score_definition(definition, needs, context)
		result.append(_make_intent(definition, score, needs, context, resolved_now))
	last_candidates = result.duplicate(true)
	return result

func select_intent(needs: PetNeedsModel, context: Dictionary = {}, now_ms: int = -1, commit: bool = true) -> Dictionary:
	var resolved_now := _resolve_now(now_ms, context)
	var candidates := candidate_scores(needs, context, resolved_now)
	if candidates.is_empty():
		return {}
	var non_recent: Array[Dictionary] = []
	for candidate in candidates:
		if not _recent_history.has(str(candidate.get("id", ""))):
			non_recent.append(candidate)
	var selection_pool := non_recent if not non_recent.is_empty() else candidates
	var selected := _weighted_choice(selection_pool)
	if selected.is_empty():
		return {}
	selected["selected_at_ms"] = resolved_now
	if commit:
		commit_intent(selected, resolved_now)
	return selected

func commit_intent(intent: Dictionary, now_ms: int = -1) -> void:
	var intent_id := str(intent.get("id", ""))
	if intent_id.is_empty():
		return
	var resolved_now := _resolve_now(now_ms, intent)
	var definition := intent_definition(intent_id)
	var cooldown_ms := int(intent.get("cooldown_ms", definition.get("cooldown_ms", 0)))
	if cooldown_ms > 0:
		_cooldown_until_ms[intent_id] = resolved_now + cooldown_ms
	_recent_history.append(intent_id)
	var history_size := maxi(int(_director_config.get("recent_history_size", DEFAULT_RECENT_HISTORY_SIZE)), 0)
	while _recent_history.size() > history_size:
		_recent_history.pop_front()

func cooldown_remaining_ms(intent_id: String, now_ms: int = -1) -> int:
	var resolved_now := _resolve_now(now_ms)
	return maxi(int(_cooldown_until_ms.get(intent_id, 0)) - resolved_now, 0)

func recent_intents() -> Array[String]:
	return _recent_history.duplicate()

func _passes_gates(definition: Dictionary, needs: PetNeedsModel, context: Dictionary, now_ms: int) -> bool:
	if not bool(definition.get("enabled", true)) or not bool(definition.get("selectable", true)):
		return false
	var intent_id := str(definition.get("id", ""))
	if intent_id.is_empty() or cooldown_remaining_ms(intent_id, now_ms) > 0:
		return false
	var gates_value: Variant = definition.get("preconditions", definition.get("gates", {}))
	var gates: Dictionary = gates_value if gates_value is Dictionary else {}
	if not _passes_need_gates(gates.get("needs", {}), needs):
		return false
	if not _passes_relationship_gate(gates.get("relationship", {}), needs, context):
		return false
	if not _passes_context_gates(gates, context):
		return false
	if not _passes_action_gates(gates, context):
		return false
	var periods_value: Variant = gates.get("time_periods", [])
	if periods_value is Array and not periods_value.is_empty():
		if not periods_value.has(str(context.get("time_period", ""))):
			return false
	return true

func _passes_need_gates(value: Variant, needs: PetNeedsModel) -> bool:
	if not value is Dictionary:
		return true
	for need_name in value.keys():
		var rule: Variant = value[need_name]
		if not rule is Dictionary:
			continue
		var current := needs.get_need(str(need_name))
		if rule.has("min") and current < float(rule["min"]):
			return false
		if rule.has("max") and current > float(rule["max"]):
			return false
	return true

func _passes_relationship_gate(value: Variant, needs: PetNeedsModel, context: Dictionary) -> bool:
	if not value is Dictionary or value.is_empty():
		return true
	var current_tier := str(context.get("relationship_tier", needs.relationship_tier()))
	var current_rank := needs.relationship_rank(current_tier)
	if value.has("min"):
		var minimum_rank := needs.relationship_rank(str(value["min"]))
		if minimum_rank >= 0 and current_rank < minimum_rank:
			return false
	if value.has("max"):
		var maximum_rank := needs.relationship_rank(str(value["max"]))
		if maximum_rank >= 0 and current_rank > maximum_rank:
			return false
	return true

func _passes_context_gates(gates: Dictionary, context: Dictionary) -> bool:
	for key in _as_string_array(gates.get("requires_all", [])):
		if not bool(context.get(key, false)):
			return false
	var requires_any := _as_string_array(gates.get("requires_any", []))
	if not requires_any.is_empty():
		var matched := false
		for key in requires_any:
			if bool(context.get(key, false)):
				matched = true
				break
		if not matched:
			return false
	for key in _as_string_array(gates.get("forbids_any", [])):
		if bool(context.get(key, false)):
			return false
	var rules: Variant = gates.get("context", {})
	if rules is Dictionary:
		for key in rules.keys():
			if not _context_rule_matches(context.get(str(key), null), rules[key]):
				return false
	return true

func _passes_action_gates(gates: Dictionary, context: Dictionary) -> bool:
	var required_all := _as_string_array(gates.get("requires_clips", gates.get("requires_actions", [])))
	var required_any := _as_string_array(gates.get("requires_any_clips", gates.get("requires_any_actions", [])))
	if required_all.is_empty() and required_any.is_empty():
		return true
	if not context.has("available_clips") and not context.has("available_actions"):
		return false
	var available := _to_lookup(context.get("available_clips", context.get("available_actions", [])))
	for action_name in required_all:
		if not available.has(action_name):
			return false
	if not required_any.is_empty():
		var matched := false
		for action_name in required_any:
			if available.has(action_name):
				matched = true
				break
		if not matched:
			return false
	return true

func _score_definition(definition: Dictionary, needs: PetNeedsModel, context: Dictionary) -> float:
	var score_value: Variant = definition.get("score_weights", definition.get("score", {}))
	var score_config: Dictionary = score_value if score_value is Dictionary else {}
	var score := float(score_config.get("base", definition.get("base_weight", 1.0)))
	var need_weights: Variant = score_config.get("needs", {})
	if need_weights is Dictionary:
		for need_name in need_weights.keys():
			score += needs.get_need(str(need_name)) * float(need_weights[need_name])
	var context_weights: Variant = score_config.get("context", {})
	if context_weights is Dictionary:
		for key in context_weights.keys():
			var context_value: Variant = context.get(str(key), false)
			if context_value is bool:
				if context_value:
					score += float(context_weights[key])
			elif context_value is int or context_value is float:
				score += float(context_value) * float(context_weights[key])
	var relationship_scores: Variant = score_config.get("relationship", {})
	if relationship_scores is Dictionary:
		var relationship_tier := str(context.get("relationship_tier", needs.relationship_tier()))
		score += float(relationship_scores.get(relationship_tier, 0.0))
	return score

func _make_intent(definition: Dictionary, score: float, needs: PetNeedsModel, context: Dictionary, now_ms: int) -> Dictionary:
	var clip := _resolved_clip(definition, context)
	var fallback_clip := str(definition.get("fallback_clip", "idle"))
	var interrupt_policy := str(definition.get("interrupt_policy", "return_idle"))
	var resume_policy := str(definition.get("resume_policy", "never"))
	var session := _dictionary_copy(definition.get("session", {}))
	if not session.has("clip") and str(session.get("type", "one_shot")) == "one_shot":
		session["clip"] = clip
	if not session.has("interrupt_mode"):
		session["interrupt_mode"] = interrupt_policy
	return {
		"id": str(definition.get("id", "")),
		"clip": clip,
		"fallback_clip": fallback_clip,
		"action": clip,
		"state": str(definition.get("state", definition.get("category", "autonomous"))),
		"category": str(definition.get("category", "autonomous")),
		"priority": definition.get("priority", "autonomous"),
		"interrupt_policy": interrupt_policy,
		"resume_policy": resume_policy,
		"score": score,
		"cooldown_ms": int(definition.get("cooldown_ms", 0)),
		"effects": _dictionary_copy(definition.get("effects", {})),
		"session": session,
		"relationship_tier": str(context.get("relationship_tier", needs.relationship_tier())),
		"evaluated_at_ms": now_ms,
	}

func _resolved_clip(definition: Dictionary, context: Dictionary) -> String:
	var primary := str(definition.get("clip", definition.get("action", "")))
	var fallback := str(definition.get("fallback_clip", "idle"))
	if not context.has("available_clips") and not context.has("available_actions"):
		return primary if not primary.is_empty() else fallback
	var available := _to_lookup(context.get("available_clips", context.get("available_actions", [])))
	if available.has(primary):
		return primary
	if available.has(fallback):
		return fallback
	return ""

func _weighted_choice(candidates: Array[Dictionary]) -> Dictionary:
	var floor_score := maxf(float(_director_config.get("score_floor", DEFAULT_SCORE_FLOOR)), 0.000001)
	var total := 0.0
	for candidate in candidates:
		total += maxf(float(candidate.get("score", 0.0)), floor_score)
	var roll := _rng.randf() * total
	var accumulated := 0.0
	for candidate in candidates:
		accumulated += maxf(float(candidate.get("score", 0.0)), floor_score)
		if roll <= accumulated:
			return candidate.duplicate(true)
	return candidates.back().duplicate(true)

func _is_globally_blocked(context: Dictionary) -> bool:
	if not bool(context.get("autonomy_allowed", true)):
		return true
	for key in _as_string_array(_director_config.get("global_blockers", [])):
		if bool(context.get(key, false)):
			return true
	return false

func _context_rule_matches(actual: Variant, expected: Variant) -> bool:
	if expected is Dictionary:
		if actual == null:
			return false
		if expected.has("min") and float(actual) < float(expected["min"]):
			return false
		if expected.has("max") and float(actual) > float(expected["max"]):
			return false
		if expected.has("equals") and actual != expected["equals"]:
			return false
		return true
	return actual == expected

func _as_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result

func _to_lookup(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if value is Array:
		for item in value:
			result[str(item)] = true
	elif value is Dictionary:
		for key in value.keys():
			if bool(value[key]):
				result[str(key)] = true
	return result

func _dictionary_copy(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

func _resolve_now(now_ms: int, context: Dictionary = {}) -> int:
	if now_ms >= 0:
		return now_ms
	if context.has("now_ms"):
		return int(context["now_ms"])
	return Time.get_ticks_msec()
