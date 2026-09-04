class_name LegacyExteriorAccessAdapter
extends RefCounted

## H3/H5 compatibility boundary for legacy exterior-arrival callers.
## It only translates an authored source ID; eligibility remains H5/H6-owned.


func to_arrival_source_id(authored_source_id: String) -> Dictionary:
	if authored_source_id.is_empty():
		return {"valid": false, "diagnostics": [{"code": "ARRIVAL_SOURCE_ID_REQUIRED", "message": "authored arrival source ID is required"}]}
	return {"valid": true, "arrival_source_id": authored_source_id, "requires_h5_eligibility": true, "diagnostics": []}
