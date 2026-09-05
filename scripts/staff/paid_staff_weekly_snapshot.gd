class_name PaidStaffWeeklySnapshot
extends RefCounted

const SCHEMA_VERSION: int = 1
const WAGE_KREDS: int = 500
const FIELDS: Array[String] = ["schema_version", "simulation_week", "staff_revision", "entries", "provenance"]
var _data: Dictionary = {}


func configure(values: Dictionary) -> void:
	_data = values.duplicate(true)


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


func validate() -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	for field: String in FIELDS:
		if not _data.has(field):
			diagnostics.append({"code": "PAID_STAFF_SNAPSHOT_INVALID", "path": "$.%s" % field})
	if int(_data.get("schema_version", -1)) != SCHEMA_VERSION or int(_data.get("simulation_week", -1)) < 0 or int(_data.get("staff_revision", -1)) < 0:
		diagnostics.append({"code": "PAID_STAFF_SNAPSHOT_INVALID", "path": "$.identity"})
	if not _data.get("entries", []) is Array:
		diagnostics.append({"code": "PAID_STAFF_SNAPSHOT_INVALID", "path": "$.entries"})
	if String(_data.get("provenance", "")).is_empty():
		diagnostics.append({"code": "PAID_STAFF_SNAPSHOT_INVALID", "path": "$.provenance"})
	for entry: Variant in _data.get("entries", []):
		if not entry is Dictionary or String(entry.get("staff_id", "")).is_empty() or not ["Cleaner", "Security"].has(String(entry.get("staff_type", ""))) or String(entry.get("operations_room_id", "")).is_empty() or int(entry.get("wage_kreds", -1)) != WAGE_KREDS:
			diagnostics.append({"code": "PAID_STAFF_SNAPSHOT_INVALID", "path": "$.entries"})
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}
