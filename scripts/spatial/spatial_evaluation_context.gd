class_name SpatialEvaluationContext
extends RefCounted

## Detached, revisioned Tenant H2 input bundle. It contains no Node references.
const FIELDS: Array[String] = ["schema_version", "policy_revision", "prestige_authority_revision", "prestige_policy_revision", "topology_revision", "geometry_revision", "prestige", "circulation", "relationship", "policy"]
const SCHEMA_VERSION: int = 1
var _data: Dictionary = {}


static func capture(prestige: OfficialPrestigeSnapshot, circulation: CirculationEvaluationSnapshot, relationship: ZoneRelationshipSnapshot, policy: RentRecommendationPolicy) -> Dictionary:
	if prestige == null:
		return _failure("PRESTIGE_CONTEXT_UNAVAILABLE")
	if circulation == null or relationship == null:
		return _failure("SPATIAL_CONTEXT_UNAVAILABLE")
	if policy == null:
		return _failure("SPATIAL_POLICY_UNAVAILABLE")
	var prestige_data := prestige.to_dictionary()
	var prestige_diagnostics: Array[Dictionary] = []
	for field: String in ["schema_version", "authority_revision", "official_tier_id", "supported_tenant_tier", "rent_ceiling_centi_kreds", "policy_revision", "calendar_identity"]:
		if not prestige_data.has(field):
			prestige_diagnostics.append({"code": "PRESTIGE_CONTEXT_UNAVAILABLE", "path": "$.%s" % field})
	if not prestige_diagnostics.is_empty():
		return {"valid": false, "diagnostics": prestige_diagnostics}
	var circulation_validation := circulation.validate()
	var relationship_validation := relationship.validate()
	var policy_validation := policy.validate_content()
	for validation: Dictionary in [circulation_validation, relationship_validation, policy_validation]:
		if not bool(validation.get("valid", false)):
			return {"valid": false, "diagnostics": validation.get("diagnostics", [{"code": "SPATIAL_CONTEXT_UNAVAILABLE"}])}
	var circulation_data := circulation.to_dictionary()
	var relationship_data := relationship.to_dictionary()
	var policy_data := {
		"policy_revision": policy.POLICY_REVISION,
		"relationship_range_tiles": policy.RELATIONSHIP_RANGE_TILES,
		"competition_within_ten": policy.COMPETITION_WITHIN_TEN,
		"competition_within_twenty": policy.COMPETITION_WITHIN_TWENTY,
		"floor_factor_g": policy.FLOOR_FACTOR_G_BPS,
		"upper_floor_increment": policy.UPPER_FLOOR_INCREMENT_BPS,
		"floor_factor_max": policy.FLOOR_FACTOR_MAX_BPS,
		"underground_floor_decrement": policy.UNDERGROUND_FLOOR_DECREMENT_BPS,
		"floor_factor_min": policy.FLOOR_FACTOR_MIN_BPS,
		"accessibility_factors_bps": policy.ACCESSIBILITY_FACTORS_BPS.duplicate(true),
		"adjacency_factors_bps": policy.ADJACENCY_FACTORS_BPS.duplicate(true),
		"relationship_matrix": policy.RELATIONSHIP_MATRIX.duplicate(true),
	}
	var context := SpatialEvaluationContext.new()
	context._data = {
		"schema_version": SCHEMA_VERSION,
		"policy_revision": int(policy_data.get("policy_revision", policy.POLICY_REVISION)),
		"prestige_authority_revision": prestige.get_authority_revision(),
		"prestige_policy_revision": prestige.get_policy_revision(),
		"topology_revision": int(circulation_data["topology_revision"]),
		"geometry_revision": int(relationship_data["geometry_revision"]),
		"prestige": prestige_data.duplicate(true),
		"circulation": circulation_data.duplicate(true),
		"relationship": relationship_data.duplicate(true),
		"policy": policy_data.duplicate(true),
	}
	return {"valid": true, "context": context, "diagnostics": []}


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


func is_current(prestige_authority_revision: int, topology_revision: int, geometry_revision: int, policy_revision: int) -> bool:
	return int(_data.get("prestige_authority_revision", -1)) == prestige_authority_revision and int(_data.get("topology_revision", -1)) == topology_revision and int(_data.get("geometry_revision", -1)) == geometry_revision and int(_data.get("policy_revision", -1)) == policy_revision


func calculate_recommendation(elevation: int) -> Dictionary:
	if _data.is_empty():
		return _failure("SPATIAL_CONTEXT_UNAVAILABLE")
	var policy := RentRecommendationPolicy.new()
	var prestige := OfficialPrestigeSnapshot.new()
	prestige.configure(_data["prestige"])
	var circulation := CirculationEvaluationSnapshot.new()
	circulation.configure(_data["circulation"])
	var relationship := ZoneRelationshipSnapshot.new()
	relationship.configure(_data["relationship"])
	return RentRecommendationCalculator.new().calculate(policy, prestige, circulation, relationship, elevation)


static func _failure(code: String) -> Dictionary:
	return {"valid": false, "diagnostics": [{"code": code}]}
