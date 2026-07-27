extends SceneTree

var failures: Array[String] = []
var assertions := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_manifest()
	_test_state_machine()
	_test_render_box()
	_test_playback()
	_test_gaze()
	_test_drag_and_umbrella()
	_test_edge_patrol()
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
	_expect(manifest.animation_names().size() == 62, "manifest should contain 62 animations")
	var frame_count := 0
	var missing_count := 0
	for name in manifest.animation_names():
		var clip := manifest.clip(name)
		for frame in clip.get("frames", []):
			frame_count += 1
			if not FileAccess.file_exists(manifest.frame_resource_path(str(frame))):
				missing_count += 1
	_expect(frame_count == 1311, "manifest should expose 1311 runtime frames")
	_expect(missing_count == 0, "all manifest frame paths should exist")

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

func _test_render_box() -> void:
	var manifest := PetManifestData.load_from_file("res://skins/little-chihiro/pet.json")
	_expect(PetRenderBox.resolve_size(manifest, manifest.clip("idle")) == Vector2i(360, 360), "idle uses 360px host")
	_expect(PetRenderBox.resolve_size(manifest, manifest.clip("umbrella_float")).x > 360, "umbrella grows host")
	var route_side := 0
	var largest_route_clip := ""
	var route_names := {}
	for clip_map in [EdgePatrolPlanner.DEFAULT_CLIPS, EdgePatrolPlanner.clips_for_variant("a"), EdgePatrolPlanner.clips_for_variant("b"), EdgePatrolPlanner.DOOR_CLIPS]:
		for name in clip_map.values(): route_names[str(name)] = true
	for name in route_names.keys():
		if manifest.has_clip(str(name)):
			var clip_side := PetRenderBox.resolve_size(manifest, manifest.clip(str(name))).x
			if clip_side > route_side:
				route_side = clip_side
				largest_route_clip = str(name)
	_expect(route_side == 436, "complete patrol route locks a 436px host (got %d from %s)" % [route_side, largest_route_clip])

func _test_playback() -> void:
	var phase := PetSpritePlayer.resolve_playback_frame([100, 200, 300], 0, 2, false, true, 350.0)
	_expect(int(phase.frame_index) == 2, "elapsed playback resolves third frame")
	_expect(is_equal_approx(float(phase.elapsed_in_frame_ms), 50.0), "elapsed playback keeps local phase")
	phase = PetSpritePlayer.resolve_playback_frame([100, 200, 300], 0, 2, true, false, 50.0)
	_expect(int(phase.frame_index) == 2, "reverse playback starts at range end")

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
	var clips := EdgePatrolPlanner.clips_for_variant("a")
	var plan := EdgePatrolPlanner.plan({
		"work_area": Rect2(0, 0, 1920, 1040),
		"box_side": 436.0,
		"start": Vector2(1200, 604),
		"available_clips": manifest.animation_names(),
		"clips": clips,
		"door_warp_chance": 0.0,
		"seed": "test-route",
	})
	_expect(str(plan.mode) == "full", "complete skin plans a full edge route")
	_expect((plan.poses as Array).size() == 9, "full route contains nine poses")
	var bounds: Dictionary = plan.bounds
	for pose in plan.poses:
		for key in ["from", "to", "position"]:
			if not pose.has(key): continue
			var point := Vector2(pose[key])
			_expect(point.x >= float(bounds.min_x) - 0.01 and point.x <= float(bounds.max_x) + 0.01, "route x stays inside work area")
			_expect(point.y >= float(bounds.min_y) - 0.01 and point.y <= float(bounds.max_y) + 0.01, "route y stays inside work area")

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
