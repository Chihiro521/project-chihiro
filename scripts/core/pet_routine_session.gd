class_name PetRoutineSession
extends RefCounted

signal step_changed(step: Dictionary, index: int)
signal routine_completed(goal_id: String, outcome: String)

var _goal: Dictionary = {}
var _steps: Array[Dictionary] = []
var _index := -1
var _active := false
var _paused := false
var _started_ms := 0
var _step_started_ms := 0
var _outcome := ""


func begin(goal: Dictionary, now_ms: int) -> bool:
	if goal.is_empty() or str(goal.get("id", "")).is_empty():
		return false
	var source_steps: Variant = goal.get("steps", [])
	if not source_steps is Array or source_steps.is_empty():
		return false
	_goal = goal.duplicate(true)
	_steps.clear()
	for value in source_steps:
		if value is Dictionary and not str(value.get("type", "")).is_empty():
			_steps.append(value.duplicate(true))
	if _steps.is_empty():
		return false
	_index = 0
	_active = true
	_paused = false
	_started_ms = now_ms
	_step_started_ms = now_ms
	_outcome = ""
	step_changed.emit(current_step(), _index)
	return true


func current_step() -> Dictionary:
	if not _active or _index < 0 or _index >= _steps.size():
		return {}
	return _steps[_index].duplicate(true)


func complete_step(outcome: String, now_ms: int) -> Dictionary:
	if not _active or _paused:
		return current_step()
	var step := current_step()
	if outcome not in _accepted_outcomes(step):
		finish("step_%s" % outcome)
		return {}
	_index += 1
	if _index >= _steps.size():
		finish("completed")
		return {}
	_step_started_ms = now_ms
	step_changed.emit(current_step(), _index)
	return current_step()


func tick(now_ms: int) -> void:
	if not _active or _paused:
		return
	var goal_timeout := int(_goal.get("max_duration_ms", 0))
	if goal_timeout > 0 and now_ms - _started_ms >= goal_timeout:
		finish("timeout")
		return
	var step_timeout := int(current_step().get("max_duration_ms", 0))
	if step_timeout > 0 and now_ms - _step_started_ms >= step_timeout:
		finish("step_timeout")


func interrupt(kind: String, resume_allowed := false) -> String:
	if not _active:
		return "inactive"
	if resume_allowed and kind in ["menu", "direct_interaction"]:
		_paused = true
		return "paused"
	finish("interrupted_%s" % kind)
	return "cancelled"


func resume(now_ms: int) -> bool:
	if not _active or not _paused:
		return false
	_paused = false
	_step_started_ms = now_ms
	step_changed.emit(current_step(), _index)
	return true


func finish(outcome: String) -> void:
	if not _active:
		return
	_active = false
	_paused = false
	_outcome = outcome
	routine_completed.emit(goal_id(), outcome)


func is_active() -> bool:
	return _active


func is_paused() -> bool:
	return _paused


func goal_id() -> String:
	return str(_goal.get("id", ""))


func goal() -> Dictionary:
	return _goal.duplicate(true)


func snapshot() -> Dictionary:
	return {
		"active": _active,
		"paused": _paused,
		"goal_id": goal_id(),
		"goal_name": str(_goal.get("name", "")),
		"step_index": _index,
		"step_count": _steps.size(),
		"step": current_step(),
		"started_ms": _started_ms,
		"step_started_ms": _step_started_ms,
		"outcome": _outcome,
	}


func _accepted_outcomes(step: Dictionary) -> Array[String]:
	var configured: Variant = step.get("accepted_outcomes", ["completed"])
	var result: Array[String] = []
	if configured is Array:
		for value in configured:
			result.append(str(value))
	return result

