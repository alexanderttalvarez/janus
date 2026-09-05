class_name ActiveTenantRentSnapshot
extends RefCounted

const SCHEMA_VERSION: int = 1
const FIELDS: Array[String] = ["schema_version", "simulation_day", "tenant_revision", "zone_revision", "entries"]
var _data: Dictionary = {}


func configure(values: Dictionary) -> void:
	_data = values.duplicate(true)


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


func validate() -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	for field: String in FIELDS:
		if not _data.has(field):
			diagnostics.append({"code": "TENANT_RENT_SNAPSHOT_INVALID", "path": "$.%s" % field})
	if int(_data.get("schema_version", -1)) != SCHEMA_VERSION or int(_data.get("simulation_day", -1)) < 0:
		diagnostics.append({"code": "TENANT_RENT_SNAPSHOT_INVALID", "path": "$.identity"})
	if not _data.get("entries", []) is Array:
		diagnostics.append({"code": "TENANT_RENT_SNAPSHOT_INVALID", "path": "$.entries"})
	for entry: Variant in _data.get("entries", []):
		if not entry is Dictionary:
			diagnostics.append({"code": "TENANT_RENT_SNAPSHOT_INVALID", "path": "$.entries"})
			continue
		for field: String in ["tenant_id", "parcel_id", "zone_id", "subtype_id", "parcel_tile_count", "daily_rate_centi_kreds", "rent_amount_kreds"]:
			if not entry.has(field):
				diagnostics.append({"code": "TENANT_RENT_SNAPSHOT_INVALID", "path": "$.entries.%s" % field})
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}
