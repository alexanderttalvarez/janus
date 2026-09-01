@tool
class_name ProjectionMetrics
extends Resource

## Presentation-only projection configuration. It never enters authority state,
## fingerprints, semantic IDs, or saves.

@export var identity: String = ""
@export var revision: int = 0
@export var grid_unit_size: float = 0.0
@export var floor_height: float = 0.0
@export var origin: Vector3 = Vector3.ZERO


func validate() -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if identity.is_empty():
		diagnostics.append({"code": "METRICS_IDENTITY_REQUIRED", "message": "projection metrics identity is required"})
	if revision < 0:
		diagnostics.append({"code": "METRICS_REVISION_INVALID", "message": "projection metrics revision cannot be negative"})
	if not is_finite(grid_unit_size) or grid_unit_size <= 0.0:
		diagnostics.append({"code": "GRID_UNIT_SIZE_INVALID", "message": "grid_unit_size must be finite and positive"})
	if not is_finite(floor_height) or floor_height <= 0.0:
		diagnostics.append({"code": "FLOOR_HEIGHT_INVALID", "message": "floor_height must be finite and positive"})
	if not _is_finite_vector(origin):
		diagnostics.append({"code": "PROJECTION_ORIGIN_INVALID", "message": "projection origin must be finite"})
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}


func value() -> Dictionary:
	return {
		"identity": identity,
		"revision": revision,
		"grid_unit_size": grid_unit_size,
		"floor_height": floor_height,
		"origin": origin,
	}


func matches(other: ProjectionMetrics) -> bool:
	return other != null and value() == other.value()


func _is_finite_vector(value_vector: Vector3) -> bool:
	return is_finite(value_vector.x) and is_finite(value_vector.y) and is_finite(value_vector.z)
