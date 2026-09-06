## Tenant H1 authority and deterministic candidate tests.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_candidate_policy()
	_test_bind_and_release()
	_test_proxy_publication()
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
	tenant_manager.free()
	zone_manager.free()


func _test_proxy_publication() -> void:
	var zone_manager := ZoneManager.new()
	var zone := _make_zone()
	var edge: Dictionary = {
		"tile": Vector2i(0, 0),
		"direction": Vector2i.RIGHT,
		"access": Vector2i(1, 0),
		"access_kind": "internal_transit",
	}
	zone.parcels[0].selected_door_edges = [edge]
	zone_manager.zones[zone.id] = zone
	var tenant_manager := TenantManager.new()
	tenant_manager.initialize(zone_manager, 7)
	var bound: Dictionary = tenant_manager.register_candidate(_make_candidate(), 1)
	_assert(bool(bound.get("committed", false)), "operating tenant binds before proxy publication")
	if not bool(bound.get("committed", false)):
		tenant_manager.free()
		zone_manager.free()
		return
	tenant_manager.all_tenants[0]["lifecycle_state"] = "operating"
	var door_id: String = ZoneManager.service_proxy_door_id("parcel_a", edge)
	var published: Dictionary = tenant_manager.publish_service_proxy_snapshot([{
		"door_id": door_id,
		"corridor_anchor_id": "proxy_anchor/%s" % door_id,
		"public_corridor_reachable": true,
		"proxy_enabled": true,
		"topology_revision": 11,
	}])
	var snapshots: Array = published.get("snapshots", [])
	_assert(bool(published.get("valid", false)) and snapshots.size() == 1, "TenantManager publishes one eligible internal Transit proxy")
	if snapshots.size() == 1:
		var proxy: Dictionary = snapshots[0]
		_assert(bool(proxy.get("queue_accepting", false)), "operating tenant proxy publishes the approved accepting fact")
		_assert(String(proxy.get("corridor_anchor_id", "")).begins_with("proxy_anchor/"), "proxy carries a dedicated stable corridor anchor ID")
		_assert(String(proxy.get("parcel_door_proxy_id", "")).begins_with("proxy/parcel_a/"), "proxy identity is derived from parcel and door identity")
		var detached: Array[Dictionary] = tenant_manager.last_service_proxy_snapshot()
		proxy["tenant_id"] = "mutated"
		_assert(String(detached[0]["tenant_id"]) != "mutated", "published proxy snapshots are detached from caller mutation")
	var unreachable: Dictionary = tenant_manager.publish_service_proxy_snapshot([{
		"door_id": door_id,
		"corridor_anchor_id": "proxy_anchor/unreachable",
		"public_corridor_reachable": false,
		"proxy_enabled": true,
		"topology_revision": 12,
	}])
	_assert(unreachable.get("snapshots", []).is_empty(), "unreachable proxy attachments are not published as candidates")
	tenant_manager.free()
	zone_manager.free()


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
	tenant_manager.free()
	zone_manager.free()
