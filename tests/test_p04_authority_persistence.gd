## P04 authority-local persistence tests for Synergy and Staff.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_synergy_reserved_payload()
	_test_staff_detached_validation_and_import()
	_test_staff_due_payroll_round_trip()
	print("P04 authority persistence tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_synergy_reserved_payload() -> void:
	var manager := SynergyManager.new()
	_assert(manager.serialize() == {"schema_version": 1, "mode": "derived_only"}, "Synergy exports exactly the reserved derived-only payload")
	manager.zone_scores = {"zone_a": 9}
	var invalid_result: Dictionary = manager.deserialize({"zone_scores": {"zone_a": 4}})
	_assert(not bool(invalid_result.get("valid", false)) and manager.zone_scores == {"zone_a": 9}, "Synergy rejects legacy cache payload without mutating derived state")
	_assert(not bool(manager.validate_serialized({"schema_version": 1, "mode": "derived_only", "cache": {}}).get("valid", false)), "Synergy rejects unknown persisted fields")
	var detached: Variant = JSON.parse_string(JSON.stringify(manager.serialize()))
	var valid_result: Dictionary = manager.deserialize(detached)
	_assert(bool(valid_result.get("valid", false)) and manager.zone_scores.is_empty(), "Synergy valid JSON import clears rather than imports cache")
	_assert(not bool(manager.rebuild_derived_state().get("valid", false)), "Synergy rebuild reports unavailable source instead of fabricating state")
	var zones := ZoneManager.new()
	manager.initialize(zones)
	_assert(bool(manager.rebuild_derived_state().get("valid", false)) and manager.zone_scores.is_empty(), "Synergy rebuild derives from the bound authority")
	zones.free()
	manager.free()


func _test_staff_detached_validation_and_import() -> void:
	var source := _staff_fixture()
	var valid: Dictionary = source.serialize()
	_assert(valid.keys().size() == 7 and valid.has_all(["schema_version", "staff_revision", "staff_counter", "rooms", "staff", "pending_payroll", "cleaning_tasks"]), "Staff exports the exact local schema")
	_assert(bool(source.validate_serialized(valid).get("valid", false)), "Staff detached validator accepts its canonical export")
	var target := _staff_fixture()
	var before: Dictionary = target.serialize()
	var cases: Array[Dictionary] = []
	var unknown := valid.duplicate(true)
	unknown["unknown"] = true
	cases.append(unknown)
	var old_schema := valid.duplicate(true)
	old_schema["schema_version"] = 1
	cases.append(old_schema)
	var bad_id := valid.duplicate(true)
	bad_id["staff"][0]["staff_id"] = "staff_01"
	cases.append(bad_id)
	var bad_reference := valid.duplicate(true)
	bad_reference["staff"][0]["operations_room_id"] = "missing"
	cases.append(bad_reference)
	var bad_counter := valid.duplicate(true)
	bad_counter["staff_counter"] = 0
	cases.append(bad_counter)
	var bad_revision := valid.duplicate(true)
	bad_revision["staff"][0]["hired_revision"] = 99
	cases.append(bad_revision)
	var bad_tasks := valid.duplicate(true)
	bad_tasks["cleaning_tasks"] = [{"task_id": "not_durable"}]
	cases.append(bad_tasks)
	for candidate: Dictionary in cases:
		var result: Dictionary = target.deserialize(candidate)
		_assert(not bool(result.get("valid", false)) and target.serialize() == before, "Staff fallible import rejects invalid detached data without clearing live state")
	var json_round_trip: Variant = JSON.parse_string(JSON.stringify(valid))
	var import_result: Dictionary = target.deserialize(json_round_trip)
	var imported: Dictionary = target.serialize()
	_assert(bool(import_result.get("valid", false)), "Staff accepts a valid JSON-detached import")
	_assert(bool(target.validate_serialized(imported).get("valid", false)), "Staff imported state remains locally valid")
	_assert(imported["staff"].size() == 1 and imported["staff"][0]["staff_id"] == "staff_1" and imported["staff_counter"] == 1, "Staff JSON import restores stable records and counters")
	target.free()
	source.free()


func _test_staff_due_payroll_round_trip() -> void:
	var manager := _staff_fixture()
	var captured: Dictionary = manager.capture_due_payroll(8)
	_assert(bool(captured.get("valid", false)) and captured["snapshot"]["entries"].size() == 1, "Staff captures one immutable boundary-employed due roster")
	manager.fire("staff_1")
	var retry: Dictionary = manager.capture_due_payroll(8)
	_assert(retry.get("snapshot", {}) == captured.get("snapshot", {}), "later firing does not rewrite a retained due roster")
	_assert(not bool(manager.capture_due_payroll(9).get("valid", false)), "an unsettled due week blocks later payroll capture")
	var persisted: Dictionary = manager.serialize()
	var restored := StaffManager.new()
	var restored_result: Dictionary = restored.deserialize(persisted)
	_assert(bool(restored_result.get("valid", false)) and restored.pending_payroll == manager.pending_payroll, "Staff round-trips historical due payroll independently of current employment")
	var bad_policy := persisted.duplicate(true)
	bad_policy["pending_payroll"][0]["wage_policy_revision"] = 2
	_assert(not bool(restored.validate_serialized(bad_policy).get("valid", false)), "Staff rejects unknown due-payroll policy revisions")
	var bad_due_reference := persisted.duplicate(true)
	bad_due_reference["pending_payroll"][0]["entries"][0]["operations_room_id"] = "missing"
	_assert(not bool(restored.validate_serialized(bad_due_reference).get("valid", false)), "Staff rejects invalid historical due-payroll room references")
	_assert(bool(restored.acknowledge_payroll_settled(8).get("valid", false)) and restored.pending_payroll.is_empty(), "Staff clears a due roster only after settlement acknowledgement")
	restored.free()
	manager.free()


func _staff_fixture() -> StaffManager:
	var manager := StaffManager.new()
	manager.register_operations_room({"operations_room_id": "ops_a", "building_id": "building_a", "floor_id": "G", "elevation": 0, "building_floor_ids": {0: "G", 1: "F1"}, "source_revision": 3, "committed_valid_for_staffing": true})
	manager.hire({"operations_room_id": "ops_a", "staff_type": "Cleaner", "expected_room_revision": 3})
	return manager


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)
