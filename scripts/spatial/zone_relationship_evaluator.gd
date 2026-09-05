class_name ZoneRelationshipEvaluator
extends RefCounted

## Pure relationship/competition projection. It never mutates ZoneManager state.


func evaluate(target_zone: Dictionary, other_zones: Array, policy: RentRecommendationPolicy, geometry_revision: int) -> ZoneRelationshipSnapshot:
	var snapshot := ZoneRelationshipSnapshot.new()
	if policy == null or not bool(policy.validate_content().get("valid", false)):
		return snapshot
	var target_id := String(target_zone.get("zone_id", target_zone.get("id", "")))
	var target_type := String(target_zone.get("zone_type", target_zone.get("type", "")))
	var target_tiles: Array = target_zone.get("tiles", [])
	var best_relation := "neutral"
	var best_zone_id := ""
	var best_distance := -1
	var nearest_same_distance := -1
	var nearest_same_id := ""
	for other_value: Variant in other_zones:
		if not other_value is Dictionary:
			continue
		var other: Dictionary = other_value
		var other_id := String(other.get("zone_id", other.get("id", "")))
		if other_id.is_empty() or other_id == target_id:
			continue
		var distance := _boundary_distance(target_tiles, other.get("tiles", []))
		if distance < 0:
			continue
		var other_type := String(other.get("zone_type", other.get("type", "")))
		if other_type == target_type:
			if nearest_same_distance < 0 or distance < nearest_same_distance or (distance == nearest_same_distance and other_id < nearest_same_id):
				nearest_same_distance = distance
				nearest_same_id = other_id
			continue
		if distance > policy.RELATIONSHIP_RANGE_TILES:
			continue
		var relation := policy.get_relationship(target_type, other_type)
		var impact := 0
		if relation == "positive":
			impact = 20
		elif relation == "negative":
			impact = -10
		var current_abs := absi(impact)
		var best_abs := absi(_impact_for_relation(best_relation))
		var should_select := current_abs > best_abs
		if current_abs == best_abs and current_abs > 0:
			should_select = impact < _impact_for_relation(best_relation) or (impact == _impact_for_relation(best_relation) and other_id < best_zone_id)
		if should_select or (best_zone_id.is_empty() and impact == 0):
			best_relation = relation
			best_zone_id = other_id
			best_distance = distance
	var competition := "none"
	if nearest_same_distance >= 0 and nearest_same_distance <= policy.COMPETITION_WITHIN_TEN:
		competition = "within_10"
	elif nearest_same_distance >= 0 and nearest_same_distance <= policy.COMPETITION_WITHIN_TWENTY:
		competition = "within_20"
	snapshot.configure({
		"schema_version": ZoneRelationshipSnapshot.SCHEMA_VERSION,
		"target_zone_id": target_id,
		"application_adjacency": best_relation,
		"selected_zone_id": best_zone_id,
		"selected_relation_distance": best_distance,
		"nearest_same_type_distance": nearest_same_distance,
		"competition_band": competition,
		"policy_revision": policy.POLICY_REVISION,
		"geometry_revision": geometry_revision,
		"provenance": "committed_zone_geometry",
	})
	return snapshot


func _impact_for_relation(relation: String) -> int:
	if relation == "positive":
		return 20
	if relation == "negative":
		return -10
	return 0


func _boundary_distance(first: Array, second: Array) -> int:
	var best := -1
	for first_cell: Variant in first:
		if not first_cell is Array or first_cell.size() < 2:
			continue
		for second_cell: Variant in second:
			if not second_cell is Array or second_cell.size() < 2:
				continue
			var distance := absi(int(first_cell[0]) - int(second_cell[0])) + absi(int(first_cell[1]) - int(second_cell[1]))
			if best < 0 or distance < best:
				best = distance
	return best
