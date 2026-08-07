class_name ManualControlModel
extends RefCounted

## Pure movement/animation model for the "操控她" control mode.
## Sub-phases: ground / jump / flight / fall / wall / landing.
## No node dependencies — main.gd adapts the returned snapshot to the sprite player.
##
## Input contract: tick() takes held-axis input {"dir_x": -1|0|1, "dir_y": -1|0|1}.
## Discrete actions are applied before tick(): queue_jump() for a single jump tap,
## set_flight_mode(true/false) for the double-tap flight toggle.
##
## Wall rules:
## - ground walk into a wall / jump into a wall / flight near a wall all attach to
##   the wall (airborne attach switches straight to the climb loop; ground attach
##   plays the floor_to_wall corner transition first).
## - Detaching from the wall defers the state switch until the transition clip
##   actually finishes (finish_detach()). Branch on flight mode: flying → release a
##   balloon (patrol_balloon_depart) then fly; not flying → near the ground hops off
##   (patrol_wall_to_floor), high up falls (drag_fall).
##
## Fall rules:
## - A fall starting far enough above the ground (UMBRELLA_MIN_FALL_PX) engages the
##   umbrella: the descent is eased by PetUmbrellaFall and reports the umbrella flag
##   so main.gd can drive the umbrella_open/float/close visuals.

const GROUND := "ground"
const JUMP := "jump"
const FLIGHT := "flight"
const FALL := "fall"
const WALL := "wall"
const LANDING := "landing"

const DEFAULT_WALK_SPEED := 120.0
const DEFAULT_FLIGHT_SPEED := 180.0
const DEFAULT_CLIMB_SPEED := 68.0
const DEFAULT_GRAVITY := 1600.0
const DEFAULT_JUMP_VY := -520.0
const DEFAULT_WALL_THRESHOLD := 40.0
const DEFAULT_WALL_RELEASE_COOLDOWN_MS := 3000.0
const WALL_LOW_DETACH_PX := 120.0
const UMBRELLA_MIN_FALL_PX := 140.0
const UMBRELLA_DRIFT_SPEED := 90.0
const DEFAULT_ONESHOT_MS := {
	"takeoff": 290.0,
	"land": 720.0,
}

var position := Vector2.ZERO
var facing := 1
var subphase := GROUND
var flight_mode := false
var wall_side := 0
var vy := 0.0
var umbrella := false
var oneshot := ""
var oneshot_kind := ""
var oneshot_remaining_ms := 0.0

var _oneshot_ms := DEFAULT_ONESHOT_MS.duplicate(true)
var _jump_pending := false
var _wall_release_cooldown_ms := 0.0
var _detach_outcome := ""
var _detach_clip := ""
var _detach_floor_y := 0.0
var _attach_pending := false
var _attach_clip := ""
var _fall_initialized := false
var _fall_from_y := 0.0
var _fall_duration_ms := 0.0
var _fall_elapsed_ms := 0.0


func _init(start_position: Vector2 = Vector2.ZERO) -> void:
	position = start_position


func configure_oneshot_durations(values: Dictionary) -> void:
	for key in values.keys():
		_oneshot_ms[str(key)] = float(values[key])


func reset(start_position: Vector2 = Vector2.ZERO) -> void:
	position = start_position
	facing = 1
	subphase = GROUND
	flight_mode = false
	wall_side = 0
	vy = 0.0
	umbrella = false
	oneshot = ""
	oneshot_kind = ""
	oneshot_remaining_ms = 0.0
	_jump_pending = false
	_wall_release_cooldown_ms = 0.0
	_detach_outcome = ""
	_detach_clip = ""
	_detach_floor_y = 0.0
	_attach_pending = false
	_attach_clip = ""
	_fall_initialized = false
	_fall_from_y = 0.0
	_fall_duration_ms = 0.0
	_fall_elapsed_ms = 0.0


func queue_jump() -> void:
	_jump_pending = true


func set_flight_mode(value: bool) -> void:
	if value == flight_mode:
		return
	flight_mode = value
	_jump_pending = false
	if value:
		if subphase in [GROUND, JUMP, LANDING]:
			subphase = FLIGHT
			vy = 0.0
			_start_oneshot("takeoff", "takeoff")
	else:
		if subphase in [FLIGHT, WALL]:
			subphase = FALL
			_fall_initialized = false
			_jump_pending = false
			_detach_outcome = ""
			_detach_clip = ""
			_attach_pending = false
			_attach_clip = ""
			vy = 0.0
			oneshot = ""
			oneshot_kind = ""
			oneshot_remaining_ms = 0.0


func finish_detach() -> void:
	var outcome := _detach_outcome
	_detach_outcome = ""
	_detach_clip = ""
	_wall_release_cooldown_ms = DEFAULT_WALL_RELEASE_COOLDOWN_MS
	if outcome == "flight":
		subphase = FLIGHT
	elif outcome == "ground":
		subphase = GROUND
		position.y = _detach_floor_y


func has_pending_detach() -> bool:
	return not _detach_outcome.is_empty()


func detach_clip() -> String:
	return _detach_clip


func finish_attach() -> void:
	_attach_pending = false
	_attach_clip = ""
	subphase = WALL


func has_pending_attach() -> bool:
	return _attach_pending


func attach_clip() -> String:
	return _attach_clip


func _start_attach(side: int, wall_x: float, clip: String) -> void:
	position.x = wall_x
	wall_side = side
	facing = side
	subphase = WALL
	_attach_pending = true
	_attach_clip = clip


func tick(delta: float, input: Dictionary, context: Dictionary) -> Dictionary:
	var dir_x := int(input.get("dir_x", 0))
	var dir_y := int(input.get("dir_y", 0))
	var floor_y := float(context.get("floor_y", position.y))
	var screen: Rect2 = context.get("screen", Rect2())
	var pet_size: Vector2 = context.get("pet_size", Vector2(360.0, 360.0))
	var walk_speed := float(context.get("walk_speed", DEFAULT_WALK_SPEED))
	var flight_speed := float(context.get("flight_speed", DEFAULT_FLIGHT_SPEED))
	var climb_speed := float(context.get("climb_speed", DEFAULT_CLIMB_SPEED))
	var gravity := float(context.get("gravity", DEFAULT_GRAVITY))
	var jump_vy := float(context.get("jump_vy", DEFAULT_JUMP_VY))
	var wall_threshold := float(context.get("wall_threshold", DEFAULT_WALL_THRESHOLD))
	var umbrella_available := bool(context.get("umbrella_available", true))

	if dir_x != 0:
		facing = dir_x

	if _wall_release_cooldown_ms > 0.0:
		_wall_release_cooldown_ms = maxf(0.0, _wall_release_cooldown_ms - delta * 1000.0)

	if oneshot_remaining_ms > 0.0:
		oneshot_remaining_ms -= delta * 1000.0
		if oneshot_remaining_ms <= 0.0:
			oneshot_remaining_ms = 0.0
			_finish_oneshot()

	var left_edge := screen.position.x
	var right_edge := screen.end.x - pet_size.x

	match subphase:
		GROUND:
			position.y = floor_y
			if _jump_pending:
				_jump_pending = false
				subphase = JUMP
				vy = jump_vy
				_start_oneshot("takeoff", "takeoff")
			else:
				position.x += dir_x * walk_speed * delta
				# Ground attach is ungated by the release cooldown: walking into the
				# wall is an explicit choice, so it re-climbs immediately. The cooldown
				# only protects the flight-mode auto-adhere from re-sucking the pet.
				if position.x - left_edge <= wall_threshold and dir_x < 0:
					_start_attach(-1, left_edge, "patrol_floor_to_wall_left_a")
				elif right_edge - position.x <= wall_threshold and dir_x > 0:
					_start_attach(1, right_edge, "patrol_floor_to_wall_right_a")
		JUMP:
			vy += gravity * delta
			position.y += vy * delta
			position.x += dir_x * flight_speed * delta * 0.5
			if position.y >= floor_y:
				position.y = floor_y
				subphase = LANDING
				_start_oneshot("land", "land")
			elif position.x - left_edge <= wall_threshold and dir_x <= 0:
				position.x = left_edge
				wall_side = -1
				facing = -1
				subphase = WALL
			elif right_edge - position.x <= wall_threshold and dir_x >= 0:
				position.x = right_edge
				wall_side = 1
				facing = 1
				subphase = WALL
		FLIGHT:
			if not _attach_pending:
				position += Vector2(dir_x, dir_y) * flight_speed * delta
				if _wall_release_cooldown_ms <= 0.0 and position.x - left_edge <= wall_threshold and dir_x <= 0:
					_start_attach(-1, left_edge, "patrol_balloon_arrive_left_a")
				elif _wall_release_cooldown_ms <= 0.0 and right_edge - position.x <= wall_threshold and dir_x >= 0:
					_start_attach(1, right_edge, "patrol_balloon_arrive_right")
		WALL:
			if _detach_outcome.is_empty() and not _attach_pending:
				var wall_x := left_edge if wall_side < 0 else right_edge
				position.x = wall_x
				position.y += dir_y * climb_speed * delta
				if dir_y > 0 and position.y >= floor_y:
					_step_off_to_ground(floor_y)
				elif dir_x == -wall_side:
					_detach_from_wall(floor_y)
		FALL:
			if not _fall_initialized:
				_fall_initialized = true
				_init_fall(floor_y, umbrella_available)
			if umbrella:
				_fall_elapsed_ms += delta * 1000.0
				var progress := clampf(_fall_elapsed_ms / maxf(1.0, _fall_duration_ms), 0.0, 1.0)
				position.y = lerpf(_fall_from_y, floor_y, PetUmbrellaFall.descent_progress(progress))
				position.x += dir_x * UMBRELLA_DRIFT_SPEED * delta
				if progress >= 1.0:
					position.y = floor_y
					subphase = LANDING
					_start_oneshot("land", "land")
			else:
				vy += gravity * delta
				position.y += vy * delta
				position.x += dir_x * flight_speed * delta * 0.5
				if position.y >= floor_y:
					position.y = floor_y
					subphase = LANDING
					_start_oneshot("land", "land")
		LANDING:
			# The window geometry changes when the fall clip hands off to the land
			# clip; pin y to the floor every frame so the landing does not float.
			position.y = floor_y

	var clip := _clip_for(dir_x)
	var segment := ""
	if _attach_pending and not _attach_clip.is_empty():
		clip = _attach_clip
	elif _detach_outcome != "" and not _detach_clip.is_empty():
		clip = _detach_clip
	elif oneshot_remaining_ms > 0.0 and not oneshot.is_empty():
		clip = oneshot
		if clip in ["takeoff", "land"]:
			segment = _facing_segment(facing)
	elif subphase == JUMP:
		clip = "takeoff"
		segment = _facing_segment(facing)
	elif subphase == FALL:
		clip = "drag_fall"
		segment = _facing_segment(facing)
	elif subphase == LANDING:
		clip = "land"
		segment = _facing_segment(facing)

	return {
		"position": position,
		"subphase": subphase,
		"clip": clip,
		"segment": segment,
		"facing": facing,
		"flight_mode": flight_mode,
		"wall_side": wall_side,
		"umbrella": umbrella,
		"fall_duration_ms": _fall_duration_ms,
		"detach_pending": not _detach_outcome.is_empty(),
		"detach_clip": _detach_clip,
	}


func _detach_from_wall(floor_y: float) -> void:
	var from_wall := wall_side
	wall_side = 0
	_wall_release_cooldown_ms = DEFAULT_WALL_RELEASE_COOLDOWN_MS
	facing = -from_wall
	_detach_floor_y = floor_y
	if flight_mode:
		# Flying detach defers the state switch: the balloon_depart corner animation
		# plays to completion while the pet is locked on the wall, then flight resumes.
		# The clip must match the WALL side (its anchor is drawn on that side), so the
		# body stays on the wall instead of being thrown off-screen by anchor compensation.
		_detach_outcome = "flight"
		_detach_clip = "patrol_balloon_depart_left" if from_wall < 0 else "patrol_balloon_depart_right"
	elif floor_y - position.y < WALL_LOW_DETACH_PX:
		_detach_outcome = "ground"
		_detach_clip = "patrol_wall_left_to_floor_right_a" if from_wall < 0 else "patrol_wall_right_to_floor_left_a"
	else:
		_detach_outcome = ""
		_detach_clip = ""
		subphase = FALL
		_fall_initialized = false
		vy = 0.0
		oneshot = ""
		oneshot_kind = ""
		oneshot_remaining_ms = 0.0


func _step_off_to_ground(floor_y: float) -> void:
	# Climbing down to the wall base hops off with the wall_to_floor detach clip,
	# ending standing on the ground (regardless of flight mode).
	var from_wall := wall_side
	position.y = floor_y
	wall_side = 0
	flight_mode = false
	_wall_release_cooldown_ms = DEFAULT_WALL_RELEASE_COOLDOWN_MS
	facing = -from_wall
	_detach_floor_y = floor_y
	_detach_outcome = "ground"
	_detach_clip = "patrol_wall_left_to_floor_right_a" if from_wall < 0 else "patrol_wall_right_to_floor_left_a"


func _init_fall(floor_y: float, umbrella_available: bool) -> void:
	umbrella = false
	_jump_pending = false
	var fall_distance := maxf(0.0, floor_y - position.y)
	if fall_distance >= UMBRELLA_MIN_FALL_PX and umbrella_available:
		umbrella = true
		_fall_from_y = position.y
		_fall_duration_ms = PetUmbrellaFall.duration_ms(fall_distance)
		_fall_elapsed_ms = 0.0
	vy = 0.0


func _clip_for(dir_x: int) -> String:
	match subphase:
		GROUND:
			return "idle" if dir_x == 0 else ("patrol_floor_left" if facing < 0 else "patrol_floor_right")
		JUMP:
			return "takeoff"
		FLIGHT:
			return "patrol_flight_left" if facing < 0 else "patrol_flight_right"
		WALL:
			return "patrol_wall_left_a" if wall_side < 0 else "patrol_wall_right_a"
		FALL:
			return "drag_fall"
		LANDING:
			return "land"
	return "idle"


func _start_oneshot(kind: String, clip: String) -> void:
	oneshot_kind = kind
	oneshot = clip
	oneshot_remaining_ms = float(_oneshot_ms.get(kind, 0.0))


func _finish_oneshot() -> void:
	oneshot = ""
	oneshot_kind = ""
	if subphase == LANDING:
		subphase = GROUND


func _facing_segment(value: int) -> String:
	return "left" if value < 0 else "right"
