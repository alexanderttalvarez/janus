class_name TenantAuthoritySnapshot
extends RefCounted

const SCHEMA_VERSION: int = 1
const FIELDS: Array[String] = ["schema_version", "authority_revision", "session_seed", "tenant_counter", "evaluation_ordinals", "next_evaluations", "tenants", "diagnostics", "evaluation_results"]
var _data: Dictionary = {}


func configure(values: Dictionary) -> void:
	_data = values.duplicate(true)


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


func validate() -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	for field: String in FIELDS:
		if not _data.has(field):
			diagnostics.append({"code": "TENANT_SNAPSHOT_INVALID", "path": "$.%s" % field})
	for key: Variant in _data.keys():
		if not FIELDS.has(String(key)):
			diagnostics.append({"code": "TENANT_SNAPSHOT_INVALID", "path": "$.%s" % String(key)})
	if int(_data.get("schema_version", -1)) != SCHEMA_VERSION or int(_data.get("authority_revision", -1)) < 0:
		diagnostics.append({"code": "TENANT_SNAPSHOT_INVALID", "path": "$.revision"})
	if int(_data.get("session_seed", -1)) < 0 or int(_data.get("tenant_counter", -1)) < 0:
		diagnostics.append({"code": "TENANT_SNAPSHOT_INVALID", "path": "$.identity"})
	if not _data.get("evaluation_ordinals", {}) is Dictionary or not _data.get("next_evaluations", {}) is Dictionary or not _data.get("tenants", []) is Array or not _data.get("diagnostics", []) is Array or not _data.get("evaluation_results", {}) is Dictionary:
		diagnostics.append({"code": "TENANT_SNAPSHOT_INVALID", "path": "$.records"})
	for tenant: Variant in _data.get("tenants", []):
		if not tenant is Dictionary:
			diagnostics.append({"code": "TENANT_SNAPSHOT_INVALID", "path": "$.tenants"})
			continue
		for field: String in ["tenant_id", "parcel_id", "zone_id", "subtype_id", "candidate_profile_id", "lifecycle_state"]:
			if String(tenant.get(field, "")).is_empty():
				diagnostics.append({"code": "TENANT_SNAPSHOT_INVALID", "path": "$.tenants.%s" % field})
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}
