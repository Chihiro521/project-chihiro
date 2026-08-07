class_name PetEcologyClock
extends RefCounted

const SUPPORTED_RATES := [1.0, 10.0, 60.0, 240.0]

var _rate := 1.0
var _elapsed_ms := 0.0


func reset() -> void:
	_elapsed_ms = 0.0


func advance(real_delta_seconds: float) -> float:
	var scaled := maxf(0.0, real_delta_seconds) * _rate
	_elapsed_ms += scaled * 1000.0
	return scaled


func set_rate(value: float) -> bool:
	for supported in SUPPORTED_RATES:
		if is_equal_approx(float(supported), value):
			_rate = float(supported)
			return true
	return false


func rate() -> float:
	return _rate


func elapsed_ms() -> int:
	return int(_elapsed_ms)


func is_accelerated() -> bool:
	return _rate > 1.0


func snapshot() -> Dictionary:
	return {
		"rate": _rate,
		"elapsed_ms": elapsed_ms(),
		"accelerated": is_accelerated(),
	}

