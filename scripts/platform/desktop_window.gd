class_name DesktopWindowBridge
extends Node

const SETTINGS_PATH := "user://little_chihiro.cfg"
const DEFAULT_SETTINGS := {
	"auto_wander": true,
	"cursor_tracking": true,
	"speech_bubbles": true,
	"title_awareness": true,
	"action_sounds": true,
	"sfx_volume": 0.72,
	"window_collision": true,
}

var _window: Window
var _native_bridge: Variant = null

func _ready() -> void:
	_window = get_window()

func configure() -> void:
	_native_bridge = ClassDB.instantiate("WindowsWindowEnumerator") if ClassDB.class_exists("WindowsWindowEnumerator") else null
	_window.transparent_bg = true
	_window.borderless = true
	_window.always_on_top = true
	_window.unfocusable = true
	# NOTE: Godot's Window class has no skip_taskbar property; the unfocusable
	# flag above is what keeps the pet out of the taskbar and Alt+Tab.
	_window.min_size = Vector2i.ZERO
	_window.max_size = Vector2i.ZERO

func get_work_area() -> Rect2i:
	return DisplayServer.screen_get_usable_rect(_window.current_screen)

func get_usable_screen_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for index in range(DisplayServer.get_screen_count()):
		var rect := Rect2(DisplayServer.screen_get_usable_rect(index))
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			result.append(rect)
	return result

func get_virtual_desktop_bounds() -> Rect2:
	var screens := get_usable_screen_rects()
	if screens.is_empty():
		return Rect2(get_work_area())
	var bounds := screens[0]
	for index in range(1, screens.size()):
		bounds = bounds.merge(screens[index])
	return bounds

func get_cursor_position() -> Vector2i:
	return DisplayServer.mouse_get_position()

func set_position(value: Vector2) -> void:
	_window.position = Vector2i(roundi(value.x), roundi(value.y))

func set_size(value: Vector2i) -> void:
	_window.size = value

func set_geometry(value_position: Vector2, value_size: Vector2i) -> void:
	var resolved_position := Vector2i(roundi(value_position.x), roundi(value_position.y))
	if _native_bridge != null and _native_bridge.has_method("set_window_rect"):
		var handle := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, _window.get_window_id())
		if handle != 0 and bool(_native_bridge.call(
			"set_window_rect",
			handle,
			resolved_position.x,
			resolved_position.y,
			value_size.x,
			value_size.y,
		)):
			return
	_window.position = resolved_position
	_window.size = value_size

func set_visible(value: bool) -> void:
	# Godot forbids toggling the main window's `visible` property directly
	# ("Can't change visibility of main window"), so hiding takes the form of
	# minimizing the window. The window is unfocusable and taskbar-less, so a
	# minimized pet is fully off the desktop; the tray "显示小千寻" restores it.
	_window.mode = Window.MODE_WINDOWED if value else Window.MODE_MINIMIZED

func is_visible() -> bool:
	return _window != null and _window.visible

func is_minimized() -> bool:
	return _window != null and _window.mode == Window.MODE_MINIMIZED

func set_unfocusable(value: bool) -> void:
	_window.unfocusable = value

func set_mouse_passthrough(polygon: PackedVector2Array) -> void:
	_window.mouse_passthrough_polygon = polygon

func save_position(position: Vector2, base_size: Vector2i, current_size: Vector2i) -> void:
	var normalized := Vector2(
		position.x + (current_size.x - base_size.x) / 2.0,
		position.y + current_size.y - base_size.y,
	)
	var config := _load_config()
	config.set_value("window", "position", normalized)
	config.save(SETTINGS_PATH)

func load_position() -> Variant:
	var config := _load_config()
	var value = config.get_value("window", "position", null)
	return value if value is Vector2 else null

func load_settings() -> Dictionary:
	var config := _load_config()
	var result := DEFAULT_SETTINGS.duplicate(true)
	for key in DEFAULT_SETTINGS.keys():
		var fallback: Variant = DEFAULT_SETTINGS[key]
		var value: Variant = config.get_value("interaction", str(key), fallback)
		if typeof(value) == typeof(fallback):
			result[key] = value
	result.sfx_volume = clampf(float(result.sfx_volume), 0.0, 1.0)
	return result

func save_settings(values: Dictionary) -> Error:
	var config := _load_config()
	for key in DEFAULT_SETTINGS.keys():
		if values.has(key):
			config.set_value("interaction", str(key), values[key])
	return config.save(SETTINGS_PATH)

func _load_config() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	return config

func get_system_context(window_snapshots: Array = []) -> Dictionary:
	var work_area := get_work_area()
	var monitor_rect := Rect2i(
		DisplayServer.screen_get_position(_window.current_screen),
		DisplayServer.screen_get_size(_window.current_screen),
	)
	var foreground: Dictionary = {}
	for value in window_snapshots:
		if value is Dictionary and bool(value.get("visible", true)) and not bool(value.get("minimized", false)):
			foreground = value
			break
	var foreground_rect := WindowPlatform.rect_from_value(foreground.get("rect", Rect2i())) if not foreground.is_empty() else Rect2i()
	var maximized := bool(foreground.get("maximized", false))
	var covers_monitor := (
		foreground_rect.size.x > 0 and foreground_rect.size.y > 0
		and foreground_rect.position.x <= monitor_rect.position.x + 2
		and foreground_rect.position.y <= monitor_rect.position.y + 2
		and foreground_rect.end.x >= monitor_rect.end.x - 2
		and foreground_rect.end.y >= monitor_rect.end.y - 2
	)
	return {
		"foreground_fullscreen": covers_monitor and not maximized,
		"foreground_maximized": maximized,
		"foreground_rect": foreground_rect,
		"foreground_title": str(foreground.get("title", "")),
		"foreground_process": str(foreground.get("process_name", "")),
		"monitor_rect": monitor_rect,
		"work_area": work_area,
	}
