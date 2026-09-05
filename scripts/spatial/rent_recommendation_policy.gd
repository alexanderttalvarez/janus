class_name RentRecommendationPolicy
extends Resource

## Immutable fixed-point spatial/rent policy for Tenant H2.
const POLICY_REVISION: int = 1
const RELATIONSHIP_RANGE_TILES: int = 5
const COMPETITION_WITHIN_TEN: int = 10
const COMPETITION_WITHIN_TWENTY: int = 20
const FLOOR_FACTOR_G_BPS: int = 10000
const UPPER_FLOOR_INCREMENT_BPS: int = 500
const FLOOR_FACTOR_MAX_BPS: int = 12500
const UNDERGROUND_FLOOR_DECREMENT_BPS: int = 1000
const FLOOR_FACTOR_MIN_BPS: int = 5000
const ACCESSIBILITY_FACTORS_BPS: Dictionary = {
	"poor": 7000,
	"average": 8500,
	"good": 10000,
	"excellent": 11500,
}
const ADJACENCY_FACTORS_BPS: Dictionary = {
	"negative": 8000,
	"neutral": 10000,
	"positive": 11500,
}
const RELATIONSHIP_MATRIX: Dictionary = {
	"Retail": {"Retail": "negative", "Food & Beverage": "positive", "Entertainment": "positive", "Services": "neutral", "Anchor": "neutral"},
	"Food & Beverage": {"Retail": "positive", "Food & Beverage": "negative", "Entertainment": "positive", "Services": "neutral", "Anchor": "positive"},
	"Entertainment": {"Retail": "positive", "Food & Beverage": "positive", "Entertainment": "negative", "Services": "negative", "Anchor": "positive"},
	"Services": {"Retail": "neutral", "Food & Beverage": "neutral", "Entertainment": "negative", "Services": "negative", "Anchor": "neutral"},
	"Anchor": {"Retail": "neutral", "Food & Beverage": "positive", "Entertainment": "positive", "Services": "neutral", "Anchor": "negative"},
}


func validate_content() -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if POLICY_REVISION < 1 or RELATIONSHIP_RANGE_TILES != 5:
		diagnostics.append({"code": "SPATIAL_POLICY_UNAVAILABLE", "message": "spatial policy revision or range is invalid"})
	for band: String in ["poor", "average", "good", "excellent"]:
		if not ACCESSIBILITY_FACTORS_BPS.has(band) or int(ACCESSIBILITY_FACTORS_BPS[band]) <= 0:
			diagnostics.append({"code": "SPATIAL_POLICY_UNAVAILABLE", "message": "accessibility factor is missing"})
	for relation: String in ["negative", "neutral", "positive"]:
		if not ADJACENCY_FACTORS_BPS.has(relation):
			diagnostics.append({"code": "SPATIAL_POLICY_UNAVAILABLE", "message": "adjacency factor is missing"})
	for first: String in RELATIONSHIP_MATRIX.keys():
		for second: String in RELATIONSHIP_MATRIX[first].keys():
			if not ["negative", "neutral", "positive"].has(String(RELATIONSHIP_MATRIX[first][second])):
				diagnostics.append({"code": "SPATIAL_POLICY_UNAVAILABLE", "message": "relationship matrix contains an unknown classification"})
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}


func get_floor_factor_bps(elevation: int) -> int:
	if elevation >= 0:
		return mini(FLOOR_FACTOR_G_BPS + elevation * UPPER_FLOOR_INCREMENT_BPS, FLOOR_FACTOR_MAX_BPS)
	return maxi(FLOOR_FACTOR_G_BPS + elevation * UNDERGROUND_FLOOR_DECREMENT_BPS, FLOOR_FACTOR_MIN_BPS)


func get_accessibility_factor_bps(band: String) -> int:
	return int(ACCESSIBILITY_FACTORS_BPS.get(band.to_lower(), -1))


func get_adjacency_factor_bps(classification: String) -> int:
	return int(ADJACENCY_FACTORS_BPS.get(classification.to_lower(), -1))


func get_relationship(first_type: String, second_type: String) -> String:
	return String(RELATIONSHIP_MATRIX.get(first_type, {}).get(second_type, "neutral"))
