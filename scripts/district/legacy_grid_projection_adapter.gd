class_name LegacyGridProjectionAdapter
extends RefCounted

## Explicit bridge for legacy consumers that still identify one fixed grid.

const LEGACY_PLOT_ID: String = "plot_0"


func to_runtime_plot_id(runtime_plot_id: String) -> Dictionary:
	if runtime_plot_id.is_empty():
		return {"valid": false, "diagnostics": [{"code": "LEGACY_PLOT_ID_REQUIRED", "message": "runtime Plot ID is required"}]}
	return {"valid": true, "legacy_plot_id": LEGACY_PLOT_ID, "runtime_plot_id": runtime_plot_id, "diagnostics": []}
