class_name PetDialogueScheduler
extends RefCounted

const INITIAL_AMBIENT_DELAY_MS := 90000.0
const RETRY_DELAY_MS := 5000.0

var next_ambient_attempt_ms := -INF

func reset(now_ms: float) -> void:
	next_ambient_attempt_ms = now_ms + INITIAL_AMBIENT_DELAY_MS

func should_attempt(now_ms: float, availability: Dictionary = {}) -> bool:
	if now_ms < next_ambient_attempt_ms:
		return false
	# Dialogue availability intentionally has no action or state-machine input.
	# Sleeping, gaze, dragging and autonomous animations cannot starve speech.
	var enabled := bool(availability.get("enabled", true))
	var surface_visible := bool(availability.get("surface_visible", true))
	var bubble_busy := bool(availability.get("bubble_busy", false))
	next_ambient_attempt_ms = now_ms + RETRY_DELAY_MS
	return enabled and surface_visible and not bubble_busy

func commit_attempt(now_ms: float, director_next_ms: float = -INF) -> void:
	var retry_at := now_ms + RETRY_DELAY_MS
	next_ambient_attempt_ms = maxf(retry_at, director_next_ms) if director_next_ms > now_ms else retry_at

func seconds_until_attempt(now_ms: float) -> float:
	return maxf(0.0, (next_ambient_attempt_ms - now_ms) / 1000.0)
