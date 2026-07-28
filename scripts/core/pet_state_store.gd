class_name PetStateStore
extends RefCounted

const CURRENT_SCHEMA_VERSION := 1
const DEFAULT_PATH := "user://little_chihiro_state.json"
const DEFAULT_AFFECTION := 40.0
const INTERACTION_KEYS := [
	"head_pats",
	"pokes",
	"rough_drags",
	"positive",
	"total",
]
const RECENT_DIALOGUE_LIMIT := 12

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
		"interaction_stats": interaction_stats,
		"total_companion_seconds": 0.0,
		"last_seen_unix": 0,
		"recent_dialogue_ids": [],
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
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"affection": clampf(float(source.get("affection", fallback.get("affection", DEFAULT_AFFECTION))), 0.0, 100.0),
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
	}

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
