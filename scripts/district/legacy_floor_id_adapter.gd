class_name LegacyFloorIdAdapter
extends RefCounted

## Explicit compatibility conversion for legacy floor labels at the boundary.


func to_elevation(floor_id: String) -> Dictionary:
	if floor_id == "G":
		return {"valid": true, "elevation": 0, "diagnostics": []}
	if floor_id.length() < 2:
		return {"valid": false, "diagnostics": [{"code": "LEGACY_FLOOR_ID_INVALID", "message": "legacy floor ID is invalid"}]}
	var prefix: String = floor_id.substr(0, 1)
	var suffix: String = floor_id.substr(1)
	if not suffix.is_valid_int() or (prefix != "F" and prefix != "B" and prefix != "U"):
		return {"valid": false, "diagnostics": [{"code": "LEGACY_FLOOR_ID_INVALID", "message": "legacy floor ID must use G, F<n>, B<n>, or U<n>"}]}
	var magnitude: int = int(suffix)
	if magnitude <= 0:
		return {"valid": false, "diagnostics": [{"code": "LEGACY_FLOOR_ID_INVALID", "message": "legacy floor magnitude must be positive"}]}
	return {"valid": true, "elevation": magnitude if prefix == "F" else -magnitude, "diagnostics": []}
