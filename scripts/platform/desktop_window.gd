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
}

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
