class_name DesktopHabitatModel
extends RefCounted

var _screens: Array[Rect2] = []


func update_screens(values: Array) -> void:
	var normalized: Array[Rect2] = []
	for value in values:
		var rect := _rect_from_value(value)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		normalized.append(rect)
	if normalized.is_empty():
		normalized.append(Rect2(0.0, 0.0, 1280.0, 720.0))
	_screens = normalized


func screen_rects() -> Array[Rect2]:
	return _screens.duplicate()


func virtual_bounds() -> Rect2:
	if _screens.is_empty():
		return Rect2()
	var result := _screens[0]
	for index in range(1, _screens.size()):
		result = result.merge(_screens[index])
	return result


func screen_index_for_point(point: Vector2) -> int:
	if _screens.is_empty():
		return -1
	for index in range(_screens.size()):
		if _screens[index].has_point(point):
			return index
	var nearest_index := 0
	var nearest_distance := INF
	for index in range(_screens.size()):
		var nearest := _nearest_point(_screens[index], point)
		var distance := nearest.distance_squared_to(point)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	return nearest_index


func screen_for_pet_position(position: Vector2, pet_size: Vector2) -> Rect2:
	if _screens.is_empty():
		return Rect2(0.0, 0.0, 1280.0, 720.0)
	var index := screen_index_for_point(position + pet_size * 0.5)
	return _screens[maxi(index, 0)]


func clamp_pet_position(value: Vector2, pet_size: Vector2, force_floor: bool) -> Vector2:
	var screen := screen_for_pet_position(value, pet_size)
	var maximum := screen.end - pet_size
	var x := screen.position.x if maximum.x < screen.position.x else clampf(value.x, screen.position.x, maximum.x)
	var maximum_y := maximum.y
	var y := screen.position.y if maximum_y < screen.position.y else (maximum_y if force_floor else clampf(value.y, screen.position.y, maximum_y))
	return Vector2(x, y)


func floor_y_for_position(value: Vector2, pet_size: Vector2) -> float:
	var screen := screen_for_pet_position(value, pet_size)
	return screen.end.y - pet_size.y


func default_position(pet_size: Vector2, screen_index := 0) -> Vector2:
	if _screens.is_empty():
		update_screens([])
	var screen := _screens[clampi(screen_index, 0, _screens.size() - 1)]
	return Vector2(screen.end.x - pet_size.x - 34.0, screen.end.y - pet_size.y)


func route_mode(from_position: Vector2, to_position: Vector2, pet_size: Vector2) -> String:
	var from_index := screen_index_for_point(from_position + pet_size * 0.5)
	var to_index := screen_index_for_point(to_position + pet_size * 0.5)
	return "walk" if from_index >= 0 and from_index == to_index else "flight"


func make_anchor(position: Vector2, pet_size: Vector2) -> Dictionary:
	var screen := screen_for_pet_position(position, pet_size)
	var travel_size := Vector2(maxf(1.0, screen.size.x - pet_size.x), maxf(1.0, screen.size.y - pet_size.y))
	var uv := Vector2(
		clampf((position.x - screen.position.x) / travel_size.x, 0.0, 1.0),
		clampf((position.y - screen.position.y) / travel_size.y, 0.0, 1.0)
	)
	return {
		"screen_rect": _rect_to_array(screen),
		"uv": [uv.x, uv.y],
		"global_position": [position.x, position.y],
	}


func restore_anchor(value: Variant, pet_size: Vector2) -> Vector2:
	if not value is Dictionary or _screens.is_empty():
		return default_position(pet_size)
	var anchor: Dictionary = value
	var stored_rect := _rect_from_value(anchor.get("screen_rect", []))
	var screen_index := -1
	for index in range(_screens.size()):
		if _rect_matches(_screens[index], stored_rect):
			screen_index = index
			break
	if screen_index < 0:
		var fallback := _vector_from_value(anchor.get("global_position", []), virtual_bounds().get_center())
		screen_index = screen_index_for_point(fallback)
	var screen := _screens[maxi(screen_index, 0)]
	var uv := _vector_from_value(anchor.get("uv", []), Vector2(0.5, 1.0))
	uv.x = clampf(uv.x, 0.0, 1.0)
	uv.y = clampf(uv.y, 0.0, 1.0)
	var travel_size := Vector2(maxf(1.0, screen.size.x - pet_size.x), maxf(1.0, screen.size.y - pet_size.y))
	return clamp_pet_position(screen.position + uv * travel_size, pet_size, false)


func snapshot(
	pet_position: Vector2,
	pet_size: Vector2,
	cursor_position: Vector2,
	platform_count: int,
	foreground_available: bool,
	home_anchor: Variant = {}
) -> Dictionary:
	var pet_screen := screen_index_for_point(pet_position + pet_size * 0.5)
	var cursor_screen := screen_index_for_point(cursor_position)
	return {
		"screen_count": _screens.size(),
		"virtual_bounds": virtual_bounds(),
		"pet_screen": pet_screen,
		"cursor_screen": cursor_screen,
		"cross_screen_cursor": pet_screen >= 0 and cursor_screen >= 0 and pet_screen != cursor_screen,
		"platform_count": maxi(0, platform_count),
		"has_platform": platform_count > 0,
		"has_foreground": foreground_available,
		"home_set": home_anchor is Dictionary and not (home_anchor as Dictionary).is_empty(),
	}


static func enumerate_usable_screens() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for index in range(DisplayServer.get_screen_count()):
		var rect := Rect2(DisplayServer.screen_get_usable_rect(index))
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			result.append(rect)
	return result


func _rect_from_value(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	if value is Rect2i:
		return Rect2(value)
	if value is Array and value.size() >= 4:
		return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	if value is Dictionary:
		var data: Dictionary = value
		if data.has("position") and data.has("size"):
			return Rect2(_vector_from_value(data.position), _vector_from_value(data.size))
		return Rect2(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("width", 0.0)), float(data.get("height", 0.0)))
	return Rect2()


func _vector_from_value(value: Variant, fallback := Vector2.ZERO) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)))
	return fallback


func _nearest_point(rect: Rect2, point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))


func _rect_matches(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) <= 2.0 and a.size.distance_to(b.size) <= 2.0


func _rect_to_array(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

