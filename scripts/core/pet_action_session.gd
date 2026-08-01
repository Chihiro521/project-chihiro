class_name PetActionSession
extends RefCounted

signal phase_changed(previous: String, current: String, clip: String)
signal session_interrupted(kind: String, resume_allowed: bool)
signal session_completed(outcome: String)

const PRIORITIES := {
	"gaze": 100,
	"autonomous": 200,
	"window_move": 300,
	"direct_interaction": 400,
	"menu": 400,
	"platform_lost": 500,
	"dragging": 600,
	"fullscreen": 700,
}

var _intent: Dictionary = {}
var _session: Dictionary = {}
var _phase := "inactive"
var _active := false
var _current_priority := 0
var _started_ms := 0
var _phase_started_ms := 0
var _interrupted_by := ""
var _resume_allowed := false
var _completion_outcome := ""
var _finish_pending := false

static func priority_for(kind: String) -> int:
	return int(PRIORITIES.get(kind, 0))

func begin(intent: Dictionary, now_ms: int = -1) -> bool:
	if intent.is_empty() or str(intent.get("id", "")).is_empty():
		return false
	if _active:
		_complete("replaced")
	_intent = intent.duplicate(true)
	var session_value: Variant = _intent.get("session", {})
	_session = session_value.duplicate(true) if session_value is Dictionary else {}
	_current_priority = _coerce_priority(_intent.get("priority", "autonomous"))
	_interrupted_by = ""
	_resume_allowed = false
	_completion_outcome = ""
	_finish_pending = false
	_active = true
	_started_ms = _resolve_now(now_ms)
	if str(_session.get("type", "sequence")) == "one_shot":
		_set_phase("one_shot", _resolve_now(now_ms))
	elif not str(_session.get("enter", "")).is_empty():
		_set_phase("enter", _resolve_now(now_ms))
	elif not str(_session.get("loop", "")).is_empty():
		_set_phase("loop", _resolve_now(now_ms))
	elif not str(_session.get("exit", "")).is_empty():
		_set_phase("exit", _resolve_now(now_ms))
	else:
		_set_phase("one_shot", _resolve_now(now_ms))
	if current_clip().is_empty():
		_complete("invalid")
		return false
	return true

func tick(now_ms: int = -1) -> Dictionary:
	if not _active:
		return snapshot()
	var max_duration_ms := int(_session.get("max_duration_ms", 0))
	if max_duration_ms > 0 and _resolve_now(now_ms) - _started_ms >= max_duration_ms:
		if not str(_session.get("exit", "")).is_empty():
			request_finish(now_ms)
		else:
			_complete("timeout")
	return snapshot()

func on_clip_finished(now_ms: int = -1) -> Dictionary:
	if not _active:
		return snapshot()
	var resolved_now := _resolve_now(now_ms)
	match _phase:
		"enter":
			if not str(_session.get("loop", "")).is_empty():
				_set_phase("loop", resolved_now)
			elif not str(_session.get("exit", "")).is_empty():
				_set_phase("exit", resolved_now)
			else:
				_complete("completed")
		"loop":
			pass
		"one_shot":
			_complete("completed")
		"exit":
			_complete("interrupted" if not _interrupted_by.is_empty() else "completed")
	return snapshot()

func request_finish(now_ms: int = -1) -> bool:
	if not _active:
		return false
	if _phase == "exit":
		return true
	if not str(_session.get("exit", "")).is_empty():
		if _phase == "loop":
			_finish_pending = true
		else:
			_set_phase("exit", _resolve_now(now_ms))
	else:
		_complete("completed")
	return true

func on_loop_boundary(now_ms: int = -1) -> bool:
	if not _active or _phase != "loop" or not _finish_pending:
		return false
	_finish_pending = false
	_set_phase("exit", _resolve_now(now_ms))
	return true

func request_interrupt(kind: String, context: Dictionary = {}, now_ms: int = -1) -> Dictionary:
	var incoming_priority := priority_for(kind)
	var decision := {
		"accepted": false,
		"kind": kind,
		"incoming_priority": incoming_priority,
		"current_priority": _current_priority,
		"resume_allowed": false,
		"next_clip": current_clip(),
		"phase_changed": false,
	}
	if not _active or incoming_priority <= _current_priority:
		return decision
	_interrupted_by = kind
	var interrupt_mode := str(_session.get("interrupt_mode", _intent.get("interrupt_policy", "return_idle")))
	var resume_policy := str(_intent.get("resume_policy", "never"))
	_resume_allowed = (interrupt_mode == "resume_if_platform_valid" or resume_policy == "platform_valid") and bool(context.get("platform_valid", false)) and kind != "platform_lost"
	decision["accepted"] = true
	decision["resume_allowed"] = _resume_allowed
	session_interrupted.emit(kind, _resume_allowed)
	if interrupt_mode == "wake_then_idle" and not str(_session.get("exit", "")).is_empty():
		if _phase == "loop":
			_finish_pending = true
		else:
			_set_phase("exit", _resolve_now(now_ms))
			decision["phase_changed"] = true
	else:
		_complete("interrupted")
	decision["next_clip"] = current_clip()
	return decision

func resume(context: Dictionary = {}, now_ms: int = -1) -> bool:
	if _active or not _resume_allowed or not bool(context.get("platform_valid", false)):
		return false
	_active = true
	_completion_outcome = ""
	_interrupted_by = ""
	_resume_allowed = false
	if not str(_session.get("loop", "")).is_empty():
		_set_phase("loop", _resolve_now(now_ms))
	else:
		_set_phase("one_shot", _resolve_now(now_ms))
	return not current_clip().is_empty()

func has_resumable_session() -> bool:
	return not _active and _resume_allowed and not _intent.is_empty()

func discard_resume() -> void:
	_resume_allowed = false
	_interrupted_by = ""
	_intent.clear()
	_session.clear()

func is_active() -> bool:
	return _active

func current_phase() -> String:
	return _phase

func finish_pending() -> bool:
	return _finish_pending

func current_clip() -> String:
	match _phase:
		"enter", "loop", "exit":
			return str(_session.get(_phase, ""))
		"one_shot":
			return str(_session.get("clip", _intent.get("clip", _intent.get("action", ""))))
	return ""

func intent_id() -> String:
	return str(_intent.get("id", ""))

func snapshot() -> Dictionary:
	return {
		"intent_id": intent_id(),
		"state": str(_intent.get("state", "")),
		"phase": _phase,
		"clip": current_clip(),
		"active": _active,
		"priority": _current_priority,
		"started_ms": _started_ms,
		"phase_started_ms": _phase_started_ms,
		"interrupted_by": _interrupted_by,
		"resume_allowed": _resume_allowed,
		"outcome": _completion_outcome,
		"finish_pending": _finish_pending,
	}

func _set_phase(next_phase: String, now_ms: int) -> void:
	var previous := _phase
	_phase = next_phase
	if _phase != "loop":
		_finish_pending = false
	_phase_started_ms = now_ms
	phase_changed.emit(previous, _phase, current_clip())

func _complete(outcome: String) -> void:
	_active = false
	_finish_pending = false
	_phase = "completed"
	_completion_outcome = outcome
	session_completed.emit(outcome)

func _coerce_priority(value: Variant) -> int:
	if value is int or value is float:
		return int(value)
	return priority_for(str(value))

func _resolve_now(now_ms: int) -> int:
	return now_ms if now_ms >= 0 else Time.get_ticks_msec()
