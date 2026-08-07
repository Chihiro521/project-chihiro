class_name PetRoamPlanner
extends RefCounted

## Pure generator for the random multi-leg autonomous roam.
## Produces 2-4 connected legs: "walk" (ground, patrol_floor), "fly" (parabola to
## a floor point), or "fly_drop" (parabola that drops to the floor partway —
## "逛到一半跳下来" / "在空中直接下坠衔接").
##
## Every leg carries {type, from, to, duration_ms}; fly/fly_drop also carry
## {fly_target, arc_height} and optionally {drop_at_progress}. Legs chain so that
## leg[i].from == leg[i-1].to.

const DEFAULT_MIN_LEGS := 2
const DEFAULT_MAX_LEGS := 4
const DEFAULT_WALK_PROBABILITY := 0.55
const DEFAULT_DROP_PROBABILITY := 0.35
const GROUND_SPEED := 82.0
const FLIGHT_SPEED := 150.0
const FALL_SPEED := 900.0


static func build_legs(
	start: Vector2,
	pet_size: Vector2,
	screens: Array[Rect2],
	seed_value: String,
	options: Dictionary = {}
) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_value)
	var min_legs := int(options.get("min_legs", DEFAULT_MIN_LEGS))
	var max_legs := int(options.get("max_legs", DEFAULT_MAX_LEGS))
	var walk_probability := float(options.get("walk_probability", DEFAULT_WALK_PROBABILITY))
	var drop_probability := float(options.get("drop_probability", DEFAULT_DROP_PROBABILITY))
	var legs: Array[Dictionary] = []
	var current := start
	var leg_count := rng.randi_range(min_legs, max_legs)
	var made_fly := false
	for index in range(leg_count):
		var screen := _screen_for_point(current, screens)
		var floor_y := screen.end.y - pet_size.y
		var on_floor := absf(current.y - floor_y) < 8.0
		var is_last := index == leg_count - 1
		var leg: Dictionary = {}
		if not on_floor:
			# Defensive: an airborne start drops straight to the floor below.
			leg = {
				"type": "fly_drop",
				"from": current,
				"to": Vector2(clampf(current.x, screen.position.x + 18.0, screen.end.x - pet_size.x - 18.0), floor_y),
				"fly_target": current,
				"arc_height": 0.0,
				"duration_ms": maxf(400.0, absf(current.y - floor_y) / FALL_SPEED * 1000.0),
				"drop_at_progress": 0.0,
			}
		elif is_last and not made_fly:
			# Guarantee the path contains at least one flight.
			leg = _make_fly(rng, current, pet_size, screens, screen, null)
		else:
			var roll := rng.randf()
			if roll < walk_probability:
				leg = _make_walk(rng, current, pet_size, screen)
			else:
				var drop_at: Variant = null
				if rng.randf() < drop_probability:
					drop_at = rng.randf_range(0.5, 0.7)
				leg = _make_fly(rng, current, pet_size, screens, screen, drop_at)
		legs.append(leg)
		current = leg.get("to", current)
		if str(leg.get("type", "")) in ["fly", "fly_drop"]:
			made_fly = true
	return legs


static func _make_walk(rng: RandomNumberGenerator, current: Vector2, pet_size: Vector2, screen: Rect2) -> Dictionary:
	var floor_y := screen.end.y - pet_size.y
	var min_x := screen.position.x + 18.0
	var max_x := screen.end.x - pet_size.x - 18.0
	var target_x := rng.randf_range(min_x, max_x)
	if absf(target_x - current.x) < 80.0:
		target_x = max_x if current.x < (min_x + max_x) * 0.5 else min_x
	var to := Vector2(target_x, floor_y)
	return {
		"type": "walk",
		"from": current,
		"to": to,
		"duration_ms": maxf(600.0, absf(target_x - current.x) / GROUND_SPEED * 1000.0),
	}


static func _make_fly(rng: RandomNumberGenerator, current: Vector2, pet_size: Vector2, screens: Array[Rect2], screen: Rect2, drop_at: Variant) -> Dictionary:
	var target_screen := screen
	if screens.size() > 1 and rng.randf() < 0.3:
		target_screen = screens[rng.randi_range(0, screens.size() - 1)]
	var min_x := target_screen.position.x + 18.0
	var max_x := target_screen.end.x - pet_size.x - 18.0
	var target_x := rng.randf_range(min_x, max_x)
	var fly_target := Vector2(target_x, target_screen.end.y - pet_size.y)
	var distance := current.distance_to(fly_target)
	var duration_ms := clampf(distance / FLIGHT_SPEED * 1000.0, 850.0, 3200.0)
	var arc_height := clampf(distance * 0.12, 60.0, 220.0)
	var leg := {
		"type": "fly",
		"from": current,
		"to": fly_target,
		"fly_target": fly_target,
		"arc_height": arc_height,
		"duration_ms": duration_ms,
		"drop_at_progress": drop_at,
	}
	if drop_at != null:
		# Mid-roam drop: the actual landing is the floor below the drop point.
		var drop_x := lerpf(current.x, fly_target.x, float(drop_at))
		var drop_screen := _screen_for_point(Vector2(drop_x, current.y), screens)
		leg["type"] = "fly_drop"
		leg["to"] = Vector2(drop_x, drop_screen.end.y - pet_size.y)
	return leg


static func _screen_for_point(point: Vector2, screens: Array[Rect2]) -> Rect2:
	if screens.is_empty():
		return Rect2(0.0, 0.0, 1280.0, 720.0)
	for screen in screens:
		if screen.has_point(point):
			return screen
	var nearest := screens[0]
	var best := INF
	for screen in screens:
		var distance := point.distance_squared_to(screen.get_center())
		if distance < best:
			best = distance
			nearest = screen
	return nearest
