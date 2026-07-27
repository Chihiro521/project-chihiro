class_name PetDragMotion
extends RefCounted

const ENTER_SPEED := 220.0
const EXIT_SPEED := 95.0
const REVERSAL_SPEED := 280.0
const IDLE_BRAKE_MS := 110.0

static func classify(velocity_x: float, current: String) -> String:
	var speed := absf(velocity_x)
	var direction := "left" if velocity_x < 0.0 else "right"
	if current == direction and speed >= EXIT_SPEED:
		return current
	if speed < ENTER_SPEED:
		return "hold"
	return direction

static func intent_direction(intent: String) -> int:
	if intent == "left": return -1
	if intent == "right": return 1
	return 0

static func is_reversal(previous_direction: int, next_intent: String, velocity_x: float) -> bool:
	var next_direction := intent_direction(next_intent)
	return previous_direction != 0 and next_direction != 0 and next_direction != previous_direction and absf(velocity_x) >= REVERSAL_SPEED

static func should_brake(phase: String, elapsed_ms: float) -> bool:
	return phase in ["left", "right"] and elapsed_ms >= IDLE_BRAKE_MS

