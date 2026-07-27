class_name DesktopWindowBridge
extends Node

const SETTINGS_PATH := "user://little_chihiro.cfg"

var _window: Window

func _ready() -> void:
	_window = get_window()

func configure() -> void:
	_window.transparent_bg = true
	_window.borderless = true
	_window.always_on_top = true
	_window.unfocusable = true
	_window.min_size = Vector2i.ZERO
	_window.max_size = Vector2i.ZERO

func get_work_area() -> Rect2i:
	return DisplayServer.screen_get_usable_rect(_window.current_screen)

func get_cursor_position() -> Vector2i:
	return DisplayServer.mouse_get_position()

func get_position() -> Vector2i:
	return _window.position

func set_position(value: Vector2) -> void:
	_window.position = Vector2i(roundi(value.x), roundi(value.y))

func set_size(value: Vector2i) -> void:
	_window.size = value

func set_visible(value: bool) -> void:
	_window.visible = value

func set_unfocusable(value: bool) -> void:
	_window.unfocusable = value

func set_mouse_passthrough(polygon: PackedVector2Array) -> void:
	_window.mouse_passthrough_polygon = polygon

func device_scale() -> float:
	# Godot exposes window, input and DisplayServer positions in one pixel space.
	# Keeping this bridge at 1 avoids mixing OS scale with already-scaled values.
	return 1.0

func save_position(position: Vector2, base_size: Vector2i, current_size: Vector2i) -> void:
	var normalized := Vector2(
		position.x + (current_size.x - base_size.x) / 2.0,
		position.y + current_size.y - base_size.y,
	)
	var config := ConfigFile.new()
	config.set_value("window", "position", normalized)
	config.save(SETTINGS_PATH)

func load_position() -> Variant:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return null
	var value = config.get_value("window", "position", null)
	return value if value is Vector2 else null

func get_system_context() -> Dictionary:
	# Godot owns all windowing features used by the pet. A Windows GDExtension
	# can override this optional hook later for foreign foreground-window checks.
	var work_area := get_work_area()
	return {
		"foreground_fullscreen": false,
		"foreground_maximized": false,
		"foreground_rect": Rect2i(),
		"monitor_rect": Rect2i(
			DisplayServer.screen_get_position(_window.current_screen),
			DisplayServer.screen_get_size(_window.current_screen),
		),
		"work_area": work_area,
	}
