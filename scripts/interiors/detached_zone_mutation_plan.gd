## Closed detached H2 mutation-plan value; never authorizes a live owner swap.
class_name DetachedZoneMutationPlan
extends RefCounted

const SCHEMA_ID: String = "detached_tenant_zone_mutation_plan"
const SCHEMA_VERSION: int = 1
const STATUSES: Array[String] = ["VALID", "INVALID_ZONE_GEOMETRY", "NO_VALID_FRONTAGE", "NO_CONCLUSIVE_FEASIBLE_PARCEL", "SEARCH_INDETERMINATE", "CONTENT_INVALID", "BOUND_INTERIOR_INVALIDATED", "DISTRICT_ZONE_SPATIAL_UNAVAILABLE", "DISTRICT_ZONE_SPATIAL_STALE", "DISTRICT_ZONE_SPATIAL_SCOPE_MISMATCH", "INVALID_DISTRICT_ZONE_SPATIAL_SNAPSHOT", "PUBLIC_BAND_ACCESS_UNAVAILABLE", "PUBLIC_BAND_ACCESS_STALE", "EXISTING_DOOR_INVALIDATED"]
const ACTIVATIONS: Array[String] = ["DETACHED_COMMIT_ELIGIBLE", "REQUIRES_H3_PHASE_B", "REQUIRES_H4_H5_INTEGRATION", "REJECTED"]
const KEYS: Array[String] = ["schema_id", "schema_version", "status", "activation", "intent_fingerprint", "base", "requested_district_effects", "parcels", "retired_parcel_ids", "residual_decoration_cells", "graph_fingerprint", "queue_input_fingerprint", "queue_envelopes", "phase_a_parity", "suitability_records", "replacement_requirements", "invalidation_parcel_ids", "diagnostics", "plan_fingerprint"]


static func validate_value(value: Dictionary) -> Array[Dictionary]:
	if not _exact_keys(value, KEYS) or value.get("schema_id") != SCHEMA_ID or value.get("schema_version") != SCHEMA_VERSION:
		return [_d("ZONE_PLAN_SCHEMA_INVALID", "$", {})]
	if not STATUSES.has(String(value.get("status", ""))) or not ACTIVATIONS.has(String(value.get("activation", ""))): return [_d("ZONE_PLAN_STATUS_INVALID", "$", {})]
	if value["status"] != "VALID" and value["activation"] != "REJECTED": return [_d("ZONE_PLAN_ACTIVATION_INVALID", "$.activation", {})]
	for record_value: Variant in value.get("suitability_records", []):
		if not record_value is Dictionary: return [_d("SUITABILITY_RECORD_INVALID", "$.suitability_records", {})]
		var freshness := String(record_value.get("freshness", "")); var suitability := String(record_value.get("suitability", ""))
		if not ["AVAILABLE", "STALE", "UNAVAILABLE"].has(freshness) or not ["SUITABLE", "UNSUITABLE", "INDETERMINATE"].has(suitability) or (freshness != "AVAILABLE" and suitability != "INDETERMINATE") or (suitability == "UNSUITABLE" and int(record_value.get("feasible_profile_count", -1)) != 0): return [_d("SUITABILITY_RECORD_INVALID", "$.suitability_records", {})]
	return []


static func seal(value_without_fingerprint: Dictionary) -> Dictionary:
	var value := value_without_fingerprint.duplicate(true)
	value["schema_id"] = SCHEMA_ID; value["schema_version"] = SCHEMA_VERSION; value["plan_fingerprint"] = null
	var hash := CanonicalJsonFingerprint.new().fingerprint(value, "JANUS_DETACHED_TENANT_ZONE_MUTATION_PLAN", 1)
	if not bool(hash.get("valid", false)): return {"valid":false,"diagnostics":hash.get("diagnostics", [])}
	value["plan_fingerprint"] = hash["fingerprint"]
	var diagnostics := validate_value(value)
	return {"valid":diagnostics.is_empty(),"value":value,"diagnostics":diagnostics}


static func _exact_keys(value: Dictionary, expected: Array[String]) -> bool:
	var actual: Array[String] = []; for key: Variant in value.keys(): actual.append(String(key))
	actual.sort(); var wanted := expected.duplicate(); wanted.sort(); return actual == wanted


static func _d(code: String, path: String, values: Dictionary) -> Dictionary:
	return {"code":code,"path":path,"values":values.duplicate(true)}
