## Tenant H1 authority and deterministic candidate tests.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_candidate_policy()
	_test_bind_and_release()
	_test_rent_snapshot()
	print("Tenant H1 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _test_candidate_policy() -> void:
	var policy := TenantCandidatePolicy.new()
	_assert(bool(policy.validate_content().get("valid", false)), "Tier-1 candidate policy has 25 valid profiles")
	var first: Dictionary = policy.select("Retail", 1, [], [], 6, 1234, "parcel_1", 0)
	var second: Dictionary = policy.select("Retail", 1, [], [], 6, 1234, "parcel_1", 0)
	_assert(bool(first.get("valid", false)), "legal Retail candidate is generated")
	_assert(first == second, "candidate selection is deterministic for identical inputs")
	_assert(int(first.get("selectivity", 999)) >= TenantCandidatePolicy.SELECTIVITY_MIN and int(first.get("selectivity", -999)) <= TenantCandidatePolicy.SELECTIVITY_MAX, "selectivity stays in the documented range")
	var blocked: Dictionary = policy.select("Retail", 1, ["retail.fashion"], ["retail.fashion"], 6, 1234, "parcel_1", 0)
	_assert(not bool(blocked.get("valid", false)), "neighbor subtype exclusion leaves no candidate")


func _make_zone() -> ZoneData:
	var zone := ZoneData.new()
	zone.id = "zone_retail_1"
	zone.type = "Retail"
	zone.plot_id = "plot_a"
	var parcel := Parcel.new()
	parcel.id = "parcel_a"
	var tiles: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 0), Vector2i(2, 1)]
	parcel.set_geometry(tiles, [])
	zone.parcels.append(parcel)
	return zone


func _make_candidate() -> Dictionary:
	return {
		"candidate_id": "candidate_a",
		"parcel_id": "parcel_a",
		"zone_id": "zone_retail_1",
		"subtype_id": "retail.fashion",
		"candidate_profile_id": "tier1.retail.fashion",
	}


func _test_bind_and_release() -> void:
	var zone_manager := ZoneManager.new()
	zone_manager.zones["zone_retail_1"] = _make_zone()
	var tenant_manager := TenantManager.new()
	tenant_manager.initialize(zone_manager, 99)
	var bound: Dictionary = tenant_manager.register_candidate(_make_candidate(), 10)
	_assert(bool(bound.get("committed", false)), "candidate binds through ZoneManager")
	_assert(zone_manager.parcel_snapshot("zone_retail_1", "parcel_a").get("tenant_id", "") == bound.get("tenant_id", ""), "parcel ownership stores committed tenant ID")
	var occupied: Dictionary = zone_manager.bind_tenant_to_parcel("zone_retail_1", "parcel_a", "tenant_other")
	_assert(not bool(occupied.get("committed", false)), "occupied parcel rejects a second tenant")
	var released: Dictionary = tenant_manager.release_tenant(String(bound["tenant_id"]), "test", 12)
	_assert(bool(released.get("committed", false)), "release clears ownership through ZoneManager")
	_assert(not bool(zone_manager.parcel_snapshot("zone_retail_1", "parcel_a").get("has_tenant", true)), "released parcel is vacant")


func _test_rent_snapshot() -> void:
	var zone_manager := ZoneManager.new()
	zone_manager.zones["zone_retail_1"] = _make_zone()
	var tenant_manager := TenantManager.new()
	tenant_manager.initialize(zone_manager, 1)
	zone_manager.initialize_zone_rate("zone_retail_1", {"valid": true, "recommended_rent_centi_kreds": 25})
	var bound: Dictionary = tenant_manager.register_candidate(_make_candidate(), 1)
	var tenant_id := String(bound["tenant_id"])
	for day: int in range(1, 24):
		tenant_manager.advance_lifecycle(day, 1)
	var snapshot_result: Dictionary = tenant_manager.build_rent_snapshot(24, 4)
	_assert(bool(snapshot_result.get("committed", false)), "rent snapshot commits from authoritative tenant state")
	var entries: Array = snapshot_result["snapshot"]["entries"]
	_assert(entries.size() == 1 and entries[0]["tenant_id"] == tenant_id, "operating tenant appears exactly once in rent snapshot")
	_assert(int(entries[0]["rent_amount_kreds"]) == 1, "rent uses exact tile count and centi-kred rate")
