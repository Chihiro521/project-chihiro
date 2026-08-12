class_name PetNeedsModel
extends RefCounted

signal values_changed(values: Dictionary, reason: String)
signal relationship_tier_changed(previous: String, current: String, affection: float)

const RelationshipRules := preload("res://scripts/core/pet_relationship_rules.gd")

const MIN_VALUE := 0.0
const MAX_VALUE := 100.0
const NEED_NAMES := ["energy", "boredom", "curiosity", "irritation", "affection"]
const DEFAULT_INITIAL := {
	"energy": 72.0,
	"boredom": 20.0,
	"curiosity": 35.0,
	"irritation": 0.0,
	"affection": 25.0,
}
const DEFAULT_RATES_PER_MINUTE := {
	"awake": {
		"energy": -1.2,
		"boredom": 0.75,
		"curiosity": -3.0,
		"irritation": -5.0,
	},
	"sleeping": {
		"energy": 12.0,
		"boredom": -1.5,
		"curiosity": -3.0,
		"irritation": -7.0,
	},
}
const DEFAULT_RELATIONSHIP_TIERS := [
	{"id": "distant", "min": 0.0},
	{"id": "guarded", "min": 20.0},
	{"id": "familiar", "min": 40.0},
	{"id": "trusted", "min": 60.0},
	{"id": "close", "min": 80.0},
]

var _values: Dictionary = DEFAULT_INITIAL.duplicate(true)
var _needs_config: Dictionary = {}
var _relationship_config: Dictionary = {}
var _current_relationship_tier := "guarded"
var _relationship_day_key := ""
var _positive_affection_today := 0.0
var _negative_affection_today := 0.0

func _init(profile: Dictionary = {}) -> void:
	configure(profile)

func configure(profile: Dictionary, reset_values: bool = true) -> void:
	var needs_value: Variant = profile.get("needs", profile)
	_needs_config = needs_value.duplicate(true) if needs_value is Dictionary else {}
	var relationship_value: Variant = profile.get("relationship", {})
	_relationship_config = relationship_value.duplicate(true) if relationship_value is Dictionary else {}
	if reset_values:
		reset_session()

func reset_session(persistent_affection: float = -1.0, persistent_relationship_state: Dictionary = {}) -> void:
	_values = DEFAULT_INITIAL.duplicate(true)
	var configured_initial: Variant = _needs_config.get("initial", {})
	if configured_initial is Dictionary:
		for need_name in NEED_NAMES:
			if configured_initial.has(need_name):
				_values[need_name] = _clamp_need(float(configured_initial[need_name]))
	if persistent_affection >= MIN_VALUE:
		_values["affection"] = _clamp_need(persistent_affection)
	var stored_tier := str(persistent_relationship_state.get("current_relationship_tier", ""))
	_current_relationship_tier = (
		RelationshipRules.normalize_tier(stored_tier)
		if not stored_tier.is_empty()
		else RelationshipRules.tier_for_affection(get_need("affection"))
	)
	_current_relationship_tier = RelationshipRules.tier_with_hysteresis(
		_current_relationship_tier,
		get_need("affection"),
	)
	_relationship_day_key = str(persistent_relationship_state.get("relationship_day_key", ""))
	_positive_affection_today = clampf(
		float(persistent_relationship_state.get("positive_affection_today", 0.0)),
		0.0,
		RelationshipRules.DAILY_POSITIVE_CAP,
	)
	_negative_affection_today = clampf(
		float(persistent_relationship_state.get("negative_affection_today", 0.0)),
		0.0,
		RelationshipRules.DAILY_NEGATIVE_CAP,
	)
	_ensure_relationship_day()
	values_changed.emit(snapshot(), "session_reset")

func tick(delta_seconds: float, context: Dictionary = {}) -> bool:
	if delta_seconds <= 0.0:
		return false
	var mode := "sleeping" if bool(context.get("sleeping", false)) else "awake"
	var configured_rates: Variant = _needs_config.get("rates_per_minute", DEFAULT_RATES_PER_MINUTE)
	var rates_by_mode: Dictionary = configured_rates if configured_rates is Dictionary else DEFAULT_RATES_PER_MINUTE
	var rates_value: Variant = rates_by_mode.get(mode, DEFAULT_RATES_PER_MINUTE.get(mode, {}))
	var rates: Dictionary = rates_value if rates_value is Dictionary else {}
	var multipliers_value: Variant = context.get("rate_multipliers", {})
	var multipliers: Dictionary = multipliers_value if multipliers_value is Dictionary else {}
	var scale := maxf(float(context.get("rate_scale", 1.0)), 0.0)
	var deltas: Dictionary = {}
	for need_name in rates.keys():
		if not _values.has(str(need_name)):
			continue
		var need_scale := float(multipliers.get(need_name, 1.0))
		deltas[str(need_name)] = float(rates[need_name]) * delta_seconds / 60.0 * scale * need_scale
	return _apply_deltas(deltas, "tick:%s" % mode)

func apply_event(event_name: String, payload: Dictionary = {}) -> bool:
	var configured_effects: Variant = _needs_config.get("event_effects", {})
	var event_effects: Dictionary = configured_effects if configured_effects is Dictionary else {}
	var effects_value: Variant = event_effects.get(event_name, {})
	var effects: Dictionary = effects_value.duplicate(true) if effects_value is Dictionary else {}
	var payload_effects: Variant = payload.get("effects", {})
	if payload_effects is Dictionary:
		for need_name in payload_effects.keys():
			effects[str(need_name)] = float(effects.get(need_name, 0.0)) + float(payload_effects[need_name])
	var multiplier := float(payload.get("multiplier", 1.0))
	var scaled_effects: Dictionary = {}
	for need_name in effects.keys():
		scaled_effects[str(need_name)] = float(effects[need_name]) * multiplier
	return _apply_deltas(
		scaled_effects,
		"event:%s" % event_name,
		str(payload.get("relationship_day_key", "")),
	)

func apply_relationship_delta(amount: float, reason: String, day_key: String = "") -> float:
	if is_zero_approx(amount):
		return 0.0
	var before := get_need("affection")
	_apply_deltas({"affection": amount}, reason, day_key)
	return get_need("affection") - before

func set_need(need_name: String, amount: float, reason: String = "set") -> bool:
	if not _values.has(need_name):
		return false
	var next_value := _clamp_need(amount)
	if is_equal_approx(float(_values[need_name]), next_value):
		return false
	_values[need_name] = next_value
	if need_name == "affection":
		_refresh_relationship_tier()
	values_changed.emit(snapshot(), reason)
	return true

func get_need(need_name: String, fallback: float = 0.0) -> float:
	return float(_values.get(need_name, fallback))

func snapshot() -> Dictionary:
	return _values.duplicate(true)

func persistent_snapshot() -> Dictionary:
	return relationship_persistent_snapshot()

func restore_persistent(data: Dictionary) -> void:
	reset_session(float(data.get("affection", get_need("affection"))), data)

func relationship_persistent_snapshot() -> Dictionary:
	_ensure_relationship_day()
	return {
		"affection": get_need("affection"),
		"current_relationship_tier": relationship_tier(),
		"relationship_day_key": _relationship_day_key,
		"positive_affection_today": _positive_affection_today,
		"negative_affection_today": _negative_affection_today,
	}

func relationship_daily_snapshot(day_key: String = "") -> Dictionary:
	_ensure_relationship_day(day_key)
	return {
		"day_key": _relationship_day_key,
		"positive": _positive_affection_today,
		"negative": _negative_affection_today,
		"positive_remaining": maxf(0.0, RelationshipRules.DAILY_POSITIVE_CAP - _positive_affection_today),
		"negative_remaining": maxf(0.0, RelationshipRules.DAILY_NEGATIVE_CAP - _negative_affection_today),
	}

func relationship_tier() -> String:
	return _current_relationship_tier

func relationship_tier_for(affection: float) -> String:
	return RelationshipRules.tier_for_affection(affection)

func relationship_rank(tier_id: String) -> int:
	return RelationshipRules.relationship_rank(tier_id)

func _relationship_tiers() -> Array:
	var configured: Variant = _relationship_config.get("tiers", DEFAULT_RELATIONSHIP_TIERS)
	if configured is Array and not configured.is_empty():
		return configured
	return DEFAULT_RELATIONSHIP_TIERS

func _apply_deltas(deltas: Dictionary, reason: String, day_key: String = "") -> bool:
	var changed := false
	for need_name in deltas.keys():
		var key := str(need_name)
		if not _values.has(key):
			continue
		var previous := float(_values[key])
		var delta := float(deltas[need_name])
		if key == "affection":
			delta = _allowed_affection_delta(delta, day_key)
		var next_value := _clamp_need(previous + delta)
		if not is_equal_approx(previous, next_value):
			_values[key] = next_value
			if key == "affection":
				_record_affection_delta(next_value - previous)
			changed = true
	if changed:
		_refresh_relationship_tier()
		values_changed.emit(snapshot(), reason)
	return changed

func _allowed_affection_delta(delta: float, day_key: String) -> float:
	_ensure_relationship_day(day_key)
	if delta > 0.0:
		return minf(delta, maxf(0.0, RelationshipRules.DAILY_POSITIVE_CAP - _positive_affection_today))
	if delta < 0.0:
		return -minf(-delta, maxf(0.0, RelationshipRules.DAILY_NEGATIVE_CAP - _negative_affection_today))
	return 0.0

func _record_affection_delta(delta: float) -> void:
	if delta > 0.0:
		_positive_affection_today = minf(RelationshipRules.DAILY_POSITIVE_CAP, _positive_affection_today + delta)
	elif delta < 0.0:
		_negative_affection_today = minf(RelationshipRules.DAILY_NEGATIVE_CAP, _negative_affection_today - delta)

func _refresh_relationship_tier() -> void:
	var previous := _current_relationship_tier
	var current := RelationshipRules.tier_with_hysteresis(previous, get_need("affection"))
	_current_relationship_tier = current
	if not previous.is_empty() and previous != current:
		relationship_tier_changed.emit(previous, current, get_need("affection"))

func _ensure_relationship_day(explicit_day_key: String = "") -> void:
	var current_day := explicit_day_key.strip_edges()
	if current_day.is_empty():
		current_day = Time.get_date_string_from_system()
	if _relationship_day_key == current_day:
		return
	_relationship_day_key = current_day
	_positive_affection_today = 0.0
	_negative_affection_today = 0.0

static func _clamp_need(value: float) -> float:
	return clampf(value, MIN_VALUE, MAX_VALUE)
