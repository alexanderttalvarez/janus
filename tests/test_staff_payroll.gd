## Economy exactly-once weekly payroll test.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	var staff := StaffManager.new()
	staff.register_operations_room({"operations_room_id": "ops_a", "building_id": "building_a", "floor_id": "G", "elevation": 0, "building_floor_ids": {0: "G", 1: "F1"}, "source_revision": 1, "committed_valid_for_staffing": true})
	staff.hire({"operations_room_id": "ops_a", "staff_type": "Cleaner", "expected_room_revision": 1})
	staff.hire({"operations_room_id": "ops_a", "staff_type": "Security", "expected_room_revision": 1})
	var economy := EconomyManager.new()
	economy.balance = 5000
	economy.initialize(null, null, staff)
	economy.on_sim_week_passed(1)
	_assert(economy.balance == 4000, "weekly payroll debits 500 Kreds per eligible employee")
	economy.on_sim_week_passed(1)
	_assert(economy.balance == 4000, "replayed week does not debit payroll twice")
	_assert(bool(staff.acknowledge_payroll_settled(1).get("valid", false)), "coordinated settlement acknowledgement clears the retained due week")
	staff.fire("staff_1")
	economy.on_sim_week_passed(2)
	_assert(economy.balance == 3500, "boundary payroll includes only currently employed staff")
	economy.free()
	staff.free()
	print("Staff payroll tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)
