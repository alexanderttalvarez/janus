## Spatial H1 detached capture and revision tests.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_capture_and_calculation()
	_test_missing_and_stale_sources()
	print("Spatial context H1 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _prestige() -> OfficialPrestigeSnapshot:
	var snapshot := OfficialPrestigeSnapshot.new()
	snapshot.configure({
		"schema_version": 1,
		"authority_revision": 4,
		"official_tier_id": "district",
		"supported_tenant_tier": 1,
		"exclusive_eligible": true,
		"rent_ceiling_centi_kreds": 1000,
		"policy_revision": 1,
		"calendar_identity": "day_30",
		"numeric_prestige_present": true,
		"numeric_prestige": 100,
		"numeric_prestige_provenance": "test",
	})
	return snapshot


func _test_capture_and_calculation() -> void:
	var circulation := CirculationEvaluationSnapshot.create("parcel_a", "zone_a", 1, true, 1, 1, 8, "topology_commit_8")
	var relationship := ZoneRelationshipSnapshot.new()
	relationship.configure({
		"schema_version": 1,
		"target_zone_id": "zone_a",
		"application_adjacency": "positive",
		"selected_zone_id": "zone_b",
		"selected_relation_distance": 3,
		"nearest_same_type_distance": -1,
		"competition_band": "none",
		"policy_revision": 1,
		"geometry_revision": 6,
		"provenance": "committed_zone_geometry",
	})
	var manager := TenantManager.new()
	var captured: Dictionary = manager.capture_spatial_context(_prestige(), circulation, relationship, RentRecommendationPolicy.new())
	_assert(bool(captured.get("valid", false)), "detached spatial context captures all required sources")
	var recommended: Dictionary = manager.evaluate_recommended_rent(1, 4, 8, 6, 1)
	_assert(bool(recommended.get("valid", false)), "recommendation evaluates from captured detached sources")
	_assert(int(recommended.get("recommended_rent_centi_kreds", -1)) == 1000, "recommendation is capped by Prestige ceiling")
	_assert(int(recommended.get("circulation_topology_revision", -1)) == 8 and int(recommended.get("zone_geometry_revision", -1)) == 6, "recommendation preserves source revisions")
	manager.free()


func _test_missing_and_stale_sources() -> void:
	var manager := TenantManager.new()
	var missing: Dictionary = manager.capture_spatial_context(_prestige(), null, null, RentRecommendationPolicy.new())
	_assert(not bool(missing.get("valid", false)), "missing spatial sources defer evaluation")
	var relationship := ZoneRelationshipSnapshot.new()
	relationship.configure({"schema_version": 1, "target_zone_id": "zone_a", "application_adjacency": "neutral", "selected_zone_id": "", "selected_relation_distance": -1, "nearest_same_type_distance": -1, "competition_band": "none", "policy_revision": 1, "geometry_revision": 6, "provenance": "committed_zone_geometry"})
	var circulation := CirculationEvaluationSnapshot.create("parcel_a", "zone_a", 0, true, 0, 0, 8, "topology_commit_8")
	manager.capture_spatial_context(_prestige(), circulation, relationship, RentRecommendationPolicy.new())
	var stale: Dictionary = manager.evaluate_recommended_rent(1, 5, 8, 6, 1)
	_assert(not bool(stale.get("valid", false)), "changed Prestige revision rejects stale context")
	var stale_topology: Dictionary = manager.evaluate_recommended_rent(1, 4, 9, 6, 1)
	_assert(not bool(stale_topology.get("valid", false)), "changed topology revision rejects stale context")
	manager.free()
