class_name ManualControlModel
extends RefCounted

const PetWallResolverScript := preload("res://scripts/core/pet_wall_resolver.gd")

## Reads a world field from either a plain Dictionary (legacy/tests) or a
## DesktopWorld (production), so callers can pass either. The model never mutates
## the caller's world: the collision lists are copied into the model's own working
## state (_walls/_platforms/...).
static func _read_world(world: Variant, key: String, default_value: Variant) -> Variant:
	if world is Dictionary:
		return (world as Dictionary).get(key, default_value)
	if world is DesktopWorld:
		return (world as DesktopWorld)._value(key, default_value)
	return default_value

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
const HOP_JUMP_MULTIPLIER := 1.5
## Horizontal drift factor while airborne (jump/fall): dir_x * flight_speed * factor.
const JUMP_AIR_CONTROL_FACTOR := 0.5
const DEFAULT_FOOT_OFFSET_X := 180.0
const DEFAULT_FOOT_OFFSET_Y := 356.0
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
var _walls := []
var _platforms := []
var _wall_x := 0.0
var _wall_top_y := 0.0
var _wall_bottom_y := 0.0
var _wall_handle := 0
var _wall_pid := 0
## Per-frame live wall fed by the host while climbing (smooth drag follow). The
## refresh-built `_walls` only move at the refresh cadence, which reads as
## teleporting on a fast drag; the live wall carries the window's current edge.
var _live_wall: Variant = {}
## Per-frame live VISIBLE top-edge segments for the standing window, fed by the
## host each tick (the window's live rect minus the cached front occluders, see
## WindowPlatformService.live_top_segment_planes). These replace the standing
## window's refresh-built segments so a dragged window carries the pet frame by
## frame AND an occluded standing point is dropped instead of kept on a full-edge
## plane. Empty when not standing / the window's top is fully covered.
var _live_platforms: Array = []
## Per-frame horizontal displacement of the standing window's live rect center (see
## WindowPlatformService.live_rect_delta_x). Nonzero while the window is being
## dragged, zero while it is static — the signal that gates whether a perch segment
## is trusted during a drag or re-anchored/fallen under static occlusion.
var _standing_plane_live_delta := 0.0
## Per-frame VERTICAL displacement of the standing window's live rect center (see
## WindowPlatformService.live_rect_delta_y). A vertical drag moves no X, so without
## this the model would read an upward drag as a static window and commit to the
## occlusion-grace fall the moment the top segment is transiently sliced — the pet
## gets "pushed off" by an upward drag (小窗向上移动一段距离).
var _standing_plane_live_delta_y := 0.0
## Pet-window-space x of the character's wall-facing (hand) edge for each climb
## side, fed by the host from the skin clips. The collision body is 110px wide and
## narrower than the pet window, so parking the body edge at the wall would leave
## the character floating inside — or past — the pane; anchoring the hand edge
## instead makes it hug the window's edge while climbing. Missing side -> current
## collision-flush behavior (byte-compatible legacy / test path).
var _climb_contact: Dictionary = {}
var _mount_pending := false
var _mount_clip := ""
var _standing_plane_handle := 0
var _standing_plane_pid := 0
var _landed_platform_handle := 0
var _hop_jump := false
## Set by queue_step_off() (double-tap S/down while standing on a window): the
## GROUND riding branch detaches from the plane and falls to the nearest lower
## visible surface instead of walking.
var _step_off_pending := false
## Horizontal-follow state for a dragged standing window: the pet rides the plane's
## center so moving the window carries it instead of stranding the foot outside the
## (stale) plane range and dropping it. `_standing_plane_tracked_handle` resets the
## delta baseline whenever the pet switches to a different plane. A window that
## teleports (center moved past TELEPORT_MIN_PX at TELEPORT_MIN_SPEED_PX_S in one
## tick) sets `_standing_plane_teleported` so the caller falls immediately instead
## of riding a stale plane.
var _standing_plane_tracked_handle := 0
var _standing_plane_prev_center := NAN
## Span (right - left) of the standing segment on the last tick `_follow_standing_plane`
## applied. A real drag translates the whole segment (span preserved), while an
## occlusion reshuffle splits/merges it (span changes) — the center jump there is
## pure noise that would teleport the pet sideways, so the follow only applies the
## center delta when the span is unchanged.
var _standing_plane_prev_span := NAN
## Milliseconds the standing plane has been absent (occluded/vanished) while the
## pet holds position; the pet commits to the fall once it exceeds OCCLUSION_GRACE_MS.
## Shared with the riding path in main.gd so both drop through the same grace.
var _standing_plane_gone_ms := 0.0
var _standing_plane_teleported := false
## Which top-edge segment (ordinal index within the window's platform list) the pet
## stands on. A window occluded into several top segments must be followed by the
## segment it actually stands on; first-match selection made the pet misjudge and
## follow/fall against segment 1. Kept sticky across drags so a moved segment is
## followed by its own center; reset whenever the pet switches planes.
var _standing_perch_index := -1
## Entry-state adoption: when the pet is (re)initialized at its current position
## (manual-control enter), the first tick must not snap it to the floor. This flag
## gates the one-shot adoption to the tick right after reset(). The autonomous
## climb reuses the same model without enabling it — the climb walks to its own
## wall from wherever it starts.
var _preserve_entry_position := false
var _entry_state_adopted := false
## The single occlusion-grace window shared by the standing path (this model) and
## the riding path (main.gd): while the foot's visible surface is absent the pet
## holds position; it commits to the fall once the surface stays gone past this.
## 1500ms = 3x the 500ms world-refresh cadence: a stale-cached occluder rect always
## gets a full refresh to clear before the grace fires, and the window absorbs
## transient UI (tooltips / context menus / IME candidates / notifications) that
## covers a standing point for ~0.5-1.5s without the support really being gone.
const OCCLUSION_GRACE_MS := 1500.0
const TELEPORT_MIN_PX := 300.0
const TELEPORT_MIN_SPEED_PX_S := 100000.0
## Vertical tolerance (window space) for the aligned standing transfer: when the
## current plane is gone but ANOTHER window's top edge sits at the pet's current
## height, the pet steps onto it instead of falling (等高转移).
const STANDING_PLANE_TOLERANCE_PX := 4.0
const ENTRY_PLANE_TOLERANCE_PX := 4.0
const ENTRY_FLOOR_TOLERANCE_PX := 1.0


func _init(start_position: Vector2 = Vector2.ZERO) -> void:
	position = start_position


func configure_oneshot_durations(values: Dictionary) -> void:
	for key in values.keys():
		_oneshot_ms[str(key)] = float(values[key])


## Enables the one-shot entry-state adoption for the tick right after the next
## reset(): the model then preserves the pet's current position instead of snapping
## to the floor. Set by the host before reset() when entering manual control.
func set_preserve_entry_position(value: bool) -> void:
	_preserve_entry_position = value


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
	_walls = []
	_platforms = []
	_live_platforms = []
	_standing_plane_live_delta = 0.0
	_standing_plane_live_delta_y = 0.0
	_wall_x = 0.0
	_wall_top_y = 0.0
	_wall_bottom_y = 0.0
	_wall_handle = 0
	_wall_pid = 0
	_mount_pending = false
	_mount_clip = ""
	_standing_plane_handle = 0
	_standing_plane_pid = 0
	_standing_plane_tracked_handle = 0
	_standing_plane_prev_center = NAN
	_standing_plane_gone_ms = 0.0
	_standing_plane_teleported = false
	_standing_perch_index = -1
	_entry_state_adopted = false
	_landed_platform_handle = 0
	_hop_jump = false
	_step_off_pending = false


func queue_jump() -> void:
	_jump_pending = true


## Requests detaching from the standing window (double-tap S/down). Only applies
## while grounded on a window plane; on the floor it is a no-op. The GROUND riding
## branch consumes it on the next tick and falls toward the nearest lower surface.
func queue_step_off() -> void:
	if subphase == GROUND and _standing_plane_handle != 0:
		_step_off_pending = true


func set_flight_mode(value: bool) -> void:
	_jump_pending = false
	if value:
		if subphase == FLIGHT:
			return
		# Lift off from any other state. flight_mode may already be true (e.g. a
		# climb that mounted leaves the flag on); re-entering FLIGHT keeps the
		# double-tap toggle responsive instead of silently early-returning.
		flight_mode = true
		if subphase == WALL:
			# Leave the wall and take off. Drop the climb geometry and any pending
			# attach/detach/mount so the FLIGHT branch (gated on not _attach_pending)
			# can run and the old corner clip does not keep the pet pinned to the pane.
			wall_side = 0
			_wall_x = 0.0
			_wall_top_y = 0.0
			_wall_bottom_y = 0.0
			_wall_handle = 0
			_wall_pid = 0
			_wall_release_cooldown_ms = DEFAULT_WALL_RELEASE_COOLDOWN_MS
			_attach_pending = false
			_attach_clip = ""
			_detach_outcome = ""
			_detach_clip = ""
			_mount_pending = false
			_mount_clip = ""
		subphase = FLIGHT
		vy = 0.0
		umbrella = false
		_fall_initialized = false
		_standing_plane_gone_ms = 0.0
		_start_oneshot("takeoff", "takeoff")
	else:
		if subphase != FLIGHT and not flight_mode:
			return  # not flying; nothing to cancel
		flight_mode = false
		if subphase in [FLIGHT, WALL]:
			subphase = FALL
			_fall_initialized = false
			_detach_outcome = ""
			_detach_clip = ""
			_attach_pending = false
			_attach_clip = ""
			vy = 0.0
			oneshot = ""
			oneshot_kind = ""
			oneshot_remaining_ms = 0.0
			_hop_jump = false
			_mount_pending = false
			_mount_clip = ""
		# GROUND/JUMP/LANDING/FALL: the flag is cleared; the current motion continues.


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


func finish_mount() -> void:
	_mount_pending = false
	_mount_clip = ""


func has_pending_mount() -> bool:
	return _mount_pending


func mount_clip() -> String:
	return _mount_clip


func standing_plane_handle() -> int:
	return _standing_plane_handle


func standing_plane_pid() -> int:
	return _standing_plane_pid


## A maximized window has replaced the visible ledge under the pet. This is not a
## transient live-query miss, so skip the normal occlusion grace and begin falling
## on this tick while preserving the current screen position.
func force_platform_loss(floor_y: float, umbrella_available: bool) -> bool:
	if _standing_plane_handle == 0:
		return false
	_standing_plane_handle = 0
	_standing_plane_pid = 0
	_standing_plane_tracked_handle = 0
	_standing_plane_prev_center = NAN
	_standing_plane_prev_span = NAN
	_standing_plane_gone_ms = 0.0
	_standing_plane_teleported = false
	_standing_perch_index = -1
	_step_off_pending = false
	_jump_pending = false
	_init_fall(floor_y, umbrella_available)
	subphase = FALL
	return true


## The wall the pet is attached to while climbing (0 when not in the WALL
## subphase). Lets the host feed a per-frame live wall so a dragged window carries
## the pet smoothly instead of teleporting at the refresh cadence.
func climbing_wall_handle() -> int:
	return _wall_handle if subphase == WALL else 0


func climbing_wall_pid() -> int:
	return _wall_pid if subphase == WALL else 0


func _start_attach(side: int, wall_x: float, clip: String, wall: Dictionary = {}) -> void:
	position.x = wall_x
	wall_side = side
	facing = side
	subphase = WALL
	_attach_pending = true
	_attach_clip = clip
	_wall_x = wall_x
	_wall_top_y = float(wall.get("top_y", 0.0))
	_wall_bottom_y = float(wall.get("bottom_y", 0.0))
	_wall_handle = int(wall.get("handle", 0))
	_wall_pid = int(wall.get("process_id", 0))


## `world` is a DesktopWorld or a legacy plain Dictionary (tests); both read
## through the same _read_world bridge. Fixed tuning is model-owned (constants);
## only the dynamic world fields are read per tick. The manual jump boost comes in
## via input["jump_boost"] (1.1 for keyboard control, absent/1.0 for the
## autonomous climb) instead of a context override.
func tick(delta: float, input: Dictionary, world: Variant) -> Dictionary:
	var dir_x := int(input.get("dir_x", 0))
	var dir_y := int(input.get("dir_y", 0))
	var floor_y := float(_read_world(world, "floor_y", position.y))
	var screen: Rect2 = _read_world(world, "screen", Rect2())
	var pet_size: Vector2 = _read_world(world, "pet_size", Vector2(360.0, 360.0))
	var walk_speed := DEFAULT_WALK_SPEED
	var flight_speed := DEFAULT_FLIGHT_SPEED
	var climb_speed := DEFAULT_CLIMB_SPEED
	var gravity := DEFAULT_GRAVITY
	var jump_vy := DEFAULT_JUMP_VY * float(input.get("jump_boost", 1.0))
	var wall_threshold := DEFAULT_WALL_THRESHOLD
	var umbrella_available := bool(_read_world(world, "umbrella_available", true))
	# Window-body collision world. When no walls/platforms are provided the model
	# falls back to the legacy screen-edge behavior verbatim (byte-compatible).
	var walls_value: Variant = _read_world(world, "walls", [])
	_walls = walls_value if walls_value is Array else []
	var platforms_value: Variant = _read_world(world, "platforms", [])
	_platforms = platforms_value if platforms_value is Array else []
	var live_value: Variant = _read_world(world, "live_wall", {})
	_live_wall = live_value if live_value is Dictionary else {}
	var live_platforms_value: Variant = _read_world(world, "live_platforms", [])
	_live_platforms = live_platforms_value if live_platforms_value is Array else []
	var live_delta_value: Variant = _read_world(world, "standing_plane_live_delta", 0.0)
	_standing_plane_live_delta = float(live_delta_value) if (live_delta_value is float or live_delta_value is int) else 0.0
	var live_delta_y_value: Variant = _read_world(world, "standing_plane_live_delta_y", 0.0)
	_standing_plane_live_delta_y = float(live_delta_y_value) if (live_delta_y_value is float or live_delta_y_value is int) else 0.0
	var climb_contact_value: Variant = _read_world(world, "climb_contact", {})
	_climb_contact = climb_contact_value if climb_contact_value is Dictionary else {}

	# While standing on a window, its per-frame visible segments override the
	# refresh-built ones (a dragged window carries the pet frame by frame, and an
	# occluded standing point is dropped rather than kept on a full-edge plane).
	# When not standing (or falling) the refresh world stays authoritative so
	# landings resolve against real visible segments only. While the window is being
	# DRAGGED (either axis), an empty live list still drops the standing window's
	# refresh planes: they are stale (old y), and a vertically-dragged window must
	# never leave the pet glued to the top edge it already left behind.
	if _standing_plane_handle != 0 and (not _live_platforms.is_empty() or _standing_plane_moving()):
		_merge_live_platforms()

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

	_adopt_entry_state(floor_y)

	match subphase:
		GROUND:
			# A standing plane outranks the wall-empty legacy floor path: when the pet
			# is on a window, the riding branch stays authoritative even if the window's
			# walls are currently occluded or collision is disabled (planes come from the
			# always-on platform list). The injected fallback plane then keeps it standing
			# through a transient occlusion instead of snapping it to the floor.
			if _standing_plane_handle == 0 and _walls.is_empty():
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
			else:
				if _standing_plane_handle != 0:
					# Double-tap S/down steps off the platform: detach and fall toward
					# the nearest lower visible surface instead of walking.
					if _step_off_pending:
						_step_off_pending = false
						_standing_plane_handle = 0
						_standing_plane_pid = 0
						_standing_plane_prev_center = NAN
						_standing_plane_gone_ms = 0.0
						_standing_perch_index = -1
						_init_fall(floor_y, umbrella_available)
						# Drop a hair below the plane so the first landing check does not
						# immediately re-land on the platform the pet just stepped off of
						# (land_on_platform crosses planes at previous_y <= plane_y).
						position.y += 1.0
						subphase = FALL
					else:
						_follow_standing_plane(delta)
						if _standing_plane_teleported:
							_standing_plane_handle = 0
							_standing_plane_pid = 0
							_standing_plane_prev_center = NAN
							_standing_plane_gone_ms = 0.0
							_init_fall(floor_y, umbrella_available)
							subphase = FALL
							_jump_pending = false
						else:
							var plane_state := _standing_plane_state()
							if plane_state.is_empty():
								if _standing_plane_moving():
									# The standing window is being dragged (its live center
									# differs from the cached refresh center in EITHER axis).
									# A momentarily absent standing segment is almost always a
									# live-query hiccup or a stale occluder rect, NOT a
									# genuinely lost foot — the window is still being carried.
									# Hold position without accruing grace so a frantic drag
									# (horizontal OR vertical) never squeezes the pet off; only
									# a STATIC window whose support is really gone starts the
									# fall (OCCLUSION_GRACE_MS below).
									_standing_plane_gone_ms = 0.0
									# A hold must never read as "stuck": the user can still
									# walk sideways off the dragging window.
									position.x += dir_x * walk_speed * delta
								else:
									# The plane vanished this tick — a transient mid-drag occlusion
									# (occluder rects are stale) or a genuinely gone window. Hold
									# position briefly (OCCLUSION_GRACE_MS) before committing to the
									# fall, matching the riding grace in main.gd.
									_standing_plane_gone_ms += delta * 1000.0
									if _standing_plane_gone_ms >= OCCLUSION_GRACE_MS:
										_standing_plane_handle = 0
										_standing_plane_pid = 0
										_standing_plane_gone_ms = 0.0
										_init_fall(floor_y, umbrella_available)
										subphase = FALL
								_jump_pending = false
							else:
								_standing_plane_gone_ms = 0.0
								position.y = float(plane_state.get("y", floor_y))
								if _jump_pending:
									_jump_pending = false
									subphase = JUMP
									# _hop_jump stays set for the whole arc: it both boosts this
									# jump's apex (to clear the short wall) and suppresses mid-jump
									# wall attach. It is cleared on landing (plane or floor).
									vy = jump_vy * (HOP_JUMP_MULTIPLIER if _hop_jump else 1.0)
									_start_oneshot("takeoff", "takeoff")
								else:
									# Walk along the plane, resolving OTHER windows' walls like
									# the floor path: a higher window whose top is within hop
									# reach hops onto it (staircase), one too high attaches as a
									# climb. The standing window's own fragment edges are NOT
									# climb targets — walking into them is walking off the ledge.
									# The resolver's `floor_y` is the FOOT's screen y (the walls are in
									# screen space), so the plane's foot-space y gets the foot offset
									# added — `short` then means "this other window's top is within
									# hop_reach above my feet".
									var plane_floor_y := float(plane_state.get("y", floor_y)) + DEFAULT_FOOT_OFFSET_Y
									var previous_foot := _foot_from_window(position)
									position.x += dir_x * walk_speed * delta
									var foot_to := _foot_from_window(position)
									var resolved := PetWallResolverScript.resolve_horizontal(
										previous_foot, foot_to,
										_foreign_walls(_walls, _standing_plane_handle, _standing_plane_pid),
										plane_floor_y, PetWallResolverScript.WALL_HOP_REACH_PX)
									position.x = Vector2(resolved.get("position", foot_to)).x - DEFAULT_FOOT_OFFSET_X
									var wall: Dictionary = resolved.get("wall", {})
									if not wall.is_empty():
										var side := int(wall.get("side", 0))
										if bool(wall.get("short", false)) and true:
											_jump_pending = true
											_hop_jump = true
										else:
											_start_attach(side, _attach_window_x(wall), "patrol_floor_to_wall_left_a" if side < 0 else "patrol_floor_to_wall_right_a", wall)
									elif foot_to.x < float(plane_state.get("left", 0.0)) or foot_to.x > float(plane_state.get("right", 0.0)):
										_standing_plane_handle = 0
										_standing_plane_pid = 0
										_standing_plane_prev_center = NAN
										_init_fall(floor_y, umbrella_available)
										subphase = FALL
				else:
					position.y = _ground_y(floor_y)
					if _jump_pending:
						_jump_pending = false
						subphase = JUMP
						# _hop_jump stays set for the whole arc: it both boosts this jump's
						# apex (to clear the short wall) and suppresses mid-jump wall attach.
						# It is cleared on landing (plane or floor).
						vy = jump_vy * (HOP_JUMP_MULTIPLIER if _hop_jump else 1.0)
						_start_oneshot("takeoff", "takeoff")
					else:
						var previous_foot := _foot_from_window(position)
						position.x += dir_x * walk_speed * delta
						var foot_to := _foot_from_window(position)
						var resolved := PetWallResolverScript.resolve_horizontal(previous_foot, foot_to, _walls, _model_floor_y(floor_y), PetWallResolverScript.WALL_HOP_REACH_PX)
						position.x = Vector2(resolved.get("position", foot_to)).x - DEFAULT_FOOT_OFFSET_X
						var wall: Dictionary = resolved.get("wall", {})
						if not wall.is_empty():
							var side := int(wall.get("side", 0))
							if bool(wall.get("short", false)) and true:
								_jump_pending = true
								_hop_jump = true
							else:
								_start_attach(side, _attach_window_x(wall), "patrol_floor_to_wall_left_a" if side < 0 else "patrol_floor_to_wall_right_a", wall)
		JUMP:
			if _walls.is_empty() and _platforms.is_empty():
				vy += gravity * delta
				var previous_y := position.y
				position.y += vy * delta
				position.x += dir_x * flight_speed * delta * JUMP_AIR_CONTROL_FACTOR
				if not _land_on_plane_or_floor(previous_y, floor_y):
					if position.x - left_edge <= wall_threshold and dir_x <= 0:
						# Jump into the screen edge: clamp horizontally, the arc continues
						# (a jump never climbs — not even a legacy screen edge).
						position.x = left_edge
					elif right_edge - position.x <= wall_threshold and dir_x >= 0:
						position.x = right_edge
			else:
				vy += gravity * delta
				var previous_y := position.y
				position.y += vy * delta
				position.x += dir_x * flight_speed * delta * JUMP_AIR_CONTROL_FACTOR
				if not _land_on_plane_or_floor(previous_y, floor_y) and not _hop_jump:
					# A jump hits a wall like a hop, not a climb: the horizontal motion
					# is clamped flush against the face (over the arc the pet either
					# clears a short top or falls back and climbs from the ground). No
					# _start_attach — a jump never latches onto a wall; only a ground
					# walk / flight approach attaches.
					var previous_foot := _foot_from_window(Vector2(position.x - dir_x * flight_speed * delta * JUMP_AIR_CONTROL_FACTOR, previous_y))
					var foot_to := _foot_from_window(position)
					var resolved := PetWallResolverScript.resolve_horizontal(previous_foot, foot_to, _walls, _model_floor_y(floor_y), PetWallResolverScript.WALL_HOP_REACH_PX)
					position.x = Vector2(resolved.get("position", foot_to)).x - DEFAULT_FOOT_OFFSET_X
		FLIGHT:
			if not _attach_pending:
				position += Vector2(dir_x, dir_y) * flight_speed * delta
				if _walls.is_empty():
					if _wall_release_cooldown_ms <= 0.0 and position.x - left_edge <= wall_threshold and dir_x <= 0:
						_start_attach(-1, left_edge, "patrol_balloon_arrive_left_a")
					elif _wall_release_cooldown_ms <= 0.0 and right_edge - position.x <= wall_threshold and dir_x >= 0:
						_start_attach(1, right_edge, "patrol_balloon_arrive_right")
				elif _wall_release_cooldown_ms <= 0.0:
					var previous_foot := _foot_from_window(position - Vector2(dir_x, dir_y) * flight_speed * delta)
					var foot_to := _foot_from_window(position)
					var resolved := PetWallResolverScript.resolve_horizontal(previous_foot, foot_to, _walls, _model_floor_y(floor_y), PetWallResolverScript.WALL_HOP_REACH_PX)
					var wall: Dictionary = resolved.get("wall", {})
					if not wall.is_empty():
						var side := int(wall.get("side", 0))
						_start_attach(side, _attach_window_x(wall), "patrol_balloon_arrive_left_a" if side < 0 else "patrol_balloon_arrive_right", wall)
		WALL:
			if not _wall_present():
				# 被爬窗口消失(移动/关闭/遮挡):不再把宠物钉在幽灵墙最后已知 x。
				# 镜像自主攀爬的墙消失守卫;手动控制此前没有,墙消失会软锁到完全
				# 不能移动。取消挂载中的 attach 再走 _detach_from_wall(高则 FALL,
				# 低则播 wall_to_floor 脱离 clip)。
				if _detach_outcome.is_empty():
					_attach_pending = false
					_attach_clip = ""
					_detach_from_wall(floor_y)
			elif _detach_outcome.is_empty() and not _attach_pending:
				_follow_wall_edge()
				# Legacy screen-edge climbs (no real wall) fall back to the screen edge
				# when the collision world is empty; a real-wall climb always follows
				# _wall_x (kept fresh by the live/refresh wall), even if the collision
				# world is momentarily empty mid-drag.
				var wall_x := _wall_x
				if _walls.is_empty() and _wall_handle == 0 and _wall_pid == 0:
					wall_x = left_edge if wall_side < 0 else right_edge
				position.x = wall_x
				position.y += dir_y * climb_speed * delta
				if dir_y > 0 and not _walls.is_empty() and _wall_bottom_y > 0.0 and position.y >= _wall_bottom_y - DEFAULT_FOOT_OFFSET_Y:
					_detach_from_wall(floor_y)
				elif dir_y > 0 and position.y >= floor_y:
					_step_off_to_ground(floor_y)
				elif not _walls.is_empty() and position.y <= _wall_top_y - DEFAULT_FOOT_OFFSET_Y:
					_start_mount()
				elif dir_x == -wall_side:
					_detach_from_wall(floor_y)
		FALL:
			if not _fall_initialized:
				_fall_initialized = true
				_init_fall(floor_y, umbrella_available)
			if umbrella:
				_fall_elapsed_ms += delta * 1000.0
				var progress := clampf(_fall_elapsed_ms / maxf(1.0, _fall_duration_ms), 0.0, 1.0)
				var previous_y := position.y
				position.y = lerpf(_fall_from_y, floor_y, PetUmbrellaFall.descent_progress(progress))
				position.x += dir_x * UMBRELLA_DRIFT_SPEED * delta
				# The descent eases out, so the pet only commits to the ground at
				# progress >= 1.0 (descent_progress is 1.0 exactly then); before that,
				# planes may still catch the fall but the floor-land is held back.
				_land_on_plane_or_floor(previous_y, floor_y, progress >= 1.0)
			else:
				vy += gravity * delta
				var previous_y := position.y
				position.y += vy * delta
				position.x += dir_x * flight_speed * delta * JUMP_AIR_CONTROL_FACTOR
				_land_on_plane_or_floor(previous_y, floor_y)
		LANDING:
			# The window geometry changes when the fall clip hands off to the land
			# clip; pin y to the floor every frame so the landing does not float.
			position.y = floor_y

	var clip := _clip_for(dir_x)
	var segment := ""
	if _mount_pending and not _mount_clip.is_empty():
		clip = _mount_clip
	elif _attach_pending and not _attach_clip.is_empty():
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

	var landed_handle := _landed_platform_handle
	_landed_platform_handle = 0
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
		"mount_pending": _mount_pending,
		"mount_clip": _mount_clip,
		"standing_plane_handle": _standing_plane_handle,
		"standing_plane_pid": _standing_plane_pid,
		"landed_platform_handle": landed_handle,
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


## Converts a window-space position (the pet window's top-left) to the absolute
## foot point. Window coordinates come from main.gd as the pet window position;
## the character docks bottom-center of that window.
func _foot_from_window(window_position: Vector2) -> Vector2:
	return Vector2(window_position.x + DEFAULT_FOOT_OFFSET_X, window_position.y + DEFAULT_FOOT_OFFSET_Y)


## Floor plane in FOOT space: main.gd reports `floor_y` in window space, but the
## wall resolver reasons about feet, so shift both the plane and the body up by
## the foot offset before comparing.
func _model_floor_y(floor_y: float) -> float:
	return floor_y + DEFAULT_FOOT_OFFSET_Y


## Window position that parks the pet at a wall. With a host-fed `climb_contact`
## for this side, the character's wall-facing (hand) edge is placed flush against
## the wall so it visibly hugs the pane while climbing (the collision body is
## narrower than the pet window, so body-flush parking would float the sprite
## inside the window). Without contact data it falls back to parking the body edge
## flush — the foot BODY_HALF_WIDTH beyond the wall plus the character's own x
## offset — which is the legacy/test behavior.
func _attach_window_x(wall: Dictionary) -> float:
	var side := int(wall.get("side", 0))
	var wall_x := float(wall.get("x", 0.0))
	if _climb_contact.has(side):
		return wall_x - float(_climb_contact[side])
	return wall_x - (DEFAULT_FOOT_OFFSET_X + side * PetWallResolverScript.BODY_HALF_WIDTH)


## While climbing, re-sync the stored wall geometry (_wall_x/top/bottom) so a
## dragged window carries the pet with it. The host feeds a per-frame `live_wall`
## (smooth drag follow, independent of the refresh cadence); when absent we fall
## back to the refresh-built collision world. The wall identity (handle,
## process_id, side) is captured at attach; if no edge matches we keep the last
## known x and the existing detach gates decide what happens. The legacy
## screen-edge attach (no wall dict -> handle/pid 0) never re-syncs: there is no
## real wall edge to follow.
func _follow_wall_edge() -> void:
	if _wall_handle == 0 and _wall_pid == 0:
		return
	var live: Dictionary = _live_wall if _live_wall is Dictionary else {}
	if not live.is_empty():
		if int(live.get("handle", 0)) == _wall_handle and int(live.get("process_id", 0)) == _wall_pid and int(live.get("side", 0)) == wall_side:
			_wall_x = _attach_window_x(live)
			_wall_top_y = float(live.get("top_y", _wall_top_y))
			_wall_bottom_y = float(live.get("bottom_y", _wall_bottom_y))
			return
	if _walls.is_empty():
		return
	for entry in _walls:
		if not entry is Dictionary:
			continue
		if int(entry.get("handle", 0)) != _wall_handle or int(entry.get("process_id", 0)) != _wall_pid:
			continue
		if int(entry.get("side", 0)) != wall_side:
			continue
		_wall_x = _attach_window_x(entry)
		_wall_top_y = float(entry.get("top_y", _wall_top_y))
		_wall_bottom_y = float(entry.get("bottom_y", _wall_bottom_y))
		return


## True while the climbed window still exists (live edge first, refresh world
## fallback). Mirrors the autonomous climb's wall guard (main.gd
## _wall_handle_present): when the climbed window is moved away/closed/cloaked the
## pet must not be pinned to a ghost edge. Presence is keyed on the HWND only — the
## same handle in either source means the window is still there, even if the live
## edge or the refresh wall disagrees on process_id (a same-handle/different-pid
## wall is a hijack attempt that _follow_wall_edge correctly refuses to follow, not
## a vanished window). Legacy screen-edge climbs (handle/pid 0) have no real window
## to track -> always present.
func _wall_present() -> bool:
	if _wall_handle == 0 and _wall_pid == 0:
		return true
	var live: Dictionary = _live_wall if _live_wall is Dictionary else {}
	if not live.is_empty() and int(live.get("handle", 0)) == _wall_handle:
		return true
	if _walls.is_empty():
		return false
	for entry in _walls:
		if not entry is Dictionary:
			continue
		if int(entry.get("handle", 0)) == _wall_handle:
			return true
	return false


## Plane identity is (handle, process_id); a missing pid on either side is 0, so
## legacy hand-built test planes (no pid key) still match a model standing pid of 0.
func _plane_matches(plane: Dictionary, handle: int, pid: int) -> bool:
	return int(plane.get("handle", 0)) == handle and int(plane.get("process_id", 0)) == pid


## Replaces the standing window's refresh-built segments with the per-frame visible
## segments fed by the host (live_top_segment_planes), keeping every other window's
## segments from the refresh world. Guards on _standing_plane_handle so a falling
## pet resolves landings against real visible segments only.
func _merge_live_platforms() -> void:
	var merged: Array = []
	for plane in _platforms:
		if not plane is Dictionary:
			continue
		if _plane_matches(plane as Dictionary, _standing_plane_handle, _standing_plane_pid):
			continue
		merged.append(plane)
	for live in _live_platforms:
		if not live is Dictionary:
			continue
		# Only the standing window's own live segments are merged in; a foreign
		# window's segments (never fed in production) must not evict the perch.
		if _plane_matches(live as Dictionary, _standing_plane_handle, _standing_plane_pid):
			merged.append(live)
	_platforms = merged


## Walls belonging to a DIFFERENT window than the standing one. The standing
## window's own fragment edges are its segment boundaries — walking into them is
## walking off the ledge (fall), not a climb target. Only other windows' walls are
## eligible for the staircase hop/climb.
func _foreign_walls(walls: Array, handle: int, pid: int) -> Array:
	if handle == 0:
		return walls
	var result: Array = []
	for wall in walls:
		if not wall is Dictionary:
			continue
		if int(wall.get("handle", 0)) == handle and int(wall.get("process_id", 0)) == pid:
			continue
		result.append(wall)
	return result


## Surface the pet's feet rest on, in window space. Stays on the standing plane
## until the foot leaves its x-span, then falls back to the floor.
func _ground_y(floor_y: float) -> float:
	if _standing_plane_handle == 0:
		return floor_y
	for plane in _platforms:
		if not _plane_matches(plane, _standing_plane_handle, _standing_plane_pid):
			continue
		var foot_x := _foot_from_window(position).x
		if foot_x >= float(plane.get("left", 0.0)) and foot_x <= float(plane.get("right", 0.0)):
			return float(plane.get("y", floor_y))
	return floor_y


## Entry-state adoption, run once on the tick right after reset(): the pet enters
## manual control from a normal state at its current position, and that position
## must be preserved — never snap it to the floor. If the feet already rest flush
## on a window plane (riding / standing / walking on a top edge), keep standing on
## it; otherwise, if the pet is above the ground, fall from the current height so
## a mid-air entry glides down instead of teleporting. Grounded entries adopt
## nothing and stay on the floor.
func _adopt_entry_state(floor_y: float) -> void:
	if not _preserve_entry_position or _entry_state_adopted or _standing_plane_handle != 0:
		return
	_entry_state_adopted = true
	var foot := _foot_from_window(position)
	for value in _platforms:
		if not value is Dictionary:
			continue
		var plane := value as Dictionary
		if absf(float(plane.get("y", 0.0)) - position.y) > ENTRY_PLANE_TOLERANCE_PX:
			continue
		var left := float(plane.get("left", 0.0))
		var right := float(plane.get("right", 0.0))
		if foot.x >= left and foot.x <= right:
			_standing_plane_handle = int(plane.get("handle", 0))
			_standing_plane_pid = int(plane.get("process_id", 0))
			_standing_plane_tracked_handle = 0
			_standing_plane_prev_center = NAN
			return
	if position.y < floor_y - ENTRY_FLOOR_TOLERANCE_PX:
		subphase = FALL
		_fall_initialized = false


## Follows a moved standing window: adds the plane's center delta to the pet so
## dragging the window carries it instead of stranding the foot outside the (stale)
## plane range and dropping it. Resets the delta baseline whenever the pet switches
## to a different (or no) plane. When the window teleports (center moved past
## TELEPORT_MIN_PX at TELEPORT_MIN_SPEED_PX_S in one tick) it sets
## `_standing_plane_teleported` so the caller falls immediately — the window is no
## longer the same perch. The first tick after a landing only records the baseline
## (NAN), so a freshly-mounted plane never misreads as a teleport.
func _follow_standing_plane(delta: float) -> void:
	_standing_plane_teleported = false
	if _standing_plane_handle != _standing_plane_tracked_handle:
		_standing_plane_tracked_handle = _standing_plane_handle
		_standing_plane_prev_center = NAN
		_standing_plane_prev_span = NAN
		_standing_perch_index = -1
	if _standing_plane_handle == 0:
		return
	var state := _standing_plane_state()
	if state.is_empty():
		return
	var left := float(state.get("left", 0.0))
	var right := float(state.get("right", 0.0))
	var center := (left + right) * 0.5
	var span := right - left
	if is_finite(_standing_plane_prev_center):
		# Follow only while the standing window is actually being DRAGGED (span
		# preserved — the whole segment translates). An occlusion reshuffle splits or
		# merges the segment and changes its span; the resulting center jump is pure
		# noise (a front window sliding over the top must not teleport the pet
		# sideways — the service's live_rect_delta_x documents exactly this segment-
		# center pollution). On a span change reset the baseline instead of moving.
		var reshuffled := is_finite(_standing_plane_prev_span) and not is_equal_approx(span, _standing_plane_prev_span)
		if not reshuffled:
			var center_delta := center - _standing_plane_prev_center
			var speed := absf(center_delta) / maxf(delta, 0.001)
			if absf(center_delta) > TELEPORT_MIN_PX and speed > TELEPORT_MIN_SPEED_PX_S:
				# Window teleported elsewhere: it is no longer the same perch. Leave the
				# pet in place so the caller drops it from where it actually stands.
				_standing_plane_teleported = true
				return
			position.x += center_delta
	_standing_plane_prev_center = center
	_standing_plane_prev_span = span


## Current standing-plane geometry, or {} when the plane is absent this tick. The
## standing window's per-frame visible segments (_platforms, merged from the host's
## live_top_segment_planes) are the authoritative standable surface: a top segment
## occluded by a front window is not in the list, so an occluded standing point
## returns {} and the caller's grace window drops the pet (visible-geometry
## semantics — no full-edge riding fallback). Selection order:
##   1. The tracked perch segment — the specific top segment the pet stands on (so
##      a window occluded into several segments is followed by the one it stands on,
##      not the first). Trusted only while the window is being dragged (live rect
##      center moved) OR the foot still lies inside it; a static window whose perch
##      stopped covering the foot means the segment was deleted by occlusion, so the
##      perch is reset and the foot re-anchors.
##   2. Foot re-anchor: whatever segment covers the foot now (sets the perch).
##   3. Aligned transfer (Tier 2, only while the window is NOT being dragged): the
##      perch segment was deleted by occlusion — a front window now covers the foot.
##      If that window's top edge is the SAME height as the pet's feet, stand
##      smoothly on it (handle/pid switch; _follow_standing_plane resets the drag
##      baseline via tracked_handle/prev_center). If the front top is HIGHER, no
##      plane is within tolerance and the caller's grace window drops the pet.
##   4. No segment covers the foot (occluded / hole / walked off) -> {}.
## Whether the standing window is being dragged right now, in EITHER axis. A
## vertical drag moves no X (live_rect_delta_x stays ~0); trusting only the X delta
## would read an upward drag as a static window and commit the pet to the occlusion
## grace the instant the top segment is transiently sliced (小窗向上移动一段距离).
func _standing_plane_moving() -> bool:
	return absf(_standing_plane_live_delta) > 0.5 or absf(_standing_plane_live_delta_y) > 0.5


func _standing_plane_state() -> Dictionary:
	var foot_x := _foot_from_window(position).x
	var window_moving := _standing_plane_moving()
	if _standing_perch_index >= 0:
		var perch_index := 0
		for plane in _platforms:
			if not _plane_matches(plane, _standing_plane_handle, _standing_plane_pid):
				continue
			if perch_index == _standing_perch_index:
				var left := float(plane.get("left", 0.0))
				var right := float(plane.get("right", 0.0))
				if window_moving or (foot_x >= left and foot_x <= right):
					return {
						"left": left,
						"right": right,
						"y": float(plane.get("y", 0.0)),
					}
				_standing_perch_index = -1
				break
			perch_index += 1
	var segment_index := 0
	for plane in _platforms:
		if not _plane_matches(plane, _standing_plane_handle, _standing_plane_pid):
			continue
		var left := float(plane.get("left", 0.0))
		var right := float(plane.get("right", 0.0))
		if foot_x >= left and foot_x <= right:
			_standing_perch_index = segment_index
			return {
				"left": left,
				"right": right,
				"y": float(plane.get("y", 0.0)),
			}
		segment_index += 1
	if not window_moving:
		var transfer := visible_plane_at(_platforms, foot_x, position.y, STANDING_PLANE_TOLERANCE_PX)
		if not transfer.is_empty():
			_standing_plane_handle = int(transfer.get("handle", 0))
			_standing_plane_pid = int(transfer.get("process_id", 0))
			_standing_plane_tracked_handle = 0
			_standing_plane_prev_center = NAN
			_standing_perch_index = -1
			return {
				"left": float(transfer.get("left", 0.0)),
				"right": float(transfer.get("right", 0.0)),
				"y": float(transfer.get("y", 0.0)),
			}
	return {}


## Scans EVERY visible top segment (not just the current standing window's) for one
## that covers foot_x and sits at foot_height_y (within tolerance). The occlusion
## pass guarantees at most one visible segment per x-height, so the first hit is the
## surface the pet's foot actually rests on. Shared by the model's aligned transfer
## above and the riding path in main.gd.
static func visible_plane_at(planes: Array, foot_x: float, foot_height_y: float, tolerance: float) -> Dictionary:
	for value in planes:
		if not value is Dictionary:
			continue
		var plane := value as Dictionary
		if absf(float(plane.get("y", 0.0)) - foot_height_y) > tolerance:
			continue
		if foot_x >= float(plane.get("left", 0.0)) and foot_x <= float(plane.get("right", 0.0)):
			return plane
	return {}


## The highest platform plane the foot's downward segment [previous_y, current_y]
## crosses. Planes below the segment start are ignored (that is the side the pet
## is leaving), matching how jump arcs land on top edges only on the descent. This
## is the single landing rule shared by the control model and the roam/throw
## descents in main.gd.
static func land_on_platform(previous_y: float, current_y: float, foot_x: float, planes: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_y := INF
	for value in planes:
		if not value is Dictionary:
			continue
		var plane := value as Dictionary
		var left := float(plane.get("left", 0.0))
		var right := float(plane.get("right", 0.0))
		if foot_x < left or foot_x > right:
			continue
		var plane_y := float(plane.get("y", 0.0))
		if plane_y >= previous_y and plane_y <= current_y and plane_y < best_y:
			best_y = plane_y
			best = plane
	return best


## Unifies the (previously duplicated) landing logic shared by jump arcs, umbrella
## descents and free falls: when the foot's downward segment [previous_y, current_y]
## crosses a visible platform plane, mount it (GROUND, handle/pid adopted, drag
## baseline reset, vy zeroed); otherwise, when the foot reaches the floor, land on
## it (LANDING + land one-shot). Returns true when a landing happened. `_hop_jump`
## is cleared in every case — a hop's boosted apex only lasts the one arc. The
## floor-land is gated by `allow_floor_land` so callers that keep the pet mid-air
## after the descent (the umbrella easing out) control exactly when it commits.
func _land_on_plane_or_floor(previous_y: float, floor_y: float, allow_floor_land: bool = true) -> bool:
	var plane := land_on_platform(previous_y, position.y, _foot_from_window(position).x, _platforms)
	if not plane.is_empty():
		position.y = float(plane.get("y", floor_y))
		subphase = GROUND
		_standing_plane_handle = int(plane.get("handle", 0))
		_standing_plane_pid = int(plane.get("process_id", 0))
		_standing_plane_tracked_handle = 0
		_landed_platform_handle = _standing_plane_handle
		_hop_jump = false
		vy = 0.0
		# Play the landing animation on a window too (the floor path lands with the
		# "land" one-shot via LANDING). Keep subphase=GROUND so the plane anchor is
		# not snapped to the floor like the LANDING branch would.
		_start_oneshot("land", "land")
		return true
	if allow_floor_land and position.y >= floor_y:
		position.y = floor_y
		_standing_plane_handle = 0
		_hop_jump = false
		subphase = LANDING
		_start_oneshot("land", "land")
		return true
	return false


## Climbed past the wall's top edge: stand on it. The mount clip (window_land_recover)
## plays while _mount_pending stays set; main.gd calls finish_mount() on CLIP_END.
## The climb x was visual-hug (character on the wall face, feet off the top surface),
## so re-anchor the foot onto the plane corner the pet reached: plane left for a
## left-face climb, plane right for a right-face climb. Missing plane falls back to
## the climb x and the standing grace window decides.
func _start_mount() -> void:
	_mount_pending = true
	_mount_clip = "window_land_recover"
	position.y = _wall_top_y - DEFAULT_FOOT_OFFSET_Y
	var side := wall_side
	# The stored climb x is the visual-hug position (window left flush against the
	# wall face), so recover the wall's actual edge x before choosing the anchor
	# segment. A window occluded into several segments has several candidate
	# corners; anchor to the segment whose edge the climb actually reached (edge
	# closest to the wall face), not the first matching segment. No matching
	# segment keeps the pre-loop position.x (the climb x) and the standing grace
	# window decides.
	var wall_edge_x := _wall_x
	if _climb_contact.has(side):
		wall_edge_x = _wall_x + float(_climb_contact[side])
	else:
		wall_edge_x = _wall_x + (DEFAULT_FOOT_OFFSET_X + side * PetWallResolverScript.BODY_HALF_WIDTH)
	var best_distance := INF
	for plane in _platforms:
		if not _plane_matches(plane, _wall_handle, _wall_pid):
			continue
		var anchor_x := float(plane.get("left", 0.0)) if side >= 0 else float(plane.get("right", 0.0))
		var distance := absf(anchor_x - wall_edge_x)
		if distance < best_distance:
			best_distance = distance
			position.x = anchor_x - DEFAULT_FOOT_OFFSET_X
	wall_side = 0
	subphase = GROUND
	_standing_plane_handle = _wall_handle
	_standing_plane_pid = _wall_pid
	_standing_plane_tracked_handle = 0
	vy = 0.0
