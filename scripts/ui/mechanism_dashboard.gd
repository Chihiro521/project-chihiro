class_name PetMechanismDashboard
extends Window

const NEED_ORDER := ["energy", "boredom", "curiosity", "irritation", "affection"]
const NEED_LABELS := {
	"energy": "精力",
	"boredom": "无聊",
	"curiosity": "好奇",
	"irritation": "烦躁",
	"affection": "亲密",
}
const NEED_COLORS := {
	"energy": Color("#62d8a6"),
	"boredom": Color("#e9b86d"),
	"curiosity": Color("#70b8f6"),
	"irritation": Color("#ef7c87"),
	"affection": Color("#ee91c2"),
}
const INTERACTION_KEYS := ["head_pats", "pokes", "rough_drags", "positive", "total"]
const MAX_TIMELINE_EVENTS := 24

var _built := false
var _pending_snapshot: Dictionary = {}
var _history_snapshot: Dictionary = {}
var _candidate_signature := ""

var _live_label: Label
var _flow_values: Array[Label] = []
var _relationship_label: Label
var _relationship_detail: Label
var _relationship_bar: ProgressBar
var _need_bars: Dictionary = {}
var _need_values: Dictionary = {}
var _runtime_values: Dictionary = {}
var _environment_values: Dictionary = {}
var _dialogue_values: Dictionary = {}
var _persistence_values: Dictionary = {}
var _settings_label: Label
var _candidate_tree: Tree
var _timeline: ItemList


func _ready() -> void:
	title = "千寻人格机制"
	close_requested.connect(hide)
	_build_ui()
	_built = true
	if not _pending_snapshot.is_empty():
		_apply_snapshot(_pending_snapshot)


func show_dashboard(snapshot: Dictionary = {}) -> void:
	if not snapshot.is_empty():
		set_snapshot(snapshot)
	show()
	if position == Vector2i.ZERO:
		popup_centered(size)
	grab_focus()


func set_snapshot(snapshot: Dictionary) -> void:
	_pending_snapshot = snapshot.duplicate(true)
	if not _built:
		return
	_apply_snapshot(snapshot)


func _build_ui() -> void:
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", _panel_style(Color("#0b1017"), Color("#263543"), 0))
	add_child(background)

	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 18)
	outer.add_theme_constant_override("margin_right", 18)
	outer.add_theme_constant_override("margin_top", 15)
	outer.add_theme_constant_override("margin_bottom", 13)
	background.add_child(outer)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	outer.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root.add_child(header)
	var heading := _make_label("千寻人格机制监视器", Color("#f3f7fb"), 25)
	header.add_child(heading)
	var subtitle := _make_label("把隐藏属性、行为评分与存档回写摊开来看", Color("#8da2b6"), 14)
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(subtitle)
	_live_label = _make_label("● 等待运行数据", Color("#778b9e"), 13)
	_live_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_live_label)

	root.add_child(HSeparator.new())
	_build_flow(root)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	root.add_child(body)
	_build_needs_column(body)
	_build_director_column(body)
	_build_observation_column(body)
	_build_timeline(root)

	var footer := _make_label(
		"只读监视器 · 窗口标题只在当前画面即时显示，不进入事件记录、日志或存档",
		Color("#708498"),
		12,
	)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(footer)


func _build_flow(parent: VBoxContainer) -> void:
	var flow := HBoxContainer.new()
	flow.add_theme_constant_override("separation", 6)
	parent.add_child(flow)
	var stages := [
		["01", "环境感知", "窗口 / 时间 / 互动"],
		["02", "隐藏属性", "五项需求持续演化"],
		["03", "行为评分", "权重 / 条件 / 冷却"],
		["04", "动作状态机", "抢占与动作会话"],
		["05", "可见输出", "动画 / 气泡 / 音效"],
		["06", "关系与记忆", "亲密度 / 统计 / 存档"],
	]
	for index in range(stages.size()):
		var data: Array = stages[index]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0.0, 78.0)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", _panel_style(Color("#121a24"), Color("#28384a"), 9))
		flow.add_child(panel)
		var margin := _margin(9, 9, 7, 7)
		panel.add_child(margin)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 1)
		margin.add_child(column)
		var stage_heading := _make_label("%s  %s" % [str(data[0]), str(data[1])], Color("#78d9ae"), 13)
		column.add_child(stage_heading)
		var value := _make_label(str(data[2]), Color("#aebdcb"), 12)
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.max_lines_visible = 2
		column.add_child(value)
		_flow_values.append(value)
		if index < stages.size() - 1:
			var arrow := _make_label("→", Color("#52677a"), 17)
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			flow.add_child(arrow)


func _build_needs_column(parent: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 292.0
	column.add_theme_constant_override("separation", 10)
	parent.add_child(column)

	var relation := _card(column, "关系", "长期保存，可升也可降")
	_relationship_label = _make_label("—", Color("#f2d1e4"), 24)
	relation.add_child(_relationship_label)
	_relationship_detail = _make_label("等待亲密度数据", Color("#9eafbf"), 13)
	_relationship_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	relation.add_child(_relationship_detail)
	_relationship_bar = _make_progress(Color("#ee91c2"), 18.0)
	relation.add_child(_relationship_bar)

	var needs := _card(column, "隐藏属性", "全部限制在 0–100")
	needs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for need_name in NEED_ORDER:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		needs.add_child(row)
		var heading := HBoxContainer.new()
		row.add_child(heading)
		var label := _make_label(str(NEED_LABELS[need_name]), Color("#c9d5e1"), 13)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(label)
		var value := _make_label("—", Color(NEED_COLORS[need_name]), 13)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		heading.add_child(value)
		var bar := _make_progress(Color(NEED_COLORS[need_name]), 14.0)
		row.add_child(bar)
		_need_values[need_name] = value
		_need_bars[need_name] = bar
	var rates := _make_label("清醒：精力下降、无聊上升；烦躁与好奇会自行消退。", Color("#71869a"), 12)
	rates.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	needs.add_child(rates)


func _build_director_column(parent: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 500.0
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	parent.add_child(column)

	var runtime := _card(column, "当前执行链", "真实状态机与 ActionSession")
	_runtime_values = _detail_grid(runtime, [
		["状态", "state"], ["意图", "intent"], ["动画", "clip"],
		["会话阶段", "phase"], ["心情", "mood"], ["抢占优先级", "priority"],
	], 84.0)

	var candidates := _card(column, "行为评分候选", "显示 16 个行为的实时分数、条件与冷却")
	candidates.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_candidate_tree = Tree.new()
	_candidate_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_candidate_tree.custom_minimum_size.y = 245.0
	_candidate_tree.columns = 4
	_candidate_tree.hide_root = true
	_candidate_tree.column_titles_visible = true
	_candidate_tree.set_column_title(0, "行为意图")
	_candidate_tree.set_column_title(1, "分数")
	_candidate_tree.set_column_title(2, "状态")
	_candidate_tree.set_column_title(3, "动画片段")
	_candidate_tree.set_column_expand(0, true)
	_candidate_tree.set_column_expand(1, false)
	_candidate_tree.set_column_expand(2, false)
	_candidate_tree.set_column_expand(3, true)
	_candidate_tree.set_column_custom_minimum_width(1, 62)
	_candidate_tree.set_column_custom_minimum_width(2, 96)
	_candidate_tree.add_theme_font_size_override("font_size", 12)
	candidates.add_child(_candidate_tree)


func _build_observation_column(parent: HBoxContainer) -> void:
	var shell := PanelContainer.new()
	shell.custom_minimum_size.x = 356.0
	shell.add_theme_stylebox_override("panel", _panel_style(Color("#0f161f"), Color("#263647"), 10))
	parent.add_child(shell)
	var shell_margin := _margin(10, 10, 10, 10)
	shell.add_child(shell_margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell_margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 324.0
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)

	var environment := _subsection(column, "环境感知")
	_environment_values = _detail_grid(environment, [
		["前台应用", "app"], ["应用类别", "category"], ["即时安全标题", "title"],
		["上次稳定标题", "stable_title"], ["可站平台", "platform_count"], ["乘坐平台", "active_platform"],
	], 90.0)

	var dialogue := _subsection(column, "气泡与台词")
	_dialogue_values = _detail_grid(dialogue, [
		["当前气泡", "bubble"], ["台词内容", "text"], ["事件冷却", "event_cooldown"],
		["日常倒计时", "ambient_countdown"], ["近期去重", "recent"],
	], 90.0)

	var persistence := _subsection(column, "关系存档")
	_persistence_values = _detail_grid(persistence, [
		["存档状态", "status"], ["上次写入", "last_save"], ["下次写入", "next_save"],
		["累计陪伴", "total_time"], ["本次运行", "session_time"], ["待写入", "pending_time"],
		["互动统计", "stats"], ["存档路径", "path"],
	], 90.0)

	var settings := _subsection(column, "运行开关")
	_settings_label = _make_label("等待设置数据", Color("#aebdcb"), 12)
	_settings_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings.add_child(_settings_label)


func _build_timeline(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 132.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#101821"), Color("#263747"), 9))
	parent.add_child(panel)
	var margin := _margin(11, 11, 8, 8)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title_label := _make_label("最近机制变化", Color("#e5edf5"), 14)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title_label)
	var hint := _make_label("仅保留本次面板会话的 24 条；不记录窗口标题", Color("#6f8498"), 11)
	heading.add_child(hint)
	_timeline = ItemList.new()
	_timeline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_timeline.add_theme_font_size_override("font_size", 12)
	column.add_child(_timeline)
	_append_timeline("监视器已连接，等待第一份运行快照")


func _apply_snapshot(snapshot: Dictionary) -> void:
	_live_label.text = "● 实时 5 Hz  ·  %s" % Time.get_time_string_from_system()
	_live_label.add_theme_color_override("font_color", Color("#63d69d"))
	var needs := _dictionary(snapshot.get("needs", {}))
	var relationship_tier := str(snapshot.get("relationship_tier", "familiar"))
	var affection := clampf(float(needs.get("affection", snapshot.get("affection", 40.0))), 0.0, 100.0)
	_update_relationship(relationship_tier, affection)
	for need_name in NEED_ORDER:
		var amount := clampf(float(needs.get(need_name, 0.0)), 0.0, 100.0)
		(_need_bars[need_name] as ProgressBar).value = amount
		(_need_values[need_name] as Label).text = "%5.1f" % amount

	var session := _dictionary(snapshot.get("session", {}))
	_set_values(_runtime_values, {
		"state": _display_or_dash(snapshot.get("state", "")),
		"intent": _display_or_dash(snapshot.get("intent", "")),
		"clip": _display_or_dash(snapshot.get("clip", "")),
		"phase": _display_or_dash(session.get("phase", "inactive")),
		"mood": mood_label(str(snapshot.get("mood", "neutral"))),
		"priority": "%d  ·  %s" % [int(session.get("priority", 0)), priority_label(int(session.get("priority", 0)))],
	})

	var environment := _dictionary(snapshot.get("environment", {}))
	_set_values(_environment_values, {
		"app": _display_or_dash(environment.get("app", "")),
		"category": application_label(str(environment.get("category", "other"))),
		"title": _title_display(environment.get("title", ""), bool(environment.get("title_awareness", false))),
		"stable_title": _title_display(environment.get("stable_title", ""), bool(environment.get("title_awareness", false))),
		"platform_count": "%d 个可站立区段" % int(environment.get("platform_count", 0)),
		"active_platform": _display_or_dash(environment.get("active_platform", "")),
	})

	var dialogue := _dictionary(snapshot.get("dialogue", {}))
	var bubble := _dictionary(snapshot.get("bubble", {}))
	_set_values(_dialogue_values, {
		"bubble": "显示中 · %s" % _display_or_dash(bubble.get("id", "")) if bool(bubble.get("visible", false)) else "当前没有气泡",
		"text": _display_or_dash(bubble.get("text", "")),
		"event_cooldown": _countdown(float(dialogue.get("event_cooldown_seconds", 0.0))),
		"ambient_countdown": _countdown(float(dialogue.get("ambient_seconds", 0.0))),
		"recent": _join_recent(dialogue.get("recent_ids", [])),
	})

	var persistence := _dictionary(snapshot.get("persistence", {}))
	var stats := _dictionary(persistence.get("stats", {}))
	var save_error := str(persistence.get("last_error", "")).strip_edges()
	_set_values(_persistence_values, {
		"status": "正常 · 原子替换写入" if save_error.is_empty() else "注意：%s" % save_error,
		"last_save": _format_unix_time(int(persistence.get("last_saved_unix", 0))),
		"next_save": _countdown(float(persistence.get("next_save_seconds", 0.0))),
		"total_time": format_duration(float(persistence.get("total_companion_seconds", 0.0))),
		"session_time": format_duration(float(persistence.get("session_seconds", 0.0))),
		"pending_time": format_duration(float(persistence.get("pending_seconds", 0.0))),
		"stats": "摸头 %d · 戳刺 %d · 粗暴拖拽 %d\n正向 %d · 总互动 %d" % [
			int(stats.get("head_pats", 0)), int(stats.get("pokes", 0)), int(stats.get("rough_drags", 0)),
			int(stats.get("positive", 0)), int(stats.get("total", 0)),
		],
		"path": _display_or_dash(persistence.get("path", "")),
	})

	var settings := _dictionary(snapshot.get("settings", {}))
	_settings_label.text = "自主闲逛 %s  ·  光标跟随 %s\n气泡 %s  ·  标题感知 %s  ·  音效 %s" % [
		_on_off(settings.get("auto_wander", false)),
		_on_off(settings.get("cursor_tracking", false)),
		_on_off(settings.get("speech_bubbles", false)),
		_on_off(settings.get("title_awareness", false)),
		_on_off(settings.get("action_sounds", false)),
	]
	_update_candidates(snapshot.get("candidates", []), str(snapshot.get("intent", "")))
	_update_flow(snapshot, needs, environment, bubble, persistence)
	for event_text in describe_snapshot_changes(_history_snapshot, snapshot):
		_append_timeline(event_text)
	_history_snapshot = history_safe_snapshot(snapshot)


func _update_relationship(tier: String, affection: float) -> void:
	_relationship_label.text = "%s  ·  %.1f" % [relationship_label(tier), affection]
	_relationship_bar.value = affection
	var next_threshold := next_relationship_threshold(affection)
	if affection >= 80.0:
		_relationship_detail.text = "已进入最高关系阶段；亲密度仍会真实升降。"
	else:
		_relationship_detail.text = "距离「%s」还差 %.1f" % [relationship_label(relationship_tier_for(next_threshold)), next_threshold - affection]


func _update_flow(snapshot: Dictionary, needs: Dictionary, environment: Dictionary, bubble: Dictionary, persistence: Dictionary) -> void:
	var candidates_value: Variant = snapshot.get("candidates", [])
	var top_candidate := "没有可选行为"
	if candidates_value is Array:
		for value in candidates_value:
			if value is Dictionary and bool(value.get("eligible", false)):
				top_candidate = "%s  %.2f" % [str(value.get("id", "?")), float(value.get("score", 0.0))]
				break
	_flow_values[0].text = "%s · %d 个平台" % [_display_or_dash(environment.get("app", "")), int(environment.get("platform_count", 0))]
	_flow_values[1].text = "%s · 精力 %.0f / 无聊 %.0f" % [mood_label(str(snapshot.get("mood", "neutral"))), float(needs.get("energy", 0.0)), float(needs.get("boredom", 0.0))]
	_flow_values[2].text = top_candidate
	var session := _dictionary(snapshot.get("session", {}))
	_flow_values[3].text = "%s · %s" % [_display_or_dash(snapshot.get("state", "")), _display_or_dash(session.get("phase", ""))]
	_flow_values[4].text = "%s%s" % [
		_display_or_dash(snapshot.get("clip", "")),
		" · 气泡显示中" if bool(bubble.get("visible", false)) else "",
	]
	_flow_values[5].text = "%s · 下次写入 %s" % [relationship_label(str(snapshot.get("relationship_tier", ""))), _countdown(float(persistence.get("next_save_seconds", 0.0)))]


func _update_candidates(value: Variant, current_intent: String) -> void:
	if not value is Array:
		return
	var signature_parts: Array[String] = [current_intent]
	for candidate_value in value:
		if candidate_value is Dictionary:
			signature_parts.append("%s|%.1f|%s" % [
				str(candidate_value.get("id", "")),
				float(candidate_value.get("score", 0.0)),
				str(candidate_value.get("status", "")),
			])
	var signature := ";".join(signature_parts)
	if signature == _candidate_signature:
		return
	_candidate_signature = signature
	_candidate_tree.clear()
	var root := _candidate_tree.create_item()
	for candidate_value in value:
		if not candidate_value is Dictionary:
			continue
		var candidate: Dictionary = candidate_value
		var item := _candidate_tree.create_item(root)
		var intent_id := str(candidate.get("id", "?"))
		item.set_text(0, ("▶  " if intent_id == current_intent else "") + intent_id)
		item.set_text(1, "%.2f" % float(candidate.get("score", 0.0)))
		item.set_text(2, str(candidate.get("status", "")))
		item.set_text(3, _display_or_dash(candidate.get("clip", "")))
		var color := Color("#70dca8") if bool(candidate.get("eligible", false)) else Color("#7c8fa2")
		if not bool(candidate.get("selectable", true)):
			color = Color("#7fb5e8")
		if intent_id == current_intent:
			color = Color("#f0c776")
		for column in range(4):
			item.set_custom_color(column, color)
			item.set_selectable(column, false)
		item.set_tooltip_text(0, "%s · %s" % [intent_id, str(candidate.get("status", ""))])


func _append_timeline(event_text: String) -> void:
	if _timeline == null or event_text.strip_edges().is_empty():
		return
	_timeline.add_item("%s  %s" % [Time.get_time_string_from_system(), event_text])
	while _timeline.item_count > MAX_TIMELINE_EVENTS:
		_timeline.remove_item(0)
	_timeline.select(_timeline.item_count - 1)
	_timeline.ensure_current_is_visible()


func _card(parent: Container, heading_text: String, caption_text: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#111923"), Color("#273748"), 9))
	parent.add_child(panel)
	var margin := _margin(11, 11, 9, 9)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var label := _make_label(heading_text, Color("#e4edf5"), 15)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	var caption := _make_label(caption_text, Color("#71869a"), 11)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(caption)
	return column


func _subsection(parent: Container, heading_text: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#121b25"), Color("#263747"), 7))
	parent.add_child(panel)
	var margin := _margin(9, 9, 8, 8)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	column.add_child(_make_label(heading_text, Color("#78d9ae"), 14))
	return column


func _detail_grid(parent: Container, specifications: Array, key_width: float) -> Dictionary:
	var result: Dictionary = {}
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	for value in specifications:
		if not value is Array or value.size() < 2:
			continue
		var key_label := _make_label(str(value[0]), Color("#71869a"), 12)
		key_label.custom_minimum_size.x = key_width
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		grid.add_child(key_label)
		var content := _make_label("—", Color("#c9d5e1"), 12)
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(content)
		result[str(value[1])] = content
	return result


func _set_values(target: Dictionary, values: Dictionary) -> void:
	for key in values.keys():
		if target.has(key):
			(target[key] as Label).text = str(values[key])


func _make_label(text_value: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _make_progress(color: Color, minimum_height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = minimum_height
	bar.add_theme_stylebox_override("background", _panel_style(Color("#202b36"), Color("#2b3947"), int(minimum_height / 2.0)))
	bar.add_theme_stylebox_override("fill", _panel_style(color, color, int(minimum_height / 2.0)))
	return bar


func _margin(left: int, right: int, top: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


func _dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _display_or_dash(value: Variant) -> String:
	var text_value := str(value).strip_edges()
	return text_value if not text_value.is_empty() else "—"


func _title_display(value: Variant, enabled: bool) -> String:
	if not enabled:
		return "已关闭"
	var text_value := str(value).strip_edges()
	return text_value if not text_value.is_empty() else "等待稳定或已隐私过滤"


func _countdown(seconds: float) -> String:
	if seconds <= 0.05:
		return "可立即触发"
	return "%.1f 秒" % seconds


func _join_recent(value: Variant) -> String:
	if not value is Array or value.is_empty():
		return "尚无记录"
	var recent: Array[String] = []
	var start := maxi(0, value.size() - 5)
	for index in range(start, value.size()):
		recent.append(str(value[index]))
	return " · ".join(recent)


func _on_off(value: Variant) -> String:
	return "开启" if bool(value) else "关闭"


static func relationship_label(tier: String) -> String:
	match tier:
		"distant": return "疏远"
		"guarded", "wary": return "戒备"
		"familiar": return "熟悉"
		"trusted", "trust": return "信任"
		"close": return "亲近"
		_: return "未判定"


static func relationship_tier_for(affection: float) -> String:
	if affection >= 80.0: return "close"
	if affection >= 60.0: return "trusted"
	if affection >= 40.0: return "familiar"
	if affection >= 20.0: return "guarded"
	return "distant"


static func next_relationship_threshold(affection: float) -> float:
	for threshold in [20.0, 40.0, 60.0, 80.0]:
		if affection < threshold:
			return threshold
	return 100.0


static func mood_label(mood: String) -> String:
	match mood:
		"irritated": return "烦躁"
		"tired": return "疲倦"
		"curious": return "好奇"
		"bored": return "无聊"
		_: return "平静"


static func priority_label(priority: int) -> String:
	if priority >= 700: return "全屏暂停"
	if priority >= 600: return "拖拽"
	if priority >= 500: return "平台丢失"
	if priority >= 400: return "菜单 / 互动"
	if priority >= 300: return "窗口移动"
	if priority >= 200: return "自主行为"
	if priority >= 100: return "注视 / 眨眼"
	return "无活动会话"


static func application_label(category: String) -> String:
	match category:
		"browser": return "浏览器"
		"code": return "开发工具"
		"terminal": return "终端"
		"game": return "游戏"
		"media": return "媒体播放"
		"chat": return "聊天软件"
		"office": return "文档工具"
		"art": return "创作工具"
		"files": return "文件管理"
		_: return "其他"


static func merge_interaction_stats(base: Dictionary, delta: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in INTERACTION_KEYS:
		result[key] = maxi(0, int(base.get(key, 0)) + int(delta.get(key, 0)))
	return result


static func format_duration(seconds: float) -> String:
	var total_seconds := maxi(0, int(floor(seconds)))
	var hours := total_seconds / 3600
	var minutes := (total_seconds % 3600) / 60
	var remaining_seconds := total_seconds % 60
	if hours > 0:
		return "%d 小时 %02d 分" % [hours, minutes]
	if minutes > 0:
		return "%d 分 %02d 秒" % [minutes, remaining_seconds]
	return "%d 秒" % remaining_seconds


static func history_safe_snapshot(snapshot: Dictionary) -> Dictionary:
	var result := snapshot.duplicate(true)
	var environment_value: Variant = result.get("environment", {})
	if environment_value is Dictionary:
		var environment: Dictionary = environment_value
		environment.erase("title")
		environment.erase("stable_title")
		result["environment"] = environment
	return result


static func describe_snapshot_changes(previous: Dictionary, current: Dictionary) -> Array[String]:
	var events: Array[String] = []
	if previous.is_empty():
		return events
	var previous_state := str(previous.get("state", ""))
	var current_state := str(current.get("state", ""))
	if previous_state != current_state:
		events.append("状态机：%s → %s" % [_dash(previous_state), _dash(current_state)])
	var previous_intent := str(previous.get("intent", ""))
	var current_intent := str(current.get("intent", ""))
	if previous_intent != current_intent:
		events.append("行为意图：%s → %s" % [_dash(previous_intent), _dash(current_intent)])
	var previous_tier := str(previous.get("relationship_tier", ""))
	var current_tier := str(current.get("relationship_tier", ""))
	if previous_tier != current_tier:
		events.append("关系阶段：%s → %s" % [relationship_label(previous_tier), relationship_label(current_tier)])
	var previous_needs := _static_dictionary(previous.get("needs", {}))
	var current_needs := _static_dictionary(current.get("needs", {}))
	var previous_affection := float(previous_needs.get("affection", previous.get("affection", 0.0)))
	var current_affection := float(current_needs.get("affection", current.get("affection", 0.0)))
	if absf(previous_affection - current_affection) >= 0.05:
		events.append("亲密度：%.1f → %.1f" % [previous_affection, current_affection])
	var previous_bubble := _static_dictionary(previous.get("bubble", {}))
	var current_bubble := _static_dictionary(current.get("bubble", {}))
	var previous_bubble_id := str(previous_bubble.get("id", ""))
	var current_bubble_id := str(current_bubble.get("id", ""))
	if previous_bubble_id != current_bubble_id:
		events.append("气泡：%s" % ("结束" if current_bubble_id.is_empty() else "显示 %s" % current_bubble_id))
	var previous_environment := _static_dictionary(previous.get("environment", {}))
	var current_environment := _static_dictionary(current.get("environment", {}))
	var previous_app := str(previous_environment.get("app", ""))
	var current_app := str(current_environment.get("app", ""))
	if previous_app != current_app:
		events.append("前台应用：%s → %s" % [_dash(previous_app), _dash(current_app)])
	var previous_platform_count := int(previous_environment.get("platform_count", 0))
	var current_platform_count := int(current_environment.get("platform_count", 0))
	if previous_platform_count != current_platform_count:
		events.append("窗口平台：%d → %d 个区段" % [previous_platform_count, current_platform_count])
	var previous_platform := str(previous_environment.get("active_platform", ""))
	var current_platform := str(current_environment.get("active_platform", ""))
	if previous_platform != current_platform:
		events.append("乘坐平台：%s → %s" % [_dash(previous_platform), _dash(current_platform)])
	var previous_persistence := _static_dictionary(previous.get("persistence", {}))
	var current_persistence := _static_dictionary(current.get("persistence", {}))
	var previous_saved := int(previous_persistence.get("last_saved_unix", 0))
	var current_saved := int(current_persistence.get("last_saved_unix", 0))
	if current_saved > 0 and previous_saved != current_saved:
		events.append("关系与统计已回写存档")
	return events


static func _static_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _dash(value: String) -> String:
	return value if not value.is_empty() else "—"


static func _format_unix_time(unix_time: int) -> String:
	if unix_time <= 0:
		return "尚未写入"
	var timezone := Time.get_time_zone_from_system()
	var local_unix_time := unix_time + int(timezone.get("bias", 0)) * 60
	var value := Time.get_datetime_dict_from_unix_time(local_unix_time)
	return "%04d-%02d-%02d  %02d:%02d:%02d" % [
		int(value.get("year", 0)), int(value.get("month", 0)), int(value.get("day", 0)),
		int(value.get("hour", 0)), int(value.get("minute", 0)), int(value.get("second", 0)),
	]
