class_name CameraBoundsSnapshot
extends RefCounted

## Immutable camera region derived from the Active Plot rectangle union.
## Rectangles remain in quarter-grid district coordinates; world conversion is
## explicit so editor and runtime use the same geometry.

var definition_fingerprint: String = ""
var district_revision: int = -1
var topology_revision: int = -1
var active_plot_ids: Array[String] = []
var expanded_rectangles: Array[Dictionary] = []
var margin: float = 0.0
var margin_quarter: float = 0.0
var grid_unit_size: float = 1.0
var origin: Vector3 = Vector3.ZERO
var empty: bool = true


func initialize(
	p_definition_fingerprint: String,
	p_district_revision: int,
	p_topology_revision: int,
	p_active_plot_ids: Array,
	p_rectangles: Array,
	p_margin: float,
	p_margin_quarter: float,
	p_grid_unit_size: float,
	p_origin: Vector3
) -> void:
	definition_fingerprint = p_definition_fingerprint
	district_revision = p_district_revision
	topology_revision = p_topology_revision
	active_plot_ids = _sorted_strings(p_active_plot_ids)
	expanded_rectangles = _typed_copy(p_rectangles)
	margin = p_margin
	margin_quarter = p_margin_quarter
	grid_unit_size = p_grid_unit_size
	origin = p_origin
	empty = expanded_rectangles.is_empty()


func duplicate_value() -> CameraBoundsSnapshot:
	var copy: CameraBoundsSnapshot = load("res://scripts/camera/camera_bounds_snapshot.gd").new() as CameraBoundsSnapshot
	copy.initialize(definition_fingerprint, district_revision, topology_revision, active_plot_ids, expanded_rectangles, margin, margin_quarter, grid_unit_size, origin)
	return copy


func contains_world_position(position: Vector3) -> bool:
	return _contains_quarter(_world_to_quarter(position))


func clamp_world_position(position: Vector3) -> Vector3:
	if empty:
		return position
	var quarter: Vector2 = _world_to_quarter(position)
	var clamped_quarter: Vector2 = _nearest_quarter_point(quarter)
	return Vector3(
		origin.x + clamped_quarter.x * grid_unit_size / 4.0,
		position.y,
		origin.z + clamped_quarter.y * grid_unit_size / 4.0
	)


func value() -> Dictionary:
	return {
		"definition_fingerprint": definition_fingerprint,
		"district_revision": district_revision,
		"topology_revision": topology_revision,
		"active_plot_ids": active_plot_ids.duplicate(),
		"expanded_rectangles": expanded_rectangles.duplicate(true),
		"margin": margin,
		"margin_quarter": margin_quarter,
		"grid_unit_size": grid_unit_size,
		"origin": origin,
		"empty": empty,
	}


func _contains_quarter(point: Vector2) -> bool:
	for rectangle: Dictionary in expanded_rectangles:
		if point.x >= float(rectangle["minimum_x4"]) and point.x <= float(rectangle["maximum_x4"]) and point.y >= float(rectangle["minimum_z4"]) and point.y <= float(rectangle["maximum_z4"]):
			return true
	return false


func _nearest_quarter_point(point: Vector2) -> Vector2:
	if _contains_quarter(point):
		return point
	var best_point: Vector2 = point
	var best_distance: float = INF
	var best_index: int = -1
	for index: int in range(expanded_rectangles.size()):
		var rectangle: Dictionary = expanded_rectangles[index]
		var candidate := Vector2(
			clampf(point.x, float(rectangle["minimum_x4"]), float(rectangle["maximum_x4"])),
			clampf(point.y, float(rectangle["minimum_z4"]), float(rectangle["maximum_z4"]))
		)
		var distance: float = point.distance_squared_to(candidate)
		if distance < best_distance or (is_equal_approx(distance, best_distance) and (best_index < 0 or index < best_index)):
			best_point = candidate
			best_distance = distance
			best_index = index
	return best_point


func _world_to_quarter(position: Vector3) -> Vector2:
	var safe_unit: float = grid_unit_size if not is_zero_approx(grid_unit_size) else 1.0
	return Vector2((position.x - origin.x) * 4.0 / safe_unit, (position.z - origin.z) * 4.0 / safe_unit)


func _typed_copy(records: Array) -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	for record: Variant in records:
		if record is Dictionary:
			copied.append(record.duplicate(true))
	copied.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.get("source_plot_id", "")) < String(right.get("source_plot_id", "")))
	return copied


func _sorted_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		result.append(String(value))
	result.sort()
	return result
