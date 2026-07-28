class_name PetNeedsModel
extends RefCounted

signal values_changed(values: Dictionary, reason: String)

const MIN_VALUE := 0.0
const MAX_VALUE := 100.0
const NEED_NAMES := ["energy", "boredom", "curiosity", "irritation", "affection"]
const DEFAULT_INITIAL := {
	"energy": 72.0,
	"boredom": 20.0,
	"curiosity": 35.0,
	"irritation": 0.0,
	"affection": 40.0,
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

func _init(profile: Dictionary = {}) -> void:
	configure(profile)

func configure(profile: Dictionary, reset_values: bool = true) -> void:
	var needs_value: Variant = profile.get("needs", profile)
	_needs_config = needs_value.duplicate(true) if needs_value is Dictionary else {}
	var relationship_value: Variant = profile.get("relationship", {})
	_relationship_config = relationship_value.duplicate(true) if relationship_value is Dictionary else {}
	if reset_values:
		reset_session()

func reset_session(persistent_affection: float = -1.0) -> void:
	_values = DEFAULT_INITIAL.duplicate(true)
	var configured_initial: Variant = _needs_config.get("initial", {})
	if configured_initial is Dictionary:
		for need_name in NEED_NAMES:
			if configured_initial.has(need_name):
				_values[need_name] = _clamp_need(float(configured_initial[need_name]))
	if persistent_affection >= MIN_VALUE:
		_values["affection"] = _clamp_need(persistent_affection)
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
	return _apply_deltas(scaled_effects, "event:%s" % event_name)

func set_need(need_name: String, amount: float, reason: String = "set") -> bool:
	if not _values.has(need_name):
		return false
	var next_value := _clamp_need(amount)
	if is_equal_approx(float(_values[need_name]), next_value):
		return false
	_values[need_name] = next_value
	values_changed.emit(snapshot(), reason)
	return true

func adjust_need(need_name: String, delta: float, reason: String = "adjust") -> bool:
	if not _values.has(need_name):
		return false
	return set_need(need_name, float(_values[need_name]) + delta, reason)

func get_need(need_name: String, fallback: float = 0.0) -> float:
	return float(_values.get(need_name, fallback))

func snapshot() -> Dictionary:
	return _values.duplicate(true)

func persistent_snapshot() -> Dictionary:
	return {"affection": get_need("affection")}

func restore_persistent(data: Dictionary) -> void:
	if data.has("affection"):
		set_need("affection", float(data["affection"]), "persistent_restore")

func relationship_tier() -> String:
	return relationship_tier_for(get_need("affection"))

func relationship_tier_for(affection: float) -> String:
	var tiers := _relationship_tiers()
	var result := str(tiers[0].get("id", "distant"))
	for tier in tiers:
		if affection >= float(tier.get("min", MIN_VALUE)):
			result = str(tier.get("id", result))
	return result

func relationship_rank(tier_id: String) -> int:
	var tiers := _relationship_tiers()
	for index in range(tiers.size()):
		if str(tiers[index].get("id", "")) == tier_id:
			return index
	return -1

func current_relationship_rank() -> int:
	return relationship_rank(relationship_tier())

func _relationship_tiers() -> Array:
	var configured: Variant = _relationship_config.get("tiers", DEFAULT_RELATIONSHIP_TIERS)
	if configured is Array and not configured.is_empty():
		return configured
	return DEFAULT_RELATIONSHIP_TIERS

func _apply_deltas(deltas: Dictionary, reason: String) -> bool:
	var changed := false
	for need_name in deltas.keys():
		var key := str(need_name)
		if not _values.has(key):
			continue
		var previous := float(_values[key])
		var next_value := _clamp_need(previous + float(deltas[need_name]))
		if not is_equal_approx(previous, next_value):
			_values[key] = next_value
			changed = true
	if changed:
		values_changed.emit(snapshot(), reason)
	return changed

static func _clamp_need(value: float) -> float:
	return clampf(value, MIN_VALUE, MAX_VALUE)
