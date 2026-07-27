class_name PetSpritePlayer
extends Node

signal clip_changed(name: String, previous_name: String)
signal clip_completed(name: String, segment: String)
signal frame_changed(frame_index: int, frame_count: int)
signal passthrough_polygon_changed(polygon: PackedVector2Array)

@export var sprite_path: NodePath

var manifest: PetManifestData
var current_clip := "boot"
var current_segment := ""
var current_frame := 0
var direction := 1

var _sprite: Sprite2D
var _elapsed_in_frame_ms := 0.0
var _range_start := 0
var _range_end := 0
var _range_loop := false
var _playback_direction := 1
var _finished := false
var _manual_frame := -1
var _externally_driven := false
var _cycle_index := 0
var _cycle_variant_index := -1
var _textures: Dictionary = {}

func _ready() -> void:
	_sprite = get_node(sprite_path) as Sprite2D
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(true)

func set_manifest(value: PetManifestData) -> void:
	manifest = value
	_textures.clear()
	current_clip = "boot"
	play_clip("boot")

func play_clip(name: String, restart := true, segment := "", reverse := false) -> void:
	if manifest == null or not manifest.has_clip(name):
		return
	var playback_direction := -1 if reverse else 1
	if not restart and name == current_clip and segment == current_segment and playback_direction == _playback_direction:
		return
	var clip := manifest.clip(name)
	var segments: Dictionary = clip.get("segments", {})
	var segment_data: Dictionary = segments.get(segment, {}) if not segment.is_empty() else {}
	if not segment.is_empty() and segment_data.is_empty():
		return
	_prepare_clip_sync(clip)
	var previous := current_clip
	current_clip = name
	current_segment = segment
	_range_start = int(segment_data.get("start", 0))
	_range_end = int(segment_data.get("end", max(0, (clip.get("frames", []) as Array).size() - 1)))
	_range_loop = bool(segment_data.get("loop", clip.get("loop", false)))
	_playback_direction = playback_direction
	current_frame = _range_end if _playback_direction < 0 else _range_start
	_elapsed_in_frame_ms = 0.0
	_finished = false
	_manual_frame = -1
	_externally_driven = false
	_cycle_index = 0
	_cycle_variant_index = _resolve_cycle_variant(clip, 0)
	clip_changed.emit(name, previous)
	_apply_frame()

func prepare_clips(names: Array[String]) -> void:
	if manifest == null:
		return
	var loaded := 0
	for name in names:
		var clip := manifest.clip(name)
		var frames: Array = clip.get("frames", [])
		for frame in frames:
			_texture(str(frame))
			loaded += 1
			if loaded % 12 == 0:
				await get_tree().process_frame
		var variants: Array = clip.get("cycleVariants", [])
		for variant_value in variants:
			if not variant_value is Dictionary:
				continue
			var overrides: Dictionary = variant_value.get("frameOverrides", {})
			for path in overrides.values():
				_texture(str(path))
				loaded += 1
				if loaded % 12 == 0:
					await get_tree().process_frame

func set_direction(next_direction: int) -> void:
	direction = -1 if next_direction < 0 else 1
	_layout()

func set_manual_frame(frame: int) -> void:
	if manifest == null:
		return
	if frame < 0:
		_manual_frame = -1
		return
	var count := frame_count()
	if count <= 0:
		return
	_manual_frame = clampi(frame, 0, count - 1)
	current_frame = _manual_frame
	_apply_frame()

func set_playback_elapsed(elapsed_ms: float) -> void:
	if manifest == null or _manual_frame >= 0:
		return
	var clip := manifest.clip(current_clip)
	if clip.is_empty():
		return
	_externally_driven = true
	_finished = false
	var phase := resolve_playback_frame(
		clip.get("frameDurationsMs", []),
		_range_start,
		_range_end,
		_playback_direction < 0,
		_range_loop,
		elapsed_ms,
	)
	var cycle_duration := _clip_range_duration(clip) if _range_loop else 0.0
	var next_cycle := int(floor(maxf(0.0, elapsed_ms) / cycle_duration)) if cycle_duration > 0.0 else 0
	var next_variant := _cycle_variant_index if next_cycle == _cycle_index else _resolve_cycle_variant(clip, next_cycle)
	var texture_changed := next_variant != _cycle_variant_index
	_cycle_index = next_cycle
	_cycle_variant_index = next_variant
	_elapsed_in_frame_ms = float(phase.get("elapsed_in_frame_ms", 0.0))
	var next_frame := int(phase.get("frame_index", current_frame))
	if next_frame == current_frame and not texture_changed:
		return
	current_frame = next_frame
	_apply_frame()

func refresh_layout() -> void:
	_layout()

func frame_count() -> int:
	if manifest == null:
		return 0
	return (manifest.clip(current_clip).get("frames", []) as Array).size()

func hit_test(window_point: Vector2) -> Dictionary:
	if manifest == null or _sprite == null:
		return {}
	var clip := manifest.clip(current_clip)
	if clip.is_empty():
		return {}
	var texture_point := _window_to_texture(window_point, clip)
	if not clip.has("canvas"):
		var zones: Dictionary = manifest.data.get("hitZones", {})
		for zone in ["head", "bag", "body"]:
			var polygon := _points_to_polygon(zones.get(zone, []))
			if polygon.size() >= 3 and Geometry2D.is_point_in_polygon(texture_point, polygon):
				return {"zone": zone, "texture_point": texture_point}
	var clip_polygon := _points_to_polygon(clip.get("hitArea", []))
	if clip_polygon.size() >= 3 and Geometry2D.is_point_in_polygon(texture_point, clip_polygon):
		return {"zone": "body", "texture_point": texture_point}
	return {}

func texture_point_to_window(texture_point: Vector2) -> Vector2:
	if manifest == null:
		return Vector2.ZERO
	var clip := manifest.clip(current_clip)
	var canvas: Dictionary = clip.get("canvas", manifest.canvas())
	var anchor: Dictionary = clip.get("anchor", {"x": 0.5, "y": 0.96})
	var scale := PetRenderBox.character_scale(manifest)
	var dock := PetRenderBox.dock_point(
		Vector2(get_window().size),
		PetRenderBox.render_dock(clip),
		PetRenderBox.render_dock_inset(clip),
	)
	return Vector2(
		dock.x + (texture_point.x - float(anchor.get("x", 0.5)) * float(canvas.get("width", 512.0))) * scale * direction,
		dock.y + (texture_point.y - float(anchor.get("y", 0.96)) * float(canvas.get("height", 512.0))) * scale,
	)

func current_passthrough_polygon() -> PackedVector2Array:
	if manifest == null:
		return PackedVector2Array()
	var clip := manifest.clip(current_clip)
	var points: Array = []
	var bounds: Dictionary = clip.get("visualBounds", {})
	if not bounds.is_empty():
		var x := float(bounds.get("x", 0.0))
		var y := float(bounds.get("y", 0.0))
		var width := float(bounds.get("width", 0.0))
		var height := float(bounds.get("height", 0.0))
		points = [Vector2(x, y), Vector2(x + width, y), Vector2(x + width, y + height), Vector2(x, y + height)]
	else:
		for point in clip.get("hitArea", []):
			points.append(Vector2(float(point.get("x", 0.0)), float(point.get("y", 0.0))))
	var result := PackedVector2Array()
	for point in points:
		result.append(texture_point_to_window(point))
	return result

static func resolve_playback_frame(durations: Array, range_start: int, range_end: int, reverse: bool, loop: bool, elapsed_ms: float) -> Dictionary:
	var first: int = maxi(0, mini(range_start, range_end))
	var last: int = maxi(first, maxi(range_start, range_end))
	var ordered: Array[int] = []
	for offset in range(last - first + 1):
		ordered.append(last - offset if reverse else first + offset)
	var cycle_duration := 0.0
	for frame_index in ordered:
		cycle_duration += _duration_for(durations, frame_index)
	var phase := maxf(0.0, elapsed_ms)
	if loop and cycle_duration > 0.0:
		phase = fposmod(phase, cycle_duration)
	else:
		phase = minf(phase, cycle_duration)
	for frame_index in ordered:
		var duration := _duration_for(durations, frame_index)
		if phase < duration:
			return {"frame_index": frame_index, "elapsed_in_frame_ms": phase}
		phase -= duration
	var final_frame: int = first if reverse else last
	return {"frame_index": final_frame, "elapsed_in_frame_ms": _duration_for(durations, final_frame)}

func _process(delta: float) -> void:
	if manifest == null or _manual_frame >= 0 or _finished or _externally_driven:
		return
	var clip := manifest.clip(current_clip)
	if clip.is_empty():
		return
	var durations: Array = clip.get("frameDurationsMs", [])
	_elapsed_in_frame_ms += delta * 1000.0
	while not _finished:
		var duration := _duration_for(durations, current_frame)
		if _elapsed_in_frame_ms < duration:
			break
		_elapsed_in_frame_ms -= duration
		var next := current_frame + _playback_direction
		if next >= _range_start and next <= _range_end:
			current_frame = next
			_apply_frame()
		elif _range_loop:
			_cycle_index += 1
			_cycle_variant_index = _resolve_cycle_variant(clip, _cycle_index)
			current_frame = _range_end if _playback_direction < 0 else _range_start
			_apply_frame()
		else:
			_finished = true
			clip_completed.emit(current_clip, current_segment)
			return

func _apply_frame() -> void:
	if manifest == null or _sprite == null:
		return
	var clip := manifest.clip(current_clip)
	var frames: Array = clip.get("frames", [])
	if current_frame < 0 or current_frame >= frames.size():
		return
	var frame_path := str(frames[current_frame])
	var variants: Array = clip.get("cycleVariants", [])
	if _cycle_variant_index >= 0 and _cycle_variant_index < variants.size():
		var variant: Dictionary = variants[_cycle_variant_index]
		var overrides: Dictionary = variant.get("frameOverrides", {})
		frame_path = str(overrides.get(str(current_frame), frame_path))
	var texture := _texture(frame_path)
	if texture == null:
		return
	_sprite.texture = texture
	_layout()
	frame_changed.emit(current_frame, frames.size())

func _layout() -> void:
	if manifest == null or _sprite == null:
		return
	var clip := manifest.clip(current_clip)
	var canvas: Dictionary = clip.get("canvas", manifest.canvas())
	var anchor: Dictionary = clip.get("anchor", {"x": 0.5, "y": 0.96})
	var scale := PetRenderBox.character_scale(manifest)
	_sprite.offset = Vector2(
		-float(anchor.get("x", 0.5)) * float(canvas.get("width", 512.0)),
		-float(anchor.get("y", 0.96)) * float(canvas.get("height", 512.0)),
	)
	_sprite.scale = Vector2(scale * direction, scale)
	_sprite.position = PetRenderBox.dock_point(
		Vector2(get_window().size),
		PetRenderBox.render_dock(clip),
		PetRenderBox.render_dock_inset(clip),
	)
	passthrough_polygon_changed.emit(current_passthrough_polygon())

func _window_to_texture(window_point: Vector2, clip: Dictionary) -> Vector2:
	var canvas: Dictionary = clip.get("canvas", manifest.canvas())
	var anchor: Dictionary = clip.get("anchor", {"x": 0.5, "y": 0.96})
	var scale := PetRenderBox.character_scale(manifest)
	var dock := PetRenderBox.dock_point(
		Vector2(get_window().size),
		PetRenderBox.render_dock(clip),
		PetRenderBox.render_dock_inset(clip),
	)
	return Vector2(
		(window_point.x - dock.x) / (scale * direction) + float(anchor.get("x", 0.5)) * float(canvas.get("width", 512.0)),
		(window_point.y - dock.y) / scale + float(anchor.get("y", 0.96)) * float(canvas.get("height", 512.0)),
	)

func _prepare_clip_sync(clip: Dictionary) -> void:
	for frame in clip.get("frames", []):
		_texture(str(frame))
	for variant_value in clip.get("cycleVariants", []):
		if not variant_value is Dictionary:
			continue
		for path in variant_value.get("frameOverrides", {}).values():
			_texture(str(path))

func _texture(relative_path: String) -> Texture2D:
	if _textures.has(relative_path):
		return _textures[relative_path]
	var resource_path := manifest.frame_resource_path(relative_path)
	var resource := ResourceLoader.load(resource_path, "Texture2D")
	if resource is Texture2D:
		_textures[relative_path] = resource
		return resource
	push_warning("无法载入精灵帧：%s" % resource_path)
	return null

func _clip_range_duration(clip: Dictionary) -> float:
	var durations: Array = clip.get("frameDurationsMs", [])
	var total := 0.0
	for frame_index in range(_range_start, _range_end + 1):
		total += _duration_for(durations, frame_index)
	return total

func _resolve_cycle_variant(clip: Dictionary, cycle: int) -> int:
	var variants: Array = clip.get("cycleVariants", [])
	if variants.is_empty() or not _range_loop or _range_start != 0 or _range_end != (clip.get("frames", []) as Array).size() - 1:
		return -1
	var last_activation := -1_000_000
	for cycle_index in range(cycle + 1):
		var selected := -1
		var selected_score := 2.0
		for variant_index in range(variants.size()):
			var variant: Dictionary = variants[variant_index]
			var score := _deterministic_random("%s|%s|%d" % [current_clip, str(variant.get("id", variant_index)), cycle_index])
			if score < float(variant.get("probability", 0.0)) and cycle_index - last_activation > int(variant.get("minGapCycles", 0)) and score < selected_score:
				selected = variant_index
				selected_score = score
		if selected >= 0:
			last_activation = cycle_index
			if cycle_index == cycle:
				return selected
	return -1

func _deterministic_random(key: String) -> float:
	var random := RandomNumberGenerator.new()
	random.seed = abs(key.hash())
	return random.randf()

func _points_to_polygon(values: Array) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for value in values:
		if value is Dictionary:
			polygon.append(Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0))))
	return polygon

static func _duration_for(durations: Array, frame_index: int) -> float:
	if frame_index >= 0 and frame_index < durations.size():
		var duration := float(durations[frame_index])
		if duration > 0.0:
			return duration
	return 100.0
