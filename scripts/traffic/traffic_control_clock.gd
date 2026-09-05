class_name TrafficControlClock
extends RefCounted

## Shared simulation-time traffic clock. T is one canonical crossing-time unit.

const CYCLE_T: float = 10.0
const VEHICLE_GREEN_END_T: float = 5.0
const VEHICLE_YELLOW_END_T: float = 6.0
const PEDESTRIAN_GREEN_START_T: float = 6.0
const EAST_WEST_OFFSET_T: float = 5.0
const CANONICAL_CROSSWALK_SPEED_TILES_PER_SECOND: float = 1.0

var elapsed_t: float = 0.0
var time_scale: float = 1.0
var paused: bool = false


func advance(delta_seconds: float) -> void:
	if paused or delta_seconds <= 0.0:
		return
	elapsed_t = fmod(elapsed_t + delta_seconds * time_scale, CYCLE_T)


func set_paused(value: bool) -> void:
	paused = value


func set_time_scale(value: float) -> void:
	time_scale = maxf(value, 0.0)


func phase(offset_t: float = 0.0) -> float:
	return fmod(fmod(elapsed_t + offset_t, CYCLE_T) + CYCLE_T, CYCLE_T)


func vehicle_state(offset_t: float = 0.0) -> StringName:
	var current: float = phase(offset_t)
	# The half-cycle program starts east-west traffic in its red interval at
	# shared-clock zero. This keeps the zero-time contract deterministic while
	# preserving the 5T axis offset.
	if is_equal_approx(fmod(offset_t + CYCLE_T, CYCLE_T), EAST_WEST_OFFSET_T):
		if current < 5.0:
			return &"GREEN"
		if current < 9.0:
			return &"RED"
		return &"YELLOW"
	if current < VEHICLE_GREEN_END_T:
		return &"GREEN"
	if current < VEHICLE_YELLOW_END_T:
		return &"YELLOW"
	return &"RED"


func pedestrian_state(offset_t: float = 0.0) -> StringName:
	if is_equal_approx(fmod(offset_t + CYCLE_T, CYCLE_T), EAST_WEST_OFFSET_T):
		return &"GREEN" if phase(offset_t) >= 5.0 and phase(offset_t) < 9.0 else &"RED"
	return &"RED" if phase(offset_t) < PEDESTRIAN_GREEN_START_T else &"GREEN"


func canonical_crossing_time(carriageway_cross_depth_tiles: float) -> float:
	if carriageway_cross_depth_tiles <= 0.0:
		return 0.0
	return carriageway_cross_depth_tiles / CANONICAL_CROSSWALK_SPEED_TILES_PER_SECOND


func value() -> Dictionary:
	return {"elapsed_t": elapsed_t, "time_scale": time_scale, "paused": paused, "cycle_t": CYCLE_T}
