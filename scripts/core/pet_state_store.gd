class_name PetStateStore
extends RefCounted

const CURRENT_SCHEMA_VERSION := 3
const DEFAULT_PATH := "user://little_chihiro_state.json"
const DEFAULT_AFFECTION := 25.0
const DEFAULT_RELATIONSHIP_TIER := "guarded"
const DAILY_AFFECTION_CAP := 3.0
const INTERACTION_KEYS := [
	"head_pats",
	"pokes",
	"rough_drags",
	"positive",
	"total",
]
const RECENT_DIALOGUE_LIMIT := 12
const RECENT_ECOLOGY_EVENT_LIMIT := 50

var save_path := DEFAULT_PATH
var last_error := ""
var last_backup_path := ""

func _init(path: String = DEFAULT_PATH) -> void:
	save_path = path

func create_default_state() -> Dictionary:
	var interaction_stats := {}
	for key in INTERACTION_KEYS:
		interaction_stats[key] = 0
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"affection": DEFAULT_AFFECTION,
		"current_relationship_tier": DEFAULT_RELATIONSHIP_TIER,
		"relationship_day_key": "",
		"positive_affection_today": 0.0,
		"negative_affection_today": 0.0,
		"interaction_stats": interaction_stats,
		"total_companion_seconds": 0.0,
		"last_seen_unix": 0,
		"recent_dialogue_ids": [],
		"habitat_familiarity": 0.0,
		"habits": {},
		"discoveries": {},
		"goal_stats": {},
		"request_stats": {"accepted": 0, "deferred": 0, "refused": 0, "completed": 0},
		"recent_ecology_events": [],
		"home_anchor": {},
	}

func load_state(default_overrides: Dictionary = {}) -> Dictionary:
	last_error = ""
	last_backup_path = ""
	var defaults := _normalized_state(default_overrides, create_default_state())
	_recover_interrupted_replace()
	if not FileAccess.file_exists(save_path):
		return defaults
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return _recover_corrupt_state(defaults, "无法读取长期状态存档")
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _recover_corrupt_state(defaults, "长期状态存档不是有效的 JSON 对象")
	var source: Dictionary = parsed
	var schema_version := int(source.get("schema_version", source.get("schemaVersion", source.get("version", 0))))
	if schema_version > CURRENT_SCHEMA_VERSION or schema_version < 0:
		return _recover_corrupt_state(defaults, "长期状态存档版本不受支持：%d" % schema_version)
	var migrated := _migrate(source, schema_version)
	if migrated.is_empty():
		return _recover_corrupt_state(defaults, "长期状态存档迁移失败")
	_cleanup_previous_copy()
	return _normalized_state(migrated, defaults)

func save_state(state: Dictionary) -> bool:
	last_error = ""
	var snapshot := _normalized_state(state, create_default_state())
	var absolute_target := _absolute_path(save_path)
	var parent := absolute_target.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		var mkdir_error := DirAccess.make_dir_recursive_absolute(parent)
		if mkdir_error != OK:
			last_error = "无法创建存档目录：%s" % error_string(mkdir_error)
			return false
	var temp_path := "%s.tmp" % save_path
	var absolute_temp := _absolute_path(temp_path)
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(absolute_temp)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		last_error = "无法创建临时状态存档"
		return false
	file.store_string(JSON.stringify(snapshot, "\t", true) + "\n")
	file.flush()
	file = null
	if not _replace_from_temp(absolute_temp, absolute_target):
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(absolute_temp)
		return false
	return true

func persistent_snapshot(state: Dictionary) -> Dictionary:
	return _normalized_state(state, create_default_state())

func record_session(
	state: Dictionary,
	companion_seconds: float,
	interaction_delta: Dictionary = {},
	now_unix: int = 0
) -> Dictionary:
	var result := _normalized_state(state, create_default_state())
	result.total_companion_seconds = maxf(
		0.0,
		float(result.total_companion_seconds) + maxf(0.0, companion_seconds)
	)
	result.last_seen_unix = now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	var stats: Dictionary = result.interaction_stats
	for key in INTERACTION_KEYS:
		if interaction_delta.has(key):
			stats[key] = maxi(0, int(stats.get(key, 0)) + int(interaction_delta[key]))
	return result

func _migrate(source: Dictionary, from_version: int) -> Dictionary:
	var migrated := source.duplicate(true)
	if from_version == 0:
		if migrated.has("interactionStats") and not migrated.has("interaction_stats"):
			migrated.interaction_stats = migrated.interactionStats
		if migrated.has("totalCompanionSeconds") and not migrated.has("total_companion_seconds"):
			migrated.total_companion_seconds = migrated.totalCompanionSeconds
		if migrated.has("lastSeenUnix") and not migrated.has("last_seen_unix"):
			migrated.last_seen_unix = migrated.lastSeenUnix
		if migrated.has("recentDialogueIds") and not migrated.has("recent_dialogue_ids"):
			migrated.recent_dialogue_ids = migrated.recentDialogueIds
		migrated.schema_version = 1
	if int(migrated.get("schema_version", from_version)) == 1:
		migrated["habitat_familiarity"] = float(migrated.get("habitat_familiarity", 0.0))
		migrated["habits"] = migrated.get("habits", {})
		migrated["discoveries"] = migrated.get("discoveries", {})
		migrated["goal_stats"] = migrated.get("goal_stats", {})
		migrated["request_stats"] = migrated.get("request_stats", {})
		migrated["recent_ecology_events"] = migrated.get("recent_ecology_events", [])
		migrated["home_anchor"] = migrated.get("home_anchor", {})
		migrated.schema_version = 2
	if int(migrated.get("schema_version", from_version)) == 2:
		var affection := clampf(float(migrated.get("affection", DEFAULT_AFFECTION)), 0.0, 100.0)
		migrated["current_relationship_tier"] = _relationship_tier_for_affection(affection)
		migrated["relationship_day_key"] = ""
		migrated["positive_affection_today"] = 0.0
		migrated["negative_affection_today"] = 0.0
		migrated.schema_version = 3
	return migrated

func _normalized_state(source: Dictionary, fallback: Dictionary) -> Dictionary:
	var fallback_stats: Dictionary = fallback.get("interaction_stats", {})
	var source_stats = source.get("interaction_stats", source.get("interactionStats", {}))
	if not source_stats is Dictionary:
		source_stats = {}
	var stats := {}
	for key in INTERACTION_KEYS:
		var legacy_key := _legacy_interaction_key(key)
		stats[key] = maxi(0, int(source_stats.get(key, source_stats.get(legacy_key, fallback_stats.get(key, 0)))))
	var recent_dialogue_ids: Array[String] = []
	var source_recent = source.get("recent_dialogue_ids", source.get("recentDialogueIds", []))
	if source_recent is Array:
		for value in source_recent:
			var dialogue_id := str(value).strip_edges()
			if not dialogue_id.is_empty() and dialogue_id not in recent_dialogue_ids:
				recent_dialogue_ids.append(dialogue_id.left(96))
	while recent_dialogue_ids.size() > RECENT_DIALOGUE_LIMIT:
		recent_dialogue_ids.pop_front()
	var recent_ecology_events := _normalize_ecology_events(source.get("recent_ecology_events", []))
	var affection := clampf(float(source.get("affection", fallback.get("affection", DEFAULT_AFFECTION))), 0.0, 100.0)
	var relationship_tier := _normalize_relationship_tier(str(source.get(
		"current_relationship_tier",
		fallback.get("current_relationship_tier", _relationship_tier_for_affection(affection)),
	)))
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"affection": affection,
		"current_relationship_tier": relationship_tier,
		"relationship_day_key": _normalize_day_key(str(source.get("relationship_day_key", fallback.get("relationship_day_key", "")))),
		"positive_affection_today": clampf(float(source.get("positive_affection_today", fallback.get("positive_affection_today", 0.0))), 0.0, DAILY_AFFECTION_CAP),
		"negative_affection_today": clampf(float(source.get("negative_affection_today", fallback.get("negative_affection_today", 0.0))), 0.0, DAILY_AFFECTION_CAP),
		"interaction_stats": stats,
		"total_companion_seconds": maxf(0.0, float(source.get(
			"total_companion_seconds",
			source.get("totalCompanionSeconds", fallback.get("total_companion_seconds", 0.0))
		))),
		"last_seen_unix": maxi(0, int(source.get(
			"last_seen_unix",
			source.get("lastSeenUnix", fallback.get("last_seen_unix", 0))
		))),
		"recent_dialogue_ids": recent_dialogue_ids,
		"habitat_familiarity": clampf(float(source.get("habitat_familiarity", fallback.get("habitat_familiarity", 0.0))), 0.0, 100.0),
		"habits": _normalize_habits(source.get("habits", fallback.get("habits", {}))),
		"discoveries": _normalize_discoveries(source.get("discoveries", fallback.get("discoveries", {}))),
		"goal_stats": _normalize_counter_map(source.get("goal_stats", fallback.get("goal_stats", {}))),
		"request_stats": _normalize_request_stats(source.get("request_stats", fallback.get("request_stats", {}))),
		"recent_ecology_events": recent_ecology_events,
		"home_anchor": _normalize_home_anchor(source.get("home_anchor", fallback.get("home_anchor", {}))),
	}

func _normalize_habits(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for raw_key in source.keys():
		var key := _safe_id(raw_key)
		if key.is_empty():
			continue
		var raw: Variant = source[raw_key]
		var entry: Dictionary = raw if raw is Dictionary else {}
		result[key] = {
			"count": maxi(0, int(entry.get("count", 0))),
			"stage": clampi(int(entry.get("stage", 0)), 0, 3),
			"last_credit_unix": maxi(0, int(entry.get("last_credit_unix", 0))),
		}
	return result

func _normalize_discoveries(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for raw_key in source.keys():
		var key := _safe_id(raw_key)
		if key.is_empty():
			continue
		var raw: Variant = source[raw_key]
		var entry: Dictionary = raw if raw is Dictionary else {}
		result[key] = {"unlocked_unix": maxi(0, int(entry.get("unlocked_unix", 0)))}
	return result

func _normalize_counter_map(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for raw_key in source.keys():
		var key := _safe_id(raw_key)
		if not key.is_empty():
			result[key] = maxi(0, int(source[raw_key]))
	return result

func _normalize_request_stats(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for key in ["accepted", "deferred", "refused", "completed"]:
		result[key] = maxi(0, int(source.get(key, 0)))
	return result

func _normalize_ecology_events(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw in value:
			if not raw is Dictionary:
				continue
			result.append({
				"kind": _safe_id(raw.get("kind", "")),
				"id": _safe_id(raw.get("id", "")),
				"unix": maxi(0, int(raw.get("unix", 0))),
				"time_period": _safe_id(raw.get("time_period", "")),
				"app_category": _safe_id(raw.get("app_category", "")),
				"goal_id": _safe_id(raw.get("goal_id", "")),
				"request_id": _safe_id(raw.get("request_id", "")),
			})
	while result.size() > RECENT_ECOLOGY_EVENT_LIMIT:
		result.pop_front()
	return result

func _normalize_home_anchor(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var source: Dictionary = value
	var screen_rect := _number_array(source.get("screen_rect", []), 4)
	var uv := _number_array(source.get("uv", []), 2)
	var global_position := _number_array(source.get("global_position", []), 2)
	if screen_rect.size() != 4 or uv.size() != 2 or global_position.size() != 2:
		return {}
	uv[0] = clampf(float(uv[0]), 0.0, 1.0)
	uv[1] = clampf(float(uv[1]), 0.0, 1.0)
	return {"screen_rect": screen_rect, "uv": uv, "global_position": global_position}

func _number_array(value: Variant, required_size: int) -> Array[float]:
	var result: Array[float] = []
	if value is Array and value.size() >= required_size:
		for index in range(required_size):
			var number := float(value[index])
			if not is_finite(number):
				return []
			result.append(number)
	return result

func _safe_id(value: Variant) -> String:
	var text := str(value).strip_edges().left(96)
	var result := ""
	for character in text:
		if character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			result += character
	return result

func _normalize_relationship_tier(value: String) -> String:
	match value.strip_edges().to_lower():
		"distant": return "distant"
		"guarded", "wary": return "guarded"
		"familiar": return "familiar"
		"trusted", "trust": return "trusted"
		"close": return "close"
		_: return DEFAULT_RELATIONSHIP_TIER

func _relationship_tier_for_affection(affection: float) -> String:
	if affection >= 80.0: return "close"
	if affection >= 60.0: return "trusted"
	if affection >= 40.0: return "familiar"
	if affection >= 20.0: return "guarded"
	return "distant"

func _normalize_day_key(value: String) -> String:
	var text := value.strip_edges()
	if text.length() != 10 or text[4] != "-" or text[7] != "-":
		return ""
	for index in range(text.length()):
		if index in [4, 7]:
			continue
		if text[index] < "0" or text[index] > "9":
			return ""
	return text

func _legacy_interaction_key(key: String) -> String:
	match key:
		"head_pats": return "headPats"
		"rough_drags": return "roughDrags"
		_: return key

func _recover_corrupt_state(defaults: Dictionary, reason: String) -> Dictionary:
	last_backup_path = _backup_corrupt_file()
	if last_backup_path.is_empty():
		last_error = reason + "；备份失败，已保留原文件"
		return defaults
	var recovery_error := reason + "；已备份到 %s" % last_backup_path
	if not save_state(defaults):
		recovery_error += "；恢复默认存档失败：%s" % last_error
	last_error = recovery_error
	return defaults

func _backup_corrupt_file() -> String:
	if not FileAccess.file_exists(save_path):
		return ""
	var stamp := int(Time.get_unix_time_from_system())
	var candidate := "%s.corrupt-%d.json" % [save_path.trim_suffix(".json"), stamp]
	var suffix := 1
	while FileAccess.file_exists(candidate):
		candidate = "%s.corrupt-%d-%d.json" % [save_path.trim_suffix(".json"), stamp, suffix]
		suffix += 1
	var copy_error := DirAccess.copy_absolute(_absolute_path(save_path), _absolute_path(candidate))
	return candidate if copy_error == OK else ""

func _replace_from_temp(absolute_temp: String, absolute_target: String) -> bool:
	if not FileAccess.file_exists(save_path):
		var first_error := DirAccess.rename_absolute(absolute_temp, absolute_target)
		if first_error != OK:
			last_error = "无法安装状态存档：%s" % error_string(first_error)
			return false
		return true
	var previous := _previous_path()
	if FileAccess.file_exists(previous):
		DirAccess.remove_absolute(previous)
	var preserve_error := DirAccess.copy_absolute(absolute_target, previous)
	if preserve_error != OK:
		last_error = "无法保留旧状态存档：%s" % error_string(preserve_error)
		return false
	if _native_atomic_replace(absolute_temp, absolute_target):
		DirAccess.remove_absolute(previous)
		return true
	var remove_error := DirAccess.remove_absolute(absolute_target)
	if remove_error != OK:
		last_error = "无法准备替换状态存档：%s" % error_string(remove_error)
		return false
	var install_error := DirAccess.rename_absolute(absolute_temp, absolute_target)
	if install_error != OK:
		var restore_error := DirAccess.copy_absolute(previous, absolute_target)
		last_error = "无法替换状态存档：%s" % error_string(install_error)
		if restore_error != OK:
			last_error += "；旧存档恢复失败：%s" % error_string(restore_error)
		return false
	DirAccess.remove_absolute(previous)
	return true

func _native_atomic_replace(absolute_temp: String, absolute_target: String) -> bool:
	if not ClassDB.class_exists("WindowsWindowEnumerator"):
		return false
	var bridge: Variant = ClassDB.instantiate("WindowsWindowEnumerator")
	return bridge != null and bridge.has_method("atomic_replace_file") and bool(
		bridge.call("atomic_replace_file", absolute_temp, absolute_target)
	)

func _recover_interrupted_replace() -> void:
	var absolute_target := _absolute_path(save_path)
	var previous := _previous_path()
	if FileAccess.file_exists(save_path) or not FileAccess.file_exists(previous):
		return
	var restore_error := DirAccess.rename_absolute(previous, absolute_target)
	if restore_error != OK:
		last_error = "检测到中断的存档替换，但旧存档恢复失败：%s" % error_string(restore_error)

func _cleanup_previous_copy() -> void:
	var previous := _previous_path()
	if FileAccess.file_exists(previous):
		DirAccess.remove_absolute(previous)

func _previous_path() -> String:
	return "%s.previous" % _absolute_path(save_path)

func _absolute_path(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.contains("://") else path
