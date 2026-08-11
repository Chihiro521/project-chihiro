class_name PetBackpackPanel
extends Window
## 千寻的背包 — 查看被归档的桌面图标。
##
## 上半区列出她包里的图标（普通"借用"或"藏品"），逐项可"要回"；
## 下半区列出桌面上的其它图标，逐项可"给她"（主动送成藏品，包满时禁用）；
## 底部"还原全部"把所有图标放回原位。面板不用 Esc 关闭——Esc 是没收光标的
## 专属逃生阀，见 main.gd 的 CURSOR_CONFISCATE 实现。

signal reclaim_requested(icon_name: String)
signal give_requested(icon_name: String)
signal restore_all_requested

var _capacity_label: Label
var _bag_rows_box: VBoxContainer
var _desktop_rows_box: VBoxContainer
var _restore_button: Button

func _ready() -> void:
	title = "千寻的背包"
	close_requested.connect(hide)
	_build_ui()

func update_view(bag_entries: Array, desktop_icons: Array, capacity: int) -> void:
	_rebuild_bag_rows(bag_entries, capacity)
	_rebuild_desktop_rows(desktop_icons, bag_entries, capacity)

func _build_ui() -> void:
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", _panel_style(Color("#0d1117"), Color("#263241"), 0))
	add_child(background)

	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 16)
	outer_margin.add_theme_constant_override("margin_right", 16)
	outer_margin.add_theme_constant_override("margin_top", 14)
	outer_margin.add_theme_constant_override("margin_bottom", 14)
	background.add_child(outer_margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	outer_margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	column.add_child(header)
	var heading := Label.new()
	heading.text = "千寻的背包"
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color("#f2f6fb"))
	header.add_child(heading)
	_capacity_label = Label.new()
	_capacity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_capacity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_capacity_label.add_theme_color_override("font_color", Color("#92a6ba"))
	header.add_child(_capacity_label)

	var divider := HSeparator.new()
	column.add_child(divider)

	column.add_child(_section_label("她包里的", "已被她收走、还没放回去的图标。"))
	_bag_rows_box = _scroll_list(column, 170.0)

	var middle_divider := HSeparator.new()
	column.add_child(middle_divider)

	column.add_child(_section_label("桌面上的", "点击“给她”，或直接把桌面图标拖到她身上；送给她后会播放收纳动画，并跨会话留在包里。"))
	_desktop_rows_box = _scroll_list(column, -1.0)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	column.add_child(footer)
	var hint := Label.new()
	hint.text = "要回：从包里取出并放在她脚边  ·  给她：收进包里"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("#6f8296"))
	footer.add_child(hint)
	_restore_button = Button.new()
	_restore_button.text = "还原全部"
	_restore_button.pressed.connect(func() -> void: restore_all_requested.emit())
	footer.add_child(_restore_button)

func _section_label(text: String, tooltip: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("#72e6a1"))
	label.tooltip_text = tooltip
	return label

func _scroll_list(parent: VBoxContainer, fixed_height: float) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL if fixed_height < 0.0 else Control.SIZE_SHRINK_BEGIN
	if fixed_height > 0.0:
		scroll.custom_minimum_size = Vector2(0.0, fixed_height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	scroll.add_child(rows)
	return rows

func _rebuild_bag_rows(bag_entries: Array, capacity: int) -> void:
	_clear_rows(_bag_rows_box)
	# Only carried (stashed) icons live in the bag list. Icons she placed back on
	# the desktop are still tracked for exit-restore but are visible on the desktop.
	var carried: Array = []
	for entry in bag_entries:
		if entry is Dictionary and not bool(entry.get("placed", false)):
			carried.append(entry)
	_capacity_label.text = "容量 %d / %d" % [carried.size(), capacity]
	if carried.is_empty():
		_bag_rows_box.add_child(_empty_row("包里是空的。"))
	else:
		for entry in carried:
			var icon_name := str(entry.get("name", ""))
			if icon_name.is_empty():
				continue
			var keepsake := str(entry.get("kind", "ordinary")) == "keepsake"
			_bag_rows_box.add_child(_row_with_button(
				icon_name,
				"藏品" if keepsake else "借用",
				Color("#72e6a1") if keepsake else Color("#8fb4da"),
				"要回",
				_on_reclaim_pressed.bind(icon_name),
				"放回原位。藏品会从她包里移除，普通借用立即归还。",
			))
	_restore_button.disabled = bag_entries.is_empty()

func _rebuild_desktop_rows(desktop_icons: Array, bag_entries: Array, capacity: int) -> void:
	_clear_rows(_desktop_rows_box)
	var bag_names: Dictionary = {}
	var carried_count := 0
	for entry in bag_entries:
		if not entry is Dictionary:
			continue
		bag_names[str(entry.get("name", ""))] = true
		if not bool(entry.get("placed", false)):
			carried_count += 1
	var full := carried_count >= capacity
	var listed := 0
	for item in desktop_icons:
		if not item is Dictionary:
			continue
		var icon_name := str(item.get("name", ""))
		if icon_name.is_empty() or bag_names.has(icon_name):
			continue
		listed += 1
		_desktop_rows_box.add_child(_row_with_button(
			icon_name,
			"",
			Color("#92a6ba"),
			"给她",
			_on_give_pressed.bind(icon_name),
			"" if full else "送给她，变成跨会话保留的藏品。",
			full,
		))
	if listed == 0:
		_desktop_rows_box.add_child(_empty_row("桌面没有可赠送的其它图标。"))

func _row_with_button(
	icon_name: String,
	badge: String,
	badge_color: Color,
	button_text: String,
	callback: Callable,
	tooltip: String,
	disabled := false,
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := Label.new()
	name_label.text = icon_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.tooltip_text = icon_name
	name_label.add_theme_color_override("font_color", Color("#c9d5e2"))
	row.add_child(name_label)
	if not badge.is_empty():
		var badge_label := Label.new()
		badge_label.text = badge
		badge_label.add_theme_font_size_override("font_size", 12)
		badge_label.add_theme_color_override("font_color", badge_color)
		badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(badge_label)
	var button := Button.new()
	button.text = button_text
	button.disabled = disabled
	if not tooltip.is_empty():
		button.tooltip_text = tooltip
	button.pressed.connect(callback)
	row.add_child(button)
	return row

func _empty_row(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("#6f8296"))
	label.add_theme_font_size_override("font_size", 13)
	return label

func _clear_rows(container: VBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _on_reclaim_pressed(icon_name: String) -> void:
	reclaim_requested.emit(icon_name)

func _on_give_pressed(icon_name: String) -> void:
	give_requested.emit(icon_name)

func _panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style
