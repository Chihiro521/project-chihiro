extends Node

const SKIN_MANIFEST := "res://skins/little-chihiro/pet.json"
const IDLE_BLINK_MIN_MS := 2400.0
const IDLE_BLINK_MAX_MS := 5200.0
const AUTO_HEAD_PAT_MS := 900.0
const FAST_MOVE_REACTION_DISTANCE := 220.0
const TRAVEL_FACING_DEAD_ZONE := 18.0
const MIN_EDGE_TRAVERSE_DISTANCE := 12.0

const MENU_HEAD_PAT := 1
const MENU_POKE := 2
const MENU_CLOCK := 3
const MENU_RECENTER := 4
const MENU_HIDE := 5
const MENU_AUTO_WANDER := 6
const MENU_CURSOR_TRACKING := 7
const MENU_QUIT := 8
const TRAY_SHOW := 101
const TRAY_RECENTER := 104
const TRAY_AUTO_WANDER := 106
const TRAY_CURSOR_TRACKING := 107
const TRAY_QUIT := 108

@onready var sprite_player: PetSpritePlayer = $SpritePlayer
@onready var desktop: DesktopWindowBridge = $DesktopWindow
@onready var menu: PopupMenu = $Menu
@onready var tray_menu: PopupMenu = $TrayMenu

var manifest: PetManifestData
var machine := PetStateMachine.new()
var gaze_tracker := PetGazeTracker.new()
var gesture_recognizer := PetMouseGestureRecognizer.new()

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

var direction := 1
var facing := 1
var pending_facing := 1
var idle_pose_facing := 0
var airborne_phase := ""
var drag_fall_mode := "direct"
var umbrella_visual_phase := ""
var interaction_resume := "idle"
var menu_resume := "idle"

var drag_visual_phase := ""
var drag_motion_intent := "hold"
var drag_travel_direction := 0
var drag_brake_direction := 1
var drag_last_horizontal_speed := 0.0
var drag_last_sample_at := 0.0

var auto_wander := true
var cursor_tracking := true
var gaze_engaged := false
var smoothed_cursor: Variant = null
var suspended := false
var started := false

var wander_deadline := -1.0
var blink_deadline := -1.0
var head_pat_deadline := -1.0
var next_cursor_sample := 0.0
var next_system_check := 0.0
var last_click_at := -INF

func _ready() -> void:
	desktop.configure()
	manifest = PetManifestData.load_from_file(SKIN_MANIFEST)
	if not manifest.is_valid():
		for error in manifest.errors:
			push_error(error)
		get_tree().quit(1)
		return
	machine.transitioned.connect(_on_transition)
	sprite_player.clip_completed.connect(_on_clip_completed)
	sprite_player.clip_changed.connect(_on_clip_changed)
	sprite_player.passthrough_polygon_changed.connect(_on_passthrough_polygon_changed)
	_setup_menus()
	base_window_size = PetRenderBox.resolve_size(manifest)
	pet_window_size = base_window_size
	desktop.set_size(pet_window_size)
	work_area = Rect2(desktop.get_work_area())
	var restored = desktop.load_position()
	position = restored if restored is Vector2 else _default_position()
	position = _clamp_position(position, false)
	_apply_position()
	sprite_player.set_manifest(manifest)
	started = true
	_next_system_check()
	_next_cursor_sample()

func _process(_delta: float) -> void:
	if not started:
		return
	var now := _now_ms()
	_update_motion(now)
	_update_edge_patrol(now)
	_update_drag_idle(now)
	_update_long_press(now)
	if wander_deadline >= 0.0 and now >= wander_deadline:
		wander_deadline = -1.0
		_trigger_ambient_behavior()
	if blink_deadline >= 0.0 and now >= blink_deadline:
		blink_deadline = -1.0
		_trigger_idle_blink()
	if head_pat_deadline >= 0.0 and now >= head_pat_deadline:
		head_pat_deadline = -1.0
		_end_head_pat()
	if now >= next_cursor_sample:
		_next_cursor_sample()
		_sample_cursor_tracking(now)
	if now >= next_system_check:
		_next_system_check()
		_check_system_context()

func _input(event: InputEvent) -> void:
	if not started:
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
			_begin_press(button.position)
		else:
			_finish_press(false)
	elif event is InputEventMouseMotion and not press.is_empty():
		_update_press_drag()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_position()
		get_tree().quit()

func _setup_menus() -> void:
	menu.add_item("摸摸头", MENU_HEAD_PAT)
	menu.add_item("戳脸", MENU_POKE)
	menu.add_item("看时间", MENU_CLOCK)
	menu.add_separator()
	menu.add_item("回到中央", MENU_RECENTER)
	menu.add_item("暂时隐藏", MENU_HIDE)
	menu.add_separator()
	menu.add_check_item("自主闲逛", MENU_AUTO_WANDER)
	menu.add_check_item("光标跟随", MENU_CURSOR_TRACKING)
	menu.add_separator()
	menu.add_item("退出", MENU_QUIT)
	menu.id_pressed.connect(_on_menu_id_pressed)
	menu.popup_hide.connect(_on_context_menu_hidden)
	tray_menu.add_item("显示小千寻", TRAY_SHOW)
	tray_menu.add_item("回到中央", TRAY_RECENTER)
	tray_menu.add_separator()
	tray_menu.add_check_item("自主闲逛", TRAY_AUTO_WANDER)
	tray_menu.add_check_item("光标跟随", TRAY_CURSOR_TRACKING)
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

func _open_context_menu(local_position: Vector2) -> void:
	if machine.state in ["boot", "dragged", "suspended"]:
		return
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
		MENU_RECENTER, TRAY_RECENTER:
			desktop.set_visible(true)
			_recenter()
		MENU_HIDE:
			desktop.set_visible(false)
		MENU_AUTO_WANDER, TRAY_AUTO_WANDER:
			auto_wander = not auto_wander
			wander_deadline = -1.0
			if auto_wander and machine.state == "idle": _schedule_wander()
			_sync_menu_checks()
		MENU_CURSOR_TRACKING, TRAY_CURSOR_TRACKING:
			cursor_tracking = not cursor_tracking
			if not cursor_tracking: _reset_cursor_tracking()
			_sync_menu_checks()
		MENU_QUIT, TRAY_QUIT:
			_save_position()
			get_tree().quit()
		TRAY_SHOW:
			desktop.set_visible(true)
	if machine.state == "menu_wait" and id not in [MENU_CLOCK]:
		machine.dispatch({"type": "INTERACTION_END", "resume": _resolve_resume(menu_resume)})

func _on_transition(from: String, to: String, _event: Dictionary) -> void:
	wander_deadline = -1.0
	blink_deadline = -1.0
	var keeps_paused_patrol := not edge_session.is_empty() and bool(edge_session.get("paused", false)) and to in ["menu_wait", "head_pat", "poke_cheek", "clock_scare"]
	if not edge_session.is_empty() and to != "edge_patrol" and not keeps_paused_patrol:
		_cancel_edge_patrol()
	if from == "dragged" and to != "dragged":
		_reset_drag_visual()
	if to not in ["idle", "notice", "cursor_track"]:
		gesture_recognizer.reset()
	if to == "suspended":
		return
	if to in ["float", "drag_fall"] and motion.is_empty():
		var target := Vector2(position.x, _floor_y())
		_prepare_motion(target, 420.0 if to == "drag_fall" else 240.0, 0.0)
	if to == "idle":
		_play_idle_entry_or_pose()
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
	elif to == "dragged":
		if _has_reactive_drag_family(): _play_drag_visual("grab")
		else: sprite_player.play_clip("dragged")
	elif to == "head_pat":
		sprite_player.play_clip("head_pat", true, "enter")
	elif to == "cursor_track":
		_play_gaze_clip()
	elif to == "cursor_startle":
		sprite_player.play_clip("react")
	elif to == "cursor_annoyed":
		sprite_player.play_clip("poke_cheek")
	else:
		sprite_player.play_clip(to)
	if to != "float": airborne_phase = ""
	if to != "drag_fall": umbrella_visual_phase = ""
	if to == "idle": _schedule_wander()

func _on_clip_completed(clip_name: String, segment: String) -> void:
	if machine.state == "edge_patrol" and not edge_session.is_empty():
		var pose: Dictionary = edge_session.get("pose", {})
		if pose.get("kind", "") in ["corner", "door"] and clip_name == str(pose.get("clip_name", "")):
			_advance_edge_patrol()
			return
	if machine.state == "idle" and clip_name in ["idle_left_enter", "idle_right_enter", "idle_blink", "idle_left_blink", "idle_right_blink"]:
		_play_idle_pose()
		return
	if machine.state == "dragged" and _has_reactive_drag_family():
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
	if clip_name == "head_pat" and machine.state == "head_pat":
		if segment == "enter":
			sprite_player.play_clip("head_pat", true, "hold")
		elif segment == "exit":
			machine.dispatch({"type": "INTERACTION_END", "resume": _resolve_resume(interaction_resume)})
		return
	if clip_name in ["poke_cheek", "clock_scare"] and machine.state in ["poke_cheek", "clock_scare"]:
		machine.dispatch({"type": "INTERACTION_END", "resume": _resolve_resume(interaction_resume)})
		return
	if (clip_name == "react" and machine.state == "cursor_startle") or (clip_name == "poke_cheek" and machine.state == "cursor_annoyed") or (clip_name == "cursor_dizzy" and machine.state == "cursor_dizzy"):
		machine.dispatch({"type": "INTERACTION_END", "resume": _resolve_resume(interaction_resume)})
		return
	machine.dispatch({"type": "CLIP_END"})

func _on_clip_changed(name: String, previous_name: String) -> void:
	var clip := manifest.clip(name)
	var previous := manifest.clip(previous_name)
	var next_size: Vector2i = render_box_lock if render_box_lock is Vector2i else PetRenderBox.resolve_size(manifest, clip)
	_set_window_geometry(next_size, previous, clip)

func _on_passthrough_polygon_changed(polygon: PackedVector2Array) -> void:
	desktop.set_mouse_passthrough(polygon)

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
		) if use_umbrella else clampf(360.0 + fall_distance * 0.7, 420.0, 720.0)
		drag_fall_mode = "umbrella" if use_umbrella else "direct"
		umbrella_visual_phase = ""
		_prepare_motion(target, fall_duration, 0.0)
		_prepare_travel_facing(target.x)
		facing = pending_facing
		machine.dispatch({"type": "DRAG_END"})
		_save_position()
	elif intent == "long_press":
		_end_head_pat()
	elif not cancelled:
		if zone == "head": _trigger_poke()
		else: _trigger_click()
	press.clear()
	if machine.state == "idle": _schedule_wander()

func _trigger_click() -> void:
	if not _claim_click():
		return
	machine.dispatch({"type": "CLICK"})

func _trigger_poke() -> void:
	if not _claim_click():
		return
	var resume := _resume_for_new_interaction()
	_leave_menu_for_interaction(resume)
	interaction_resume = resume
	machine.dispatch({"type": "POKE"})

func _trigger_head_pat(auto_release: bool) -> void:
	var resume := _resume_for_new_interaction()
	_leave_menu_for_interaction(resume)
	_start_head_pat(resume)
	if auto_release and machine.state == "head_pat":
		head_pat_deadline = _now_ms() + AUTO_HEAD_PAT_MS

func _start_head_pat(resume: String) -> void:
	interaction_resume = resume
	machine.dispatch({"type": "HEAD_PAT_START"})

func _end_head_pat() -> void:
	head_pat_deadline = -1.0
	if machine.state == "head_pat":
		sprite_player.play_clip("head_pat", true, "exit")

func _trigger_clock_scare() -> void:
	var resume := _resume_for_new_interaction()
	interaction_resume = resume
	if machine.state != "menu_wait":
		menu_resume = resume
		machine.dispatch({"type": "MENU_OPEN"})
	machine.dispatch({"type": "MENU_SELECT_CLOCK"})

func _resume_for_new_interaction() -> String:
	return menu_resume if machine.state == "menu_wait" else _capture_resume_state()

func _leave_menu_for_interaction(resume: String) -> void:
	if machine.state == "menu_wait":
		machine.dispatch({"type": "INTERACTION_END", "resume": _resolve_resume(resume)})

func _capture_resume_state() -> String:
	if machine.state == "menu_wait": return menu_resume
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

func _has_reactive_drag_family() -> bool:
	for name in ["drag_grab", "drag_hold", "drag_left", "drag_right", "drag_brake"]:
		if not manifest.has_clip(name): return false
	return true

func _begin_drag_visual(now: float) -> void:
	drag_visual_phase = "grab"
	drag_motion_intent = "hold"
	drag_travel_direction = 0
	drag_brake_direction = 1
	drag_last_horizontal_speed = 0.0
	drag_last_sample_at = now
	if _has_reactive_drag_family(): _set_direction(1)

func _reset_drag_visual() -> void:
	drag_visual_phase = ""
	drag_motion_intent = "hold"
	drag_travel_direction = 0
	drag_brake_direction = 1
	drag_last_horizontal_speed = 0.0
	drag_last_sample_at = 0.0

func _play_drag_visual(phase: String) -> void:
	if not _has_reactive_drag_family():
		sprite_player.play_clip("dragged", false)
		return
	drag_visual_phase = phase
	match phase:
		"grab": sprite_player.play_clip("drag_grab")
		"hold": sprite_player.play_clip("drag_hold")
		"left": sprite_player.play_clip("drag_left")
		"right": sprite_player.play_clip("drag_right")
		"brake":
			_play_segment_or_clip("drag_brake", "left" if drag_brake_direction < 0 else "right")

func _update_drag_visual_from_samples(now: float) -> void:
	if press.is_empty() or str(press.get("intent", "")) != "drag" or machine.state != "dragged" or not _has_reactive_drag_family():
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
	if machine.state != "dragged" or not _has_reactive_drag_family() or not PetDragMotion.should_brake(drag_visual_phase, now - drag_last_sample_at):
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
	if circle:
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

func _schedule_idle_blink() -> void:
	if machine.state != "idle": return
	blink_deadline = _now_ms() + randf_range(IDLE_BLINK_MIN_MS, IDLE_BLINK_MAX_MS)

func _trigger_idle_blink() -> void:
	if machine.state != "idle": return
	var name := "idle_blink"
	if idle_pose_facing != 0:
		var candidate := "idle_%s_blink" % _facing_segment(idle_pose_facing)
		if manifest.has_clip(candidate): name = candidate
	if manifest.has_clip(name): sprite_player.play_clip(name)
	else: _schedule_idle_blink()

func _schedule_wander() -> void:
	if not auto_wander or machine.state != "idle": return
	var minimum := float(manifest.behavior_value("idleWanderMinMs", 6500.0))
	var maximum := float(manifest.behavior_value("idleWanderMaxMs", 12000.0))
	wander_deadline = _now_ms() + randf_range(minimum, maximum)

func _trigger_ambient_behavior() -> void:
	if machine.state != "idle": return
	var chance := clampf(float(manifest.behavior_value("edgePatrolChance", 0.4)), 0.0, 1.0)
	if randf() < chance:
		_trigger_edge_patrol()
	else:
		_trigger_wander()

func _trigger_wander() -> void:
	if machine.state != "idle": return
	var minimum_x := work_area.position.x + 18.0
	var maximum_x := work_area.end.x - pet_window_size.x - 18.0
	var target_x := randf_range(minimum_x, maxf(minimum_x + 1.0, maximum_x))
	if absf(target_x - position.x) < 180.0:
		target_x = maximum_x if position.x < (minimum_x + maximum_x) / 2.0 else minimum_x
	_prepare_motion(Vector2(target_x, _floor_y()), float(manifest.behavior_value("floatDurationMs", 1050.0)), 84.0)
	var needs_turn := _prepare_travel_facing(target_x)
	machine.dispatch({"type": "WANDER", "needs_turn": needs_turn})

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

func _prepare_motion(target: Vector2, duration_ms: float, arc_height: float) -> void:
	motion = {
		"from": position,
		"to": _clamp_position(target, true),
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
	var next := source.lerp(target, movement_progress)
	next.x += sway
	next.y -= 4.0 * float(motion.arc_height) * progress * (1.0 - progress)
	position = _clamp_position(next, false)
	_apply_position()
	if progress >= 1.0:
		motion.clear()
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

func _play_umbrella_phase(phase: String) -> void:
	if phase == umbrella_visual_phase: return
	umbrella_visual_phase = phase
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
	position = _clamp_position(previous_position + previous_dock - next_dock, false)
	var shift := position - previous_position
	if not motion.is_empty():
		motion.from = Vector2(motion.from) + shift
		motion.to = Vector2(motion.to) + shift
	if not press.is_empty():
		press.offset = Vector2(press.offset) - shift
	desktop.set_size(pet_window_size)
	desktop.set_position(position)
	sprite_player.refresh_layout()

func _default_position() -> Vector2:
	return Vector2(work_area.end.x - pet_window_size.x - 34.0, _floor_y())

func _floor_y() -> float:
	return work_area.end.y - pet_window_size.y

func _clamp_position(value: Vector2, force_floor: bool) -> Vector2:
	var minimum_x := work_area.position.x
	var maximum_x := work_area.end.x - pet_window_size.x
	var minimum_y := work_area.position.y
	var maximum_y := _floor_y()
	var x := minimum_x if maximum_x < minimum_x else clampf(value.x, minimum_x, maximum_x)
	var y := minimum_y if maximum_y < minimum_y else (maximum_y if force_floor else clampf(value.y, minimum_y, maximum_y))
	return Vector2(x, y)

func _apply_position() -> void:
	desktop.set_position(position)

func _save_position() -> void:
	if desktop != null:
		desktop.save_position(position, base_window_size, pet_window_size)

func _check_system_context() -> void:
	var latest := Rect2(desktop.get_work_area())
	if latest.size.x > 0.0 and latest.size.y > 0.0 and (latest.position != work_area.position or latest.size != work_area.size):
		work_area = latest
		if not edge_session.is_empty():
			_cancel_edge_patrol()
			position = _clamp_position(Vector2(position.x, _floor_y()), true)
			if machine.state == "edge_patrol": machine.dispatch({"type": "EDGE_PATROL_END"})
		else:
			position = _clamp_position(position, machine.state not in ["float", "drag_fall", "dragged"])
		_apply_position()
	var context := desktop.get_system_context()
	var fullscreen := bool(context.get("foreground_fullscreen", false))
	if fullscreen and not suspended:
		suspended = true
		motion.clear()
		_cancel_edge_patrol()
		machine.dispatch({"type": "FULLSCREEN_ENTER"})
		desktop.set_visible(false)
	elif not fullscreen and suspended:
		desktop.set_visible(true)
		suspended = false
		machine.dispatch({"type": "FULLSCREEN_EXIT"})

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
		EdgePatrolPlanner.DEFAULT_CLIPS,
		EdgePatrolPlanner.clips_for_variant("a"),
		EdgePatrolPlanner.clips_for_variant("b"),
		EdgePatrolPlanner.DOOR_CLIPS,
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
	var route_box := _resolve_edge_patrol_box_size()
	var variant := "b" if randf() < clampf(float(manifest.behavior_value("wallClimbVariantBChance", 0.5)), 0.0, 1.0) else "a"
	var clips := EdgePatrolPlanner.clips_for_variant(variant)
	var available := manifest.animation_names()
	if not _supports_patrol_variant(available, clips):
		clips = EdgePatrolPlanner.DEFAULT_CLIPS.duplicate()
		variant = ""
	var plan := EdgePatrolPlanner.plan({
		"work_area": work_area,
		"box_side": float(route_box.x),
		"start": position,
		"available_clips": available,
		"clips": clips,
		"door_warp_chance": float(manifest.behavior_value("doorWarpChance", 0.0)),
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

func _supports_patrol_variant(available_names: Array[String], clips: Dictionary) -> bool:
	for name in [clips.wall_left, clips.wall_right, clips.floor_to_wall_left, clips.floor_to_wall_right, clips.wall_left_to_floor_right, clips.wall_right_to_floor_left]:
		if str(name) not in available_names:
			return false
	return true

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
	position = _clamp_position(Vector2(edge_session.from).lerp(Vector2(edge_session.to), progress), false)
	_apply_position()
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
