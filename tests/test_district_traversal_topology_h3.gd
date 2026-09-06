## H3 traversal topology source tests for explicit parcel-door attachments.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_explicit_attachment_join()
	_test_missing_or_invalid_attachment_rejection()
	print("District traversal topology H3 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_explicit_attachment_join() -> void:
	var zone_manager := _make_zone_manager()
	var source := DistrictTraversalTopologySource.new()
	source.configure(zone_manager)
	var edge: Dictionary = zone_manager.zones["zone_test"].parcels[0].selected_door_edges[0]
	var door_id: String = ZoneManager.service_proxy_door_id("parcel_test", edge)
	var built: Dictionary = source.build_door_access_edges([_attachment(door_id)])
	_assert(bool(built.get("valid", false)), "explicit H3 attachment joins a committed parcel door")
	var records: Array = built.get("records", [])
	_assert(records.size() == 1 and records[0]["door_edge_id"] == door_id, "joined topology preserves the stable parcel-door identity")
	if records.size() == 1:
		var detached: Array = built["records"]
		detached[0]["external_ref"] = "mutated"
		var rebuilt: Dictionary = source.build_door_access_edges([_attachment(door_id)])
		_assert(String(rebuilt["records"][0]["external_ref"]) == "public_band/test", "topology source returns detached records")
	zone_manager.free()


func _test_missing_or_invalid_attachment_rejection() -> void:
	var zone_manager := _make_zone_manager()
	var source := DistrictTraversalTopologySource.new()
	source.configure(zone_manager)
	var edge: Dictionary = zone_manager.zones["zone_test"].parcels[0].selected_door_edges[0]
	var door_id: String = ZoneManager.service_proxy_door_id("parcel_test", edge)
	var unknown: Dictionary = source.build_door_access_edges([_attachment("unknown_door")])
	_assert(not bool(unknown.get("valid", false)) and unknown.get("records", []).is_empty(), "unknown door attachment is rejected without fabrication")
	var wrong_kind: Dictionary = _attachment(door_id)
	wrong_kind["access_kind"] = "internal_transit"
	var invalid_kind: Dictionary = source.build_door_access_edges([wrong_kind])
	_assert(not bool(invalid_kind.get("valid", false)) and invalid_kind.get("records", []).is_empty(), "non-public H3 attachment kind is rejected")
	var missing_band: Dictionary = _attachment(door_id)
	missing_band.erase("external_ref")
	var invalid_mapping: Dictionary = source.build_door_access_edges([missing_band])
	_assert(not bool(invalid_mapping.get("valid", false)) and invalid_mapping.get("records", []).is_empty(), "missing explicit public-band mapping is rejected")
	var duplicate: Dictionary = source.build_door_access_edges([_attachment(door_id), _attachment(door_id)])
	_assert(not bool(duplicate.get("valid", false)) and duplicate.get("records", []).is_empty(), "duplicate stable door attachments are rejected")
	zone_manager.free()


func _make_zone_manager() -> ZoneManager:
	var zone_manager := ZoneManager.new()
	var zone := ZoneData.new()
	zone.id = "zone_test"
	zone.type = "Retail"
	zone.plot_id = "plot_test"
	var parcel := Parcel.new()
	parcel.id = "parcel_test"
	parcel.set_geometry([Vector2i(1, 1)], [])
	parcel.selected_door_edges = [{
		"tile": Vector2i(1, 1),
		"direction": Vector2i.RIGHT,
		"access": Vector2i(2, 1),
		"access_kind": "internal_transit",
	}]
	zone.parcels.append(parcel)
	zone_manager.zones[zone.id] = zone
	return zone_manager


func _attachment(door_id: String) -> Dictionary:
	return {
		"door_edge_id": door_id,
		"floor_id": "floor/test/G",
		"interior_cell_id": "cell/test/1,1",
		"external_ref": "public_band/test",
		"access_kind": "public_band_physical",
		"source_kind": "H3",
	}


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)
