class_name PetGazeTracker
extends RefCounted

const DIRECTIONS := ["right", "down-right", "down", "down-left", "left", "up-left", "up", "up-right"]
const ANGLES := {
	"right": 0.0, "down-right": 45.0, "down": 90.0, "down-left": 135.0,
	"left": 180.0, "up-left": 225.0, "up": 270.0, "up-right": 315.0,
}

var deadzone_px := 24.0
var distance_hysteresis_px := 6.0
var angular_hysteresis_deg := 7.0
var direction := "center"

func update(offset: Vector2) -> Dictionary:
	var previous := direction
	direction = resolve(offset, previous)
	return {
		"direction": direction,
		"changed": direction != previous,
		"offset": offset,
		"distance_px": offset.length(),
		"angle_deg": _normalize_angle(rad_to_deg(atan2(offset.y, offset.x))),
	}

func resolve(offset: Vector2, previous := "center") -> String:
	var distance := offset.length()
	var enter_radius := deadzone_px + distance_hysteresis_px
	var leave_radius := deadzone_px - distance_hysteresis_px
	if previous == "center":
		if distance < enter_radius:
			return "center"
	elif distance <= leave_radius:
		return "center"
	elif distance < enter_radius:
		return previous
	var angle := _normalize_angle(rad_to_deg(atan2(offset.y, offset.x)))
	if previous != "center":
		var difference := absf(_normalize_angle(angle) - _normalize_angle(float(ANGLES.get(previous, 0.0))))
		difference = minf(difference, 360.0 - difference)
		if difference <= 22.5 + angular_hysteresis_deg:
			return previous
	var sector := int(floor((_normalize_angle(angle) + 22.5) / 45.0)) % DIRECTIONS.size()
	return DIRECTIONS[sector]

func reset(next_direction := "center") -> void:
	direction = next_direction

func _normalize_angle(angle: float) -> float:
	return fposmod(angle, 360.0)

