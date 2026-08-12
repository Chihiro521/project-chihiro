class_name PetDialogueDirector
extends RefCounted

const DEFAULT_DATA_PATH := "res://data/dialogue_zh_CN.json"
const SUPPORTED_SCHEMA_VERSION := 1
const RECENT_LIMIT := 12
const EVENT_COOLDOWN_MS := 12000.0
const AMBIENT_MIN_COOLDOWN_MS := 90000.0
const AMBIENT_MAX_COOLDOWN_MS := 240000.0
const TITLE_STABILITY_MS := 2000.0
const TITLE_MAX_LENGTH := 24
const RELATIONSHIP_TIERS := ["distant", "guarded", "familiar", "trusted", "close"]
const TIME_PERIODS := ["morning", "noon", "afternoon", "evening", "late_night"]
const APP_CATEGORIES := ["browser", "code", "terminal", "game", "media", "chat", "office", "art", "files", "other"]
const SENSITIVE_TITLE_MARKERS := [
	"登录", "登入", "密码", "口令", "验证码", "账号", "账户", "银行", "支付",
	"隐私", "无痕", "私密", "login", "log in", "sign in", "password", "passcode",
	"verification", "verify", "auth", "token", "secret", "private", "incognito",
	"bank", "payment", "checkout", "wallet",
]

var entries: Array[Dictionary] = []
var errors: Array[String] = []
var source_path := ""
var next_event_at_ms := -INF
var next_ambient_at_ms := -INF

var _rng := RandomNumberGenerator.new()
var _recent_ids: Array[String] = []
var _observed_title := ""
var _observed_title_since_ms := -INF

func _init(seed: int = 0) -> void:
	if seed == 0:
		_rng.randomize()
	else:
		_rng.seed = seed

static func load_from_file(path: String = DEFAULT_DATA_PATH, seed: int = 0) -> PetDialogueDirector:
	var result := PetDialogueDirector.new(seed)
	result.load_data(path)
	return result

func load_data(path: String = DEFAULT_DATA_PATH) -> bool:
	entries.clear()
	errors.clear()
	source_path = path
	if not FileAccess.file_exists(path):
		errors.append("找不到对话数据：%s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("无法读取对话数据：%s" % path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		errors.append("对话数据不是有效的 JSON 对象")
		return false
	var root: Dictionary = parsed
	if int(root.get("schema_version", root.get("schemaVersion", 0))) != SUPPORTED_SCHEMA_VERSION:
		errors.append("只支持 schema_version: %d" % SUPPORTED_SCHEMA_VERSION)
		return false
	var values = root.get("entries", [])
	if not values is Array:
		errors.append("对话数据 entries 必须是数组")
		return false
	var known_ids := {}
	for index in range(values.size()):
		var value = values[index]
		if not value is Dictionary:
			errors.append("对话条目 %d 不是对象" % index)
			continue
		var normalized := _normalize_entry(value)
		var dialogue_id := str(normalized.get("id", ""))
		if dialogue_id.is_empty() or str(normalized.get("text", "")).is_empty():
			errors.append("对话条目 %d 缺少 id 或 text" % index)
			continue
		if known_ids.has(dialogue_id):
			errors.append("对话 id 重复：%s" % dialogue_id)
			continue
		known_ids[dialogue_id] = true
		entries.append(normalized)
	_expand_relationship_interactions(root.get("relationship_interactions", {}), known_ids)
	return errors.is_empty()

func is_valid() -> bool:
	return errors.is_empty() and not entries.is_empty()

func line_count() -> int:
	return entries.size()

func set_seed(seed: int) -> void:
	_rng.seed = seed

func reset_session(recent_dialogue_ids: Array = []) -> void:
	next_event_at_ms = -INF
	next_ambient_at_ms = -INF
	_observed_title = ""
	_observed_title_since_ms = -INF
	set_recent_dialogue_ids(recent_dialogue_ids)

func set_recent_dialogue_ids(ids: Array) -> void:
	_recent_ids.clear()
	for value in ids:
		var dialogue_id := str(value).strip_edges()
		if not dialogue_id.is_empty() and dialogue_id not in _recent_ids:
			_recent_ids.append(dialogue_id.left(96))
	while _recent_ids.size() > RECENT_LIMIT:
		_recent_ids.pop_front()

func recent_dialogue_ids() -> Array[String]:
	return _recent_ids.duplicate()

func select_line(context: Dictionary, now_ms: float = -1.0, bypass_event_cooldown := false) -> Dictionary:
	if not is_valid():
		return {}
	var now := float(Time.get_ticks_msec()) if now_ms < 0.0 else now_ms
	var normalized := _normalize_context(context, now)
	var event_name := str(normalized.event)
	if event_name == "ambient":
		if now < next_ambient_at_ms:
			return {}
	elif not bypass_event_cooldown and now < next_event_at_ms:
		return {}
	var dedicated_pool: Array[Dictionary] = []
	var tier_pool: Array[Dictionary] = []
	var generic_pool: Array[Dictionary] = []
	for entry in entries:
		if not _matches(entry, normalized):
			continue
		if bool(entry.get("relationship_dedicated", false)):
			dedicated_pool.append(entry)
		elif (entry.relationship_tiers as Array).is_empty():
			generic_pool.append(entry)
		else:
			tier_pool.append(entry)
	# A relationship-specific pool is authoritative. Generic lines only fill a
	# genuine data gap; they never dilute a complete five-tier interaction pool.
	var source_pool: Array[Dictionary] = (
		dedicated_pool
		if not dedicated_pool.is_empty()
		else (tier_pool if not tier_pool.is_empty() else generic_pool)
	)
	var candidates: Array[Dictionary] = []
	var total_weight := 0.0
	for entry in source_pool:
		if str(entry.id) in _recent_ids:
			continue
		var weighted := entry.duplicate(true)
		weighted["_selection_weight"] = _score(entry, normalized)
		if float(weighted._selection_weight) <= 0.0:
			continue
		total_weight += float(weighted._selection_weight)
		candidates.append(weighted)
	# Interaction milestones must always produce feedback. Prefer a line that has
	# not been used recently, but allow the two-line event pool to wrap when the
	# same action happens several times in quick succession.
	if candidates.is_empty() and (bypass_event_cooldown or not dedicated_pool.is_empty() or not tier_pool.is_empty()):
		total_weight = 0.0
		for entry in source_pool:
			var weighted := entry.duplicate(true)
			weighted["_selection_weight"] = _score(entry, normalized)
			if float(weighted._selection_weight) <= 0.0:
				continue
			total_weight += float(weighted._selection_weight)
			candidates.append(weighted)
	if candidates.is_empty() or total_weight <= 0.0:
		return {}
	var cursor := _rng.randf_range(0.0, total_weight)
	var selected: Dictionary = candidates.back()
	for candidate in candidates:
		cursor -= float(candidate._selection_weight)
		if cursor <= 0.0:
			selected = candidate
			break
	var result := {
		"id": str(selected.id),
		"text": _render_text(str(selected.text), normalized),
		"tags": (selected.tags as Array).duplicate(),
	}
	_remember(str(selected.id))
	if event_name == "ambient":
		next_ambient_at_ms = now + _rng.randf_range(AMBIENT_MIN_COOLDOWN_MS, AMBIENT_MAX_COOLDOWN_MS)
	else:
		next_event_at_ms = now + EVENT_COOLDOWN_MS
	return result

func sanitize_window_title(raw_title: String) -> String:
	var cleaned := ""
	for character in raw_title:
		var code := character.unicode_at(0)
		if _is_invisible_control(code):
			continue
		if code < 32 or code == 127 or (code >= 0x80 and code <= 0x9f) or code == 0x3000:
			cleaned += " "
		elif code >= 0xff01 and code <= 0xff5e:
			cleaned += String.chr(code - 0xfee0)
		else:
			cleaned += character
	cleaned = cleaned.strip_edges()
	while cleaned.contains("  "):
		cleaned = cleaned.replace("  ", " ")
	var lowered := cleaned.to_lower()
	for marker in SENSITIVE_TITLE_MARKERS:
		if lowered.contains(marker):
			return ""
	if cleaned.length() > TITLE_MAX_LENGTH:
		cleaned = cleaned.left(TITLE_MAX_LENGTH - 1).strip_edges() + "…"
	return cleaned

func _is_invisible_control(code: int) -> bool:
	return (
		(code >= 0x200b and code <= 0x200f)
		or (code >= 0x202a and code <= 0x202e)
		or (code >= 0x2060 and code <= 0x206f)
		or code == 0xfeff
	)

func observe_window_title(raw_title: String, now_ms: float = -1.0) -> String:
	var now := float(Time.get_ticks_msec()) if now_ms < 0.0 else now_ms
	var cleaned := sanitize_window_title(raw_title)
	if cleaned != _observed_title:
		_observed_title = cleaned
		_observed_title_since_ms = now
		return ""
	if cleaned.is_empty() or now - _observed_title_since_ms < TITLE_STABILITY_MS:
		return ""
	return cleaned

func classify_time_period(hour: int = -1) -> String:
	var resolved_hour := hour
	if resolved_hour < 0:
		resolved_hour = int(Time.get_datetime_dict_from_system().get("hour", 0))
	resolved_hour = posmod(resolved_hour, 24)
	if resolved_hour >= 5 and resolved_hour < 11:
		return "morning"
	if resolved_hour >= 11 and resolved_hour < 14:
		return "noon"
	if resolved_hour >= 14 and resolved_hour < 18:
		return "afternoon"
	if resolved_hour >= 18 and resolved_hour < 23:
		return "evening"
	return "late_night"

func classify_application(app_name: String, safe_title: String = "") -> String:
	var source := (app_name + " " + safe_title).to_lower()
	if _contains_any(source, ["godot", "code", "codium", "idea", "pycharm", "webstorm", "rider", "devenv", "unity", "unreal"]):
		return "code"
	if _contains_any(source, ["powershell", "pwsh", "terminal", "cmd.exe", "windowsterminal", "wezterm", "alacritty"]):
		return "terminal"
	if _contains_any(source, ["chrome", "msedge", "firefox", "brave", "vivaldi", "opera", "browser"]):
		return "browser"
	if _contains_any(source, ["steam", "game", "genshin", "starrail", "zzz", "minecraft"]):
		return "game"
	if _contains_any(source, ["spotify", "music", "vlc", "mpv", "potplayer", "bilibili", "youtube"]):
		return "media"
	if _contains_any(source, ["wechat", "weixin", "qq", "discord", "telegram", "slack", "teams"]):
		return "chat"
	if _contains_any(source, ["word", "excel", "powerpnt", "notion", "obsidian", "onenote", "wps"]):
		return "office"
	if _contains_any(source, ["photoshop", "krita", "blender", "aseprite", "clip studio", "illustrator", "figma"]):
		return "art"
	if _contains_any(source, ["explorer", "files", "文件资源管理器"]):
		return "files"
	return app_name.to_lower() if app_name.to_lower() in APP_CATEGORIES else "other"

func normalize_relationship_tier(value: String) -> String:
	match value.strip_edges().to_lower():
		"distant", "estranged", "疏远": return "distant"
		"wary", "guarded", "戒备": return "guarded"
		"familiar", "熟悉": return "familiar"
		"trust", "trusted", "信任": return "trusted"
		"close", "intimate", "亲近": return "close"
		_: return "familiar"

func _normalize_context(context: Dictionary, now_ms: float) -> Dictionary:
	var raw_app := str(context.get("app_name", ""))
	var stable_title := observe_window_title(str(context.get("window_title", "")), now_ms)
	var explicit_period := str(context.get("time_period", "")).to_lower()
	var requested_tags := _string_array(context.get("tags", []))
	return {
		"event": str(context.get("event", "ambient")).to_lower(),
		"mood": str(context.get("mood", "neutral")).to_lower(),
		"relationship_tier": normalize_relationship_tier(str(context.get("relationship_tier", "familiar"))),
		"irritation": clampf(float(context.get("irritation", 0.0)), 0.0, 100.0),
		"app_name": classify_application(raw_app, stable_title),
		"window_title": stable_title,
		"time_period": explicit_period if explicit_period in TIME_PERIODS else classify_time_period(),
		"tags": requested_tags,
	}

func _normalize_entry(value: Dictionary) -> Dictionary:
	var relationship_tiers: Array[String] = []
	for tier_value in _string_array(value.get("relationship_tiers", [])):
		var tier := normalize_relationship_tier(tier_value)
		if tier not in relationship_tiers:
			relationship_tiers.append(tier)
	return {
		"id": str(value.get("id", "")).strip_edges(),
		"text": str(value.get("text", "")).strip_edges(),
		"tags": _string_array(value.get("tags", [])),
		"events": _string_array(value.get("events", value.get("event", []))),
		"moods": _string_array(value.get("moods", [])),
		"relationship_tiers": relationship_tiers,
		"time_periods": _string_array(value.get("time_periods", [])),
		"app_names": _string_array(value.get("app_names", [])),
		"min_irritation": clampf(float(value.get("min_irritation", 0.0)), 0.0, 100.0),
		"max_irritation": clampf(float(value.get("max_irritation", 100.0)), 0.0, 100.0),
		"requires_window_title": bool(value.get("requires_window_title", false)),
		"relationship_dedicated": bool(value.get("relationship_dedicated", false)),
		"weight": maxf(0.01, float(value.get("weight", 1.0))),
	}

func _expand_relationship_interactions(value: Variant, known_ids: Dictionary) -> void:
	if not value is Dictionary:
		if value != null:
			errors.append("relationship_interactions 必须是对象")
		return
	var root: Dictionary = value
	if root.is_empty():
		return
	var openers_value: Variant = root.get("tier_openers", {})
	var events_value: Variant = root.get("events", {})
	if not openers_value is Dictionary or not events_value is Dictionary:
		errors.append("relationship_interactions 缺少 tier_openers 或 events")
		return
	var openers: Dictionary = openers_value
	var event_map: Dictionary = events_value
	for event_value in event_map.keys():
		var event_name := str(event_value).strip_edges().to_lower()
		var cores: Array[String] = _string_array(event_map[event_value])
		if event_name.is_empty() or cores.size() != 2:
			errors.append("关系互动事件 %s 必须恰好提供两句核心台词" % event_name)
			continue
		for tier in RELATIONSHIP_TIERS:
			var tier_openers: Array[String] = _string_array(openers.get(tier, []))
			if tier_openers.size() != 2:
				errors.append("关系阶段 %s 必须恰好提供两个语气开头" % tier)
				continue
			for line_index in range(2):
				var dialogue_id := "relationship_%s_%s_%d" % [event_name, tier, line_index + 1]
				if known_ids.has(dialogue_id):
					errors.append("对话 id 重复：%s" % dialogue_id)
					continue
				var normalized := _normalize_entry({
					"id": dialogue_id,
					"text": "%s%s" % [tier_openers[line_index], cores[line_index]],
					"events": [event_name],
					"relationship_tiers": [tier],
					"relationship_dedicated": true,
					"tags": ["relationship", "player_interaction"],
				})
				known_ids[dialogue_id] = true
				entries.append(normalized)

func _matches(entry: Dictionary, context: Dictionary) -> bool:
	if not _allows(entry.events, str(context.event)):
		return false
	if not _allows(entry.moods, str(context.mood)):
		return false
	if not _allows(entry.relationship_tiers, str(context.relationship_tier)):
		return false
	if not _allows(entry.time_periods, str(context.time_period)):
		return false
	if not _allows(entry.app_names, str(context.app_name)):
		return false
	if float(context.irritation) < float(entry.min_irritation) or float(context.irritation) > float(entry.max_irritation):
		return false
	if bool(entry.requires_window_title) and str(context.window_title).is_empty():
		return false
	var requested_tags: Array = context.tags
	if not requested_tags.is_empty() and not _has_overlap(entry.tags, requested_tags):
		return false
	return true

func _score(entry: Dictionary, context: Dictionary) -> float:
	var result := float(entry.weight)
	for tag in context.tags:
		if tag in entry.tags:
			result += 2.0
	if not (entry.relationship_tiers as Array).is_empty(): result += 1.0
	if not (entry.time_periods as Array).is_empty(): result += 1.0
	if not (entry.app_names as Array).is_empty(): result += 1.0
	if bool(entry.requires_window_title): result += 1.0
	return result

func _render_text(text: String, context: Dictionary) -> String:
	var title := str(context.window_title)
	return text.replace("{title}", title).replace("{app}", _application_label(str(context.app_name)))

func _remember(dialogue_id: String) -> void:
	_recent_ids.erase(dialogue_id)
	_recent_ids.append(dialogue_id)
	while _recent_ids.size() > RECENT_LIMIT:
		_recent_ids.pop_front()

func _allows(values: Array, value: String) -> bool:
	return values.is_empty() or "any" in values or value in values

func _has_overlap(left: Array, right: Array) -> bool:
	for value in left:
		if value in right:
			return true
	return false

func _contains_any(source: String, needles: Array) -> bool:
	for needle in needles:
		if source.contains(str(needle)):
			return true
	return false

func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is String:
		var text := str(value).strip_edges().to_lower()
		if not text.is_empty(): result.append(text)
	elif value is Array:
		for item in value:
			var text := str(item).strip_edges().to_lower()
			if not text.is_empty() and text not in result: result.append(text)
	return result

func _application_label(category: String) -> String:
	match category:
		"browser": return "浏览器"
		"code": return "开发工具"
		"terminal": return "终端"
		"game": return "游戏"
		"media": return "播放器"
		"chat": return "聊天软件"
		"office": return "文档工具"
		"art": return "创作工具"
		"files": return "文件管理器"
		_: return "这个窗口"
