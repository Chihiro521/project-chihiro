class_name PetStateMachine
extends RefCounted

signal transitioned(from: String, to: String, event: Dictionary)

const ACTIVE_STATES := {
	"boot": true, "idle": true, "notice": true, "cursor_track": true,
	"cursor_startle": true, "cursor_annoyed": true, "cursor_dizzy": true, "cursor_warning": true,
	"head_pat": true, "poke_cheek": true, "menu_wait": true, "clock_scare": true,
	"react": true, "turn": true, "takeoff": true, "float": true,
	"edge_patrol": true, "drag_fall": true, "land": true, "dragged": true,
	"ambient_action": true, "sleeping": true, "platform_transition": true,
	"platform_walk": true, "platform_sit": true,
	"manual_control": true, "roam_walk": true,
	"drag_slide": true, "drag_throw": true, "wall_climb": true,
	"cursor_play_chase": true, "cursor_confiscate": true, "icon_collect": true, "icon_transfer": true,
	"window_hop_up": true,
}
const DIRECT_INTERACTION_STATES := {
	"idle": true, "notice": true, "cursor_track": true, "cursor_startle": true,
	"cursor_annoyed": true, "cursor_dizzy": true, "react": true, "turn": true,
	"takeoff": true, "float": true, "edge_patrol": true, "drag_fall": true,
	"land": true, "head_pat": true, "poke_cheek": true, "clock_scare": true,
	"ambient_action": true, "sleeping": true, "platform_transition": true,
	"platform_walk": true, "platform_sit": true, "manual_control": true,
	"roam_walk": true, "drag_slide": true, "drag_throw": true, "window_hop_up": true,
}
const PASSIVE_CURSOR_STATES := {"idle": true, "notice": true, "cursor_track": true}
const AUTONOMOUS_ACTION_STATES := {
	"ambient_action": true, "sleeping": true, "platform_transition": true,
	"platform_walk": true, "platform_sit": true, "roam_walk": true, "wall_climb": true,
	"cursor_play_chase": true, "cursor_confiscate": true, "icon_collect": true, "icon_transfer": true,
	"window_hop_up": true,
}

var state := "boot"

func dispatch(event: Dictionary) -> String:
	var next := _reduce(state, event)
	if next == state:
		return state
	var previous := state
	state = next
	transitioned.emit(previous, next, event)
	return state

func reset() -> void:
	dispatch({"type": "RESET"})

func _reduce(current: String, event: Dictionary) -> String:
	var event_type := str(event.get("type", ""))
	if event_type == "RESET":
		return "boot"
	if event_type == "FULLSCREEN_ENTER" and ACTIVE_STATES.has(current):
		return "suspended"
	if current == "suspended":
		return "idle" if event_type == "FULLSCREEN_EXIT" else current
	# Cursor custody runs independently after the bagging clip. Its timed reverse
	# animation is a safety transition and may pre-empt whichever ordinary action
	# is active when the custody period expires.
	if event_type == "CURSOR_RELEASE_START" and ACTIVE_STATES.has(current) and current != "boot":
		return "cursor_confiscate"
	if event_type == "DRAG_START":
		return "dragged"
	if current == "dragged":
		if event_type == "SLIDE_START": return "drag_slide"
		if event_type == "THROW_START": return "drag_throw"
		return "drag_fall" if event_type == "DRAG_END" else current
	if event_type == "MENU_OPEN" and current != "boot":
		return "menu_wait"
	if event_type == "PLATFORM_LOST" and ACTIVE_STATES.has(current) and current != "boot":
		return "drag_fall"
	if current == "menu_wait":
		if event_type == "MENU_SELECT_CLOCK":
			return "clock_scare"
		if event_type == "INTERACTION_END":
			return str(event.get("resume", "idle"))
		if event_type == "MENU_CLOSE":
			return "idle"
		return current
	if PASSIVE_CURSOR_STATES.has(current):
		if event_type == "CURSOR_STARTLE":
			return "cursor_startle"
		if event_type == "CURSOR_WARNING":
			return "cursor_warning"
		if event_type == "CURSOR_SWEEP":
			return "cursor_annoyed"
		if event_type == "CURSOR_CIRCLE":
			return "cursor_dizzy"
	if DIRECT_INTERACTION_STATES.has(current):
		if event_type == "HEAD_PAT_START":
			return "head_pat"
		if event_type == "POKE":
			return "poke_cheek"
	if current in ["notice", "cursor_track"] and event_type == "ACTION_START":
		var cursor_action := str(event.get("state", ""))
		if cursor_action in ["cursor_play_chase", "cursor_confiscate"]:
			return cursor_action
	if event_type == "INTERACTION_END" and current in [
		"head_pat", "poke_cheek", "clock_scare", "cursor_startle",
		"cursor_annoyed", "cursor_dizzy", "cursor_warning", "manual_control",
	]:
		return str(event.get("resume", "idle"))
	if AUTONOMOUS_ACTION_STATES.has(current):
		if event_type in ["ACTION_END", "CLIP_END"]:
			return "idle"
		if current == "sleeping" and event_type == "SLEEP_WAKE":
			return "ambient_action" if bool(event.get("play_wake", true)) else "idle"
	if event_type == "MANUAL_CONTROL_START" and ACTIVE_STATES.has(current) and current not in ["boot", "menu_wait", "suspended"]:
		return "manual_control"
	match current:
		"boot":
			return "idle" if event_type == "CLIP_END" else current
		"idle":
			if event_type == "NOTICE": return "notice"
			if event_type == "CLICK": return "react"
			if event_type == "EDGE_PATROL_START": return "edge_patrol"
			if event_type == "ROAM_WALK_START": return "roam_walk"
			if event_type == "WALL_CLIMB_START": return "wall_climb"
			if event_type == "WANDER": return "takeoff" if not bool(event.get("needs_turn", true)) else "turn"
			if event_type == "ACTION_START":
				var requested := str(event.get("state", "ambient_action"))
				return requested if AUTONOMOUS_ACTION_STATES.has(requested) else "ambient_action"
		"notice":
			if event_type == "POINTER_LEAVE": return "idle"
			if event_type == "CLICK": return "react"
			if event_type == "CLIP_END": return "cursor_track"
		"cursor_track":
			if event_type == "POINTER_LEAVE": return "idle"
			if event_type == "CLICK": return "react"
		"poke_cheek", "clock_scare", "react":
			if event_type == "CLIP_END": return "idle"
		"turn":
			if event_type == "CLIP_END": return "takeoff"
		"takeoff":
			if event_type == "CLIP_END": return "float"
		"float", "drag_fall", "drag_throw":
			if event_type == "ARRIVE": return "land"
		"drag_slide":
			if event_type == "SLIDE_END": return "idle"
		"edge_patrol":
			if event_type == "EDGE_PATROL_END": return "idle"
			if event_type == "CLICK": return "react"
		"land":
			if event_type == "CLIP_END": return "idle"
	return current
