class_name PetMouseGestureRecognizer
extends RefCounted

const FAST_MOVE_SPEED := 1200.0
const FAST_MOVE_COOLDOWN_MS := 650.0
const SPEED_SMOOTHING := 0.5
const DWELL_RADIUS := 12.0
const DWELL_DURATION_MS := 850.0
const SWEEP_HALF_WIDTH := 52.0
const SWEEP_VERTICAL_TOLERANCE := 72.0
const SWEEP_REVERSALS := 3
const SWEEP_WINDOW_MS := 1500.0
const SWEEP_COOLDOWN_MS := 1800.0
const CIRCLE_MIN_RADIUS := 34.0
const CIRCLE_MAX_RADIUS := 170.0
const CIRCLE_COMPLETION_TURNS := 0.82
const CIRCLE_MAX_DURATION_MS := 2800.0
const CIRCLE_COOLDOWN_MS := 2000.0

var _last_sample: Dictionary = {}
var _smoothed_velocity := Vector2.ZERO
var _last_fast_move_at := -INF
var _dwell_anchor: Variant = null
var _dwell_started_at := 0.0
var _dwell_emitted := false
var _sweep_visits: Array[Dictionary] = []
var _last_sweep_at := -INF
var _circle: Dictionary = {}
var _last_circle_at := -INF

func update(point: Vector2, time_ms: float, focus: Variant = null) -> Dictionary:
	var gestures: Array[Dictionary] = []
	if not _last_sample.is_empty():
		var elapsed := time_ms - float(_last_sample.time)
		if elapsed > 0.0:
			var instantaneous := (point - Vector2(_last_sample.point)) * 1000.0 / elapsed
			_smoothed_velocity = _smoothed_velocity * (1.0 - SPEED_SMOOTHING) + instantaneous * SPEED_SMOOTHING
	var speed := _smoothed_velocity.length()
	if not _last_sample.is_empty() and speed >= FAST_MOVE_SPEED and time_ms - _last_fast_move_at >= FAST_MOVE_COOLDOWN_MS:
		gestures.append({"type": "fast_move", "time": time_ms, "speed_px_per_second": speed})
		_last_fast_move_at = time_ms
	_update_dwell(point, time_ms, gestures)
	_update_sweep(point, time_ms, focus, gestures)
	_update_circle(point, time_ms, focus, gestures)
	_last_sample = {"point": point, "time": time_ms, "focus": focus}
	return {"velocity": _smoothed_velocity, "speed": speed, "gestures": gestures}

func reset() -> void:
	_last_sample.clear()
	_smoothed_velocity = Vector2.ZERO
	_last_fast_move_at = -INF
	_dwell_anchor = null
	_dwell_started_at = 0.0
	_dwell_emitted = false
	_sweep_visits.clear()
	_last_sweep_at = -INF
	_circle.clear()
	_last_circle_at = -INF

func _update_dwell(point: Vector2, time_ms: float, gestures: Array[Dictionary]) -> void:
	if _dwell_anchor == null:
		_dwell_anchor = point
		_dwell_started_at = time_ms
		_dwell_emitted = false
		return
	if point.distance_to(Vector2(_dwell_anchor)) > DWELL_RADIUS:
		_dwell_anchor = point
		_dwell_started_at = time_ms
		_dwell_emitted = false
		return
	var duration := time_ms - _dwell_started_at
	if not _dwell_emitted and duration >= DWELL_DURATION_MS:
		gestures.append({"type": "dwell", "time": time_ms, "duration_ms": duration, "point": _dwell_anchor})
		_dwell_emitted = true

func _update_sweep(point: Vector2, time_ms: float, focus: Variant, gestures: Array[Dictionary]) -> void:
	if not focus is Vector2 or absf(point.y - focus.y) > SWEEP_VERTICAL_TOLERANCE:
		_sweep_visits.clear()
		return
	var offset_x: float = point.x - focus.x
	var side := -1 if offset_x <= -SWEEP_HALF_WIDTH else (1 if offset_x >= SWEEP_HALF_WIDTH else 0)
	if side == 0:
		return
	var retained: Array[Dictionary] = []
	for visit in _sweep_visits:
		if time_ms - float(visit.time) <= SWEEP_WINDOW_MS:
			retained.append(visit)
	_sweep_visits = retained
	if _sweep_visits.is_empty() or int(_sweep_visits.back().side) != side:
		_sweep_visits.append({"side": side, "time": time_ms})
	var reversals := maxi(0, _sweep_visits.size() - 1)
	if reversals >= SWEEP_REVERSALS and time_ms - _last_sweep_at >= SWEEP_COOLDOWN_MS:
		gestures.append({"type": "repeated_sweep", "time": time_ms, "reversals": reversals})
		_last_sweep_at = time_ms
		_sweep_visits = [{"side": side, "time": time_ms}]

func _update_circle(point: Vector2, time_ms: float, focus: Variant, gestures: Array[Dictionary]) -> void:
	if not focus is Vector2 or time_ms - _last_circle_at < CIRCLE_COOLDOWN_MS:
		_circle.clear()
		return
	var offset: Vector2 = point - focus
	var radius := offset.length()
	if radius < CIRCLE_MIN_RADIUS or radius > CIRCLE_MAX_RADIUS:
		_circle.clear()
		return
	var angle := atan2(offset.y, offset.x)
	if _circle.is_empty() or Vector2(_circle.focus).distance_to(focus) > 4.0 or time_ms - float(_circle.started_at) > CIRCLE_MAX_DURATION_MS:
		_circle = {"focus": focus, "started_at": time_ms, "last_angle": angle, "accumulated": 0.0}
		return
	var delta := _normalize_angle_delta(angle - float(_circle.last_angle))
	_circle.last_angle = angle
	if absf(delta) > PI * 0.6:
		_circle.accumulated = 0.0
		_circle.started_at = time_ms
		return
	_circle.accumulated = float(_circle.accumulated) + delta
	var turns := absf(float(_circle.accumulated)) / TAU
	if turns >= CIRCLE_COMPLETION_TURNS:
		gestures.append({
			"type": "circle",
			"time": time_ms,
			"direction": "clockwise" if float(_circle.accumulated) > 0.0 else "counterclockwise",
			"turns": turns,
		})
		_last_circle_at = time_ms
		_circle.clear()

func _normalize_angle_delta(value: float) -> float:
	var result := value
	while result > PI: result -= TAU
	while result < -PI: result += TAU
	return result

