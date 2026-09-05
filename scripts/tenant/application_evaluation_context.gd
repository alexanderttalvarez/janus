class_name ApplicationEvaluationContext
extends RefCounted

const SCHEMA_VERSION: int = 1
const FIELDS: Array[String] = [
	"schema_version", "candidate_id", "parcel_id", "zone_id", "subtype_id", "candidate_profile_id",
	"candidate_tier", "selectivity", "supported_prestige_tier", "rent_ceiling_centi_kreds",
	"recommended_rent_centi_kreds", "actual_rent_centi_kreds", "rate_revision", "elevation",
	"public_route_reaches_frontage", "valid_stair_count", "valid_elevator_count",
	"application_adjacency", "competition_band", "prestige_authority_revision",
	"topology_revision", "geometry_revision", "calendar_identity", "policy_revision", "provenance",
]
var _data: Dictionary = {}


func configure(values: Dictionary) -> void:
	_data = values.duplicate(true)


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


func validate() -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	for field: String in FIELDS:
		if not _data.has(field):
			diagnostics.append({"code": "EVALUATION_INPUT_UNAVAILABLE", "path": "$.%s" % field})
	for key: Variant in _data.keys():
		if not FIELDS.has(String(key)):
			diagnostics.append({"code": "EVALUATION_INPUT_UNAVAILABLE", "path": "$.%s" % String(key)})
	if int(_data.get("schema_version", -1)) != SCHEMA_VERSION:
		diagnostics.append({"code": "EVALUATION_INPUT_UNAVAILABLE", "path": "$.schema_version"})
	if int(_data.get("candidate_tier", 0)) < 1 or int(_data.get("supported_prestige_tier", 0)) < 1:
		diagnostics.append({"code": "PRESTIGE_TIER_UNAVAILABLE", "path": "$.tier"})
	if int(_data.get("selectivity", 999)) < -10 or int(_data.get("selectivity", -999)) > 20:
		diagnostics.append({"code": "EVALUATION_INPUT_UNAVAILABLE", "path": "$.selectivity"})
	if int(_data.get("rent_ceiling_centi_kreds", -1)) < 0 or int(_data.get("recommended_rent_centi_kreds", -1)) < 0 or int(_data.get("actual_rent_centi_kreds", -1)) < 0:
		diagnostics.append({"code": "EVALUATION_INPUT_UNAVAILABLE", "path": "$.rent"})
	if int(_data.get("rate_revision", -1)) < 0 or int(_data.get("prestige_authority_revision", -1)) < 0 or int(_data.get("topology_revision", -1)) < 0 or int(_data.get("geometry_revision", -1)) < 0 or int(_data.get("policy_revision", -1)) < 1:
		diagnostics.append({"code": "EVALUATION_INPUT_UNAVAILABLE", "path": "$.revisions"})
	if not ["negative", "neutral", "positive"].has(String(_data.get("application_adjacency", ""))) or not ["none", "within_10", "within_20"].has(String(_data.get("competition_band", ""))):
		diagnostics.append({"code": "EVALUATION_INPUT_UNAVAILABLE", "path": "$.spatial_classification"})
	if String(_data.get("calendar_identity", "")).is_empty() or String(_data.get("provenance", "")).is_empty():
		diagnostics.append({"code": "EVALUATION_INPUT_UNAVAILABLE", "path": "$.identity"})
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}
