extends SceneTree

## Diagnostic: enumerate real desktop windows via the native DLL and print the
## resulting platforms, solid bodies, wall edges, and standing planes. Helps
## tell apart "collision world not built" from "behavior logic wrong".

const WindowPlatformServiceScript := preload("res://scripts/platform/window_platform_service.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var native_available := ClassDB.class_exists("WindowsWindowEnumerator")
	print("native WindowsWindowEnumerator class: %s" % ("available" if native_available else "MISSING"))
	var service := WindowPlatformServiceScript.new()
	service.set_collision_enabled(true)
	service.set_work_area(Rect2i(0, 0, 3840, 2160))
	service.capture_titles = false
	var platforms := service.refresh()
	var bodies := service.last_bodies()
	print("platforms: %d   bodies: %d" % [platforms.size(), bodies.size()])
	for body in bodies:
		var walls: Array = body.fragment_wall_edges()
		var planes: Array = body.standable_planes(356.0)
		print("  body handle=%d rect=%s walls=%d planes=%d" % [
			body.handle, str(body.rect), walls.size(), planes.size(),
		])
		for wall in walls:
			print("    wall x=%.0f top=%.0f bottom=%.0f side=%d handle=%d" % [
				float(wall.get("x", 0.0)),
				float(wall.get("top_y", 0.0)),
				float(wall.get("bottom_y", 0.0)),
				int(wall.get("side", 0)),
				int(wall.get("handle", 0)),
			])
	quit(0)
