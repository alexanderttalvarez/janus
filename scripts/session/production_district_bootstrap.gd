class_name ProductionDistrictBootstrap
extends Resource

## Immutable composition-owned new-game configuration from Decision 29.
## V2 loads resolve their own layout_ref and never consult this bootstrap.

@export var layout_id: String = ""
@export_file("*.tres") var definition_path: String = ""
@export var projection_metrics_identity: String = ""
@export var projection_metrics_revision: int = 0
@export var grid_unit_size: float = 0.0
@export var floor_height: float = 0.0
@export var origin: Vector3 = Vector3.ZERO


func validate() -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if layout_id.is_empty():
		diagnostics.append({"code": "BOOTSTRAP_LAYOUT_ID_REQUIRED", "message": "production bootstrap requires an explicit layout identity"})
	if definition_path.is_empty():
		diagnostics.append({"code": "BOOTSTRAP_DEFINITION_PATH_REQUIRED", "message": "production bootstrap requires an explicit definition resource"})
	if projection_metrics_identity.is_empty() or projection_metrics_revision <= 0:
		diagnostics.append({"code": "BOOTSTRAP_METRICS_REQUIRED", "message": "production bootstrap requires explicit projection metrics identity and revision"})
	if grid_unit_size <= 0.0 or floor_height <= 0.0:
		diagnostics.append({"code": "BOOTSTRAP_METRICS_INVALID", "message": "production bootstrap projection metrics must be positive"})
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}
