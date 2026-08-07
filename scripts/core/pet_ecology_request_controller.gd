class_name PetEcologyRequestController
extends RefCounted

const DEFAULT_DEFER_MS := 30000

var _definitions: Dictionary = {}
var _pending: Dictionary = {}


func _init(profile: Dictionary = {}) -> void:
	configure(profile)


func configure(profile: Dictionary) -> void:
	_definitions.clear()
	for value in profile.get("requests", []):
		if value is Dictionary:
			var request_id := str(value.get("id", ""))
			if not request_id.is_empty():
				_definitions[request_id] = value.duplicate(true)


func evaluate(request_id: String, context: Dictionary, now_ms: int) -> Dictionary:
	if not _definitions.has(request_id):
		return _result(request_id, "refused", "unknown_request", now_ms)
	var definition: Dictionary = _definitions[request_id]
	for key in definition.get("requires", []):
		if not bool(context.get(str(key), false)):
			return _result(request_id, "refused", "target_unavailable", now_ms)
	if bool(context.get("fullscreen", false)) or bool(context.get("dragging", false)):
		return _defer(definition, request_id, context, now_ms, "system_busy")
	if bool(context.get("busy", false)):
		return _defer(definition, request_id, context, now_ms, "finishing_current_goal")
	var irritation := float(context.get("irritation", 0.0))
	var energy := float(context.get("energy", 100.0))
	if irritation >= float(definition.get("refuse_irritation", 70.0)):
		return _result(request_id, "refused", "irritated", now_ms)
	if energy < float(definition.get("min_energy", 0.0)):
		return _result(request_id, "refused", "too_tired", now_ms)
	_pending.clear()
	var accepted := _result(request_id, "accepted", "", now_ms)
	accepted["goal_id"] = str(definition.get("goal_id", ""))
	accepted["payload"] = context.get("payload", {}).duplicate(true) if context.get("payload", {}) is Dictionary else {}
	return accepted


func poll(context: Dictionary, now_ms: int) -> Dictionary:
	if _pending.is_empty():
		return {}
	if now_ms >= int(_pending.get("expires_at_ms", 0)):
		var expired := _pending.duplicate(true)
		_pending.clear()
		expired["status"] = "refused"
		expired["reason"] = "expired"
		return expired
	if bool(context.get("busy", false)) or bool(context.get("fullscreen", false)) or bool(context.get("dragging", false)):
		return {}
	var request_id := str(_pending.get("request_id", ""))
	var payload: Dictionary = _pending.get("payload", {}).duplicate(true)
	_pending.clear()
	var next_context := context.duplicate(true)
	next_context["payload"] = payload
	return evaluate(request_id, next_context, now_ms)


func cancel_pending() -> void:
	_pending.clear()


func snapshot() -> Dictionary:
	return _pending.duplicate(true)


func _defer(definition: Dictionary, request_id: String, context: Dictionary, now_ms: int, reason: String) -> Dictionary:
	var max_defer := int(definition.get("max_defer_ms", DEFAULT_DEFER_MS))
	_pending = _result(request_id, "deferred", reason, now_ms)
	_pending["expires_at_ms"] = now_ms + maxi(1, max_defer)
	_pending["goal_id"] = str(definition.get("goal_id", ""))
	_pending["payload"] = context.get("payload", {}).duplicate(true) if context.get("payload", {}) is Dictionary else {}
	return _pending.duplicate(true)


func _result(request_id: String, status: String, reason: String, now_ms: int) -> Dictionary:
	return {
		"request_id": request_id,
		"status": status,
		"reason": reason,
		"evaluated_at_ms": now_ms,
	}

