class_name RideFeedbackController
extends RefCounted

## Pure-model reactions to a ridden window being moved or resized. Fed from the
## 33ms platform-track branch; returns reaction events for main.gd to map onto
## existing animation assets. All state is internal so the model is deterministic
## and unit-testable without a window world.

const MOVE_REACTION_COOLDOWN_MS := 10000.0
const FAST_DRAG_THRESHOLD_PX_PER_SEC := 400.0
const FAST_DRAG_SUSTAIN_MS := 200.0
const SETTLE_SILENCE_MS := 1500.0
const MOVE_THRESHOLD_PX := 2.0

const IDLE := 0
const MOVING := 1
const FAST := 2
const SETTLING := 3

var phase := IDLE

var _session_active := false
var _move_reacted_at := -INF
var _fast_accum_ms := 0.0
var _settle_accum_ms := 0.0
var _last_now_ms := 0.0
var _initialized := false


func reset() -> void:
	phase = IDLE
	_session_active = false
	_move_reacted_at = -INF
	_fast_accum_ms = 0.0
	_settle_accum_ms = 0.0
	_initialized = false


## Feed each track frame. prev_rect is the rect observed last frame, curr_rect the
## fresh one. standing_x is the pet foot position; seg_left/seg_right bound the
## standing top segment (foot space). Returns reaction events to apply:
##   start_move / wobble / settle / resize / restance
func update(now_ms: float, prev_rect: Rect2i, curr_rect: Rect2i, standing_x: float, seg_left: float, seg_right: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not _initialized:
		_last_now_ms = now_ms
		_initialized = true
		return events
	var delta_ms := maxf(0.0, now_ms - _last_now_ms)
	_last_now_ms = now_ms
	# Resize: dimensions changed while riding. If the standing point left the top
	# segment, restand to the nearest inside x; a vanished segment is handled by
	# track_platform loss, not here.
	if curr_rect.size != prev_rect.size:
		events.append({"kind": "resize"})
		if standing_x < seg_left or standing_x > seg_right:
			events.append({"kind": "restance", "x": clampf(standing_x, seg_left, seg_right)})
	# Motion: displacement beyond the threshold starts/continues a session.
	var displacement := Vector2i(curr_rect.position) - Vector2i(prev_rect.position)
	if Vector2(displacement).length() > MOVE_THRESHOLD_PX:
		if not _session_active:
			_session_active = true
			if now_ms - _move_reacted_at >= MOVE_REACTION_COOLDOWN_MS:
				events.append({"kind": "start_move"})
				_move_reacted_at = now_ms
		var speed := Vector2(displacement).length() / maxf(0.001, delta_ms / 1000.0)
		var was_fast := _fast_accum_ms >= FAST_DRAG_SUSTAIN_MS
		if speed > FAST_DRAG_THRESHOLD_PX_PER_SEC:
			_fast_accum_ms += delta_ms
		else:
			_fast_accum_ms = 0.0
		phase = FAST if _fast_accum_ms >= FAST_DRAG_SUSTAIN_MS else MOVING
		if phase == FAST and not was_fast:
			events.append({"kind": "wobble"})
		_settle_accum_ms = 0.0
	else:
		_fast_accum_ms = 0.0
		if _session_active:
			phase = SETTLING
			_settle_accum_ms += delta_ms
			if _settle_accum_ms >= SETTLE_SILENCE_MS:
				events.append({"kind": "settle"})
				_session_active = false
				_settle_accum_ms = 0.0
				phase = IDLE
		else:
			phase = IDLE
	return events
