class_name WindowPlatform
extends RefCounted

## A standable, currently visible segment of a foreign top-level window.
##
## `rect` is the complete source HWND rectangle. `top_edge` is a one-pixel-high,
## half-open segment [x, x + width) that remains after z-order occlusion.

var handle: int = 0
var process_id: int = 0
var rect := Rect2i()
var top_edge := Rect2i()
var z_order: int = 0
var title := ""
var process_name := ""
var window_class := ""
var maximized := false


static func from_snapshot(snapshot: Dictionary, segment_left: int, segment_right: int) -> WindowPlatform:
	var platform := WindowPlatform.new()
	platform.handle = int(snapshot.get("handle", 0))
	platform.process_id = int(snapshot.get("process_id", 0))
	platform.rect = rect_from_value(snapshot.get("rect", Rect2i()))
	platform.z_order = int(snapshot.get("z_order", 0))
	platform.title = str(snapshot.get("title", ""))
	platform.process_name = str(snapshot.get("process_name", ""))
	platform.window_class = str(snapshot.get("class_name", ""))
	platform.maximized = bool(snapshot.get("maximized", false))
	var left := mini(segment_left, segment_right)
	var right := maxi(segment_left, segment_right)
	platform.top_edge = Rect2i(left, platform.rect.position.y, maxi(0, right - left), 1)
	return platform


static func rect_from_value(value: Variant) -> Rect2i:
	if value is Rect2i:
		return value
	if value is Rect2:
		var source := value as Rect2
		return Rect2i(
			floori(source.position.x),
			floori(source.position.y),
			maxi(0, ceili(source.size.x)),
			maxi(0, ceili(source.size.y)),
		)
	if value is Dictionary:
		var source := value as Dictionary
		return Rect2i(
			int(source.get("x", 0)),
			int(source.get("y", 0)),
			maxi(0, int(source.get("width", 0))),
			maxi(0, int(source.get("height", 0))),
		)
	if value is Array and (value as Array).size() >= 4:
		var source := value as Array
		return Rect2i(int(source[0]), int(source[1]), maxi(0, int(source[2])), maxi(0, int(source[3])))
	return Rect2i()


func segment_left() -> int:
	return top_edge.position.x


func segment_right() -> int:
	return top_edge.position.x + top_edge.size.x


func center() -> Vector2:
	return Vector2(top_edge.position.x + top_edge.size.x * 0.5, top_edge.position.y)


func contains_x(x: float) -> bool:
	return x >= float(segment_left()) and x < float(segment_right())


func stable_id() -> String:
	return "%d:%d:%d" % [handle, segment_left(), segment_right()]
