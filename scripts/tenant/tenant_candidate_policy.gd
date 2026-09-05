class_name TenantCandidatePolicy
extends Resource

## Immutable Tier-1 candidate content. Runtime candidate state is never stored here.
const POLICY_REVISION: int = 1
const SELECTIVITY_MIN: int = -10
const SELECTIVITY_MAX: int = 20
const PROFILES: Array[Dictionary] = [
	{"profile_id": "tier1.anchor.department_store", "subtype_id": "anchor.department_store", "zone_type": "Anchor", "tier": 1},
	{"profile_id": "tier1.anchor.supermarket", "subtype_id": "anchor.supermarket", "zone_type": "Anchor", "tier": 1},
	{"profile_id": "tier1.anchor.gym", "subtype_id": "anchor.gym", "zone_type": "Anchor", "tier": 1},
	{"profile_id": "tier1.anchor.food_court", "subtype_id": "anchor.food_court", "zone_type": "Anchor", "tier": 1},
	{"profile_id": "tier1.anchor.exhibition_hall", "subtype_id": "anchor.exhibition_hall", "zone_type": "Anchor", "tier": 1},
	{"profile_id": "tier1.entertainment.arcade", "subtype_id": "entertainment.arcade", "zone_type": "Entertainment", "tier": 1},
	{"profile_id": "tier1.entertainment.bowling_alley", "subtype_id": "entertainment.bowling_alley", "zone_type": "Entertainment", "tier": 1},
	{"profile_id": "tier1.entertainment.cinema", "subtype_id": "entertainment.cinema", "zone_type": "Entertainment", "tier": 1},
	{"profile_id": "tier1.entertainment.escape_room", "subtype_id": "entertainment.escape_room", "zone_type": "Entertainment", "tier": 1},
	{"profile_id": "tier1.entertainment.vr_experience", "subtype_id": "entertainment.vr_experience", "zone_type": "Entertainment", "tier": 1},
	{"profile_id": "tier1.food.cafe", "subtype_id": "food.cafe", "zone_type": "Food & Beverage", "tier": 1},
	{"profile_id": "tier1.food.italian_restaurant", "subtype_id": "food.italian_restaurant", "zone_type": "Food & Beverage", "tier": 1},
	{"profile_id": "tier1.food.local_food", "subtype_id": "food.local_food", "zone_type": "Food & Beverage", "tier": 1},
	{"profile_id": "tier1.food.mexican_restaurant", "subtype_id": "food.mexican_restaurant", "zone_type": "Food & Beverage", "tier": 1},
	{"profile_id": "tier1.food.sushi_restaurant", "subtype_id": "food.sushi_restaurant", "zone_type": "Food & Beverage", "tier": 1},
	{"profile_id": "tier1.retail.bookstore", "subtype_id": "retail.bookstore", "zone_type": "Retail", "tier": 1},
	{"profile_id": "tier1.retail.electronics", "subtype_id": "retail.electronics", "zone_type": "Retail", "tier": 1},
	{"profile_id": "tier1.retail.fashion", "subtype_id": "retail.fashion", "zone_type": "Retail", "tier": 1},
	{"profile_id": "tier1.retail.home_goods", "subtype_id": "retail.home_goods", "zone_type": "Retail", "tier": 1},
	{"profile_id": "tier1.retail.jewelry", "subtype_id": "retail.jewelry", "zone_type": "Retail", "tier": 1},
	{"profile_id": "tier1.services.bank", "subtype_id": "services.bank", "zone_type": "Services", "tier": 1},
	{"profile_id": "tier1.services.clinic", "subtype_id": "services.clinic", "zone_type": "Services", "tier": 1},
	{"profile_id": "tier1.services.hair_salon", "subtype_id": "services.hair_salon", "zone_type": "Services", "tier": 1},
	{"profile_id": "tier1.services.repair_shop", "subtype_id": "services.repair_shop", "zone_type": "Services", "tier": 1},
	{"profile_id": "tier1.services.travel_agency", "subtype_id": "services.travel_agency", "zone_type": "Services", "tier": 1},
]


func validate_content() -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if PROFILES.size() != 25:
		diagnostics.append({"code": "CANDIDATE_POLICY_INVALID", "message": "Tier-1 catalog must contain 25 profiles"})
	var seen: Dictionary = {}
	for profile: Dictionary in PROFILES:
		var profile_id := String(profile.get("profile_id", ""))
		if profile_id.is_empty() or seen.has(profile_id) or int(profile.get("tier", 0)) < 1:
			diagnostics.append({"code": "CANDIDATE_POLICY_INVALID", "message": "profile identity/content is invalid"})
		seen[profile_id] = true
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}


func legal_profiles(zone_type: String, supported_tier: int, legal_subtype_ids: Array, neighbor_subtype_ids: Array, minimum_tiles: int) -> Array[Dictionary]:
	var legal: Array[Dictionary] = []
	for profile: Dictionary in PROFILES:
		if String(profile["zone_type"]) != zone_type or int(profile["tier"]) > supported_tier:
			continue
		if not legal_subtype_ids.is_empty() and not legal_subtype_ids.has(String(profile["subtype_id"])):
			continue
		if neighbor_subtype_ids.has(String(profile["subtype_id"])):
			continue
		var catalog_entries: Array[Dictionary] = DebugBusinessSubtypeCatalog.snapshot_for_zone_type(zone_type)
		var meets_minimum: bool = false
		for entry: Dictionary in catalog_entries:
			if String(entry["id"]) == String(profile["subtype_id"]):
				meets_minimum = minimum_tiles >= int(entry["min_tiles"])
				break
		if meets_minimum:
			legal.append(profile.duplicate(true))
	legal.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return String(first["profile_id"]) < String(second["profile_id"]))
	return legal


func select(zone_type: String, supported_tier: int, legal_subtype_ids: Array, neighbor_subtype_ids: Array, minimum_tiles: int, session_seed: int, parcel_id: String, evaluation_ordinal: int) -> Dictionary:
	var profiles: Array[Dictionary] = legal_profiles(zone_type, supported_tier, legal_subtype_ids, neighbor_subtype_ids, minimum_tiles)
	if profiles.is_empty():
		return {"valid": false, "diagnostics": [{"code": "CANDIDATE_POLICY_NO_LEGAL_PROFILE"}]}
	var selector := _stable_hash("%d|%s|%d|%d" % [session_seed, parcel_id, evaluation_ordinal, POLICY_REVISION])
	var profile: Dictionary = profiles[selector % profiles.size()].duplicate(true)
	var selectivity := SELECTIVITY_MIN + ((_stable_hash("selectivity|%d|%s|%d" % [session_seed, parcel_id, evaluation_ordinal]) % (SELECTIVITY_MAX - SELECTIVITY_MIN + 1)))
	return {"valid": true, "profile": profile, "selectivity": selectivity, "policy_revision": POLICY_REVISION, "provenance": "tenant_candidate_policy_v1", "diagnostics": []}


func _stable_hash(value: String) -> int:
	var hash_value: int = 2166136261
	for byte_value: int in value.to_utf8_buffer():
		hash_value = int((hash_value ^ byte_value) * 16777619) & 0x7fffffff
	return hash_value
