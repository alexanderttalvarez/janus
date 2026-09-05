class_name LegacyVisitorSpawnAdapter
extends RefCounted

## H8-only bridge from a selected source record to the existing visitor
## preparation path. It never maps or persists legacy corner identities.


func bridge_selected_source(arrival_source_id: String, source_record: Dictionary) -> Dictionary:
	if arrival_source_id.is_empty() or source_record.is_empty():
		return {"valid": false, "diagnostics": [{"code": "LEGACY_VISITOR_SOURCE_REQUIRED", "message": "a selected arrival source record is required"}]}
	if String(source_record.get("arrival_source_id", arrival_source_id)) != arrival_source_id:
		return {"valid": false, "diagnostics": [{"code": "LEGACY_VISITOR_SOURCE_MISMATCH", "message": "selected source identity does not match the source record"}]}
	return {
		"valid": true,
		"arrival_source_id": arrival_source_id,
		"source": source_record.duplicate(true),
		"diagnostics": [],
	}
