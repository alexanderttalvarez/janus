class_name RentRecommendationCalculator
extends RefCounted

## Pure fixed-point Tenant H2 rent recommendation calculation.


func calculate(policy: RentRecommendationPolicy, prestige: OfficialPrestigeSnapshot, circulation: CirculationEvaluationSnapshot, relationship: ZoneRelationshipSnapshot, elevation: int) -> Dictionary:
	if policy == null:
		return _failure("SPATIAL_POLICY_UNAVAILABLE", "rent recommendation policy is required")
	if prestige == null:
		return _failure("PRESTIGE_CONTEXT_UNAVAILABLE", "official Prestige rent ceiling is required")
	if circulation == null or relationship == null:
		return _failure("SPATIAL_POLICY_UNAVAILABLE", "circulation and relationship inputs are required")
	var policy_result: Dictionary = policy.validate_content()
	if not bool(policy_result.get("valid", false)):
		return _failure("SPATIAL_POLICY_UNAVAILABLE", "rent recommendation policy is invalid")
	var circulation_result: Dictionary = circulation.validate()
	if not bool(circulation_result.get("valid", false)):
		return _failure("CIRCULATION_CONTEXT_UNAVAILABLE", "circulation context is invalid")
	var relationship_result: Dictionary = relationship.validate()
	if not bool(relationship_result.get("valid", false)):
		return _failure("RELATIONSHIP_CONTEXT_UNAVAILABLE", "zone relationship context is invalid")
	var prestige_result: Dictionary = prestige.to_dictionary()
	if prestige_result.is_empty() or not prestige.has_numeric_prestige() and prestige.get_rent_ceiling_centi_kreds() <= 0:
		return _failure("PRESTIGE_CONTEXT_UNAVAILABLE", "official Prestige rent ceiling is unavailable")
	var ceiling := prestige.get_rent_ceiling_centi_kreds()
	var floor_factor := policy.get_floor_factor_bps(elevation)
	var accessibility_band := String(circulation.to_dictionary().get("accessibility_band", ""))
	var adjacency := String(relationship.to_dictionary().get("application_adjacency", ""))
	var accessibility_factor := policy.get_accessibility_factor_bps(accessibility_band)
	var adjacency_factor := policy.get_adjacency_factor_bps(adjacency)
	if ceiling <= 0 or floor_factor <= 0 or accessibility_factor <= 0 or adjacency_factor <= 0:
		return _failure("SPATIAL_POLICY_UNAVAILABLE", "rent recommendation factor is unavailable")
	var unclamped: int = floori(float(ceiling * floor_factor * accessibility_factor * adjacency_factor) / 1000000000000.0)
	var recommended := mini(ceiling, unclamped)
	return {
		"valid": true,
		"recommended_rent_centi_kreds": recommended,
		"unclamped_rent_centi_kreds": unclamped,
		"rent_ceiling_centi_kreds": ceiling,
		"floor_factor_bps": floor_factor,
		"accessibility_factor_bps": accessibility_factor,
		"adjacency_factor_bps": adjacency_factor,
		"accessibility_band": accessibility_band,
		"application_adjacency": adjacency,
		"prestige_authority_revision": prestige.get_authority_revision(),
		"prestige_policy_revision": prestige.get_policy_revision(),
		"circulation_topology_revision": int(circulation.to_dictionary().get("topology_revision", -1)),
		"zone_geometry_revision": int(relationship.to_dictionary().get("geometry_revision", -1)),
		"diagnostics": [],
	}


func _failure(code: String, message: String) -> Dictionary:
	return {"valid": false, "recommended_rent_centi_kreds": -1, "diagnostics": [{"code": code, "message": message}]}
