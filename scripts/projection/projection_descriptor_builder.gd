class_name ProjectionDescriptorBuilder
extends RefCounted

## Pure H2-to-presentation descriptor builder. It creates no Nodes and writes no
## district authority state.


func build_floor_descriptors(
	snapshot: ResolvedDistrictSnapshot,
	state: Dictionary,
	metrics: ProjectionMetrics
) -> Dictionary:
	if snapshot == null:
		return _failure("SNAPSHOT_REQUIRED", "projection requires an immutable snapshot")
	if metrics == null:
		return _failure("METRICS_REQUIRED", "projection metrics are required")
	var metrics_validation: Dictionary = metrics.validate()
	if not bool(metrics_validation.get("valid", false)):
		return {"valid": false, "diagnostics": metrics_validation.get("diagnostics", [])}
	var descriptors: Array[Dictionary] = []
	var data: Dictionary = snapshot.get_data()
	for floor: Dictionary in data.get("floors", []):
		var pose: Dictionary = floor.get("pose", {})
		var rect: Dictionary = floor.get("rect_quarter", {})
		var pose_result: Dictionary = project_pose(pose, metrics)
		if not bool(pose_result.get("valid", false)):
			return pose_result
		var bounds_result: Dictionary = project_bounds(rect, int(floor.get("elevation", 0)), metrics)
		if not bool(bounds_result.get("valid", false)):
			return bounds_result
		var floor_state: Dictionary = _floor_state_for(state, String(floor.get("id", "")))
		descriptors.append({
			"floor_id": String(floor.get("id", "")),
			"plot_id": String(floor.get("plot_id", "")),
			"elevation": int(floor.get("elevation", 0)),
			"position": pose_result["position"],
			"rotation_y": pose_result["rotation_y"],
			"bounds": bounds_result["bounds"],
			"acquired_cells": floor_state.get("acquired_cells", []).duplicate(true),
			"constructed_cells": floor_state.get("constructed_cells", []).duplicate(true),
		})
	return {"valid": true, "descriptors": descriptors, "metrics": metrics.value(), "diagnostics": []}


func project_pose(pose: Dictionary, metrics: ProjectionMetrics) -> Dictionary:
	if metrics == null:
		return _failure("METRICS_REQUIRED", "projection metrics are required")
	var metrics_validation: Dictionary = metrics.validate()
	if not bool(metrics_validation.get("valid", false)):
		return {"valid": false, "diagnostics": metrics_validation.get("diagnostics", [])}
	var facing: String = String(pose.get("facing", "NONE"))
	var rotation_y: float = 0.0
	match facing:
		"NORTH", "NONE":
			rotation_y = 0.0
		"EAST":
			rotation_y = -PI / 2.0
		"SOUTH":
			rotation_y = PI
		"WEST":
			rotation_y = PI / 2.0
		_:
			return _failure("FACING_INVALID", "unsupported projection facing")
	var x4: int = int(pose.get("x4", 0))
	var z4: int = int(pose.get("z4", 0))
	var elevation: int = int(pose.get("elevation", 0))
	return {
		"valid": true,
		"position": metrics.origin + Vector3(float(x4) / 4.0 * metrics.grid_unit_size, float(elevation) * metrics.floor_height, float(z4) / 4.0 * metrics.grid_unit_size),
		"rotation_y": rotation_y,
		"diagnostics": [],
	}


func project_bounds(rect: Dictionary, elevation: int, metrics: ProjectionMetrics) -> Dictionary:
	if metrics == null:
		return _failure("METRICS_REQUIRED", "projection metrics are required")
	var metrics_validation: Dictionary = metrics.validate()
	if not bool(metrics_validation.get("valid", false)):
		return {"valid": false, "diagnostics": metrics_validation.get("diagnostics", [])}
	var minimum_x4: int = int(rect.get("minimum_x4", 0))
	var minimum_z4: int = int(rect.get("minimum_z4", 0))
	var maximum_x4: int = int(rect.get("maximum_x4", minimum_x4))
	var maximum_z4: int = int(rect.get("maximum_z4", minimum_z4))
	var minimum: Vector3 = metrics.origin + Vector3(float(minimum_x4) / 4.0 * metrics.grid_unit_size, float(elevation) * metrics.floor_height, float(minimum_z4) / 4.0 * metrics.grid_unit_size)
	var size: Vector3 = Vector3(float(maximum_x4 - minimum_x4) / 4.0 * metrics.grid_unit_size, 0.0, float(maximum_z4 - minimum_z4) / 4.0 * metrics.grid_unit_size)
	return {"valid": true, "bounds": AABB(minimum, size), "diagnostics": []}


func _floor_state_for(state: Dictionary, floor_id: String) -> Dictionary:
	for plot_state: Dictionary in state.get("plot_states", []):
		for floor_state: Dictionary in plot_state.get("floor_states", []):
			if String(floor_state.get("floor_id", "")) == floor_id:
				return floor_state
	return {"floor_id": floor_id, "acquired_cells": [], "constructed_cells": []}


func _failure(code: String, message: String) -> Dictionary:
	return {"valid": false, "diagnostics": [{"code": code, "message": message}]}
