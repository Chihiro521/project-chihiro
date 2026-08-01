class_name PetActionCatalogPanel
extends Window

const DEFAULT_CATALOG_PATH := "res://data/action_catalog_zh_CN.json"
const DEFAULT_PROFILE_PATH := "res://data/behavior_profile.json"

enum CatalogFilter {
	ALL,
	LIFE,
	SYSTEM,
	DIRECTOR,
	LOOP,
	ONE_SHOT,
}

var manifest: PetManifestData
var catalog: Dictionary = {}
var profile: Dictionary = {}

var _labels: Dictionary = {}
var _behavior_map: Dictionary = {}
var _selected_clip := ""
var _selected_family: Dictionary = {}
var _frame_index := 0
var _elapsed_in_frame_ms := 0.0
var _playing := true
var _speed := 1.0
var _preview_loop := true
var _updating_timeline := false
var _textures: Dictionary = {}

var _summary_label: Label
var _search: LineEdit
var _filter: OptionButton
var _tree: Tree
var _preview: PetActionPreviewCanvas
var _title_label: Label
var _clip_id_label: Label
var _info: RichTextLabel
var _play_button: Button
var _timeline: HSlider
var _frame_label: Label
var _guides_toggle: CheckButton
var _loop_toggle: CheckButton

func _ready() -> void:
	title = "千寻动作总览"
	close_requested.connect(hide)
	_build_ui()
	set_process(true)

func configure(value: PetManifestData, catalog_path := DEFAULT_CATALOG_PATH, profile_path := DEFAULT_PROFILE_PATH) -> void:
	manifest = value
	catalog = _load_dictionary(catalog_path)
	profile = _load_dictionary(profile_path)
	_labels = catalog.get("labels", {})
	_behavior_map = build_behavior_clip_map(profile)
	_rebuild_tree()
	_update_summary()
	if _selected_clip.is_empty():
		_select_first_visible_clip()

func show_catalog() -> void:
	if manifest == null:
		return
	show()
	if position == Vector2i.ZERO:
		popup_centered(size)
	grab_focus()
	if _selected_clip.is_empty():
		_select_first_visible_clip()

func _build_ui() -> void:
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", _panel_style(Color("#0d1117"), Color("#263241"), 0))
	add_child(background)

	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 18)
	outer_margin.add_theme_constant_override("margin_right", 18)
	outer_margin.add_theme_constant_override("margin_top", 16)
	outer_margin.add_theme_constant_override("margin_bottom", 14)
	background.add_child(outer_margin)

	var root_column := VBoxContainer.new()
	root_column.add_theme_constant_override("separation", 12)
	outer_margin.add_child(root_column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root_column.add_child(header)
	var heading := Label.new()
	heading.text = "千寻动作总览"
	heading.add_theme_font_size_override("font_size", 25)
	heading.add_theme_color_override("font_color", Color("#f2f6fb"))
	header.add_child(heading)
	_summary_label = Label.new()
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_summary_label.add_theme_font_size_override("font_size", 14)
	_summary_label.add_theme_color_override("font_color", Color("#92a6ba"))
	header.add_child(_summary_label)
	var hint := Label.new()
	hint.text = "右键/托盘打开 · Space 播放 · ← → 逐帧"
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("#6f8296"))
	header.add_child(hint)

	var divider := HSeparator.new()
	root_column.add_child(divider)

	var body := HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.split_offset = 310
	body.add_theme_constant_override("separation", 14)
	root_column.add_child(body)

	var browser_panel := PanelContainer.new()
	browser_panel.custom_minimum_size = Vector2(300.0, 0.0)
	browser_panel.add_theme_stylebox_override("panel", _panel_style(Color("#121923"), Color("#253344"), 10))
	body.add_child(browser_panel)
	var browser_margin := MarginContainer.new()
	browser_margin.add_theme_constant_override("margin_left", 12)
	browser_margin.add_theme_constant_override("margin_right", 12)
	browser_margin.add_theme_constant_override("margin_top", 12)
	browser_margin.add_theme_constant_override("margin_bottom", 12)
	browser_panel.add_child(browser_margin)
	var browser_column := VBoxContainer.new()
	browser_column.add_theme_constant_override("separation", 9)
	browser_margin.add_child(browser_column)

	_search = LineEdit.new()
	_search.placeholder_text = "搜索中文动作名或 clip id…"
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_text: String) -> void: _rebuild_tree())
	browser_column.add_child(_search)

	_filter = OptionButton.new()
	_filter.add_item("全部动作", CatalogFilter.ALL)
	_filter.add_item("16 个生活行为族", CatalogFilter.LIFE)
	_filter.add_item("系统动作", CatalogFilter.SYSTEM)
	_filter.add_item("行为导演已映射", CatalogFilter.DIRECTOR)
	_filter.add_item("循环片段", CatalogFilter.LOOP)
	_filter.add_item("一次性片段", CatalogFilter.ONE_SHOT)
	_filter.item_selected.connect(func(_index: int) -> void: _rebuild_tree())
	browser_column.add_child(_filter)

	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.columns = 2
	_tree.hide_root = true
	_tree.column_titles_visible = true
	_tree.set_column_title(0, "行为族 / 动作片段")
	_tree.set_column_title(1, "运行类型")
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, 82)
	_tree.item_selected.connect(_on_tree_item_selected)
	browser_column.add_child(_tree)

	var detail_column := VBoxContainer.new()
	detail_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_column.add_theme_constant_override("separation", 10)
	body.add_child(detail_column)

	var selected_header := VBoxContainer.new()
	selected_header.add_theme_constant_override("separation", 1)
	detail_column.add_child(selected_header)
	_title_label = Label.new()
	_title_label.text = "选择一个动作"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color("#f2f6fb"))
	selected_header.add_child(_title_label)
	_clip_id_label = Label.new()
	_clip_id_label.add_theme_font_size_override("font_size", 13)
	_clip_id_label.add_theme_color_override("font_color", Color("#72e6a1"))
	selected_header.add_child(_clip_id_label)

	var preview_and_info := HSplitContainer.new()
	preview_and_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_and_info.split_offset = 390
	preview_and_info.add_theme_constant_override("separation", 12)
	detail_column.add_child(preview_and_info)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(340.0, 340.0)
	preview_panel.add_theme_stylebox_override("panel", _panel_style(Color("#11161d"), Color("#2c3b4c"), 10))
	preview_and_info.add_child(preview_panel)
	_preview = PetActionPreviewCanvas.new()
	preview_panel.add_child(_preview)

	var info_panel := PanelContainer.new()
	info_panel.custom_minimum_size = Vector2(240.0, 0.0)
	info_panel.add_theme_stylebox_override("panel", _panel_style(Color("#121923"), Color("#253344"), 10))
	preview_and_info.add_child(info_panel)
	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 14)
	info_margin.add_theme_constant_override("margin_right", 14)
	info_margin.add_theme_constant_override("margin_top", 12)
	info_margin.add_theme_constant_override("margin_bottom", 12)
	info_panel.add_child(info_margin)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = false
	_info.scroll_active = true
	_info.add_theme_font_size_override("normal_font_size", 14)
	_info.add_theme_color_override("default_color", Color("#c9d5e2"))
	info_margin.add_child(_info)

	var playback := HBoxContainer.new()
	playback.add_theme_constant_override("separation", 8)
	detail_column.add_child(playback)
	var previous_button := Button.new()
	previous_button.text = "上一帧"
	previous_button.pressed.connect(func() -> void: _step_frame(-1))
	playback.add_child(previous_button)
	_play_button = Button.new()
	_play_button.text = "暂停"
	_play_button.custom_minimum_size.x = 76.0
	_play_button.pressed.connect(_toggle_playback)
	playback.add_child(_play_button)
	var next_button := Button.new()
	next_button.text = "下一帧"
	next_button.pressed.connect(func() -> void: _step_frame(1))
	playback.add_child(next_button)

	_timeline = HSlider.new()
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline.min_value = 0.0
	_timeline.step = 1.0
	_timeline.value_changed.connect(_on_timeline_changed)
	playback.add_child(_timeline)
	_frame_label = Label.new()
	_frame_label.custom_minimum_size.x = 84.0
	_frame_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	playback.add_child(_frame_label)

	var speed_selector := OptionButton.new()
	speed_selector.add_item("0.5×", 0)
	speed_selector.add_item("1×", 1)
	speed_selector.add_item("2×", 2)
	speed_selector.select(1)
	speed_selector.item_selected.connect(func(index: int) -> void:
		_speed = [0.5, 1.0, 2.0][index]
	)
	playback.add_child(speed_selector)

	_guides_toggle = CheckButton.new()
	_guides_toggle.text = "锚点/接触线"
	_guides_toggle.button_pressed = true
	_guides_toggle.toggled.connect(func(value: bool) -> void: _preview.set_guides_visible(value))
	playback.add_child(_guides_toggle)
	_loop_toggle = CheckButton.new()
	_loop_toggle.text = "循环预览"
	_loop_toggle.button_pressed = true
	_loop_toggle.toggled.connect(func(value: bool) -> void: _preview_loop = value)
	playback.add_child(_loop_toggle)

	var footer := Label.new()
	footer.text = "黄色：可见边界  ·  粉色：命中区  ·  蓝色：锚点  ·  绿色：逐帧平台支撑点"
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", Color("#7e91a5"))
	root_column.add_child(footer)

func _process(delta: float) -> void:
	if not visible or not _playing or manifest == null or _selected_clip.is_empty():
		return
	var clip := manifest.clip(_selected_clip)
	var frames: Array = clip.get("frames", [])
	if frames.is_empty():
		return
	_elapsed_in_frame_ms += delta * 1000.0 * _speed
	var advanced := false
	while _elapsed_in_frame_ms >= _frame_duration(clip, _frame_index):
		_elapsed_in_frame_ms -= _frame_duration(clip, _frame_index)
		if _frame_index + 1 < frames.size():
			_frame_index += 1
			advanced = true
		elif bool(clip.get("loop", false)) or _preview_loop:
			_frame_index = 0
			advanced = true
		else:
			_playing = false
			_elapsed_in_frame_ms = 0.0
			_update_play_button()
			break
	if advanced:
		_apply_selected_frame()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			_toggle_playback()
			set_input_as_handled()
		KEY_LEFT:
			_step_frame(-1)
			set_input_as_handled()
		KEY_RIGHT:
			_step_frame(1)
			set_input_as_handled()
		KEY_ESCAPE:
			hide()
			set_input_as_handled()
		KEY_F:
			if key.ctrl_pressed:
				_search.grab_focus()
				_search.select_all()
				set_input_as_handled()

func _rebuild_tree() -> void:
	if _tree == null:
		return
	_tree.clear()
	var root := _tree.create_item()
	var query := _search.text.strip_edges().to_lower() if _search != null else ""
	var filter_id := _filter.get_selected_id() if _filter != null else CatalogFilter.ALL
	var first_clip_item: TreeItem
	var selected_item: TreeItem
	for family_value in catalog.get("families", []):
		if not family_value is Dictionary:
			continue
		var family: Dictionary = family_value
		var matching_clips: Array[String] = []
		for clip_value in family.get("clips", []):
			var clip_name := str(clip_value)
			if _clip_matches(clip_name, family, query, filter_id):
				matching_clips.append(clip_name)
		if matching_clips.is_empty():
			continue
		var family_item := _tree.create_item(root)
		var family_prefix := "%02d" % int(family.get("index", 0)) if str(family.get("kind", "")) == "life" else "SYS"
		family_item.set_text(0, "%s  %s" % [family_prefix, str(family.get("label", family.get("id", "?")))])
		family_item.set_text(1, "%d 个片段" % matching_clips.size())
		family_item.set_selectable(0, false)
		family_item.set_selectable(1, false)
		family_item.set_custom_color(0, Color("#72e6a1") if str(family.get("kind", "")) == "life" else Color("#8fb4da"))
		family_item.set_tooltip_text(0, str(family.get("description", "")))
		for clip_name in matching_clips:
			var clip_item := _tree.create_item(family_item)
			clip_item.set_text(0, str(_labels.get(clip_name, clip_name)))
			clip_item.set_text(1, _runtime_badge(clip_name, family))
			clip_item.set_metadata(0, {"clip": clip_name, "family": family})
			clip_item.set_tooltip_text(0, clip_name)
			if first_clip_item == null:
				first_clip_item = clip_item
			if clip_name == _selected_clip:
				selected_item = clip_item
	if selected_item != null:
		selected_item.select(0)
		_tree.scroll_to_item(selected_item)
	elif first_clip_item != null:
		first_clip_item.select(0)
		_on_tree_item_selected()
	else:
		_selected_clip = ""
		_title_label.text = "没有匹配的动作"
		_clip_id_label.text = ""
		_info.text = "请调整搜索词或筛选条件。"

func _clip_matches(clip_name: String, family: Dictionary, query: String, filter_id: int) -> bool:
	if manifest == null or not manifest.has_clip(clip_name):
		return false
	var kind := str(family.get("kind", ""))
	var clip := manifest.clip(clip_name)
	match filter_id:
		CatalogFilter.LIFE:
			if kind != "life": return false
		CatalogFilter.SYSTEM:
			if kind != "system": return false
		CatalogFilter.DIRECTOR:
			if not _behavior_map.has(clip_name): return false
		CatalogFilter.LOOP:
			if not bool(clip.get("loop", false)): return false
		CatalogFilter.ONE_SHOT:
			if bool(clip.get("loop", false)): return false
	if query.is_empty():
		return true
	var haystack := "%s %s %s %s" % [
		clip_name,
		str(_labels.get(clip_name, "")),
		str(family.get("label", "")),
		str(family.get("description", "")),
	]
	return haystack.to_lower().contains(query)

func _on_tree_item_selected() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	var metadata: Variant = item.get_metadata(0)
	if not metadata is Dictionary:
		return
	var clip_name := str(metadata.get("clip", ""))
	if clip_name.is_empty() or manifest == null or not manifest.has_clip(clip_name):
		return
	_selected_clip = clip_name
	_selected_family = metadata.get("family", {})
	_frame_index = 0
	_elapsed_in_frame_ms = 0.0
	_playing = true
	var frame_count := (manifest.clip(_selected_clip).get("frames", []) as Array).size()
	_updating_timeline = true
	_timeline.max_value = max(0, frame_count - 1)
	_timeline.value = 0
	_updating_timeline = false
	_update_play_button()
	_update_metadata()
	_apply_selected_frame()

func _select_first_visible_clip() -> void:
	if _tree == null:
		return
	var root := _tree.get_root()
	if root == null:
		return
	var family_item := root.get_first_child()
	while family_item != null:
		var clip_item := family_item.get_first_child()
		if clip_item != null:
			clip_item.select(0)
			_on_tree_item_selected()
			return
		family_item = family_item.get_next()

func _apply_selected_frame() -> void:
	if manifest == null or _selected_clip.is_empty():
		return
	var clip := manifest.clip(_selected_clip)
	var frames: Array = clip.get("frames", [])
	if frames.is_empty():
		return
	_frame_index = clampi(_frame_index, 0, frames.size() - 1)
	var relative_path := str(frames[_frame_index])
	var texture := _texture(relative_path)
	_preview.set_preview(texture, clip, _frame_index)
	_updating_timeline = true
	_timeline.value = _frame_index
	_updating_timeline = false
	_frame_label.text = "%d / %d" % [_frame_index + 1, frames.size()]

func _toggle_playback() -> void:
	if manifest == null or _selected_clip.is_empty():
		return
	var frames: Array = manifest.clip(_selected_clip).get("frames", [])
	if frames.is_empty():
		return
	if not _playing and _frame_index >= frames.size() - 1:
		_frame_index = 0
		_elapsed_in_frame_ms = 0.0
		_apply_selected_frame()
	_playing = not _playing
	_update_play_button()

func _step_frame(offset: int) -> void:
	if manifest == null or _selected_clip.is_empty():
		return
	var frame_count := (manifest.clip(_selected_clip).get("frames", []) as Array).size()
	if frame_count <= 0:
		return
	_playing = false
	_frame_index = posmod(_frame_index + offset, frame_count)
	_elapsed_in_frame_ms = 0.0
	_update_play_button()
	_apply_selected_frame()

func _on_timeline_changed(value: float) -> void:
	if _updating_timeline:
		return
	_playing = false
	_frame_index = int(value)
	_elapsed_in_frame_ms = 0.0
	_update_play_button()
	_apply_selected_frame()

func _update_play_button() -> void:
	if _play_button != null:
		_play_button.text = "暂停" if _playing else "播放"

func _update_summary() -> void:
	if _summary_label == null or manifest == null:
		return
	var coverage := catalog_coverage(catalog, manifest.animation_names())
	var frame_count := 0
	for clip_name in manifest.animation_names():
		frame_count += (manifest.clip(clip_name).get("frames", []) as Array).size()
	_summary_label.text = "%d 个生活行为族  ·  %d 个运行片段  ·  %d 帧  ·  %d 个导演入口" % [
		int(coverage.get("life_family_count", 0)),
		manifest.animation_names().size(),
		frame_count,
		(profile.get("director", {}).get("behaviors", []) as Array).size(),
	]

func _update_metadata() -> void:
	if manifest == null or _selected_clip.is_empty():
		return
	var clip := manifest.clip(_selected_clip)
	var frames: Array = clip.get("frames", [])
	var duration_ms := total_duration_ms(clip)
	var average_fps := float(frames.size()) * 1000.0 / duration_ms if duration_ms > 0.0 else 0.0
	var family_label := str(_selected_family.get("label", "未分类"))
	_title_label.text = str(_labels.get(_selected_clip, _selected_clip))
	_clip_id_label.text = _selected_clip
	var lines: Array[String] = []
	lines.append("[color=#72e6a1][b]所属行为族[/b][/color]")
	lines.append(family_label)
	lines.append(str(_selected_family.get("description", "")))
	lines.append("")
	lines.append("[color=#72e6a1][b]播放信息[/b][/color]")
	lines.append("帧数：%d" % frames.size())
	lines.append("总时长：%s" % _format_duration(duration_ms))
	lines.append("平均速率：%.1f FPS" % average_fps)
	lines.append("类型：%s" % ("循环" if bool(clip.get("loop", false)) else "一次性"))
	var segments: Dictionary = clip.get("segments", {})
	if not segments.is_empty():
		var segment_names: Array[String] = []
		for segment_name in segments.keys():
			var segment: Dictionary = segments[segment_name]
			segment_names.append("%s %d–%d%s" % [
				str(segment_name),
				int(segment.get("start", 0)) + 1,
				int(segment.get("end", 0)) + 1,
				" ↻" if bool(segment.get("loop", false)) else "",
			])
		lines.append("分段：%s" % "，".join(segment_names))
	lines.append("")
	lines.append("[color=#72e6a1][b]运行映射[/b][/color]")
	var mappings: Array = _behavior_map.get(_selected_clip, [])
	if mappings.is_empty():
		lines.append("由系统状态机直接调用，或作为过渡素材。")
	else:
		for mapping in mappings:
			if mapping is Dictionary:
				lines.append("%s  ·  %s" % [str(mapping.get("id", "?")), str(mapping.get("role", "clip"))])
	lines.append("")
	lines.append("[color=#72e6a1][b]几何信息[/b][/color]")
	var canvas: Dictionary = clip.get("canvas", manifest.canvas())
	var anchor: Dictionary = clip.get("anchor", {})
	lines.append("画布：%d × %d" % [int(canvas.get("width", 0)), int(canvas.get("height", 0))])
	lines.append("锚点：(%.3f, %.3f)" % [float(anchor.get("x", 0.0)), float(anchor.get("y", 0.0))])
	var support_y: Array = clip.get("supportContactY", [])
	if not support_y.is_empty():
		var minimum_support := INF
		var maximum_support := -INF
		for support in support_y:
			minimum_support = minf(minimum_support, float(support))
			maximum_support = maxf(maximum_support, float(support))
		lines.append("逐帧支撑点：Y %.0f–%.0f" % [minimum_support, maximum_support])
	else:
		lines.append("逐帧支撑点：使用锚点")
	var root_motion: Dictionary = clip.get("rootMotion", {})
	if not root_motion.is_empty():
		lines.append("根运动：%.1f px / cycle" % float(root_motion.get("cycleAdvancePx", 0.0)))
	lines.append("")
	lines.append("[color=#71869b]首帧路径[/color]")
	lines.append(str(frames[0]) if not frames.is_empty() else "—")
	_info.text = "\n".join(lines)

func _runtime_badge(clip_name: String, family: Dictionary) -> String:
	var clip := manifest.clip(clip_name)
	var playback := "循环" if bool(clip.get("loop", false)) else "单次"
	if _behavior_map.has(clip_name):
		return "导演·%s" % playback
	if str(family.get("kind", "")) == "system":
		return "状态机·%s" % playback
	return "辅助·%s" % playback

func _texture(relative_path: String) -> Texture2D:
	if _textures.has(relative_path):
		return _textures[relative_path]
	var resource := ResourceLoader.load(manifest.frame_resource_path(relative_path), "Texture2D")
	if resource is Texture2D:
		_textures[relative_path] = resource
		return resource
	return null

func _frame_duration(clip: Dictionary, frame_index: int) -> float:
	var durations: Array = clip.get("frameDurationsMs", [])
	if frame_index >= 0 and frame_index < durations.size():
		return maxf(1.0, float(durations[frame_index]))
	return 100.0

func _format_duration(milliseconds: float) -> String:
	if milliseconds < 1000.0:
		return "%d ms" % int(milliseconds)
	return "%.2f 秒" % (milliseconds / 1000.0)

func _load_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("找不到动作面板数据：%s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法读取动作面板数据：%s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("动作面板数据不是有效 JSON：%s" % path)
	return {}

func _panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style

static func total_duration_ms(clip: Dictionary) -> float:
	var total := 0.0
	for duration in clip.get("frameDurationsMs", []):
		total += maxf(0.0, float(duration))
	return total

static func catalog_coverage(catalog_data: Dictionary, animation_names: Array[String]) -> Dictionary:
	var animation_set: Dictionary = {}
	for name in animation_names:
		animation_set[name] = true
	var occurrences: Dictionary = {}
	var life_family_count := 0
	var family_count := 0
	for family_value in catalog_data.get("families", []):
		if not family_value is Dictionary:
			continue
		family_count += 1
		var family: Dictionary = family_value
		if str(family.get("kind", "")) == "life":
			life_family_count += 1
		for clip_value in family.get("clips", []):
			var clip_name := str(clip_value)
			occurrences[clip_name] = int(occurrences.get(clip_name, 0)) + 1
	var missing: Array[String] = []
	var unknown: Array[String] = []
	var duplicates: Array[String] = []
	for name in animation_names:
		if not occurrences.has(name):
			missing.append(name)
	for clip_name in occurrences.keys():
		if not animation_set.has(clip_name):
			unknown.append(str(clip_name))
		if int(occurrences[clip_name]) > 1:
			duplicates.append(str(clip_name))
	missing.sort()
	unknown.sort()
	duplicates.sort()
	return {
		"family_count": family_count,
		"life_family_count": life_family_count,
		"classified_count": occurrences.size(),
		"missing": missing,
		"unknown": unknown,
		"duplicates": duplicates,
	}

static func build_behavior_clip_map(profile_data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var director: Dictionary = profile_data.get("director", {})
	for behavior_value in director.get("behaviors", []):
		if not behavior_value is Dictionary:
			continue
		var behavior: Dictionary = behavior_value
		var behavior_id := str(behavior.get("id", "?"))
		_add_behavior_mapping(result, str(behavior.get("clip", "")), behavior_id, "主片段")
		_add_behavior_mapping(result, str(behavior.get("fallback_clip", "")), behavior_id, "回退")
		var session: Dictionary = behavior.get("session", {})
		for role in ["enter", "loop", "exit"]:
			_add_behavior_mapping(result, str(session.get(role, "")), behavior_id, role)
	return result

static func _add_behavior_mapping(target: Dictionary, clip_name: String, behavior_id: String, role: String) -> void:
	if clip_name.is_empty():
		return
	if not target.has(clip_name):
		target[clip_name] = []
	var mappings: Array = target[clip_name]
	for mapping in mappings:
		if mapping is Dictionary and str(mapping.get("id", "")) == behavior_id and str(mapping.get("role", "")) == role:
			return
	mappings.append({"id": behavior_id, "role": role})
