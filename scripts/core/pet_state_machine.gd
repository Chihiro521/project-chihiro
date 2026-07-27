class_name PetStateMachine
extends RefCounted

signal transitioned(from: String, to: String, event: Dictionary)

const ACTIVE_STATES := {
	"boot": true, "idle": true, "notice": true, "cursor_track": true,
	"cursor_startle": true, "cursor_annoyed": true, "cursor_dizzy": true,
	"head_pat": true, "poke_cheek": true, "menu_wait": true, "clock_scare": true,
	"react": true, "turn": true, "takeoff": true, "float": true,
	"edge_patrol": true, "drag_fall": true, "land": true, "dragged": true,
}
const DIRECT_INTERACTION_STATES := {
	"idle": true, "notice": true, "cursor_track": true, "cursor_startle": true,
	"cursor_annoyed": true, "cursor_dizzy": true, "react": true, "turn": true,
	"takeoff": true, "float": true, "edge_patrol": true, "drag_fall": true,
	"land": true, "head_pat": true, "poke_cheek": true, "clock_scare": true,
}
const PASSIVE_CURSOR_STATES := {"idle": true, "notice": true, "cursor_track": true}

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
	if event_type == "DRAG_START":
		return "dragged"
	if current == "dragged":
		return "drag_fall" if event_type == "DRAG_END" else current
	if event_type == "MENU_OPEN" and current != "boot":
		return "menu_wait"
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
		if event_type == "CURSOR_SWEEP":
			return "cursor_annoyed"
		if event_type == "CURSOR_CIRCLE":
			return "cursor_dizzy"
	if DIRECT_INTERACTION_STATES.has(current):
		if event_type == "HEAD_PAT_START":
			return "head_pat"
		if event_type == "POKE":
			return "poke_cheek"
	if event_type == "INTERACTION_END" and current in [
		"head_pat", "poke_cheek", "clock_scare", "cursor_startle",
		"cursor_annoyed", "cursor_dizzy",
	]:
		return str(event.get("resume", "idle"))
	match current:
		"boot":
			return "idle" if event_type == "CLIP_END" else current
		"idle":
			if event_type == "NOTICE": return "notice"
			if event_type == "CLICK": return "react"
			if event_type == "EDGE_PATROL_START": return "edge_patrol"
			if event_type == "WANDER": return "takeoff" if not bool(event.get("needs_turn", true)) else "turn"
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
		"float", "drag_fall":
			if event_type == "ARRIVE": return "land"
		"edge_patrol":
			if event_type == "EDGE_PATROL_END": return "idle"
			if event_type == "CLICK": return "react"
		"land":
			if event_type == "CLIP_END": return "idle"
	return current

