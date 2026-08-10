class_name WindowBody
extends RefCounted

## A foreign top-level window rendered as a solid 2D collision body.
##
## `rect` is the complete source HWND rectangle. `fragments` are the visible
## (occlusion-subtracted) 2D rectangles of that window; each fragment's vertical
## sides act as walls and its visible top edge as a standable plane. Fully
## occluded windows contribute no fragments and therefore no collision.

var handle: int = 0
var process_id: int = 0
var rect := Rect2i()
var fragments: Array[Rect2i] = []
var top_segments: Array[Rect2i] = []
var z_order: int = 0
var title := ""
var process_name := ""
var window_class := ""
var maximized := false


static func from_snapshot(snapshot: Dictionary, fragments: Array, top_segments: Array) -> WindowBody:
	var body := WindowBody.new()
	body.handle = int(snapshot.get("handle", 0))
	body.process_id = int(snapshot.get("process_id", 0))
	body.rect = WindowPlatform.rect_from_value(snapshot.get("rect", Rect2i()))
	body.z_order = int(snapshot.get("z_order", 0))
	body.title = str(snapshot.get("title", ""))
	body.process_name = str(snapshot.get("process_name", ""))
	body.window_class = str(snapshot.get("class_name", ""))
	body.maximized = bool(snapshot.get("maximized", false))
	for fragment in fragments:
		if fragment is Rect2i:
			body.fragments.append(fragment as Rect2i)
	for segment in top_segments:
		if segment is Rect2i:
			body.top_segments.append(segment as Rect2i)
	return body


## Vertical collision walls of every visible fragment. `side` encodes the motion
## direction the edge blocks: a left edge (solid body on +x) has side=+1 and a
## right edge (solid body on -x) has side=-1, so a resolver only matches
## side == movement-dx. An occlusion cut therefore creates inner walls (the
## "cave" edges), which is the intended semantics — only visible portions of a
## window are solid.
func fragment_wall_edges() -> Array[Dictionary]:
	var edges: Array[Dictionary] = []
	for fragment in fragments:
		if fragment.size.y < 1:
			continue
		edges.append({
			"x": fragment.position.x,
			"top_y": fragment.position.y,
			"bottom_y": fragment.end.y,
			"side": 1,
			"handle": handle,
			"process_id": process_id,
		})
		edges.append({
			"x": fragment.end.x,
			"top_y": fragment.position.y,
			"bottom_y": fragment.end.y,
			"side": -1,
			"handle": handle,
			"process_id": process_id,
		})
	return edges


## Standable planes derived from the visible top segments. `y` is the foot
## plane (window top minus the sprite's foot offset), matching how WindowPlatform
## positions the pet's feet on its one-pixel top edge.
func standable_planes(foot_offset_y: float) -> Array[Dictionary]:
	var planes: Array[Dictionary] = []
	for segment in top_segments:
		planes.append({
			"left": float(segment.position.x),
			"right": float(segment.end.x),
			"y": float(segment.position.y) - foot_offset_y,
			"handle": handle,
			"process_id": process_id,
		})
	return planes
