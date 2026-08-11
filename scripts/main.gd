extends Node

const SKIN_MANIFEST := "res://skins/little-chihiro/pet.json"
const BEHAVIOR_PROFILE := "res://data/behavior_profile.json"
const DIALOGUE_DATA := "res://data/dialogue_zh_CN.json"
const ECOLOGY_PROFILE := "res://data/ecology_profile.json"
const DialogueSchedulerScript := preload("res://scripts/core/pet_dialogue_scheduler.gd")
const HabitatModelScript := preload("res://scripts/core/desktop_habitat_model.gd")
const EcologyClockScript := preload("res://scripts/core/pet_ecology_clock.gd")
const EcologyProgressionScript := preload("res://scripts/core/pet_ecology_progression.gd")
const EcologyRequestScript := preload("res://scripts/core/pet_ecology_request_controller.gd")
const GoalDirectorScript := preload("res://scripts/core/pet_goal_director.gd")
const RoutineSessionScript := preload("res://scripts/core/pet_routine_session.gd")
const ManualControlModelScript := preload("res://scripts/core/manual_control_model.gd")
const RoamPlannerScript := preload("res://scripts/core/pet_roam_planner.gd")
const PetWallResolverScript := preload("res://scripts/core/pet_wall_resolver.gd")
const WindowEventDebouncerScript := preload("res://scripts/core/window_event_debouncer.gd")
const RideFeedbackControllerScript := preload("res://scripts/core/ride_feedback_controller.gd")
const IDLE_BLINK_MIN_MS := 2400.0
const IDLE_BLINK_MAX_MS := 5200.0
const IDLE_WANDER_MIN_MS := 15000.0
const IDLE_WANDER_MAX_MS := 45000.0
const AUTO_HEAD_PAT_MS := 900.0
const FAST_MOVE_REACTION_DISTANCE := 220.0
const TRAVEL_FACING_DEAD_ZONE := 18.0
const MIN_EDGE_TRAVERSE_DISTANCE := 12.0
const LIFE_SAVE_INTERVAL_MS := 30000.0
const MECHANISM_DASHBOARD_REFRESH_MS := 200.0
const SPEECH_FOLLOW_INTERVAL_MS := 33.0
## How often the ridden window's rect is re-sampled while standing on it. The
## per-tick cost is one native single-window query plus a cached-snapshot
## platform rebuild, so aligning with the display refresh (16ms/60Hz) keeps the
## pet glued to the window without meaningful overhead.
const PLATFORM_TRACK_INTERVAL_MS := 16.0
const RAPID_POKE_WINDOW_MS := 10000.0
const ROUGH_DRAG_SPEED_PX_PER_SECOND := 1200.0
const SLIDE_GROUND_THRESHOLD := 20.0
const SLIDE_MIN_VELOCITY := 0.12
const SLIDE_VELOCITY_FACTOR := 0.6
const SLIDE_DECAY_RATE := 3.0
const SLIDE_STOP_SPEED := 20.0
const THROW_MIN_UP_VELOCITY := 0.2
const THROW_HEIGHT_FACTOR := 0.5
const THROW_MIN_HEIGHT := 150.0
const THROW_MAX_HEIGHT := 800.0
const THROW_DRIFT_FACTOR := 120.0
const MARKER_OFFSCREEN_MARGIN := 30.0
const MANUAL_WALK_SPEED := 120.0
const MANUAL_FLIGHT_SPEED := 180.0
const MANUAL_CLIMB_SPEED := 68.0
const MANUAL_GRAVITY := 1600.0
const MANUAL_JUMP_VY := -520.0
const MANUAL_WALL_THRESHOLD := 40.0
const MANUAL_DOUBLE_TAP_MS := 300.0
## Slightly higher jump apex under keyboard control, so a manual staircase hop
## clears a short wall the autonomous hop also clears. Applied only to the manual
## tick (the autonomous climb shares the context but keeps the base jump_vy).
const MANUAL_CONTROL_JUMP_BOOST := 1.1
## Riding grace before a foot covered by a front window drops the rider: a transient
## mid-drag occlusion (cached occluder rects stale) recovers at the refresh cadence,
## a persistent occlusion commits to the fall. Must exceed the 500ms world-refresh
## cadence so a stale occluder clears before the grace fires (1500ms = 3x); it also
## absorbs transient UI (tooltips/menus) that covers a standing point for ~0.5-1.5s.
## Same value as the model's standing grace (OCCLUSION_GRACE_MS) — one rule for both.
const RIDER_OCCLUSION_GRACE_MS := ManualControlModelScript.OCCLUSION_GRACE_MS
const CONTROL_QUIP_PROBABILITY := 0.4
const CONTROL_LONG_MS := 30000.0
const CONTROL_COMBO_MS := 800.0
const WINDOW_FOOT_OFFSET_X := 180.0
const WINDOW_FOOT_OFFSET_Y := 356.0
const WINDOW_HOP_REACH_PX := 120.0
## A window must exist for this long before its top is accepted as a standing
## surface, so a freshly-appeared popup (a toast, a tooltip, a splash) is never
## stood on. Only the standing list is gated — occlusion and walls always follow
## visible rendering.
const WINDOW_STAND_MIN_AGE_MS := 2000.0

# Cursor confiscation ("绝对没收"). VK_ESCAPE is reserved EXCLUSIVELY as this
# behavior's escape valve — it does nothing outside the confiscation hold.
const VK_ESCAPE := 0x1B
const CURSOR_CONFISCATE_CHASE_MS := 2600.0
const CURSOR_CONFISCATE_GRAB_RANGE_PX := 110.0
const CURSOR_CONFISCATE_HOLD_MS := 60000.0
const CURSOR_CONFISCATE_WALK_SPEED := 480.0

# Icon collection ("归档桌面图标"). Only the rendered desktop presentation is
# changed; .lnk/files are never touched. Ordinary icons move through the ListView,
# while keepsakes use a shell delete notification and return on refresh.
const ICON_BAG_CAPACITY := 3
const ICON_KEEPSAKE_PROBABILITY := 0.12
const ICON_COLLECT_WALK_SPEED := 420.0
const ICON_COLLECT_GRAB_MS := 800.0
# Reachability band for grabbing an icon. Mirrors the cursor-confiscation grab range:
# she can only collect icons her hands can actually reach from her current spot.
const ICON_COLLECT_GRAB_RANGE_PX := 130.0
const ICON_REACH_UP_PX := 90.0
const ICON_REACH_DOWN_PX := 40.0
const ICON_MAX_WALK_HORIZONTAL_PX := 1800.0
const ICON_NAV_ARC_HEIGHT_PX := 84.0
const ICON_COLLECT_FLY_SPEED := 300.0
const ICON_COLLECT_LANDING_MS := 520.0
const ICON_TRANSFER_TIMEOUT_MS := 5000.0
const ICON_ORDINARY_HOLD_MIN_MS := 60000.0
const ICON_ORDINARY_HOLD_MAX_MS := 120000.0
const ICON_KEEPSAKE_HOLD_MIN_MS := 180000.0
const ICON_KEEPSAKE_HOLD_MAX_MS := 300000.0
const ICON_RELEASE_COOLDOWN_MIN_MS := 20000.0
const ICON_RELEASE_COOLDOWN_MAX_MS := 30000.0
const ICON_RELEASE_RETRY_MIN_MS := 20000.0
const ICON_RELEASE_RETRY_MAX_MS := 30000.0
const ICON_RELEASE_SEARCH_RINGS := 8
const ICON_RECENT_TARGET_COOLDOWN_MS := 60000.0
const ICON_EXIT_RESTORE_TIMEOUT_MS := 3000.0
const ICON_DEFAULT_GRID_SPACING := Vector2(96.0, 96.0)
# The desktop ListView position is the icon-cell origin. Dropping relative to the
# pet's standing foot makes a reclaimed icon visibly land at her current location.
const ICON_DROP_FROM_FOOT := Vector2(-48.0, -72.0)
# Windows desktop icon cells are larger than the glyph itself. This hitbox is only
# used while the left button is held, so a normal click cannot become a gift.
const ICON_GIFT_HITBOX := Rect2(-18.0, -18.0, 96.0, 96.0)
const ICON_GIFT_DRAG_THRESHOLD_PX := 12.0
# Hand anchor is ~48px below the window top (the cursor-hold anchor), while her
# feet sit WINDOW_FOOT_OFFSET_Y below it. Horizontal slack absorbs the body's
# offset inside the window so the grab test does not depend on her facing.
const ICON_HAND_OFFSET_Y_PX := 48.0
const ICON_HORIZONTAL_SLACK_PX := WINDOW_FOOT_OFFSET_X
const ICON_BAG_PATH := "user://icon_bag.json"

const MENU_HEAD_PAT := 1
const MENU_POKE := 2
const MENU_CLOCK := 3
const MENU_RECENTER := 4
const MENU_HIDE := 5
const MENU_AUTO_WANDER := 6
const MENU_CURSOR_TRACKING := 7
const MENU_QUIT := 8
const MENU_SPEECH_BUBBLES := 9
const MENU_TITLE_AWARENESS := 10
const MENU_ACTION_SOUNDS := 11
const MENU_DEBUG_OVERLAY := 12
const MENU_ACTION_CATALOG := 13
const MENU_MECHANISM_DASHBOARD := 14
const MENU_REQUEST_COME := 15
const MENU_REQUEST_INSPECT := 16
const MENU_REQUEST_STAY := 17
const MENU_REQUEST_SET_HOME := 18
const MENU_REQUEST_RETURN_HOME := 19
const MENU_COMPANION_15 := 20
const MENU_COMPANION_30 := 21
const MENU_COMPANION_60 := 22
const MENU_FREE_ROAM := 23
const MENU_MANUAL_CONTROL := 24
const MENU_WINDOW_COLLISION := 25
const MENU_BACKPACK := 26
const MENU_RESTORE_ICONS := 27
const MENU_CURSOR_MISCHIEF := 28
const MENU_ICON_COLLECTION := 29
const TRAY_SHOW := 101
const TRAY_RECENTER := 104
const TRAY_AUTO_WANDER := 106
const TRAY_CURSOR_TRACKING := 107
const TRAY_QUIT := 108
const TRAY_SPEECH_BUBBLES := 109
const TRAY_TITLE_AWARENESS := 110
const TRAY_ACTION_SOUNDS := 111
const TRAY_ACTION_CATALOG := 112
const TRAY_MECHANISM_DASHBOARD := 113
const TRAY_MANUAL_CONTROL := 114
const TRAY_WINDOW_COLLISION := 115
const TRAY_BACKPACK := 116
const TRAY_RESTORE_ICONS := 117
const TRAY_CURSOR_MISCHIEF := 118
const TRAY_ICON_COLLECTION := 119

@onready var sprite_player: PetSpritePlayer = $SpritePlayer
@onready var desktop: DesktopWindowBridge = $DesktopWindow
@onready var menu: PopupMenu = $Menu
@onready var tray_menu: PopupMenu = $TrayMenu
@onready var speech_bubble: PetSpeechBubble = $SpeechBubble
@onready var offscreen_marker: PetOffscreenMarker = $OffscreenMarker
@onready var debug_overlay: PetDebugOverlay = $DebugOverlay
@onready var sfx_player: PetSfxPlayer = $SfxPlayer
@onready var action_catalog: PetActionCatalogPanel = $ActionCatalog
@onready var mechanism_dashboard: PetMechanismDashboard = $MechanismDashboard
@onready var backpack_panel: PetBackpackPanel = $BackpackPanel

var manifest: PetManifestData
var machine := PetStateMachine.new()
var gaze_tracker := PetGazeTracker.new()
var gesture_recognizer := PetMouseGestureRecognizer.new()
var needs_model: PetNeedsModel
var behavior_director: PetBehaviorDirector
var action_session := PetActionSession.new()
var state_store := PetStateStore.new()
var developer_state_store := PetStateStore.new("user://little_chihiro_state_dev.json")
var dialogue_director := PetDialogueDirector.new(21013)
var dialogue_scheduler := DialogueSchedulerScript.new()
var window_platform_service := WindowPlatformService.new()
var window_event_debouncer := WindowEventDebouncerScript.new()
var ride_feedback_controller := RideFeedbackControllerScript.new()
var habitat_model := HabitatModelScript.new()
var ecology_clock := EcologyClockScript.new()
var ecology_profile: Dictionary = {}
var ecology_progression
var ecology_request_controller
var goal_director
var routine_session := RoutineSessionScript.new()

var work_area := Rect2(0, 0, 1280, 720)
var position := Vector2.ZERO
var base_window_size := Vector2i(360, 360)
var pet_window_size := Vector2i(360, 360)
var render_box_lock: Variant = null
var motion: Dictionary = {}
var edge_session: Dictionary = {}
var edge_preparing := false
var edge_preparation_token := 0
var press: Dictionary = {}
var platforms: Array[WindowPlatform] = []
var window_bodies: Array[WindowBody] = []
## The one world the pet's platformer moves through (see desktop_world.gd): the
## riding/roam loop and the manual/autonomous-climb model both consume THIS object,
## refreshed from the WindowPlatformService occlusion pass.
var desktop_world := DesktopWorld.new()
var active_platform: WindowPlatform = null
var pending_platform: WindowPlatform = null
var platform_walk_motion: Dictionary = {}

var direction := 1
var facing := 1
var pending_facing := 1
var idle_pose_facing := 0
var idle_side_pose_deadline := -1.0
var side_pose_reverting := false
var airborne_phase := ""
var drag_fall_mode := "direct"
var umbrella_visual_phase := ""
var interaction_resume := "idle"
var menu_resume := "idle"
var current_intent: Dictionary = {}
var pending_front_intent: Dictionary = {}
var pending_front_handoff_clip := ""
var resumable_platform_intent: Dictionary = {}
var deferred_wake_action: Dictionary = {}
var persistent_state: Dictionary = {}
var interaction_delta := {
	"head_pats": 0, "pokes": 0, "rough_drags": 0, "positive": 0, "total": 0,
}
var home_anchor: Dictionary = {}
var ecology_step_mode := ""
var ecology_step_deadline_ms := -1
var ecology_step_context: Dictionary = {}
var active_request: Dictionary = {}
var companion_until_ms := -1
var last_ecology_time_period := ""
var using_developer_state := false
var returned_after_seconds := 0.0
var session_unrecorded_seconds := 0.0
var poke_timestamps: Array[float] = []
var head_pat_refused := false
var poke_visual_clip := "poke_cheek"
var last_stable_window_title := ""
var last_novel_window_title := ""
var last_foreground_app := ""

var drag_visual_phase := ""
var drag_motion_intent := "hold"
var slide_speed := 0.0
var throw_session: Dictionary = {}
var drag_travel_direction := 0
var drag_brake_direction := 1
var drag_last_horizontal_speed := 0.0
var drag_last_sample_at := 0.0

var auto_wander := true
var cursor_tracking := true
var speech_bubbles_enabled := true
var title_awareness := true
var action_sounds := true
var sfx_volume := 0.72
var window_collision_enabled := true
var cursor_mischief := true
var icon_collection := true
var gaze_engaged := false
var smoothed_cursor: Variant = null
var suspended := false
var hidden := false
var started := false

var wander_deadline := -1.0
var blink_deadline := -1.0
var head_pat_deadline := -1.0
var next_cursor_sample := 0.0
var next_system_check := 0.0
var next_debug_update := 0.0
var next_life_save := 0.0
var next_window_refresh := 0.0
var next_platform_track := 0.0
var _last_platform_track_at := -1.0
var last_platform_lost_reason := ""
var _rider_occlusion_ms := 0.0
## First-seen time (ms, Time.get_ticks_msec) per window handle, for the transient
## standing gate in _rebuild_platform_planes.
var _window_first_seen_ms: Dictionary = {}
var next_platform_swap := 0.0
var next_mechanism_dashboard_update := 0.0
var next_speech_follow := 0.0
var life_session_started_at_ms := 0.0
var last_click_at := -INF
var manual_control_model: Variant = null
var manual_last_up_tap := -INF
var manual_last_down_tap := -INF
var manual_last_flight_enter_ms := -INF
var _control_started_at := -1.0
var _control_long_emitted := false
var _last_control_clip := ""
var _last_control_segment := ""
var _last_control_reverse := false
var _last_control_subphase := ""
var _wall_frozen := false
var _control_fall_started_at := -1.0
# Set when a manual-control umbrella phase clip (open/float/close) finishes while
# its phase is still current; _apply_control_clip re-issues the clip so the fall
# keeps animating instead of freezing on the last frame of the phase.
var _umbrella_control_dirty := false
# True while the control result is an umbrella descent. The umbrella branch never
# updates _last_control_clip/_last_control_segment, so on leaving the descent the
# identity guard could swallow the post-landing clip (e.g. idle -> idle) and leave
# the sprite frozen on the last umbrella frame; see leaving_umbrella in
# _apply_control_clip.
var _umbrella_control_active := false
var roam_active := false
var roam_session: Dictionary = {}
# Ecology-travel walk leg: a same-tier alternative to the jump arc for grounded
# floor relocation. Driven in _update_ecology_walk while machine.state == "roam_walk";
# on arrival the pet reaches idle and _on_transition completes the travel step,
# exactly like the jump path. Cleared by _stop_roam so any interrupt drops it.
var ecology_walk_motion: Dictionary = {}
var _climb_model: Variant = null
var _ride_reaction_active := false
var _ride_reaction_clip := ""
var wall_climb_session: Dictionary = {}
## Last-seen rect for the manual-standing feedback session, so the ride feedback
## controller can compare against a real previous frame instead of the current one.
var _manual_feedback_handle := 0
var _manual_feedback_prev_rect := Rect2i()
var _manual_feedback_last_at := -INF

# Cursor confiscation ("绝对没收") — a bespoke phase machine, not a clip session.
# The WH_MOUSE_LL hook is only ever armed while cursor_capture_phase == "hold";
# _release_cursor_capture() is idempotent and called on every exit path.
var cursor_capture_phase := ""
var cursor_capture_started_ms := -1.0
var cursor_capture_end_reason := ""
var cursor_capture_anchor := Vector2.ZERO
var _cursor_capture_installed := false

# Icon collection ("归档桌面图标") — approach → grab → timed storage. Every
# icon that actually enters the bag is removed from the rendered desktop through
# a shell delete notification. icon_bag_entries is a session journal persisted
# only as crash recovery: normal exit restores all still-carried icons and clears
# it; a successfully placed icon is removed from the journal immediately.
var icon_collect_phase := ""
var icon_collect_phase_at := -1.0
var icon_collect_started_at := -1.0
var icon_collect_icon: Dictionary = {}
var icon_collect_target := Vector2.ZERO
var icon_collect_keepsaked := false
var icon_bag_entries: Array = []
# FIFO of deferred desktop-icon restore tasks. A task:
#   "refresh": bool        # issue refresh_desktop_icons() before waiting
#   "refresh_issued": bool # internal
#   "wait_names": Array    # every name must reappear before positioning
#   "position_map": Dictionary  # name -> Vector2 (final desktop position)
#   "positioned": Dictionary    # internal progress
#   "rehide_names": Array  # names to hide again after positioning (remaining bag icons)
#   "escalated": bool      # internal: force_desktop_icon_refresh already tried
#   "started_ms"/"timeout_ms": float
#   "done_kind"/"done_name": String
var icon_restore_queue: Array = []
var next_icon_restore_check_ms := -1.0
# A real desktop-icon drag is observed globally because the pet window is
# mouse-passthrough. Once the icon enters her rendered hit area and the button is
# released, it becomes the same recorded keepsake transfer as the backpack button.
var icon_gift_drag: Dictionary = {}
# Transaction for a visible give / reclaim animation. The manifest is written
# before the give animation starts; a close or interruption therefore cannot lose
# the hidden icon even if the clip is cut short.
var icon_transfer: Dictionary = {}
var next_icon_release_attempt_ms := -1.0
var icon_recent_targets: Dictionary = {}
var icon_exit_restore_started := false
# Multi-modal navigation for one collection run: {mode, platform, at}. Hop/fly
# drives a manual parabola (icon_collect_arc); walk reuses behavior_walk.
var icon_collect_nav: Dictionary = {}
var icon_collect_arc: Dictionary = {}
var icon_collect_nav_clip := ""

# Lightweight lerp walk shared by the two special behaviors (mirrors the roam
# system's walk_motion: from → to over a fixed duration, wall-blocked).
var behavior_walk: Dictionary = {}

func _ready() -> void:
	desktop.configure()
	var settings := desktop.load_settings()
	auto_wander = bool(settings.get("auto_wander", true))
	cursor_tracking = bool(settings.get("cursor_tracking", true))
	speech_bubbles_enabled = bool(settings.get("speech_bubbles", true))
	title_awareness = bool(settings.get("title_awareness", true))
	window_platform_service.capture_titles = title_awareness
	action_sounds = bool(settings.get("action_sounds", true))
	sfx_volume = float(settings.get("sfx_volume", 0.72))
	window_collision_enabled = bool(settings.get("window_collision", true))
	window_platform_service.set_collision_enabled(window_collision_enabled)
	cursor_mischief = bool(settings.get("cursor_mischief", true))
	icon_collection = bool(settings.get("icon_collection", true))
	sfx_player.configure(action_sounds, sfx_volume)
	_reconcile_icon_bag()
	backpack_panel.reclaim_requested.connect(_on_backpack_reclaim)
	backpack_panel.give_requested.connect(_on_backpack_give)
	backpack_panel.restore_all_requested.connect(_on_backpack_restore_all)
	manifest = PetManifestData.load_from_file(SKIN_MANIFEST)
	if not manifest.is_valid():
		for error in manifest.errors:
			push_error(error)
		get_tree().quit(1)
		return
	_initialize_life_systems()
	action_catalog.configure(manifest)
	mechanism_dashboard.simulation_rate_requested.connect(_on_ecology_rate_requested)
	machine.transitioned.connect(_on_transition)
	sprite_player.clip_completed.connect(_on_clip_completed)
	sprite_player.clip_changed.connect(_on_clip_changed)
	sprite_player.frame_changed.connect(_on_sprite_frame_changed)
	sprite_player.loop_boundary.connect(_on_sprite_loop_boundary)
	sprite_player.passthrough_polygon_changed.connect(_on_passthrough_polygon_changed)
	_setup_menus()
	base_window_size = PetRenderBox.resolve_size(manifest)
	pet_window_size = base_window_size
	desktop.set_size(pet_window_size)
	_refresh_habitat_screens()
	work_area = Rect2(desktop.get_work_area())
	window_platform_service.set_work_area(Rect2i(work_area))
	window_event_debouncer.set_bridge(window_platform_service.native_bridge())
	window_event_debouncer.start_event_hook()
	var restored = desktop.load_position()
	position = restored if restored is Vector2 else _default_position()
	position = _clamp_position(position, false)
	_apply_position()
	sprite_player.set_manifest(manifest)
	offscreen_marker.set_avatar_texture(_head_avatar_texture())
	started = true
	_next_system_check()
	_next_cursor_sample()
	next_window_refresh = _now_ms()
	next_platform_swap = _now_ms() + randf_range(45000.0, 90000.0)

func _process(delta: float) -> void:
	if not started:
		return
	var now := _now_ms()
	var event_deadline := window_event_debouncer.poll(now)
	if event_deadline < INF:
		next_window_refresh = minf(next_window_refresh, event_deadline)
	_update_window_platforms(now)
	_update_life_systems(delta, now)
	_update_dialogue_system(now)
	if not hidden and not suspended and desktop.is_visible() and not desktop.is_minimized():
		if offscreen_marker != null:
			var pet_screen := habitat_model.screen_for_pet_position(position, Vector2(pet_window_size))
			offscreen_marker.update_marker(position.x, pet_screen, position.y < pet_screen.position.y - MARKER_OFFSCREEN_MARGIN)
	else:
		speech_bubble.hide_message(true)
		if offscreen_marker != null:
			offscreen_marker.hide()
	_update_motion(now)
	if machine.state == "manual_control":
		_update_manual_control(delta, now)
	elif machine.state == "wall_climb":
		_update_autonomous_climb(delta, now)
	elif roam_active:
		_update_roam(now)
	elif not ecology_walk_motion.is_empty():
		_update_ecology_walk(now)
	elif machine.state == "cursor_confiscate":
		_update_cursor_confiscate(now)
	elif machine.state == "icon_collect":
		_update_icon_collect(now)
	_update_icon_gift_drag(now)
	_update_icon_transfer(now)
	_update_icon_release_scheduler(now)
	_update_icon_restore(now)
	_update_edge_patrol(now)
	_update_drag_idle(now)
	if machine.state == "drag_slide":
		_update_drag_slide(delta)
	elif machine.state == "drag_throw":
		_update_drag_throw(now)
	_update_long_press(now)
	if wander_deadline >= 0.0 and now >= wander_deadline:
		wander_deadline = -1.0
		_trigger_ambient_behavior()
	if blink_deadline >= 0.0 and now >= blink_deadline:
		blink_deadline = -1.0
		_trigger_idle_blink()
	if idle_side_pose_deadline >= 0.0 and now >= idle_side_pose_deadline:
		idle_side_pose_deadline = -1.0
		_revert_side_pose()
	if head_pat_deadline >= 0.0 and now >= head_pat_deadline:
		head_pat_deadline = -1.0
		_end_head_pat()
	if now >= next_cursor_sample:
		_next_cursor_sample()
		_sample_cursor_tracking(now)
	if now >= next_system_check:
		_next_system_check()
		_check_system_context()
	if debug_overlay.visible and now >= next_debug_update:
		next_debug_update = now + 250.0
		debug_overlay.set_snapshot({
			"state": machine.state,
			"intent": str(current_intent.get("id", "")),
			"clip": sprite_player.current_clip,
			"needs": needs_model.snapshot() if needs_model != null else {},
			"scores": behavior_director.last_candidates if behavior_director != null else [],
			"platform": active_platform.stable_id() if active_platform != null else "",
			"world": {
				"platforms": platforms.size(),
				"bodies": window_bodies.size(),
				"walls": desktop_world.walls.size(),
			},
			"bubble": speech_bubble.snapshot(),
			"dialogue": {
				"ambient_seconds": dialogue_scheduler.seconds_until_attempt(now),
				"event_cooldown_seconds": maxf(0.0, (dialogue_director.next_event_at_ms - now) / 1000.0),
			},
		})
	if mechanism_dashboard.visible and now >= next_mechanism_dashboard_update:
		next_mechanism_dashboard_update = now + MECHANISM_DASHBOARD_REFRESH_MS
		mechanism_dashboard.set_snapshot(_mechanism_snapshot(now))
	if speech_bubble.is_showing() and now >= next_speech_follow:
		next_speech_follow = now + SPEECH_FOLLOW_INTERVAL_MS
		speech_bubble.update_anchor(_speech_anchor_rect(), work_area)

func _input(event: InputEvent) -> void:
	if not started:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_F8:
			_show_mechanism_dashboard()
			get_viewport().set_input_as_handled()
			return
		if key.pressed and not key.echo and key.keycode == KEY_F9:
			action_catalog.show_catalog()
			get_viewport().set_input_as_handled()
			return
		if key.pressed and not key.echo and key.keycode == KEY_F10:
			debug_overlay.toggle()
			_sync_menu_checks()
			get_viewport().set_input_as_handled()
			return
		if machine.state == "manual_control" and key.pressed and not key.echo:
			match key.keycode:
				KEY_ESCAPE:
					_exit_manual_control()
					get_viewport().set_input_as_handled()
					return
				KEY_W, KEY_UP:
					_handle_manual_up_tap()
					get_viewport().set_input_as_handled()
					return
				KEY_S, KEY_DOWN:
					_handle_manual_down_tap()
					get_viewport().set_input_as_handled()
					return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			if not sprite_player.hit_test(button.position).is_empty():
				_open_context_menu(button.position)
				get_viewport().set_input_as_handled()
			return
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			if machine.state != "manual_control":
				_begin_press(button.position)
		else:
			_finish_press(false)
	elif event is InputEventMouseMotion and not press.is_empty():
		_update_press_drag()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_position()
		_save_user_settings()
		_save_life_state()
		_release_cursor_capture()
		_restore_carried_icons_on_exit()
		window_event_debouncer.stop_event_hook()
		get_tree().quit()

func _setup_menus() -> void:
	menu.add_item("摸摸头", MENU_HEAD_PAT)
	menu.add_item("戳脸", MENU_POKE)
	menu.add_item("看时间", MENU_CLOCK)
	menu.add_separator()
	menu.add_item("来我这里", MENU_REQUEST_COME)
	menu.add_item("观察当前窗口", MENU_REQUEST_INSPECT)
	menu.add_item("在这里待会", MENU_REQUEST_STAY)
	menu.add_item("把这里设为休息点", MENU_REQUEST_SET_HOME)
	menu.add_item("回休息点", MENU_REQUEST_RETURN_HOME)
	menu.add_item("陪伴 15 分钟", MENU_COMPANION_15)
	menu.add_item("陪伴 30 分钟", MENU_COMPANION_30)
	menu.add_item("陪伴 60 分钟", MENU_COMPANION_60)
	menu.add_item("自由活动", MENU_FREE_ROAM)
	menu.add_item("操控她😏", MENU_MANUAL_CONTROL)
	menu.add_separator()
	menu.add_item("回到中央", MENU_RECENTER)
	menu.add_item("暂时隐藏", MENU_HIDE)
	menu.add_separator()
	menu.add_item("查看背包", MENU_BACKPACK)
	menu.add_item("还原全部图标", MENU_RESTORE_ICONS)
	menu.add_separator()
	menu.add_check_item("自主闲逛", MENU_AUTO_WANDER)
	menu.add_check_item("光标跟随", MENU_CURSOR_TRACKING)
	menu.add_check_item("气泡台词", MENU_SPEECH_BUBBLES)
	menu.add_check_item("读取窗口标题", MENU_TITLE_AWARENESS)
	menu.add_check_item("窗口碰撞", MENU_WINDOW_COLLISION)
	menu.add_check_item("动作音效", MENU_ACTION_SOUNDS)
	menu.add_check_item("没收光标", MENU_CURSOR_MISCHIEF)
	menu.add_check_item("归档图标", MENU_ICON_COLLECTION)
	menu.add_item("人格机制…（F8）", MENU_MECHANISM_DASHBOARD)
	menu.add_item("动作总览…（F9）", MENU_ACTION_CATALOG)
	menu.add_check_item("调试信息（F10）", MENU_DEBUG_OVERLAY)
	menu.add_separator()
	menu.add_item("退出", MENU_QUIT)
	menu.id_pressed.connect(_on_menu_id_pressed)
	menu.popup_hide.connect(_on_context_menu_hidden)
	tray_menu.add_item("显示小千寻", TRAY_SHOW)
	tray_menu.add_item("回到中央", TRAY_RECENTER)
	tray_menu.add_separator()
	tray_menu.add_check_item("自主闲逛", TRAY_AUTO_WANDER)
	tray_menu.add_check_item("光标跟随", TRAY_CURSOR_TRACKING)
	tray_menu.add_check_item("气泡台词", TRAY_SPEECH_BUBBLES)
	tray_menu.add_check_item("读取窗口标题", TRAY_TITLE_AWARENESS)
	tray_menu.add_check_item("窗口碰撞", TRAY_WINDOW_COLLISION)
	tray_menu.add_check_item("动作音效", TRAY_ACTION_SOUNDS)
	tray_menu.add_check_item("没收光标", TRAY_CURSOR_MISCHIEF)
	tray_menu.add_check_item("归档图标", TRAY_ICON_COLLECTION)
	tray_menu.add_separator()
	tray_menu.add_item("查看背包", TRAY_BACKPACK)
	tray_menu.add_item("还原全部图标", TRAY_RESTORE_ICONS)
	tray_menu.add_separator()
	tray_menu.add_item("人格机制", TRAY_MECHANISM_DASHBOARD)
	tray_menu.add_item("动作总览", TRAY_ACTION_CATALOG)
	tray_menu.add_item("操控她😏", TRAY_MANUAL_CONTROL)
	tray_menu.add_separator()
	tray_menu.add_item("退出", TRAY_QUIT)
	tray_menu.id_pressed.connect(_on_menu_id_pressed)
	_sync_menu_checks()

func _sync_menu_checks() -> void:
	for popup: PopupMenu in [menu, tray_menu]:
		for id: int in [MENU_AUTO_WANDER, TRAY_AUTO_WANDER]:
			var index: int = popup.get_item_index(id)
			if index >= 0: popup.set_item_checked(index, auto_wander)
		for id: int in [MENU_CURSOR_TRACKING, TRAY_CURSOR_TRACKING]:
			var index: int = popup.get_item_index(id)
			if index >= 0: popup.set_item_checked(index, cursor_tracking)
		for id: int in [MENU_SPEECH_BUBBLES, TRAY_SPEECH_BUBBLES]:
			var index: int = popup.get_item_index(id)
			if index >= 0: popup.set_item_checked(index, speech_bubbles_enabled)
		for id: int in [MENU_TITLE_AWARENESS, TRAY_TITLE_AWARENESS]:
			var index: int = popup.get_item_index(id)
			if index >= 0: popup.set_item_checked(index, title_awareness)
		for id: int in [MENU_WINDOW_COLLISION, TRAY_WINDOW_COLLISION]:
			var index: int = popup.get_item_index(id)
			if index >= 0: popup.set_item_checked(index, window_collision_enabled)
		for id: int in [MENU_ACTION_SOUNDS, TRAY_ACTION_SOUNDS]:
			var index: int = popup.get_item_index(id)
			if index >= 0: popup.set_item_checked(index, action_sounds)
		for id: int in [MENU_CURSOR_MISCHIEF, TRAY_CURSOR_MISCHIEF]:
			var index: int = popup.get_item_index(id)
			if index >= 0: popup.set_item_checked(index, cursor_mischief)
		for id: int in [MENU_ICON_COLLECTION, TRAY_ICON_COLLECTION]:
			var index: int = popup.get_item_index(id)
			if index >= 0: popup.set_item_checked(index, icon_collection)
	var debug_index := menu.get_item_index(MENU_DEBUG_OVERLAY)
	if debug_index >= 0: menu.set_item_checked(debug_index, debug_overlay.visible)

func _open_context_menu(local_position: Vector2) -> void:
	if machine.state in ["boot", "dragged", "suspended"]:
		return
	if machine.state == "manual_control":
		_exit_manual_control()
	if _defer_until_wake("menu", {"position": local_position}):
		return
	_interrupt_action("menu")
	menu_resume = _capture_resume_state()
	machine.dispatch({"type": "MENU_OPEN"})
	desktop.set_unfocusable(false)
	menu.position = Vector2i(local_position)
	menu.popup()

func _on_context_menu_hidden() -> void:
	desktop.set_unfocusable(true)
	if machine.state == "menu_wait":
		machine.dispatch({"type": "INTERACTION_END", "resume": _resolve_resume(menu_resume)})

func _on_menu_id_pressed(id: int) -> void:
	match id:
		MENU_HEAD_PAT:
			_trigger_head_pat(true)
		MENU_POKE:
			_trigger_poke()
		MENU_CLOCK:
			_trigger_clock_scare()
		MENU_REQUEST_COME:
			_submit_ecology_request("come_here")
		MENU_REQUEST_INSPECT:
			_submit_ecology_request("inspect_foreground")
		MENU_REQUEST_STAY:
			_submit_ecology_request("stay_here")
		MENU_REQUEST_SET_HOME:
			_submit_ecology_request("set_home")
		MENU_REQUEST_RETURN_HOME:
			_submit_ecology_request("return_home")
		MENU_COMPANION_15:
			_submit_ecology_request("companion", {"duration_minutes": 15})
		MENU_COMPANION_30:
			_submit_ecology_request("companion", {"duration_minutes": 30})
		MENU_COMPANION_60:
			_submit_ecology_request("companion", {"duration_minutes": 60})
		MENU_FREE_ROAM:
			_submit_ecology_request("free_roam")
		MENU_MANUAL_CONTROL, TRAY_MANUAL_CONTROL:
			_trigger_manual_control()
		MENU_RECENTER, TRAY_RECENTER:
			desktop.set_visible(true)
			_recenter()
		MENU_HIDE:
			hidden = true
			speech_bubble.hide_message(true)
			if offscreen_marker != null:
				offscreen_marker.hide()
			if machine.state == "manual_control":
				_exit_manual_control()
			desktop.set_visible(false)
		MENU_AUTO_WANDER, TRAY_AUTO_WANDER:
			auto_wander = not auto_wander
			wander_deadline = -1.0
			if auto_wander and machine.state == "idle": _schedule_wander()
			_save_user_settings()
			_sync_menu_checks()
		MENU_CURSOR_TRACKING, TRAY_CURSOR_TRACKING:
			cursor_tracking = not cursor_tracking
			if not cursor_tracking: _reset_cursor_tracking()
			_save_user_settings()
			_sync_menu_checks()
		MENU_SPEECH_BUBBLES, TRAY_SPEECH_BUBBLES:
			speech_bubbles_enabled = not speech_bubbles_enabled
			if not speech_bubbles_enabled: speech_bubble.hide_message()
			_save_user_settings()
			_sync_menu_checks()
		MENU_TITLE_AWARENESS, TRAY_TITLE_AWARENESS:
			title_awareness = not title_awareness
			window_platform_service.capture_titles = title_awareness
			last_stable_window_title = ""
			last_novel_window_title = ""
			dialogue_director.observe_window_title("", _now_ms())
			_save_user_settings()
			_sync_menu_checks()
		MENU_ACTION_SOUNDS, TRAY_ACTION_SOUNDS:
			action_sounds = not action_sounds
			sfx_player.configure(action_sounds, sfx_volume)
			_save_user_settings()
			_sync_menu_checks()
		MENU_WINDOW_COLLISION, TRAY_WINDOW_COLLISION:
			window_collision_enabled = not window_collision_enabled
			window_platform_service.set_collision_enabled(window_collision_enabled)
			window_platform_service.refresh_bodies()
			_save_user_settings()
			_sync_menu_checks()
		MENU_CURSOR_MISCHIEF, TRAY_CURSOR_MISCHIEF:
			cursor_mischief = not cursor_mischief
			_save_user_settings()
			_sync_menu_checks()
		MENU_ICON_COLLECTION, TRAY_ICON_COLLECTION:
			icon_collection = not icon_collection
			_save_user_settings()
			_sync_menu_checks()
		MENU_BACKPACK, TRAY_BACKPACK:
			_open_backpack_panel()
		MENU_RESTORE_ICONS, TRAY_RESTORE_ICONS:
			_restore_all_icons()
		MENU_DEBUG_OVERLAY:
			debug_overlay.toggle()
			_sync_menu_checks()
		MENU_ACTION_CATALOG, TRAY_ACTION_CATALOG:
			action_catalog.show_catalog()
		MENU_MECHANISM_DASHBOARD, TRAY_MECHANISM_DASHBOARD:
			_show_mechanism_dashboard()
		MENU_QUIT, TRAY_QUIT:
			speech_bubble.hide_message(true)
			_save_position()
			_save_user_settings()
			_save_life_state()
			_release_cursor_capture()
			_restore_carried_icons_on_exit()
			get_tree().quit()
		TRAY_SHOW:
			hidden = false
			desktop.set_visible(true)
	if machine.state == "menu_wait" and id not in [MENU_CLOCK]:
		machine.dispatch({"type": "INTERACTION_END", "resume": _resolve_resume(menu_resume)})

func _submit_ecology_request(request_id: String, payload: Dictionary = {}) -> void:
	if ecology_request_controller == null or needs_model == null:
		return
	if machine.state == "menu_wait":
		machine.dispatch({"type": "INTERACTION_END", "resume": "idle"})
	if request_id == "free_roam":
		ecology_request_controller.cancel_pending()
		companion_until_ms = -1
		active_request.clear()
		if routine_session.is_active():
			routine_session.finish("cancelled_by_user")
		auto_wander = true
		if machine.state == "idle":
			_schedule_wander()
		_show_speech("request_free_roam", "好。恢复自由观察。", 3.6)
		return
	if routine_session.is_active():
		routine_session.finish("replaced_by_request")
	var context := _ecology_context()
	context["busy"] = machine.state != "idle" or action_session.is_active()
	context["payload"] = payload.duplicate(true)
	var result: Dictionary = ecology_request_controller.evaluate(request_id, context, ecology_clock.elapsed_ms())
	if str(result.get("status", "")) == "accepted" and request_id == "set_home":
		home_anchor = habitat_model.make_anchor(_clamp_position(position, true), Vector2(pet_window_size))
		ecology_progression.record_request(request_id, "accepted", int(Time.get_unix_time_from_system()))
		ecology_progression.record_request(request_id, "completed", int(Time.get_unix_time_from_system()))
		_observe_ecology("home_set")
		_show_speech("request_home_set", "坐标已记录。以后我会自己回来。", 4.5)
		_save_life_state()
		return
	_handle_request_result(result)

func _save_user_settings() -> void:
	var save_error := desktop.save_settings({
		"auto_wander": auto_wander,
		"cursor_tracking": cursor_tracking,
		"speech_bubbles": speech_bubbles_enabled,
		"title_awareness": title_awareness,
		"action_sounds": action_sounds,
		"sfx_volume": sfx_volume,
		"window_collision": window_collision_enabled,
		"cursor_mischief": cursor_mischief,
		"icon_collection": icon_collection,
	})
	if save_error != OK:
		push_warning("无法保存桌宠设置：%s" % error_string(save_error))

func _initialize_life_systems() -> void:
	life_session_started_at_ms = _now_ms()
	var profile := _load_json_dictionary(BEHAVIOR_PROFILE)
	ecology_profile = _load_json_dictionary(ECOLOGY_PROFILE)
	needs_model = PetNeedsModel.new(profile)
	persistent_state = state_store.load_state()
	needs_model.restore_persistent(persistent_state)
	ecology_progression = EcologyProgressionScript.new(ecology_profile)
	ecology_progression.restore_persistent(persistent_state)
	ecology_request_controller = EcologyRequestScript.new(ecology_profile)
	goal_director = GoalDirectorScript.new(ecology_profile, 22013)
	if not goal_director.is_valid():
		for error in goal_director.errors:
			push_error(error)
	home_anchor = persistent_state.get("home_anchor", {}).duplicate(true) if persistent_state.get("home_anchor", {}) is Dictionary else {}
	ecology_clock.reset()
	routine_session.routine_completed.connect(_on_routine_completed)
	var previous_seen := int(persistent_state.get("last_seen_unix", 0))
	if previous_seen > 0:
		returned_after_seconds = maxf(0.0, Time.get_unix_time_from_system() - previous_seen)
	behavior_director = PetBehaviorDirector.load_from_file(BEHAVIOR_PROFILE, 21013)
	if not behavior_director.is_valid():
		for error in behavior_director.errors:
			push_error(error)
	if not dialogue_director.load_data(DIALOGUE_DATA):
		for error in dialogue_director.errors:
			push_error(error)
	dialogue_director.reset_session(persistent_state.get("recent_dialogue_ids", []))
	dialogue_scheduler.reset(_now_ms())
	action_session.session_completed.connect(_on_action_session_completed)
	next_life_save = _now_ms() + LIFE_SAVE_INTERVAL_MS

func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("找不到数据文件：%s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法读取数据文件：%s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("数据文件不是有效 JSON 对象：%s" % path)
	return {}

func _update_life_systems(delta: float, now: float) -> void:
	if needs_model == null:
		return
	var ecology_delta := ecology_clock.advance(delta)
	needs_model.tick(ecology_delta, {"sleeping": machine.state == "sleeping"})
	session_unrecorded_seconds += maxf(0.0, delta)
	_update_ecology(now)
	if action_session.is_active():
		var previous_phase := action_session.current_phase()
		if machine.state == "sleeping" and needs_model.get_need("energy") >= 60.0:
			action_session.request_finish(int(now))
		else:
			action_session.tick(int(now))
		if action_session.is_active() and action_session.current_phase() != previous_phase:
			_play_action_session_clip()
	if now >= next_life_save:
		next_life_save = now + LIFE_SAVE_INTERVAL_MS
		_save_life_state()

func _update_dialogue_system(now: float) -> void:
	if not dialogue_scheduler.should_attempt(now, {
		"enabled": speech_bubbles_enabled,
		"surface_visible": not suspended and desktop.is_visible() and not desktop.is_minimized(),
		"bubble_busy": speech_bubble.is_showing(),
	}):
		return
	var emitted := _emit_dialogue("ambient")
	dialogue_scheduler.commit_attempt(now, dialogue_director.next_ambient_at_ms if emitted else -INF)

func _save_life_state() -> void:
	if persistent_state.is_empty() or needs_model == null:
		return
	var target_store: PetStateStore = developer_state_store if using_developer_state else state_store
	var candidate := persistent_state.duplicate(true)
	candidate["affection"] = needs_model.get_need("affection")
	candidate["recent_dialogue_ids"] = dialogue_director.recent_dialogue_ids()
	if ecology_progression != null:
		candidate.merge(ecology_progression.persistent_snapshot(), true)
	candidate["home_anchor"] = home_anchor.duplicate(true)
	candidate = target_store.record_session(
		candidate,
		session_unrecorded_seconds,
		interaction_delta,
		int(Time.get_unix_time_from_system()),
	)
	if target_store.save_state(candidate):
		persistent_state = candidate
		session_unrecorded_seconds = 0.0
		for key in interaction_delta.keys():
			interaction_delta[key] = 0
	else:
		push_warning(target_store.last_error)

func _on_ecology_rate_requested(rate: float) -> void:
	if not ecology_clock.set_rate(rate):
		return
	var should_use_developer_state := ecology_clock.is_accelerated()
	if should_use_developer_state == using_developer_state:
		return
	_save_life_state()
	using_developer_state = should_use_developer_state
	var source_store: PetStateStore = developer_state_store if using_developer_state else state_store
	persistent_state = source_store.load_state()
	needs_model.reset_session(float(persistent_state.get("affection", 40.0)))
	ecology_progression.restore_persistent(persistent_state)
	home_anchor = persistent_state.get("home_anchor", {}).duplicate(true) if persistent_state.get("home_anchor", {}) is Dictionary else {}
	session_unrecorded_seconds = 0.0
	for key in interaction_delta.keys():
		interaction_delta[key] = 0
	_show_speech("ecology_rate", "生态时钟切换为 %d 倍。%s" % [int(rate), "使用独立开发存档。" if using_developer_state else "恢复正式存档。"], 4.5)

func _bump_interaction(kind: String, positive := false) -> void:
	if interaction_delta.has(kind):
		interaction_delta[kind] = int(interaction_delta[kind]) + 1
	interaction_delta.total = int(interaction_delta.total) + 1
	if positive and kind != "positive":
		interaction_delta.positive = int(interaction_delta.positive) + 1

func _current_mood() -> String:
	if needs_model == null:
		return "neutral"
	if needs_model.get_need("irritation") >= 55.0:
		return "irritated"
	if needs_model.get_need("energy") <= 25.0:
		return "tired"
	if needs_model.get_need("curiosity") >= 60.0:
		return "curious"
	if needs_model.get_need("boredom") >= 65.0:
		return "bored"
	return "neutral"

func _dialogue_context(event_name: String, tags: Array = []) -> Dictionary:
	var foreground := window_platform_service.foreground_snapshot()
	return {
		"event": event_name,
		"mood": _current_mood(),
		"relationship_tier": needs_model.relationship_tier() if needs_model != null else "familiar",
		"irritation": needs_model.get_need("irritation") if needs_model != null else 0.0,
		"app_name": str(foreground.get("process_name", "")),
		"window_title": str(foreground.get("title", "")) if title_awareness else "",
		"time_period": dialogue_director.classify_time_period(),
		"tags": tags,
	}

func _emit_dialogue(event_name: String, tags: Array = []) -> bool:
	if not speech_bubbles_enabled or suspended or not desktop.is_visible() or dialogue_director == null:
		return false
	var line := dialogue_director.select_line(_dialogue_context(event_name, tags), _now_ms())
	if not line.is_empty():
		_show_speech(str(line.get("id", event_name)), str(line.get("text", "")))
		return true
	return false

func _emit_control_quip(event_name: String) -> void:
	if randf() >= CONTROL_QUIP_PROBABILITY:
		return
	_emit_dialogue(event_name)

func _behavior_context() -> Dictionary:
	return {
		"now_ms": int(_now_ms()),
		"hour": int(Time.get_datetime_dict_from_system().get("hour", 0)),
		"time_period": dialogue_director.classify_time_period(),
		"available_clips": manifest.animation_names(),
		"has_platform": not window_platform_service.last_platforms().is_empty(),
		"on_platform": active_platform != null,
		"relationship_tier": needs_model.relationship_tier(),
		"returned_after_seconds": returned_after_seconds,
		"autonomy_allowed": auto_wander and machine.state == "idle",
		"fullscreen": suspended,
		"dragging": machine.state == "dragged",
		"menu_open": menu.visible,
		"direct_interaction": machine.state in ["head_pat", "poke_cheek", "clock_scare"],
		"cursor_mischief": cursor_mischief,
		"icon_collection": icon_collection,
		"cursor_in_reach": _cursor_in_confiscate_reach(),
		"desktop_listview_available": desktop.desktop_listview_available(),
		"has_desktop_icons": _desktop_has_collectable_icons(),
		"has_reachable_icons": _has_reachable_collectable_icon(),
		"bag_not_full": _bag_carry_count() < ICON_BAG_CAPACITY,
	}

func _ecology_context() -> Dictionary:
	var foreground := window_platform_service.foreground_snapshot()
	var safe_title := dialogue_director.sanitize_window_title(str(foreground.get("title", ""))) if title_awareness else ""
	var app_category := dialogue_director.classify_application(str(foreground.get("process_name", "")), safe_title)
	var habitat := habitat_model.snapshot(
		position,
		Vector2(pet_window_size),
		Vector2(desktop.get_cursor_position()),
		platforms.size(),
		not foreground.is_empty(),
		home_anchor
	)
	var context := {
		"familiarity": ecology_progression.familiarity() if ecology_progression != null else 0.0,
		"habit_stages": ecology_progression.habit_stages() if ecology_progression != null else {},
		"time_period": dialogue_director.classify_time_period(),
		"app_category": app_category,
		"has_foreground": not foreground.is_empty(),
		"has_platform": not platforms.is_empty(),
		"has_multiple_platforms": platforms.size() >= 2,
		"on_platform": active_platform != null,
		"cursor_available": true,
		"home_set": not home_anchor.is_empty(),
		"fullscreen": suspended,
		"dragging": machine.state == "dragged",
		"busy": machine.state != "idle" or action_session.is_active() or routine_session.is_active(),
		"energy": needs_model.get_need("energy"),
		"irritation": needs_model.get_need("irritation"),
		"relationship_tier": needs_model.relationship_tier(),
		"screen_count": int(habitat.get("screen_count", 1)),
		"pet_screen": int(habitat.get("pet_screen", 0)),
		"platform_count": platforms.size(),
	}
	context.merge(habitat, true)
	return context

func _update_ecology(_real_now: float) -> void:
	if ecology_progression == null or goal_director == null:
		return
	var simulation_now := ecology_clock.elapsed_ms()
	var time_period := dialogue_director.classify_time_period()
	if time_period != last_ecology_time_period:
		last_ecology_time_period = time_period
		_observe_ecology("time_observed", {"time_period": time_period})
	if routine_session.is_active():
		routine_session.tick(simulation_now)
		if ecology_step_mode == "wait" and ecology_step_deadline_ms >= 0 and simulation_now >= ecology_step_deadline_ms:
			_complete_ecology_step("completed")
	if ecology_request_controller != null and not ecology_request_controller.snapshot().is_empty():
		var request_context := _ecology_context()
		request_context["busy"] = machine.state != "idle" or action_session.is_active() or routine_session.is_active()
		var resolved: Dictionary = ecology_request_controller.poll(request_context, simulation_now)
		if not resolved.is_empty():
			_handle_request_result(resolved)
	if companion_until_ms >= 0 and simulation_now >= companion_until_ms:
		companion_until_ms = -1
		if routine_session.is_active() and str(active_request.get("request_id", "")) == "companion":
			routine_session.finish("completed")
		var events: Array = ecology_progression.observe_event("companion_completed", _ecology_context(), int(Time.get_unix_time_from_system()), simulation_now)
		_handle_progress_events(events)

func _start_ecology_goal(goal: Dictionary, request: Dictionary = {}) -> bool:
	if goal.is_empty() or routine_session.is_active() or machine.state != "idle":
		return false
	if not routine_session.begin(goal, ecology_clock.elapsed_ms()):
		return false
	active_request = request.duplicate(true)
	ecology_step_mode = ""
	ecology_step_deadline_ms = -1
	call_deferred("_run_current_routine_step")
	return true

func _run_current_routine_step() -> void:
	if not routine_session.is_active() or routine_session.is_paused():
		return
	if machine.state != "idle" or action_session.is_active() or not motion.is_empty():
		return
	var step := routine_session.current_step()
	if step.is_empty():
		routine_session.finish("invalid_step")
		return
	var step_type := str(step.get("type", ""))
	ecology_step_mode = step_type
	ecology_step_context = step.duplicate(true)
	match step_type:
		"intent":
			var intent_id := _choose_ecology_intent(step)
			if intent_id.is_empty() or not _start_direct_behavior(intent_id):
				_finish_or_skip_ecology_step(step, "unavailable")
		"travel":
			if not _run_ecology_travel(step):
				_finish_or_skip_ecology_step(step, "unavailable")
		"special":
			if str(step.get("special", "")) == "edge_patrol":
				_trigger_edge_patrol()
				if machine.state != "edge_patrol":
					_finish_or_skip_ecology_step(step, "unavailable")
			else:
				_finish_or_skip_ecology_step(step, "unavailable")
		"wait":
			ecology_step_deadline_ms = ecology_clock.elapsed_ms() + maxi(1, int(step.get("duration_ms", 1000)))
		_:
			_finish_or_skip_ecology_step(step, "invalid")

func _choose_ecology_intent(step: Dictionary) -> String:
	var candidates: Array[String] = []
	for value in step.get("intent_ids", []):
		candidates.append(str(value))
	if candidates.is_empty():
		return ""
	if str(step.get("select_by_need", "")) == "energy":
		if needs_model.get_need("energy") <= 25.0 and "nap" in candidates:
			return "nap"
		if "sit_rest" in candidates:
			return "sit_rest"
	var start := ecology_clock.elapsed_ms() % candidates.size()
	for offset in range(candidates.size()):
		var candidate := candidates[(start + offset) % candidates.size()]
		if behavior_director.create_intent(candidate, needs_model, _behavior_context(), int(_now_ms())).is_empty():
			continue
		return candidate
	return ""

func _run_ecology_travel(step: Dictionary) -> bool:
	var target_kind := str(step.get("target", ""))
	if target_kind in ["foreground_platform", "nearby_platform"]:
		var target_platform: WindowPlatform = _foreground_platform() if target_kind == "foreground_platform" else _nearby_platform()
		return target_platform != null and _travel_to_platform(target_platform)
	var target := position
	var screens := habitat_model.screen_rects()
	match target_kind:
		"random_floor":
			if screens.is_empty():
				return false
			var screen_index := habitat_model.screen_index_for_point(position + Vector2(pet_window_size) * 0.5)
			if ecology_progression.familiarity() >= 60.0 and screens.size() > 1:
				screen_index = randi_range(0, screens.size() - 1)
			var screen: Rect2 = screens[clampi(screen_index, 0, screens.size() - 1)]
			target = Vector2(randf_range(screen.position.x + 18.0, screen.end.x - pet_window_size.x - 18.0), screen.end.y - pet_window_size.y)
		"cursor_floor":
			var cursor := Vector2(desktop.get_cursor_position())
			target = Vector2(cursor.x - pet_window_size.x * 0.5, habitat_model.floor_y_for_position(cursor, Vector2(pet_window_size)))
		"foreground_floor":
			var foreground := window_platform_service.foreground_snapshot()
			if foreground.is_empty():
				return false
			var rect := WindowPlatform.rect_from_value(foreground.get("rect", Rect2i()))
			target = Vector2(rect.get_center().x - pet_window_size.x * 0.5, habitat_model.floor_y_for_position(rect.get_center(), Vector2(pet_window_size)))
		"home":
			if home_anchor.is_empty():
				return false
			target = habitat_model.restore_anchor(home_anchor, Vector2(pet_window_size))
		_:
			return false
	target = habitat_model.clamp_pet_position(target, Vector2(pet_window_size), true)
	# Same-tier relocation: jump and walk are both valid modes for a grounded
	# floor→floor move, chosen at random. Platform targets (handled above) always
	# hop because the pet cannot walk up onto a window.
	var on_floor := active_platform == null
	var same_screen := habitat_model.route_mode(position, target, Vector2(pet_window_size)) == "walk"
	_unmount_from_window()
	if RoamPlannerScript.choose_ground_relocation_mode(on_floor, same_screen, randf()) == "walk":
		return _start_ecology_floor_walk(target)
	_prepare_motion(target, _travel_duration_ms(position.distance_to(target)), 84.0, false)
	var needs_turn := _prepare_travel_facing(target.x)
	machine.dispatch({"type": "WANDER", "needs_turn": needs_turn})
	return machine.state in ["turn", "takeoff", "float"]

## Starts an ecology-travel walk leg (the grounded floor→floor counterpart to the
## jump arc). Reuses the roam_walk state so the patrol_floor clip plays; the motion
## is driven by ecology_walk_motion, and arrival at idle makes _on_transition
## complete the travel step — no completion bookkeeping needed here.
func _start_ecology_floor_walk(target: Vector2) -> bool:
	motion.clear()
	ecology_walk_motion = {
		"from": position,
		"to": target,
		"started_at": _now_ms(),
		"duration_ms": maxf(600.0, position.distance_to(target) / RoamPlannerScript.GROUND_SPEED * 1000.0),
	}
	_prepare_travel_facing(target.x)
	facing = pending_facing
	machine.dispatch({"type": "ROAM_WALK_START"})
	if machine.state != "roam_walk":
		ecology_walk_motion = {}
		return false
	return true

## Drives the ecology-travel walk leg: lerp along the floor toward the target and
## stop early when a window wall blocks the path. Any state change out of roam_walk
## (drag, poke, manual control, platform loss) drops the walk without completing the
## step — the interruption path already paused/finished the routine.
func _update_ecology_walk(now: float) -> void:
	if machine.state != "roam_walk":
		ecology_walk_motion = {}
		return
	var duration := maxf(1.0, float(ecology_walk_motion.get("duration_ms", 1.0)))
	var progress := clampf((now - float(ecology_walk_motion.get("started_at", now))) / duration, 0.0, 1.0)
	var from := Vector2(ecology_walk_motion.get("from", position))
	var to := Vector2(ecology_walk_motion.get("to", position))
	var previous_position := position
	position = _clamp_position(from.lerp(to, progress), false)
	_apply_position()
	if not desktop_world.walls.is_empty() and progress < 1.0:
		var wall := _blocked_walk_wall(previous_position, position)
		if not wall.is_empty():
			var side := int(wall.get("side", 0))
			var wall_x := float(wall.get("x", 0.0))
			var body_edge := wall_x - (WINDOW_FOOT_OFFSET_X + side * PetWallResolverScript.BODY_HALF_WIDTH)
			position = _clamp_position(Vector2(body_edge, position.y), false)
			_apply_position()
			ecology_walk_motion = {}
			machine.dispatch({"type": "CLIP_END"})
			return
	if progress >= 1.0:
		ecology_walk_motion = {}
		machine.dispatch({"type": "CLIP_END"})

func _foreground_platform() -> WindowPlatform:
	var foreground := window_platform_service.foreground_snapshot()
	var handle := int(foreground.get("handle", 0))
	for platform in platforms:
		if platform.handle == handle:
			return platform
	return null

func _nearby_platform() -> WindowPlatform:
	if active_platform != null:
		var nearby: Variant = WindowPlatformService.choose_nearby_platform(active_platform, platforms)
		return nearby as WindowPlatform if nearby is WindowPlatform else null
	if platforms.is_empty():
		return null
	var foot := _pet_foot_global()
	var result: WindowPlatform = null
	var best := INF
	for platform in platforms:
		var distance := foot.distance_squared_to(platform.center())
		if distance < best:
			best = distance
			result = platform
	return result

func _finish_or_skip_ecology_step(step: Dictionary, outcome: String) -> void:
	if bool(step.get("optional", false)):
		_complete_ecology_step("completed")
	else:
		routine_session.finish("step_%s" % outcome)

func _complete_ecology_step(outcome: String) -> void:
	if not routine_session.is_active():
		return
	ecology_step_mode = ""
	ecology_step_deadline_ms = -1
	routine_session.complete_step(outcome, ecology_clock.elapsed_ms())
	if routine_session.is_active():
		call_deferred("_run_current_routine_step")

func _on_routine_completed(goal_id: String, outcome: String) -> void:
	var goal := routine_session.goal()
	var request := active_request.duplicate(true)
	ecology_step_mode = ""
	ecology_step_deadline_ms = -1
	ecology_step_context.clear()
	active_request.clear()
	if outcome == "completed" and ecology_progression != null:
		var context := _ecology_context()
		context["goal_id"] = goal_id
		context.merge(goal.get("context", {}), true)
		_handle_progress_events(ecology_progression.record_goal(goal_id, context, int(Time.get_unix_time_from_system()), ecology_clock.elapsed_ms()))
		_observe_goal_discovery(goal_id, context)
		if not request.is_empty():
			ecology_progression.record_request(str(request.get("request_id", "")), "completed", int(Time.get_unix_time_from_system()))
			var relationship_gain := 0.40 if str(request.get("request_id", "")) == "companion" else 0.25
			needs_model.apply_event("friendly_interaction", {"effects": {"affection": relationship_gain, "boredom": -4.0}})
	if machine.state == "idle":
		_schedule_wander()

func _observe_goal_discovery(goal_id: String, context: Dictionary) -> void:
	var event_name := ""
	match goal_id:
		"platform_patrol": event_name = "platform_walk"
		"window_migration": event_name = "window_migration"
		"edge_expedition": event_name = "edge_expedition"
	if not event_name.is_empty():
		_observe_ecology(event_name, context)

func _observe_ecology(event_type: String, context: Dictionary = {}) -> void:
	if ecology_progression == null:
		return
	var merged := _ecology_context()
	merged.merge(context, true)
	var events: Array = ecology_progression.observe_event(event_type, merged, int(Time.get_unix_time_from_system()), ecology_clock.elapsed_ms())
	_handle_progress_events(events)

func _handle_progress_events(events: Array) -> void:
	for value in events:
		if not value is Dictionary:
			continue
		var kind := str(value.get("kind", ""))
		var details: Dictionary = value.get("details", {}) if value.get("details", {}) is Dictionary else {}
		if kind == "discovery":
			_show_speech("discovery_%s" % str(value.get("id", "")), "新发现：%s" % str(details.get("name", value.get("id", ""))), 4.8)
		elif kind == "habit_stage":
			_show_speech("habit_%s" % str(value.get("id", "")), "形成习惯：%s · %d 阶" % [str(details.get("name", value.get("id", ""))), int(details.get("stage", 0))], 4.8)

func _handle_request_result(result: Dictionary) -> void:
	var request_id := str(result.get("request_id", ""))
	var request_status := str(result.get("status", "refused"))
	if ecology_progression != null and request_status != "accepted":
		ecology_progression.record_request(request_id, request_status, int(Time.get_unix_time_from_system()))
	match request_status:
		"accepted":
			var goal_id := str(result.get("goal_id", ""))
			if goal_id.is_empty():
				if ecology_progression != null:
					ecology_progression.record_request(request_id, "refused", int(Time.get_unix_time_from_system()))
				_show_speech("request_unavailable", "现在没法满足这个请求，稍后再试试。", 4.0)
				return
			var goal: Dictionary = goal_director.create_goal(goal_id, _ecology_context(), ecology_clock.elapsed_ms())
			if request_id == "stay_here" and not goal.is_empty():
				goal["steps"] = [{"type": "intent", "intent_ids": ["sit_rest", "breathe_shift"], "max_duration_ms": 24000}]
			if request_id == "companion":
				var payload: Dictionary = result.get("payload", {}) if result.get("payload", {}) is Dictionary else {}
				var minutes := clampi(int(payload.get("duration_minutes", 15)), 15, 60)
				companion_until_ms = ecology_clock.elapsed_ms() + minutes * 60000
			if _start_ecology_goal(goal, result):
				if ecology_progression != null:
					ecology_progression.record_request(request_id, "accepted", int(Time.get_unix_time_from_system()))
			else:
				if request_id == "companion":
					companion_until_ms = -1
				if ecology_progression != null:
					ecology_progression.record_request(request_id, "refused", int(Time.get_unix_time_from_system()))
				_show_speech("request_unavailable", "现在没法满足这个请求，稍后再试试。", 4.0)
		"deferred":
			_show_speech("request_deferred", "等我把手上的事做完。", 3.8)
		"refused":
			_show_speech("request_refused", "条件不成立。你总不能要求实验对象违反物理。", 4.2)

func _show_mechanism_dashboard() -> void:
	next_mechanism_dashboard_update = _now_ms() + MECHANISM_DASHBOARD_REFRESH_MS
	mechanism_dashboard.show_dashboard(_mechanism_snapshot(_now_ms()))

func _mechanism_snapshot(now: float) -> Dictionary:
	var foreground := window_platform_service.foreground_snapshot()
	var foreground_app := str(foreground.get("process_name", ""))
	if foreground_app.is_empty():
		foreground_app = last_foreground_app
	var safe_title := ""
	if title_awareness:
		safe_title = dialogue_director.sanitize_window_title(str(foreground.get("title", "")))
	var needs_snapshot := needs_model.snapshot() if needs_model != null else {}
	var relationship_tier := needs_model.relationship_tier() if needs_model != null else "familiar"
	var context := _behavior_context() if needs_model != null and manifest != null else {}
	var candidates := behavior_director.diagnostic_candidates(needs_model, context, int(now)) if behavior_director != null else []
	var state_stats_value: Variant = persistent_state.get("interaction_stats", {})
	var state_stats: Dictionary = state_stats_value if state_stats_value is Dictionary else {}
	var merged_stats := PetMechanismDashboard.merge_interaction_stats(state_stats, interaction_delta)
	var event_cooldown_seconds := 0.0
	var active_store: PetStateStore = developer_state_store if using_developer_state else state_store
	if dialogue_director.next_event_at_ms > now:
		event_cooldown_seconds = (dialogue_director.next_event_at_ms - now) / 1000.0
	return {
		"now_ms": int(now),
		"state": machine.state,
		"intent": str(current_intent.get("id", "")),
		"clip": sprite_player.current_clip,
		"session": action_session.snapshot(),
		"routine": routine_session.snapshot(),
		"ecology": ecology_progression.snapshot() if ecology_progression != null else {},
		"ecology_clock": ecology_clock.snapshot(),
		"goal_candidates": goal_director.last_candidates if goal_director != null else [],
		"needs": needs_snapshot,
		"relationship_tier": relationship_tier,
		"mood": _current_mood(),
		"candidates": candidates,
		"recent_intents": behavior_director.recent_intents() if behavior_director != null else [],
		"bubble": speech_bubble.snapshot(),
		"environment": {
			"app": foreground_app,
			"category": dialogue_director.classify_application(foreground_app, safe_title),
			"title": safe_title,
			"stable_title": last_novel_window_title if title_awareness else "",
			"title_awareness": title_awareness,
			"platform_count": platforms.size(),
			"body_count": window_bodies.size(),
			"wall_count": desktop_world.walls.size(),
			"active_platform": active_platform.stable_id() if active_platform != null else "",
			"last_lost": last_platform_lost_reason,
		},
		"dialogue": {
			"event_cooldown_seconds": event_cooldown_seconds,
			"ambient_seconds": dialogue_scheduler.seconds_until_attempt(now),
			"recent_ids": dialogue_director.recent_dialogue_ids(),
		},
		"persistence": {
			"stats": merged_stats,
			"total_companion_seconds": float(persistent_state.get("total_companion_seconds", 0.0)) + session_unrecorded_seconds,
			"session_seconds": maxf(0.0, (now - life_session_started_at_ms) / 1000.0),
			"pending_seconds": session_unrecorded_seconds,
			"last_saved_unix": int(persistent_state.get("last_seen_unix", 0)),
			"next_save_seconds": maxf(0.0, (next_life_save - now) / 1000.0),
			"path": ProjectSettings.globalize_path(active_store.save_path),
			"last_error": active_store.last_error,
		},
		"settings": {
			"auto_wander": auto_wander,
			"cursor_tracking": cursor_tracking,
			"speech_bubbles": speech_bubbles_enabled,
			"title_awareness": title_awareness,
			"action_sounds": action_sounds,
			"window_collision": window_collision_enabled,
			"ecology_rate": ecology_clock.rate(),
			"developer_state": using_developer_state,
		},
	}

func _start_autonomous_intent(intent: Dictionary) -> bool:
	if intent.is_empty() or machine.state != "idle" or action_session.is_active() or not pending_front_intent.is_empty():
		return false
	# The two desktop-intervention behaviors are bespoke phase machines (they need
	# real walk/grab clips and real-world effects, not a clip-session envelope).
	var special_id := str(intent.get("id", ""))
	if special_id == "cursor_confiscate":
		return _begin_cursor_confiscation(intent)
	if special_id == "icon_collect":
		return _begin_icon_collection(intent)
	if str(intent.get("id", "")) == "window_walk":
		intent = _prepare_platform_walk(intent)
		if intent.is_empty():
			# The pace was redirected to a hop/climb/fly encounter; nothing to begin.
			return true
	elif idle_pose_facing != 0:
		var handoff_clip := "idle_%s_enter" % _facing_segment(idle_pose_facing)
		if manifest.has_clip(handoff_clip):
			pending_front_intent = intent.duplicate(true)
			pending_front_handoff_clip = handoff_clip
			wander_deadline = -1.0
			blink_deadline = -1.0
			# The existing side-entry sequence is pixel-identical at both ends,
			# so reverse it to return to the front pose without scaling artwork.
			sprite_player.play_clip(handoff_clip, true, "", true)
			return true
	return _begin_autonomous_intent(intent)

func _begin_autonomous_intent(intent: Dictionary) -> bool:
	current_intent = intent.duplicate(true)
	if not action_session.begin(current_intent, int(_now_ms())):
		current_intent.clear()
		return false
	var requested_state := _machine_state_for_intent(current_intent)
	if machine.dispatch({"type": "ACTION_START", "state": requested_state}) != requested_state:
		action_session.request_finish(int(_now_ms()))
		current_intent.clear()
		return false
	_play_intent_sfx(str(current_intent.get("id", "")))
	if str(current_intent.get("id", "")) == "return_wave":
		returned_after_seconds = 0.0
	return true

func _resume_front_handoff(intent: Dictionary) -> void:
	if machine.state != "idle" or action_session.is_active():
		return
	if not _begin_autonomous_intent(intent):
		_play_idle_pose()

func _start_direct_behavior(intent_id: String) -> bool:
	if behavior_director == null or needs_model == null:
		return false
	var intent := behavior_director.create_intent(intent_id, needs_model, _behavior_context(), int(_now_ms()))
	return _start_autonomous_intent(intent)

func _play_intent_sfx(intent_id: String) -> void:
	match intent_id:
		"straighten_bag", "inspect_rabbit", "guard_bag_annoyed": sfx_player.play("bag")
		"tidy_clothes", "stretch", "reason_pose", "return_wave": sfx_player.play("cloth")
		"sit_rest", "nap", "window_sit": sfx_player.play("sit")
		"window_walk": sfx_player.play("step")
		"window_land_recover": sfx_player.play("land")

func _machine_state_for_intent(intent: Dictionary) -> String:
	var intent_id := str(intent.get("id", ""))
	var configured_state := str(intent.get("state", ""))
	if configured_state in ["ambient_action", "sleeping", "platform_transition", "platform_walk", "platform_sit", "cursor_confiscate", "icon_collect", "icon_transfer"]:
		return configured_state
	match intent_id:
		"nap": return "sleeping"
		"window_walk": return "platform_walk"
		"window_sit": return "platform_sit"
		"window_land_recover": return "platform_transition"
		_: return "ambient_action"

func _play_action_session_clip() -> void:
	if not action_session.is_active():
		return
	var clip_name := action_session.current_clip()
	if manifest.has_clip(clip_name):
		sprite_player.play_clip(clip_name)
	else:
		action_session.request_finish(int(_now_ms()))

func _on_action_session_completed(outcome: String) -> void:
	var finished_intent := current_intent.duplicate(true)
	var session_snapshot := action_session.snapshot()
	if (
		outcome == "interrupted"
		and str(finished_intent.get("id", "")) == "window_sit"
		and bool(session_snapshot.get("resume_allowed", false))
	):
		resumable_platform_intent = finished_intent.duplicate(true)
	elif outcome != "replaced":
		resumable_platform_intent.clear()
	current_intent.clear()
	if outcome in ["completed", "timeout"] and needs_model != null:
		needs_model.apply_event("behavior_completed", {"effects": finished_intent.get("effects", {})})
		var dialogue_event := _dialogue_event_for_intent(str(finished_intent.get("id", "")))
		if not dialogue_event.is_empty():
			_emit_dialogue(dialogue_event)
	if machine.state in ["ambient_action", "sleeping", "platform_transition", "platform_walk", "platform_sit"]:
		machine.dispatch({"type": "ACTION_END"})
	if routine_session.is_active() and ecology_step_mode == "intent" and not routine_session.is_paused():
		if outcome in ["completed", "timeout"]:
			_complete_ecology_step("completed")
		else:
			routine_session.finish("step_%s" % outcome)
	if not deferred_wake_action.is_empty():
		call_deferred("_run_deferred_wake_action")

func _dialogue_event_for_intent(intent_id: String) -> String:
	match intent_id:
		"straighten_bag": return "adjust_bag"
		"inspect_rabbit": return "inspect_rabbit"
		"tidy_clothes": return "tidy_clothes"
		"stretch": return "stretch"
		"reason_pose": return "think"
		"return_wave": return "return"
		"nap": return "wake"
		"window_walk": return "window_walk"
		"window_sit": return "window_sit"
		"window_land_recover": return "window_land"
		"cursor_confiscate":
			return "cursor_miss" if cursor_capture_end_reason == "miss" else ("cursor_escape" if cursor_capture_end_reason == "escape" else "cursor_release")
		"icon_collect":
			return "icon_keepsake" if icon_collect_keepsaked else "icon_collect"
		_: return ""

## ---- User-gifted icon transfer --------------------------------------------
##
## There are two entry points into the same transaction:
##   1. click "给她" in the backpack;
##   2. drag a rendered desktop icon onto her and release the mouse.
## Both paths record the original desktop position, hide only the rendered shell
## item, play the same bag animation, and persist the keepsake before the clip
## starts. Reclaim uses the reverse playback of the same bag clip, then asks the
## shell to restore the icon at the pet's current feet.

func _update_icon_gift_drag(now: float) -> void:
	var mouse_down := desktop != null and desktop.is_key_pressed(0x01)
	if not mouse_down:
		if not icon_gift_drag.is_empty():
			var dropped := icon_gift_drag.duplicate(true)
			icon_gift_drag.clear()
			if bool(dropped.get("entered_pet", false)) and bool(dropped.get("moved", false)):
				_begin_icon_transfer(
					"give",
					str(dropped.get("name", "")),
					dropped.get("original", {}),
					false,
					"mouse_drag",
				)
		return
	if not icon_collection or machine.state != "idle" or not press.is_empty() or menu.visible:
		icon_gift_drag.clear()
		return
	var cursor := Vector2(desktop.get_cursor_position())
	if icon_gift_drag.is_empty():
		var target := _desktop_icon_at_screen_point(cursor)
		if target.is_empty():
			return
		icon_gift_drag = {
			"name": str(target.get("name", "")),
			"original": {"x": int(target.get("x", 0)), "y": int(target.get("y", 0))},
			"start_cursor": cursor,
			"started_at": now,
			"moved": false,
			"entered_pet": false,
		}
		return
	var start_cursor := Vector2(icon_gift_drag.get("start_cursor", cursor))
	if cursor.distance_to(start_cursor) >= ICON_GIFT_DRAG_THRESHOLD_PX:
		icon_gift_drag["moved"] = true
	if _screen_point_hits_pet(cursor):
		icon_gift_drag["entered_pet"] = true
	if now - float(icon_gift_drag.get("started_at", now)) > ICON_TRANSFER_TIMEOUT_MS:
		icon_gift_drag.clear()

func _update_icon_transfer(now: float) -> void:
	if icon_transfer.is_empty():
		return
	# The bag clip is finite, but keep the transaction self-closing if a clip is
	# interrupted or an animation asset fails to report completion. Give has
	# already been persisted before this point; reclaim/restore-all still retain
	# their manifest rollback until the shell restore task finishes.
	if now - float(icon_transfer.get("started_at", now)) >= ICON_TRANSFER_TIMEOUT_MS:
		_complete_icon_transfer()

func _desktop_icon_at_screen_point(screen_point: Vector2) -> Dictionary:
	if desktop == null or not desktop.desktop_listview_available():
		return {}
	var bag_names: Dictionary = {}
	for entry in icon_bag_entries:
		bag_names[str(entry.get("name", ""))] = true
	var result: Dictionary = {}
	var best_distance := INF
	for item in desktop.enumerate_desktop_icons():
		if not item is Dictionary:
			continue
		var name := str(item.get("name", ""))
		if name.is_empty() or bag_names.has(name):
			continue
		var icon_pos := Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0)))
		if not _is_icon_visible(icon_pos):
			continue
		if not ICON_GIFT_HITBOX.has_point(screen_point - icon_pos):
			continue
		var distance := screen_point.distance_squared_to(icon_pos)
		if distance < best_distance:
			best_distance = distance
			result = item.duplicate(true)
	return result

func _screen_point_hits_pet(screen_point: Vector2) -> bool:
	if hidden or suspended or not desktop.is_visible():
		return false
	var local := screen_point - position
	return local.x >= 0.0 and local.y >= 0.0 and local.x < float(pet_window_size.x) and local.y < float(pet_window_size.y) and not sprite_player.hit_test(local).is_empty()

func _new_icon_bag_entry(icon_name: String, original: Dictionary, source: String) -> Dictionary:
	var keepsake := randf() < ICON_KEEPSAKE_PROBABILITY
	var hold_min := ICON_KEEPSAKE_HOLD_MIN_MS if keepsake else ICON_ORDINARY_HOLD_MIN_MS
	var hold_max := ICON_KEEPSAKE_HOLD_MAX_MS if keepsake else ICON_ORDINARY_HOLD_MAX_MS
	return {
		"name": icon_name,
		"kind": "keepsake" if keepsake else "ordinary",
		"original_pos": original.duplicate(true),
		"source": source,
		"acquired_at_ms": _now_ms(),
		"release_at_ms": _now_ms() + randf_range(hold_min, hold_max),
	}

func _begin_icon_transfer(
	kind: String,
	icon_name: String,
	original: Dictionary,
	panel_was_visible: bool,
	source := "backpack",
	payload: Dictionary = {},
) -> bool:
	if icon_transfer.size() > 0 or (not icon_collection and kind == "give"):
		return false
	if machine.state == "menu_wait":
		machine.dispatch({"type": "INTERACTION_END", "resume": "idle"})
	if machine.state != "idle" or action_session.is_active() or (icon_name.is_empty() and kind != "restore_all"):
		return false
	if kind == "give":
		if _bag_carry_count() >= ICON_BAG_CAPACITY or _icon_bag_entry_index(icon_name) >= 0:
			return false
		if original.is_empty():
			original = _desktop_icon_position(icon_name)
		if original.is_empty() or not desktop.hide_desktop_icon(icon_name):
			return false
		icon_bag_entries.append(_new_icon_bag_entry(icon_name, original, source))
		_save_icon_bag()
	icon_transfer = {
		"kind": kind,
		"name": icon_name,
		"original": original.duplicate(true),
		"panel_was_visible": panel_was_visible,
		"source": source,
		"started_at": _now_ms(),
	}
	for key in payload:
		icon_transfer[key] = payload[key]
	if panel_was_visible:
		backpack_panel.hide()
	if machine.dispatch({"type": "ACTION_START", "state": "icon_transfer"}) != "icon_transfer":
		# The transfer is already durably recorded (or still present in the bag for
		# reclaim). Complete its data path even if a transient state transition rejects
		# the animation state, rather than leaving a hidden icon with no UI feedback.
		_complete_icon_transfer()
		return true
	sfx_player.play("bag")
	return true

func _handle_icon_transfer_clip(clip_name: String) -> void:
	if icon_transfer.is_empty():
		machine.dispatch({"type": "CLIP_END"})
		return
	if clip_name == "straighten_bag":
		_complete_icon_transfer()

func _complete_icon_transfer() -> void:
	var transfer := icon_transfer.duplicate(true)
	icon_transfer.clear()
	var kind := str(transfer.get("kind", ""))
	var name := str(transfer.get("name", ""))
	var reopen_panel := bool(transfer.get("panel_was_visible", false))
	if kind == "give":
		if needs_model != null:
			needs_model.apply_event("friendly_interaction")
		_bump_interaction("positive", true)
		if machine.state == "icon_transfer":
			machine.dispatch({"type": "ACTION_END"})
		_refresh_backpack_panel()
		_emit_dialogue("icon_give")
		if reopen_panel:
			backpack_panel.popup_centered()
		return
	if kind == "reclaim":
		var drop_position := _icon_drop_position_at_pet()
		var index := _icon_bag_entry_index(name)
		if index < 0:
			if machine.state == "icon_transfer":
				machine.dispatch({"type": "ACTION_END"})
			return
		var entry: Dictionary = icon_bag_entries[index]
		icon_bag_entries.remove_at(index)
		_save_icon_bag()
		_queue_icon_restore({
			"refresh": true,
			"wait_names": [name],
			"position_map": {name: drop_position},
			"rehide_names": _carried_icon_names(),
			"rollback_entries": [entry],
			"done_kind": "reclaim",
			"done_name": name,
			"reopen_panel": reopen_panel,
		})
		if machine.state == "icon_transfer":
			machine.dispatch({"type": "ACTION_END"})
		return
	if kind == "release":
		var release_index := _icon_bag_entry_index(name)
		if release_index < 0:
			if machine.state == "icon_transfer":
				machine.dispatch({"type": "ACTION_END"})
			return
		var release_entry: Dictionary = icon_bag_entries[release_index]
		var release_position := Vector2(transfer.get("drop_position", Vector2.ZERO))
		icon_bag_entries.remove_at(release_index)
		_save_icon_bag()
		_queue_icon_restore({
			"refresh": true,
			"wait_names": [name],
			"position_map": {name: release_position},
			"rehide_names": _carried_icon_names(),
			"rollback_entries": [release_entry],
			"done_kind": "arrange",
			"done_name": name,
		})
		if machine.state == "icon_transfer":
			machine.dispatch({"type": "ACTION_END"})
		return
	if kind == "restore_all":
		_queue_restore_all_icons(reopen_panel)
		if machine.state == "icon_transfer":
			machine.dispatch({"type": "ACTION_END"})

func _abort_icon_transfer() -> void:
	var reopen := bool(icon_transfer.get("panel_was_visible", false))
	icon_transfer.clear()
	if reopen:
		call_deferred("_open_backpack_panel")

func _icon_drop_position_at_pet() -> Vector2:
	var foot := position + Vector2(WINDOW_FOOT_OFFSET_X, WINDOW_FOOT_OFFSET_Y)
	return Vector2(roundf(foot.x + ICON_DROP_FROM_FOOT.x), roundf(foot.y + ICON_DROP_FROM_FOOT.y))

## ---- Cursor confiscation ("绝对没收") ----
## Chase → grab → absolute confiscation hold (mouse pinned, hidden, swallowed)
## → release. Esc is the sole escape valve; the 60s hold times out on its own.
## Everything here is idempotent: _release_cursor_capture() is safe to call from
## any exit path (Esc, timeout, interrupt, quit).

func _cursor_in_confiscate_reach() -> bool:
	var cursor := Vector2(desktop.get_cursor_position())
	var foot := _pet_foot_global()
	var dx := absf(cursor.x - foot.x)
	var dy := cursor.y - foot.y
	return dx <= 480.0 and dy >= -360.0 and dy <= 180.0

func _can_snatch_cursor(cursor: Vector2) -> bool:
	var foot := _pet_foot_global()
	var dy := cursor.y - foot.y
	return absf(cursor.x - foot.x) <= CURSOR_CONFISCATE_GRAB_RANGE_PX + 40.0 and dy >= -300.0 and dy <= 120.0

func _begin_cursor_confiscation(intent: Dictionary) -> bool:
	current_intent = intent.duplicate(true)
	if machine.dispatch({"type": "ACTION_START", "state": "cursor_confiscate"}) != "cursor_confiscate":
		current_intent.clear()
		return false
	cursor_capture_phase = "chase"
	cursor_capture_end_reason = ""
	cursor_capture_started_ms = _now_ms()
	var cursor := Vector2(desktop.get_cursor_position())
	_start_behavior_walk(Vector2(cursor.x, position.y), CURSOR_CONFISCATE_WALK_SPEED)
	if not behavior_walk.is_empty():
		_play_confiscate_chase_clip()
	return true

func _update_cursor_confiscate(now: float) -> void:
	match cursor_capture_phase:
		"chase":
			var cursor := Vector2(desktop.get_cursor_position())
			if _can_snatch_cursor(cursor):
				_begin_cursor_hold(now)
				return
			if now - cursor_capture_started_ms >= CURSOR_CONFISCATE_CHASE_MS:
				cursor_capture_end_reason = "miss"
				_finish_special_behavior("cursor_confiscate", "completed")
				return
			if behavior_walk.is_empty():
				# The cursor sits on top of her x (or she already reached it). Stand
				# still until it re-enters the grab band or the chase times out.
				return
			if _advance_behavior_walk(now):
				# Reached the old target — re-aim at the live cursor. Re-issue the
				# walk clip so a direction flip picks the correct baked-direction loop.
				_start_behavior_walk(Vector2(cursor.x, position.y), CURSOR_CONFISCATE_WALK_SPEED)
				if not behavior_walk.is_empty():
					_play_confiscate_chase_clip()
		"hold":
			# Absolute: pin to her hand, hide it, swallow every mouse event. If the
			# player was mid-drag when grabbed, wait for the button release before
			# arming the hook so a swallowed button-up can never leave a sticky drag.
			desktop.set_cursor_position(roundi(cursor_capture_anchor.x), roundi(cursor_capture_anchor.y))
			desktop.set_cursor_visible(false)
			if not _cursor_capture_installed:
				if _mouse_button_held():
					return
				_install_cursor_capture()
			if desktop.is_key_pressed(VK_ESCAPE):
				_end_cursor_confiscation("escape")
			elif now - cursor_capture_started_ms >= CURSOR_CONFISCATE_HOLD_MS:
				_end_cursor_confiscation("timeout")

func _begin_cursor_hold(now: float) -> void:
	cursor_capture_phase = "hold"
	cursor_capture_started_ms = now
	_cursor_capture_installed = false
	var cursor := Vector2(desktop.get_cursor_position())
	# The cursor is stuffed into her bag, held at her side where the sprite keeps it.
	cursor_capture_anchor = position + Vector2(facing * 26.0, 48.0)
	desktop.set_cursor_position(roundi(cursor_capture_anchor.x), roundi(cursor_capture_anchor.y))
	desktop.set_cursor_visible(false)
	if not _mouse_button_held():
		_install_cursor_capture()
	sprite_player.play_clip("straighten_bag")
	sfx_player.play("bag")
	_emit_dialogue("cursor_grab")

func _end_cursor_confiscation(reason: String) -> void:
	cursor_capture_end_reason = reason
	_release_cursor_capture()
	if reason == "timeout":
		# Release the hold, then play her "考察完毕" pose before returning.
		cursor_capture_phase = "release"
		sprite_player.play_clip("reason_pose")
		return
	_finish_special_behavior("cursor_confiscate", "completed")

func _abort_cursor_confiscation() -> void:
	_release_cursor_capture()
	cursor_capture_phase = ""
	cursor_capture_end_reason = ""
	if str(current_intent.get("id", "")) == "cursor_confiscate":
		current_intent.clear()

func _release_cursor_capture() -> void:
	_cursor_capture_installed = false
	if desktop.is_cursor_capture_active():
		desktop.stop_cursor_capture()
	desktop.set_cursor_visible(true)

func _install_cursor_capture() -> void:
	if _cursor_capture_installed:
		return
	_cursor_capture_installed = true
	if not desktop.start_cursor_capture():
		# Keep the flag set for this hold so we degrade to pin+hide without
		# re-warning every frame; _release_cursor_capture() clears it for the
		# next hold, which gets a fresh attempt.
		push_warning("小千寻：无法安装鼠标没收钩子，退化为仅锁定位置")

func _mouse_button_held() -> bool:
	return desktop.is_key_pressed(0x01) or desktop.is_key_pressed(0x02) or desktop.is_key_pressed(0x04)

func _play_confiscate_chase_clip() -> void:
	_set_direction(1)
	sprite_player.play_clip("patrol_floor_right" if facing > 0 else "patrol_floor_left")

func _handle_cursor_confiscate_clip(clip_name: String) -> void:
	if cursor_capture_phase == "release":
		if clip_name == "reason_pose":
			_finish_special_behavior("cursor_confiscate", "completed")
		return
	if clip_name in ["patrol_floor_left", "patrol_floor_right"]:
		if cursor_capture_phase == "chase":
			_play_confiscate_chase_clip()
		return
	if clip_name == "straighten_bag":
		# The grab gesture finished — the hold loop keeps guarding the bag.
		sprite_player.play_clip("guard_bag_annoyed")
		return
	if clip_name == "guard_bag_annoyed" and cursor_capture_phase == "hold":
		sprite_player.play_clip("guard_bag_annoyed")

## ---- Icon collection ("归档桌面图标") ----
## approach → grab/hide → timed storage. Both ordinary icons and keepsakes are
## hidden while carried; the only difference is how long she keeps them before a
## later placement opportunity. .lnk/files are never touched.

## ---- Visibility and reachability (the collection trigger/selection chain) ----

## Windows currently occluding screen content behind them: every foreground-valid
## window whose z-order sits behind the pet (or is maximized), mirroring the
## pet-occlusion rule in window_platform_service.gd. The pet's own always-on-top
## window is excluded by the self-pid filter, so she never occludes her targets.
func _occluding_rects() -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	var self_z := window_platform_service.self_z_order()
	var self_pid := window_platform_service.self_process_id()
	for snap in window_platform_service.last_snapshots():
		if not snap is Dictionary:
			continue
		if not WindowPlatformService.is_foreground_snapshot_valid(snap, self_pid):
			continue
		var z := int(snap.get("z_order", 0))
		if self_z > 0 and z >= self_z and not bool(snap.get("maximized", false)):
			continue
		var rect := WindowPlatform.rect_from_value(snap.get("rect", Rect2i()))
		if rect.size.x > 0 and rect.size.y > 0:
			rects.append(rect)
	return rects

func _is_point_obscured(screen_pos: Vector2) -> bool:
	for rect in _occluding_rects():
		if rect.has_point(Vector2i(roundi(screen_pos.x), roundi(screen_pos.y))):
			return true
	return false

## An icon she cannot see (covered by a foreground window — e.g. a maximized
## window) is not collectable. "如果桌面图标并没有被绘制出来…不会触发搜集".
func _is_icon_visible(icon_pos: Vector2) -> bool:
	return not _is_point_obscured(icon_pos)

## Grab reach from the window origin she would occupy: the horizontal band adds
## slack for her body's offset inside the window (so the test is facing-agnostic),
## the vertical band is the hand anchor (~48px below the box top) plus her reach.
## Wall-blocked or clamped short → the live grab check fails and she loses the
## target, which is the intended "隔墙/过高够不到" outcome.
func _icon_reachable_from_position(at_position: Vector2, icon_pos: Vector2) -> bool:
	var hand_y := at_position.y + ICON_HAND_OFFSET_Y_PX
	return absf(icon_pos.x - at_position.x) <= ICON_COLLECT_GRAB_RANGE_PX + ICON_HORIZONTAL_SLACK_PX \
		and icon_pos.y >= hand_y - ICON_REACH_UP_PX \
		and icon_pos.y <= hand_y + ICON_REACH_DOWN_PX

## Enumerate every approach mode that could put an icon within grab reach:
## walk (same-level only — flat walking never climbs), hop (borrow a window
## ledge), fly (always viable, bounded by the whole behavior's timeout). Each
## entry carries the window origin she would occupy in that mode.
func _icon_reach_analysis(icon_pos: Vector2) -> Dictionary:
	var modes: Array = []
	var walk_stand := _clamp_position(Vector2(icon_pos.x, position.y), false)
	if absf(icon_pos.x - position.x) <= ICON_MAX_WALK_HORIZONTAL_PX and _icon_reachable_from_position(walk_stand, icon_pos):
		modes.append({"mode": "walk", "platform": null, "at": walk_stand})
	var best_hop: Dictionary = {}
	var best_hop_distance := INF
	for platform in platforms:
		if not platform.contains_x(icon_pos.x) and absf(platform.center().x - icon_pos.x) > ICON_COLLECT_GRAB_RANGE_PX * 2.0:
			continue
		var stand_x := clampf(icon_pos.x, float(platform.segment_left()) + 24.0, float(platform.segment_right()) - 24.0)
		var stand := _position_for_platform(platform, stand_x)
		if not _icon_reachable_from_position(stand, icon_pos):
			continue
		var distance := stand.distance_to(icon_pos)
		if distance < best_hop_distance:
			best_hop_distance = distance
			best_hop = {"mode": "hop", "platform": platform, "at": stand}
	if not best_hop.is_empty():
		modes.append(best_hop)
	modes.append({"mode": "fly", "platform": null, "at": _clamp_position(Vector2(icon_pos.x, icon_pos.y), false)})
	return {"reachable": not modes.is_empty(), "modes": modes}

## Weighted random among viable modes (walk > hop > fly). A single viable mode
## is used outright; only genuinely open choices roll — "随机选中之后跳上附近的
## 小窗口,或者直接选择飞行".
func _pick_approach_mode(modes: Array) -> Dictionary:
	if modes.is_empty():
		return {}
	var weights := {"walk": 50.0, "hop": 30.0, "fly": 20.0}
	var total := 0.0
	for m in modes:
		total += weights.get(str(m.get("mode", "fly")), 20.0)
	var roll := randf() * total
	for m in modes:
		roll -= weights.get(str(m.get("mode", "fly")), 20.0)
		if roll <= 0.0:
			return m
	return modes[0]

## The visibility gate: at least one un-collected desktop icon is actually drawn
## on screen. A maximized window covering every icon → false → the behavior never
## triggers while the player cannot see the icons being taken.
func _desktop_has_collectable_icons() -> bool:
	if not desktop.desktop_listview_available():
		return false
	var bag_names: Dictionary = {}
	for entry in icon_bag_entries:
		bag_names[str(entry.get("name", ""))] = true
	for item in desktop.enumerate_desktop_icons():
		if item is Dictionary and not str(item.get("name", "")).is_empty() and not bag_names.has(str(item.get("name", ""))):
			var icon_pos := Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0)))
			if _is_icon_visible(icon_pos):
				return true
	return false

## The reachability gate: at least one visible, un-collected icon has a viable
## approach mode. "触发前先确认真的够得着" — advertised to the director as
## has_reachable_icons so it is an explicit trigger condition.
func _has_reachable_collectable_icon() -> bool:
	if not desktop.desktop_listview_available():
		return false
	var bag_names: Dictionary = {}
	for entry in icon_bag_entries:
		bag_names[str(entry.get("name", ""))] = true
	for item in desktop.enumerate_desktop_icons():
		if item is Dictionary and not str(item.get("name", "")).is_empty() and not bag_names.has(str(item.get("name", ""))):
			var icon_pos := Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0)))
			if not _is_icon_visible(icon_pos):
				continue
			if bool(_icon_reach_analysis(icon_pos).get("reachable", false)):
				return true
	return false

func _begin_icon_collection(intent: Dictionary) -> bool:
	var target := _pick_collectable_icon()
	if target.is_empty():
		return false
	current_intent = intent.duplicate(true)
	icon_collect_icon = target
	icon_collect_keepsaked = false
	if machine.dispatch({"type": "ACTION_START", "state": "icon_collect"}) != "icon_collect":
		current_intent.clear()
		icon_collect_icon = {}
		return false
	icon_collect_phase = "approach"
	icon_collect_phase_at = _now_ms()
	icon_collect_started_at = icon_collect_phase_at
	var icon_pos := Vector2(float(target.get("x", 0.0)), float(target.get("y", 0.0)))
	var analysis := _icon_reach_analysis(icon_pos)
	var mode := _pick_approach_mode(analysis.get("modes", []))
	if mode.is_empty():
		# Should not happen (target was reachable), but degrade rather than stall.
		_abort_icon_collection()
		return false
	_begin_icon_navigation(str(mode.get("mode", "fly")), mode.get("platform", null), Vector2(mode.get("at", icon_pos)))
	return true

func _update_icon_collect(now: float) -> void:
	if _icon_collect_timeout_check(now):
		return
	# She only keeps chasing a target she can still see. The moment a window
	# slides over it she drops the plan — "被遮挡失去目标".
	if icon_collect_phase == "approach" and not _is_icon_visible(_icon_collect_target_pos()):
		_lose_icon_target("obscured")
		return
	match icon_collect_phase:
		"approach":
			if _advance_icon_navigation(now):
				if str(icon_collect_nav.get("mode", "walk")) == "walk":
					icon_collect_phase = "grab"
					icon_collect_phase_at = now
					_grab_icon(now)
				else:
					icon_collect_phase = "landing"
					icon_collect_phase_at = now
		"landing":
			if now - icon_collect_phase_at >= ICON_COLLECT_LANDING_MS:
				icon_collect_phase = "grab"
				icon_collect_phase_at = now
				_grab_icon(now)
		"grab":
			if now - icon_collect_phase_at >= ICON_COLLECT_GRAB_MS:
				# The icon is already hidden and journaled. Placement is deliberately
				# deferred to the global release cycle, so autonomous collection can
				# hold up to three icons without immediately dropping them in a row.
				_finish_icon_collection()

func _icon_collect_target_pos() -> Vector2:
	return Vector2(float(icon_collect_icon.get("x", 0.0)), float(icon_collect_icon.get("y", 0.0)))

## Total-run budget. Special behaviors bypass action_session's max_duration_ms,
## so icon_collect enforces its own internal timeout (profile default 16000).
func _icon_collect_timeout_check(now: float) -> bool:
	var max_ms := int(current_intent.get("session", {}).get("max_duration_ms", 16000))
	if max_ms > 0 and _now_ms() - icon_collect_started_at >= max_ms:
		_lose_icon_target("timeout")
		return true
	return false

func _grab_icon(now: float) -> void:
	var name := str(icon_collect_icon.get("name", ""))
	if name.is_empty():
		_finish_icon_collection()
		return
	# No teleport grabbing: she must be within reach *and* still able to see the
	# icon. A wall-blocked approach, a clamped-short hop, or a window sliding over
	# the icon all end as "失去目标" rather than an impossible grab.
	var icon_pos := _icon_collect_target_pos()
	if not _is_icon_visible(icon_pos):
		_lose_icon_target("obscured")
		return
	if not _icon_reachable_from_position(position, icon_pos):
		_lose_icon_target("out_of_reach")
		return
	# Every icon that enters the bag is hidden. The random kind only controls how
	# long she keeps it, not whether the desktop presentation disappears.
	if not desktop.hide_desktop_icon(name):
		# If Explorer refused the shell notification, leave the icon untouched and
		# end this attempt rather than creating a phantom bag entry.
		_finish_icon_collection()
		return
	var entry := _new_icon_bag_entry(
		name,
		icon_collect_icon.get("original", {"x": 0, "y": 0}),
		"autonomous",
	)
	icon_collect_keepsaked = str(entry.get("kind", "ordinary")) == "keepsake"
	icon_bag_entries.append(entry)
	_save_icon_bag()
	sprite_player.play_clip("straighten_bag")
	sfx_player.play("bag")
	if icon_collect_keepsaked:
		_emit_dialogue("icon_keepsake")
func _finish_icon_collection() -> void:
	_finish_special_behavior("icon_collect", "completed")

func _abort_icon_collection() -> void:
	if str(current_intent.get("id", "")) == "icon_collect":
		current_intent.clear()
	icon_collect_phase = ""
	icon_collect_nav = {}
	icon_collect_arc = {}
	behavior_walk = {}
	_return_in_flight_icon()

## The in-behavior "失去目标" ending (occluded, out of reach, or timed out): the
## ordinary icon goes home, the run ends, and she complains. Called at most once
## per run (the phase machine leaves the state afterwards).
func _lose_icon_target(_reason: String) -> void:
	icon_collect_phase = ""
	icon_collect_nav = {}
	icon_collect_arc = {}
	behavior_walk = {}
	_return_in_flight_icon()
	_emit_dialogue("icon_miss")
	_finish_special_behavior("icon_collect", "aborted")

## ---- Multi-modal navigation for icon collection (approach + carry) ----

func _begin_icon_navigation(mode_name: String, platform: Variant, at: Vector2) -> void:
	icon_collect_nav = {"mode": mode_name, "platform": platform}
	icon_collect_nav_clip = ""
	var to := _clamp_position(at, false)
	if position.distance_to(to) < 6.0:
		icon_collect_arc = {}
		behavior_walk = {}
		return
	if mode_name == "walk":
		_start_behavior_walk(to, ICON_COLLECT_WALK_SPEED)
		_play_icon_collect_chase_clip()
	else:
		_start_icon_arc(to, mode_name)

func _start_icon_arc(to: Vector2, mode_name: String) -> void:
	icon_collect_arc = {
		"from": position,
		"to": to,
		"started_at": _now_ms(),
		"duration_ms": maxf(600.0, position.distance_to(to) / maxf(1.0, ICON_COLLECT_FLY_SPEED) * 1000.0),
		"arc_height": ICON_NAV_ARC_HEIGHT_PX,
		"mode": mode_name,
	}
	_set_icon_nav_clip("takeoff")

func _advance_icon_navigation(now: float) -> bool:
	if behavior_walk.is_empty() and icon_collect_arc.is_empty():
		return true
	if not icon_collect_arc.is_empty():
		return _advance_icon_arc(now)
	if _advance_behavior_walk(now):
		behavior_walk = {}
		return true
	return false

## Manual parabola: y -= 4*arc_height*t*(1-t), the same math as _update_motion
## but self-contained so it never touches the roam state machine (special
## behaviors own the icon_collect state). Real clips takeoff → float → land /
## window_land_recover carry her through the arc.
func _advance_icon_arc(now: float) -> bool:
	if icon_collect_arc.is_empty():
		return true
	var duration := maxf(1.0, float(icon_collect_arc.get("duration_ms", 1.0)))
	var t := clampf((now - float(icon_collect_arc.get("started_at", now))) / duration, 0.0, 1.0)
	var from := Vector2(icon_collect_arc.get("from", position))
	var to := Vector2(icon_collect_arc.get("to", position))
	var arc := float(icon_collect_arc.get("arc_height", 0.0))
	var base := from.lerp(to, t)
	position = _clamp_position(Vector2(base.x, base.y - 4.0 * arc * t * (1.0 - t)), false)
	_apply_position()
	if t < 0.12:
		_set_icon_nav_clip("takeoff")
	elif t < 0.82:
		_set_icon_nav_clip("float")
	else:
		_set_icon_nav_clip("window_land_recover" if str(icon_collect_arc.get("mode", "")) == "hop" else "land")
	if t >= 1.0:
		icon_collect_arc = {}
		return true
	return false

func _set_icon_nav_clip(clip_name: String) -> void:
	if icon_collect_nav_clip == clip_name:
		return
	icon_collect_nav_clip = clip_name
	sprite_player.play_clip(clip_name)

func _play_icon_collect_chase_clip() -> void:
	_set_direction(1)
	sprite_player.play_clip("patrol_floor_right" if facing > 0 else "patrol_floor_left")

func _handle_icon_collect_clip(clip_name: String) -> void:
	if icon_collect_phase in ["approach", "carry"] and clip_name in ["patrol_floor_left", "patrol_floor_right"]:
		_play_icon_collect_chase_clip()
		return
	# grab/place hold their pose until the phase timer advances.

func _finish_special_behavior(intent_id: String, outcome: String) -> void:
	var finished := current_intent.duplicate(true)
	current_intent.clear()
	resumable_platform_intent.clear()
	if outcome in ["completed", "timeout"] and needs_model != null:
		needs_model.apply_event("behavior_completed", {"effects": finished.get("effects", {})})
		var dialogue_event := _dialogue_event_for_intent(intent_id)
		if not dialogue_event.is_empty():
			_emit_dialogue(dialogue_event)
	if machine.state in ["cursor_confiscate", "icon_collect"]:
		machine.dispatch({"type": "ACTION_END"})
	if routine_session.is_active() and ecology_step_mode == "intent" and not routine_session.is_paused():
		_complete_ecology_step("completed")

## ---- Movement helpers shared by the two special behaviors ----

func _start_behavior_walk(target: Vector2, speed_px_per_second: float) -> void:
	var from := position
	var to := _clamp_position(target, false)
	if from.distance_to(to) < 6.0:
		behavior_walk = {}
		return
	facing = 1 if (to.x - from.x) > 0.0 else -1
	behavior_walk = {
		"from": from,
		"to": to,
		"started_at": _now_ms(),
		"duration_ms": maxf(160.0, from.distance_to(to) / maxf(1.0, speed_px_per_second) * 1000.0),
	}

func _advance_behavior_walk(now: float) -> bool:
	if behavior_walk.is_empty():
		return true
	var duration := maxf(1.0, float(behavior_walk.get("duration_ms", 1.0)))
	var progress := clampf((now - float(behavior_walk.get("started_at", now))) / duration, 0.0, 1.0)
	var from := Vector2(behavior_walk.get("from", position))
	var to := Vector2(behavior_walk.get("to", position))
	var previous_position := position
	position = _clamp_position(from.lerp(to, progress), false)
	if not desktop_world.walls.is_empty() and progress < 1.0:
		var wall := _blocked_walk_wall(previous_position, position)
		if not wall.is_empty():
			var side := int(wall.get("side", 0))
			var wall_x := float(wall.get("x", 0.0))
			var body_edge := wall_x - (WINDOW_FOOT_OFFSET_X + side * PetWallResolverScript.BODY_HALF_WIDTH)
			position = _clamp_position(Vector2(body_edge, position.y), false)
			behavior_walk = {}
			_apply_position()
			return true
	if absf(to.x - from.x) > 1.0:
		facing = 1 if (to.x - from.x) > 0.0 else -1
	_apply_position()
	if progress >= 1.0:
		behavior_walk = {}
		return true
	return false

## ---- Backpack manifest (user://icon_bag.json) ----

func _load_icon_bag() -> void:
	if not FileAccess.file_exists(ICON_BAG_PATH):
		return
	var file := FileAccess.open(ICON_BAG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		icon_bag_entries.clear()
		for value in parsed:
			# Older builds kept placed ordinary icons in the manifest. Under the
			# session-journal rule a placed icon is already released and must not be
			# moved again on boot or exit.
			if value is Dictionary and not str(value.get("name", "")).is_empty() and not bool(value.get("placed", false)):
				icon_bag_entries.append(value)

func _save_icon_bag() -> void:
	var file := FileAccess.open(ICON_BAG_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("无法写入背包清单：%s" % ICON_BAG_PATH)
		return
	file.store_string(JSON.stringify(icon_bag_entries, "  "))

func _icon_bag_entry_index(name: String) -> int:
	for index in range(icon_bag_entries.size()):
		if str(icon_bag_entries[index].get("name", "")) == name:
			return index
	return -1

func _remove_icon_bag_entry(name: String) -> void:
	var index := _icon_bag_entry_index(name)
	if index >= 0:
		icon_bag_entries.remove_at(index)

## Every manifest entry is currently hidden in the rendered desktop and occupies
## one of the three physical bag slots. Once released, it is removed entirely.
func _bag_carry_count() -> int:
	return icon_bag_entries.size()

func _carried_icon_names() -> Array:
	var result: Array = []
	for entry in icon_bag_entries:
		if entry is Dictionary:
			var name := str(entry.get("name", ""))
			if not name.is_empty():
				result.append(name)
	return result

## Boot recovery: the journal only represents icons hidden by an interrupted
## session. They must be made visible and returned to their original positions;
## a normal previous exit leaves this file empty.
func _reconcile_icon_bag() -> void:
	_load_icon_bag()
	if icon_bag_entries.is_empty():
		return
	var position_map: Dictionary = {}
	var wait_names := _carried_icon_names()
	for entry in icon_bag_entries:
		var name := str(entry.get("name", ""))
		var original: Dictionary = entry.get("original_pos", {})
		if not name.is_empty() and not original.is_empty():
			position_map[name] = Vector2(int(original.get("x", 0)), int(original.get("y", 0)))
	_queue_icon_restore({
		"refresh": true,
		"wait_names": wait_names,
		"position_map": position_map,
		"rehide_names": [],
		"timeout_ms": 60000.0,
		"clear_manifest_on_success": true,
		"done_kind": "recovery",
	})

## Normal exit is bounded and synchronous because the process is about to quit:
## refresh the shell view, wait for all hidden names to reappear, position them,
## and clear the journal only after every operation succeeds. If Explorer is
## unavailable, leave the journal for the next boot instead of losing recovery
## information.
func _restore_carried_icons_on_exit() -> void:
	if icon_exit_restore_started:
		return
	icon_exit_restore_started = true
	next_icon_release_attempt_ms = -1.0
	# A reclaim/release transaction may already have removed its entry from the
	# live bag and be waiting in the restore queue. It is still a hidden shell
	# item, so fold its rollback record into the exit recovery set as well.
	var entries_by_name: Dictionary = {}
	for entry in icon_bag_entries:
		if entry is Dictionary:
			var live_name := str(entry.get("name", ""))
			if not live_name.is_empty():
				entries_by_name[live_name] = entry.duplicate(true)
	for task in icon_restore_queue:
		for entry in task.get("rollback_entries", []):
			if entry is Dictionary:
				var pending_name := str(entry.get("name", ""))
				if not pending_name.is_empty():
					entries_by_name[pending_name] = entry.duplicate(true)
	var entries: Array = []
	for value in entries_by_name.values():
		entries.append(value)
	if entries.is_empty():
		return
	# The normal quit path must not leave an older deferred task racing this
	# synchronous recovery. Its rollback entries are now represented above.
	icon_restore_queue.clear()
	desktop.force_desktop_icon_refresh()
	var deadline := Time.get_ticks_msec() + int(ICON_EXIT_RESTORE_TIMEOUT_MS)
	var restored := false
	while Time.get_ticks_msec() < deadline:
		var items: Array = desktop.enumerate_desktop_icons()
		var present: Dictionary = {}
		for item in items:
			if item is Dictionary:
				present[str(item.get("name", ""))] = true
		var all_present := true
		for entry in entries:
			if not present.has(str(entry.get("name", ""))):
				all_present = false
				break
		if all_present:
			var all_positioned := true
			for entry in entries:
				var name := str(entry.get("name", ""))
				var original: Dictionary = entry.get("original_pos", {})
				if original.is_empty() or not desktop.set_desktop_icon_position(name, int(original.get("x", 0)), int(original.get("y", 0))):
					all_positioned = false
					break
			if all_positioned:
				# Read the view once more after Explorer has processed the scalar
				# position messages. This is the final confirmation that every
				# recovered name is rendered again, rather than trusting a message
				# return value alone.
				var verified: Dictionary = {}
				for item in desktop.enumerate_desktop_icons():
					if item is Dictionary:
						verified[str(item.get("name", ""))] = true
				var all_verified := true
				for entry in entries:
					if not verified.has(str(entry.get("name", ""))):
						all_verified = false
						break
				if all_verified:
					restored = true
					break
		OS.delay_msec(50)
	if restored:
		icon_bag_entries.clear()
		_save_icon_bag()
	else:
		# Keep the journal exactly as a recovery record when Explorer did not
		# become usable before quit. The next process can retry it.
		icon_bag_entries = entries
		_save_icon_bag()

func _restore_all_icons() -> void:
	if icon_bag_entries.is_empty():
		_refresh_backpack_panel()
		return
	if _begin_icon_transfer("restore_all", "", {}, backpack_panel.visible, "restore_all"):
		return
	_queue_restore_all_icons(false)

func _queue_restore_all_icons(reopen_panel: bool) -> void:
	if icon_bag_entries.is_empty():
		_refresh_backpack_panel()
		return
	var position_map: Dictionary = {}
	var wait_names: Array = []
	var rollback_entries := icon_bag_entries.duplicate(true)
	for entry in icon_bag_entries:
		var name := str(entry.get("name", ""))
		if name.is_empty():
			continue
		wait_names.append(name)
		var original: Dictionary = entry.get("original_pos", {})
		if not original.is_empty():
			position_map[name] = Vector2(int(original.get("x", 0)), int(original.get("y", 0)))
	icon_bag_entries.clear()
	_save_icon_bag()
	_queue_icon_restore({
		"refresh": true,
		"wait_names": wait_names,
		"position_map": position_map,
		"rehide_names": [],
		"rollback_entries": rollback_entries,
		"done_kind": "restore_all",
		"reopen_panel": reopen_panel,
	})

## If collection is interrupted before the shell-delete transaction completes,
## leave the live icon alone. Once the journal entry exists it is already safely
## recoverable; aborting the state must never move or delete it from the journal.
func _return_in_flight_icon() -> void:
	icon_collect_icon = {}

func _desktop_icon_position(icon_name: String) -> Dictionary:
	for item in desktop.enumerate_desktop_icons():
		if item is Dictionary and str(item.get("name", "")) == icon_name:
			return {"x": int(item.get("x", 0)), "y": int(item.get("y", 0))}
	return {}

## ---- Deferred desktop-icon restore (reclaim / arrange / restore-all) -------

func _queue_icon_restore(spec: Dictionary) -> void:
	spec["refresh_issued"] = false
	spec["positioned"] = {}
	spec["escalated"] = false
	spec["started_ms"] = _now_ms()
	spec["timeout_ms"] = float(spec.get("timeout_ms", 10000.0))
	spec["done_kind"] = str(spec.get("done_kind", ""))
	spec["done_name"] = str(spec.get("done_name", ""))
	spec["clear_manifest_on_success"] = bool(spec.get("clear_manifest_on_success", false))
	icon_restore_queue.append(spec)

## Drives the front-most restore task to completion, throttled to ~150ms. After a
## refresh the deleted slots reappear asynchronously, so we poll for them, then
## position the released icon, then re-hide every other still-carried icon.
func _update_icon_restore(now: float) -> void:
	if icon_restore_queue.is_empty():
		return
	if now < next_icon_restore_check_ms:
		return
	next_icon_restore_check_ms = now + 150.0
	if desktop == null or not desktop.desktop_listview_available():
		return
	var task: Dictionary = icon_restore_queue[0]
	if bool(task.get("refresh", false)) and not bool(task.get("refresh_issued", false)):
		desktop.refresh_desktop_icons()
		task["refresh_issued"] = true
	# 1) Wait for every target name to reappear.
	var missing: Array = []
	for name in task.get("wait_names", []):
		if not desktop.desktop_icon_present(str(name)):
			missing.append(str(name))
	if not missing.is_empty():
		if now - float(task.get("started_ms", now)) >= float(task.get("timeout_ms", 10000.0)):
			if not bool(task.get("escalated", false)):
				# The light refresh did not re-add — force a full desktop rebuild.
				task["escalated"] = true
				task["started_ms"] = now
				desktop.force_desktop_icon_refresh()
			else:
				_abandon_icon_restore(task)
		return
	# 2) Position each present name once.
	var positioned: Dictionary = task.get("positioned", {})
	for name in task.get("wait_names", []):
		var key := str(name)
		if positioned.has(key):
			continue
		var target: Variant = task.get("position_map", {}).get(key, null)
		if target == null:
			positioned[key] = true
			continue
		if desktop.set_desktop_icon_position(key, int(target.x), int(target.y)):
			# Explorer may snap to its current icon grid. A fresh enumeration is
			# the authoritative confirmation that the target is rendered and has
			# accepted a position before this task can hide the other bag entries.
			if not _desktop_icon_position(key).is_empty():
				positioned[key] = true
	task["positioned"] = positioned
	if positioned.size() < (task.get("wait_names", []) as Array).size():
		if now - float(task.get("started_ms", now)) >= float(task.get("timeout_ms", 10000.0)):
			_abandon_icon_restore(task)
		return
	# 3) Re-hide the remaining carried icons. A shell refresh re-adds every hidden
	# slot, so the other bag entries must be hidden again immediately.
	var retry: Array = []
	for name in task.get("rehide_names", []):
		var key := str(name)
		if desktop.desktop_icon_present(key) and not desktop.hide_desktop_icon(key):
			retry.append(key)
	if retry.is_empty():
		icon_restore_queue.pop_front()
		_finish_icon_restore(task)
	elif now - float(task.get("started_ms", now)) >= float(task.get("timeout_ms", 10000.0)):
		# Give up re-hiding; the remaining entries stay in the journal and the next
		# boot recovery will restore them safely. Nothing is lost.
		icon_restore_queue.pop_front()
		_finish_icon_restore(task)

func _finish_icon_restore(task: Dictionary) -> void:
	match str(task.get("done_kind", "")):
		"reclaim":
			_refresh_backpack_panel()
			_emit_dialogue("icon_reclaim")
		"arrange":
			_refresh_backpack_panel()
			_emit_dialogue("icon_arrange")
			next_icon_release_attempt_ms = _now_ms() + randf_range(ICON_RELEASE_COOLDOWN_MIN_MS, ICON_RELEASE_COOLDOWN_MAX_MS)
		"restore_all":
			_refresh_backpack_panel()
			_emit_dialogue("icon_restore")
		"recovery":
			icon_bag_entries.clear()
			_save_icon_bag()
	if bool(task.get("clear_manifest_on_success", false)):
		icon_bag_entries.clear()
		_save_icon_bag()
	if bool(task.get("reopen_panel", false)):
		backpack_panel.popup_centered()

func _abandon_icon_restore(task: Dictionary) -> void:
	icon_restore_queue.pop_front()
	var rollback: Array = task.get("rollback_entries", [])
	if not rollback.is_empty():
		for entry in rollback:
			if entry is Dictionary and _icon_bag_entry_index(str(entry.get("name", ""))) < 0:
				icon_bag_entries.append(entry)
		_save_icon_bag()
	if str(task.get("done_kind", "")) == "arrange":
		_schedule_icon_release_retry(_now_ms())
	push_warning("图标恢复超时，未能完成: %s" % str(task.get("done_name", "")))
	_refresh_backpack_panel()
	if bool(task.get("reopen_panel", false)):
		backpack_panel.popup_centered()

## ---- Timed release and grid-aware placement ------------------------------

func _schedule_icon_release_retry(now: float) -> void:
	next_icon_release_attempt_ms = now + randf_range(ICON_RELEASE_RETRY_MIN_MS, ICON_RELEASE_RETRY_MAX_MS)

func _update_icon_release_scheduler(now: float) -> void:
	if icon_bag_entries.is_empty():
		next_icon_release_attempt_ms = -1.0
		return
	if next_icon_release_attempt_ms < 0.0:
		var earliest := INF
		for entry in icon_bag_entries:
			earliest = minf(earliest, float(entry.get("release_at_ms", now)))
		next_icon_release_attempt_ms = earliest
	if now < next_icon_release_attempt_ms:
		return
	if not icon_restore_queue.is_empty() or not icon_transfer.is_empty() or machine.state != "idle" or action_session.is_active() or routine_session.is_active() or not press.is_empty() or menu.visible or hidden or suspended or desktop.is_minimized() or not desktop.is_visible() or not desktop.desktop_listview_available():
		# A due icon waits for the next placement cycle; current behavior is never
		# forcibly interrupted just to put something down.
		_schedule_icon_release_retry(now)
		return
	var due: Array = []
	var earliest_due := INF
	for entry in icon_bag_entries:
		var release_at := float(entry.get("release_at_ms", now))
		if release_at > now:
			continue
		if release_at < earliest_due - 1.0:
			due.clear()
			earliest_due = release_at
		if is_equal_approx(release_at, earliest_due):
			due.append(entry)
	if due.is_empty():
		_schedule_icon_release_retry(now)
		return
	var target := _find_icon_placement_target()
	if target.is_empty():
		_schedule_icon_release_retry(now)
		return
	var selected: Dictionary = due[randi() % due.size()]
	var name := str(selected.get("name", ""))
	if name.is_empty() or not _begin_icon_transfer(
		"release",
		name,
		selected.get("original_pos", {}),
		false,
		"autonomous_release",
		{"drop_position": Vector2(target.get("position", Vector2.ZERO))},
	):
		_schedule_icon_release_retry(now)
		return
	# The cooldown starts only after the shell restore has actually completed in
	# _finish_icon_restore("arrange"), not when the reverse-bag animation begins.
	next_icon_release_attempt_ms = -1.0

func _desktop_grid_spacing(items: Array) -> Vector2:
	var spacing := Vector2(desktop.desktop_icon_spacing())
	if spacing.x >= 32.0 and spacing.y >= 32.0:
		return spacing
	var xs: Array = []
	var ys: Array = []
	for item in items:
		if item is Dictionary:
			xs.append(int(item.get("x", 0)))
			ys.append(int(item.get("y", 0)))
	var inferred := ICON_DEFAULT_GRID_SPACING
	if xs.size() >= 2:
		xs.sort()
		for index in range(1, xs.size()):
			var delta := float(xs[index] - xs[index - 1])
			if delta >= 32.0:
				inferred.x = minf(inferred.x, delta)
				break
	if ys.size() >= 2:
		ys.sort()
		for index in range(1, ys.size()):
			var delta := float(ys[index] - ys[index - 1])
			if delta >= 32.0:
				inferred.y = minf(inferred.y, delta)
				break
	return inferred

func _desktop_grid_anchor(items: Array, bounds: Rect2) -> Vector2:
	var anchor := Vector2(bounds.position) + Vector2(24.0, 24.0)
	var found := false
	for item in items:
		if not item is Dictionary:
			continue
		var point := Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0)))
		if not found:
			anchor = point
			found = true
		else:
			anchor.x = minf(anchor.x, point.x)
			anchor.y = minf(anchor.y, point.y)
	return anchor

func _desktop_grid_key(point: Vector2, anchor: Vector2, spacing: Vector2) -> String:
	var gx := roundi((point.x - anchor.x) / maxf(1.0, spacing.x))
	var gy := roundi((point.y - anchor.y) / maxf(1.0, spacing.y))
	return "%d:%d" % [gx, gy]

func _desktop_grid_point(anchor: Vector2, spacing: Vector2, gx: int, gy: int) -> Vector2:
	return anchor + Vector2(float(gx) * spacing.x, float(gy) * spacing.y)

func _point_in_usable_screen(point: Vector2) -> bool:
	for screen in desktop.get_usable_screen_rects():
		if screen is Rect2 and screen.has_point(point):
			return true
	return false

func _placement_cell_is_valid(point: Vector2, spacing: Vector2, anchor: Vector2, occupied: Dictionary) -> bool:
	var center := point + spacing * 0.5
	if not _point_in_usable_screen(center):
		return false
	if Rect2(position, Vector2(pet_window_size)).grow(16.0).has_point(center):
		return false
	if occupied.has(_desktop_grid_key(point, anchor, spacing)):
		return false
	var cell := Rect2(point, spacing)
	for occluder in _occluding_rects():
		if cell.intersects(Rect2(occluder)):
			return false
	return true

## Search rings around the pet first, then widen to the current screen and the
## whole virtual desktop. The first ring with valid cells wins, preserving the
## requested nearby-first behavior while still guaranteeing a broad fallback.
func _find_icon_placement_target() -> Dictionary:
	if desktop == null or not desktop.desktop_listview_available():
		return {}
	var items: Array = desktop.enumerate_desktop_icons()
	var bounds := desktop.get_virtual_desktop_bounds()
	var spacing := _desktop_grid_spacing(items)
	var anchor := _desktop_grid_anchor(items, bounds)
	var occupied: Dictionary = {}
	for item in items:
		if item is Dictionary:
			var point := Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0)))
			occupied[_desktop_grid_key(point, anchor, spacing)] = true
	var foot := position + Vector2(WINDOW_FOOT_OFFSET_X, WINDOW_FOOT_OFFSET_Y)
	var snapped_foot := Vector2(
		anchor.x + roundf((foot.x - anchor.x) / spacing.x) * spacing.x,
		anchor.y + roundf((foot.y - anchor.y) / spacing.y) * spacing.y,
	)
	for ring in range(1, ICON_RELEASE_SEARCH_RINGS + 1):
		var candidates: Array = []
		for gx in range(-ring, ring + 1):
			for gy in range(-ring, ring + 1):
				if maxi(absi(gx), absi(gy)) != ring:
					continue
				var point := _desktop_grid_point(snapped_foot, spacing, gx, gy)
				if _placement_cell_is_valid(point, spacing, anchor, occupied):
					candidates.append(point)
		if not candidates.is_empty():
			return {"position": candidates[randi() % candidates.size()]}
	# Full fallback: inspect a bounded sample of grid cells across all usable
	# screens. This prevents pathological large virtual desktops from creating a
	# per-frame allocation storm while still finding a real empty cell.
	var fallback: Array = []
	for screen in desktop.get_usable_screen_rects():
		if not screen is Rect2:
			continue
		var gx := 0
		var x := float(screen.position.x)
		while x < screen.end.x and gx < 256:
			var gy := 0
			var y := float(screen.position.y)
			while y < screen.end.y and gy < 256:
				var point := Vector2(x, y)
				if _placement_cell_is_valid(point, spacing, anchor, occupied):
					fallback.append(point)
				if fallback.size() >= 256:
					break
				y += spacing.y
				gy += 1
			if fallback.size() >= 256:
				break
			x += spacing.x
			gx += 1
		if fallback.size() >= 256:
			break
	if fallback.is_empty():
		return {}
	return {"position": fallback[randi() % fallback.size()]}

## Candidate filter: un-collected, visible, reachable, and not recently failed
## or selected. Among those, use a layered score and weighted random choice.
func _pick_collectable_icon() -> Dictionary:
	if not desktop.desktop_listview_available():
		return {}
	var bag_names: Dictionary = {}
	for entry in icon_bag_entries:
		bag_names[str(entry.get("name", ""))] = true
	var candidates: Array = []
	var fresh_candidates: Array = []
	var now := _now_ms()
	for recent_name in icon_recent_targets.keys():
		if float(icon_recent_targets[recent_name]) <= now:
			icon_recent_targets.erase(recent_name)
	for item in desktop.enumerate_desktop_icons():
		if not item is Dictionary:
			continue
		var name := str(item.get("name", ""))
		if name.is_empty() or bag_names.has(name):
			continue
		var icon_pos := Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0)))
		if not _is_icon_visible(icon_pos):
			continue
		var analysis := _icon_reach_analysis(icon_pos)
		if not bool(analysis.get("reachable", false)):
			continue
		var modes: Array = analysis.get("modes", [])
		var has_walk := false
		var has_hop := false
		for mode in modes:
			match str(mode.get("mode", "")):
				"walk": has_walk = true
				"hop": has_hop = true
		var distance_factor := 1.0 / (1.0 + position.distance_to(icon_pos) / 600.0)
		var level_factor := 1.2 if absf(icon_pos.y - position.y) <= 240.0 else 0.9
		var terrain_factor := 1.15 if has_hop else (1.0 if has_walk else 0.85)
		var recent := float(icon_recent_targets.get(name, 0.0)) > now
		var recency_factor := 0.25 if recent else 1.0
		var candidate := {
			"item": item,
			"score": maxf(0.01, distance_factor * level_factor * terrain_factor * recency_factor),
			"recent": recent,
		}
		candidates.append(candidate)
		if not recent:
			fresh_candidates.append(candidate)
	if candidates.is_empty():
		return {}
	var pool: Array = fresh_candidates if not fresh_candidates.is_empty() else candidates
	var total := 0.0
	for entry in pool:
		total += float(entry.get("score", 0.01))
	var roll := randf() * total
	var chosen: Dictionary = {}
	for entry in pool:
		roll -= float(entry.get("score", 0.01))
		if roll <= 0.0:
			chosen = entry["item"]
			break
	if chosen.is_empty():
		chosen = (pool.back()["item"] as Dictionary)
	icon_recent_targets[str(chosen.get("name", ""))] = now + ICON_RECENT_TARGET_COOLDOWN_MS
	var result := chosen.duplicate(true)
	result["original"] = {"x": int(chosen.get("x", 0)), "y": int(chosen.get("y", 0))}
	return result

## ---- Backpack panel plumbing ----

func _open_backpack_panel() -> void:
	_refresh_backpack_panel()
	backpack_panel.popup_centered()

func _refresh_backpack_panel() -> void:
	var desktop_icons: Array = desktop.enumerate_desktop_icons() if desktop.desktop_listview_available() else []
	backpack_panel.update_view(icon_bag_entries, desktop_icons, ICON_BAG_CAPACITY)

func _on_backpack_reclaim(icon_name: String) -> void:
	var index := _icon_bag_entry_index(icon_name)
	if index < 0:
		return
	var entry: Dictionary = icon_bag_entries[index]
	var original: Dictionary = entry.get("original_pos", {})
	_begin_icon_transfer("reclaim", icon_name, original, backpack_panel.visible, "backpack")

func _on_backpack_give(icon_name: String) -> void:
	var original := _desktop_icon_position(icon_name)
	if original.is_empty():
		return
	_begin_icon_transfer("give", icon_name, original, backpack_panel.visible, "backpack")

func _on_backpack_restore_all() -> void:
	_restore_all_icons()

func _interrupt_action(kind: String, context: Dictionary = {}) -> void:
	_stop_roam()
	if routine_session.is_active():
		var resume_routine := kind in ["menu", "direct_interaction"]
		var routine_decision := routine_session.interrupt(kind, resume_routine)
		if routine_decision == "paused" and ecology_step_mode in ["travel", "special"]:
			motion.clear()
			if machine.state == "edge_patrol":
				_cancel_edge_patrol()
		elif routine_decision == "cancelled":
			ecology_step_mode = ""
	if not action_session.is_active():
		return
	var resolved_context := context.duplicate(true)
	if not resolved_context.has("platform_valid"):
		resolved_context["platform_valid"] = _platform_still_valid(active_platform)
	var decision := action_session.request_interrupt(kind, resolved_context, int(_now_ms()))
	if bool(decision.get("accepted", false)) and action_session.is_active() and bool(decision.get("phase_changed", false)):
		_play_action_session_clip()

func _defer_until_wake(kind: String, payload: Dictionary = {}) -> bool:
	if str(current_intent.get("id", "")) != "nap" or not action_session.is_active():
		return false
	deferred_wake_action = {"kind": kind, "payload": payload.duplicate(true)}
	_interrupt_action("menu" if kind == "menu" else "direct_interaction")
	return action_session.is_active()

func _run_deferred_wake_action() -> void:
	if deferred_wake_action.is_empty() or machine.state != "idle":
		return
	var deferred := deferred_wake_action.duplicate(true)
	deferred_wake_action.clear()
	var payload: Dictionary = deferred.get("payload", {})
	match str(deferred.get("kind", "")):
		"menu": _open_context_menu(Vector2(payload.get("position", Vector2.ZERO)))
		"click": _trigger_click()
		"poke": _trigger_poke()
		"bag": _trigger_bag_guard()
		"head_pat": _trigger_head_pat(bool(payload.get("auto_release", true)))
		"clock": _trigger_clock_scare()

func _try_resume_platform_action() -> void:
	if resumable_platform_intent.is_empty() or not action_session.has_resumable_session():
		return
	if not _platform_still_valid(active_platform):
		resumable_platform_intent.clear()
		action_session.discard_resume()
		return
	current_intent = resumable_platform_intent.duplicate(true)
	resumable_platform_intent.clear()
	if not action_session.resume({"platform_valid": true}, int(_now_ms())):
		current_intent.clear()
		action_session.discard_resume()
		return
	var requested_state := _machine_state_for_intent(current_intent)
	if machine.dispatch({"type": "ACTION_START", "state": requested_state}) != requested_state:
		current_intent.clear()
		action_session.discard_resume()
		return
	_play_action_session_clip()

func _platform_still_valid(platform: WindowPlatform) -> bool:
	if platform == null:
		return false
	var foot_x := _pet_foot_global().x
	for candidate in window_platform_service.last_platforms():
		if (
			candidate.handle == platform.handle
			and candidate.process_id == platform.process_id
			and candidate.contains_x(foot_x)
		):
			return true
	return false

## Rebuilds the collision lists of the shared DesktopWorld: walls come from the
## solid bodies (gated by the collision toggle); the standable planes come from the
## always-on WindowPlatform list so manual mode can stand on windows even when
## collision is disabled, matching the riding path. Planes are already
## occlusion-subtracted; the standing model additionally merges the standing
## window's per-frame live visible segments, so an occluded standing point is never
## kept on an injected full-width plane.
func _flatten_collision_world(now_ms: float) -> void:
	desktop_world.walls = []
	if window_collision_enabled:
		for body in window_bodies:
			desktop_world.walls.append_array(body.fragment_wall_edges())
	_rebuild_platform_planes(now_ms)


## Standable planes from the platform list (WindowPlatform, always on). Each plane
## is the occlusion-subtracted top segment in the model's foot space, carrying the
## (handle, process_id) identity so the model can distinguish windows. Transient
## windows (present < WINDOW_STAND_MIN_AGE_MS) are excluded from the STANDING list
## only — occlusion and walls always follow visible rendering.
func _rebuild_platform_planes(now_ms: float) -> void:
	var planes: Array = []
	for platform in platforms:
		planes.append({
			"left": float(platform.segment_left()),
			"right": float(platform.segment_right()),
			"y": float(platform.top_edge.position.y) - WINDOW_FOOT_OFFSET_Y,
			"handle": platform.handle,
			"process_id": platform.process_id,
		})
	desktop_world.platforms = WindowPlatformService.gate_transient_planes(planes, _window_first_seen_ms, now_ms, WINDOW_STAND_MIN_AGE_MS)


## Records when each window handle was first seen this session, so a freshly
## appeared popup is not stood on until it has existed for WINDOW_STAND_MIN_AGE_MS.
## Handles that left the platform set are dropped (a re-appear counts as new).
func _observe_window_first_seen(now: float) -> void:
	var present: Dictionary = {}
	for platform in platforms:
		present[platform.handle] = true
		if not _window_first_seen_ms.has(platform.handle):
			_window_first_seen_ms[platform.handle] = now
	var stale: Array = []
	for handle in _window_first_seen_ms:
		if not present.has(handle):
			stale.append(handle)
	for handle in stale:
		_window_first_seen_ms.erase(handle)


func _platform_for_identity(handle: int, pid: int) -> WindowPlatform:
	for platform in platforms:
		if platform.handle == handle and platform.process_id == pid:
			return platform
	return null


## The window the pet is currently standing on: the ridden platform, the pending
## travel target, or the model's standing plane (manual control / wall climb).
## Null when the pet is not committed to any window.
func _standing_platform() -> WindowPlatform:
	if active_platform != null:
		return active_platform
	if pending_platform != null:
		return pending_platform
	if manual_control_model != null:
		var handle: int = manual_control_model.standing_plane_handle()
		if handle != 0:
			return _platform_for_identity(handle, manual_control_model.standing_plane_pid())
	return null


## Handle of whatever window the pet stands on, 0 when none. Used by the event
## debouncer so dragging the standing window does not trigger redundant rebuilds.
func _standing_window_identity() -> int:
	var platform := _standing_platform()
	return platform.handle if platform != null else 0


func _wall_handle_present(handle: int) -> bool:
	for edge in desktop_world.walls:
		if int(edge.get("handle", 0)) == handle:
			return true
	return false


## Maps ride-feedback events onto existing animation assets and dialogue lines.
## Reaction clips are transient: they play over the ride clip and the model's
## CLIP_END restores the ride (or idle pose) instead of ending the platform state.
func _apply_ride_feedback_events(events: Array) -> void:
	for value in events:
		if not value is Dictionary:
			continue
		var kind := str(value.get("kind", ""))
		match kind:
			"start_move":
				_play_ride_reaction("react")
				_emit_dialogue("window_move")
			"wobble":
				_play_ride_reaction("look_around")
			"settle":
				_play_ride_reaction("idle_breathe")
			"resize":
				_play_ride_reaction("look_around")
				_emit_dialogue("window_resize")
			"restance":
				position.x = float(value.get("x", _pet_foot_global().x)) - WINDOW_FOOT_OFFSET_X
				_apply_position()


## Feeds one frame of ride feedback for a standing window and maps the reaction
## events onto animations and dialogue. Shared by the riding track loop and the
## manual-standing loop so every standing mode reacts the same way.
func _feed_standing_feedback(now: float, platform: WindowPlatform, prev_rect: Rect2i) -> void:
	if platform == null:
		return
	_apply_ride_feedback_events(ride_feedback_controller.update(
		now,
		prev_rect,
		platform.rect,
		_pet_foot_global().x,
		float(platform.segment_left()),
		float(platform.segment_right()),
	))


## Feeds ride feedback while the manual model stands on a window (keyboard
## control or wall-climb mount) with no ridden platform. The previous rect is
## cached per standing window; a gap larger than 2.5s re-baselines so leaving
## and re-approaching the same window is not read as a drag.
func _feed_manual_standing_feedback(now: float, platform: WindowPlatform) -> void:
	if platform == null:
		return
	if platform.handle != _manual_feedback_handle or now - _manual_feedback_last_at > 2500.0:
		_manual_feedback_handle = platform.handle
		_manual_feedback_prev_rect = platform.rect
	var prev_rect := _manual_feedback_prev_rect
	_feed_standing_feedback(now, platform, prev_rect)
	_manual_feedback_prev_rect = platform.rect
	_manual_feedback_last_at = now


func _is_standing_on_model_plane() -> bool:
	return manual_control_model != null and manual_control_model.standing_plane_handle() != 0


func _play_ride_reaction(clip_name: String) -> void:
	if not manifest.has_clip(clip_name):
		return
	if active_platform == null and not _is_standing_on_model_plane():
		return
	_ride_reaction_active = true
	_ride_reaction_clip = clip_name
	sprite_player.play_clip(clip_name)


## Floor plane in FOOT space, for the resolver which reasons about feet.
func _foot_floor() -> float:
	return _floor_y() + WINDOW_FOOT_OFFSET_Y


func _blocked_walk_wall(previous_position: Vector2, next_position: Vector2) -> Dictionary:
	if desktop_world.walls.is_empty():
		return {}
	return PetWallResolverScript.find_blocking_wall(
		_pet_foot_global(previous_position),
		_pet_foot_global(next_position),
		desktop_world.walls,
		_foot_floor(),
	)

func _update_window_platforms(now: float) -> void:
	window_event_debouncer.set_ridden_handle(_standing_window_identity())
	if now >= next_window_refresh:
		next_window_refresh = now + 500.0
		window_event_debouncer.acknowledge()
		var previous_handles := {}
		for platform in platforms:
			previous_handles[platform.handle] = true
		platforms = window_platform_service.refresh()
		window_bodies = window_platform_service.last_bodies()
		_observe_window_first_seen(now)
		_flatten_collision_world(now)
		for platform in platforms:
			if not previous_handles.has(platform.handle):
				needs_model.apply_event("novel_window")
				break
		var foreground := window_platform_service.foreground_snapshot()
		var foreground_app := str(foreground.get("process_name", ""))
		if not foreground_app.is_empty() and foreground_app != last_foreground_app:
			last_foreground_app = foreground_app
			needs_model.apply_event("novel_window")
			_emit_dialogue("app_context")
			var safe_app_title := dialogue_director.sanitize_window_title(str(foreground.get("title", ""))) if title_awareness else ""
			_observe_ecology("app_observed", {"app_category": dialogue_director.classify_application(foreground_app, safe_app_title)})
		if title_awareness:
			var stable_title := dialogue_director.observe_window_title(str(foreground.get("title", "")), now)
			if not stable_title.is_empty():
				if stable_title != last_novel_window_title:
					last_novel_window_title = stable_title
					needs_model.apply_event("novel_window")
				if stable_title != last_stable_window_title and _emit_dialogue("window_title"):
					last_stable_window_title = stable_title
	var standing := _standing_platform()
	if standing != null and now >= next_platform_track:
		# The gap since the last tick scales the teleport threshold inside the
		# service: a fast drag across a hitched/stale-rect tick must still follow.
		var track_elapsed_ms := now - _last_platform_track_at if _last_platform_track_at > 0.0 else -1.0
		_last_platform_track_at = now
		next_platform_track = now + PLATFORM_TRACK_INTERVAL_MS
		if pending_platform != null:
			_track_pending_platform(track_elapsed_ms)
		else:
			var tracking := window_platform_service.track_platform(standing, null, _pet_foot_global().x, track_elapsed_ms)
			if bool(tracking.get("lost", false)):
				_on_standing_window_lost(standing, tracking, track_elapsed_ms)
			elif active_platform != null:
				# The standing point is covered by a front window: hold position (no
				# follow, no y-pin) and, after the grace, drop. A transient mid-drag
				# occlusion recovers once the occluder rects refresh; a persistent one
				# is a real occlusion, so the rider falls instead of riding a hidden edge.
				if str(tracking.get("status", "")) == "occluded":
					if track_elapsed_ms > 0.0:
						_rider_occlusion_ms += track_elapsed_ms
					if _rider_occlusion_ms >= RIDER_OCCLUSION_GRACE_MS:
						_rider_occlusion_ms = 0.0
						_drop_from_platform("occluded")
					return
				_rider_occlusion_ms = 0.0
				var prev_rect := standing.rect
				var fresh := tracking.get("platform") as WindowPlatform
				var center_delta := fresh.center().x - standing.center().x
				active_platform = fresh
				_feed_standing_feedback(now, fresh, prev_rect)
				# Riding follows the window: the visible-segment center displacement
				# (drag + resize both move it, matching the model's center-delta
				# follow) plus an absolute foot pin to the window's top edge.
				# Manual standing follows inside the model, so it never reaches
				# this branch.
				if not is_zero_approx(center_delta):
					_observe_ecology("moving_platform")
					var delta := Vector2(center_delta, 0.0)
					position += delta
					if not platform_walk_motion.is_empty():
						platform_walk_motion.from += delta
						platform_walk_motion.to += delta
				# Pin the foot with the CURRENT pose's offset, not the standing
				# constant: riding clips like the window sit keep their feet at a
				# different supportContactY offset (e.g. ~261 vs 356 for standing).
				# A hardcoded standing pin fights _on_sprite_frame_changed's live
				# per-frame correction and the pet vibrates vertically on the ledge.
				position.y = float(fresh.top_edge.position.y) - _riding_foot_offset_y()
				_apply_position()
			else:
				_feed_manual_standing_feedback(now, tracking.get("platform") as WindowPlatform)
	if machine.state == "platform_walk" and not platform_walk_motion.is_empty():
		_update_platform_walk(now)
	if active_platform != null and machine.state == "idle" and auto_wander and now >= next_platform_swap:
		next_platform_swap = now + randf_range(45000.0, 90000.0)
		var nearby = WindowPlatformService.choose_nearby_platform(active_platform, platforms)
		if nearby is WindowPlatform and randf() < 0.6:
			_travel_to_platform(nearby)

func _prepare_platform_walk(intent: Dictionary) -> Dictionary:
	if active_platform == null:
		return intent
	var foot := _pet_foot_global()
	var left := float(active_platform.segment_left() + 54)
	var right := float(active_platform.segment_right() - 54)
	if right <= left:
		return intent
	var target_x := right if foot.x < (left + right) / 2.0 else left
	# A taller window rising beside the paced segment is an encounter like any roam
	# wall: hop onto a short one, climb a reachable tall one, or fly over. The
	# resolver floor is the platform top (the pet's feet), so `short` is relative to
	# the ledge, not the ground. The standing window's own fragment edges are not
	# climb targets — they are just the paced segment's boundaries.
	var blocked := PetWallResolverScript.find_blocking_wall(
		foot,
		Vector2(target_x, foot.y),
		desktop_world.walls,
		foot.y,
		WINDOW_HOP_REACH_PX,
	)
	if not blocked.is_empty() and int(blocked.get("handle", 0)) != active_platform.handle:
		if bool(blocked.get("short", false)):
			var hop_platform := _platform_for_identity(int(blocked.get("handle", 0)), int(blocked.get("process_id", 0)))
			if hop_platform != null:
				roam_session.redirect = {"kind": "hop", "platform": hop_platform}
				_advance_or_schedule_wander()
				return {}
		var wall_top_y := float(blocked.get("top_y", 0.0))
		if wall_top_y - WINDOW_FOOT_OFFSET_Y >= work_area.position.y and _has_wall_climb_assets():
			roam_session.redirect = {"kind": "climb", "wall": blocked}
		else:
			roam_session.redirect = {"kind": "fly", "wall": blocked}
		_advance_or_schedule_wander()
		return {}
	var walk_facing := 1 if target_x > foot.x else -1
	var clip_name := "patrol_floor_right" if walk_facing > 0 else "patrol_floor_left"
	var result := intent.duplicate(true)
	result.clip = clip_name
	result.action = clip_name
	var session: Dictionary = result.get("session", {}).duplicate(true)
	session.clip = clip_name
	result.session = session
	var target_position := _position_for_platform(active_platform, target_x)
	platform_walk_motion = {
		"from": position,
		"to": target_position,
		"started_at": _now_ms(),
		"duration_ms": maxf(900.0, absf(target_x - foot.x) / 82.0 * 1000.0),
	}
	facing = walk_facing
	return result

func _update_platform_walk(now: float) -> void:
	var duration := maxf(1.0, float(platform_walk_motion.get("duration_ms", 1.0)))
	var progress := clampf((now - float(platform_walk_motion.get("started_at", now))) / duration, 0.0, 1.0)
	position = Vector2(platform_walk_motion.from).lerp(Vector2(platform_walk_motion.to), progress)
	_apply_position()
	if progress >= 1.0:
		platform_walk_motion.clear()
		action_session.request_finish(int(now))

func _travel_to_platform(platform: WindowPlatform) -> bool:
	if platform == null or machine.state != "idle":
		return false
	var target_x := clampf(platform.center().x, float(platform.segment_left() + 48), float(platform.segment_right() - 48))
	var target := _position_for_platform(platform, target_x)
	pending_platform = platform
	active_platform = null
	platform_walk_motion.clear()
	_prepare_motion(target, _travel_duration_ms(position.distance_to(target)), 82.0, false)
	var needs_turn := _prepare_travel_facing(target.x)
	machine.dispatch({"type": "WANDER", "needs_turn": needs_turn})
	sfx_player.play("window_hop")
	return true

## Unmounts the pet from whatever window it is standing on (riding platform,
## pending travel target, or platform-walk motion) and clears the ride-feedback
## session. Every mode that abandons a window — drag, roam, edge patrol, manual
## control entry, ecology travel, slides and throws — routes through this one
## function so the "leave a window" rule is defined once.
func _unmount_from_window() -> void:
	active_platform = null
	pending_platform = null
	platform_walk_motion.clear()
	ride_feedback_controller.reset()
	_manual_feedback_handle = 0
	_manual_feedback_prev_rect = Rect2i()
	_manual_feedback_last_at = -INF


## Unified flight-travel duration: distance-proportional with a fixed clamp band.
func _travel_duration_ms(distance: float) -> float:
	return clampf(distance * 1.5, 850.0, 2200.0)


## Unified falling duration: base plus distance, matching umbrella fall timing.
func _fall_duration_ms(fall_distance: float) -> float:
	return clampf(380.0 + fall_distance * 0.7, 420.0, 1700.0)


## Unified throw-arc duration.
func _throw_arc_duration_ms(distance: float) -> float:
	return clampf(distance / 900.0 * 1000.0, 400.0, 1400.0)


## Unified handling when the standing window disappears or teleports away.
## Riding drops immediately; manual/wall-climb standing is owned by the model's
## grace window, so the loss is only logged here and the model decides the fall.
func _on_standing_window_lost(standing: WindowPlatform, tracking: Dictionary, elapsed_ms: float) -> void:
	_log_ride_drop("track", {
		"reason": str(tracking.get("reason", "missing")),
		"platform_rect": standing.rect,
		"snapshot_rect": (tracking.get("snapshot", {}) as Dictionary).get("rect", Rect2i()),
		"delta": tracking.get("delta", Vector2i.ZERO),
		"elapsed_ms": elapsed_ms,
		"standing_x": _pet_foot_global().x,
		"z_order": standing.z_order,
	})
	if active_platform != null:
		_drop_from_platform(str(tracking.get("reason", "missing")))


func _drop_from_platform(_reason: String) -> void:
	if active_platform == null:
		return
	last_platform_lost_reason = _reason
	_log_ride_drop("drop", {"reason": _reason})
	_unmount_from_window()
	resumable_platform_intent.clear()
	_interrupt_action("platform_lost")
	var floor_target := _clamp_position(Vector2(position.x, _floor_y()), true)
	var fall_distance := maxf(0.0, floor_target.y - position.y)
	drag_fall_mode = "umbrella" if PetUmbrellaFall.should_use(fall_distance, _has_umbrella_family()) else "direct"
	_prepare_motion(floor_target, _fall_duration_ms(fall_distance), 0.0)
	machine.dispatch({"type": "PLATFORM_LOST"})
	_emit_dialogue("window_lost")


## Empirical diagnostic: append one line per ride drop so a drag-induced drop can
## be attributed from the log instead of guessed at. Written to an absolute path
## because the pet is usually run from the exported exe. Remove after diagnosis.
func _log_ride_drop(tag: String, info: Dictionary) -> void:
	var line := "[%s] %s drop=%s pos=%s foot=%s state=%s platforms=%d bodies=%d collision=%s self_z=%s"
	line = line % [
		str(_now_ms()),
		tag,
		str(info.get("reason", "")),
		str(position),
		str(_pet_foot_global()),
		str(machine.state),
		platforms.size(),
		window_bodies.size(),
		str(window_collision_enabled),
		str(window_platform_service.self_z_order()),
	]
	for key in info:
		if key == "reason":
			continue
		line += " %s=%s" % [str(key), str(info[key])]
	var file := FileAccess.open("D:/workspace/project-chihiro/build/ride_drop.log", FileAccess.WRITE)
	if file == null:
		return
	file.store_line(line)
	file.close()

func _track_pending_platform(elapsed_ms: float = -1.0) -> void:
	if pending_platform == null or motion.is_empty():
		return
	var target_foot_x := _pet_foot_global(Vector2(motion.get("to", position))).x
	var tracking := window_platform_service.track_platform(pending_platform, null, target_foot_x, elapsed_ms)
	if bool(tracking.get("lost", false)):
		_log_ride_drop("pending", {
			"reason": str(tracking.get("reason", "missing")),
			"platform_rect": pending_platform.rect,
			"snapshot_rect": (tracking.get("snapshot", {}) as Dictionary).get("rect", Rect2i()),
			"delta": tracking.get("delta", Vector2i.ZERO),
			"elapsed_ms": elapsed_ms,
			"standing_x": target_foot_x,
			"z_order": pending_platform.z_order,
		})
		pending_platform = null
		var floor_target := _clamp_position(Vector2(position.x, _floor_y()), true)
		_prepare_motion(floor_target, _fall_duration_ms(position.distance_to(floor_target)), 0.0)
		_emit_dialogue("window_lost")
		return
	var delta := Vector2(tracking.get("delta", Vector2i.ZERO))
	pending_platform = tracking.get("platform") as WindowPlatform
	var next_foot_x := clampf(
		target_foot_x + delta.x,
		float(pending_platform.segment_left() + 48),
		float(pending_platform.segment_right() - 48),
	)
	motion["to"] = _position_for_platform(pending_platform, next_foot_x)

func _pet_foot_global(at_position: Variant = null) -> Vector2:
	var resolved_position := position if at_position == null else Vector2(at_position)
	var clip := manifest.clip(sprite_player.current_clip)
	var canvas: Dictionary = clip.get("canvas", manifest.canvas())
	var anchor: Dictionary = clip.get("anchor", {"x": 0.5, "y": 0.96})
	var anchor_point := Vector2(
		float(anchor.get("x", 0.5)) * float(canvas.get("width", 512.0)),
		float(anchor.get("y", 0.96)) * float(canvas.get("height", 512.0)),
	)
	var support_point := PetRenderBox.support_texture_point(clip, sprite_player.current_frame)
	var support_offset := (support_point - anchor_point) * PetRenderBox.character_scale(manifest)
	support_offset.x *= direction
	var dock := PetRenderBox.dock_point(
		Vector2(pet_window_size),
		PetRenderBox.render_dock(clip),
		PetRenderBox.render_dock_inset(clip),
	)
	var legacy_inset := 0.0 if not (clip.get("supportContactY", []) as Array).is_empty() else 4.0
	return resolved_position + dock + support_offset + Vector2(0.0, legacy_inset)


## Y offset from the pet box top to the current pose's foot, shared with the
## riding pin (PetRenderBox.foot_offset_y). Riding pins the foot with this live
## offset; the standing constant (WINDOW_FOOT_OFFSET_Y = 356) only matches
## standing/walking clips, and a hardcoded pin fights the per-frame foot
## correction on riding poses like the window sit (supportContactY keeps the
## sitting feet higher).
func _riding_foot_offset_y() -> float:
	return PetRenderBox.foot_offset_y(
		manifest.clip(sprite_player.current_clip),
		sprite_player.current_frame,
		Vector2(pet_window_size),
		PetRenderBox.character_scale(manifest),
	)

func _position_for_platform(platform: WindowPlatform, foot_x: float) -> Vector2:
	var local_foot := _pet_foot_global(Vector2.ZERO)
	return Vector2(foot_x - local_foot.x, float(platform.top_edge.position.y) - local_foot.y)

func _on_transition(from: String, to: String, _event: Dictionary) -> void:
	# Any state transition plays its own clip, interrupting a ride/window reaction
	# mid-play. Drop the reaction bookkeeping so a stale flag cannot gate the next
	# state's clip logic (e.g. manual control's _apply_control_clip yielding).
	_ride_reaction_active = false
	_ride_reaction_clip = ""
	wander_deadline = -1.0
	blink_deadline = -1.0
	idle_side_pose_deadline = -1.0
	side_pose_reverting = false
	if from == "cursor_confiscate" and to != "cursor_confiscate":
		_abort_cursor_confiscation()
	if from == "icon_collect" and to != "icon_collect":
		_abort_icon_collection()
	if from == "icon_transfer" and to != "icon_transfer":
		_abort_icon_transfer()
	if to != "idle" and not pending_front_intent.is_empty():
		pending_front_intent.clear()
		pending_front_handoff_clip = ""
	var keeps_paused_patrol := not edge_session.is_empty() and bool(edge_session.get("paused", false)) and to in ["menu_wait", "head_pat", "poke_cheek", "clock_scare"]
	if not edge_session.is_empty() and to != "edge_patrol" and not keeps_paused_patrol:
		_cancel_edge_patrol()
	if from == "dragged" and to != "dragged":
		_reset_drag_visual()
	if from == "sleeping" and to != "sleeping" and action_session.is_active() and action_session.current_phase() == "exit":
		action_session.on_clip_finished(int(_now_ms()))
	if to not in ["idle", "notice", "cursor_track"]:
		gesture_recognizer.reset()
	if to == "suspended":
		return
	if to in ["float", "drag_fall"] and motion.is_empty():
		var target := Vector2(position.x, _floor_y())
		_prepare_motion(target, 420.0 if to == "drag_fall" else 240.0, 0.0)
	if to == "idle":
		_play_idle_entry_or_pose()
		if from == "boot":
			_emit_dialogue("return" if returned_after_seconds >= 1800.0 else "greeting")
		if not resumable_platform_intent.is_empty():
			call_deferred("_try_resume_platform_action")
		if not deferred_wake_action.is_empty():
			call_deferred("_run_deferred_wake_action")
		if routine_session.is_paused() and from in ["menu_wait", "head_pat", "poke_cheek", "clock_scare", "cursor_startle", "cursor_annoyed", "cursor_dizzy"]:
			if routine_session.resume(ecology_clock.elapsed_ms()):
				call_deferred("_run_current_routine_step")
		elif routine_session.is_active() and ecology_step_mode in ["travel", "special"]:
			call_deferred("_complete_ecology_step", "completed")
	elif to == "edge_patrol":
		if not edge_session.is_empty() and bool(edge_session.get("paused", false)):
			_resume_edge_patrol()
		else:
			_advance_edge_patrol()
	elif to == "turn":
		_set_direction(1)
		sprite_player.play_clip("turn", true, _facing_segment(pending_facing))
	elif to == "takeoff":
		facing = pending_facing
		_set_direction(1)
		sprite_player.play_clip("takeoff", true, _facing_segment(facing))
	elif to == "float":
		airborne_phase = ""
		_play_airborne_phase("fall" if float(motion.get("arc_height", 0.0)) == 0.0 else "rise")
	elif to == "drag_fall":
		if drag_fall_mode == "umbrella" and _has_umbrella_family():
			_play_umbrella_phase("open")
		else:
			_play_drag_fall()
	elif to == "land":
		idle_pose_facing = facing
		_set_direction(1)
		_play_segment_or_clip("land", _facing_segment(facing))
		sfx_player.play("land")
		if from == "drag_fall" and drag_fall_mode == "umbrella":
			_observe_ecology("umbrella_land")
	elif to == "dragged":
		_play_drag_visual("grab")
	elif to == "drag_slide":
		facing = 1 if slide_speed >= 0.0 else -1
		_set_direction(1)
		sprite_player.play_clip("idle")
	elif to == "drag_throw":
		_set_direction(1)
		sprite_player.play_clip("float", true, "%s-rise" % _facing_segment(facing))
	elif to == "head_pat":
		if head_pat_refused:
			sprite_player.play_clip("head_pat_refuse" if manifest.has_clip("head_pat_refuse") else "react")
		else:
			sprite_player.play_clip("head_pat_accept")
	elif to == "cursor_track":
		_play_gaze_clip()
	elif to == "cursor_startle":
		sprite_player.play_clip("react")
	elif to == "cursor_annoyed":
		sprite_player.play_clip("poke_cheek")
	elif to == "poke_cheek":
		sprite_player.play_clip(poke_visual_clip if manifest.has_clip(poke_visual_clip) else "poke_cheek")
	elif to in ["ambient_action", "sleeping", "platform_transition", "platform_walk", "platform_sit"]:
		_play_action_session_clip()
	elif to == "manual_control":
		motion.clear()
		_last_control_clip = ""
		_last_control_segment = ""
		_set_direction(1)
		sprite_player.play_clip("idle")
	elif to == "roam_walk":
		_set_direction(1)
		sprite_player.play_clip("patrol_floor_right" if facing > 0 else "patrol_floor_left")
	elif to == "icon_transfer":
		var transfer_kind := str(icon_transfer.get("kind", ""))
		sprite_player.play_clip("straighten_bag", true, "", transfer_kind in ["reclaim", "release", "restore_all"])
	else:
		sprite_player.play_clip(to)
	if to != "float": airborne_phase = ""
	if to != "drag_fall": umbrella_visual_phase = ""
	if to == "idle": _advance_or_schedule_wander()

func _on_clip_completed(clip_name: String, _segment: String) -> void:
	if machine.state == "cursor_confiscate":
		_handle_cursor_confiscate_clip(clip_name)
		return
	if machine.state == "icon_collect":
		_handle_icon_collect_clip(clip_name)
		return
	if machine.state == "icon_transfer":
		_handle_icon_transfer_clip(clip_name)
		return
	if machine.state == "idle" and not pending_front_intent.is_empty() and clip_name == pending_front_handoff_clip:
		var intent := pending_front_intent.duplicate(true)
		pending_front_intent.clear()
		pending_front_handoff_clip = ""
		idle_pose_facing = 0
		call_deferred("_resume_front_handoff", intent)
		return
	if action_session.is_active() and clip_name == action_session.current_clip():
		action_session.on_clip_finished(int(_now_ms()))
		if action_session.is_active():
			_play_action_session_clip()
		return
	if machine.state == "manual_control" and manual_control_model != null and manual_control_model.has_pending_attach() and clip_name == manual_control_model.attach_clip():
		manual_control_model.finish_attach()
		_emit_control_quip("control_climb")
		return
	if machine.state == "manual_control" and manual_control_model != null and manual_control_model.has_pending_detach() and clip_name == manual_control_model.detach_clip():
		manual_control_model.finish_detach()
		_emit_control_quip("control_detach")
		return
	if machine.state == "manual_control" and manual_control_model != null and manual_control_model.has_pending_mount() and clip_name == manual_control_model.mount_clip():
		manual_control_model.finish_mount()
		_emit_dialogue("window_land")
		_observe_ecology("window_land")
		return
	if machine.state == "wall_climb":
		_handle_wall_climb_clip_completed(clip_name)
		return
	if machine.state == "manual_control" and manual_control_model != null and manual_control_model.subphase == "fall" and clip_name == "drag_fall":
		sprite_player.play_clip("drag_fall", true, _facing_segment(facing))
		return
	if machine.state == "manual_control" and clip_name in ["umbrella_open", "umbrella_float", "umbrella_close"]:
		# An umbrella phase clip finished while the phase is still current. Flag it
		# so the next control tick re-issues the phase; the umbrella fall has long
		# phases (float can last hundreds of ms) and without this the sprite would
		# freeze on the last frame until the phase changes.
		_umbrella_control_dirty = true
		return
	if head_pat_refused and machine.state == "head_pat" and clip_name in ["head_pat_refuse", "react"]:
		head_pat_refused = false
		machine.dispatch({"type": "INTERACTION_END", "resume": _resolve_resume(interaction_resume)})
		return
	if clip_name == "head_pat_accept" and machine.state == "head_pat":
		machine.dispatch({"type": "INTERACTION_END", "resume": _resolve_resume(interaction_resume)})
		return
	if machine.state == "edge_patrol" and not edge_session.is_empty():
		var pose: Dictionary = edge_session.get("pose", {})
		if pose.get("kind", "") == "corner" and clip_name == str(pose.get("clip_name", "")):
			_advance_edge_patrol()
			return
	if machine.state == "idle" and side_pose_reverting and clip_name in ["idle_left_enter", "idle_right_enter"]:
		side_pose_reverting = false
		idle_pose_facing = 0
		idle_side_pose_deadline = -1.0
		_play_idle_pose()
		return
	if machine.state == "idle" and clip_name in ["idle_left_enter", "idle_right_enter", "idle_blink", "idle_left_blink", "idle_right_blink"]:
		_play_idle_pose()
		return
	if machine.state == "dragged":
		if clip_name == "drag_grab" and drag_visual_phase == "grab":
			if _now_ms() - drag_last_sample_at >= PetDragMotion.IDLE_BRAKE_MS:
				drag_motion_intent = "hold"
			_play_drag_visual(drag_motion_intent)
			return
		if clip_name == "drag_brake" and drag_visual_phase == "brake":
			_play_drag_visual(drag_motion_intent)
			return
		if clip_name in ["drag_grab", "drag_hold", "drag_left", "drag_right", "drag_brake"]:
			return
	if machine.state == "drag_fall" and drag_fall_mode == "umbrella" and clip_name in ["umbrella_open", "umbrella_float", "umbrella_close"]:
		return
	if machine.state == "poke_cheek" and clip_name in ["poke_cheek", "guard_bag_annoyed"]:
		poke_visual_clip = "poke_cheek"
		machine.dispatch({"type": "INTERACTION_END", "resume": _resolve_resume(interaction_resume)})
		return
	if clip_name == "clock_scare" and machine.state == "clock_scare":
		machine.dispatch({"type": "INTERACTION_END", "resume": _resolve_resume(interaction_resume)})
		return
	if (clip_name == "react" and machine.state == "cursor_startle") or (clip_name == "poke_cheek" and machine.state == "cursor_annoyed") or (clip_name == "cursor_dizzy" and machine.state == "cursor_dizzy"):
		machine.dispatch({"type": "INTERACTION_END", "resume": _resolve_resume(interaction_resume)})
		return
	if machine.state == "land" and active_platform != null and manifest.has_clip("window_land_recover"):
		machine.dispatch({"type": "CLIP_END"})
		_start_direct_behavior("window_land_recover")
		return
	if _ride_reaction_active and clip_name == _ride_reaction_clip:
		_ride_reaction_active = false
		_ride_reaction_clip = ""
		if machine.state == "manual_control" or machine.state == "wall_climb":
			_restore_control_clip_after_reaction()
		elif action_session.is_active():
			_play_action_session_clip()
		else:
			_play_idle_pose()
		return
	machine.dispatch({"type": "CLIP_END"})

func _on_clip_changed(name: String, previous_name: String) -> void:
	var clip := manifest.clip(name)
	var previous := manifest.clip(previous_name)
	var next_size := _desired_window_size(clip)
	_set_window_geometry(next_size, previous, clip)

func _on_sprite_frame_changed(_frame_index: int, _frame_count: int) -> void:
	if active_platform == null:
		return
	var adjustment := float(active_platform.top_edge.position.y) - _pet_foot_global().y
	if absf(adjustment) < 0.01:
		return
	position.y += adjustment
	_apply_position()

func _on_sprite_loop_boundary(clip_name: String, _segment: String, _completed_cycle: int) -> void:
	# A looping reaction clip (e.g. idle_breathe for a settle) would never fire
	# clip_completed, so end the reaction after one cycle and restore like a
	# one-shot reaction does.
	if _ride_reaction_active and clip_name == _ride_reaction_clip:
		_ride_reaction_active = false
		_ride_reaction_clip = ""
		if machine.state == "manual_control" or machine.state == "wall_climb":
			_restore_control_clip_after_reaction()
		elif action_session.is_active():
			_play_action_session_clip()
		else:
			_play_idle_pose()
		return
	if not action_session.is_active() or action_session.current_phase() != "loop" or action_session.current_clip() != clip_name:
		return
	if action_session.on_loop_boundary(int(_now_ms())):
		_play_action_session_clip()

func _on_passthrough_polygon_changed(polygon: PackedVector2Array) -> void:
	desktop.set_mouse_passthrough(polygon)

func _show_speech(id: String, text: String, duration_seconds := -1.0) -> void:
	if not speech_bubbles_enabled or hidden or suspended or not desktop.is_visible() or desktop.is_minimized() or text.strip_edges().is_empty():
		return
	speech_bubble.show_message(id, text, duration_seconds, _speech_anchor_rect(), work_area)
	next_speech_follow = _now_ms() + SPEECH_FOLLOW_INTERVAL_MS
	sfx_player.play("bubble", 0.02)

func _speech_anchor_rect() -> Rect2:
	return Rect2(position, Vector2(pet_window_size))

func _desired_window_size(clip: Dictionary) -> Vector2i:
	return render_box_lock if render_box_lock is Vector2i else PetRenderBox.resolve_size(manifest, clip)

func _begin_press(local_point: Vector2) -> void:
	if machine.state == "suspended" or menu.visible:
		return
	var hit := sprite_player.hit_test(local_point)
	if hit.is_empty():
		return
	var global := Vector2(desktop.get_cursor_position())
	var now := _now_ms()
	wander_deadline = -1.0
	press = {
		"started_at": now,
		"start_global": global,
		"offset": global - position,
		"zone": str(hit.get("zone", "body")),
		"intent": "pending",
		"samples": [{"point": global, "time": now}],
	}

func _update_long_press(now: float) -> void:
	if press.is_empty() or str(press.get("intent", "")) != "pending" or str(press.get("zone", "")) != "head":
		return
	if now - float(press.get("started_at", now)) >= float(manifest.behavior_value("longPressMs", 350.0)):
		_evaluate_press_intent(Vector2(desktop.get_cursor_position()), now)

func _update_press_drag() -> void:
	if press.is_empty():
		return
	var global := Vector2(desktop.get_cursor_position())
	var now := _now_ms()
	_evaluate_press_intent(global, now)
	if press.is_empty() or str(press.get("intent", "")) != "drag":
		return
	position = _clamp_position(global - Vector2(press.offset), false)
	var samples: Array = press.samples
	samples.append({"point": global, "time": now})
	var retained: Array = []
	for sample in samples:
		if now - float(sample.time) <= 120.0:
			retained.append(sample)
	press.samples = retained
	_update_drag_visual_from_samples(now)
	_apply_position()

func _evaluate_press_intent(global: Vector2, now: float) -> void:
	if press.is_empty():
		return
	var current := str(press.get("intent", "pending"))
	if current == "drag":
		return
	var distance := global.distance_to(Vector2(press.start_global))
	var drag_threshold := float(manifest.behavior_value("dragThresholdPx", 7.0))
	var long_press_ms := float(manifest.behavior_value("longPressMs", 350.0))
	var next := current
	if distance >= drag_threshold:
		next = "drag"
	elif current != "long_press" and str(press.zone) == "head" and now - float(press.started_at) >= long_press_ms:
		next = "long_press"
	if next == current:
		return
	press.intent = next
	if next == "long_press":
		_start_head_pat(_capture_resume_state())
	elif next == "drag":
		head_pat_deadline = -1.0
		_interrupt_action("dragging")
		_unmount_from_window()
		motion.clear()
		var samples: Array = press.samples
		samples.append({"point": global, "time": now})
		press.samples = samples
		_begin_drag_visual(now)
		machine.dispatch({"type": "DRAG_START"})

func _finish_press(cancelled: bool) -> void:
	if press.is_empty():
		return
	var intent := str(press.get("intent", "pending"))
	var zone := str(press.get("zone", "body"))
	if intent == "drag":
		var velocity := _drag_velocity_px_per_ms(press.get("samples", []))
		if velocity.length() * 1000.0 >= ROUGH_DRAG_SPEED_PX_PER_SECOND:
			needs_model.apply_event("rough_drag")
			_bump_interaction("rough_drags")
			_emit_dialogue("rough_drag")
		var grounded := absf(position.y - _floor_y()) < SLIDE_GROUND_THRESHOLD
		if grounded and absf(velocity.x) >= SLIDE_MIN_VELOCITY:
			_start_ground_slide(velocity)
			_emit_control_quip("fling_slide")
		elif not grounded and velocity.y < -THROW_MIN_UP_VELOCITY:
			_start_air_throw(velocity)
			_emit_control_quip("fling_throw")
		else:
			var floor_target := _clamp_position(Vector2(position.x, _floor_y()), true)
			var fall_distance := maxf(0.0, floor_target.y - position.y)
			var use_umbrella := PetUmbrellaFall.should_use(
				fall_distance,
				_has_umbrella_family(),
				float(manifest.behavior_value("umbrellaMinDropPx", 120.0)),
			)
			var projected_x := velocity.x * 120.0
			if use_umbrella:
				projected_x = PetUmbrellaFall.clamp_drift(projected_x)
			var target := _clamp_position(Vector2(position.x + projected_x, _floor_y()), true)
			var fall_duration := PetUmbrellaFall.duration_ms(
				fall_distance,
				float(manifest.behavior_value("umbrellaFallMinDurationMs", 1000.0)),
				float(manifest.behavior_value("umbrellaFallMaxDurationMs", 2200.0)),
			) if use_umbrella else _fall_duration_ms(fall_distance)
			drag_fall_mode = "umbrella" if use_umbrella else "direct"
			umbrella_visual_phase = ""
			_prepare_motion(target, fall_duration, 0.0)
			_prepare_travel_facing(target.x)
			facing = pending_facing
			machine.dispatch({"type": "DRAG_END"})
			_emit_control_quip("fling")
		_save_position()
	elif intent == "long_press":
		_end_head_pat()
	elif not cancelled:
		if zone == "head": _trigger_poke()
		elif zone == "bag": _trigger_bag_guard()
		else: _trigger_click()
	press.clear()
	if machine.state == "idle": _schedule_wander()

func _trigger_click() -> void:
	if _defer_until_wake("click"):
		return
	if not _claim_click():
		return
	_interrupt_action("direct_interaction")
	needs_model.apply_event("friendly_interaction")
	_bump_interaction("positive", true)
	machine.dispatch({"type": "CLICK"})

func _trigger_poke() -> void:
	if _defer_until_wake("poke"):
		return
	if not _claim_click():
		return
	_interrupt_action("direct_interaction")
	var now := _now_ms()
	var retained: Array[float] = []
	for timestamp in poke_timestamps:
		if now - timestamp <= RAPID_POKE_WINDOW_MS:
			retained.append(timestamp)
	retained.append(now)
	poke_timestamps = retained
	if poke_timestamps.size() >= 3:
		needs_model.apply_event("rapid_poke")
	else:
		needs_model.apply_event("rapid_poke", {"effects": {"affection": 0.3, "irritation": -6.0}})
	_bump_interaction("pokes")
	_emit_dialogue("poke")
	poke_visual_clip = "poke_cheek"
	var resume := _resume_for_new_interaction()
	_leave_menu_for_interaction(resume)
	interaction_resume = resume
	machine.dispatch({"type": "POKE"})

func _trigger_head_pat(auto_release: bool) -> void:
	if _defer_until_wake("head_pat", {"auto_release": auto_release}):
		return
	_interrupt_action("direct_interaction")
	var resume := _resume_for_new_interaction()
	_leave_menu_for_interaction(resume)
	_start_head_pat(resume)
	if auto_release and machine.state == "head_pat":
		head_pat_deadline = _now_ms() + AUTO_HEAD_PAT_MS

func _start_head_pat(resume: String) -> void:
	if _defer_until_wake("head_pat", {"auto_release": true}):
		return
	_interrupt_action("direct_interaction")
	interaction_resume = resume
	head_pat_refused = needs_model.get_need("irritation") >= 45.0 or (needs_model.relationship_tier() == "distant" and randf() < 0.65)
	if head_pat_refused:
		needs_model.apply_event("head_pat_accepted", {"effects": {"affection": -0.08, "irritation": 6.0}})
		_emit_dialogue("head_pat_refuse")
	else:
		needs_model.apply_event("head_pat_accepted")
		_bump_interaction("head_pats", true)
		_emit_dialogue("head_pat_accept")
	machine.dispatch({"type": "HEAD_PAT_START"})

func _end_head_pat() -> void:
	head_pat_deadline = -1.0
	if machine.state == "head_pat" and head_pat_refused:
		head_pat_refused = false
		machine.dispatch({"type": "INTERACTION_END", "resume": _resolve_resume(interaction_resume)})

func _trigger_bag_guard() -> void:
	if _defer_until_wake("bag"):
		return
	if not _claim_click():
		return
	_interrupt_action("direct_interaction")
	needs_model.apply_event("rapid_poke", {"effects": {"affection": 0.3, "irritation": -2.0}})
	_bump_interaction("pokes")
	_emit_dialogue("adjust_bag", ["bag"])
	var resume := _resume_for_new_interaction()
	_leave_menu_for_interaction(resume)
	interaction_resume = resume
	poke_visual_clip = "guard_bag_annoyed" if manifest.has_clip("guard_bag_annoyed") else "poke_cheek"
	if poke_visual_clip == "guard_bag_annoyed":
		sfx_player.play("bag")
	machine.dispatch({"type": "POKE"})

func _trigger_clock_scare() -> void:
	if _defer_until_wake("clock"):
		return
	_interrupt_action("direct_interaction")
	var resume := _resume_for_new_interaction()
	interaction_resume = resume
	if machine.state != "menu_wait":
		menu_resume = resume
		machine.dispatch({"type": "MENU_OPEN"})
	machine.dispatch({"type": "MENU_SELECT_CLOCK"})

func _trigger_manual_control() -> void:
	if machine.state in ["boot", "dragged", "suspended"]:
		return
	_interrupt_action("direct_interaction")
	var resume := _resume_for_new_interaction()
	_leave_menu_for_interaction(resume)
	interaction_resume = resume
	_enter_manual_control()
	machine.dispatch({"type": "MANUAL_CONTROL_START"})
	_emit_dialogue("control_enter")

func _enter_manual_control() -> void:
	_cancel_edge_patrol()
	_unmount_from_window()
	motion.clear()
	_stop_roam()
	if manual_control_model == null:
		manual_control_model = ManualControlModelScript.new()
	# Entering control must keep the pet exactly where it is: the model adopts the
	# plane it already stands on (or falls from the current height) instead of
	# snapping to the floor on the first tick.
	manual_control_model.set_preserve_entry_position(true)
	manual_control_model.reset(position)
	var durations := _control_oneshot_durations()
	if not durations.is_empty():
		manual_control_model.configure_oneshot_durations(durations)
	_last_control_clip = ""
	_last_control_segment = ""
	_last_control_reverse = false
	_last_control_subphase = ""
	_wall_frozen = false
	_control_fall_started_at = -1.0
	_control_started_at = _now_ms()
	_control_long_emitted = false
	manual_last_flight_enter_ms = -INF
	desktop.set_unfocusable(false)

func _exit_manual_control() -> void:
	if machine.state != "manual_control":
		return
	_emit_dialogue("control_exit")
	desktop.set_unfocusable(true)
	_last_control_clip = ""
	_last_control_segment = ""
	var resume := _resolve_resume(interaction_resume)
	# Exiting control mid-air (the pet fell off a ledge or was knocked loose during
	# the session) must not resume a ground state: that would park the pet hovering
	# at the exit position. Hand it off as a fall from where it actually stands so
	# the exit keeps the same position while the normal physics take over.
	if manual_control_model != null and manual_control_model.standing_plane_handle() == 0:
		if manual_control_model.subphase in ["fall", "flight", "wall", "jump"] and position.y < _floor_y() - 2.0:
			resume = "drag_fall"
	_handoff_manual_platform()
	machine.dispatch({"type": "INTERACTION_END", "resume": resume})

## When manual control ends with the pet standing on a window (the model tracks
## the standing plane), hand the platform over so riding/tracking resume. Off a
## platform the pet just keeps its current position.
func _handoff_manual_platform() -> void:
	if manual_control_model == null:
		return
	var handle: int = manual_control_model.standing_plane_handle()
	if handle == 0:
		return
	var pid: int = manual_control_model.standing_plane_pid()
	var platform := _platform_for_identity(handle, pid)
	if platform == null:
		return
	active_platform = platform
	# Anchor to the platform's top edge without clamping to the work area: the
	# window may sit at or past the screen edge and the pet must stand on it.
	position = _position_for_platform(platform, _pet_foot_global().x)
	_apply_position()
	_save_position()

func _handle_manual_up_tap() -> void:
	if manual_control_model == null:
		return
	if _now_ms() - manual_last_up_tap <= MANUAL_DOUBLE_TAP_MS:
		manual_last_up_tap = -INF
		manual_last_flight_enter_ms = _now_ms()
		manual_control_model.set_flight_mode(true)
		_emit_control_quip("control_fly")
	else:
		manual_last_up_tap = _now_ms()
		manual_control_model.queue_jump()
		_emit_control_quip("control_jump")

func _handle_manual_down_tap() -> void:
	if manual_control_model == null:
		return
	if _now_ms() - manual_last_down_tap <= MANUAL_DOUBLE_TAP_MS:
		manual_last_down_tap = -INF
		if manual_control_model.flight_mode:
			manual_control_model.set_flight_mode(false)
			if _now_ms() - manual_last_flight_enter_ms <= CONTROL_COMBO_MS:
				_emit_control_quip("control_combo")
			else:
				_emit_control_quip("control_fly_cancel")
		else:
			# Not flying: double-tap down detaches from the standing window platform
			# and falls to the nearest lower surface (a lower window top or the floor).
			manual_control_model.queue_step_off()
			_emit_control_quip("control_step_off")
	else:
		manual_last_down_tap = _now_ms()

func _update_manual_control(delta: float, now: float) -> void:
	if manual_control_model == null:
		return
	var dir_x := 0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		dir_x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		dir_x += 1
	var dir_y := 0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		dir_y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		dir_y += 1
	var world := _build_desktop_world()
	# Manual jump is slightly stronger than the autonomous one so a staircase hop
	# clears a short wall the pet would otherwise scrape; the autonomous climb
	# omits jump_boost (defaults to 1.0) and keeps the base jump height.
	var result: Dictionary = manual_control_model.tick(delta, {"dir_x": dir_x, "dir_y": dir_y, "jump_boost": MANUAL_CONTROL_JUMP_BOOST}, world)
	position = _clamp_position(Vector2(result.get("position", position)), false)
	_apply_control_clip(result, now, dir_y)
	if not _control_long_emitted and _control_started_at >= 0.0 and now - _control_started_at >= CONTROL_LONG_MS:
		_control_long_emitted = true
		_emit_control_quip("control_long")
	if int(result.get("landed_platform_handle", 0)) != 0:
		_emit_dialogue("window_land")
		_observe_ecology("window_land")

## Fills the shared DesktopWorld (the same object the riding/roam loop refreshes)
## with the per-frame live sources and the model's fixed parameters. The collision
## lists (world.platforms / world.walls) were refreshed on the window-refresh
## cadence by _flatten_collision_world / _rebuild_platform_planes. Both the
## keyboard control mode and the autonomous wall climb drive the model with this
## ONE world object.
func _build_desktop_world() -> DesktopWorld:
	desktop_world.floor_y = _floor_y()
	desktop_world.screen = habitat_model.screen_for_pet_position(position, Vector2(pet_window_size))
	desktop_world.pet_size = Vector2(pet_window_size)
	desktop_world.umbrella_available = _has_umbrella_family()
	desktop_world.live_wall = _live_climb_wall()
	desktop_world.live_platforms = _live_standing_segments()
	desktop_world.live_delta_x = _live_standing_rect_delta()
	desktop_world.live_delta_y = _live_standing_rect_delta_y()
	desktop_world.climb_contact = _climb_contact_offsets()
	return desktop_world


## Pet-window-space x of the character's wall-facing (hand) edge for each climb
## clip. The model parks the pet window at `wall_x - contact`, so the hands touch
## the window's wall face while climbing. Without this the collision body (110px,
## narrower than the 360px pet window) would park the sprite floating inside — or
## past — the pane. Both climb clips anchor their hand edge to the same texture
## column, so the attach corner clips align seamlessly at the same contact x.
func _climb_contact_offsets() -> Dictionary:
	var size := Vector2(pet_window_size)
	var result := {}
	for spec in [
		{"side": 1, "clip": "patrol_wall_right_a", "edge": 1.0},
		{"side": -1, "clip": "patrol_wall_left_a", "edge": 0.0},
	]:
		var clip := manifest.clip(str(spec.get("clip", "")))
		var bounds: Dictionary = clip.get("visualBounds", {})
		if clip.is_empty() or bounds.is_empty():
			continue
		var edge_texture_x := float(bounds.get("x", 0.0)) + float(bounds.get("width", 0.0)) * float(spec.get("edge", 1.0))
		var canvas: Dictionary = clip.get("canvas", manifest.canvas())
		var anchor: Dictionary = clip.get("anchor", {"x": 0.5, "y": 0.96})
		var dock := PetRenderBox.dock_point(
			size,
			PetRenderBox.render_dock(clip),
			PetRenderBox.render_dock_inset(clip),
		)
		var window_x := dock.x + (edge_texture_x - float(anchor.get("x", 0.5)) * float(canvas.get("width", 512.0))) * PetRenderBox.character_scale(manifest)
		result[int(spec.get("side", 0))] = window_x
	return result


## Per-frame wall edge for the window the pet is currently climbing, so a dragged
## window carries it smoothly instead of teleporting at the refresh cadence.
## Manual control and the autonomous climb drive separate model instances, so pick
## the active one by state. Returns {} when not climbing or the window is gone/not
## eligible.
func _live_climb_wall() -> Dictionary:
	var model: Variant = _climb_model if machine.state == "wall_climb" else manual_control_model
	if model == null:
		return {}
	var handle: int = model.climbing_wall_handle()
	if handle == 0:
		return {}
	return window_platform_service.live_wall_edge(handle, model.climbing_wall_pid(), model.wall_side)


## Per-frame VISIBLE standable segments for the window the pet is standing on in
## control mode: the window's live rect minus the cached front occluders, so a
## dragged window carries it smoothly AND an occluded standing point drops instead
## of riding the hidden full edge. Returns [] when not standing or the window is
## gone/not eligible/fully covered.
func _live_standing_segments() -> Array:
	var model: Variant = _climb_model if machine.state == "wall_climb" else manual_control_model
	if model == null:
		return []
	var handle: int = model.standing_plane_handle()
	if handle == 0:
		return []
	return window_platform_service.live_top_segment_planes(handle, model.standing_plane_pid(), WINDOW_FOOT_OFFSET_Y)


## Per-frame horizontal displacement of the standing window's live rect center —
## whether the window is being dragged right now. Feeds the model's perch-continuity
## gate so a drag trusts the perch segment while static occlusion re-anchors.
func _live_standing_rect_delta() -> float:
	var model: Variant = _climb_model if machine.state == "wall_climb" else manual_control_model
	if model == null:
		return 0.0
	var handle: int = model.standing_plane_handle()
	if handle == 0:
		return 0.0
	return window_platform_service.live_rect_delta_x(handle)


## Per-frame VERTICAL displacement of the standing window's live rect center. A
## vertical drag moves no X (live_rect_delta_x stays ~0), so this is the signal that
## keeps the model from reading an upward drag as a static window and dropping the
## pet through the occlusion grace.
func _live_standing_rect_delta_y() -> float:
	var model: Variant = _climb_model if machine.state == "wall_climb" else manual_control_model
	if model == null:
		return 0.0
	var handle: int = model.standing_plane_handle()
	if handle == 0:
		return 0.0
	return window_platform_service.live_rect_delta_y(handle)

## Drives the sprite from a model tick result: facing, clip/segment switching,
## wall-loop reverse/freeze bookkeeping, subphase reactions and umbrella phases.
## Shared by keyboard control and the autonomous climb so both stay in sync.
func _apply_control_clip(result: Dictionary, now: float, dir_y: int) -> void:
	var result_facing := int(result.get("facing", facing))
	if result_facing != facing:
		facing = result_facing
		_set_direction(1)
	if _ride_reaction_active and sprite_player.current_clip == _ride_reaction_clip:
		# A window move/resize reaction is playing over the control clip. Yield
		# so it is not stomped; _on_clip_completed restores the control clip.
		# If the reaction clip was interrupted (e.g. a state transition played a
		# different clip), the flag is stale and the control clip must proceed.
		_apply_position()
		return
	var subphase := str(result.get("subphase", ""))
	var clip := str(result.get("clip", "idle"))
	var segment := str(result.get("segment", ""))
	var umbrella_fall := subphase == "fall" and bool(result.get("umbrella", false))
	var leaving_umbrella := _umbrella_control_active and not umbrella_fall
	_umbrella_control_active = umbrella_fall
	var is_wall_loop := clip == "patrol_wall_left_a" or clip == "patrol_wall_right_a"
	if not umbrella_fall:
		_umbrella_control_dirty = false
		if leaving_umbrella:
			# The umbrella branch above never updated the clip identity, so a landing
			# that returns to the same pre-fall clip (e.g. idle -> idle) would be
			# identity-guarded out and the sprite would freeze on the last umbrella
			# frame. Force the clip to re-issue on the way out.
			_last_control_clip = ""
			_last_control_segment = ""
		if clip != _last_control_clip or segment != _last_control_segment:
			_last_control_clip = clip
			_last_control_segment = segment
			_last_control_reverse = is_wall_loop and dir_y > 0
			if _wall_frozen:
				sprite_player.set_manual_frame(-1)
				_wall_frozen = false
			if segment.is_empty():
				sprite_player.play_clip(clip, false, "", _last_control_reverse)
			else:
				sprite_player.play_clip(clip, false, segment, _last_control_reverse)
		elif is_wall_loop and dir_y != 0:
			var want_reverse := dir_y > 0
			if want_reverse != _last_control_reverse:
				_last_control_reverse = want_reverse
				if _wall_frozen:
					sprite_player.set_manual_frame(-1)
					_wall_frozen = false
				sprite_player.set_playback_reverse(want_reverse)
		if is_wall_loop and dir_y == 0:
			if not _wall_frozen:
				sprite_player.set_manual_frame(sprite_player.current_frame)
				_wall_frozen = true
		elif _wall_frozen:
			sprite_player.set_manual_frame(-1)
			_wall_frozen = false
	if subphase != _last_control_subphase:
		_last_control_subphase = subphase
		if subphase == "fall":
			_control_fall_started_at = now
		if subphase == "fall" and bool(result.get("umbrella", false)):
			_emit_control_quip("control_umbrella")
		elif subphase == "landing":
			_emit_control_quip("control_land")
	if umbrella_fall:
		if _wall_frozen:
			sprite_player.set_manual_frame(-1)
			_wall_frozen = false
		var fall_duration := maxf(1.0, float(result.get("fall_duration_ms", 1000.0)))
		var phase := PetUmbrellaFall.phase(maxf(0.0, now - _control_fall_started_at), fall_duration)
		if _umbrella_control_dirty:
			# The phase clip finished; re-issue it so the descent keeps animating
			# (the phase itself is unchanged, which _play_umbrella_phase would skip).
			_umbrella_control_dirty = false
			_play_umbrella_phase(phase, true)
		else:
			_play_umbrella_phase(phase)
	_apply_position()

## Re-issues the control clip the manual model was driving when a window-move
## reaction preempted it. Uses the cached clip/segment/reverse identity, so a
## clip change during the reaction is corrected on the next model tick.
func _restore_control_clip_after_reaction() -> void:
	var clip := _last_control_clip
	var segment := _last_control_segment
	if _wall_frozen:
		sprite_player.set_manual_frame(-1)
		_wall_frozen = false
	if clip.is_empty():
		_play_idle_pose()
	elif segment.is_empty():
		sprite_player.play_clip(clip, false, "", _last_control_reverse)
	else:
		sprite_player.play_clip(clip, false, segment, _last_control_reverse)

func _head_avatar_texture() -> Texture2D:
	if manifest == null:
		return null
	var idle := manifest.clip("idle")
	var frames: Array = idle.get("frames", [])
	if frames.is_empty():
		return null
	var frame_texture := load(manifest.frame_resource_path(str(frames[0]))) as Texture2D
	if frame_texture == null:
		return null
	var head: Array = manifest.data.get("hitZones", {}).get("head", [])
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for point in head:
		if not point is Dictionary:
			continue
		min_x = minf(min_x, float(point.get("x", INF)))
		min_y = minf(min_y, float(point.get("y", INF)))
		max_x = maxf(max_x, float(point.get("x", -INF)))
		max_y = maxf(max_y, float(point.get("y", -INF)))
	if not is_finite(min_x) or max_x <= min_x or max_y <= min_y:
		return null
	var image := frame_texture.get_image()
	if image == null:
		return null
	var cropped := image.get_region(Rect2(min_x, min_y, max_x - min_x, max_y - min_y))
	return ImageTexture.create_from_image(cropped)

func _control_oneshot_durations() -> Dictionary:
	var result := {}
	var takeoff := _clip_segment_duration_ms("takeoff", _facing_segment(1))
	if takeoff > 0.0:
		result["takeoff"] = takeoff
	var land := _clip_segment_duration_ms("land", _facing_segment(1))
	if land > 0.0:
		result["land"] = land
	return result

func _clip_segment_duration_ms(clip_name: String, segment: String) -> float:
	var clip := manifest.clip(clip_name)
	if clip.is_empty():
		return 0.0
	var durations: Array = clip.get("frameDurationsMs", [])
	var segments: Dictionary = clip.get("segments", {})
	if segments.is_empty():
		var total := 0.0
		for value in durations:
			total += float(value)
		return total
	var segment_data: Dictionary = segments.get(segment, {})
	if segment_data.is_empty():
		return 0.0
	var start := int(segment_data.get("start", 0))
	var end := int(segment_data.get("end", durations.size() - 1))
	var total := 0.0
	for index in range(start, end + 1):
		total += float(durations[index])
	return total

func _resume_for_new_interaction() -> String:
	return menu_resume if machine.state == "menu_wait" else _capture_resume_state()

func _leave_menu_for_interaction(resume: String) -> void:
	if machine.state == "menu_wait":
		machine.dispatch({"type": "INTERACTION_END", "resume": _resolve_resume(resume)})

func _capture_resume_state() -> String:
	if machine.state == "menu_wait": return menu_resume
	if machine.state == "manual_control": return "manual_control"
	if machine.state in ["head_pat", "poke_cheek", "clock_scare", "cursor_startle", "cursor_annoyed", "cursor_dizzy"]:
		return interaction_resume
	if machine.state == "edge_patrol" and not edge_session.is_empty():
		_pause_edge_patrol()
		return "edge_patrol"
	if machine.state == "drag_fall":
		_rebase_motion()
		return "drag_fall"
	if not motion.is_empty() or machine.state in ["float", "turn", "takeoff"]:
		if machine.state in ["turn", "takeoff"]: facing = pending_facing
		_rebase_motion()
		return "float"
	if machine.state == "land":
		_prepare_motion(Vector2(position.x, _floor_y()), 180.0, 0.0)
		return "float"
	if cursor_tracking and gaze_engaged and machine.state in ["notice", "cursor_track"]:
		return "cursor_track"
	return "idle"

func _resolve_resume(resume: String) -> String:
	if resume == "edge_patrol" and edge_session.is_empty(): return "idle"
	if resume == "cursor_track" and (not cursor_tracking or not gaze_engaged): return "idle"
	return resume

func _claim_click() -> bool:
	var now := _now_ms()
	if now - last_click_at < float(manifest.behavior_value("clickCooldownMs", 420.0)):
		return false
	last_click_at = now
	return true

func _begin_drag_visual(now: float) -> void:
	drag_visual_phase = "grab"
	drag_motion_intent = "hold"
	drag_travel_direction = 0
	drag_brake_direction = 1
	drag_last_horizontal_speed = 0.0
	drag_last_sample_at = now
	_set_direction(1)

func _reset_drag_visual() -> void:
	drag_visual_phase = ""
	drag_motion_intent = "hold"
	drag_travel_direction = 0
	drag_brake_direction = 1
	drag_last_horizontal_speed = 0.0
	drag_last_sample_at = 0.0

func _play_drag_visual(phase: String) -> void:
	drag_visual_phase = phase
	match phase:
		"grab": sprite_player.play_clip("drag_grab")
		"hold": sprite_player.play_clip("drag_hold")
		"left": sprite_player.play_clip("drag_left")
		"right": sprite_player.play_clip("drag_right")
		"brake":
			_play_segment_or_clip("drag_brake", "left" if drag_brake_direction < 0 else "right")

func _update_drag_visual_from_samples(now: float) -> void:
	if press.is_empty() or str(press.get("intent", "")) != "drag" or machine.state != "dragged":
		return
	var velocity := _drag_velocity_px_per_second(press.get("samples", []))
	var previous_direction := drag_travel_direction
	var previous_speed := drag_last_horizontal_speed
	var next_intent := PetDragMotion.classify(velocity.x, drag_motion_intent)
	var next_direction := PetDragMotion.intent_direction(next_intent)
	var reversal := PetDragMotion.is_reversal(previous_direction, next_intent, velocity.x)
	var sudden_stop := previous_direction != 0 and previous_speed >= PetDragMotion.ENTER_SPEED and next_intent == "hold"
	drag_motion_intent = next_intent
	drag_last_horizontal_speed = absf(velocity.x)
	drag_last_sample_at = now
	if next_direction != 0: drag_travel_direction = next_direction
	if drag_visual_phase in ["grab", "brake"]: return
	if reversal or sudden_stop:
		drag_brake_direction = previous_direction if previous_direction != 0 else drag_brake_direction
		_play_drag_visual("brake")
	elif drag_visual_phase != next_intent:
		_play_drag_visual(next_intent)

func _update_drag_idle(now: float) -> void:
	if machine.state != "dragged" or not PetDragMotion.should_brake(drag_visual_phase, now - drag_last_sample_at):
		return
	drag_motion_intent = "hold"
	drag_last_horizontal_speed = 0.0
	drag_brake_direction = drag_travel_direction if drag_travel_direction != 0 else 1
	_play_drag_visual("brake")

func _drag_velocity_px_per_second(samples: Array) -> Vector2:
	if samples.size() < 2: return Vector2.ZERO
	var first: Dictionary = samples.front()
	var last: Dictionary = samples.back()
	var seconds := maxf(0.016, (float(last.time) - float(first.time)) / 1000.0)
	return (Vector2(last.point) - Vector2(first.point)) / seconds

func _drag_velocity_px_per_ms(samples: Array) -> Vector2:
	return _drag_velocity_px_per_second(samples) / 1000.0

func _start_ground_slide(velocity: Vector2) -> void:
	slide_speed = velocity.x * 1000.0 * SLIDE_VELOCITY_FACTOR
	motion.clear()
	_unmount_from_window()
	machine.dispatch({"type": "SLIDE_START"})

func _start_air_throw(velocity: Vector2) -> void:
	var screen := habitat_model.screen_for_pet_position(position, Vector2(pet_window_size))
	var throw_height := clampf(-velocity.y * 1000.0 * THROW_HEIGHT_FACTOR, THROW_MIN_HEIGHT, THROW_MAX_HEIGHT)
	var apex := Vector2(position.x + velocity.x * THROW_DRIFT_FACTOR, screen.position.y - throw_height)
	var duration := _throw_arc_duration_ms(position.distance_to(apex))
	motion = {
		"from": position,
		"to": apex,
		"started_at": _now_ms(),
		"duration_ms": maxf(1.0, duration),
		"arc_height": 0.0,
	}
	_unmount_from_window()
	throw_session = {
		"descending": false,
		"descent_target": Vector2(apex.x, _floor_y()),
	}
	machine.dispatch({"type": "THROW_START"})

func _update_drag_slide(delta: float) -> void:
	if machine.state != "drag_slide":
		return
	position.x += slide_speed * delta
	position = _clamp_position(position, false)
	_apply_position()
	slide_speed *= maxf(0.0, 1.0 - SLIDE_DECAY_RATE * delta)
	if absf(slide_speed) < SLIDE_STOP_SPEED:
		slide_speed = 0.0
		machine.dispatch({"type": "SLIDE_END"})

func _update_drag_throw(now: float) -> void:
	if machine.state != "drag_throw" or motion.is_empty():
		return
	var elapsed := now - float(motion.get("started_at", now))
	var duration := maxf(1.0, float(motion.get("duration_ms", 1.0)))
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	if not bool(throw_session.get("descending", false)):
		position = Vector2(motion.get("from", position)).lerp(Vector2(motion.get("to", position)), progress)
		_apply_position()
		if progress >= 0.85:
			throw_session.descending = true
			var descent_target: Vector2 = throw_session.get("descent_target", Vector2(position.x, _floor_y()))
			var fall_distance := maxf(0.0, descent_target.y - position.y)
			var descent_duration := PetUmbrellaFall.duration_ms(fall_distance, 1200.0, 2600.0)
			drag_fall_mode = "umbrella"
			umbrella_visual_phase = ""
			_prepare_motion(_clamp_position(descent_target, true), descent_duration, 0.0)
	else:
		var previous_position := position
		position = Vector2(motion.get("from", position)).lerp(Vector2(motion.get("to", position)), PetUmbrellaFall.descent_progress(progress))
		_apply_position()
		var phase := PetUmbrellaFall.phase(elapsed, duration)
		_play_umbrella_phase(phase)
		# The descent can catch a window top: the throw used to fall only to the
		# floor, but the shared landing rule lets it land on a window on the way down.
		var plane := ManualControlModelScript.land_on_platform(previous_position.y, position.y, _pet_foot_global(position).x, desktop_world.platforms)
		var landed_platform := _platform_for_identity(int(plane.get("handle", 0)), int(plane.get("process_id", 0))) if not plane.is_empty() else null
		if landed_platform != null:
			position = _position_for_platform(landed_platform, _pet_foot_global(position).x)
			active_platform = landed_platform
			motion.clear()
			throw_session.clear()
			_apply_position()
			_save_position()
			_emit_dialogue("window_land")
			_observe_ecology("window_land")
			machine.dispatch({"type": "ARRIVE"})
			return
		if progress >= 1.0:
			motion.clear()
			throw_session.clear()
			machine.dispatch({"type": "ARRIVE"})

func _sample_cursor_tracking(now: float) -> void:
	var gaze := manifest.gaze()
	if gaze.is_empty() or not cursor_tracking or suspended or machine.state == "edge_patrol":
		return
	var cursor := Vector2(desktop.get_cursor_position())
	var eye_origin := _gaze_eye_origin_global()
	var distance := cursor.distance_to(eye_origin)
	var was_engaged := gaze_engaged
	if gaze_engaged:
		if distance > float(gaze.get("disengageDistancePx", 540.0)): gaze_engaged = false
	elif distance <= float(gaze.get("engageDistancePx", 420.0)):
		gaze_engaged = true
	if not gaze_engaged:
		smoothed_cursor = null
		gesture_recognizer.reset()
		if was_engaged: gaze_tracker.reset()
		if machine.state in ["notice", "cursor_track"]:
			machine.dispatch({"type": "POINTER_LEAVE"})
		return
	smoothed_cursor = cursor if smoothed_cursor == null else Vector2(smoothed_cursor).lerp(cursor, 0.35)
	var logical_offset := Vector2((Vector2(smoothed_cursor).x - eye_origin.x) * direction, Vector2(smoothed_cursor).y - eye_origin.y)
	var result := gaze_tracker.update(logical_offset)
	if bool(result.changed) and machine.state == "cursor_track":
		var direction_frames: Dictionary = gaze.get("directionFrames", {})
		sprite_player.set_manual_frame(int(direction_frames.get(str(result.direction), 0)))
	if machine.state == "idle":
		machine.dispatch({"type": "NOTICE"})
	if machine.state not in ["idle", "notice", "cursor_track"]:
		gesture_recognizer.reset()
		return
	var observation := gesture_recognizer.update(cursor, now, eye_origin)
	var circle := false
	var sweep := false
	var fast := false
	for gesture in observation.gestures:
		match str(gesture.type):
			"circle": circle = true
			"repeated_sweep": sweep = true
			"fast_move": fast = true
	if circle or sweep or fast:
		needs_model.apply_event("cursor_gesture")
		_emit_dialogue("cursor")
	if circle:
		_observe_ecology("cursor_circle")
		_trigger_cursor_reaction("CURSOR_CIRCLE")
	elif sweep:
		_trigger_cursor_reaction("CURSOR_SWEEP")
	elif fast and distance <= FAST_MOVE_REACTION_DISTANCE:
		_trigger_cursor_reaction("CURSOR_STARTLE")

func _trigger_cursor_reaction(event_type: String) -> void:
	if machine.state not in ["idle", "notice", "cursor_track"]:
		return
	interaction_resume = _capture_resume_state()
	machine.dispatch({"type": event_type})

func _gaze_eye_origin_global() -> Vector2:
	var gaze := manifest.gaze()
	var source: Dictionary = gaze.get("eyeOrigin", {"x": 256.0, "y": 95.0})
	var local := sprite_player.texture_point_to_window(Vector2(float(source.x), float(source.y)))
	return position + local

func _play_gaze_clip() -> void:
	var gaze := manifest.gaze()
	if gaze.is_empty():
		_play_segment_or_clip("cursor_track", "right")
		return
	var clip_name := str(gaze.get("animation", "gaze"))
	sprite_player.play_clip(clip_name)
	var direction_frames: Dictionary = gaze.get("directionFrames", {})
	sprite_player.set_manual_frame(int(direction_frames.get(gaze_tracker.direction, 0)))

func _reset_cursor_tracking() -> void:
	gaze_engaged = false
	smoothed_cursor = null
	gaze_tracker.reset()
	gesture_recognizer.reset()
	if machine.state in ["notice", "cursor_track"]:
		machine.dispatch({"type": "POINTER_LEAVE"})

func _play_idle_entry_or_pose() -> void:
	if idle_pose_facing != 0 and randf() < 0.6:
		idle_pose_facing = 0
	if idle_pose_facing != 0:
		var entry := "idle_%s_enter" % _facing_segment(idle_pose_facing)
		if manifest.has_clip(entry):
			_set_direction(1)
			sprite_player.play_clip(entry)
			return
	_play_idle_pose()

func _play_idle_pose() -> void:
	_set_direction(1)
	var name := "idle"
	if idle_pose_facing != 0:
		var candidate := "idle_%s" % _facing_segment(idle_pose_facing)
		if manifest.has_clip(candidate): name = candidate
	sprite_player.play_clip(name)
	_schedule_idle_blink()
	if idle_pose_facing != 0 and pending_front_intent.is_empty():
		idle_side_pose_deadline = _now_ms() + randf_range(5000.0, 10000.0)
	else:
		idle_side_pose_deadline = -1.0

func _revert_side_pose() -> void:
	if idle_pose_facing == 0 or machine.state != "idle" or not pending_front_intent.is_empty():
		return
	var seg := _facing_segment(idle_pose_facing)
	var handoff := "idle_%s_enter" % seg
	if not manifest.has_clip(handoff):
		idle_pose_facing = 0
		_play_idle_pose()
		return
	side_pose_reverting = true
	sprite_player.play_clip(handoff, true, "", true)

func _schedule_idle_blink() -> void:
	if machine.state != "idle": return
	blink_deadline = _now_ms() + randf_range(IDLE_BLINK_MIN_MS, IDLE_BLINK_MAX_MS)

func _trigger_idle_blink() -> void:
	if machine.state != "idle" or not pending_front_intent.is_empty(): return
	var name := "idle_blink"
	if idle_pose_facing != 0:
		var candidate := "idle_%s_blink" % _facing_segment(idle_pose_facing)
		if manifest.has_clip(candidate): name = candidate
	if manifest.has_clip(name): sprite_player.play_clip(name)
	else: _schedule_idle_blink()

func _schedule_wander() -> void:
	if not auto_wander or machine.state != "idle": return
	wander_deadline = _now_ms() + randf_range(IDLE_WANDER_MIN_MS, IDLE_WANDER_MAX_MS)

func _trigger_ambient_behavior() -> void:
	if machine.state != "idle" or not pending_front_intent.is_empty(): return
	if routine_session.is_active():
		call_deferred("_run_current_routine_step")
		return
	if goal_director != null and goal_director.is_valid() and ecology_progression != null:
		var goal: Dictionary = goal_director.select_goal(needs_model, _ecology_context(), ecology_clock.elapsed_ms())
		if _start_ecology_goal(goal):
			return
	if behavior_director != null and behavior_director.is_valid():
		var intent := behavior_director.select_intent(needs_model, _behavior_context(), int(_now_ms()))
		if _start_autonomous_intent(intent):
			return
	var chance := clampf(float(manifest.behavior_value("edgePatrolChance", 0.4)), 0.0, 1.0)
	if randf() < chance:
		_trigger_edge_patrol()
	else:
		_trigger_wander()

func _trigger_wander() -> void:
	if machine.state != "idle" or not pending_front_intent.is_empty(): return
	if not platforms.is_empty() and (active_platform != null or needs_model.get_need("curiosity") >= 45.0) and randf() < 0.42:
		var target_platform: WindowPlatform = null
		if active_platform != null:
			var nearby = WindowPlatformService.choose_nearby_platform(active_platform, platforms)
			if nearby is WindowPlatform: target_platform = nearby
		else:
			var foot := _pet_foot_global()
			var best_distance := INF
			for candidate in platforms:
				var distance := foot.distance_to(candidate.center())
				if distance < best_distance:
					best_distance = distance
					target_platform = candidate
		if target_platform != null and _travel_to_platform(target_platform):
			return
	_start_random_roam()

func _start_random_roam() -> void:
	if machine.state != "idle" or not pending_front_intent.is_empty():
		return
	_unmount_from_window()
	motion.clear()
	roam_active = true
	roam_session = {
		"legs": RoamPlannerScript.build_legs(
			position,
			Vector2(pet_window_size),
			habitat_model.screen_rects(),
			"%d:%f" % [Time.get_unix_time_from_system(), randf()],
		),
		"index": -1,
		"walk_motion": {},
		"drop_fired": false,
	}
	_dispatch_roam_leg(0)

func _dispatch_roam_leg(index: int) -> void:
	if not roam_active:
		return
	if machine.state != "idle":
		_stop_roam()
		return
	var legs: Array = roam_session.get("legs", [])
	if index < 0 or index >= legs.size():
		_stop_roam()
		_schedule_wander()
		return
	roam_session.index = index
	roam_session.drop_fired = false
	roam_session.walk_motion = {}
	var leg: Dictionary = legs[index]
	var leg_type := str(leg.get("type", "fly"))
	_unmount_from_window()
	motion.clear()
	match leg_type:
		"walk":
			var walk_to: Vector2 = leg.get("to", position)
			roam_session.walk_motion = {
				"from": position,
				"to": walk_to,
				"started_at": _now_ms(),
				"duration_ms": maxf(1.0, float(leg.get("duration_ms", 1000.0))),
			}
			_prepare_travel_facing(walk_to.x)
			facing = pending_facing
			machine.dispatch({"type": "ROAM_WALK_START"})
		"fly", "fly_drop":
			var fly_target: Vector2 = leg.get("fly_target", leg.get("to", position))
			_prepare_motion(fly_target, float(leg.get("duration_ms", 1000.0)), float(leg.get("arc_height", 0.0)), false)
			var needs_turn := _prepare_travel_facing(fly_target.x)
			machine.dispatch({"type": "WANDER", "needs_turn": needs_turn})

func _update_roam(now: float) -> void:
	if not roam_active or roam_session.is_empty():
		return
	var legs: Array = roam_session.get("legs", [])
	var index: int = roam_session.get("index", -1)
	if index < 0 or index >= legs.size():
		return
	var leg: Dictionary = legs[index]
	if machine.state == "roam_walk":
		var walk_motion: Dictionary = roam_session.get("walk_motion", {})
		if not walk_motion.is_empty():
			var duration := maxf(1.0, float(walk_motion.get("duration_ms", 1.0)))
			var progress := clampf((now - float(walk_motion.get("started_at", now))) / duration, 0.0, 1.0)
			var from := Vector2(walk_motion.get("from", position))
			var to := Vector2(walk_motion.get("to", position))
			var previous_position := position
			position = _clamp_position(from.lerp(to, progress), false)
			_apply_position()
			if not desktop_world.walls.is_empty() and progress < 1.0:
				var wall := _blocked_walk_wall(previous_position, position)
				if not wall.is_empty():
					var side := int(wall.get("side", 0))
					var wall_x := float(wall.get("x", 0.0))
					var body_edge := wall_x - (WINDOW_FOOT_OFFSET_X + side * PetWallResolverScript.BODY_HALF_WIDTH)
					position = _clamp_position(Vector2(body_edge, position.y), false)
					_apply_position()
					_handle_roam_wall(wall)
					return
			if progress >= 1.0:
				roam_session.walk_motion = {}
				machine.dispatch({"type": "CLIP_END"})
	elif machine.state == "float" and not roam_session.get("drop_fired", false) and leg.get("drop_at_progress", null) != null:
		var drop_at := float(leg.get("drop_at_progress", 0.0))
		if float(motion.get("arc_height", 0.0)) > 0.0:
			var duration := maxf(1.0, float(motion.get("duration_ms", 1.0)))
			var progress := clampf((now - float(motion.get("started_at", now))) / duration, 0.0, 1.0)
			if progress >= drop_at:
				roam_session.drop_fired = true
				var drop_to: Vector2 = leg.get("to", position)
				var drop_duration := maxf(300.0, position.distance_to(drop_to) / 900.0 * 1000.0)
				_prepare_motion(_clamp_position(drop_to, true), drop_duration, 0.0)

func _advance_or_schedule_wander() -> void:
	var redirect: Dictionary = roam_session.get("redirect", {})
	if not redirect.is_empty():
		roam_session.redirect = {}
		_stop_roam()
		var kind := str(redirect.get("kind", ""))
		if kind == "hop" and machine.state == "idle":
			var platform: Variant = redirect.get("platform", null)
			if platform is WindowPlatform:
				_travel_to_platform(platform)
				return
		if kind == "climb":
			_start_autonomous_climb(redirect.get("wall", {}))
			return
		if kind == "fly":
			_fly_over_wall(redirect.get("wall", {}))
			return
	if roam_active and not roam_session.is_empty():
		var legs: Array = roam_session.get("legs", [])
		var next_index: int = int(roam_session.get("index", -1)) + 1
		if next_index < legs.size():
			roam_session.index = next_index
			call_deferred("_dispatch_roam_leg", next_index)
			return
	_stop_roam()
	_schedule_wander()

func _stop_roam() -> void:
	roam_active = false
	roam_session = {}
	# Any stop also drops an in-flight ecology walk (interrupt, manual control entry,
	# or the roam terminal branch); the walk is only ever finished via its own
	# CLIP_END reaching idle.
	ecology_walk_motion = {}

func _has_wall_climb_assets() -> bool:
	return (
		manifest.has_clip("patrol_floor_to_wall_left_a")
		and manifest.has_clip("patrol_floor_to_wall_right_a")
		and manifest.has_clip("patrol_wall_left_a")
		and manifest.has_clip("patrol_wall_right_a")
		and manifest.has_clip("window_land_recover")
	)

## A roam walk leg ran into a wall: hop onto a short window, climb a reachable
## tall one, or phase over one too high to mount. The redirect is consumed when
## the roam_walk clip ends and the pet reaches idle.
func _handle_roam_wall(wall: Dictionary) -> void:
	var wall_handle := int(wall.get("handle", 0))
	var wall_top_y := float(wall.get("top_y", 0.0))
	if bool(wall.get("short", false)):
		var platform := _platform_for_identity(wall_handle, int(wall.get("process_id", 0)))
		if platform != null:
			roam_session.redirect = {"kind": "hop", "platform": platform}
			machine.dispatch({"type": "CLIP_END"})
			return
	if wall_top_y - WINDOW_FOOT_OFFSET_Y >= work_area.position.y and _has_wall_climb_assets():
		roam_session.redirect = {"kind": "climb", "wall": wall}
		machine.dispatch({"type": "CLIP_END"})
		return
	roam_session.redirect = {"kind": "fly", "wall": wall}
	machine.dispatch({"type": "CLIP_END"})

## Fallback when a wall is too tall to mount: arc over to the far side. The
## descent still resolves platforms, so a low top may be landed on instead.
func _fly_over_wall(wall: Dictionary) -> void:
	var side := int(wall.get("side", 0))
	var wall_x := float(wall.get("x", 0.0))
	var land_x := wall_x + side * 160.0
	var floor_target := _clamp_position(Vector2(land_x, _floor_y()), true)
	_prepare_motion(floor_target, _travel_duration_ms(position.distance_to(floor_target)), 90.0, false)
	var needs_turn := _prepare_travel_facing(floor_target.x)
	machine.dispatch({"type": "WANDER", "needs_turn": needs_turn})

## Drives the shared control model through a wall climb. Phase is event-driven:
## the model walks toward the wall (approach), attaches, climbs (climb), and
## mounts at the top; clip completions advance the session in _on_clip_completed.
func _start_autonomous_climb(wall: Dictionary) -> void:
	if wall.is_empty():
		_finish_autonomous_climb()
		return
	if _climb_model == null:
		_climb_model = ManualControlModelScript.new()
	_climb_model.reset(position)
	var durations := _control_oneshot_durations()
	if not durations.is_empty():
		_climb_model.configure_oneshot_durations(durations)
	var side := int(wall.get("side", 0))
	_last_control_clip = ""
	_last_control_segment = ""
	_last_control_reverse = false
	_last_control_subphase = ""
	_wall_frozen = false
	wall_climb_session = {
		"wall": wall,
		"platform": _platform_for_identity(int(wall.get("handle", 0)), int(wall.get("process_id", 0))),
		"dir_x": side,
		"dir_y": 0,
		"started_at": _now_ms(),
	}
	machine.dispatch({"type": "WALL_CLIMB_START"})

func _update_autonomous_climb(delta: float, now: float) -> void:
	if _climb_model == null or wall_climb_session.is_empty():
		_abort_autonomous_climb()
		return
	var wall_handle := int((wall_climb_session.get("wall", {}) as Dictionary).get("handle", 0))
	if wall_handle != 0 and not _wall_handle_present(wall_handle):
		_abort_autonomous_climb()
		return
	# While the mount clip plays, stop driving the model: _start_mount put it back
	# on GROUND, so a live tick would walk the pet sideways along the wall top.
	# The mount clip is bounded and completes via _on_clip_completed, so the
	# timeout below only bounds the approach+climb, never the mount itself.
	if _climb_model.has_pending_mount():
		return
	if now - float(wall_climb_session.get("started_at", now)) > 8000.0:
		_abort_autonomous_climb()
		return
	var dir_x := int(wall_climb_session.get("dir_x", 1))
	var dir_y := int(wall_climb_session.get("dir_y", 0))
	var result: Dictionary = _climb_model.tick(delta, {"dir_x": dir_x, "dir_y": dir_y}, _build_desktop_world())
	position = _clamp_position(Vector2(result.get("position", position)), false)
	_apply_control_clip(result, now, dir_y)
	if str(result.get("subphase", "")) == "fall":
		_abort_autonomous_climb()

func _handle_wall_climb_clip_completed(clip_name: String) -> void:
	if _climb_model == null or wall_climb_session.is_empty():
		_abort_autonomous_climb()
		return
	if _climb_model.has_pending_attach() and clip_name == _climb_model.attach_clip():
		_climb_model.finish_attach()
		wall_climb_session.phase = "climb"
		wall_climb_session.dir_y = -1
		return
	if _climb_model.has_pending_mount() and clip_name == _climb_model.mount_clip():
		_finish_autonomous_climb()
		return
	# Walk/wall loops and stray clips do not advance the session; the next tick
	# keeps walking/climbing from the model's current state.

func _finish_autonomous_climb() -> void:
	if _climb_model == null:
		return
	_climb_model.finish_mount()
	var session := wall_climb_session
	wall_climb_session = {}
	var platform: Variant = session.get("platform", null)
	if platform is WindowPlatform:
		active_platform = platform
		# Anchor to the platform's top edge without clamping to the work area so
		# the pet can stand on a window at/past the screen edge.
		position = _position_for_platform(platform, _pet_foot_global().x)
		_apply_position()
		_save_position()
		_emit_dialogue("window_land")
		_observe_ecology("window_land")
	else:
		position = _clamp_position(position, false)
		_apply_position()
	machine.dispatch({"type": "CLIP_END"})

func _abort_autonomous_climb() -> void:
	wall_climb_session = {}
	position = _clamp_position(Vector2(position.x, _floor_y()), true)
	_apply_position()
	if machine.state == "wall_climb":
		machine.dispatch({"type": "CLIP_END"})

func _recenter() -> void:
	if machine.state == "menu_wait":
		menu_resume = "idle"
		machine.dispatch({"type": "INTERACTION_END", "resume": "idle"})
	var target := _clamp_position(Vector2(work_area.position.x + work_area.size.x / 2.0 - pet_window_size.x / 2.0, _floor_y()), true)
	_prepare_motion(target, float(manifest.behavior_value("floatDurationMs", 1050.0)), 72.0)
	var needs_turn := _prepare_travel_facing(target.x)
	if machine.state == "idle":
		machine.dispatch({"type": "WANDER", "needs_turn": needs_turn})
	elif machine.state == "float":
		facing = pending_facing

func _prepare_motion(target: Vector2, duration_ms: float, arc_height: float, clamp_to_floor := true) -> void:
	motion = {
		"from": position,
		"to": _clamp_position(target, true) if clamp_to_floor else target,
		"started_at": _now_ms(),
		"duration_ms": maxf(1.0, duration_ms),
		"arc_height": arc_height,
	}

func _rebase_motion() -> void:
	if motion.is_empty(): return
	var total := Vector2(motion.from).distance_to(Vector2(motion.to))
	var remaining := position.distance_to(Vector2(motion.to))
	var ratio := minf(1.0, remaining / total) if total > 0.0 else 0.0
	motion.from = position
	motion.started_at = _now_ms()
	motion.duration_ms = maxf(220.0, float(motion.duration_ms) * ratio)
	motion.arc_height = float(motion.arc_height) * maxf(0.25, ratio)

func _update_motion(now: float) -> void:
	if machine.state not in ["float", "drag_fall"] or motion.is_empty():
		return
	var elapsed := now - float(motion.started_at)
	var duration := float(motion.duration_ms)
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	if machine.state == "float": _update_airborne_phase(progress)
	var umbrella := machine.state == "drag_fall" and drag_fall_mode == "umbrella" and _has_umbrella_family()
	if umbrella: _play_umbrella_phase(PetUmbrellaFall.phase(elapsed, duration))
	var movement_progress := PetUmbrellaFall.descent_progress(progress) if umbrella else progress
	var sway := sin(progress * TAU) * 4.0 if umbrella else 0.0
	var source := Vector2(motion.from)
	var target := Vector2(motion.to)
	var previous_position := position
	var next := source.lerp(target, movement_progress)
	next.x += sway
	next.y -= 4.0 * float(motion.arc_height) * progress * (1.0 - progress)
	if pending_platform == null and (machine.state == "drag_fall" or progress >= 0.62):
		var plane := ManualControlModelScript.land_on_platform(previous_position.y, next.y, _pet_foot_global(next).x, desktop_world.platforms)
		var landed_platform := _platform_for_identity(int(plane.get("handle", 0)), int(plane.get("process_id", 0))) if not plane.is_empty() else null
		if landed_platform != null:
			position = _position_for_platform(landed_platform, _pet_foot_global(next).x)
			active_platform = landed_platform
			motion.clear()
			_apply_position()
			_save_position()
			machine.dispatch({"type": "ARRIVE"})
			needs_model.apply_event("novel_window")
			_emit_dialogue("window_land")
			_observe_ecology("window_land")
			return
	position = next if pending_platform != null else _clamp_position(next, false)
	_apply_position()
	if progress >= 1.0:
		motion.clear()
		if pending_platform != null:
			active_platform = pending_platform
			pending_platform = null
			position = _position_for_platform(active_platform, _pet_foot_global(position).x)
			_apply_position()
			_emit_dialogue("window_land")
			_observe_ecology("window_land")
		else:
			active_platform = null
		_save_position()
		machine.dispatch({"type": "ARRIVE"})

func _update_airborne_phase(progress: float) -> void:
	if float(motion.get("arc_height", 0.0)) == 0.0:
		_play_airborne_phase("fall")
	elif progress < 0.38:
		_play_airborne_phase("rise")
	elif progress < 0.60:
		_play_airborne_phase("apex")
	else:
		_play_airborne_phase("fall")

func _play_airborne_phase(phase: String) -> void:
	if phase == airborne_phase: return
	var previous := airborne_phase
	airborne_phase = phase
	var segment := "%s-%s" % [_facing_segment(facing), phase]
	var clip := manifest.clip("float")
	var segments: Dictionary = clip.get("segments", {})
	if segments.has(segment):
		_set_direction(1)
		sprite_player.play_clip("float", true, segment)
	elif previous.is_empty():
		sprite_player.play_clip("float")

func _play_drag_fall() -> void:
	var segment := _facing_segment(facing)
	var clip := manifest.clip("drag_fall")
	if (clip.get("segments", {}) as Dictionary).has(segment):
		_set_direction(1)
		sprite_player.play_clip("drag_fall", true, segment)
	else:
		airborne_phase = ""
		_play_airborne_phase("fall")

func _has_umbrella_family() -> bool:
	return manifest.has_clip("umbrella_open") and manifest.has_clip("umbrella_float") and manifest.has_clip("umbrella_close")

func _play_umbrella_phase(phase: String, force := false) -> void:
	var first_time := phase != umbrella_visual_phase
	if not force and not first_time: return
	umbrella_visual_phase = phase
	# SFX only on the real phase change; a forced re-issue of the same phase clip
	# (re-issuing a finished clip so the fall keeps animating) must not re-pop.
	if first_time:
		if phase == "open": sfx_player.play("umbrella_open")
		elif phase == "close": sfx_player.play("umbrella_close")
	_set_direction(1)
	_play_segment_or_clip("umbrella_%s" % phase, _facing_segment(facing))

func _play_segment_or_clip(clip_name: String, segment: String) -> void:
	var segments: Dictionary = manifest.clip(clip_name).get("segments", {})
	if segments.has(segment): sprite_player.play_clip(clip_name, true, segment)
	else: sprite_player.play_clip(clip_name)

func _prepare_travel_facing(target_x: float) -> bool:
	var delta := target_x - position.x
	var desired := facing
	if absf(delta) > TRAVEL_FACING_DEAD_ZONE:
		desired = -1 if delta < 0.0 else 1
	var needs_turn := desired != facing
	pending_facing = desired
	_set_direction(1)
	return needs_turn

func _set_direction(value: int) -> void:
	direction = -1 if value < 0 else 1
	sprite_player.set_direction(direction)

func _facing_segment(value: int) -> String:
	return "left" if value < 0 else "right"

func _set_window_geometry(next_size: Vector2i, previous_clip: Dictionary, next_clip: Dictionary) -> void:
	var previous_size := pet_window_size
	var previous_position := position
	var previous_dock := PetRenderBox.dock_point(Vector2(previous_size), PetRenderBox.render_dock(previous_clip), PetRenderBox.render_dock_inset(previous_clip))
	var next_dock := PetRenderBox.dock_point(Vector2(next_size), PetRenderBox.render_dock(next_clip), PetRenderBox.render_dock_inset(next_clip))
	if previous_size == next_size and previous_dock.is_equal_approx(next_dock):
		return
	pet_window_size = next_size
	position = previous_position + previous_dock - next_dock
	var shift := position - previous_position
	if not motion.is_empty():
		motion.from = Vector2(motion.from) + shift
		motion.to = Vector2(motion.to) + shift
	if not press.is_empty():
		press.offset = Vector2(press.offset) - shift
	desktop.set_geometry(position, pet_window_size)
	sprite_player.refresh_layout()

func _default_position() -> Vector2:
	if habitat_model != null:
		return habitat_model.default_position(Vector2(pet_window_size))
	return Vector2(work_area.end.x - pet_window_size.x - 34.0, work_area.end.y - pet_window_size.y)

func _floor_y() -> float:
	if habitat_model != null:
		return habitat_model.floor_y_for_position(position, Vector2(pet_window_size))
	return work_area.end.y - pet_window_size.y

func _clamp_position(value: Vector2, force_floor: bool) -> Vector2:
	if active_platform != null:
		# Standing on a window: the window's top edge is the anchor, so the pet
		# may legitimately sit outside the work area (the window was dragged to
		# or past the screen edge). Clamping here would pull the pet off the
		# ledge and drop it onto the floor, so riding never clamps.
		return value
	if (machine.state == "manual_control" or machine.state == "wall_climb") and _is_standing_on_model_plane():
		# Manual/wall-climb standing on a window: same rule as riding. The model
		# anchors to the plane's absolute top edge, which may sit past the screen
		# edge; clamping would drag the pet off the ledge.
		return value
	if habitat_model != null:
		return habitat_model.clamp_pet_position(value, Vector2(pet_window_size), force_floor)
	var maximum := work_area.end - Vector2(pet_window_size)
	return Vector2(
		clampf(value.x, work_area.position.x, maximum.x),
		maximum.y if force_floor else clampf(value.y, work_area.position.y, maximum.y)
	)

func _apply_position() -> void:
	if desktop.is_minimized():
		return
	desktop.set_position(position)

func _save_position() -> void:
	if desktop != null:
		var stored_position := Vector2(position.x, _floor_y()) if active_platform != null else position
		desktop.save_position(stored_position, base_window_size, pet_window_size)

func _check_system_context() -> void:
	_refresh_habitat_screens()
	var latest := Rect2(desktop.get_work_area())
	if latest.size.x > 0.0 and latest.size.y > 0.0 and (latest.position != work_area.position or latest.size != work_area.size):
		work_area = latest
		if not edge_session.is_empty():
			_cancel_edge_patrol()
			position = _clamp_position(Vector2(position.x, _floor_y()), true)
			if machine.state == "edge_patrol": machine.dispatch({"type": "EDGE_PATROL_END"})
		elif active_platform == null and pending_platform == null:
			var force_floor := active_platform == null and machine.state not in ["float", "drag_fall", "dragged", "manual_control"]
			position = _clamp_position(position, force_floor)
		_apply_position()
	var foreground := window_platform_service.foreground_snapshot()
	var context := desktop.get_system_context([foreground] if not foreground.is_empty() else [])
	var fullscreen := bool(context.get("foreground_fullscreen", false))
	if fullscreen and not suspended:
		suspended = true
		speech_bubble.hide_message(true)
		if machine.state == "manual_control":
			_exit_manual_control()
		_interrupt_action("fullscreen")
		motion.clear()
		_cancel_edge_patrol()
		machine.dispatch({"type": "FULLSCREEN_ENTER"})
		desktop.set_visible(false)
	elif not fullscreen and suspended:
		suspended = false
		if not hidden:
			desktop.set_visible(true)
		machine.dispatch({"type": "FULLSCREEN_EXIT"})

func _refresh_habitat_screens() -> void:
	if habitat_model == null or desktop == null:
		return
	var screens := desktop.get_usable_screen_rects()
	if screens.is_empty():
		screens.append(Rect2(desktop.get_work_area()))
	if habitat_model.screen_rects() != screens:
		habitat_model.update_screens(screens)

func _next_cursor_sample() -> void:
	next_cursor_sample = _now_ms() + maxf(16.0, float(manifest.gaze().get("sampleIntervalMs", 33.0)) if manifest != null else 33.0)

func _next_system_check() -> void:
	next_system_check = _now_ms() + 400.0

func _now_ms() -> float:
	return float(Time.get_ticks_msec())

func _resolve_edge_patrol_box_size() -> Vector2i:
	var side := maxi(base_window_size.x, base_window_size.y)
	var route_names := {}
	for clip_map in [
		EdgePatrolPlanner.clips_for_variant("a"),
		EdgePatrolPlanner.clips_for_variant("b"),
	]:
		for name in clip_map.values():
			route_names[str(name)] = true
	for name in route_names.keys():
		if not manifest.has_clip(str(name)):
			continue
		var size := PetRenderBox.resolve_size(manifest, manifest.clip(str(name)))
		side = maxi(side, maxi(size.x, size.y))
	return Vector2i(side, side)

func _trigger_edge_patrol() -> void:
	if machine.state != "idle" or edge_preparing:
		return
	_unmount_from_window()
	var route_box := _resolve_edge_patrol_box_size()
	var variant := "b" if randf() < clampf(float(manifest.behavior_value("wallClimbVariantBChance", 0.5)), 0.0, 1.0) else "a"
	var clips := EdgePatrolPlanner.clips_for_variant(variant)
	var available := manifest.animation_names()
	var plan := EdgePatrolPlanner.plan({
		"work_area": work_area,
		"box_side": float(route_box.x),
		"start": position,
		"available_clips": available,
		"clips": clips,
		"seed": "%d:%f" % [Time.get_unix_time_from_system(), randf()],
	})
	var poses: Array = plan.get("poses", [])
	if str(plan.get("mode", "none")) == "none" or poses.is_empty():
		_trigger_wander()
		return
	var names: Array[String] = []
	for pose in poses:
		if pose.has("clip_name") and str(pose.clip_name) not in names:
			names.append(str(pose.clip_name))
	edge_preparing = true
	edge_preparation_token += 1
	var token := edge_preparation_token
	wander_deadline = -1.0
	_prepare_edge_patrol(plan, variant, route_box, names, token)

func _prepare_edge_patrol(plan: Dictionary, variant: String, route_box: Vector2i, names: Array[String], token: int) -> void:
	await sprite_player.prepare_clips(names)
	if token != edge_preparation_token:
		return
	edge_preparing = false
	if machine.state != "idle":
		return
	render_box_lock = route_box
	_set_window_geometry(route_box, manifest.clip(sprite_player.current_clip), manifest.clip(sprite_player.current_clip))
	_reset_cursor_tracking()
	motion.clear()
	edge_session = {
		"plan": plan,
		"variant": variant,
		"pose_index": -1,
		"pose": {},
		"from": position,
		"to": position,
		"started_at": 0.0,
		"duration_ms": 0.0,
		"traverse_elapsed_ms": 0.0,
		"paused": false,
	}
	if machine.dispatch({"type": "EDGE_PATROL_START"}) != "edge_patrol":
		edge_session.clear()
		render_box_lock = null

func _advance_edge_patrol() -> void:
	if edge_session.is_empty():
		if machine.state == "edge_patrol": machine.dispatch({"type": "EDGE_PATROL_END"})
		return
	var plan: Dictionary = edge_session.plan
	var poses: Array = plan.get("poses", [])
	var next_index := int(edge_session.pose_index) + 1
	if next_index >= poses.size():
		edge_session.clear()
		render_box_lock = null
		_save_position()
		if machine.state == "edge_patrol": machine.dispatch({"type": "EDGE_PATROL_END"})
		return
	var pose: Dictionary = poses[next_index]
	edge_session.pose_index = next_index
	edge_session.pose = pose
	edge_session.paused = false
	var kind := str(pose.kind)
	if kind == "traverse":
		edge_session.from = Vector2(pose.from)
		edge_session.to = Vector2(pose.to)
		edge_session.traverse_elapsed_ms = 0.0
		var distance := Vector2(pose.from).distance_to(Vector2(pose.to))
		if str(pose.direction) == "left": facing = -1
		elif str(pose.direction) == "right": facing = 1
		if str(pose.edge) == "bottom": idle_pose_facing = facing
		if distance < MIN_EDGE_TRAVERSE_DISTANCE:
			position = _clamp_position(Vector2(pose.to), false)
			_apply_position()
			_advance_edge_patrol()
			return
		edge_session.duration_ms = _edge_traverse_duration(pose, distance)
		edge_session.started_at = _now_ms()
		_set_direction(1)
		sprite_player.play_clip(str(pose.clip_name), true, "", bool(pose.reverse))
		sprite_player.set_playback_elapsed(0.0)
		position = _clamp_position(Vector2(pose.from), false)
		_apply_position()
		return
	if kind == "warp":
		$PetSprite.visible = false
		position = _clamp_position(Vector2(pose.to), false)
		_apply_position()
		_advance_edge_patrol()
		$PetSprite.visible = true
		return
	var anchor := Vector2(pose.position)
	edge_session.from = anchor
	edge_session.to = anchor
	edge_session.duration_ms = 0.0
	edge_session.started_at = _now_ms()
	_set_direction(1)
	sprite_player.play_clip(str(pose.clip_name), true, "", bool(pose.get("reverse", false)))
	position = _clamp_position(anchor, false)
	_apply_position()

func _edge_traverse_duration(pose: Dictionary, distance: float) -> float:
	var clip := manifest.clip(str(pose.clip_name))
	var cycle_duration := _clip_cycle_duration(clip)
	var root_motion: Dictionary = clip.get("rootMotion", {})
	var progress: Array = root_motion.get("frameProgress", [])
	var frames: Array = clip.get("frames", [])
	if not root_motion.is_empty() and float(root_motion.get("cycleAdvancePx", 0.0)) > 0.0 and progress.size() == frames.size() + 1 and cycle_duration > 0.0:
		var cycles := ceili((maxf(0.0, distance) - 0.001) / float(root_motion.cycleAdvancePx))
		var minimum_cycles := ceili(240.0 / cycle_duration)
		return maxf(1.0, maxf(float(cycles), float(minimum_cycles))) * cycle_duration
	var speed := _edge_patrol_speed(pose)
	var requested := distance / maxf(1.0, speed) * 1000.0
	if cycle_duration <= 0.0: return maxf(240.0, requested)
	return maxf(1.0, ceilf((maxf(240.0, requested) - 0.001) / cycle_duration)) * cycle_duration

func _edge_patrol_speed(pose: Dictionary) -> float:
	match str(pose.edge):
		"bottom": return float(manifest.behavior_value("groundWalkSpeedPxPerSecond", 82.0))
		"top": return float(manifest.behavior_value("flightMoveSpeedPxPerSecond", manifest.behavior_value("ceilingMoveSpeedPxPerSecond", 72.0)))
		_: return float(manifest.behavior_value("wallClimbSpeedPxPerSecond", 68.0))

func _clip_cycle_duration(clip: Dictionary) -> float:
	var total := 0.0
	for value in clip.get("frameDurationsMs", []):
		total += float(value) if float(value) > 0.0 else 100.0
	return total

func _update_edge_patrol(now: float) -> void:
	if machine.state != "edge_patrol" or edge_session.is_empty() or bool(edge_session.get("paused", false)):
		return
	var pose: Dictionary = edge_session.get("pose", {})
	if str(pose.get("kind", "")) != "traverse": return
	var elapsed := minf(float(edge_session.duration_ms), maxf(0.0, float(edge_session.traverse_elapsed_ms) + now - float(edge_session.started_at)))
	var progress := _traverse_movement_progress(pose, elapsed, float(edge_session.duration_ms))
	sprite_player.set_playback_elapsed(elapsed)
	var previous_position := position
	position = _clamp_position(Vector2(edge_session.from).lerp(Vector2(edge_session.to), progress), false)
	_apply_position()
	# A window sitting on the bottom edge blocks the traverse: park flush against
	# it and end the patrol instead of clipping through the solid body.
	if str(pose.get("edge", "")) == "bottom" and not desktop_world.walls.is_empty() and progress < 1.0:
		var wall := _blocked_walk_wall(previous_position, position)
		if not wall.is_empty():
			var side := int(wall.get("side", 0))
			var wall_x := float(wall.get("x", 0.0))
			var body_edge := wall_x - (WINDOW_FOOT_OFFSET_X + side * PetWallResolverScript.BODY_HALF_WIDTH)
			position = _clamp_position(Vector2(body_edge, position.y), false)
			_apply_position()
			_cancel_edge_patrol()
			machine.dispatch({"type": "EDGE_PATROL_END"})
			return
	if progress >= 1.0: _advance_edge_patrol()

func _traverse_movement_progress(pose: Dictionary, elapsed_ms: float, duration_ms: float) -> float:
	if duration_ms <= 0.0: return 1.0
	var linear := clampf(elapsed_ms / duration_ms, 0.0, 1.0)
	var clip := manifest.clip(str(pose.clip_name))
	var root_motion: Dictionary = clip.get("rootMotion", {})
	var frame_progress: Array = root_motion.get("frameProgress", [])
	var frames: Array = clip.get("frames", [])
	var cycle_duration := _clip_cycle_duration(clip)
	if root_motion.is_empty() or frame_progress.size() != frames.size() + 1 or cycle_duration <= 0.0:
		return linear
	if linear >= 1.0: return 1.0
	var cycle_count := maxi(1, roundi(duration_ms / cycle_duration))
	var completed := mini(cycle_count - 1, floori(maxf(0.0, elapsed_ms) / cycle_duration))
	var cycle_elapsed := maxf(0.0, elapsed_ms) - completed * cycle_duration
	var cycle_progress := _root_motion_cycle_progress(clip, cycle_elapsed, bool(pose.reverse))
	return clampf((completed + cycle_progress) / float(cycle_count), 0.0, 1.0)

func _root_motion_cycle_progress(clip: Dictionary, elapsed_ms: float, reverse: bool) -> float:
	var frames: Array = clip.get("frames", [])
	var durations: Array = clip.get("frameDurationsMs", [])
	var progress: Array = (clip.get("rootMotion", {}) as Dictionary).get("frameProgress", [])
	var remaining := maxf(0.0, elapsed_ms)
	for index in range(frames.size()):
		var frame_index := frames.size() - 1 - index if reverse else index
		var duration := float(durations[frame_index]) if frame_index < durations.size() else 100.0
		if remaining < duration:
			var local := remaining / maxf(1.0, duration)
			var source := float(progress[frame_index])
			var target := float(progress[frame_index + 1])
			return 1.0 - lerpf(source, target, 1.0 - local) if reverse else lerpf(source, target, local)
		remaining -= duration
	return 1.0

func _pause_edge_patrol() -> void:
	if edge_session.is_empty() or bool(edge_session.get("paused", false)): return
	var pose: Dictionary = edge_session.get("pose", {})
	if str(pose.get("kind", "")) == "traverse":
		var now := _now_ms()
		var elapsed := minf(float(edge_session.duration_ms), maxf(0.0, float(edge_session.traverse_elapsed_ms) + now - float(edge_session.started_at)))
		var progress := _traverse_movement_progress(pose, elapsed, float(edge_session.duration_ms))
		position = _clamp_position(Vector2(edge_session.from).lerp(Vector2(edge_session.to), progress), false)
		edge_session.traverse_elapsed_ms = elapsed
		edge_session.started_at = now
		_apply_position()
	edge_session.paused = true

func _resume_edge_patrol() -> void:
	if edge_session.is_empty(): return
	var pose: Dictionary = edge_session.get("pose", {})
	if pose.is_empty():
		_advance_edge_patrol()
		return
	edge_session.paused = false
	edge_session.started_at = _now_ms()
	var kind := str(pose.kind)
	if kind == "traverse" and position.distance_to(Vector2(pose.to)) < MIN_EDGE_TRAVERSE_DISTANCE:
		position = _clamp_position(Vector2(pose.to), false)
		_apply_position()
		_advance_edge_patrol()
		return
	_set_direction(1)
	sprite_player.play_clip(str(pose.get("clip_name", "idle")), true, "", bool(pose.get("reverse", false)))
	if kind == "traverse": sprite_player.set_playback_elapsed(float(edge_session.traverse_elapsed_ms))

func _cancel_edge_patrol() -> void:
	edge_preparation_token += 1
	edge_preparing = false
	edge_session.clear()
	render_box_lock = null
