class_name PetUmbrellaFall
extends RefCounted

const OPEN_WINDOW_MS := 360.0
const CLOSE_WINDOW_MS := 360.0
const MAX_DRIFT_PX := 52.0

static func should_use(fall_distance_px: float, family_available: bool, threshold_px := 120.0) -> bool:
	return family_available and fall_distance_px >= threshold_px

static func duration_ms(fall_distance_px: float, minimum_ms := 1000.0, maximum_ms := 2200.0) -> float:
	var lower := minf(minimum_ms, maximum_ms)
	var upper := maxf(minimum_ms, maximum_ms)
	return roundf(clampf(600.0 + maxf(0.0, fall_distance_px) * 4.2, lower, upper))

static func phase(elapsed_ms: float, duration: float) -> String:
	var elapsed := clampf(elapsed_ms, 0.0, maxf(0.0, duration))
	if elapsed < minf(OPEN_WINDOW_MS, duration * 0.36):
		return "open"
	if duration - elapsed <= minf(CLOSE_WINDOW_MS, duration * 0.36):
		return "close"
	return "float"

static func descent_progress(progress: float) -> float:
	var value := clampf(progress, 0.0, 1.0)
	return clampf(value + 0.045 * sin(PI * value), 0.0, 1.0)

static func clamp_drift(offset_px: float, maximum := MAX_DRIFT_PX) -> float:
	return clampf(offset_px, -absf(maximum), absf(maximum))

