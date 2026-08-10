class_name DesktopWorld
extends RefCounted

## Unified desktop-window world model: the visible geometry the pet's platformer
## (ManualControlModel) moves through. The desktop is a 2D side-scroller whose
## level is the immutable Windows window geometry — everything the OS actually
## renders, nothing hidden. Riding/roam (main.gd) and keyboard control / the
## autonomous climb (the model) all consume this ONE world object, so every path
## sees the same surfaces.
##
## Pure data: no nodes, no native calls. main.gd fills it from the
## WindowPlatformService occlusion pass (refresh cadence for the collision lists,
## per frame for the live sources).
##
## Field conventions (the model's):
## - platforms: occlusion-subtracted VISIBLE top-edge segments, each
##   {left, right, y, handle, process_id} with y in window space (window top minus
##   the foot offset). This is the "standable" list — the host excludes transient
##   (<2s) windows, so a freshly-appeared popup is never stood on. A window whose
##   top is covered by a front window has no segment here.
## - walls: solid window faces {x, top_y, bottom_y, side, handle, process_id} in
##   absolute screen space (the resolver's foot space).
## - live_*: per-frame sources for the standing/climbing window so a drag carries
##   the pet frame by frame and an occluded standing point is dropped instead of
##   kept on a stale full edge (see WindowPlatformService.live_top_segment_planes,
##   live_rect_delta_x, live_wall_edge).

var platforms: Array = []
var walls: Array = []
var floor_y: float = 0.0
var screen: Rect2 = Rect2()
var pet_size: Vector2 = Vector2(360.0, 360.0)
var live_platforms: Array = []
## Horizontal displacement of the standing window's live rect center (whether it
## is being dragged right now). Gates the model's perch-continuity during a drag.
var live_delta_x: float = 0.0
## Vertical displacement of the standing window's live rect center. A vertical drag
## moves no X (live_delta_x stays ~0); without this the model would read an upward
## drag as a static window and drop the pet the moment the top segment is sliced.
var live_delta_y: float = 0.0
var live_wall: Dictionary = {}
var umbrella_available: bool = true
var climb_contact: Dictionary = {}


## Key bridge so the model reads uniformly whether the caller passes this
## DesktopWorld or a plain Dictionary (legacy/test paths). Named _value to avoid
## shadowing Object.get(property).
func _value(key: String, default_value: Variant = null) -> Variant:
	match key:
		"platforms": return platforms
		"walls": return walls
		"floor_y": return floor_y
		"screen": return screen
		"pet_size": return pet_size
		"live_platforms": return live_platforms
		"standing_plane_live_delta": return live_delta_x
		"standing_plane_live_delta_y": return live_delta_y
		"live_wall": return live_wall
		"umbrella_available": return umbrella_available
		"climb_contact": return climb_contact
	return default_value
