## Staff H1 records, coverage, task, and payroll snapshot tests.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	var manager := StaffManager.new()
	var missing := manager.hire({"operations_room_id": "missing", "staff_type": "Cleaner"})
	_assert(not bool(missing.get("committed", false)), "missing Operations Room rejects hire")
	var room_result := manager.register_operations_room({"operations_room_id": "ops_a", "building_id": "building_a", "floor_id": "F2", "elevation": 2, "building_floor_ids": {1: "F1", 2: "F2", 3: "F3"}, "source_revision": 5, "committed_valid_for_staffing": true})
	_assert(bool(room_result.get("committed", false)), "valid committed Operations Room registers")
	var cleaner_one := manager.hire({"operations_room_id": "ops_a", "staff_type": "Cleaner", "expected_room_revision": 5})
	var cleaner_two := manager.hire({"operations_room_id": "ops_a", "staff_type": "Cleaner", "expected_room_revision": 5})
	_assert(bool(cleaner_one.get("committed", false)) and bool(cleaner_two.get("committed", false)), "two Cleaners fit the per-type room capacity")
	_assert(not bool(manager.hire({"operations_room_id": "ops_a", "staff_type": "Cleaner", "expected_room_revision": 5}).get("committed", false)), "third Cleaner is rejected")
	var security_one := manager.hire({"operations_room_id": "ops_a", "staff_type": "Security", "expected_room_revision": 5})
	_assert(bool(security_one.get("committed", false)), "Security uses independent capacity from Cleaners")
	_assert(manager.staff_count("ops_a", "Cleaner") == 2 and manager.staff_count("ops_a", "Security") == 1, "room occupancy counts by type")
	var coverage := manager.coverage_for_staff(String(cleaner_one["staff_id"]))
	_assert(coverage.get("covered_floor_ids", []).has("F1") and coverage.get("covered_floor_ids", []).has("F2") and coverage.get("covered_floor_ids", []).has("F3"), "coverage includes room floor and adjacent floors")
	_assert(not coverage.get("covered_floor_ids", []).has("F4"), "coverage excludes floors beyond one level")
	var task := manager.commit_cleaning_task({"task_id": "task_1", "task_kind": "garbage_removal", "floor_id": "F3", "source_reference": "garbage_1", "staff_id": cleaner_one["staff_id"]})
	_assert(bool(task.get("committed", false)), "Cleaner accepts covered garbage task")
	_assert(not bool(manager.commit_cleaning_task({"task_id": "task_2", "task_kind": "bathroom_cleaning", "floor_id": "F1", "staff_id": security_one["staff_id"]}).get("committed", false)), "Security cannot receive cleaning tasks")
	_assert(not bool(manager.commit_cleaning_task({"task_id": "task_3", "task_kind": "bathroom_cleaning", "floor_id": "F5", "staff_id": cleaner_one["staff_id"]}).get("committed", false)), "Cleaner task outside coverage is rejected")
	var weekly := manager.paid_staff_weekly_snapshot(7)
	var weekly_validation := PaidStaffWeeklySnapshot.new()
	weekly_validation.configure(weekly)
	_assert(bool(weekly_validation.validate().get("valid", false)), "weekly paid-staff snapshot validates")
	_assert(weekly["entries"].size() == 3 and weekly["entries"][0]["staff_id"] == "staff_1", "weekly snapshot is canonical and contains each employee")
	_assert(weekly["entries"][0]["wage_kreds"] == 500, "weekly wage is exactly 500 Kreds per entry")
	var fired := manager.fire(String(cleaner_two["staff_id"]))
	_assert(bool(fired.get("committed", false)) and manager.staff_count("ops_a", "Cleaner") == 1, "firing removes one staff occupancy contribution")
	var restored := StaffManager.new()
	restored.deserialize(manager.serialize())
	_assert(restored.snapshot()["staff"].size() == 2, "staff authority round-trips detached state")
	restored.free()
	manager.free()
	print("Staff H1 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)
