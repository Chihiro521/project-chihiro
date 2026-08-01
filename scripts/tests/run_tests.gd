extends SceneTree

const DialogueSchedulerScript := preload("res://scripts/core/pet_dialogue_scheduler.gd")

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
	_test_dialogue_scheduler()
	await _test_speech_bubble()
	_test_action_catalog()
	_test_mechanism_dashboard()
	_test_window_platforms()
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
	_expect(diagnostics.size() == 16, "behavior diagnostics expose all sixteen configured intents")
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
	state.affection = 73.5
	state.interaction_stats.head_pats = 4
	state["untrusted_title"] = "must not persist"
	_expect(store.save_state(state), "state store writes atomically")
	var loaded := store.load_state()
	_expect(is_equal_approx(float(loaded.affection), 73.5), "state store restores affection")
	_expect(int(loaded.interaction_stats.head_pats) == 4, "state store restores interaction counters")
	_expect(not loaded.has("untrusted_title"), "state store drops fields outside the whitelist")
	var previous_path := absolute + ".previous"
	_expect(DirAccess.rename_absolute(absolute, previous_path) == OK, "test can simulate an interrupted state replacement")
	var recovered := store.load_state()
	_expect(is_equal_approx(float(recovered.affection), 73.5), "state store restores the previous file after an interrupted replacement")
	var dialogue := PetDialogueDirector.new(99)
	_expect(dialogue.load_data("res://data/dialogue_zh_CN.json"), "dialogue data loads")
	_expect(dialogue.line_count() == 145, "dialogue catalog contains 145 lines")
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
	var occluded_track := tracker.track_platform(ridden, tool_occlusion, 200.0)
	_expect(bool(occluded_track.get("lost", false)) and str(occluded_track.get("reason", "")) == "standing_point_occluded", "rider falls when its exact standing point becomes occluded")
	var reused_track := tracker.track_platform(ridden, [
		{"handle": 11, "process_id": 999, "rect": Rect2i(0, 100, 700, 500), "z_order": 0, "visible": true},
	], 400.0)
	_expect(bool(reused_track.get("lost", false)), "reused HWND with another process id is rejected")
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
