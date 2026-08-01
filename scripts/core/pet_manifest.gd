class_name PetManifestData
extends RefCounted

const REQUIRED_ACTIONS := [
	"boot", "idle", "idle_blink", "react", "turn", "takeoff", "float", "land",
	"dragged", "notice", "cursor_track", "head_pat", "poke_cheek", "menu_wait",
	"clock_scare",
]

var data: Dictionary = {}
var manifest_path := ""
var skin_root := ""
var errors: Array[String] = []

static func load_from_file(path: String) -> PetManifestData:
	var result := PetManifestData.new()
	result.manifest_path = path
	result.skin_root = path.get_base_dir()
	if not FileAccess.file_exists(path):
		result.errors.append("找不到皮套清单：%s" % path)
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		result.errors.append("无法读取皮套清单：%s" % path)
		return result
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		result.errors.append("pet.json 不是有效的 JSON 对象")
		return result
	result.data = parsed
	result._validate()
	return result

func is_valid() -> bool:
	return errors.is_empty()

func clip(name: String) -> Dictionary:
	var animations: Dictionary = data.get("animations", {})
	var value = animations.get(name, {})
	return value if value is Dictionary else {}

func has_clip(name: String) -> bool:
	return not clip(name).is_empty()

func animation_names() -> Array[String]:
	var result: Array[String] = []
	var animations: Dictionary = data.get("animations", {})
	for key in animations.keys():
		result.append(str(key))
	return result

func behavior_value(key: String, fallback: Variant) -> Variant:
	var behavior: Dictionary = data.get("behavior", {})
	return behavior.get(key, fallback)

func canvas() -> Dictionary:
	return data.get("canvas", {})

func render_box() -> Dictionary:
	return data.get("renderBox", {})

func gaze() -> Dictionary:
	return data.get("gaze", {})

func frame_resource_path(relative_path: String) -> String:
	return skin_root.path_join(relative_path).replace("\\", "/")

func _validate() -> void:
	if int(data.get("schemaVersion", 0)) != 1:
		errors.append("只支持 schemaVersion: 1")
	if str(data.get("id", "")).is_empty() or str(data.get("name", "")).is_empty():
		errors.append("皮套缺少 id 或 name")
	var base_canvas: Dictionary = data.get("canvas", {})
	for key in ["width", "height", "displayWidth", "displayHeight"]:
		if float(base_canvas.get(key, 0.0)) <= 0.0:
			errors.append("canvas.%s 必须为正数" % key)
	var width := float(base_canvas.get("width", 1.0))
	var height := float(base_canvas.get("height", 1.0))
	var scale_x := float(base_canvas.get("displayWidth", 0.0)) / width
	var scale_y := float(base_canvas.get("displayHeight", 0.0)) / height
	if absf(scale_x - scale_y) > 0.0001:
		errors.append("canvas.displayWidth/displayHeight 必须使用同一缩放比例")
	var behavior: Dictionary = data.get("behavior", {})
	if behavior.is_empty():
		errors.append("皮套缺少 behavior 配置")
	var animations: Dictionary = data.get("animations", {})
	if animations.is_empty():
		errors.append("皮套缺少 animations 配置")
		return
	for required in REQUIRED_ACTIONS:
		if not animations.has(required):
			errors.append("皮套缺少动作：%s" % required)
	for name in animations.keys():
		_validate_clip(str(name), animations[name])

func _validate_clip(name: String, value: Variant) -> void:
	if not value is Dictionary:
		errors.append("动作 %s 不是对象" % name)
		return
	var clip_data: Dictionary = value
	var frames: Array = clip_data.get("frames", [])
	var durations: Array = clip_data.get("frameDurationsMs", [])
	if frames.is_empty():
		errors.append("动作 %s 没有精灵帧" % name)
	if frames.size() != durations.size():
		errors.append("动作 %s 的帧数量和时长数量不一致" % name)
	for duration in durations:
		if float(duration) <= 0.0:
			errors.append("动作 %s 包含无效帧时长" % name)
			break
	var support_y: Array = clip_data.get("supportContactY", [])
	if not support_y.is_empty():
		if support_y.size() != frames.size():
			errors.append("动作 %s 的 supportContactY 长度无效" % name)
		var clip_canvas: Dictionary = clip_data.get("canvas", data.get("canvas", {}))
		var canvas_height := float(clip_canvas.get("height", 512.0))
		for value_y in support_y:
			if typeof(value_y) not in [TYPE_INT, TYPE_FLOAT] or float(value_y) < 0.0 or float(value_y) > canvas_height:
				errors.append("动作 %s 包含无效支撑点" % name)
				break
	var anchor: Dictionary = clip_data.get("anchor", {})
	if not anchor.has("x") or not anchor.has("y"):
		errors.append("动作 %s 的锚点无效" % name)
	var hit_area: Array = clip_data.get("hitArea", [])
	if hit_area.size() < 3:
		errors.append("动作 %s 至少需要三个命中区域顶点" % name)
	var root_motion: Dictionary = clip_data.get("rootMotion", {})
	if not root_motion.is_empty():
		var progress: Array = root_motion.get("frameProgress", [])
		if progress.size() != frames.size() + 1:
			errors.append("动作 %s 的 rootMotion.frameProgress 长度无效" % name)
