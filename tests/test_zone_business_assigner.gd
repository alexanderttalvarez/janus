## ZoneBusinessAssignerTest — Deterministic pure debug subtype assignment checks.
## Run with: godot --headless --path . -s res://tests/test_zone_business_assigner.gd
extends SceneTree


var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_edge_conflicts_and_diagonal_contact()
	_test_eligibility_and_purity()
	_test_balanced_deterministic_ordering()
	_test_catalog_and_parcel_persistence()
	print("ZoneBusinessAssigner tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _make_parcel(id: String, origin: Vector2i, width: int = 1, height: int = 1) -> Parcel:
	var parcel := Parcel.new()
	parcel.id = id
	var tiles: Array[Vector2i] = []
	for y: int in range(height):
		for x: int in range(width):
			tiles.append(origin + Vector2i(x, y))
	parcel.set_geometry(tiles, [])
	return parcel


func _entry(id: String, priority: int, minimum_tiles: int = 1) -> Dictionary:
	return {
		"id": id,
		"display_name": id,
		"zone_type": "Retail",
		"min_tiles": minimum_tiles,
		"max_tiles": -1,
		"debug_priority": priority,
	}


func _test_edge_conflicts_and_diagonal_contact() -> void:
	var first := _make_parcel("parcel_a", Vector2i(0, 0))
	var edge_neighbor := _make_parcel("parcel_b", Vector2i(1, 0))
	var diagonal_only := _make_parcel("parcel_c", Vector2i(2, 1))
	var result := ZoneBusinessAssigner.assign(
		[first, edge_neighbor, diagonal_only],
		"Retail",
		[_entry("retail.only", 0)]
	)
	_assert(result.subtype_for("parcel_a") == "retail.only", "first parcel receives the only subtype")
	_assert(
		result.diagnostic_for("parcel_b") == BusinessAssignmentResult.NO_LEGAL_SUBTYPE,
		"edge-adjacent parcel is not assigned a duplicate subtype"
	)
	_assert(
		result.subtype_for("parcel_c") == "retail.only",
		"diagonal-only contact may share a subtype"
	)


func _test_eligibility_and_purity() -> void:
	var parcel := _make_parcel("parcel_small", Vector2i(0, 0), 2, 1)
	parcel.assigned_subtype_id = "unchanged"
	var result := ZoneBusinessAssigner.assign([parcel], "Retail", [_entry("retail.large", 0, 3)])
	_assert(
		result.diagnostic_for(parcel.id) == BusinessAssignmentResult.NO_ELIGIBLE_SUBTYPE,
		"undersized parcel receives NO_ELIGIBLE_SUBTYPE"
	)
	_assert(parcel.assigned_subtype_id == "unchanged", "pure assigner does not mutate parcel metadata")


func _test_balanced_deterministic_ordering() -> void:
	var catalog: Array[Dictionary] = [_entry("retail.c", 2), _entry("retail.a", 0), _entry("retail.b", 1)]
	var first := _make_parcel("parcel_1", Vector2i(0, 0))
	var second := _make_parcel("parcel_2", Vector2i(3, 0))
	var third := _make_parcel("parcel_3", Vector2i(6, 0))
	var fourth := _make_parcel("parcel_4", Vector2i(9, 0))
	var result := ZoneBusinessAssigner.assign([fourth, second, first, third], "Retail", catalog)
	_assert(result.subtype_for("parcel_1") == "retail.a", "priority selects the first equally used subtype")
	_assert(result.subtype_for("parcel_2") == "retail.b", "least-used rule balances the second subtype")
	_assert(result.subtype_for("parcel_3") == "retail.c", "least-used rule balances the third subtype")
	_assert(result.subtype_for("parcel_4") == "retail.a", "least-used tie returns to canonical priority")

	var reordered_catalog: Array[Dictionary] = [_entry("retail.b", 1), _entry("retail.c", 2), _entry("retail.a", 0)]
	var reordered := ZoneBusinessAssigner.assign([third, first, fourth, second], "Retail", reordered_catalog)
	_assert(reordered.assignments == result.assignments, "parcel and catalog insertion order do not affect assignments")


func _test_catalog_and_parcel_persistence() -> void:
	var retail_catalog := DebugBusinessSubtypeCatalog.snapshot_for_zone_type("Retail")
	var retail_parcel := _make_parcel("parcel_retail", Vector2i(0, 0), 3, 2)
	var result := ZoneBusinessAssigner.assign([retail_parcel], "Retail", retail_catalog)
	var subtype_id := result.subtype_for(retail_parcel.id)
	_assert(subtype_id.begins_with("retail."), "catalog subtype matches the parcel zone type")
	_assert(
		DebugBusinessSubtypeCatalog.display_name_for(subtype_id) != "",
		"catalog resolves the assigned subtype display name"
	)
	retail_parcel.assigned_subtype_id = subtype_id
	retail_parcel.display_number = 17
	var restored := Parcel.deserialize(retail_parcel.serialize())
	_assert(
		restored.assigned_subtype_id == subtype_id,
		"assigned subtype ID persists with parcel serialization"
	)
	_assert(restored.display_number == 17, "parcel display number persists with parcel serialization")
