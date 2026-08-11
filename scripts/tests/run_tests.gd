extends SceneTree

const DialogueSchedulerScript := preload("res://scripts/core/pet_dialogue_scheduler.gd")
const EcologyClockScript := preload("res://scripts/core/pet_ecology_clock.gd")
const HabitatModelScript := preload("res://scripts/core/desktop_habitat_model.gd")
const RoutineSessionScript := preload("res://scripts/core/pet_routine_session.gd")
const GoalDirectorScript := preload("res://scripts/core/pet_goal_director.gd")
const EcologyRequestScript := preload("res://scripts/core/pet_ecology_request_controller.gd")
const EcologyProgressionScript := preload("res://scripts/core/pet_ecology_progression.gd")
const ManualControlModelScript := preload("res://scripts/core/manual_control_model.gd")
const RoamPlannerScript := preload("res://scripts/core/pet_roam_planner.gd")
const PetWallResolverScript := preload("res://scripts/core/pet_wall_resolver.gd")
const WindowEventDebouncerScript := preload("res://scripts/core/window_event_debouncer.gd")
const RideFeedbackControllerScript := preload("res://scripts/core/ride_feedback_controller.gd")

var failures: Array[String] = []
var assertions := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_manifest()
	_test_animation_resource_closure()
	_test_state_machine()
	_test_render_box()
	await _test_playback()
	_test_gaze()
	_test_drag_and_umbrella()
	_test_edge_patrol()
	_test_life_model()
	_test_behavior_director()
	_test_action_session()
	_test_state_store_and_dialogue()
	_test_control_dialogue()
	_test_dialogue_scheduler()
	await _test_speech_bubble()
	_test_action_catalog()
	_test_mechanism_dashboard()
	_test_ecology_models()
	_test_manual_control_model()
	_test_roam_planner()
	_test_ground_relocation_mode()
	_test_control_and_roam_state()
	_test_wall_resolver()
	_test_window_platforms()
	_test_pet_z_occlusion_threshold()
	_test_icon_visibility_and_reach()
	_test_window_bodies()
	_test_n_way_occlusion()
	_test_window_event_debounce()
	_test_ride_feedback()
	if failures.is_empty():
		print("PASS: %d assertions" % assertions)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: %d failures / %d assertions" % [failures.size(), assertions])
		quit(1)

func _test_manifest() -> void:
	var manifest := PetManifestData.load_from_file("res://skins/little-chihiro/pet.json")
	_expect(manifest.is_valid(), "manifest should be valid: %s" % ", ".join(manifest.errors))
	_expect(manifest.animation_names().size() == 75, "manifest should contain 75 active animations")
	var breathe := manifest.clip("idle_breathe")
	_expect((breathe.get("frames", []) as Array).size() == 8, "idle breathing should contain eight phases")
	_expect(bool(breathe.get("loop", false)), "idle breathing should loop")
	var breathe_durations: Array = breathe.get("frameDurationsMs", [])
	var breathes_at_four_fps := breathe_durations.size() == 8
	for duration in breathe_durations:
		breathes_at_four_fps = breathes_at_four_fps and is_equal_approx(float(duration), 250.0)
	_expect(breathes_at_four_fps, "idle breathing should play at four FPS")
	var look_around := manifest.clip("look_around")
	_expect((look_around.get("frames", []) as Array).size() == 12, "look-around should contain twelve directed poses")
	_expect(not bool(look_around.get("loop", true)), "look-around should return to idle after one scan")
	var look_durations: Array = look_around.get("frameDurationsMs", [])
	var looks_at_six_fps := look_durations.size() == 12
	for duration in look_durations:
		looks_at_six_fps = looks_at_six_fps and is_equal_approx(float(duration), 167.0)
	_expect(looks_at_six_fps, "look-around should play at approximately six FPS")
	var straighten_bag := manifest.clip("straighten_bag")
	_expect((straighten_bag.get("frames", []) as Array).size() == 10, "straighten-bag should contain ten directly drawn poses")
	_expect(not bool(straighten_bag.get("loop", true)), "straighten-bag should return to idle after one adjustment")
	var bag_durations: Array = straighten_bag.get("frameDurationsMs", [])
	var bag_at_six_fps := bag_durations.size() == 10
	for duration in bag_durations:
		bag_at_six_fps = bag_at_six_fps and is_equal_approx(float(duration), 167.0)
	_expect(bag_at_six_fps, "straighten-bag should play at approximately six FPS")
	var inspect_rabbit := manifest.clip("inspect_rabbit")
	_expect((inspect_rabbit.get("frames", []) as Array).size() == 15, "inspect-rabbit should contain fifteen directly drawn poses")
	_expect(not bool(inspect_rabbit.get("loop", true)), "inspect-rabbit should return to idle after replacing the rabbit")
	var rabbit_durations: Array = inspect_rabbit.get("frameDurationsMs", [])
	var rabbit_at_six_fps := rabbit_durations.size() == 15
	for duration in rabbit_durations:
		rabbit_at_six_fps = rabbit_at_six_fps and is_equal_approx(float(duration), 167.0)
	_expect(rabbit_at_six_fps, "inspect-rabbit should play at approximately six FPS")
	var rabbit_textures_load := true
	for frame in inspect_rabbit.get("frames", []):
		var resource_path := manifest.frame_resource_path(str(frame))
		rabbit_textures_load = rabbit_textures_load and ResourceLoader.exists(resource_path) and load(resource_path) is Texture2D
	_expect(rabbit_textures_load, "inspect-rabbit runtime frames should import as Texture2D resources")
	var tidy_clothes := manifest.clip("tidy_clothes")
	_expect((tidy_clothes.get("frames", []) as Array).size() == 12, "tidy-clothes should contain twelve directly drawn poses")
	_expect(not bool(tidy_clothes.get("loop", true)), "tidy-clothes should return to idle after smoothing the hem")
	var tidy_durations: Array = tidy_clothes.get("frameDurationsMs", [])
	var tidy_at_six_fps := tidy_durations.size() == 12
	for duration in tidy_durations:
		tidy_at_six_fps = tidy_at_six_fps and is_equal_approx(float(duration), 167.0)
	_expect(tidy_at_six_fps, "tidy-clothes should play at approximately six FPS")
	var tidy_textures_load := true
	for frame in tidy_clothes.get("frames", []):
		var resource_path := manifest.frame_resource_path(str(frame))
		tidy_textures_load = tidy_textures_load and ResourceLoader.exists(resource_path) and load(resource_path) is Texture2D
	_expect(tidy_textures_load, "tidy-clothes runtime frames should import as Texture2D resources")
	var stretch := manifest.clip("stretch")
	_expect((stretch.get("frames", []) as Array).size() == 17, "stretch should contain seventeen directly drawn poses")
	_expect(not bool(stretch.get("loop", true)), "stretch should return to idle after lowering both arms")
	var stretch_durations: Array = stretch.get("frameDurationsMs", [])
	var stretch_at_six_fps := stretch_durations.size() == 17
	for duration in stretch_durations:
		stretch_at_six_fps = stretch_at_six_fps and is_equal_approx(float(duration), 167.0)
	_expect(stretch_at_six_fps, "stretch should play at approximately six FPS")
	var stretch_textures_load := true
	for frame in stretch.get("frames", []):
		var resource_path := manifest.frame_resource_path(str(frame))
		stretch_textures_load = stretch_textures_load and ResourceLoader.exists(resource_path) and load(resource_path) is Texture2D
	_expect(stretch_textures_load, "stretch runtime frames should import as Texture2D resources")
	var reason_pose := manifest.clip("reason_pose")
	_expect((reason_pose.get("frames", []) as Array).size() == 15, "reason-pose should contain fifteen directly drawn poses")
	_expect(not bool(reason_pose.get("loop", true)), "reason-pose should return to idle after reaching a conclusion")
	var reason_durations: Array = reason_pose.get("frameDurationsMs", [])
	var reason_at_six_fps := reason_durations.size() == 15
	for duration in reason_durations:
		reason_at_six_fps = reason_at_six_fps and is_equal_approx(float(duration), 167.0)
	_expect(reason_at_six_fps, "reason-pose should play at approximately six FPS")
	var reason_textures_load := true
	for frame in reason_pose.get("frames", []):
		var resource_path := manifest.frame_resource_path(str(frame))
		reason_textures_load = reason_textures_load and ResourceLoader.exists(resource_path) and load(resource_path) is Texture2D
	_expect(reason_textures_load, "reason-pose runtime frames should import as Texture2D resources")
	var return_wave := manifest.clip("return_wave")
	_expect((return_wave.get("frames", []) as Array).size() == 17, "return-wave should contain seventeen directly drawn poses")
	_expect(not bool(return_wave.get("loop", true)), "return-wave should return to idle after two restrained beats")
	var return_durations: Array = return_wave.get("frameDurationsMs", [])
	var return_at_six_fps := return_durations.size() == 17
	for duration in return_durations:
		return_at_six_fps = return_at_six_fps and is_equal_approx(float(duration), 167.0)
	_expect(return_at_six_fps, "return-wave should play at approximately six FPS")
	var return_textures_load := true
	for frame in return_wave.get("frames", []):
		var resource_path := manifest.frame_resource_path(str(frame))
		return_textures_load = return_textures_load and ResourceLoader.exists(resource_path) and load(resource_path) is Texture2D
	_expect(return_textures_load, "return-wave runtime frames should import as Texture2D resources")
	var guard_bag := manifest.clip("guard_bag_annoyed")
	_expect((guard_bag.get("frames", []) as Array).size() == 15, "guard-bag-annoyed should contain fifteen directly drawn poses")
	_expect(not bool(guard_bag.get("loop", true)), "guard-bag-annoyed should return the satchel to neutral")
	var guard_durations: Array = guard_bag.get("frameDurationsMs", [])
	var guard_at_six_fps := guard_durations.size() == 15
	for duration in guard_durations:
		guard_at_six_fps = guard_at_six_fps and is_equal_approx(float(duration), 167.0)
	_expect(guard_at_six_fps, "guard-bag-annoyed should play at approximately six FPS")
	var guard_textures_load := true
	for frame in guard_bag.get("frames", []):
		var resource_path := manifest.frame_resource_path(str(frame))
		guard_textures_load = guard_textures_load and ResourceLoader.exists(resource_path) and load(resource_path) is Texture2D
	_expect(guard_textures_load, "guard-bag-annoyed runtime frames should import as Texture2D resources")
	var sit_specs := [
		{"name": "sit_enter", "frames": 8, "loop": false},
		{"name": "sit_loop", "frames": 10, "loop": true},
		{"name": "sit_exit", "frames": 8, "loop": false},
	]
	var sit_textures_load := true
	for spec in sit_specs:
		var sit_clip := manifest.clip(str(spec["name"]))
		_expect((sit_clip.get("frames", []) as Array).size() == int(spec["frames"]), "%s should contain its approved frame range" % spec["name"])
		_expect(bool(sit_clip.get("loop", false)) == bool(spec["loop"]), "%s should preserve its segment loop policy" % spec["name"])
		var sit_durations: Array = sit_clip.get("frameDurationsMs", [])
		var sit_at_six_fps := sit_durations.size() == int(spec["frames"])
		for duration in sit_durations:
			sit_at_six_fps = sit_at_six_fps and is_equal_approx(float(duration), 167.0)
		_expect(sit_at_six_fps, "%s should play at approximately six FPS" % spec["name"])
		for frame in sit_clip.get("frames", []):
			var resource_path := manifest.frame_resource_path(str(frame))
			sit_textures_load = sit_textures_load and ResourceLoader.exists(resource_path) and load(resource_path) is Texture2D
	_expect(sit_textures_load, "all sit-rest runtime frames should import as Texture2D resources")
	var nap_specs := [
		{"name": "nap_enter", "frames": 8, "loop": false},
		{"name": "nap_loop", "frames": 8, "loop": true},
		{"name": "nap_wake", "frames": 14, "loop": false},
	]
	var nap_textures_load := true
	for spec in nap_specs:
		var nap_clip := manifest.clip(str(spec["name"]))
		_expect((nap_clip.get("frames", []) as Array).size() == int(spec["frames"]), "%s should contain its approved sleep segment" % spec["name"])
		_expect(bool(nap_clip.get("loop", false)) == bool(spec["loop"]), "%s should preserve its sleep loop policy" % spec["name"])
		var nap_durations: Array = nap_clip.get("frameDurationsMs", [])
		var nap_at_six_fps := nap_durations.size() == int(spec["frames"])
		for duration in nap_durations:
			nap_at_six_fps = nap_at_six_fps and is_equal_approx(float(duration), 167.0)
		_expect(nap_at_six_fps, "%s should play at approximately six FPS" % spec["name"])
		for frame in nap_clip.get("frames", []):
			var resource_path := manifest.frame_resource_path(str(frame))
			nap_textures_load = nap_textures_load and ResourceLoader.exists(resource_path) and load(resource_path) is Texture2D
	_expect(nap_textures_load, "all nap runtime frames should import as Texture2D resources")
	var head_pat_accept := manifest.clip("head_pat_accept")
	_expect((head_pat_accept.get("frames", []) as Array).size() == 17, "accepted head pat should contain seventeen direct poses")
	_expect(not bool(head_pat_accept.get("loop", true)), "accepted head pat should complete as a one-shot")
	var accept_durations: Array = head_pat_accept.get("frameDurationsMs", [])
	var accept_at_eight_fps := accept_durations.size() == 17
	var accept_textures_load := true
	for duration in accept_durations:
		accept_at_eight_fps = accept_at_eight_fps and is_equal_approx(float(duration), 125.0)
	for frame in head_pat_accept.get("frames", []):
		var resource_path := manifest.frame_resource_path(str(frame))
		accept_textures_load = accept_textures_load and ResourceLoader.exists(resource_path) and load(resource_path) is Texture2D
	_expect(accept_at_eight_fps, "accepted head pat should play at eight FPS")
	_expect(accept_textures_load, "accepted head-pat runtime frames should import as Texture2D resources")
	var head_pat_refuse := manifest.clip("head_pat_refuse")
	_expect((head_pat_refuse.get("frames", []) as Array).size() == 23, "refused head pat should contain twenty-three direct poses")
	_expect(not bool(head_pat_refuse.get("loop", true)), "refused head pat should complete as a one-shot")
	var refuse_durations: Array = head_pat_refuse.get("frameDurationsMs", [])
	_expect(refuse_durations.size() == 23 and is_equal_approx(float(refuse_durations[13]), 220.0), "refused head pat should preserve its peak blocking hold")
	var refuse_textures_load := true
	for frame in head_pat_refuse.get("frames", []):
		var resource_path := manifest.frame_resource_path(str(frame))
		refuse_textures_load = refuse_textures_load and ResourceLoader.exists(resource_path) and load(resource_path) is Texture2D
	_expect(refuse_textures_load, "refused head-pat runtime frames should import as Texture2D resources")
	var window_land := manifest.clip("window_land_recover")
	_expect((window_land.get("frames", []) as Array).size() == 15, "window landing recovery should contain fifteen direct poses")
	_expect(not bool(window_land.get("loop", true)), "window landing recovery should complete as a one-shot")
	var window_land_durations: Array = window_land.get("frameDurationsMs", [])
	var window_land_at_eight_fps := window_land_durations.size() == 15
	var window_land_textures_load := true
	for duration in window_land_durations:
		window_land_at_eight_fps = window_land_at_eight_fps and is_equal_approx(float(duration), 125.0)
	for frame in window_land.get("frames", []):
		var resource_path := manifest.frame_resource_path(str(frame))
		window_land_textures_load = window_land_textures_load and ResourceLoader.exists(resource_path) and load(resource_path) is Texture2D
	_expect(window_land_at_eight_fps, "window landing recovery should play at eight FPS")
	_expect(window_land_textures_load, "window landing recovery frames should import as Texture2D resources")
	var window_sit_specs := [
		{"name": "window_sit_enter", "frames": 8, "loop": false},
		{"name": "window_sit_loop", "frames": 16, "loop": true},
		{"name": "window_sit_exit", "frames": 8, "loop": false},
	]
	var window_sit_textures_load := true
	for spec in window_sit_specs:
		var window_sit_clip := manifest.clip(str(spec["name"]))
		_expect((window_sit_clip.get("frames", []) as Array).size() == int(spec["frames"]), "%s should contain its approved window-seat segment" % spec["name"])
		_expect(bool(window_sit_clip.get("loop", false)) == bool(spec["loop"]), "%s should preserve its window-seat loop policy" % spec["name"])
		_expect((window_sit_clip.get("supportContactY", []) as Array).size() == int(spec["frames"]), "%s should expose one support contact per frame" % spec["name"])
		for frame in window_sit_clip.get("frames", []):
			var resource_path := manifest.frame_resource_path(str(frame))
			window_sit_textures_load = window_sit_textures_load and ResourceLoader.exists(resource_path) and load(resource_path) is Texture2D
	_expect(window_sit_textures_load, "all window-seat frames should import as Texture2D resources")
	var frame_count := 0
	var missing_count := 0
	for name in manifest.animation_names():
		var clip := manifest.clip(name)
		for frame in clip.get("frames", []):
			frame_count += 1
			if not FileAccess.file_exists(manifest.frame_resource_path(str(frame))):
				missing_count += 1
	_expect(frame_count == 1511, "manifest should expose 1511 runtime frames")
	_expect(missing_count == 0, "all manifest frame paths should exist")

func _test_animation_resource_closure() -> void:
	var manifest := PetManifestData.load_from_file("res://skins/little-chihiro/pet.json")
	var referenced := {}
	var every_texture_loads := true
	for clip_name in manifest.animation_names():
		var clip := manifest.clip(clip_name)
		for frame in clip.get("frames", []):
			var relative := str(frame).replace("\\", "/")
			referenced[relative] = true
			var resource_path := manifest.frame_resource_path(relative)
			var texture: Resource = ResourceLoader.load(resource_path, "Texture2D")
			every_texture_loads = every_texture_loads and texture is Texture2D
			texture = null
		for variant_value in clip.get("cycleVariants", []):
			if not variant_value is Dictionary:
				continue
			for override_path in (variant_value as Dictionary).get("frameOverrides", {}).values():
				var relative := str(override_path).replace("\\", "/")
				referenced[relative] = true
				var resource_path := manifest.frame_resource_path(relative)
				var texture: Resource = ResourceLoader.load(resource_path, "Texture2D")
				every_texture_loads = every_texture_loads and texture is Texture2D
				texture = null
	_expect(every_texture_loads, "every manifest frame should load as a Texture2D")
	_expect(referenced.size() == 1511, "manifest should reference 1511 unique runtime PNGs")
	var animation_root := ProjectSettings.globalize_path("res://skins/little-chihiro/animations").replace("\\", "/")
	var png_files: Array[String] = []
	var import_files: Array[String] = []
	_collect_files_with_suffix(animation_root, ".png", png_files)
	_collect_files_with_suffix(animation_root, ".png.import", import_files)
	var orphan_count := 0
	var sidecar_missing_count := 0
	for absolute_path in png_files:
		var relative := "animations/%s" % absolute_path.trim_prefix("%s/" % animation_root)
		if not referenced.has(relative):
			orphan_count += 1
		if not FileAccess.file_exists("%s.import" % absolute_path):
			sidecar_missing_count += 1
	var stray_sidecar_count := 0
	for sidecar_path in import_files:
		if not FileAccess.file_exists(sidecar_path.trim_suffix(".import")):
			stray_sidecar_count += 1
	_expect(png_files.size() == 1511, "skin should contain exactly 1511 runtime PNGs")
	_expect(import_files.size() == 1511, "every runtime PNG should have one tracked import sidecar")
	_expect(orphan_count == 0, "skin animation directory should contain no unreferenced PNGs")
	_expect(sidecar_missing_count == 0 and stray_sidecar_count == 0, "runtime PNGs and import sidecars should be one-to-one")
	for removed_name in [
		"head_pat", "dragged", "patrol_ceiling_left", "patrol_ceiling_right",
		"patrol_door_enter_left", "patrol_door_enter_right", "patrol_door_exit_left", "patrol_door_exit_right",
	]:
		_expect(not manifest.has_clip(removed_name), "retired clip should stay absent: %s" % removed_name)

func _test_state_machine() -> void:
	var machine := PetStateMachine.new()
	_expect(machine.state == "boot", "state machine starts in boot")
	_expect(machine.dispatch({"type": "CLIP_END"}) == "idle", "boot completes to idle")
	_expect(machine.dispatch({"type": "WANDER", "needs_turn": true}) == "turn", "wander can turn")
	_expect(machine.dispatch({"type": "CLIP_END"}) == "takeoff", "turn completes to takeoff")
	_expect(machine.dispatch({"type": "CLIP_END"}) == "float", "takeoff completes to float")
	_expect(machine.dispatch({"type": "DRAG_START"}) == "dragged", "drag preempts motion")
	_expect(machine.dispatch({"type": "DRAG_END"}) == "drag_fall", "drag release starts fall")
	_expect(machine.dispatch({"type": "ARRIVE"}) == "land", "fall arrives at land")
	_expect(machine.dispatch({"type": "CLIP_END"}) == "idle", "land completes to idle")
	_expect(machine.dispatch({"type": "FULLSCREEN_ENTER"}) == "suspended", "fullscreen suspends")
	_expect(machine.dispatch({"type": "FULLSCREEN_EXIT"}) == "idle", "fullscreen exit resumes idle")
	_expect(machine.dispatch({"type": "ACTION_START", "state": "ambient_action"}) == "ambient_action", "autonomous action enters generic execution state")
	_expect(machine.dispatch({"type": "ACTION_END"}) == "idle", "autonomous action returns to idle")
	_expect(machine.dispatch({"type": "ACTION_START", "state": "cursor_confiscate"}) == "cursor_confiscate", "cursor confiscate enters its bespoke state")
	_expect(machine.dispatch({"type": "ACTION_END"}) == "idle", "cursor confiscate returns to idle")
	_expect(machine.dispatch({"type": "ACTION_START", "state": "cursor_confiscate"}) == "cursor_confiscate", "cursor confiscate re-enters")
	_expect(machine.dispatch({"type": "CLIP_END"}) == "idle", "cursor confiscate clip end returns to idle")
	_expect(machine.dispatch({"type": "ACTION_START", "state": "icon_collect"}) == "icon_collect", "icon collect enters its bespoke state")
	_expect(machine.dispatch({"type": "CLIP_END"}) == "idle", "icon collect clip end returns to idle")
	_expect(machine.dispatch({"type": "ACTION_START", "state": "icon_collect"}) == "icon_collect", "icon collect re-enters")
	_expect(machine.dispatch({"type": "ACTION_END"}) == "idle", "icon collect returns to idle")
	_expect(machine.dispatch({"type": "ACTION_START", "state": "icon_transfer"}) == "icon_transfer", "icon transfer enters its gift/reclaim state")
	_expect(machine.dispatch({"type": "CLIP_END"}) == "idle", "icon transfer clip end returns to idle")
	_expect(machine.dispatch({"type": "ACTION_START", "state": "platform_sit"}) == "platform_sit", "platform action enters platform state")
	_expect(machine.dispatch({"type": "PLATFORM_LOST"}) == "drag_fall", "platform loss preempts into fall")
	_expect(machine.dispatch({"type": "ARRIVE"}) == "land", "platform fall can land")
	_expect(machine.dispatch({"type": "CLIP_END"}) == "idle", "platform landing returns idle")

func _test_render_box() -> void:
	var manifest := PetManifestData.load_from_file("res://skins/little-chihiro/pet.json")
	_expect(PetRenderBox.resolve_size(manifest, manifest.clip("idle")) == Vector2i(360, 360), "idle uses 360px host")
	_expect(PetRenderBox.resolve_size(manifest, manifest.clip("umbrella_float")).x > 360, "umbrella grows host")
	var route_side := 0
	var largest_route_clip := ""
	var route_names := {}
	for clip_map in [EdgePatrolPlanner.clips_for_variant("a"), EdgePatrolPlanner.clips_for_variant("b")]:
		for name in clip_map.values(): route_names[str(name)] = true
	for name in route_names.keys():
		if manifest.has_clip(str(name)):
			var clip_side := PetRenderBox.resolve_size(manifest, manifest.clip(str(name))).x
			if clip_side > route_side:
				route_side = clip_side
				largest_route_clip = str(name)
	_expect(route_side == 436, "complete patrol route locks a 436px host (got %d from %s)" % [route_side, largest_route_clip])
	var sit_enter := manifest.clip("window_sit_enter")
	var sit_loop := manifest.clip("window_sit_loop")
	var sit_exit := manifest.clip("window_sit_exit")
	_expect(is_equal_approx(PetRenderBox.support_texture_point(sit_enter, 0).y, 472.0), "window-seat enter begins on both shoe soles")
	_expect(is_equal_approx(PetRenderBox.support_texture_point(sit_enter, 7).y, 365.0), "window-seat enter transfers support toward the pelvis")
	_expect(is_equal_approx(PetRenderBox.support_texture_point(sit_loop, 8).y, 350.0), "window-seat loop pins its pelvis contact to the window top")
	_expect(is_equal_approx(PetRenderBox.support_texture_point(sit_exit, 7).y, 472.0), "window-seat exit restores shoe support")
	var standing_box := Vector2(360.0, 360.0)
	var standing_scale := PetRenderBox.character_scale(manifest)
	var standing_offset := PetRenderBox.foot_offset_y(manifest.clip("idle_breathe"), 0, standing_box, standing_scale)
	_expect(is_equal_approx(standing_offset, 356.0), "standing clips resolve to the model's standing foot offset 356 (got %s)" % standing_offset)
	_expect(is_equal_approx(PetRenderBox.foot_offset_y(manifest.clip("patrol_floor_right"), 0, standing_box, standing_scale), 356.0), "floor patrol also resolves to the standing foot offset")
	# The riding y-pin follows the LIVE pose offset (PetRenderBox.foot_offset_y) so it
	# agrees with _on_sprite_frame_changed. Standing/walking clips equal the standing
	# constant, but riding poses like the window sit keep their feet higher; a
	# hardcoded 356 pin would fight the per-frame correction and vibrate the pet.
	var sit_loop_offset := PetRenderBox.foot_offset_y(sit_loop, 0, standing_box, standing_scale)
	_expect(absf(sit_loop_offset - 356.0) > 80.0, "window-seat loop keeps its feet well above the standing offset (got %s)" % sit_loop_offset)
	_expect(is_equal_approx(sit_loop_offset, 261.338760375977), "window-seat loop pins a stable 261px sitting foot offset")

func _test_playback() -> void:
	var phase := PetSpritePlayer.resolve_playback_frame([100, 200, 300], 0, 2, false, true, 350.0)
	_expect(int(phase.frame_index) == 2, "elapsed playback resolves third frame")
	_expect(is_equal_approx(float(phase.elapsed_in_frame_ms), 50.0), "elapsed playback keeps local phase")
	phase = PetSpritePlayer.resolve_playback_frame([100, 200, 300], 0, 2, true, false, 50.0)
	_expect(int(phase.frame_index) == 2, "reverse playback starts at range end")
	var host := Node2D.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	var player := PetSpritePlayer.new()
	player.name = "Player"
	player.sprite_path = NodePath("../Sprite")
	host.add_child(sprite)
	host.add_child(player)
	root.add_child(host)
	await process_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var manifest := PetManifestData.load_from_file("res://skins/little-chihiro/pet.json")
	player.set_manifest(manifest)
	var expected_texture := load(manifest.frame_resource_path(str(manifest.clip("stretch").get("frames", [""])[0]))) as Texture2D
	var signal_probe := {"texture_ready": false}
	player.clip_changed.connect(func(name: String, _previous: String) -> void:
		if name == "stretch":
			signal_probe.texture_ready = sprite.texture == expected_texture
	)
	player.play_clip("stretch")
	_expect(bool(signal_probe.texture_ready), "clip switch commits its first texture before geometry listeners run")
	var boundary_probe := {"switched": false}
	player.loop_boundary.connect(func(name: String, _segment: String, _cycle: int) -> void:
		if name == "idle":
			player.play_clip("stretch")
			boundary_probe.switched = true
	)
	player.play_clip("idle")
	player._process(20.0)
	_expect(bool(boundary_probe.switched) and player.current_clip == "stretch" and sprite.texture == expected_texture, "loop seam can switch clips without restoring a stale loop frame")
	var front_texture := load(manifest.frame_resource_path(str(manifest.clip("idle").get("frames", [""])[0]))) as Texture2D
	var side_texture := load(manifest.frame_resource_path(str(manifest.clip("idle_right").get("frames", [""])[0]))) as Texture2D
	var handoff_frames: Array = manifest.clip("idle_right_enter").get("frames", [])
	var handoff_front := load(manifest.frame_resource_path(str(handoff_frames[0]))) as Texture2D
	var handoff_side := load(manifest.frame_resource_path(str(handoff_frames[-1]))) as Texture2D
	_expect(front_texture.get_image().get_data() == handoff_front.get_image().get_data(), "reverse side handoff ends on the exact front-idle pixels")
	_expect(side_texture.get_image().get_data() == handoff_side.get_image().get_data(), "reverse side handoff starts on the exact side-idle pixels")
	# Reversing playback preserves the current frame instead of restarting from an end.
	player.play_clip("patrol_wall_left_a")
	player._process(0.4)
	var wall_frame_before := player.current_frame
	player.set_playback_reverse(true)
	_expect(player.current_frame == wall_frame_before, "reversing playback keeps the current frame")
	player._process(0.12)
	_expect(player.current_frame < wall_frame_before, "reversed playback advances backward from the same spot")
	host.queue_free()
	await process_frame

func _test_gaze() -> void:
	var gaze := PetGazeTracker.new()
	_expect(gaze.resolve(Vector2.ZERO) == "center", "gaze deadzone is centered")
	_expect(gaze.resolve(Vector2(100, 0)) == "right", "gaze resolves right")
	_expect(gaze.resolve(Vector2(0, -100)) == "up", "gaze resolves up")

func _test_drag_and_umbrella() -> void:
	_expect(PetDragMotion.classify(250.0, "hold") == "right", "drag threshold enters right")
	_expect(PetDragMotion.classify(80.0, "right") == "hold", "drag hysteresis exits to hold")
	_expect(PetDragMotion.is_reversal(1, "left", -320.0), "decisive reversal is detected")
	_expect(PetUmbrellaFall.should_use(140.0, true), "high release uses umbrella")
	_expect(not PetUmbrellaFall.should_use(80.0, true), "low release skips umbrella")
	_expect(PetUmbrellaFall.phase(0.0, 1800.0) == "open", "umbrella begins open")
	_expect(PetUmbrellaFall.phase(900.0, 1800.0) == "float", "umbrella middle floats")
	_expect(PetUmbrellaFall.phase(1750.0, 1800.0) == "close", "umbrella ends closed")

func _test_edge_patrol() -> void:
	var manifest := PetManifestData.load_from_file("res://skins/little-chihiro/pet.json")
	var available := manifest.animation_names()
	for variant in ["a", "b"]:
		var clips := EdgePatrolPlanner.clips_for_variant(variant)
		var all_variant_clips_exist := true
		for clip_name in clips.values():
			all_variant_clips_exist = all_variant_clips_exist and manifest.has_clip(str(clip_name))
		_expect(all_variant_clips_exist, "edge patrol variant %s should reference only manifest clips" % variant)
		var plan := EdgePatrolPlanner.plan({
			"work_area": Rect2(0, 0, 1920, 1040),
			"box_side": 436.0,
			"start": Vector2(1200, 604),
			"available_clips": available,
			"clips": clips,
			"seed": "test-route-%s" % variant,
		})
		_expect(str(plan.mode) == "full", "complete variant %s plans a full edge route" % variant)
		_expect((plan.poses as Array).size() == 9, "variant %s full route contains nine poses" % variant)
		var uses_balloon_flight := false
		var uses_wall_transition := false
		var uses_only_active_pose_kinds := true
		var bounds: Dictionary = plan.bounds
		for pose in plan.poses:
			var pose_kind := str(pose.get("kind", ""))
			uses_only_active_pose_kinds = uses_only_active_pose_kinds and pose_kind in ["traverse", "corner"]
			var clip_name := str(pose.get("clip_name", ""))
			uses_balloon_flight = uses_balloon_flight or clip_name in [clips.flight_left, clips.flight_right]
			uses_wall_transition = uses_wall_transition or clip_name in [clips.floor_to_wall_left, clips.floor_to_wall_right, clips.wall_left_to_floor_right, clips.wall_right_to_floor_left]
			_expect(not ("ceiling" in clip_name or "door" in clip_name or "patrol_corner" in clip_name), "route should not revive retired transition clips")
			for key in ["from", "to", "position"]:
				if not pose.has(key): continue
				var point := Vector2(pose[key])
				_expect(point.x >= float(bounds.min_x) - 0.01 and point.x <= float(bounds.max_x) + 0.01, "route x stays inside work area")
				_expect(point.y >= float(bounds.min_y) - 0.01 and point.y <= float(bounds.max_y) + 0.01, "route y stays inside work area")
		_expect(uses_balloon_flight, "variant %s full route should cross the top with balloon flight" % variant)
		_expect(uses_wall_transition, "variant %s full route should use dedicated floor-wall transitions" % variant)
		_expect(uses_only_active_pose_kinds, "variant %s should contain only traverse and corner poses" % variant)
	var fallback_clips := EdgePatrolPlanner.clips_for_variant("a")
	var wall_available := available.duplicate()
	wall_available.erase(str(fallback_clips.flight_left))
	wall_available.erase(str(fallback_clips.flight_right))
	var wall_plan := EdgePatrolPlanner.plan({"available_clips": wall_available, "clips": fallback_clips, "seed": "wall-fallback"})
	_expect(str(wall_plan.mode) == "wall", "missing flight clips should degrade edge patrol to a wall route")
	var ground_plan := EdgePatrolPlanner.plan({
		"available_clips": [str(fallback_clips.ground_left), str(fallback_clips.ground_right)],
		"clips": fallback_clips,
		"seed": "ground-fallback",
	})
	_expect(str(ground_plan.mode) == "ground", "ground clips alone should degrade edge patrol to ground walking")
	var unavailable_plan := EdgePatrolPlanner.plan({"available_clips": [], "clips": fallback_clips, "seed": "none-fallback"})
	_expect(str(unavailable_plan.mode) == "none", "missing patrol clips should fall back to ordinary wandering")

func _test_life_model() -> void:
	var profile := _load_json("res://data/behavior_profile.json")
	var needs := PetNeedsModel.new(profile)
	_expect(is_equal_approx(needs.get_need("energy"), 72.0), "life model starts with configured energy")
	needs.tick(3600.0, {"sleeping": false})
	_expect(is_equal_approx(needs.get_need("energy"), 0.0), "awake energy clamps at zero")
	_expect(needs.get_need("boredom") > 20.0, "awake boredom rises")
	needs.reset_session(40.0)
	needs.apply_event("rapid_poke")
	_expect(needs.get_need("irritation") >= 12.0, "rapid poke raises irritation")
	_expect(needs.get_need("affection") < 40.0, "rapid poke lowers affection")
	needs.set_need("affection", 150.0)
	_expect(is_equal_approx(needs.get_need("affection"), 100.0), "affection clamps at one hundred")
	_expect(needs.relationship_tier() == "close", "relationship tier follows affection")
	needs.set_need("energy", 20.0)
	needs.tick(300.0, {"sleeping": true})
	_expect(needs.get_need("energy") > 20.0, "sleep restores energy")

func _test_behavior_director() -> void:
	var profile := _load_json("res://data/behavior_profile.json")
	var needs := PetNeedsModel.new(profile)
	var director := PetBehaviorDirector.load_from_file("res://data/behavior_profile.json", 4242)
	_expect(director.is_valid(), "behavior profile is valid")
	var context := {
		"autonomy_allowed": true,
		"available_clips": PetManifestData.load_from_file("res://skins/little-chihiro/pet.json").animation_names(),
		"has_platform": false,
		"on_platform": false,
		"relationship_tier": needs.relationship_tier(),
		"time_period": "afternoon",
		"returned_after_seconds": 3600.0,
	}
	var diagnostics := director.diagnostic_candidates(needs, context, 89000)
	_expect(diagnostics.size() == 18, "behavior diagnostics expose all eighteen configured intents")
	var eligible_diagnostic := false
	var event_diagnostic := false
	for diagnostic in diagnostics:
		if diagnostic is Dictionary:
			eligible_diagnostic = eligible_diagnostic or bool(diagnostic.get("eligible", false))
			event_diagnostic = event_diagnostic or str(diagnostic.get("status", "")) == "事件触发"
	_expect(eligible_diagnostic, "behavior diagnostics mark currently selectable candidates")
	_expect(event_diagnostic, "behavior diagnostics distinguish direct event behaviors")
	var breathe_intent := director.create_intent("breathe_shift", needs, context, 90000)
	_expect(str(breathe_intent.get("clip", "")) == "idle_breathe", "breathing behavior uses the approved animation")
	_expect(int((breathe_intent.get("session", {}) as Dictionary).get("max_duration_ms", 0)) == 2000, "breathing session ends on the two-second loop seam")
	var look_intent := director.create_intent("look_around", needs, context, 92000)
	_expect(str(look_intent.get("clip", "")) == "look_around", "look-around behavior uses the approved directed scan")
	var bag_intent := director.create_intent("straighten_bag", needs, context, 94000)
	_expect(str(bag_intent.get("clip", "")) == "straighten_bag", "straighten-bag behavior uses the approved direct animation")
	var rabbit_intent := director.create_intent("inspect_rabbit", needs, context, 96000)
	_expect(str(rabbit_intent.get("clip", "")) == "inspect_rabbit", "inspect-rabbit behavior uses the approved direct animation")
	var tidy_intent := director.create_intent("tidy_clothes", needs, context, 98000)
	_expect(str(tidy_intent.get("clip", "")) == "tidy_clothes", "tidy-clothes behavior uses the approved direct animation")
	var stretch_intent := director.create_intent("stretch", needs, context, 99000)
	_expect(str(stretch_intent.get("clip", "")) == "stretch", "stretch behavior uses the approved direct animation")
	var reason_intent := director.create_intent("reason_pose", needs, context, 99500)
	_expect(str(reason_intent.get("clip", "")) == "reason_pose", "reason-pose behavior uses the approved direct animation")
	var return_intent := director.create_intent("return_wave", needs, context, 99750)
	_expect(str(return_intent.get("clip", "")) == "return_wave", "return-wave behavior uses the approved direct animation")
	var guard_intent := director.create_intent("guard_bag_annoyed", needs, context, 99800)
	_expect(str(guard_intent.get("clip", "")) == "guard_bag_annoyed", "guard-bag behavior uses the approved direct animation")
	var accepted_pat_intent := director.create_intent("head_pat_accept", needs, context, 99850)
	_expect(str(accepted_pat_intent.get("clip", "")) == "head_pat_accept", "accepted head-pat behavior uses the approved direct animation")
	var refused_pat_intent := director.create_intent("head_pat_refuse", needs, context, 99875)
	_expect(str(refused_pat_intent.get("clip", "")) == "head_pat_refuse", "refused head-pat behavior uses the approved direct animation")
	var window_land_intent := director.create_intent("window_land_recover", needs, context, 99890)
	_expect(str(window_land_intent.get("clip", "")) == "window_land_recover", "window landing behavior uses the approved recovery animation")
	var platform_context := context.duplicate(true)
	platform_context["has_platform"] = true
	platform_context["on_platform"] = true
	var window_sit_intent := director.create_intent("window_sit", needs, platform_context, 99900)
	_expect(str(window_sit_intent.get("clip", "")) == "window_sit_enter", "window-seat behavior enters through its approved contact-transfer clip")
	var window_sit_session: Dictionary = window_sit_intent.get("session", {})
	_expect(str(window_sit_session.get("loop", "")) == "window_sit_loop" and str(window_sit_session.get("exit", "")) == "window_sit_exit", "window-seat behavior preserves enter-loop-exit routing")
	needs.set_need("energy", 50.0)
	var sit_intent := director.create_intent("sit_rest", needs, context, 99900)
	_expect(str(sit_intent.get("clip", "")) == "sit_enter", "sit-rest behavior enters through the approved descent clip")
	var sit_session: Dictionary = sit_intent.get("session", {})
	_expect(str(sit_session.get("loop", "")) == "sit_loop" and str(sit_session.get("exit", "")) == "sit_exit", "sit-rest behavior preserves enter-loop-exit routing")
	needs.set_need("energy", 20.0)
	var nap_intent := director.create_intent("nap", needs, context, 99950)
	_expect(str(nap_intent.get("clip", "")) == "nap_enter", "nap behavior enters through the approved sleep descent")
	var nap_session: Dictionary = nap_intent.get("session", {})
	_expect(str(nap_session.get("loop", "")) == "nap_loop" and str(nap_session.get("exit", "")) == "nap_wake", "nap behavior preserves enter-loop-wake routing")
	needs.set_need("energy", 72.0)
	var selected_ids: Array[String] = []
	for index in range(8):
		var intent := director.select_intent(needs, context, 100000 + index * 200000)
		_expect(not intent.is_empty(), "behavior director produces an eligible intent")
		var intent_id := str(intent.get("id", ""))
		if selected_ids.size() >= 3:
			_expect(intent_id not in selected_ids.slice(selected_ids.size() - 3), "behavior director avoids the latest three intents")
		selected_ids.append(intent_id)
		needs.apply_event("behavior_completed", {"effects": intent.get("effects", {})})
	for minute in range(240):
		needs.tick(60.0, {"sleeping": needs.get_need("energy") < 25.0})
		if minute % 5 == 0:
			var intent := director.select_intent(needs, context, 2000000 + minute * 60000)
			if not intent.is_empty(): needs.apply_event("behavior_completed", {"effects": intent.get("effects", {})})
	for key in PetNeedsModel.NEED_NAMES:
		_expect(needs.get_need(key) >= 0.0 and needs.get_need(key) <= 100.0, "four-hour simulation keeps %s in range" % key)

func _test_action_session() -> void:
	var session := PetActionSession.new()
	var timeout_intent := {
		"id": "breathe", "clip": "idle", "priority": "autonomous",
		"session": {"type": "one_shot", "clip": "idle", "max_duration_ms": 100},
	}
	_expect(session.begin(timeout_intent, 1000), "action session begins")
	session.tick(1200)
	_expect(not session.is_active() and str(session.snapshot().outcome) == "timeout", "loop fallback ends at maximum duration")
	var interrupt_intent := {
		"id": "platform", "clip": "idle", "priority": "autonomous",
		"resume_policy": "platform_valid",
		"session": {"type": "one_shot", "clip": "idle", "interrupt_mode": "resume_if_platform_valid"},
	}
	_expect(session.begin(interrupt_intent, 2000), "platform session begins")
	var decision := session.request_interrupt("dragging", {"platform_valid": true}, 2100)
	_expect(bool(decision.accepted), "dragging preempts autonomous action")
	_expect(bool(decision.resume_allowed), "valid platform action records resumability")
	_expect(session.has_resumable_session(), "interrupted platform session remains resumable")
	_expect(session.resume({"platform_valid": true}, 2200), "platform session resumes while its source remains valid")
	session.request_finish(2300)
	var sequence_intent := {
		"id": "rest", "clip": "rest_enter", "priority": "autonomous",
		"session": {"type": "sequence", "enter": "rest_enter", "loop": "rest_loop", "exit": "rest_exit", "max_duration_ms": 100},
	}
	_expect(session.begin(sequence_intent, 3000), "bounded sequence session begins")
	session.on_clip_finished(3010)
	_expect(session.current_phase() == "loop", "sequence advances from enter to loop")
	session.tick(3110)
	_expect(session.current_phase() == "loop" and session.finish_pending(), "bounded loop defers its exit until a visual seam")
	_expect(session.on_loop_boundary(3120) and session.current_phase() == "exit", "loop boundary releases a pending graceful exit")
	session.on_clip_finished(3130)
	_expect(not session.is_active(), "sequence completes after its exit clip")
	var sleep_intent := {
		"id": "nap", "clip": "nap_enter", "priority": "autonomous",
		"session": {"type": "sequence", "enter": "nap_enter", "loop": "nap_loop", "exit": "nap_wake", "interrupt_mode": "wake_then_idle"},
	}
	_expect(session.begin(sleep_intent, 4000), "sleep session begins")
	session.on_clip_finished(4010)
	session.request_interrupt("direct_interaction", {}, 4020)
	_expect(session.is_active() and session.current_clip() == "nap_loop" and session.finish_pending(), "sleep interruption waits for the loop seam instead of cutting an arbitrary frame")
	_expect(session.on_loop_boundary(4030) and session.current_clip() == "nap_wake", "sleep loop seam starts the wake clip")
	session.on_clip_finished(4040)
	_expect(not session.is_active(), "wake exit releases the action session")

func _test_state_store_and_dialogue() -> void:
	var test_path := "user://little_chihiro_state_test.json"
	var absolute := ProjectSettings.globalize_path(test_path)
	if FileAccess.file_exists(test_path): DirAccess.remove_absolute(absolute)
	var store := PetStateStore.new(test_path)
	var state := store.create_default_state()
	_expect(int(state.schema_version) == 2, "state store defaults to the v0.22 schema")
	state.affection = 73.5
	state.interaction_stats.head_pats = 4
	state.habitat_familiarity = 32.5
	state.habits = {"morning_patrol": {"count": 3, "stage": 1, "last_credit_unix": 123}}
	state.discoveries = {"time_morning": {"unlocked_unix": 124}}
	state.home_anchor = {"screen_rect": [0, 0, 1920, 1080], "uv": [0.8, 1.0], "global_position": [1240, 720]}
	state.recent_ecology_events = [{"kind": "discovery", "id": "time_morning", "unix": 124, "window_title": "must not persist"}]
	state["untrusted_title"] = "must not persist"
	_expect(store.save_state(state), "state store writes atomically")
	var loaded := store.load_state()
	_expect(is_equal_approx(float(loaded.affection), 73.5), "state store restores affection")
	_expect(int(loaded.interaction_stats.head_pats) == 4, "state store restores interaction counters")
	_expect(is_equal_approx(float(loaded.habitat_familiarity), 32.5) and int(loaded.habits.morning_patrol.stage) == 1, "state store restores familiarity and habit progress")
	_expect(loaded.discoveries.has("time_morning") and not (loaded.recent_ecology_events[0] as Dictionary).has("window_title"), "state store persists discovery ids without retaining window titles")
	_expect(not (loaded.home_anchor as Dictionary).is_empty(), "state store restores a normalized multi-monitor home anchor")
	_expect(not loaded.has("untrusted_title"), "state store drops fields outside the whitelist")
	var previous_path := absolute + ".previous"
	_expect(DirAccess.rename_absolute(absolute, previous_path) == OK, "test can simulate an interrupted state replacement")
	var recovered := store.load_state()
	_expect(is_equal_approx(float(recovered.affection), 73.5), "state store restores the previous file after an interrupted replacement")
	var dialogue := PetDialogueDirector.new(99)
	_expect(dialogue.load_data("res://data/dialogue_zh_CN.json"), "dialogue data loads")
	_expect(dialogue.line_count() == 271, "dialogue catalog contains 271 lines")
	_expect(dialogue.sanitize_window_title("Password 登录") == "", "sensitive titles are suppressed")
	_expect(dialogue.sanitize_window_title("pass​word") == "", "zero-width characters cannot bypass sensitive-title suppression")
	_expect(dialogue.sanitize_window_title("Ｐａｓｓｗｏｒｄ") == "", "full-width text cannot bypass sensitive-title suppression")
	_expect(dialogue.sanitize_window_title("这是一个非常非常非常非常非常非常长的窗口标题").length() <= 24, "window titles are truncated")
	var line := dialogue.select_line({
		"event": "head_pat_accept", "relationship_tier": "trusted", "irritation": 0,
		"mood": "neutral", "app_name": "godot.exe", "window_title": "", "time_period": "afternoon",
	}, 100000)
	_expect(not line.is_empty(), "dialogue director selects a matching event line")
	var tidy_line := dialogue.select_line({
		"event": "tidy_clothes", "relationship_tier": "familiar", "irritation": 0,
		"mood": "neutral", "app_name": "godot.exe", "window_title": "", "time_period": "afternoon",
	}, 200000)
	_expect(not tidy_line.is_empty(), "tidy-clothes completion selects a matching dialogue line")
	var direct_intent := PetBehaviorDirector.load_from_file("res://data/behavior_profile.json", 7).create_intent(
		"window_land_recover", PetNeedsModel.new(_load_json("res://data/behavior_profile.json")),
		{"available_clips": ["land"], "relationship_tier": "familiar"}, 1000,
	)
	_expect(str(direct_intent.get("id", "")) == "window_land_recover", "non-selectable event behavior can be created directly")
	if FileAccess.file_exists(test_path): DirAccess.remove_absolute(absolute)
	if FileAccess.file_exists(previous_path): DirAccess.remove_absolute(previous_path)

func _test_speech_bubble() -> void:
	var work := Rect2(0.0, 0.0, 1920.0, 1080.0)
	var top_pet := Rect2(900.0, 0.0, 360.0, 360.0)
	var floor_pet := Rect2(900.0, 720.0, 360.0, 360.0)
	_expect(PetSpeechBubble.resolve_placement(top_pet, work) == "below", "a pet near the screen top flips its speech bubble below instead of clipping")
	_expect(PetSpeechBubble.resolve_placement(floor_pet, work) == "above", "a floor pet keeps its speech bubble above")
	var top_position := PetSpeechBubble.resolve_position(top_pet, work, "below")
	var floor_position := PetSpeechBubble.resolve_position(floor_pet, work, "above")
	_expect(top_position.y >= top_pet.end.y and floor_position.y + PetSpeechBubble.WINDOW_SIZE.y <= floor_pet.position.y, "speech positions stay on the selected side of the pet")
	_expect(work.encloses(Rect2(top_position, Vector2(PetSpeechBubble.WINDOW_SIZE))), "speech position is clamped inside the current monitor work area")
	var bubble := PetSpeechBubble.new()
	root.add_child(bubble)
	await process_frame
	_expect(bubble.force_native and bubble.transparent and bubble.mouse_passthrough, "speech uses a transparent native click-through window without changing the pet host geometry")
	bubble.show_message("first", "第一条", 10.0, top_pet, work)
	await process_frame
	await process_frame
	_expect(bubble.placement() == "below", "the live bubble applies the resolved screen-edge placement")
	_expect(bubble.card_layout_size().is_equal_approx(Vector2(372.0, 112.0)), "the native show layout pass cannot stretch the speech card below its viewport")
	_expect(bubble.text_layout_size().x >= 300.0 and bubble.text_layout_size().y >= 60.0 and bubble.text_layout_size().y <= 70.0, "speech body stays inside the visible card after the native window is shown")
	var stable_revision := bubble.layout_revision()
	for _index in range(120):
		bubble.update_anchor(top_pet, work)
	_expect(bubble.layout_revision() == stable_revision, "an unchanged anchor does not repeatedly reposition the native speech window")
	bubble.update_anchor(Rect2(top_pet.position + Vector2(0.1, 0.0), top_pet.size), work)
	_expect(bubble.layout_revision() == stable_revision, "subpixel pet motion does not churn native speech-window geometry")
	bubble.update_anchor(Rect2(top_pet.position + Vector2(3.0, 0.0), top_pet.size), work)
	_expect(bubble.layout_revision() == stable_revision + 1, "visible speech follows meaningful pet movement once")
	bubble.hide_message()
	_expect(bubble.is_showing() and bubble.current_id == "first", "speech host stays reserved throughout fade-out")
	await create_timer(0.04).timeout
	bubble.show_message("second", "第二条", 10.0, floor_pet, work)
	await create_timer(0.18).timeout
	var live_snapshot := bubble.snapshot()
	_expect(bubble.is_showing() and bubble.current_id == "second" and str(live_snapshot.get("text", "")) == "第二条", "a new message cancels a stale fade without leaving an empty panel")
	bubble.hide_message()
	await create_timer(0.18).timeout
	_expect(not bubble.is_showing() and bubble.current_id.is_empty() and str(bubble.snapshot().get("text", "")).is_empty(), "speech panel hides atomically with its text")
	bubble.show_message("third", "重新出现也必须有正文", 10.0, top_pet, work)
	await process_frame
	await process_frame
	_expect(bubble.card_layout_size().is_equal_approx(Vector2(372.0, 112.0)) and bubble.text_layout_size().y <= 70.0, "a cold speech-window reopen restores the compact body layout")
	bubble.hide_message(true)
	bubble.queue_free()
	await process_frame

func _test_control_dialogue() -> void:
	var dialogue := PetDialogueDirector.new(77)
	_expect(dialogue.load_data("res://data/dialogue_zh_CN.json"), "control dialogue data loads")
	var control_events := [
		"control_enter", "control_exit", "control_jump", "control_fly", "control_fly_cancel",
		"control_climb", "control_detach", "control_umbrella", "control_land",
		"control_long", "control_combo", "fling", "fling_slide", "fling_throw",
	]
	var now := 300000.0
	for event in control_events:
		var line := dialogue.select_line({
			"event": event, "relationship_tier": "familiar", "irritation": 0,
			"mood": "neutral", "app_name": "godot.exe", "window_title": "", "time_period": "afternoon",
		}, now)
		_expect(not line.is_empty(), "control event %s selects a line" % event)
		now += 20000.0  # step past the 12s event cooldown between events
	# Relationship-tiered enter lines: distant must not select the close-tier variant.
	dialogue.set_seed(11)
	var distant_line := dialogue.select_line({
		"event": "control_enter", "relationship_tier": "distant", "irritation": 0,
		"mood": "neutral", "app_name": "godot.exe", "window_title": "", "time_period": "afternoon",
	}, now)
	_expect(not distant_line.is_empty(), "distant control_enter selects a line")
	_expect(
		str(distant_line.get("id", "")) in ["control_enter_001", "control_enter_002", "control_enter_003", "control_enter_004"],
		"distant control_enter avoids the close-tier line"
	)

func _test_dialogue_scheduler() -> void:
	var scheduler := DialogueSchedulerScript.new()
	scheduler.reset(1000.0)
	_expect(not scheduler.should_attempt(90999.0), "ambient scheduler honors its initial delay")
	_expect(scheduler.should_attempt(91000.0, {
		"enabled": true,
		"surface_visible": true,
		"bubble_busy": false,
		"machine_state": "cursor_track",
		"action_active": true,
	}), "ambient speech remains eligible during gaze and active animations")
	scheduler.commit_attempt(91000.0, 211000.0)
	_expect(is_equal_approx(scheduler.seconds_until_attempt(121000.0), 90.0), "ambient scheduler follows the dialogue director cooldown")
	_expect(not scheduler.should_attempt(211000.0, {"enabled": true, "surface_visible": true, "bubble_busy": true}), "an existing bubble delays rather than overlaps ambient speech")
	_expect(scheduler.should_attempt(216000.0, {"enabled": true, "surface_visible": true, "bubble_busy": false}), "ambient speech retries after the current bubble closes")

func _test_action_catalog() -> void:
	var manifest := PetManifestData.load_from_file("res://skins/little-chihiro/pet.json")
	var catalog := _load_json("res://data/action_catalog_zh_CN.json")
	var profile := _load_json("res://data/behavior_profile.json")
	_expect(int(catalog.get("schema_version", 0)) == 1, "action catalog schema loads")
	var coverage := PetActionCatalogPanel.catalog_coverage(catalog, manifest.animation_names())
	_expect(int(coverage.get("family_count", 0)) == 19, "action catalog contains sixteen life families and three system groups")
	_expect(int(coverage.get("life_family_count", 0)) == 16, "action catalog preserves the planned sixteen behavior families")
	_expect(int(coverage.get("classified_count", 0)) == 75, "action catalog classifies all runtime clips")
	_expect((coverage.get("missing", []) as Array).is_empty(), "action catalog has no unclassified runtime clips")
	_expect((coverage.get("unknown", []) as Array).is_empty(), "action catalog references no unknown runtime clips")
	_expect((coverage.get("duplicates", []) as Array).is_empty(), "every runtime clip belongs to exactly one visual family")
	var labels: Dictionary = catalog.get("labels", {})
	var every_clip_has_label := true
	for clip_name in manifest.animation_names():
		every_clip_has_label = every_clip_has_label and not str(labels.get(clip_name, "")).is_empty()
	_expect(every_clip_has_label, "every action browser entry has a Chinese display label")
	var profile_clip_references := {}
	for behavior_value in profile.get("director", {}).get("behaviors", []):
		if not behavior_value is Dictionary:
			continue
		var behavior: Dictionary = behavior_value
		for field in ["clip", "fallback_clip"]:
			var clip_name := str(behavior.get(field, ""))
			if not clip_name.is_empty():
				profile_clip_references[clip_name] = true
		var preconditions: Dictionary = behavior.get("preconditions", {})
		for field in ["requires_clips", "requires_any_clips"]:
			for clip_value in preconditions.get(field, []):
				var clip_name := str(clip_value)
				if not clip_name.is_empty():
					profile_clip_references[clip_name] = true
		var session: Dictionary = behavior.get("session", {})
		for field in ["enter", "loop", "exit"]:
			var clip_name := str(session.get(field, ""))
			if not clip_name.is_empty():
				profile_clip_references[clip_name] = true
	var every_behavior_clip_exists := true
	for clip_name in profile_clip_references.keys():
		every_behavior_clip_exists = every_behavior_clip_exists and manifest.has_clip(str(clip_name))
	_expect(profile_clip_references.size() == 28, "behavior profile should expose its complete active clip reference set")
	_expect(every_behavior_clip_exists, "behavior profile should reference only manifest clips")
	var behavior_map := PetActionCatalogPanel.build_behavior_clip_map(profile)
	_expect(behavior_map.has("idle_breathe") and behavior_map.has("window_sit_loop"), "action browser maps one-shots and sequence loops back to behavior intents")
	var window_sit_loop_mapping := false
	for mapping in behavior_map.get("window_sit_loop", []):
		if mapping is Dictionary and str(mapping.get("id", "")) == "window_sit" and str(mapping.get("role", "")) == "loop":
			window_sit_loop_mapping = true
	_expect(window_sit_loop_mapping, "window-seat loop is labeled with its exact director role")
	_expect(is_equal_approx(PetActionCatalogPanel.total_duration_ms(manifest.clip("window_sit_enter")), 1336.0), "action browser reports exact manifest duration")
	_expect(not PetActionCatalogPanel.preview_should_wrap(manifest.clip("window_sit_enter")), "one-shot previews stop at their final frame instead of flashing back to frame zero")
	_expect(PetActionCatalogPanel.preview_should_wrap(manifest.clip("window_sit_loop")), "declared loop previews continue wrapping at their authored seam")
	_expect(PetActionCatalogPanel.preview_should_wrap(manifest.clip("window_sit_enter"), true), "the explicit repeat toggle can replay a one-shot when requested")
	var preview := PetActionPreviewCanvas.new()
	_expect(preview != null, "action preview canvas can be instantiated headlessly")
	preview.free()

func _test_mechanism_dashboard() -> void:
	_expect(PetMechanismDashboard.relationship_label("distant") == "疏远", "mechanism dashboard localizes relationship tiers")
	_expect(PetMechanismDashboard.relationship_label("trusted") == "信任", "mechanism dashboard accepts the profile relationship ids")
	_expect(is_equal_approx(PetMechanismDashboard.next_relationship_threshold(41.0), 60.0), "mechanism dashboard reports the next relationship threshold")
	var merged := PetMechanismDashboard.merge_interaction_stats(
		{"head_pats": 3, "pokes": 4, "rough_drags": 1, "positive": 3, "total": 8},
		{"head_pats": 2, "pokes": 1, "rough_drags": 0, "positive": 2, "total": 3},
	)
	_expect(int(merged.head_pats) == 5 and int(merged.total) == 11, "mechanism dashboard merges persisted and pending interaction counters")
	var previous := {"state": "idle", "environment": {"title": "private A", "stable_title": "private A", "app": "code.exe"}}
	var title_only := {"state": "idle", "environment": {"title": "private B", "stable_title": "private B", "app": "code.exe"}}
	_expect(PetMechanismDashboard.describe_snapshot_changes(previous, title_only).is_empty(), "mechanism timeline never records window title changes")
	var safe_history := PetMechanismDashboard.history_safe_snapshot(title_only)
	var safe_environment: Dictionary = safe_history.get("environment", {})
	_expect(not safe_environment.has("title") and not safe_environment.has("stable_title"), "mechanism history snapshot redacts ephemeral titles")
	var state_change := title_only.duplicate(true)
	state_change.state = "ambient_action"
	_expect(PetMechanismDashboard.describe_snapshot_changes(title_only, state_change).size() == 1, "mechanism timeline reports state-machine changes")
	var dashboard := PetMechanismDashboard.new()
	_expect(dashboard != null, "mechanism dashboard can be instantiated headlessly")
	dashboard.free()


func _test_ecology_models() -> void:
	var clock := EcologyClockScript.new()
	_expect(clock.set_rate(60.0), "ecology clock accepts the supported sixty-times rate")
	_expect(is_equal_approx(clock.advance(2.0), 120.0) and clock.elapsed_ms() == 120000, "ecology clock accelerates simulation time without changing real time")
	_expect(not clock.set_rate(3.0) and is_equal_approx(clock.rate(), 60.0), "ecology clock rejects unsupported rates")

	var habitat := HabitatModelScript.new()
	habitat.update_screens([
		Rect2(-1280.0, 0.0, 1280.0, 1024.0),
		Rect2(0.0, 0.0, 1920.0, 1080.0),
	])
	_expect(habitat.screen_rects().size() == 2 and habitat.virtual_bounds() == Rect2(-1280.0, 0.0, 3200.0, 1080.0), "habitat model unifies negative-coordinate monitors into virtual desktop bounds")
	var pet_size := Vector2(360.0, 360.0)
	var secondary_floor := habitat.clamp_pet_position(Vector2(-900.0, 900.0), pet_size, true)
	_expect(is_equal_approx(secondary_floor.y, 664.0) and secondary_floor.x < 0.0, "habitat clamps a pet to the selected monitor instead of treating the inter-monitor union as walkable")
	_expect(habitat.route_mode(Vector2(-900.0, 664.0), Vector2(900.0, 720.0), pet_size) == "flight", "cross-monitor habitat travel requests a flight route")
	var anchor := habitat.make_anchor(Vector2(-700.0, 664.0), pet_size)
	var restored := habitat.restore_anchor(anchor, pet_size)
	_expect(restored.x < 0.0 and is_equal_approx(restored.y, 664.0), "habitat restores a normalized home anchor on its original monitor")
	habitat.update_screens([Rect2(0.0, 0.0, 1920.0, 1080.0)])
	var migrated := habitat.restore_anchor(anchor, pet_size)
	_expect(migrated.x >= 0.0 and migrated.y <= 720.0, "a removed monitor migrates the home anchor to the nearest safe screen")

	var profile := _load_json("res://data/ecology_profile.json")
	_expect((profile.get("goals", []) as Array).size() == 12 and (profile.get("habits", []) as Array).size() == 12 and (profile.get("discoveries", []) as Array).size() == 24, "ecology profile declares twelve goals, twelve habits and twenty-four discoveries")
	var needs := PetNeedsModel.new(_load_json("res://data/behavior_profile.json"))
	var director := GoalDirectorScript.new(profile, 22013)
	_expect(director.is_valid(), "ecology goal director accepts the complete profile")
	var goal_context := {
		"familiarity": 60.0,
		"has_foreground": true,
		"has_platform": true,
		"has_multiple_platforms": true,
		"on_platform": true,
		"cursor_available": true,
		"home_set": true,
		"time_period": "afternoon",
		"app_category": "development",
		"habit_stages": {},
	}
	var selected_goals: Array[String] = []
	for index in range(6):
		var goal := director.select_goal(needs, goal_context, 100000 + index * 300000)
		_expect(not goal.is_empty() and not (goal.get("steps", []) as Array).is_empty(), "goal director produces an executable multi-step goal")
		var goal_id := str(goal.get("id", ""))
		if selected_goals.size() >= 3:
			_expect(goal_id not in selected_goals.slice(selected_goals.size() - 3), "goal director avoids the latest three goal families when alternatives exist")
		selected_goals.append(goal_id)
	_expect(director.last_candidates.size() == 12, "goal diagnostics expose all twelve ecological goals")

	var routine := RoutineSessionScript.new()
	var routine_goal := {"id": "test_routine", "steps": [{"type": "travel"}, {"type": "intent"}]}
	_expect(routine.begin(routine_goal, 1000) and str(routine.current_step().type) == "travel", "routine session begins at its first semantic step")
	routine.complete_step("completed", 2000)
	_expect(str(routine.current_step().type) == "intent", "routine session advances only after a completed step")
	_expect(routine.interrupt("direct_interaction", true) == "paused" and routine.resume(2500), "routine session can pause for a direct interaction and resume at the same step")
	routine.complete_step("completed", 3000)
	_expect(not routine.is_active() and str(routine.snapshot().outcome) == "completed", "routine session completes after its final step")

	var requests := EcologyRequestScript.new(profile)
	var accepted := requests.evaluate("come_here", {"cursor_available": true, "energy": 72.0, "irritation": 0.0, "busy": false}, 1000)
	_expect(str(accepted.status) == "accepted" and str(accepted.goal_id) == "cursor_visit", "available ecological requests resolve to semantic goals")
	var deferred := requests.evaluate("come_here", {"cursor_available": true, "energy": 72.0, "irritation": 0.0, "busy": true}, 2000)
	_expect(str(deferred.status) == "deferred" and not requests.snapshot().is_empty(), "busy ecological requests defer for a bounded interval")
	var resumed_request := requests.poll({"cursor_available": true, "energy": 72.0, "irritation": 0.0, "busy": false}, 3000)
	_expect(str(resumed_request.status) == "accepted", "a deferred request starts at the next safe boundary")
	var refused := requests.evaluate("inspect_foreground", {"has_foreground": false, "energy": 72.0, "irritation": 0.0}, 4000)
	_expect(str(refused.status) == "refused" and str(refused.reason) == "target_unavailable", "requests refuse safely when their desktop target disappeared")

	var progression := EcologyProgressionScript.new(profile)
	progression.restore_persistent({})
	var time_events := progression.observe_event("time_observed", {"time_period": "morning"}, 100, 1000)
	var app_events := progression.observe_event("app_observed", {"app_category": "development"}, 101, 2000)
	_expect(time_events.size() == 1 and app_events.size() == 1 and int(progression.snapshot().discovery_count) == 2, "time and application observations unlock privacy-safe discovery cards")
	for index in range(3):
		progression.record_goal("floor_roam", {"time_period": "morning", "app_category": "", "goal_id": "floor_roam"}, 200 + index, 10000 + index * 600001)
	var habit_state: Dictionary = progression.habit_stages()
	_expect(int(habit_state.get("morning_patrol", 0)) == 1, "three spaced qualifying goals form the first habit stage")
	_expect(progression.familiarity() > 0.0 and (progression.persistent_snapshot().get("recent_ecology_events", []) as Array).size() <= 50, "ecology progression produces visible familiarity while bounding its private-safe history")

func _test_manual_control_model() -> void:
	var model := ManualControlModelScript.new(Vector2(300.0, 500.0))
	model.configure_oneshot_durations({"takeoff": 300.0, "land": 700.0})
	var context := {
		"floor_y": 500.0,
		"screen": Rect2(0.0, 0.0, 800.0, 600.0),
		"pet_size": Vector2(360.0, 360.0),
		"walk_speed": 120.0,
		"flight_speed": 180.0,
		"gravity": 1600.0,
		"jump_vy": -520.0,
		"wall_threshold": 40.0,
	}
	var result := model.tick(0.016, {"dir_x": 0, "dir_y": 0}, context)
	_expect(model.subphase == ManualControlModelScript.GROUND, "control model starts on the ground")
	_expect(str(result.get("clip")) == "idle", "ground without input shows idle")
	result = model.tick(0.5, {"dir_x": 1, "dir_y": 0}, context)
	_expect(str(result.get("clip")) == "patrol_floor_right", "ground walk right uses patrol_floor_right")
	model.queue_jump()
	result = model.tick(0.016, {"dir_x": 0, "dir_y": 0}, context)
	_expect(model.subphase == ManualControlModelScript.JUMP, "queue_jump on ground starts a jump")
	_expect(str(result.get("clip")) == "takeoff", "jump opens with the takeoff clip")
	for i in range(30):
		model.tick(0.1, {"dir_x": 0, "dir_y": 0}, context)
		if model.subphase == ManualControlModelScript.GROUND:
			break
	_expect(model.subphase == ManualControlModelScript.GROUND, "jump arcs and returns to the ground")
	model.reset(Vector2(300.0, 500.0))
	model.set_flight_mode(true)
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, context)
	_expect(model.flight_mode, "set_flight_mode(true) enables flight")
	_expect(model.subphase == ManualControlModelScript.FLIGHT, "flight mode lifts off")
	var start := model.position
	model.tick(0.5, {"dir_x": 0, "dir_y": -1}, context)
	_expect(model.position.y < start.y, "flight moves vertically")
	start = model.position
	model.tick(0.5, {"dir_x": 1, "dir_y": 0}, context)
	_expect(model.position.x > start.x, "flight moves horizontally")
	model.position = Vector2(10.0, 300.0)
	model._wall_release_cooldown_ms = 0.0
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, context)
	_expect(model.has_pending_attach(), "flying into the left edge starts a wall attach")
	_expect(model.attach_clip() == "patrol_balloon_arrive_left_a", "left-wall attach uses the left-anchored arrive clip")
	model.finish_attach()
	_expect(model.subphase == ManualControlModelScript.WALL, "finishing the attach enters the wall climb")
	_expect(model.wall_side < 0, "adherence is on the left wall")
	model.subphase = ManualControlModelScript.WALL
	model.wall_side = -1
	model.position = Vector2(0.0, 300.0)
	model.tick(0.016, {"dir_x": 1, "dir_y": 0}, context)
	_expect(model.has_pending_detach(), "flight detach starts a pending transition")
	_expect(model.subphase == ManualControlModelScript.WALL, "flight detach locks the pet on the wall until the clip completes")
	_expect(model.detach_clip() == "patrol_balloon_depart_left", "left-wall detach uses the left-anchored balloon clip")
	model.finish_detach()
	_expect(model.subphase == ManualControlModelScript.FLIGHT, "finishing the detach returns to flight")
	_expect(model._wall_release_cooldown_ms > 0.0, "finishing a flight detach grants re-attach grace")
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, context)
	_expect(model.subphase == ManualControlModelScript.FLIGHT, "detach grace prevents an immediate re-attach")
	for i in range(125):
		model.tick(0.016, {"dir_x": 0, "dir_y": 0}, context)
	_expect(model.subphase == ManualControlModelScript.FLIGHT, "detach grace lasts long enough to fly away (no re-suck)")
	model.set_flight_mode(false)
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, context)
	_expect(model.subphase == ManualControlModelScript.FALL, "cancelling flight while airborne falls")
	result = model.tick(0.016, {"dir_x": 0, "dir_y": 0}, context)
	_expect(str(result.get("clip")) == "drag_fall", "fall uses the drag_fall clip")
	for i in range(40):
		model.tick(0.1, {"dir_x": 0, "dir_y": 0}, context)
		if model.subphase == ManualControlModelScript.GROUND:
			break
	_expect(model.subphase == ManualControlModelScript.GROUND, "fall lands back on the ground")
	_expect(is_equal_approx(model.position.y, 500.0), "landed pet sits on the floor (no floating)")
	# Ground walk into the wall defers the climb until the corner clip completes.
	model.reset(Vector2(400.0, 500.0))
	model.tick(1.0, {"dir_x": 1, "dir_y": 0}, context)
	_expect(model.subphase == ManualControlModelScript.WALL, "ground walk into the wall attaches")
	_expect(model.has_pending_attach(), "ground attach defers until the corner clip completes")
	_expect(model.attach_clip() == "patrol_floor_to_wall_right_a", "ground attach uses the floor_to_wall corner clip")
	model.finish_attach()
	_expect(model.wall_side > 0, "ground climb attaches to the right wall")
	# Regression: clinging at the wall base with no vertical input must stay on the
	# wall (previously it oscillated ground<->wall every frame — the 鬼畜 jitter).
	for i in range(5):
		model.tick(0.016, {"dir_x": 0, "dir_y": 0}, context)
	_expect(model.subphase == ManualControlModelScript.WALL, "clinging at the wall base stays on the wall (no jitter)")
	# Pressing down at the base plays the wall_to_floor detach, then stands.
	model.tick(0.016, {"dir_x": 0, "dir_y": 1}, context)
	_expect(model.has_pending_detach(), "pressing down at the base starts a wall detach")
	_expect(model.detach_clip() == "patrol_wall_right_to_floor_left_a", "base detach uses the wall_to_floor clip")
	model.finish_detach()
	_expect(model.subphase == ManualControlModelScript.GROUND, "finishing the base detach stands on the ground")
	# Climb speed matches the animation root motion (68 px/s), not flight speed.
	model.reset(Vector2(400.0, 500.0))
	model.subphase = ManualControlModelScript.WALL
	model.wall_side = 1
	model.position = Vector2(440.0, 500.0)
	model.tick(1.0, {"dir_x": 0, "dir_y": -1}, context)
	_expect(is_equal_approx(model.position.y, 432.0), "wall climb advances at the root-motion speed (68 px/s)")
	# Non-flight detach near the ground defers until the wall_to_floor clip completes.
	model.subphase = ManualControlModelScript.WALL
	model.wall_side = 1
	model.position = Vector2(440.0, 490.0)
	model.tick(0.016, {"dir_x": -1, "dir_y": 0}, context)
	_expect(model.has_pending_detach(), "non-flight low detach starts a pending transition")
	model.finish_detach()
	_expect(model.subphase == ManualControlModelScript.GROUND, "finishing the low detach returns to the ground")
	# Non-flight detach high up falls immediately (no transition clip).
	model.subphase = ManualControlModelScript.WALL
	model.wall_side = 1
	model.position = Vector2(440.0, 200.0)
	model.tick(0.016, {"dir_x": -1, "dir_y": 0}, context)
	_expect(model.subphase == ManualControlModelScript.FALL, "non-flight high detach falls")
	_expect(not model.has_pending_detach(), "high detach does not wait for a transition clip")
	# Jumping into the screen edge clamps horizontally; the arc continues — a jump
	# never climbs, not even a legacy screen edge.
	model.reset(Vector2(400.0, 500.0))
	model.queue_jump()
	model.tick(0.016, {"dir_x": 1, "dir_y": 0}, context)
	model.position = Vector2(430.0, 300.0)
	model.subphase = ManualControlModelScript.JUMP
	model.tick(0.016, {"dir_x": 1, "dir_y": 0}, context)
	_expect(model.subphase == ManualControlModelScript.JUMP, "jumping into the screen edge stays a jump (no climb)")
	_expect(is_equal_approx(model.position.x, 440.0), "jump into the screen edge clamps the pet's right edge flush")
	# High fall engages the umbrella descent.
	model.reset(Vector2(300.0, 300.0))
	model.set_flight_mode(true)
	model.set_flight_mode(false)
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, context)
	_expect(model.umbrella, "high fall engages the umbrella")
	_expect(model.subphase == ManualControlModelScript.FALL, "umbrella descent stays in the fall sub-phase")
	# Short fall does not engage the umbrella.
	model.reset(Vector2(300.0, 480.0))
	model.set_flight_mode(true)
	model.set_flight_mode(false)
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, context)
	_expect(not model.umbrella, "short fall does not engage the umbrella")
	# A jump queued while flying must not fire after an umbrella-fall landing.
	model.reset(Vector2(300.0, 300.0))
	model.set_flight_mode(true)
	model.queue_jump()
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, context)
	model.set_flight_mode(false)
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, context)
	for i in range(40):
		model.tick(0.1, {"dir_x": 0, "dir_y": 0}, context)
		if model.subphase == ManualControlModelScript.GROUND:
			break
	_expect(model.subphase == ManualControlModelScript.GROUND, "a stale flight jump does not fire after landing")
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, context)
	_expect(model.subphase == ManualControlModelScript.GROUND, "landed pet stays standing (no queued jump)")
	# --- Window-body collision world ---
	# A tall window: walking right into its left face attaches, climbs, and mounts.
	var walls_context := context.duplicate(true)
	walls_context["walls"] = [
		{"x": 700.0, "top_y": 400.0, "bottom_y": 856.0, "side": 1, "handle": 8},
	]
	walls_context["platforms"] = [
		{"left": 645.0, "right": 755.0, "y": 44.0, "handle": 8},
	]
	walls_context["foot_offset_x"] = 180.0
	walls_context["foot_offset_y"] = 356.0
	walls_context["hop_reach_px"] = 120.0
	walls_context["auto_hop_short_walls"] = true
	model.reset(Vector2(300.0, 500.0))
	for i in range(10):
		model.tick(1.0, {"dir_x": 1, "dir_y": 0}, walls_context)
		if model.has_pending_attach():
			break
	_expect(model.has_pending_attach(), "walking into a window wall defers to the corner clip")
	_expect(model.attach_clip() == "patrol_floor_to_wall_right_a", "attaching on the window's left face uses the right-anchored corner clip")
	_expect(is_equal_approx(model.position.x, 465.0), "attach parks the pet flush against the wall face")
	model.finish_attach()
	_expect(model.subphase == ManualControlModelScript.WALL and model.wall_side == 1, "wall climb clings to the window side")
	for i in range(20):
		model.tick(0.5, {"dir_x": 0, "dir_y": -1}, walls_context)
		if model.has_pending_mount():
			break
	_expect(model.has_pending_mount(), "climbing past the wall top mounts onto it")
	_expect(model.mount_clip() == "window_land_recover", "mount plays the window land recover clip")
	_expect(is_equal_approx(model.position.y, 44.0), "mount parks the pet on the wall top")
	_expect(model.standing_plane_handle() == 8, "mounted pet stands on the window plane")
	model.finish_mount()
	_expect(model.subphase == ManualControlModelScript.GROUND, "finishing the mount stands on the window")
	# A jump into a window wall mid-air clamps flush against the face but does NOT
	# attach: only a ground walk / flight approach climbs. The arc continues (the
	# wall's horizontal extent is the only thing blocked), so the pet falls back and
	# climbs only after it walks into the wall again from the ground.
	model.reset(Vector2(420.0, 500.0))
	model.queue_jump()
	model.tick(0.016, {"dir_x": 1, "dir_y": 0}, walls_context)
	model.position = Vector2(450.0, 300.0)
	model.subphase = ManualControlModelScript.JUMP
	model.tick(0.5, {"dir_x": 1, "dir_y": 0}, walls_context)
	_expect(model.subphase == ManualControlModelScript.JUMP, "jump into a window wall stays a jump (no attach)")
	_expect(not model.has_pending_attach(), "a jump into a wall never defers to an attach clip")
	_expect(is_equal_approx(model.position.x, 465.0), "jump into a wall clamps flush against the face")
	model.tick(0.5, {"dir_x": 0, "dir_y": 0}, walls_context)
	_expect(model.position.x <= 465.0, "jump into a wall does not ride the face upward")
	# Dragging the window while the pet climbs carries it: the WALL tick must re-read
	# the current wall edge (identity handle+pid+side) instead of the stored attach
	# x, or the pet clings to the old position while the window moves away.
	model.reset(Vector2(300.0, 500.0))
	for i in range(10):
		model.tick(1.0, {"dir_x": 1, "dir_y": 0}, walls_context)
		if model.has_pending_attach():
			break
	model.finish_attach()
	model.tick(0.5, {"dir_x": 0, "dir_y": -1}, walls_context)
	_expect(model.subphase == ManualControlModelScript.WALL, "climb-follow pet clings to the window wall")
	var climb_x := model.position.x
	var moved_wall_context := walls_context.duplicate(true)
	moved_wall_context["walls"] = [
		{"x": 800.0, "top_y": 400.0, "bottom_y": 856.0, "side": 1, "handle": 8},
	]
	model.tick(0.5, {"dir_x": 0, "dir_y": -1}, moved_wall_context)
	_expect(is_equal_approx(model.position.x, climb_x + 100.0), "dragged window carries the climbing pet horizontally")
	# A wall owned by a different process must not hijack the climb.
	var other_pid_context := walls_context.duplicate(true)
	other_pid_context["walls"] = [
		{"x": 999.0, "top_y": 400.0, "bottom_y": 856.0, "side": 1, "handle": 8, "process_id": 42},
	]
	model.tick(0.5, {"dir_x": 0, "dir_y": -1}, other_pid_context)
	_expect(is_equal_approx(model.position.x, climb_x + 100.0), "a wall with a different process id does not move the pet")
	# A per-frame live wall (host-fed during a drag) beats the refresh-built
	# collision world: two consecutive frames move the window 100px each and the pet
	# tracks each frame instead of teleporting once per refresh.
	var live_a := walls_context.duplicate(true)
	live_a["live_wall"] = {"x": 750.0, "top_y": 400.0, "bottom_y": 856.0, "side": 1, "handle": 8, "process_id": 0}
	model.tick(0.5, {"dir_x": 0, "dir_y": -1}, live_a)
	_expect(is_equal_approx(model.position.x, climb_x + 50.0), "live wall frame 1: pet follows the fresh edge, not the stale wall set")
	var live_b := walls_context.duplicate(true)
	live_b["live_wall"] = {"x": 850.0, "top_y": 380.0, "bottom_y": 856.0, "side": 1, "handle": 8, "process_id": 0}
	model.tick(0.5, {"dir_x": 0, "dir_y": -1}, live_b)
	_expect(is_equal_approx(model.position.x, climb_x + 150.0), "live wall frame 2: pet tracks each per-frame edge, not the refresh batch")
	_expect(is_equal_approx(model._wall_top_y, 380.0), "live wall refreshes the mount gate too")
	# --- Fix 2: vanishing the climbed wall must auto-detach, not pin the pet ---
	# Manual climb had no wall-vanish guard (autonomous climb has _wall_handle_present
	# + 8s timeout). When the climbed window is moved away/closed/cloaked,
	# _follow_wall_edge silently keeps the stale _wall_x and the WALL tick pins
	# position.x to it: with no input and no wall the pet soft-locks to the ghost edge
	# (两小窗交界卡死). A vanished wall must detach into a fall instead.
	var vanish_ctx := walls_context.duplicate(true)
	model.reset(Vector2(300.0, 500.0))
	for i in range(10):
		model.tick(1.0, {"dir_x": 1, "dir_y": 0}, vanish_ctx)
		if model.has_pending_attach():
			break
	model.finish_attach()
	for i in range(4):
		model.tick(0.5, {"dir_x": 0, "dir_y": -1}, vanish_ctx)
		if model.subphase != ManualControlModelScript.WALL:
			break
	_expect(model.subphase == ManualControlModelScript.WALL, "fix2 pet climbs the tall window before the wall vanishes")
	_expect(model.position.y < 420.0, "fix2 pet climbs high enough for a high detach")
	var vanish_gone := vanish_ctx.duplicate(true)
	vanish_gone["walls"] = []
	vanish_gone["live_wall"] = {}
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, vanish_gone)
	_expect(model.subphase == ManualControlModelScript.FALL, "vanishing the climbed wall auto-detaches the pet into a fall (Fix 2)")
	_expect(model.wall_side == 0, "the wall-vanish detach clears the wall side (Fix 2)")
	# A still-present wall must NOT detach: the guard is not over-eager.
	model.reset(Vector2(300.0, 500.0))
	for i in range(10):
		model.tick(1.0, {"dir_x": 1, "dir_y": 0}, vanish_ctx)
		if model.has_pending_attach():
			break
	model.finish_attach()
	model.tick(0.5, {"dir_x": 0, "dir_y": -1}, vanish_ctx)
	_expect(model.subphase == ManualControlModelScript.WALL, "a still-present climbed wall keeps the pet climbing (Fix 2 not over-eager)")
	# A short window: auto-hop clears it and lands on the plane.
	var short_context := context.duplicate(true)
	short_context["walls"] = [
		{"x": 500.0, "top_y": 760.0, "bottom_y": 856.0, "side": 1, "handle": 9},
	]
	short_context["platforms"] = [
		{"left": 445.0, "right": 555.0, "y": 404.0, "handle": 9},
	]
	short_context["foot_offset_x"] = 180.0
	short_context["foot_offset_y"] = 356.0
	short_context["hop_reach_px"] = 120.0
	short_context["auto_hop_short_walls"] = true
	model.reset(Vector2(200.0, 500.0))
	model.tick(1.0, {"dir_x": 1, "dir_y": 0}, short_context)
	_expect(not model.has_pending_attach(), "a short wall is not climbed")
	_expect(is_equal_approx(model.position.x, 265.0), "auto-hop parks the pet against the short wall")
	for i in range(60):
		model.tick(0.05, {"dir_x": 0, "dir_y": 0}, short_context)
		if model.subphase == ManualControlModelScript.GROUND and i > 0:
			break
	_expect(model.subphase == ManualControlModelScript.GROUND, "auto-hop lands back on a surface")
	_expect(is_equal_approx(model.position.y, 404.0), "auto-hop lands on the short wall top")
	_expect(model.standing_plane_handle() == 9, "auto-hop landing reports the window plane")
	# Dragging the window the pet stands on carries it: the plane's left edge moves
	# under a fresh platform set and the pet follows instead of stranding its foot
	# and dropping to the floor (the stale rect during a drag used to end the ride).
	model.reset(Vector2(300.0, 500.0))
	for i in range(10):
		model.tick(1.0, {"dir_x": 1, "dir_y": 0}, walls_context)
		if model.has_pending_attach():
			break
	model.finish_attach()
	for i in range(20):
		model.tick(0.5, {"dir_x": 0, "dir_y": -1}, walls_context)
		if model.has_pending_mount():
			break
	model.finish_mount()
	_expect(model.standing_plane_handle() == 8, "drag test pet stands on the window plane")
	_expect(is_equal_approx(model.position.x, 465.0), "drag test pet parks at the plane's left edge")
	# One still tick establishes the follow baseline (a freshly landed/mounted pet
	# records the current left edge without shifting, so a mid-mount drag does not
	# snap it sideways).
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, walls_context)
	_expect(model.subphase == ManualControlModelScript.GROUND, "still pet stays standing on the window")
	_expect(is_equal_approx(model.position.x, 465.0), "still tick does not shift the pet")
	# The drag is signaled by the live per-frame segments plus the window-rect motion
	# delta (standing_plane_live_delta); a static platform-list swap no longer means
	# movement — it means the standing segment vanished, which falls after grace.
	walls_context["live_platforms"] = [
		{"left": 745.0, "right": 855.0, "y": 44.0, "handle": 8},
	]
	walls_context["standing_plane_live_delta"] = 100.0
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, walls_context)
	_expect(is_equal_approx(model.position.x, 565.0), "dragged window carries the standing pet horizontally")
	_expect(model.subphase == ManualControlModelScript.GROUND, "pet keeps standing while the window drags")
	_expect(model.standing_plane_handle() == 8, "pet stays on the dragged window plane")
	walls_context["standing_plane_live_delta"] = 0.0
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, walls_context)
	_expect(is_equal_approx(model.position.x, 565.0), "a settled window does not double-shift the pet")
	# Walking off the moved plane's right edge still falls.
	model.tick(1.0, {"dir_x": 1, "dir_y": 0}, walls_context)
	_expect(model.subphase == ManualControlModelScript.FALL, "walking off the dragged window's edge still falls")
	# --- Phase 1: plane identity (handle, pid), center-delta follow, teleport ---
	# The drag test above moved walls_context (wall at x=800); Phase 1 tests use a
	# fresh copy of the original geometry.
	var p1_context := context.duplicate(true)
	p1_context["walls"] = [
		{"x": 700.0, "top_y": 400.0, "bottom_y": 856.0, "side": 1, "handle": 8},
	]
	p1_context["platforms"] = [
		{"left": 645.0, "right": 755.0, "y": 44.0, "handle": 8},
	]
	p1_context["foot_offset_x"] = 180.0
	p1_context["foot_offset_y"] = 356.0
	p1_context["hop_reach_px"] = 120.0
	p1_context["auto_hop_short_walls"] = true
	# A same-handle plane with a different process_id is NOT the same perch: the pet
	# holds position (no follow) while the identity changes, then the vanished plane
	# drops it after the grace window.
	model.reset(Vector2(300.0, 500.0))
	for i in range(10):
		model.tick(1.0, {"dir_x": 1, "dir_y": 0}, p1_context)
		if model.has_pending_attach():
			break
	model.finish_attach()
	for i in range(20):
		model.tick(0.5, {"dir_x": 0, "dir_y": -1}, p1_context)
		if model.has_pending_mount():
			break
	model.finish_mount()
	_expect(model.standing_plane_handle() == 8 and model.standing_plane_pid() == 0, "pid test pet mounts the pid-0 window plane")
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, p1_context)
	var pid_context := p1_context.duplicate(true)
	pid_context["platforms"] = [
		{"left": 745.0, "right": 855.0, "y": 44.0, "handle": 8, "process_id": 4321},
	]
	pid_context["walls"] = [
		{"x": 800.0, "top_y": 400.0, "bottom_y": 856.0, "side": 1, "handle": 8, "process_id": 4321},
	]
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, pid_context)
	_expect(is_equal_approx(model.position.x, 465.0), "a same-handle different-pid plane is not followed")
	_expect(model.subphase == ManualControlModelScript.GROUND and model.standing_plane_handle() == 8, "identity change holds the pet in grace")
	# The wall still exists but its plane is gone: the pet holds through the grace
	# window and then falls (keeping the wall present avoids the legacy no-collision
	# floor branch, exercising the standing-plane grace path directly).
	var gone_context := pid_context.duplicate(true)
	gone_context["platforms"] = []
	for i in range(110):  # 110 * 16ms = 1.76s, past the 1500ms grace
		model.tick(0.016, {"dir_x": 0, "dir_y": 0}, gone_context)
		if model.subphase == ManualControlModelScript.FALL:
			break
	_expect(model.subphase == ManualControlModelScript.FALL, "a truly vanished standing plane drops after the grace window")
	# Center-delta follow is gated on span preservation. Stretching only the right
	# edge moves the segment center but changes the span — a reshape (like an
	# occlusion reshuffle) is not a drag, so the pet must NOT shift sideways by half
	# the width growth; the follow resets its baseline instead and the pet stays put.
	model.reset(Vector2(300.0, 500.0))
	for i in range(10):
		model.tick(1.0, {"dir_x": 1, "dir_y": 0}, p1_context)
		if model.has_pending_attach():
			break
	model.finish_attach()
	for i in range(20):
		model.tick(0.5, {"dir_x": 0, "dir_y": -1}, p1_context)
		if model.has_pending_mount():
			break
	model.finish_mount()
	_expect(is_equal_approx(model.position.x, 465.0), "center-follow test pet parks on the plane")
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, p1_context)  # baseline: center 700
	var stretch_context := p1_context.duplicate(true)
	stretch_context["platforms"] = [
		{"left": 645.0, "right": 855.0, "y": 44.0, "handle": 8},
	]
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, stretch_context)
	_expect(is_equal_approx(model.position.x, 465.0), "a right-edge stretch (span change) does NOT shift the pet sideways")
	_expect(model.subphase == ManualControlModelScript.GROUND, "pet keeps standing after a right-edge stretch")
	# A window that teleports (center moved past TELEPORT_MIN_PX at teleport speed in
	# one tick) drops the pet immediately — no grace, no follow-shift — from where it
	# actually stands.
	model.reset(Vector2(300.0, 500.0))
	for i in range(10):
		model.tick(1.0, {"dir_x": 1, "dir_y": 0}, p1_context)
		if model.has_pending_attach():
			break
	model.finish_attach()
	for i in range(20):
		model.tick(0.5, {"dir_x": 0, "dir_y": -1}, p1_context)
		if model.has_pending_mount():
			break
	model.finish_mount()
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, p1_context)  # baseline: center 700
	var teleport_context := p1_context.duplicate(true)
	teleport_context["live_platforms"] = [
		{"left": 3845.0, "right": 3955.0, "y": 44.0, "handle": 8},
	]
	teleport_context["standing_plane_live_delta"] = 3200.0
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, teleport_context)
	_expect(model.subphase == ManualControlModelScript.FALL, "a window teleport drops the pet immediately")
	_expect(model.standing_plane_handle() == 0, "teleport clears the standing plane")
	_expect(is_equal_approx(model.position.x, 465.0), "teleport leaves the pet where it stood (no follow shift)")
	# A fast-but-sub-threshold move is a drag, not a teleport: the pet follows.
	model.reset(Vector2(300.0, 500.0))
	for i in range(10):
		model.tick(1.0, {"dir_x": 1, "dir_y": 0}, p1_context)
		if model.has_pending_attach():
			break
	model.finish_attach()
	for i in range(20):
		model.tick(0.5, {"dir_x": 0, "dir_y": -1}, p1_context)
		if model.has_pending_mount():
			break
	model.finish_mount()
	model.tick(0.2, {"dir_x": 0, "dir_y": 0}, p1_context)  # baseline: center 700
	var fast_drag_context := p1_context.duplicate(true)
	fast_drag_context["live_platforms"] = [
		{"left": 1345.0, "right": 1455.0, "y": 44.0, "handle": 8},
	]
	fast_drag_context["standing_plane_live_delta"] = 700.0
	model.tick(0.2, {"dir_x": 0, "dir_y": 0}, fast_drag_context)
	_expect(is_equal_approx(model.position.x, 465.0 + 700.0), "a 700px/200ms move is followed, not treated as a teleport")
	_expect(model.subphase == ManualControlModelScript.GROUND, "pet keeps standing after the fast drag")
	# --- Phase 2: occlusion of the standing point drops the pet after grace ---
	# Standing geometry is the visible segments only. When the segment under the
	# foot is covered (removed from the platform list while the window still
	# exists), the pet holds through the grace window then falls — there is no
	# injected full-width fallback anymore. Walls stay present so the legacy
	# wall-empty floor branch cannot mask the standing-plane grace path.
	model.reset(Vector2(300.0, 500.0))
	for i in range(10):
		model.tick(1.0, {"dir_x": 1, "dir_y": 0}, p1_context)
		if model.has_pending_attach():
			break
	model.finish_attach()
	for i in range(20):
		model.tick(0.5, {"dir_x": 0, "dir_y": -1}, p1_context)
		if model.has_pending_mount():
			break
	model.finish_mount()
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, p1_context)
	var occluded_context := p1_context.duplicate(true)
	occluded_context["platforms"] = []
	for i in range(110):  # 110 * 16ms = 1.76s, past the 1500ms grace
		model.tick(0.016, {"dir_x": 0, "dir_y": 0}, occluded_context)
		if model.subphase == ManualControlModelScript.FALL:
			break
	_expect(model.subphase == ManualControlModelScript.FALL, "a covered standing point drops the pet through the grace window (no injected fallback)")
	# A segment that reappears before the grace expires keeps the pet standing — the
	# grace exists precisely for this transient-occlusion case (cached occluder rects
	# stale mid-drag).
	model.reset(Vector2(300.0, 500.0))
	for i in range(10):
		model.tick(1.0, {"dir_x": 1, "dir_y": 0}, p1_context)
		if model.has_pending_attach():
			break
	model.finish_attach()
	for i in range(20):
		model.tick(0.5, {"dir_x": 0, "dir_y": -1}, p1_context)
		if model.has_pending_mount():
			break
	model.finish_mount()
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, p1_context)
	# A segment that reappears before the grace expires keeps the pet standing — the
	# grace exists precisely for this transient-occlusion case (cached occluder rects
	# stale mid-drag). 60 * 16ms = 960ms is long past the old 450ms boundary but still
	# inside the 1500ms grace, so recovery here pins the raised grace window.
	var medium_context := p1_context.duplicate(true)
	medium_context["platforms"] = []
	for i in range(60):
		model.tick(0.016, {"dir_x": 0, "dir_y": 0}, medium_context)
		if model.subphase == ManualControlModelScript.FALL:
			break
	medium_context["platforms"] = (p1_context["platforms"] as Array)
	for i in range(5):
		model.tick(0.016, {"dir_x": 0, "dir_y": 0}, medium_context)
	_expect(model.subphase == ManualControlModelScript.GROUND, "a segment that reappears within the grace window keeps the pet standing")
	# --- Phase 3: shared landing rule (static land_on_platform) ---
	# A descending segment crossing several planes lands on the highest one.
	var planes := [
		{"left": 400.0, "right": 600.0, "y": 100.0, "handle": 1, "process_id": 10},
		{"left": 400.0, "right": 600.0, "y": 200.0, "handle": 2, "process_id": 20},
		{"left": 400.0, "right": 600.0, "y": 300.0, "handle": 3, "process_id": 30},
	]
	var landed := ManualControlModelScript.land_on_platform(50.0, 350.0, 500.0, planes)
	_expect(int(landed.get("handle", 0)) == 1 and is_equal_approx(float(landed.get("y", -1.0)), 100.0), "land_on_platform picks the highest crossed plane")
	var reached := ManualControlModelScript.land_on_platform(50.0, 120.0, 500.0, planes)
	_expect(int(reached.get("handle", 0)) == 1, "land_on_platform only crosses planes within the segment")
	var ascent := ManualControlModelScript.land_on_platform(200.0, 60.0, 500.0, planes)
	_expect(ascent.is_empty(), "land_on_platform ignores planes on the ascending side")
	var offset := ManualControlModelScript.land_on_platform(50.0, 350.0, 200.0, planes)
	_expect(offset.is_empty(), "land_on_platform ignores planes that do not contain the foot")
	# --- climb_contact: the sprite hugs the window edge while climbing ---
	# The collision body (110px) is narrower than the pet window (360px), so a body
	# flush park floats the character inside/past the pane. With host-fed contact
	# offsets the model anchors the character's wall-facing (hand) edge to the wall
	# face instead: patrol_wall_right_a's hand edge at window x 344 (side +1, left
	# face) and patrol_wall_left_a's at 15.36 (side -1, right face).
	var hug_context := context.duplicate(true)
	hug_context["foot_offset_x"] = 180.0
	hug_context["foot_offset_y"] = 356.0
	hug_context["hop_reach_px"] = 120.0
	hug_context["auto_hop_short_walls"] = true
	hug_context["climb_contact"] = {1: 344.0, -1: 15.36}
	hug_context["walls"] = [
		{"x": 700.0, "top_y": 400.0, "bottom_y": 856.0, "side": 1, "handle": 8},
	]
	hug_context["platforms"] = [
		{"left": 700.0, "right": 800.0, "y": 44.0, "handle": 8},
	]
	model.reset(Vector2(300.0, 500.0))
	for i in range(10):
		model.tick(1.0, {"dir_x": 1, "dir_y": 0}, hug_context)
		if model.has_pending_attach():
			break
	_expect(model.has_pending_attach(), "contact climb walking into the wall attaches")
	_expect(is_equal_approx(model.position.x, 356.0), "contact attach parks the hand edge on the wall face (700 - 344)")
	model.finish_attach()
	_expect(model.subphase == ManualControlModelScript.WALL and model.wall_side == 1, "contact climb clings to the left face")
	model.tick(0.5, {"dir_x": 0, "dir_y": -1}, hug_context)
	var hug_climb_x := model.position.x
	# A per-frame live wall keeps the hug flush while the window is dragged.
	var hug_live_context := hug_context.duplicate(true)
	hug_live_context["live_wall"] = {"x": 800.0, "top_y": 400.0, "bottom_y": 856.0, "side": 1, "handle": 8}
	model.tick(0.5, {"dir_x": 0, "dir_y": -1}, hug_live_context)
	_expect(is_equal_approx(model.position.x, hug_climb_x + 100.0), "a dragged wall carries the hug-climbing pet frame by frame")
	_expect(is_equal_approx(model.position.x, 456.0), "live-wall hug stays flush at the new wall face (800 - 344)")
	# The climb x is visual-hug (feet off the top surface), so mounting re-anchors the
	# foot onto the plane corner the pet reached — plane left for a left-face climb —
	# and the pet stands instead of dropping off the edge.
	for i in range(20):
		model.tick(0.5, {"dir_x": 0, "dir_y": -1}, hug_live_context)
		if model.has_pending_mount():
			break
	_expect(model.has_pending_mount(), "contact climb mounts at the wall top")
	_expect(is_equal_approx(model.position.x, 520.0), "left-face mount re-anchors the foot onto the plane's left corner (700 - 180)")
	model.finish_mount()
	_expect(model.subphase == ManualControlModelScript.GROUND and model.standing_plane_handle() == 8, "contact-climb mount stands on the window plane")
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, hug_live_context)
	_expect(model.subphase == ManualControlModelScript.GROUND, "contact-climb mount keeps standing (foot is on the plane)")
	# Right face (side=-1) uses patrol_wall_left_a's hand edge and mounts at the
	# plane's right corner, so the pet hugs that side and lands on the top-right.
	var hug_right_context := hug_context.duplicate(true)
	hug_right_context["walls"] = [
		{"x": 800.0, "top_y": 400.0, "bottom_y": 856.0, "side": -1, "handle": 9},
	]
	hug_right_context["platforms"] = [
		{"left": 700.0, "right": 800.0, "y": 44.0, "handle": 9},
	]
	model.reset(Vector2(860.0, 500.0))
	for i in range(10):
		model.tick(1.0, {"dir_x": -1, "dir_y": 0}, hug_right_context)
		if model.has_pending_attach():
			break
	_expect(model.has_pending_attach(), "contact climb into the right face attaches")
	_expect(is_equal_approx(model.position.x, 784.64), "right-face attach parks the hand edge on the wall face (800 - 15.36)")
	model.finish_attach()
	_expect(model.wall_side == -1, "contact climb clings to the right face")
	for i in range(20):
		model.tick(0.5, {"dir_x": 0, "dir_y": -1}, hug_right_context)
		if model.has_pending_mount():
			break
	_expect(model.has_pending_mount(), "right-face contact climb mounts at the top")
	_expect(is_equal_approx(model.position.x, 620.0), "right-face mount re-anchors the foot onto the plane's right corner (800 - 180)")
	model.finish_mount()
	_expect(model.subphase == ManualControlModelScript.GROUND and model.standing_plane_handle() == 9, "right-face contact-climb mount stands")
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, hug_right_context)
	_expect(model.subphase == ManualControlModelScript.GROUND, "right-face mount keeps standing (foot is on the plane)")
	# --- Entry-state preservation: toggling into manual control must not move the pet ---
	# The model is (re)initialized at the pet's current position, and the first tick
	# must keep that position. A pet riding a window enters with its feet flush on the
	# plane top and keeps standing; a pet caught mid-air enters falling from the current
	# height; a floor entry stays on the floor. Previously all three snapped
	# position.y to the floor, visibly teleporting the character on the state switch.
	var entry_context := {
		"floor_y": 500.0,
		"screen": Rect2(0.0, 0.0, 800.0, 600.0),
		"pet_size": Vector2(360.0, 360.0),
		"walk_speed": 120.0,
		"flight_speed": 180.0,
		"climb_speed": 68.0,
		"gravity": 1600.0,
		"jump_vy": -520.0,
		"wall_threshold": 40.0,
		"umbrella_available": false,
		"foot_offset_x": 180.0,
		"foot_offset_y": 356.0,
		"walls": [
			{"x": 700.0, "top_y": 400.0, "bottom_y": 856.0, "side": 1, "handle": 8},
		],
		"platforms": [
			{"left": 645.0, "right": 755.0, "y": 44.0, "handle": 8},
		],
	}
	# Riding entry: feet flush on the plane top (foot = position + (180, 356) rests at
	# the plane's y = 44). The pet keeps standing on the window at the exact position.
	model.set_preserve_entry_position(true)
	model.reset(Vector2(500.0, 44.0))
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, entry_context)
	_expect(model.subphase == ManualControlModelScript.GROUND, "riding entry keeps the pet on the ground")
	_expect(model.standing_plane_handle() == 8, "riding entry adopts the window plane the feet rest on")
	_expect(model.position == Vector2(500.0, 44.0), "riding entry preserves the exact position (no floor snap)")
	# Mid-air entry: above the floor and not flush on a plane top -> fall from the
	# current height instead of teleporting down to the floor.
	model.reset(Vector2(500.0, 100.0))
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, entry_context)
	_expect(model.subphase == ManualControlModelScript.FALL, "mid-air entry falls from the current height")
	_expect(model.position.y < 200.0, "mid-air entry does not snap to the floor (falls from near y=100)")
	# Floor entry: already on the ground, nothing to adopt, position untouched.
	model.reset(Vector2(500.0, 500.0))
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, entry_context)
	_expect(model.subphase == ManualControlModelScript.GROUND, "floor entry stays grounded")
	_expect(model.standing_plane_handle() == 0, "floor entry adopts no plane")
	_expect(is_equal_approx(model.position.y, 500.0), "floor entry keeps the floor position")
	# The adopted plane is a real perch: walking along it stays on it instead of
	# dropping through once input resumes.
	model.reset(Vector2(500.0, 44.0))
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, entry_context)
	model.tick(0.5, {"dir_x": 1, "dir_y": 0}, entry_context)
	_expect(model.subphase == ManualControlModelScript.GROUND, "walking after a riding entry stays on the adopted plane")
	_expect(model.position.x > 500.0 and model.position.x <= 560.0, "walking after a riding entry advances along the plane")
	# --- Per-frame live segments: a dragged window carries the standing pet frame by frame ---
	# The refresh-built `platforms` list only moves at the window-refresh cadence, so a
	# fast drag would carry the pet in ~500ms steps. The host feeds the standing
	# window's per-frame visible top segments (`live_platforms`) and the window-rect
	# motion signal (`standing_plane_live_delta`) every tick; the model replaces the
	# refresh segments with the live ones and gates perch continuity on the motion
	# signal — a static window whose segment stopped covering the foot has really been
	# occluded (the pet falls), while a dragged window follows its moving segment.
	var live_plane_context := entry_context.duplicate(true)
	model.set_preserve_entry_position(true)
	model.reset(Vector2(500.0, 44.0))
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, live_plane_context)
	_expect(model.subphase == ManualControlModelScript.GROUND and model.standing_plane_handle() == 8, "live-segment test pet stands on the adopted plane")
	_expect(is_equal_approx(model.position.x, 500.0), "live-segment test baseline tick records the center without shifting")
	# Live segments for a different window do not evict the real perch (the merge
	# keeps foreign segments out; the standing segment stays authoritative).
	live_plane_context["live_platforms"] = [{"left": 845.0, "right": 955.0, "y": 44.0, "handle": 99, "process_id": 0}]
	live_plane_context["standing_plane_live_delta"] = 0.0
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, live_plane_context)
	_expect(model.subphase == ManualControlModelScript.GROUND, "live segments for another window do not evict the pet")
	_expect(is_equal_approx(model.position.x, 500.0), "live segments for another window do not move the pet")
	# Now the real window: move it 200px right. The pet follows by the center delta in
	# a single tick even though the refresh `platforms` list still holds the old rect
	# ([645, 755]) — the fresh live segment wins.
	live_plane_context["live_platforms"] = [{"left": 845.0, "right": 955.0, "y": 44.0, "handle": 8, "process_id": 0}]
	live_plane_context["standing_plane_live_delta"] = 200.0
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, live_plane_context)
	_expect(is_equal_approx(model.position.x, 700.0), "live segment frame 1: pet follows the fresh segment, not the stale platform set")
	_expect(model.subphase == ManualControlModelScript.GROUND, "live segment drag keeps the pet standing")
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, live_plane_context)
	_expect(is_equal_approx(model.position.x, 700.0), "a settled live segment does not double-shift the pet")
	# Dragging the window down moves the y-pin too (the standing plane is a real perch,
	# carried vertically by the same per-frame source).
	live_plane_context["live_platforms"] = [{"left": 845.0, "right": 955.0, "y": 64.0, "handle": 8, "process_id": 0}]
	live_plane_context["standing_plane_live_delta"] = 0.0
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, live_plane_context)
	_expect(is_equal_approx(model.position.y, 64.0), "live segment carries the pet vertically when the window is dragged down")
	_expect(is_equal_approx(model.position.x, 700.0), "vertical drag does not shift the pet sideways")
	# Walking along the live segment stays on it (edge checks use the fresh segment).
	model.tick(0.5, {"dir_x": 1, "dir_y": 0}, live_plane_context)
	_expect(model.subphase == ManualControlModelScript.GROUND, "walking on a live-dragged plane stays standing")
	_expect(is_equal_approx(model.position.x, 760.0), "walking advances along the live segment")
	# --- Multi-segment top edge: a window occluded into several segments ---
	# One window can yield several top segments. The model must stand on / follow the
	# segment its foot is on, not the first matching segment (bug: first-match made
	# the pet standing on segment 2 misjudge walking off segment 1's edge and fall).
	var segment_context := entry_context.duplicate(true)
	segment_context["platforms"] = [
		{"left": 100.0, "right": 200.0, "y": 44.0, "handle": 8},
		{"left": 300.0, "right": 400.0, "y": 44.0, "handle": 8},
	]
	segment_context["walls"] = [
		{"x": 300.0, "top_y": 400.0, "bottom_y": 856.0, "side": 1, "handle": 8},
	]
	model.set_preserve_entry_position(true)
	model.reset(Vector2(150.0, 44.0))
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, segment_context)
	_expect(model.subphase == ManualControlModelScript.GROUND, "two-segment entry lands on segment 2 and stands")
	_expect(model.standing_plane_handle() == 8, "two-segment entry adopts the window identity")
	_expect(model.position == Vector2(150.0, 44.0), "two-segment entry preserves the exact position")
	# Walking right on segment 2 stays standing: the old first-match code judged the
	# foot (342) against segment 1's right edge (200) and dropped the pet.
	model.tick(0.1, {"dir_x": 1, "dir_y": 0}, segment_context)
	_expect(model.subphase == ManualControlModelScript.GROUND, "walking on segment 2 stays standing (segment selection follows the foot)")
	_expect(is_equal_approx(model.position.x, 162.0), "walking on segment 2 advances along its own span")
	# Past segment 2's right edge the pet falls.
	model.tick(0.5, {"dir_x": 1, "dir_y": 0}, segment_context)
	_expect(model.subphase == ManualControlModelScript.FALL, "walking past segment 2's right edge drops the pet")
	# Multi-segment follow: standing on segment 2, when segment 2 moves while segment
	# 1 stays put the pet follows its own segment's center delta — the old first-match
	# code saw segment 1's static center and did not move at all.
	var follow_context := entry_context.duplicate(true)
	follow_context["platforms"] = [
		{"left": 100.0, "right": 200.0, "y": 44.0, "handle": 8},
		{"left": 300.0, "right": 400.0, "y": 44.0, "handle": 8},
	]
	model.set_preserve_entry_position(true)
	model.reset(Vector2(150.0, 44.0))
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, follow_context)
	_expect(model.subphase == ManualControlModelScript.GROUND, "multi-segment follow baseline pet stands on segment 2")
	follow_context["live_platforms"] = [
		{"left": 100.0, "right": 200.0, "y": 44.0, "handle": 8},
		{"left": 500.0, "right": 600.0, "y": 44.0, "handle": 8},
	]
	follow_context["standing_plane_live_delta"] = 200.0
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, follow_context)
	_expect(is_equal_approx(model.position.x, 350.0), "multi-segment pet follows the segment it stands on, not the first segment")
	_expect(model.subphase == ManualControlModelScript.GROUND, "multi-segment follow keeps standing on the moved segment")
	# Inner-wall mount: the window is split into two segments; the pet climbs the
	# wall at x=300 (the left face of segment 2). The mount must anchor onto the
	# adjacent segment (segment 2, edge closest to the wall face), not the first
	# matching segment (old code anchored onto segment 1 and parked the pet at -80).
	var mount_context := entry_context.duplicate(true)
	mount_context["platforms"] = [
		{"left": 100.0, "right": 200.0, "y": 44.0, "handle": 8},
		{"left": 300.0, "right": 400.0, "y": 44.0, "handle": 8},
	]
	mount_context["walls"] = [
		{"x": 300.0, "top_y": 400.0, "bottom_y": 856.0, "side": 1, "handle": 8},
	]
	mount_context["climb_contact"] = {1: 344.0, -1: 15.36}
	mount_context["hop_reach_px"] = 120.0
	mount_context["auto_hop_short_walls"] = true
	model.reset(Vector2(50.0, 500.0))
	for i in range(10):
		model.tick(1.0, {"dir_x": 1, "dir_y": 0}, mount_context)
		if model.has_pending_attach():
			break
	_expect(model.has_pending_attach(), "inner-wall climb walking right attaches")
	model.finish_attach()
	_expect(model.subphase == ManualControlModelScript.WALL and model.wall_side == 1, "inner-wall climb clings to the left face at x=300")
	for i in range(20):
		model.tick(0.5, {"dir_x": 0, "dir_y": -1}, mount_context)
		if model.has_pending_mount():
			break
	_expect(model.has_pending_mount(), "inner-wall climb mounts at the top")
	_expect(is_equal_approx(model.position.x, 120.0), "inner-wall mount anchors onto the adjacent segment's left edge (300 - 180)")
	model.finish_mount()
	_expect(model.subphase == ManualControlModelScript.GROUND and model.standing_plane_handle() == 8, "inner-wall mount stands on the window")
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, mount_context)
	_expect(model.subphase == ManualControlModelScript.GROUND, "inner-wall mount keeps standing (foot is on segment 2)")
	# --- Manual jump: the control-mode boost raises the apex ---
	# main.gd feeds input["jump_boost"] (MANUAL_CONTROL_JUMP_BOOST x1.1 for manual
	# control, absent=1.0 for the autonomous climb); the model must honor a boost by
	# arcing higher than the unboosted default.
	var apex_for_boost := func(boost: float) -> float:
		var boost_input := {"dir_x": 0, "dir_y": 0, "jump_boost": boost}
		model.reset(Vector2(300.0, 500.0))
		model.tick(0.016, boost_input, context)
		model.queue_jump()
		model.tick(0.016, boost_input, context)
		_expect(model.subphase == ManualControlModelScript.JUMP, "boosted jump leaves the ground")
		var apex_y := 500.0
		# 0.016s ticks: the arc is ~45 ticks plus the 700ms "land" oneshot (~44 ticks),
		# so 130 ticks lets the jump complete back to GROUND.
		for i in range(130):
			model.tick(0.016, boost_input, context)
			if model.subphase == ManualControlModelScript.GROUND:
				break
			apex_y = minf(apex_y, model.position.y)
		return apex_y
	var default_apex: float = apex_for_boost.call(1.0)
	var boosted_apex: float = apex_for_boost.call(1.1)
	_expect(default_apex > 400.0 and default_apex < 425.0, "default jump apex ~84px above the floor (%s)" % default_apex)
	_expect(boosted_apex < default_apex, "the manual-control jump boost reaches a higher apex (%.1f vs %.1f)" % [boosted_apex, default_apex])
	# Mid-jump air control: holding left/right moves the pet while it is airborne.
	var boosted_setup := {"dir_x": 0, "dir_y": 0, "jump_boost": 1.1}
	var boosted_move := {"dir_x": 1, "dir_y": 0, "jump_boost": 1.1}
	model.reset(Vector2(300.0, 500.0))
	model.tick(0.016, boosted_setup, context)
	model.queue_jump()
	model.tick(0.016, boosted_setup, context)
	var jump_x := model.position.x
	# 0.1s ticks: the arc is ~8 ticks and the 700ms "land" oneshot ~7 more, so 30
	# ticks comfortably completes the jump back to GROUND.
	for i in range(30):
		model.tick(0.1, boosted_move, context)
		if model.subphase == ManualControlModelScript.GROUND:
			break
	_expect(model.position.x > jump_x, "holding right during a jump moves the pet horizontally (air control)")
	_expect(model.subphase == ManualControlModelScript.GROUND, "air-controlled jump lands back on the ground")
	# --- Aligned transfer (Tier 2 standing rule) ---
	# Standing on window A, a front window B whose top edge is the SAME height
	# covers the foot: the pet smoothly stands on B (handle switches, no fall).
	model.set_preserve_entry_position(true)
	model.reset(Vector2(20.0, 44.0))
	var transfer_context := {
		"floor_y": 500.0,
		"screen": Rect2(0, 0, 800, 600),
		"pet_size": Vector2(360, 360),
		"platforms": [
			{"left": 100.0, "right": 300.0, "y": 44.0, "handle": 1},
		],
		"walls": [],
	}
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, transfer_context)
	_expect(model.standing_plane_handle() == 1, "pet stands on the first window")
	var covered_context := transfer_context.duplicate(true)
	covered_context["platforms"] = [
		{"left": 200.0, "right": 400.0, "y": 44.0, "handle": 2},
	]
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, covered_context)
	_expect(model.standing_plane_handle() == 2, "a same-height front window adopts the standing handle (no fall)")
	_expect(model.subphase == ManualControlModelScript.GROUND, "aligned transfer keeps standing")
	_expect(is_equal_approx(model.position.y, 44.0), "aligned transfer stays on the transferred top edge")
	# A front window whose top is HIGHER (y smaller, beyond the tolerance) drops the
	# pet after the standing grace: no same-height plane covers the foot.
	model.set_preserve_entry_position(true)
	model.reset(Vector2(20.0, 44.0))
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, transfer_context)
	var higher_context := transfer_context.duplicate(true)
	higher_context["platforms"] = [
		{"left": 200.0, "right": 400.0, "y": -6.0, "handle": 3},
	]
	for i in range(18):  # 18 * 100ms = 1.8s, past the 1500ms grace
		model.tick(0.1, {"dir_x": 0, "dir_y": 0}, higher_context)
		if model.subphase == ManualControlModelScript.FALL:
			break
	_expect(model.subphase == ManualControlModelScript.FALL, "a higher front window drops the pet after the grace")
	# --- Fullscreen occlusion: two small windows covered -> the pet falls to the floor ---
	model.set_preserve_entry_position(true)
	model.reset(Vector2(200.0, 44.0))
	var small_window_context := {
		"floor_y": 500.0,
		"screen": Rect2(0, 0, 1920, 1080),
		"pet_size": Vector2(360, 360),
		"platforms": [
			{"left": 100.0, "right": 500.0, "y": 44.0, "handle": 1},
		],
		"walls": [],
	}
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, small_window_context)
	_expect(model.standing_plane_handle() == 1, "pet stands on a small window")
	var swallowed_context := small_window_context.duplicate(true)
	swallowed_context["platforms"] = []
	for i in range(120):
		model.tick(0.1, {"dir_x": 0, "dir_y": 0}, swallowed_context)
		if model.subphase == ManualControlModelScript.GROUND and is_equal_approx(model.position.y, 500.0):
			break
	_expect(model.subphase == ManualControlModelScript.GROUND, "fullscreen occlusion drops the pet to the ground")
	_expect(is_equal_approx(model.position.y, 500.0), "the pet lands on the floor, not on the fullscreen window's top")
	# --- Flight: only blocks at the side, free over the top ---
	# Feet above the window's top (top_y >= foot_y) -> the wall is skipped entirely.
	var over_top_context := context.duplicate(true)
	over_top_context["walls"] = [
		{"x": 500.0, "top_y": 450.0, "bottom_y": 856.0, "side": 1, "handle": 8},
	]
	model.reset(Vector2(200.0, 44.0))
	# The flight tests launch the pet mid-air with no entry surface; opting out of
	# entry-position preservation stops _adopt_entry_state from forcing a FALL
	# before the flight branch ever runs (set_preserve_entry_position(true) leaked
	# in from the transfer tests above).
	model.set_preserve_entry_position(false)
	model.set_flight_mode(true)
	model._wall_release_cooldown_ms = 0.0
	model.tick(0.016, {"dir_x": 1, "dir_y": 0}, over_top_context)
	model.tick(0.5, {"dir_x": 1, "dir_y": 0}, over_top_context)
	_expect(not model.has_pending_attach(), "flying with the feet above the window's top passes freely")
	# Feet level with a taller window's face -> the side blocks and the pet attaches.
	var side_block_context := context.duplicate(true)
	side_block_context["walls"] = [
		{"x": 500.0, "top_y": 350.0, "bottom_y": 856.0, "side": 1, "handle": 8},
	]
	model.reset(Vector2(200.0, 44.0))
	model.set_preserve_entry_position(false)
	model.set_flight_mode(true)
	model._wall_release_cooldown_ms = 0.0
	model.tick(0.016, {"dir_x": 1, "dir_y": 0}, side_block_context)
	model.tick(0.5, {"dir_x": 1, "dir_y": 0}, side_block_context)
	_expect(model.has_pending_attach(), "flying level with a window side attaches to it")
	# --- Flight toggle: double-tap up must lift off from any state ---
	# Mid-fall (even mid-umbrella-fall) -> cancel the fall and take off. The old
	# set_flight_mode set the flag from FALL without leaving the subphase, so the
	# toggle looked dead and the pet kept falling.
	model.reset(Vector2(300.0, 300.0))
	model.set_preserve_entry_position(false)
	model.set_flight_mode(true)
	model.set_flight_mode(false)
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, context)
	_expect(model.subphase == ManualControlModelScript.FALL and model.umbrella, "high fall descends with the umbrella")
	model.set_flight_mode(true)
	_expect(model.subphase == ManualControlModelScript.FLIGHT, "double-tap up cancels a fall and lifts off")
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, context)
	_expect(model.subphase == ManualControlModelScript.FLIGHT and not model.umbrella, "flight resumes cleanly, umbrella cleared")
	# A climb mount leaves flight_mode on while the pet stands on the window top; a
	# double-tap up must still take off instead of early-returning on the stale flag.
	model.reset(Vector2(200.0, 44.0))
	model.set_preserve_entry_position(false)
	model.flight_mode = true  # simulate the stale flag a mount leaves behind
	model.set_flight_mode(true)
	_expect(model.subphase == ManualControlModelScript.FLIGHT, "double-tap up lifts off even with a stale flight flag")
	model.set_flight_mode(false)
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, context)
	_expect(not model.flight_mode, "double-tap down clears the stale flag")
	# Double-tap up while attached to a wall lifts off and drops the pending attach.
	model.reset(Vector2(200.0, 44.0))
	model.set_preserve_entry_position(false)
	model.set_flight_mode(true)
	model._wall_release_cooldown_ms = 0.0
	model.tick(0.016, {"dir_x": 1, "dir_y": 0}, side_block_context)
	model.tick(0.5, {"dir_x": 1, "dir_y": 0}, side_block_context)
	_expect(model.has_pending_attach(), "flying level with a window side attaches to it")
	model.set_flight_mode(true)
	_expect(model.subphase == ManualControlModelScript.FLIGHT, "double-tap up lifts off from an attached wall")
	_expect(not model.has_pending_attach(), "the pending attach is dropped")
	model.tick(0.016, {"dir_x": 1, "dir_y": 0}, side_block_context)
	_expect(model.subphase == ManualControlModelScript.FLIGHT, "the lifted-off pet flies (FLIGHT branch is not gated shut)")
	# --- Bug A: a window landing plays the full landing animation ---
	# The floor path lands with a "land" one-shot (via LANDING); the plane path used
	# to go straight to GROUND with no landing clip, so landing on a small window had
	# no landing motion and (with the stale clip identity in main.gd) froze on the
	# last umbrella frame. The plane catch must play the "land" clip too.
	model.reset(Vector2(300.0, 100.0))
	model.set_preserve_entry_position(false)
	model.set_flight_mode(true)
	model.set_flight_mode(false)  # start a fall above the plane
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, context)
	_expect(model.subphase == ManualControlModelScript.FALL, "window-landing test falls from above the plane")
	var plane_land_context := context.duplicate(true)
	plane_land_context["platforms"] = [
		{"left": 100.0, "right": 700.0, "y": 300.0, "handle": 7},
	]
	var window_landed := false
	var window_land_clip := ""
	for i in range(200):
		var landing_result: Dictionary = model.tick(0.1, {"dir_x": 0, "dir_y": 0}, plane_land_context)
		if str(landing_result.get("subphase", "")) == "ground":
			window_landed = true
			window_land_clip = str(landing_result.get("clip", ""))
			break
	_expect(window_landed, "a fall mounts the window plane (subphase ground)")
	_expect(model.standing_plane_handle() == 7, "the window landing stands on the plane")
	_expect(window_land_clip == "land", "a window landing plays the landing animation (clip land)")
	# --- Bug B: dragging the standing window must not squeeze the pet off ---
	# The standing window's live segments vanishing mid-drag (query hiccup / stale
	# occluder rects) must HOLD the pet, not fall: the foot has not lost support —
	# the window is still being carried. Only a STATIC window whose support is really
	# gone starts the grace-then-fall (matches "脚底完全失去支撑才坠落").
	model.set_preserve_entry_position(true)
	model.reset(Vector2(100.0, 44.0))  # foot_x = 280 within the plane's [100,300]
	var stand_context := {
		"floor_y": 500.0,
		"screen": Rect2(0, 0, 800, 600),
		"pet_size": Vector2(360, 360),
		"platforms": [{"left": 100.0, "right": 300.0, "y": 44.0, "handle": 1}],
		"walls": [],
	}
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, stand_context)
	_expect(model.standing_plane_handle() == 1, "pet stands on the window before the drag")
	var drag_gap := stand_context.duplicate(true)
	drag_gap["platforms"] = []
	drag_gap["live_platforms"] = []
	drag_gap["standing_plane_live_delta"] = 50.0
	var held := true
	for i in range(200):  # 200 * 16ms = 3.2s, far past the 1500ms grace
		model.tick(0.016, {"dir_x": 0, "dir_y": 0}, drag_gap)
		if model.subphase != ManualControlModelScript.GROUND:
			held = false
			break
	_expect(held, "a mid-drag vanishing segment does not squeeze the pet off (holds)")
	_expect(is_equal_approx(model._standing_plane_gone_ms, 0.0), "the drag hold never accrues standing grace")
	drag_gap["standing_plane_live_delta"] = 0.0  # drag stops; support really gone
	var fell := false
	for i in range(200):
		model.tick(0.016, {"dir_x": 0, "dir_y": 0}, drag_gap)
		if model.subphase == ManualControlModelScript.FALL:
			fell = true
			break
	_expect(fell, "a static window whose support is gone still falls after the grace")
	# --- Fix 3: a drag hold must never read as "stuck" ---
	# Bug B holds the pet while the standing window's segments vanish mid-drag, but the
	# hold previously skipped walking entirely — with input the pet stayed glued (reads
	# as 卡死). The user must still be able to walk sideways off the dragging window.
	model.set_preserve_entry_position(true)
	model.reset(Vector2(100.0, 44.0))  # foot_x = 280 within the plane's [100,300]
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, stand_context)
	_expect(model.standing_plane_handle() == 1, "fix3 pet stands on the window before the drag hold")
	var hold_walk := stand_context.duplicate(true)
	hold_walk["platforms"] = []
	hold_walk["live_platforms"] = []
	hold_walk["standing_plane_live_delta"] = 50.0
	var hold_start_x := model.position.x
	for i in range(30):
		model.tick(0.016, {"dir_x": 1, "dir_y": 0}, hold_walk)
	_expect(model.subphase == ManualControlModelScript.GROUND, "the drag hold still holds the pet standing")
	_expect(model.position.x > hold_start_x + 10.0, "the drag hold still lets the pet walk sideways off the window (Fix 3)")
	var hold_idle_x := model.position.x
	for i in range(30):
		model.tick(0.016, {"dir_x": 0, "dir_y": 0}, hold_walk)
	_expect(is_equal_approx(model.position.x, hold_idle_x), "the drag hold with no input keeps the pet in place (Bug B regression)")
	# --- Fix 4: a VERTICAL drag must hold, not fall (小窗向上移动一段距离) ---
	# The Bug B hold gate was X-only (`standing_plane_live_delta`); a vertical drag
	# moves no X, so the model read the dragged window as STATIC and committed to the
	# 1500ms grace the instant the top segment was sliced — the pet got "pushed off" by
	# an upward drag. The Y delta must feed window_moving too.
	model.set_preserve_entry_position(true)
	model.reset(Vector2(100.0, 44.0))
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, stand_context)
	_expect(model.standing_plane_handle() == 1, "fix4 pet stands on the window before the vertical drag")
	var vertical_drag := stand_context.duplicate(true)
	vertical_drag["platforms"] = []
	vertical_drag["live_platforms"] = []
	vertical_drag["standing_plane_live_delta"] = 0.0   # X center does not move during a vertical drag
	vertical_drag["standing_plane_live_delta_y"] = -50.0  # window dragged UP 50px/tick
	var vertical_held := true
	for i in range(200):  # 3.2s, far past the 1500ms grace
		model.tick(0.016, {"dir_x": 0, "dir_y": 0}, vertical_drag)
		if model.subphase != ManualControlModelScript.GROUND:
			vertical_held = false
			break
	_expect(vertical_held, "a vertical drag with a sliced standing segment holds the pet (never pushed off)")
	_expect(is_equal_approx(model._standing_plane_gone_ms, 0.0), "the vertical-drag hold never accrues standing grace")
	vertical_drag["standing_plane_live_delta_y"] = 0.0  # drag stops; support really gone
	var vertical_fell := false
	for i in range(200):
		model.tick(0.016, {"dir_x": 0, "dir_y": 0}, vertical_drag)
		if model.subphase == ManualControlModelScript.FALL:
			vertical_fell = true
			break
	_expect(vertical_fell, "a static window whose support is gone still falls after the grace (vertical axis regression)")
	# --- Occlusion reshuffle must not teleport the pet ---
	# _follow_standing_plane follows the standing segment's CENTER. When an
	# approaching front window first clips the standing window's top, the segment
	# splits/reshuffles: the foot stays on one fragment, but the fragment's center
	# differs from the pre-split full segment, so a center-delta follow snaps the pet
	# sideways (opposite to the approach — the reported "瞬移"). Only a real drag
	# (span preserved) may move the pet; an occlusion reshuffle (span changes) must
	# reset the baseline instead.
	model.set_preserve_entry_position(true)
	model.reset(Vector2(180.0, 44.0))  # foot_x = 360 within A's [100,500]
	var reshuffle_base := {
		"floor_y": 500.0,
		"screen": Rect2(0, 0, 800, 600),
		"pet_size": Vector2(360, 360),
		"platforms": [{"left": 100.0, "right": 500.0, "y": 44.0, "handle": 1}],
		"walls": [],
	}
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, reshuffle_base)
	_expect(model.standing_plane_handle() == 1, "pet stands on the window before the occlusion reshuffle")
	_expect(is_equal_approx(model.position.x, 180.0), "pet starts at its anchor x")
	# An approaching front window clips A's top from the left: the standable fragment
	# shrinks to [350,500] (foot still on it). Span 400 -> 150, center 300 -> 425 — a
	# center-delta follow would snap the pet +125px away from the approach.
	var reshuffle_clipped := reshuffle_base.duplicate(true)
	reshuffle_clipped["platforms"] = [{"left": 350.0, "right": 500.0, "y": 44.0, "handle": 1}]
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, reshuffle_clipped)
	_expect(model.subphase == ManualControlModelScript.GROUND, "occlusion reshuffle keeps the pet standing")
	_expect(is_equal_approx(model.position.x, 180.0), "an occlusion reshuffle does NOT teleport the pet (baseline reset, no snap)")
	# A real drag (span preserved) still carries the pet.
	model.reset(Vector2(180.0, 44.0))
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, reshuffle_base)
	var drag_span := reshuffle_base.duplicate(true)
	drag_span["platforms"] = [{"left": 80.0, "right": 480.0, "y": 44.0, "handle": 1}]
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, drag_span)
	_expect(is_equal_approx(model.position.x, 160.0), "a real window drag (span preserved) still carries the pet")
	# --- DesktopWorld same-source: Dictionary and named world drive the model identically ---
	var same_platforms := [
		{"left": 300.0, "right": 500.0, "y": 44.0, "handle": 8},
	]
	var dict_world := {
		"floor_y": 500.0,
		"screen": Rect2(0, 0, 800, 600),
		"pet_size": Vector2(360, 360),
		"platforms": same_platforms,
		"walls": [],
	}
	var named_world := DesktopWorld.new()
	named_world.floor_y = 500.0
	named_world.screen = Rect2(0, 0, 800, 600)
	named_world.pet_size = Vector2(360, 360)
	named_world.platforms = same_platforms
	named_world.walls = []
	var dict_run: Dictionary = {}
	var named_run: Dictionary = {}
	model.reset(Vector2(120.0, 44.0))
	model.set_preserve_entry_position(true)
	for i in range(5):
		dict_run = model.tick(0.1, {"dir_x": 1, "dir_y": 0}, dict_world)
	model.reset(Vector2(120.0, 44.0))
	model.set_preserve_entry_position(true)
	for i in range(5):
		named_run = model.tick(0.1, {"dir_x": 1, "dir_y": 0}, named_world)
	_expect(
		Vector2(dict_run.get("position", Vector2.ZERO)) == Vector2(named_run.get("position", Vector2.ZERO))
		and str(dict_run.get("subphase", "")) == str(named_run.get("subphase", "")),
		"Dictionary and DesktopWorld worlds drive the model identically (same-source)"
	)
	# --- Staircase hop: walking toward a higher window within hop reach ---
	# A higher window whose top is within hop_reach of the standing plane is hopped
	# onto: the walk resolves the other window's wall as a short wall, launches a
	# hop, and the descending arc lands on the higher plane.
	var staircase_context := entry_context.duplicate(true)
	staircase_context["platforms"] = [
		{"left": 300.0, "right": 500.0, "y": 44.0, "handle": 8},
		{"left": 400.0, "right": 600.0, "y": -36.0, "handle": 9},
	]
	staircase_context["walls"] = [
		{"x": 400.0, "top_y": 320.0, "bottom_y": 856.0, "side": 1, "handle": 9},
	]
	staircase_context["foot_offset_x"] = 180.0
	staircase_context["foot_offset_y"] = 356.0
	staircase_context["hop_reach_px"] = 120.0
	staircase_context["auto_hop_short_walls"] = true
	model.set_preserve_entry_position(true)
	model.reset(Vector2(120.0, 44.0))
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, staircase_context)
	_expect(model.subphase == ManualControlModelScript.GROUND and model.standing_plane_handle() == 8, "staircase pet stands on the lower window")
	for i in range(120):
		model.tick(0.1, {"dir_x": 1, "dir_y": 0}, staircase_context)
		if model.standing_plane_handle() == 9:
			break
	_expect(model.standing_plane_handle() == 9, "walking toward a higher window within hop reach auto-hops onto it")
	_expect(model.subphase == ManualControlModelScript.GROUND, "staircase hop lands standing on the higher window")
	# --- Staircase climb: a higher window beyond hop reach is climbed ---
	# The same walk, but the higher window's top is 200px above the feet (beyond
	# hop_reach 120): the other window's wall is not short, so the pet climbs its
	# face and mounts on the top instead of hopping.
	var climb_staircase := entry_context.duplicate(true)
	climb_staircase["platforms"] = [
		{"left": 300.0, "right": 500.0, "y": 44.0, "handle": 8},
		{"left": 400.0, "right": 600.0, "y": -156.0, "handle": 9},
	]
	climb_staircase["walls"] = [
		{"x": 400.0, "top_y": 200.0, "bottom_y": 856.0, "side": 1, "handle": 9},
	]
	climb_staircase["foot_offset_x"] = 180.0
	climb_staircase["foot_offset_y"] = 356.0
	climb_staircase["hop_reach_px"] = 120.0
	climb_staircase["auto_hop_short_walls"] = true
	model.set_preserve_entry_position(true)
	model.reset(Vector2(120.0, 44.0))
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, climb_staircase)
	for i in range(20):
		model.tick(0.1, {"dir_x": 1, "dir_y": 0}, climb_staircase)
		if model.has_pending_attach():
			break
	_expect(model.has_pending_attach(), "a higher window beyond hop reach triggers a climb instead of a hop")
	model.finish_attach()
	_expect(model.subphase == ManualControlModelScript.WALL and model.wall_side == 1, "staircase climb clings to the higher window's face")
	for i in range(20):
		model.tick(0.5, {"dir_x": 0, "dir_y": -1}, climb_staircase)
		if model.has_pending_mount():
			break
	_expect(model.has_pending_mount(), "staircase climb mounts at the higher window's top")
	model.finish_mount()
	_expect(model.standing_plane_handle() == 9, "staircase climb mount stands on the higher window")
	# --- Double-tap S/down steps off a platform ---
	# queue_step_off detaches the grounded pet from the standing window and it falls
	# toward the nearest lower visible surface: a lower window's top if one is below,
	# else the floor. It is a no-op on the floor or while airborne.
	var stepoff_context := entry_context.duplicate(true)
	stepoff_context["platforms"] = [
		{"left": 645.0, "right": 755.0, "y": 44.0, "handle": 8},
	]
	stepoff_context["foot_offset_x"] = 180.0
	stepoff_context["foot_offset_y"] = 356.0
	model.set_preserve_entry_position(true)
	model.reset(Vector2(500.0, 44.0))
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, stepoff_context)
	_expect(model.subphase == ManualControlModelScript.GROUND and model.standing_plane_handle() == 8, "step-off test pet stands on the platform")
	model.queue_step_off()
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, stepoff_context)
	_expect(model.subphase == ManualControlModelScript.FALL, "queue_step_off detaches the grounded pet into a fall")
	model.queue_step_off()
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, stepoff_context)
	_expect(model.subphase == ManualControlModelScript.FALL, "queue_step_off while airborne is a no-op")
	for i in range(40):
		model.tick(0.1, {"dir_x": 0, "dir_y": 0}, stepoff_context)
		if model.subphase == ManualControlModelScript.GROUND:
			break
	_expect(model.subphase == ManualControlModelScript.GROUND and model.standing_plane_handle() == 0, "stepping off a platform with no lower window lands on the floor")
	_expect(is_equal_approx(model.position.y, 500.0), "step-off lands on the floor")
	# With a lower window below, the same step-off lands on its top instead.
	var stepoff_lower := stepoff_context.duplicate(true)
	stepoff_lower["platforms"] = [
		{"left": 645.0, "right": 755.0, "y": 44.0, "handle": 8},
		{"left": 600.0, "right": 700.0, "y": 200.0, "handle": 9},
	]
	model.set_preserve_entry_position(true)
	model.reset(Vector2(500.0, 44.0))
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, stepoff_lower)
	model.queue_step_off()
	for i in range(80):
		model.tick(0.1, {"dir_x": 0, "dir_y": 0}, stepoff_lower)
		if model.subphase == ManualControlModelScript.GROUND:
			break
	_expect(model.subphase == ManualControlModelScript.GROUND and model.standing_plane_handle() == 9, "stepping off with a lower window below lands on its top")
	_expect(is_equal_approx(model.position.y, 200.0), "step-off lands on the lower window's plane y")
	# --- FALL landing adopts the plane's process_id (regression) ---
	# Canceling flight (or stepping off) lands via the FALL branch. That landing must
	# adopt the plane's (handle, process_id) identity: a stale pid left standing fails
	# the live segment merge, makes _standing_plane_state() return {} and re-lands on
	# the same plane every grace window — a permanent stuck-on-the-window loop that
	# also never follows a dragged window. Test planes carry a real process_id to
	# expose it (the pid-less legacy planes above mask it with a 0 match).
	var fall_pid_context := entry_context.duplicate(true)
	fall_pid_context["platforms"] = [
		{"left": 645.0, "right": 755.0, "y": 44.0, "handle": 8, "process_id": 555},
		{"left": 600.0, "right": 700.0, "y": 200.0, "handle": 9, "process_id": 4321},
	]
	fall_pid_context["foot_offset_x"] = 180.0
	fall_pid_context["foot_offset_y"] = 356.0
	model.set_preserve_entry_position(true)
	model.reset(Vector2(500.0, 44.0))
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, fall_pid_context)
	_expect(model.standing_plane_handle() == 8 and model.standing_plane_pid() == 555, "pid regression pet stands on the upper plane with its pid")
	model.queue_step_off()
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, fall_pid_context)
	_expect(model.subphase == ManualControlModelScript.FALL, "pid regression step-off clears identity and falls")
	for i in range(80):
		model.tick(0.1, {"dir_x": 0, "dir_y": 0}, fall_pid_context)
		if model.subphase == ManualControlModelScript.GROUND:
			break
	_expect(model.subphase == ManualControlModelScript.GROUND and model.standing_plane_handle() == 9, "pid regression FALL landing stands on the lower window")
	_expect(model.standing_plane_pid() == 4321, "FALL landing adopts the plane's process_id (no stale pid)")
	# With the pid adopted the standing state persists; a stale pid would drop to
	# FALL and re-land on the same plane every grace window (a stuck loop).
	var pid_stays_grounded := true
	for i in range(60):
		model.tick(0.016, {"dir_x": 0, "dir_y": 0}, fall_pid_context)
		if model.subphase != ManualControlModelScript.GROUND:
			pid_stays_grounded = false
			break
	_expect(pid_stays_grounded, "pid regression pet stays standing (no stuck re-land loop)")
	# And the correct identity lets a dragged window carry the pet.
	var fall_follow := fall_pid_context.duplicate(true)
	fall_follow["live_platforms"] = [
		{"left": 700.0, "right": 800.0, "y": 200.0, "handle": 9, "process_id": 4321},
	]
	fall_follow["standing_plane_live_delta"] = 100.0
	model.tick(0.016, {"dir_x": 0, "dir_y": 0}, fall_follow)
	_expect(is_equal_approx(model.position.x, 600.0), "pid regression pet follows the lower window when dragged")

func _test_roam_planner() -> void:
	var screens: Array[Rect2] = [Rect2(0.0, 0.0, 800.0, 600.0), Rect2(800.0, 0.0, 800.0, 600.0)]
	var start := Vector2(400.0, 240.0)
	var pet_size := Vector2(360.0, 360.0)
	var legs := RoamPlannerScript.build_legs(start, pet_size, screens, "roam-seed-1")
	_expect(legs.size() >= 2 and legs.size() <= 4, "roam planner produces 2-4 legs")
	var previous := start
	for leg in legs:
		var from: Vector2 = leg.get("from", Vector2.ZERO)
		_expect(from.distance_to(previous) < 1.0, "roam legs chain from the previous target")
		previous = leg.get("to", from)
		var leg_type := str(leg.get("type", ""))
		_expect(leg_type in ["walk", "fly", "fly_drop"], "roam leg type is known")
		if leg.has("drop_at_progress") and leg.get("drop_at_progress", null) != null:
			_expect(leg_type == "fly_drop", "drop_at_progress only appears on fly_drop legs")
	var made_fly := false
	for leg in legs:
		if str(leg.get("type", "")) in ["fly", "fly_drop"]:
			made_fly = true
	_expect(made_fly, "roam path always contains a flight")
	var last_to: Vector2 = legs.back().get("to", Vector2.ZERO)
	var last_screen := _roam_screen_for_point(last_to, screens)
	_expect(absf(last_to.y - (last_screen.end.y - pet_size.y)) < 2.0, "last roam leg ends on a floor")
	var single_screens: Array[Rect2] = [screens[0]]
	var single := RoamPlannerScript.build_legs(start, pet_size, single_screens, "roam-seed-2")
	for leg in single:
		var to: Vector2 = leg.get("to", Vector2.ZERO)
		_expect(to.x >= 0.0 and to.x <= 800.0 - pet_size.x + 1.0, "single-screen roam legs stay in horizontal bounds")

func _test_ground_relocation_mode() -> void:
	# Same-tier relocation: jump and walk are both valid for a grounded floor→floor
	# move, chosen at random with the default 50/50 band.
	_expect(RoamPlannerScript.choose_ground_relocation_mode(true, true, 0.0) == "walk", "grounded same-screen roll 0 walks")
	_expect(RoamPlannerScript.choose_ground_relocation_mode(true, true, 0.49) == "walk", "grounded same-screen roll in walk band walks")
	_expect(RoamPlannerScript.choose_ground_relocation_mode(true, true, 0.5) == "jump", "roll exactly at the band edge jumps")
	_expect(RoamPlannerScript.choose_ground_relocation_mode(true, true, 0.99) == "jump", "grounded same-screen roll past the band jumps")
	# Walking is only possible grounded on the same screen; everything else jumps.
	_expect(RoamPlannerScript.choose_ground_relocation_mode(true, false, 0.0) == "jump", "cross-screen relocation always jumps")
	_expect(RoamPlannerScript.choose_ground_relocation_mode(false, true, 0.0) == "jump", "standing on a window cannot walk to the floor")
	_expect(RoamPlannerScript.choose_ground_relocation_mode(false, false, 0.1) == "jump", "airborne/off-screen relocation jumps")
	# A custom band is honored.
	_expect(RoamPlannerScript.choose_ground_relocation_mode(true, true, 0.2, 0.3) == "walk", "custom walk band 0.2 walks under 0.3")
	_expect(RoamPlannerScript.choose_ground_relocation_mode(true, true, 0.3, 0.3) == "jump", "custom walk band edge jumps")

func _roam_screen_for_point(point: Vector2, screens: Array[Rect2]) -> Rect2:
	for screen in screens:
		if screen.has_point(point):
			return screen
	return screens[0]

func _test_control_and_roam_state() -> void:
	var machine := PetStateMachine.new()
	machine.dispatch({"type": "CLIP_END"})
	_expect(machine.dispatch({"type": "MANUAL_CONTROL_START"}) == "manual_control", "manual control starts from idle")
	_expect(machine.dispatch({"type": "INTERACTION_END", "resume": "idle"}) == "idle", "manual control exits to resume")
	machine.dispatch({"type": "MANUAL_CONTROL_START"})
	_expect(machine.dispatch({"type": "POKE"}) == "poke_cheek", "poke interrupts manual control")
	machine.dispatch({"type": "MANUAL_CONTROL_START"})
	_expect(machine.dispatch({"type": "HEAD_PAT_START"}) == "head_pat", "head-pat interrupts manual control")
	machine.dispatch({"type": "MANUAL_CONTROL_START"})
	_expect(machine.dispatch({"type": "MENU_OPEN"}) == "menu_wait", "menu preempts manual control")
	machine.dispatch({"type": "INTERACTION_END", "resume": "idle"})
	machine.dispatch({"type": "MANUAL_CONTROL_START"})
	_expect(machine.dispatch({"type": "FULLSCREEN_ENTER"}) == "suspended", "fullscreen suspends manual control")
	machine.dispatch({"type": "FULLSCREEN_EXIT"})
	_expect(machine.dispatch({"type": "ROAM_WALK_START"}) == "roam_walk", "roam walk starts from idle")
	_expect(machine.dispatch({"type": "POKE"}) == "poke_cheek", "poke interrupts roam walk")
	machine.dispatch({"type": "INTERACTION_END", "resume": "idle"})
	_expect(machine.dispatch({"type": "ROAM_WALK_START"}) == "roam_walk", "roam walk re-enters")
	_expect(machine.dispatch({"type": "CLIP_END"}) == "idle", "roam walk ends to idle")
	_expect(machine.dispatch({"type": "WANDER", "needs_turn": false}) == "takeoff", "roam fly leg launches")
	# Dragged fling branching: slide / throw / fall.
	machine.dispatch({"type": "DRAG_START"})
	_expect(machine.dispatch({"type": "SLIDE_START"}) == "drag_slide", "dragged ground flick slides")
	_expect(machine.dispatch({"type": "SLIDE_END"}) == "idle", "slide ends to idle")
	machine.dispatch({"type": "DRAG_START"})
	_expect(machine.dispatch({"type": "THROW_START"}) == "drag_throw", "dragged air flick throws")
	_expect(machine.dispatch({"type": "ARRIVE"}) == "land", "throw lands")
	_expect(machine.dispatch({"type": "CLIP_END"}) == "idle", "throw landing returns idle")
	machine.dispatch({"type": "DRAG_START"})
	_expect(machine.dispatch({"type": "DRAG_END"}) == "drag_fall", "dragged normal release falls")
	# Wall climb: idle + WALL_CLIMB_START → wall_climb, wall_climb + CLIP_END → idle.
	machine.dispatch({"type": "RESET"})
	machine.dispatch({"type": "CLIP_END"})
	_expect(machine.dispatch({"type": "WALL_CLIMB_START"}) == "wall_climb", "wall climb starts from idle")
	_expect(machine.dispatch({"type": "CLIP_END"}) == "idle", "wall climb ends to idle")
	_expect(machine.dispatch({"type": "WALL_CLIMB_START"}) == "wall_climb", "wall climb re-enters")

func _test_window_platforms() -> void:
	var snapshots := [
		{"handle": 1, "process_id": 10, "rect": Rect2i(100, 100, 500, 400), "z_order": 0, "visible": true},
		{"handle": 2, "process_id": 20, "rect": Rect2i(0, 100, 800, 500), "z_order": 1, "visible": true},
		{"handle": 3, "process_id": 999, "rect": Rect2i(0, 300, 500, 400), "z_order": 2, "visible": true},
		{"handle": 4, "process_id": 30, "rect": Rect2i(0, 500, 400, 300), "z_order": 3, "visible": true, "minimized": true},
	]
	var platforms := WindowPlatformService.build_platforms(snapshots, 999, 160, 12)
	_expect(platforms.size() == 2, "window occlusion leaves two standable segments")
	_expect(platforms[0].handle == 1 and platforms[0].top_edge.size.x == 500, "front window keeps its complete top edge")
	_expect(platforms[1].handle == 2 and platforms[1].top_edge.position.x == 600, "covered lower edge is subtracted by z order")
	_expect(not WindowPlatformService.is_snapshot_eligible(snapshots[2], 999), "own-process windows are excluded")
	var nearby: Variant = WindowPlatformService.choose_nearby_platform(platforms[0], platforms, 1000.0, 500.0)
	_expect(nearby == platforms[1], "nearest different platform is selected")
	var tool_occlusion := [
		{"handle": 10, "process_id": 20, "rect": Rect2i(0, 50, 320, 100), "z_order": 0, "visible": true, "tool_window": true},
		{"handle": 11, "process_id": 21, "rect": Rect2i(0, 100, 700, 500), "z_order": 1, "visible": true},
	]
	var tool_platforms := WindowPlatformService.build_platforms(tool_occlusion, -1, 160, 12)
	_expect(tool_platforms.size() == 1 and tool_platforms[0].segment_left() == 320, "tool windows occlude lower ledges without becoming platforms")
	var tracker := WindowPlatformService.new()
	tracker.set_native_bridge(null)
	var ridden := WindowPlatform.from_snapshot(tool_occlusion[1], 0, 700)
	# The standing point (x=200) is covered by the tool window's top: under the
	# visible-geometry semantics the rider is reported occluded (window still valid,
	# no motion, no y-pin) and the caller's grace window decides the drop — the
	# full-edge fallback is gone.
	var occluded_track := tracker.track_platform(ridden, tool_occlusion, 200.0)
	_expect(not bool(occluded_track.get("lost", false)) and str(occluded_track.get("status", "")) == "occluded", "occluding the standing point reports an occluded rider, not a lost window")
	_expect((occluded_track.get("platform") as WindowPlatform).handle == 11, "an occluded rider keeps its current platform (no full-width rebuild)")
	# The actual drag-squeeze regression: the ridden window is dragged so it passes
	# under a front window covering the standing point. The rider is reported
	# occluded (drop after the caller's grace), not carried by a full top edge.
	var drag_occluded := tracker.track_platform(ridden, [
		{"handle": 9, "process_id": 30, "rect": Rect2i(0, 50, 900, 300), "z_order": 0, "visible": true},
		{"handle": 11, "process_id": 21, "rect": Rect2i(300, 100, 700, 500), "z_order": 1, "visible": true},
	], 400.0, 16.0)
	_expect(not bool(drag_occluded.get("lost", false)) and str(drag_occluded.get("status", "")) == "occluded", "a drag that keeps the standing point covered reports occluded, not a full-edge follow")
	_expect(Vector2(drag_occluded.get("delta", Vector2i.ZERO)) == Vector2(300.0, 0.0), "the occluded result still reports the window's drag delta for the grace/fall decision")
	# A standing point that stays visible while dragging keeps riding (regression
	# guard: occlusion is about the point, not the motion).
	var visible_drag := tracker.track_platform(ridden, [
		{"handle": 11, "process_id": 21, "rect": Rect2i(100, 100, 700, 500), "z_order": 0, "visible": true},
	], 350.0, 16.0)
	_expect(not bool(visible_drag.get("lost", false)) and str(visible_drag.get("status", "")) == "moved", "a visible standing point keeps riding a dragged window")
	# --- Live visible top segments: the per-frame standable surface ---
	# The standing window's live top is its fresh rect minus the cached front
	# occluders (same slab pass as the refresh), so the foot can only stand on what
	# is actually visible.
	var live_tracker := WindowPlatformService.new()
	live_tracker.set_native_bridge(null)
	var alone_live := [
		{"handle": 11, "process_id": 21, "rect": Rect2i(0, 100, 700, 500), "z_order": 0, "visible": true},
	]
	var live_planes := live_tracker.live_top_segment_planes(11, 21, 356.0, alone_live)
	_expect(live_planes.size() == 1 and is_equal_approx(float(live_planes[0].get("left", -1.0)), 0.0) and is_equal_approx(float(live_planes[0].get("right", -1.0)), 700.0), "a visible standing window yields one live top segment spanning its whole edge")
	_expect(is_equal_approx(float(live_planes[0].get("y", -1.0)), 100.0 - 356.0), "live segment y is in foot space (window top minus foot offset)")
	var covered_live := [
		{"handle": 9, "process_id": 30, "rect": Rect2i(0, 50, 900, 300), "z_order": 0, "visible": true},
		{"handle": 11, "process_id": 21, "rect": Rect2i(0, 100, 700, 500), "z_order": 1, "visible": true},
	]
	_expect(live_tracker.live_top_segment_planes(11, 21, 356.0, covered_live).is_empty(), "a front window covering the whole top edge leaves no live segment")
	var partly_live := [
		{"handle": 9, "process_id": 30, "rect": Rect2i(0, 50, 320, 300), "z_order": 0, "visible": true},
		{"handle": 11, "process_id": 21, "rect": Rect2i(0, 100, 700, 500), "z_order": 1, "visible": true},
	]
	var partly_planes := live_tracker.live_top_segment_planes(11, 21, 356.0, partly_live)
	_expect(partly_planes.size() == 1 and is_equal_approx(float(partly_planes[0].get("left", -1.0)), 320.0), "a partially covering front window leaves the uncovered top slab")
	# --- Live window-rect motion signal ---
	# A dragged window moves its rect center; a static one does not. The model gates
	# perch continuity on this signal, not on segment-center deltas (which occlusion
	# reshuffles pollute).
	var delta_tracker := WindowPlatformService.new()
	delta_tracker.set_native_bridge(null)
	delta_tracker._last_snapshots = [
		{"handle": 11, "process_id": 21, "rect": Rect2i(0, 100, 700, 500), "z_order": 1, "visible": true},
	]
	_expect(is_equal_approx(delta_tracker.live_rect_delta_x(11, [
		{"handle": 11, "process_id": 21, "rect": Rect2i(0, 100, 700, 500), "z_order": 1, "visible": true},
	]), 0.0), "a static window has zero live rect delta")
	_expect(is_equal_approx(delta_tracker.live_rect_delta_x(11, [
		{"handle": 11, "process_id": 21, "rect": Rect2i(300, 100, 700, 500), "z_order": 1, "visible": true},
	]), 300.0), "a dragged window reports its rect center delta")
	# --- Fix 1: a live-only window with no cached reference is NOT being dragged ---
	# When the standing window's handle exists in the live snapshots but was filtered
	# out of the last refresh (_last_snapshots), the old code subtracted the zero rect
	# center (0,0) and reported the live center (hundreds of px) as drag motion. The
	# model consumed that as window_moving and the drag hold pinned the pet mid-air
	# forever (两小窗交界卡死). A window with no cached reference must read as zero
	# motion: its top face is not being carried, so the model falls through the grace
	# instead of freezing.
	var live_only := WindowPlatformService.new()
	live_only.set_native_bridge(null)
	live_only._last_snapshots = []
	_expect(is_equal_approx(live_only.live_rect_delta_x(11, [
		{"handle": 11, "process_id": 21, "rect": Rect2i(300, 100, 700, 500), "z_order": 1, "visible": true},
	]), 0.0), "a live-only window with no cached snapshot reports zero motion (Fix 1)")
	# A cached snapshot belonging to another handle must not bleed into this delta.
	live_only._last_snapshots = [
		{"handle": 99, "process_id": 21, "rect": Rect2i(0, 100, 700, 500), "z_order": 1, "visible": true},
	]
	_expect(is_equal_approx(live_only.live_rect_delta_x(11, [
		{"handle": 11, "process_id": 21, "rect": Rect2i(300, 100, 700, 500), "z_order": 1, "visible": true},
	]), 0.0), "a cached snapshot for another handle still reads zero motion for the target (Fix 1)")
	# --- Fix 4: vertical drag reports Y motion so the model does not read it as static ---
	# live_rect_delta_x is X-only; a VERTICAL drag leaves it ~0, so the model used to
	# treat an upward-dragged window as STATIC and dropped the pet through the
	# occlusion grace the instant the top segment was sliced (小窗向上移动一段距离).
	# live_rect_delta_y mirrors the X axis so the window_moving gate sees the drag.
	_expect(is_equal_approx(delta_tracker.live_rect_delta_y(11, [
		{"handle": 11, "process_id": 21, "rect": Rect2i(0, 100, 700, 500), "z_order": 1, "visible": true},
	]), 0.0), "a static window has zero vertical live rect delta")
	# Rect2i(0, 0, 700, 500) center.y = 250 vs cached center.y = 350 -> -100 (moved up).
	_expect(is_equal_approx(delta_tracker.live_rect_delta_y(11, [
		{"handle": 11, "process_id": 21, "rect": Rect2i(0, 0, 700, 500), "z_order": 1, "visible": true},
	]), -100.0), "an upward-dragged window reports its vertical rect center delta")
	_expect(is_equal_approx(delta_tracker.live_rect_delta_y(11, [
		{"handle": 11, "process_id": 21, "rect": Rect2i(0, 200, 700, 500), "z_order": 1, "visible": true},
	]), 100.0), "a downward-dragged window reports a positive vertical delta")
	var live_only_y := WindowPlatformService.new()
	live_only_y.set_native_bridge(null)
	live_only_y._last_snapshots = []
	_expect(is_equal_approx(live_only_y.live_rect_delta_y(11, [
		{"handle": 11, "process_id": 21, "rect": Rect2i(0, 0, 700, 500), "z_order": 1, "visible": true},
	]), 0.0), "a live-only window with no cached snapshot reports zero vertical motion (Fix 4)")
	var reused_track := tracker.track_platform(ridden, [
		{"handle": 11, "process_id": 999, "rect": Rect2i(0, 100, 700, 500), "z_order": 0, "visible": true},
	], 400.0)
	_expect(bool(reused_track.get("lost", false)), "reused HWND with another process id is rejected")
	# A big rect delta across a slow tick is a continuous fast drag, not a
	# teleport: the rider must stay glued even when DWM's stale rect or a frame
	# hitch makes one tick cover hundreds of pixels. Only an instant reposition
	# far beyond any human drag speed drops the rider.
	var long_gap_drag := tracker.track_platform(ridden, [
		{"handle": 11, "process_id": 21, "rect": Rect2i(700, 100, 700, 500), "z_order": 0, "visible": true},
	], 400.0, 200.0)
	_expect(not bool(long_gap_drag.get("lost", false)), "a 700px drag over a 200ms tick gap still follows")
	var hard_flick := tracker.track_platform(ridden, [
		{"handle": 11, "process_id": 21, "rect": Rect2i(1500, 100, 700, 500), "z_order": 0, "visible": true},
	], 400.0, 16.0)
	_expect(not bool(hard_flick.get("lost", false)), "an 1500px flick over a 16ms tick follows (drag speed, not teleport)")
	var instant_jump := tracker.track_platform(ridden, [
		{"handle": 11, "process_id": 21, "rect": Rect2i(3200, 100, 700, 500), "z_order": 0, "visible": true},
	], 400.0, 16.0)
	_expect(bool(instant_jump.get("lost", false)) and str(instant_jump.get("reason", "")) == "teleported", "an instant reposition far beyond drag speed is a teleport")
	var native_service := WindowPlatformService.new()
	_expect(native_service.native_available(), "Windows test baseline loads the native GDExtension")
	var native_bridge: Variant = ClassDB.instantiate("WindowsWindowEnumerator")
	_expect(native_bridge != null and native_bridge.has_method("set_window_rect"), "native bridge exposes atomic position-and-size updates")
	native_service.capture_titles = false
	var native_snapshots := native_service.enumerate_snapshots(12)
	_expect(native_snapshots.size() <= 12, "native enumeration is capped at twelve relevant HWNDs")
	var titles_suppressed := true
	for snapshot in native_snapshots:
		if snapshot is Dictionary and not str(snapshot.get("title", "")).is_empty():
			titles_suppressed = false
	_expect(titles_suppressed, "disabling title awareness prevents native title collection")

## Pet-own-z occlusion threshold: only windows in FRONT of the pet (z < pet_z) or
## maximized ones occlude a standing point. A window behind the always-on-top pet
## renders under it and cannot cover its feet, so it must NOT drop the rider — this
## is the "flash to ground + roam" false-drop fix. -1 fallback keeps old behavior.
func _test_pet_z_occlusion_threshold() -> void:
	var tracker := WindowPlatformService.new()
	tracker.set_native_bridge(null)
	tracker._self_z_order = 50
	var ridden := WindowPlatform.from_snapshot(
		{"handle": 11, "process_id": 21, "rect": Rect2i(0, 100, 700, 500), "z_order": 100, "visible": true},
		0, 700)
	# 1. Normal window behind the pet (z=60 >= pet_z=50): the standing point stays.
	var behind := tracker.track_platform(ridden, [
		{"handle": 9, "process_id": 30, "rect": Rect2i(0, 50, 700, 300), "z_order": 60, "visible": true},
		{"handle": 11, "process_id": 21, "rect": Rect2i(0, 100, 700, 500), "z_order": 100, "visible": true},
	], 300.0)
	_expect(not bool(behind.get("lost", false)) and str(behind.get("status", "")) != "occluded", "a normal window behind the pet does not occlude the standing point")
	# 2. Window in front of the pet (z=40 < pet_z=50): still occludes -> occluded.
	var in_front := tracker.track_platform(ridden, [
		{"handle": 9, "process_id": 30, "rect": Rect2i(0, 50, 700, 300), "z_order": 40, "visible": true},
		{"handle": 11, "process_id": 21, "rect": Rect2i(0, 100, 700, 500), "z_order": 100, "visible": true},
	], 300.0)
	_expect(not bool(in_front.get("lost", false)) and str(in_front.get("status", "")) == "occluded", "a window in front of the pet still occludes the standing point")
	# 3. Maximized window behind the pet (z=60, maximized): the user maximizes to
	# focus, so the pet yields — still occluded.
	var maximized := tracker.track_platform(ridden, [
		{"handle": 9, "process_id": 30, "rect": Rect2i(0, 50, 700, 300), "z_order": 60, "visible": true, "maximized": true},
		{"handle": 11, "process_id": 21, "rect": Rect2i(0, 100, 700, 500), "z_order": 100, "visible": true},
	], 300.0)
	_expect(not bool(maximized.get("lost", false)) and str(maximized.get("status", "")) == "occluded", "a maximized window behind the pet still occludes (maximized exception)")
	# 4. Tool/owned window behind the pet (the `platforms=0 bodies=1` log signature):
	# tool windows are ineligible as sources but were occluders under the old standing
	# window z threshold; behind the pet they no longer trigger a false drop.
	var tool_behind := tracker.track_platform(ridden, [
		{"handle": 9, "process_id": 30, "rect": Rect2i(0, 50, 700, 300), "z_order": 60, "visible": true, "tool_window": true},
		{"handle": 11, "process_id": 21, "rect": Rect2i(0, 100, 700, 500), "z_order": 100, "visible": true},
	], 300.0)
	_expect(not bool(tool_behind.get("lost", false)) and str(tool_behind.get("status", "")) != "occluded", "a tool window behind the pet does not occlude the standing point (false-drop signature)")
	# 5. live_top_segment_planes: a behind-pet normal window keeps the plane; a
	# behind-pet maximized window removes it.
	var live_tracker := WindowPlatformService.new()
	live_tracker.set_native_bridge(null)
	live_tracker._self_z_order = 50
	var standing := {"handle": 11, "process_id": 21, "rect": Rect2i(0, 100, 700, 500), "z_order": 100, "visible": true}
	var live_planes := live_tracker.live_top_segment_planes(11, 21, 356.0, [
		{"handle": 9, "process_id": 30, "rect": Rect2i(0, 50, 700, 300), "z_order": 60, "visible": true},
		standing,
	])
	_expect(live_planes.size() == 1 and is_equal_approx(float(live_planes[0].get("left", -1.0)), 0.0) and is_equal_approx(float(live_planes[0].get("right", -1.0)), 700.0), "a behind-pet window leaves the live top segment intact")
	var live_maximized := live_tracker.live_top_segment_planes(11, 21, 356.0, [
		{"handle": 9, "process_id": 30, "rect": Rect2i(0, 50, 700, 300), "z_order": 60, "visible": true, "maximized": true},
		standing,
	])
	_expect(live_maximized.is_empty(), "a behind-pet maximized window removes the live top segment")
	# 6. Fallback: _self_z_order = -1 (no bridge z data) keeps the old full-occlusion
	# behavior — the standing point covered by any front window is still occluded.
	var fallback := WindowPlatformService.new()
	fallback.set_native_bridge(null)
	var fallback_track := fallback.track_platform(ridden, [
		{"handle": 9, "process_id": 30, "rect": Rect2i(0, 50, 700, 300), "z_order": 60, "visible": true},
		{"handle": 11, "process_id": 21, "rect": Rect2i(0, 100, 700, 500), "z_order": 100, "visible": true},
	], 300.0)
	_expect(not bool(fallback_track.get("lost", false)) and str(fallback_track.get("status", "")) == "occluded", "without pet z the old full-occlusion behavior is preserved")

func _test_icon_visibility_and_reach() -> void:
	# _occluding_rects / _is_point_obscured / _is_icon_visible on a bare pet
	# instance whose window service is stubbed with synthetic snapshots. The real
	# static filter (is_foreground_snapshot_valid) and the pet-z occlusion rule
	# both apply, matching the service-level tests above.
	var pet := preload("res://scripts/main.gd").new()
	var fake := _FakeWindowSnapshotService.new()
	pet.window_platform_service = fake
	# 1. A foreground window (z below the pet's always-on-top) covers the point.
	fake.snapshots = [_window_snapshot(101, 1, Rect2i(0, 0, 200, 200))]
	fake.self_z = 2
	_expect(pet._is_point_obscured(Vector2(100, 100)), "icon covered by a foreground window is obscured")
	_expect(not pet._is_point_obscured(Vector2(500, 500)), "icon outside every window is visible")
	# 2. A window behind the pet (z >= pet z, not maximized) does not occlude.
	fake.snapshots = [_window_snapshot(102, 5, Rect2i(0, 0, 200, 200))]
	fake.self_z = 3
	_expect(not pet._is_point_obscured(Vector2(50, 50)), "window behind the pet's z-order does not occlude")
	# 3. A maximized window always occludes, even behind the pet's z-order.
	fake.snapshots = [_window_snapshot(103, 5, Rect2i(0, 0, 200, 200), true)]
	fake.self_z = 3
	_expect(pet._is_point_obscured(Vector2(50, 50)), "a maximized window occludes even above the pet's z-order")
	_expect(not pet._is_icon_visible(Vector2(50, 50)), "an icon under a maximized window is not visible (visibility gate)")
	# 4. Reach band around the window origin + hand anchor.
	pet.position = Vector2(1000, 700)
	_expect(pet._icon_reachable_from_position(pet.position, Vector2(1000, 730)), "icon at hand height is within reach")
	_expect(not pet._icon_reachable_from_position(pet.position, Vector2(1000, 520)), "icon high above the hand is out of reach")
	_expect(not pet._icon_reachable_from_position(pet.position, Vector2(1000, 810)), "icon far below the hand is out of reach")
	_expect(pet._icon_reachable_from_position(pet.position, Vector2(1180, 700)), "icon within the body's horizontal slack is reachable")
	_expect(not pet._icon_reachable_from_position(pet.position, Vector2(1600, 700)), "icon far to the side is out of reach")
	# 5. Mode selection rolls among viable modes and rejects an empty set.
	var modes := [
		{"mode": "walk", "at": Vector2.ZERO},
		{"mode": "fly", "at": Vector2.ZERO},
	]
	var picked: Dictionary = {}
	for _i in range(50):
		picked = pet._pick_approach_mode(modes)
	_expect(str(picked.get("mode", "")) in ["walk", "fly"], "mode selection returns a viable mode")
	_expect(pet._pick_approach_mode([]).is_empty(), "no viable modes selects none")
	pet.free()

func _window_snapshot(handle: int, z_order: int, rect: Rect2i, maximized := false) -> Dictionary:
	return {
		"handle": handle,
		"process_id": 99000 + handle,
		"visible": true,
		"minimized": false,
		"cloaked": false,
		"shell_window": false,
		"class_name": "",
		"z_order": z_order,
		"maximized": maximized,
		"rect": rect,
	}

class _FakeWindowSnapshotService extends WindowPlatformService:
	## Duck-typed window service for the visibility predicates: the pet instance
	## holds it in a WindowPlatformService-typed field, so the fake subclasses it
	## and only overrides the snapshot/z getters the predicates read.
	var snapshots: Array = []
	var self_z := 0
	var self_pid := 90001
	func last_snapshots() -> Array:
		return snapshots
	func self_z_order() -> int:
		return self_z
	func self_process_id() -> int:
		return self_pid

func _test_window_bodies() -> void:
	var snapshots := [
		{"handle": 1, "process_id": 10, "rect": Rect2i(100, 100, 500, 400), "z_order": 0, "visible": true},
		{"handle": 2, "process_id": 20, "rect": Rect2i(0, 100, 800, 500), "z_order": 1, "visible": true},
		{"handle": 3, "process_id": 999, "rect": Rect2i(0, 300, 500, 400), "z_order": 2, "visible": true},
		{"handle": 4, "process_id": 30, "rect": Rect2i(0, 500, 400, 300), "z_order": 3, "visible": true, "minimized": true},
	]
	var bodies := WindowPlatformService.build_bodies(snapshots, 999, 160, 12)
	_expect(bodies.size() == 2, "own-process and minimized windows contribute no body")
	var w1: WindowBody = bodies[0]
	var w2: WindowBody = bodies[1]
	_expect(w1.handle == 1 and w1.fragments.size() == 1 and w1.fragments[0] == Rect2i(100, 100, 500, 400), "front window keeps its full visible body")
	_expect(w1.top_segments.size() == 1 and w1.top_segments[0].position == Vector2i(100, 100) and w1.top_segments[0].end.x == 600, "front window top segment spans its whole top edge")
	# W2 is occluded on the left by W1: the visible body is the right slab plus the
	# strip below the occluder (the 100px-wide left slab is below min_width and dropped).
	_expect(w2.handle == 2 and w2.fragments.size() == 2, "covered window exposes right slab and below-occluder strip")
	var w2_has_right_slab := false
	var w2_has_bottom_band := false
	for fragment in w2.fragments:
		if fragment == Rect2i(600, 100, 200, 400):
			w2_has_right_slab = true
		if fragment == Rect2i(0, 500, 800, 100):
			w2_has_bottom_band = true
	_expect(w2_has_right_slab and w2_has_bottom_band, "occlusion slab split is exact")
	# The visible top segment matches the platform's top-edge interval exactly.
	_expect(w2.top_segments.size() == 1 and w2.top_segments[0].position.x == 600 and w2.top_segments[0].end.x == 800, "body top segment matches the platform segment range")
	# Two fragments expose four vertical walls (each side of each fragment).
	var edges := w1.fragment_wall_edges()
	_expect(edges.size() == 2, "single fragment exposes two walls")
	_expect(edges[0].get("x") == 100 and edges[0].get("side") == 1, "left wall sits on the fragment left edge and blocks +x motion")
	_expect(edges[1].get("x") == 600 and edges[1].get("side") == -1, "right wall sits on the fragment right edge and blocks -x motion")
	_expect(int(edges[0].get("process_id", -1)) == 10 and int(edges[1].get("process_id", -1)) == 10, "wall edges carry the window's process id")
	_expect(w2.fragment_wall_edges().size() == 4, "occluded window exposes four visible walls")
	var planes := w2.standable_planes(170.0)
	_expect(planes.size() == 1 and is_equal_approx(float(planes[0].get("y", -1.0)), -70.0) and float(planes[0].get("left", -1.0)) == 600.0 and float(planes[0].get("right", -1.0)) == 800.0, "standable plane offsets the foot above the window top")
	_expect(int(planes[0].get("process_id", -1)) == 20, "standable planes carry the window's process id")
	# A fully occluded window yields no body at all.
	var stacked := [
		{"handle": 20, "process_id": 30, "rect": Rect2i(0, 0, 1000, 800), "z_order": 0, "visible": true},
		{"handle": 21, "process_id": 31, "rect": Rect2i(100, 100, 200, 200), "z_order": 1, "visible": true},
	]
	var stacked_bodies := WindowPlatformService.build_bodies(stacked, -1, 160, 12)
	_expect(stacked_bodies.size() == 1 and stacked_bodies[0].handle == 20, "fully occluded window contributes no body")
	# The size cap excludes oversized windows from both platforms and bodies.
	var cap_snapshots := [
		{"handle": 30, "process_id": 40, "rect": Rect2i(0, 0, 1600, 1000), "z_order": 0, "visible": true},
		{"handle": 31, "process_id": 41, "rect": Rect2i(1650, 50, 200, 200), "z_order": 1, "visible": true},
	]
	var work_area := Rect2i(0, 0, 1920, 1080)
	var capped_bodies := WindowPlatformService.build_bodies(cap_snapshots, -1, 160, 12, work_area, 0.7)
	_expect(capped_bodies.size() == 1 and capped_bodies[0].handle == 31, "window larger than 70% of the work area is excluded from collision")
	var capped_platforms := WindowPlatformService.build_platforms(cap_snapshots, -1, 160, 12, false, 0.7, work_area)
	_expect(capped_platforms.size() == 1 and capped_platforms[0].handle == 31, "oversized window is excluded from platforms too for consistency")
	# The collision toggle independently empties bodies while platforms survive.
	var disabled_bodies := WindowPlatformService.build_bodies(snapshots, 999, 160, 12, Rect2i(), 0.0, false)
	_expect(disabled_bodies.is_empty(), "disabled collision toggle yields no bodies")
	var service := WindowPlatformService.new()
	# The fullscreen scenario: a fullscreen window (area ratio > 0.7) excludes
	# ITSELF as a platform but still occludes — so two small windows covered by it
	# lose their top edges entirely and NO standable surface remains.
	var fullscreen_snapshots := [
		{"handle": 81, "process_id": 91, "rect": Rect2i(0, 0, 1920, 1080), "z_order": 0, "visible": true},
		{"handle": 82, "process_id": 92, "rect": Rect2i(100, 100, 400, 300), "z_order": 1, "visible": true},
		{"handle": 83, "process_id": 93, "rect": Rect2i(600, 100, 400, 300), "z_order": 1, "visible": true},
	]
	var fs_platforms := WindowPlatformService.build_platforms(fullscreen_snapshots, -1, 160, 12, false, 0.7, Rect2i(0, 0, 1920, 1080))
	_expect(fs_platforms.is_empty(), "a fullscreen window occludes every other top edge (no standable planes)")
	# Transient windows: a freshly-appeared (< min_age) window's top is not a
	# standable plane; occlusion and walls are unaffected by this gate.
	var transient_planes := [
		{"left": 100.0, "right": 300.0, "y": 44.0, "handle": 90},
		{"left": 400.0, "right": 600.0, "y": 44.0, "handle": 91},
	]
	var gated := WindowPlatformService.gate_transient_planes(transient_planes, {90: 1000.0, 91: 3000.0}, 4000.0, 2000.0)
	_expect(gated.size() == 1 and int((gated[0] as Dictionary).get("handle", 0)) == 90, "a window present for less than min_age is excluded from the standing list")
	_expect(WindowPlatformService.gate_transient_planes(transient_planes, {}, 4000.0, 2000.0).is_empty(), "an unobserved window is treated as brand new (excluded)")
	# live_wall_edge must use the fragment-wall edge convention (side=+1 left face,
	# side=-1 right face): feeding the opposite edge would park the pet on the far
	# side of the window — the "teleport to the other side" regression.
	var climb_snapshots := [
		{"handle": 70, "process_id": 90, "rect": Rect2i(500, 300, 120, 200), "z_order": 0, "visible": true},
	]
	var left_edge := service.live_wall_edge(70, 90, 1, climb_snapshots)
	_expect(is_equal_approx(float(left_edge.get("x", -1.0)), 500.0), "live_wall_edge side=+1 reports the window's left face")
	_expect(is_equal_approx(float(left_edge.get("bottom_y", -1.0)), 500.0), "live_wall_edge carries the window's vertical extent")
	var right_edge := service.live_wall_edge(70, 90, -1, climb_snapshots)
	_expect(is_equal_approx(float(right_edge.get("x", -1.0)), 620.0), "live_wall_edge side=-1 reports the window's right face")
	_expect(int(right_edge.get("process_id", -1)) == 90, "live_wall_edge carries the window identity")
	_expect(service.live_wall_edge(999, 999, 1, climb_snapshots).is_empty(), "live_wall_edge returns {} for a missing window")

func _test_n_way_occlusion() -> void:
	# n-way chain: three windows, each occluded by the one in front. The middle
	# window is split by the front strip into two visible fragments and therefore
	# two top-edge segments, so the geometry covers an n-polygon overlap in a plane.
	var chain := [
		{"handle": 1, "process_id": 10, "rect": Rect2i(300, 0, 100, 500), "z_order": 0, "visible": true},
		{"handle": 2, "process_id": 20, "rect": Rect2i(0, 0, 800, 500), "z_order": 1, "visible": true},
		{"handle": 3, "process_id": 30, "rect": Rect2i(900, 0, 200, 500), "z_order": 2, "visible": true},
	]
	var chain_entries := WindowPlatformService.compute_visible_fragments(chain, -1, 160, 12)
	_expect(chain_entries.size() == 3, "n-way chain yields one entry per eligible window")
	_expect((chain_entries[0].get("top_segments", []) as Array).size() == 1, "front window keeps a single top segment")
	var middle_top: Array = chain_entries[1].get("top_segments", [])
	_expect(middle_top.size() == 2, "middle window is split into two top segments")
	_expect(
		(middle_top[0] as Rect2i) == Rect2i(0, 0, 300, 500) and (middle_top[1] as Rect2i) == Rect2i(400, 0, 400, 500),
		"middle window's split top segments match the visible intervals"
	)
	_expect((chain_entries[2].get("top_segments", []) as Array).size() == 1, "back window keeps its full top segment")
	var chain_platforms := WindowPlatformService.build_platforms(chain, -1, 160, 12)
	_expect(chain_platforms.size() == 4, "n-way chain yields four standable platforms")
	var middle_segment_lefts: Array[int] = []
	for platform in chain_platforms:
		if platform.handle == 2:
			middle_segment_lefts.append(platform.segment_left())
	middle_segment_lefts.sort()
	_expect(middle_segment_lefts == [0, 400], "middle window's platforms span both visible intervals")
	var chain_bodies := WindowPlatformService.build_bodies(chain, -1, 160, 12)
	_expect(chain_bodies.size() == 3, "n-way chain yields three collision bodies")
	for body in chain_bodies:
		if body.handle == 2:
			_expect(body.fragments.size() == 2 and body.fragment_wall_edges().size() == 4, "split window exposes two fragments and four walls")
	# Order independence: the occlusion pass sorts by z_order, so a shuffled input
	# array yields the same per-window visible area (rect \ union of occluders).
	var reversed_chain := []
	for index in range(chain.size() - 1, -1, -1):
		reversed_chain.append(chain[index])
	for handle in [1, 2, 3]:
		var ordered_area := _fragment_area_sum(chain_entries, handle)
		var shuffled_area := _fragment_area_sum(WindowPlatformService.compute_visible_fragments(reversed_chain, -1, 160, 12), handle)
		_expect(ordered_area == shuffled_area and ordered_area > 0, "visible area is order-independent for window %d" % handle)
	# Hole: a small front window fully inside a larger back window splits the back
	# window into bands; the top edge cracks into left-of-hole and right-of-hole
	# segments and the hole's vertical sides become inner walls.
	var hole := [
		{"handle": 2, "process_id": 20, "rect": Rect2i(300, 100, 200, 100), "z_order": 0, "visible": true},
		{"handle": 1, "process_id": 10, "rect": Rect2i(100, 100, 700, 400), "z_order": 1, "visible": true},
	]
	var hole_entries := WindowPlatformService.compute_visible_fragments(hole, -1, 160, 12)
	var back: Dictionary = hole_entries[1]
	var back_top: Array = back.get("top_segments", [])
	_expect(back_top.size() == 2, "a window with a hole in its top edge cracks into two top segments")
	_expect(
		(back_top[0] as Rect2i) == Rect2i(100, 100, 200, 100) and (back_top[1] as Rect2i) == Rect2i(500, 100, 300, 100),
		"hole window's top segments are left-of-hole and right-of-hole"
	)
	_expect((back.get("fragments", []) as Array).size() == 3, "hole window breaks into three visible fragments")
	var hole_platforms := WindowPlatformService.build_platforms(hole, -1, 160, 12)
	_expect(hole_platforms.size() == 3, "the back window's two segments plus the hole window itself yield three platforms")
	var hole_body: WindowBody = null
	for body in WindowPlatformService.build_bodies(hole, -1, 160, 12):
		if body.handle == 1:
			hole_body = body
	_expect(hole_body != null, "the back window still contributes a collision body")
	var hole_has_cave_walls := false
	var hole_has_bottom_band := false
	for edge in hole_body.fragment_wall_edges():
		if (float(edge.get("x", 0.0)) == 300.0 and int(edge.get("side", 0)) == -1) \
			or (float(edge.get("x", 0.0)) == 500.0 and int(edge.get("side", 0)) == 1):
			hole_has_cave_walls = true
	for fragment in hole_body.fragments:
		if fragment == Rect2i(100, 200, 700, 300):
			hole_has_bottom_band = true
	_expect(hole_has_cave_walls, "the hole's vertical sides become inner walls")
	_expect(hole_has_bottom_band, "the band below the hole stays solid")
	# No top edge, only walls: a window whose top edge is fully covered still
	# contributes a collision body (walls) but no standable platform.
	var no_top := [
		{"handle": 1, "process_id": 10, "rect": Rect2i(0, 0, 800, 200), "z_order": 0, "visible": true},
		{"handle": 2, "process_id": 20, "rect": Rect2i(0, 0, 800, 500), "z_order": 1, "visible": true},
	]
	var no_top_bodies := WindowPlatformService.build_bodies(no_top, -1, 160, 12)
	_expect(no_top_bodies.size() == 2, "a window with its top edge fully covered still has a body")
	var no_top_platforms := WindowPlatformService.build_platforms(no_top, -1, 160, 12)
	_expect(no_top_platforms.size() == 1 and no_top_platforms[0].handle == 1, "a window with its top edge fully covered yields no platform")
	for body in no_top_bodies:
		if body.handle == 2:
			_expect(body.fragments.size() == 1 and (body.fragments[0] as Rect2i) == Rect2i(0, 200, 800, 300), "the covered window's visible body is the band below the occluder")
	# Sliver semantics: a window left with only a sub-minimum-width visible slit is
	# dropped from both bodies and platforms — the slit is passable.
	var sliver := [
		{"handle": 1, "process_id": 10, "rect": Rect2i(100, 0, 800, 500), "z_order": 0, "visible": true},
		{"handle": 2, "process_id": 20, "rect": Rect2i(0, 0, 900, 500), "z_order": 1, "visible": true},
	]
	_expect(WindowPlatformService.build_bodies(sliver, -1, 160, 12).size() == 1, "a sub-minimum-width visible slit contributes no body")
	_expect(WindowPlatformService.build_platforms(sliver, -1, 160, 12).size() == 1, "a sub-minimum-width visible slit contributes no platform")
	var wide_sliver_bodies := WindowPlatformService.build_bodies(sliver, -1, 1, 12)
	_expect(wide_sliver_bodies.size() == 2 and (wide_sliver_bodies[1].fragments[0] as Rect2i) == Rect2i(0, 0, 100, 500), "the same slit survives with a wider minimum width, confirming the width threshold is what drops it")

func _fragment_area_sum(entries: Array, handle: int) -> int:
	var total := 0
	for entry in entries:
		if not entry is Dictionary:
			continue
		var snapshot: Dictionary = (entry as Dictionary).get("snapshot", {})
		if int(snapshot.get("handle", 0)) != handle:
			continue
		for fragment in (entry as Dictionary).get("fragments", []):
			if fragment is Rect2i:
				total += (fragment as Rect2i).size.x * (fragment as Rect2i).size.y
	return total

func _test_wall_resolver() -> void:
	var R := PetWallResolverScript
	# The collision body is foot-anchored and rises PET_COLLISION_SIZE.y above the feet.
	var body := R.collision_rect(Vector2(400.0, 800.0))
	_expect(body == Rect2(345.0, 630.0, 110.0, 170.0), "collision rect anchors the feet at the box bottom-center")
	# Walking right into a window's left face: side=+1 matches dx=+1 and blocks.
	var walls := [
		{"x": 600.0, "top_y": 300.0, "bottom_y": 800.0, "side": 1, "handle": 1},
	]
	var blocked := R.find_blocking_wall(Vector2(400.0, 800.0), Vector2(620.0, 800.0), walls, 800.0)
	_expect(int(blocked.get("handle", 0)) == 1 and not bool(blocked.get("short", true)), "rightward walk into a tall wall finds the wall and is not short")
	# A wall entry with process_id passes the identity through to the caller.
	var pid_walls := [
		{"x": 600.0, "top_y": 300.0, "bottom_y": 800.0, "side": 1, "handle": 1, "process_id": 4321},
	]
	var pid_hit := R.find_blocking_wall(Vector2(400.0, 800.0), Vector2(620.0, 800.0), pid_walls, 800.0)
	_expect(int(pid_hit.get("process_id", -1)) == 4321, "blocking wall passes the window's process id through")
	# A missing pid on the wall entry reads as 0 for legacy callers.
	var legacy_hit := R.find_blocking_wall(Vector2(400.0, 800.0), Vector2(620.0, 800.0), walls, 800.0)
	_expect(int(legacy_hit.get("process_id", -1)) == 0, "a wall without a process id defaults to 0")
	var resolved := R.resolve_horizontal(Vector2(400.0, 800.0), Vector2(620.0, 800.0), walls, 800.0)
	_expect(is_equal_approx((resolved.get("position", Vector2()) as Vector2).x, 545.0), "rightward walk parks the foot flush against the wall face")
	# Walking left into a window's right face: side=-1 matches dx=-1 and blocks.
	var left_walls := [
		{"x": 200.0, "top_y": 300.0, "bottom_y": 800.0, "side": -1, "handle": 2},
	]
	var left_resolved := R.resolve_horizontal(Vector2(400.0, 800.0), Vector2(100.0, 800.0), left_walls, 800.0)
	_expect(is_equal_approx((left_resolved.get("position", Vector2()) as Vector2).x, 255.0), "leftward walk parks the foot flush against the wall face")
	# A window raised above the pet's head is walked under: its bottom stays above body_top.
	var raised := [
		{"x": 600.0, "top_y": 200.0, "bottom_y": 500.0, "side": 1, "handle": 3},
	]
	var under := R.resolve_horizontal(Vector2(400.0, 800.0), Vector2(650.0, 800.0), raised, 800.0)
	_expect(is_equal_approx((under.get("position", Vector2()) as Vector2).x, 650.0) and (under.get("wall", {}) as Dictionary).is_empty(), "a raised window is walked under")
	# Short-wall threshold flips within WALL_HOP_REACH_PX of the floor.
	var short_walls := [
		{"x": 500.0, "top_y": 700.0, "bottom_y": 800.0, "side": 1, "handle": 4},
		{"x": 500.0, "top_y": 500.0, "bottom_y": 800.0, "side": 1, "handle": 5},
	]
	var short_hit := R.find_blocking_wall(Vector2(400.0, 800.0), Vector2(520.0, 800.0), [short_walls[0]], 800.0)
	_expect(int(short_hit.get("handle", 0)) == 4 and bool(short_hit.get("short", false)), "a wall within hop reach is flagged short")
	var tall_hit := R.find_blocking_wall(Vector2(400.0, 800.0), Vector2(520.0, 800.0), [short_walls[1]], 800.0)
	_expect(int(tall_hit.get("handle", 0)) == 5 and not bool(tall_hit.get("short", true)), "a taller wall is not flagged short")
	# Moving away, moving in the opposite direction, or standing still is never blocked.
	var away := R.resolve_horizontal(Vector2(620.0, 800.0), Vector2(400.0, 800.0), walls, 800.0)
	_expect(is_equal_approx((away.get("position", Vector2()) as Vector2).x, 400.0) and (away.get("wall", {}) as Dictionary).is_empty(), "moving away from a wall is not blocked")
	var stationary := R.find_blocking_wall(Vector2(400.0, 800.0), Vector2(400.0, 800.0), walls, 800.0)
	_expect(stationary.is_empty(), "standing still never hits a wall")
	_expect(R.is_blocked(Vector2(400.0, 800.0), Vector2(620.0, 800.0), walls, 800.0), "is_blocked reports the crossing")
	_expect(not R.is_blocked(Vector2(400.0, 800.0), Vector2(620.0, 800.0), [], 800.0), "an empty wall set never blocks")

func _test_window_event_debounce() -> void:
	var debouncer := WindowEventDebouncerScript.new()
	_expect(debouncer.poll(100.0) == INF, "no bridge never schedules a refresh")
	var bridge := FakeEventBridge.new()
	debouncer.set_bridge(bridge)
	_expect(debouncer.poll(100.0) == INF, "a clean bridge does not schedule a refresh")
	# First dirty event schedules a refresh at now + debounce.
	bridge.dirty_value = true
	bridge.handle_value = 0
	_expect(is_equal_approx(debouncer.poll(100.0), 180.0), "a dirty event schedules the debounced refresh")
	# The pending deadline is sticky: a drag flood keeps the original deadline.
	bridge.dirty_value = true
	_expect(is_equal_approx(debouncer.poll(110.0), 180.0), "a second dirty event keeps the original deadline")
	bridge.dirty_value = false
	_expect(is_equal_approx(debouncer.poll(120.0), 180.0), "a clean poll still reports the pending deadline")
	# Acknowledging after the refresh clears the sticky deadline.
	debouncer.acknowledge()
	_expect(debouncer.poll(200.0) == INF, "acknowledging clears the pending deadline")
	# Ridden-handle events are skipped (the 33ms platform-track loop covers them).
	debouncer.set_ridden_handle(5)
	bridge.dirty_value = true
	bridge.handle_value = 5
	_expect(debouncer.poll(300.0) == INF, "events for the ridden window are skipped")
	bridge.dirty_value = true
	bridge.handle_value = 7
	_expect(is_equal_approx(debouncer.poll(300.0), 380.0), "a non-ridden window event schedules a refresh")
	debouncer.acknowledge()
	debouncer.set_ridden_handle(0)
	# start/stop forward to the bridge when present.
	debouncer.start_event_hook()
	debouncer.stop_event_hook()
	_expect(bridge.start_calls == 1 and bridge.stop_calls == 1, "start/stop forward to the native bridge")
	# Native smoke: the real bridge exposes the hook API (existence only, no hook start).
	var native_bridge: Variant = ClassDB.instantiate("WindowsWindowEnumerator")
	_expect(
		native_bridge != null
		and native_bridge.has_method("start_event_hook")
		and native_bridge.has_method("stop_event_hook")
		and native_bridge.has_method("is_event_hook_active")
		and native_bridge.has_method("consume_dirty_flag")
		and native_bridge.has_method("get_dirty_handle")
		and native_bridge.has_method("set_event_hook_tracked_handles"),
		"native bridge exposes the event-hook API"
	)
	_expect(native_bridge.has_method("get_self_window_z_order"), "native bridge exposes the pet's own z-order")


class FakeEventBridge:
	extends RefCounted
	var dirty_value := false
	var handle_value := 0
	var start_calls := 0
	var stop_calls := 0
	func consume_dirty_flag() -> bool:
		var value := dirty_value
		dirty_value = false
		return value
	func get_dirty_handle() -> int:
		return handle_value
	func get_self_window_z_order() -> int:
		return -1
	func start_event_hook() -> void:
		start_calls += 1
	func stop_event_hook() -> void:
		stop_calls += 1
	func set_event_hook_tracked_handles(handles: Array) -> void:
		pass


func _test_ride_feedback() -> void:
	var ctrl := RideFeedbackControllerScript.new()
	# The first observation only primes the controller.
	var first := ctrl.update(1000.0, Rect2i(100, 200, 400, 300), Rect2i(100, 200, 400, 300), 300.0, 200.0, 500.0)
	_expect(first.is_empty(), "first observation only primes the ride feedback")
	# Moving the window >2px starts a session and fires start_move, not a wobble.
	var events := ctrl.update(1100.0, Rect2i(100, 200, 400, 300), Rect2i(150, 200, 400, 300), 350.0, 250.0, 550.0)
	_expect(_has_kind(events, "start_move"), "a ridden window displacement reacts once")
	_expect(not _has_kind(events, "wobble"), "a slow displacement is not a wobble")
	# A fast drag sustained past the threshold wobbles.
	events = ctrl.update(1300.0, Rect2i(150, 200, 400, 300), Rect2i(300, 200, 400, 300), 500.0, 250.0, 550.0)
	_expect(_has_kind(events, "wobble"), "a fast sustained drag wobbles")
	# Stopping starts the settle silence; the settle event waits for 1500ms.
	events = ctrl.update(1700.0, Rect2i(300, 200, 400, 300), Rect2i(300, 200, 400, 300), 500.0, 250.0, 550.0)
	_expect(not _has_kind(events, "settle"), "settle waits for the silence window")
	events = ctrl.update(3300.0, Rect2i(300, 200, 400, 300), Rect2i(300, 200, 400, 300), 500.0, 250.0, 550.0)
	_expect(_has_kind(events, "settle"), "a quiet window settles and clears the session")
	# A new drag session inside the 10s cooldown does not re-react.
	events = ctrl.update(3600.0, Rect2i(300, 200, 400, 300), Rect2i(320, 200, 400, 300), 520.0, 250.0, 550.0)
	_expect(not _has_kind(events, "start_move"), "a second drag session inside the cooldown stays quiet")
	# Resizing while the foot stays on the segment only reports resize.
	events = ctrl.update(4000.0, Rect2i(320, 200, 400, 300), Rect2i(320, 200, 420, 300), 520.0, 220.0, 540.0)
	_expect(_has_kind(events, "resize"), "a window resize while riding reacts")
	_expect(not _has_kind(events, "restance"), "a foot still on the segment needs no restand")
	# Resizing so the foot leaves the segment restands to the nearest inside x.
	events = ctrl.update(4500.0, Rect2i(320, 200, 420, 300), Rect2i(320, 200, 300, 300), 520.0, 320.0, 480.0)
	_expect(_has_kind(events, "resize") and _has_kind(events, "restance"), "a resized segment nudges the pet back on")
	_expect(is_equal_approx(_kind_value(events, "restance", "x", -1.0), 480.0), "restand clamps to the nearest inside x")
	# An unmount resets the cooldown: a fresh mount re-reacts to its first move
	# immediately instead of waiting out the 10s window.
	ctrl.reset()
	events = ctrl.update(6000.0, Rect2i(100, 200, 400, 300), Rect2i(100, 200, 400, 300), 300.0, 200.0, 500.0)
	_expect(events.is_empty(), "a fresh mount after reset primes the controller again")
	events = ctrl.update(6100.0, Rect2i(100, 200, 400, 300), Rect2i(140, 200, 400, 300), 340.0, 200.0, 500.0)
	_expect(_has_kind(events, "start_move"), "a remount after reset reacts to the first move immediately")


func _has_kind(events: Array, kind: String) -> bool:
	for value in events:
		if value is Dictionary and str(value.get("kind", "")) == kind:
			return true
	return false


func _kind_value(events: Array, kind: String, key: String, fallback: float) -> float:
	for value in events:
		if value is Dictionary and str(value.get("kind", "")) == kind:
			return float(value.get(key, fallback))
	return fallback


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func _collect_files_with_suffix(root: String, suffix: String, output: Array[String]) -> void:
	var directory := DirAccess.open(root)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var absolute_path := root.path_join(entry).replace("\\", "/")
			if directory.current_is_dir():
				_collect_files_with_suffix(absolute_path, suffix, output)
			elif entry.ends_with(suffix):
				output.append(absolute_path)
		entry = directory.get_next()
	directory.list_dir_end()

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
