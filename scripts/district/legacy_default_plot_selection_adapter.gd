class_name LegacyDefaultPlotSelectionAdapter
extends RefCounted

## Explicit compatibility bridge for callers that formerly omitted Plot scope.


func resolve_initial_plot(snapshot: ResolvedDistrictSnapshot) -> Dictionary:
	if snapshot == null:
		return {"valid": false, "diagnostics": [{"code": "SNAPSHOT_REQUIRED", "message": "resolved snapshot is required"}]}
	for section: Dictionary in snapshot.get_data().get("sections", []):
		if bool(section.get("initially_owned", false)):
			return {"valid": true, "runtime_plot_id": String(section.get("plot_id", "")), "diagnostics": []}
	return {"valid": false, "diagnostics": [{"code": "INITIAL_PLOT_UNRESOLVED", "message": "no initially owned Plot exists in the resolved snapshot"}]}
