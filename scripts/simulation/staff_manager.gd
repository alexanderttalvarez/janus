## StaffManager — record-based MVP staff authority.
class_name StaffManager
extends Node

signal staff_hired(staff_id: String, staff_type: String, operations_room_id: String)
signal staff_fired(staff_id: String, operations_room_id: String)
signal staff_cleaning_task_committed(task_id: String, staff_id: String, task_kind: String)
signal staff_snapshot_changed(snapshot: Dictionary)

const SCHEMA_VERSION: int = 1
const MAX_PER_TYPE_PER_ROOM: int = 2
const STAFF_TYPES: Array[String] = ["Cleaner", "Security"]
const CLEANING_TASK_KINDS: Array[String] = ["garbage_removal", "bathroom_cleaning"]

var operations_rooms: Dictionary = {}
var all_staff: Array[Dictionary] = []
var cleaning_tasks: Array[Dictionary] = []
var authority_revision: int = 0
var _staff_counter: int = 0
var _grid_manager: GridManager


func initialize(grid_manager: GridManager) -> void:
	_grid_manager = grid_manager


func on_visitor_tick(_tick: int) -> void:
	# Visitor integration is intentionally deferred; Staff H1 publishes records only.
	pass


func register_operations_room(room: Dictionary) -> Dictionary:
	var room_id := String(room.get("operations_room_id", ""))
	var building_id := String(room.get("building_id", ""))
	var floor_id := String(room.get("floor_id", ""))
	if room_id.is_empty() or building_id.is_empty() or floor_id.is_empty():
		return {"committed": false, "diagnostics": [{"code": "OPERATIONS_ROOM_INVALID"}]}
	if not bool(room.get("committed_valid_for_staffing", false)):
		return {"committed": false, "diagnostics": [{"code": "OPERATIONS_ROOM_INVALID"}]}
	operations_rooms[room_id] = {
		"operations_room_id": room_id,
		"building_id": building_id,
		"floor_id": floor_id,
		"elevation": int(room.get("elevation", 0)),
		"building_floor_ids": room.get("building_floor_ids", {}).duplicate(true),
		"committed_valid_for_staffing": true,
		"source_revision": int(room.get("source_revision", 0)),
	}
	return {"committed": true, "diagnostics": []}


func hire(intent: Dictionary) -> Dictionary:
	var staff_type := String(intent.get("staff_type", ""))
	var room_id := String(intent.get("operations_room_id", ""))
	if not STAFF_TYPES.has(staff_type):
		return {"committed": false, "diagnostics": [{"code": "STAFF_TYPE_INVALID"}]}
	var room: Dictionary = operations_rooms.get(room_id, {})
	if room.is_empty():
		return {"committed": false, "diagnostics": [{"code": "OPERATIONS_ROOM_MISSING"}]}
	if not bool(room.get("committed_valid_for_staffing", false)):
		return {"committed": false, "diagnostics": [{"code": "OPERATIONS_ROOM_INVALID"}]}
	var expected_revision := int(intent.get("expected_room_revision", room.get("source_revision", 0)))
	if expected_revision != int(room.get("source_revision", 0)):
		return {"committed": false, "diagnostics": [{"code": "OPERATIONS_ROOM_STALE"}]}
	if staff_count(room_id, staff_type) >= MAX_PER_TYPE_PER_ROOM:
		return {"committed": false, "diagnostics": [{"code": "ROOM_TYPE_CAPACITY_REACHED"}]}
	_staff_counter += 1
	var record := {
		"staff_id": "staff_%d" % _staff_counter,
		"staff_type": staff_type,
		"operations_room_id": room_id,
		"building_id": String(room["building_id"]),
		"floor_id": String(room["floor_id"]),
		"schema_version": SCHEMA_VERSION,
		"hired_revision": authority_revision + 1,
	}
	all_staff.append(record)
	all_staff.sort_custom(_sort_staff)
	authority_revision += 1
	staff_hired.emit(record["staff_id"], staff_type, room_id)
	staff_snapshot_changed.emit(snapshot())
	return {"committed": true, "staff_id": record["staff_id"], "authority_revision": authority_revision, "diagnostics": []}


func hire_staff(room_id: String, staff_type: OperationsRoomData.StaffType) -> Dictionary:
	return hire({"operations_room_id": room_id, "staff_type": "Cleaner" if staff_type == OperationsRoomData.StaffType.CLEANER else "Security"})


func fire(staff_id: String) -> Dictionary:
	for index: int in range(all_staff.size()):
		var record: Dictionary = all_staff[index]
		if String(record.get("staff_id", "")) != staff_id:
			continue
		var room_id := String(record["operations_room_id"])
		all_staff.remove_at(index)
		authority_revision += 1
		staff_fired.emit(staff_id, room_id)
		staff_snapshot_changed.emit(snapshot())
		return {"committed": true, "authority_revision": authority_revision, "diagnostics": []}
	return {"committed": false, "diagnostics": [{"code": "STAFF_MISSING"}]}


func staff_count(room_id: String, staff_type: String) -> int:
	var count: int = 0
	for record: Dictionary in all_staff:
		if String(record.get("operations_room_id", "")) == room_id and String(record.get("staff_type", "")) == staff_type:
			count += 1
	return count


func coverage_for_staff(staff_id: String) -> Dictionary:
	for record: Dictionary in all_staff:
		if String(record.get("staff_id", "")) != staff_id:
			continue
		var room: Dictionary = operations_rooms.get(String(record["operations_room_id"]), {})
		if room.is_empty():
			return {"valid": false, "diagnostics": [{"code": "STAFF_REFERENCE_INVALID"}]}
		var base: int = int(room.get("elevation", 0))
		return {"valid": true, "staff_id": staff_id, "building_id": String(room["building_id"]), "covered_floor_ids": _covered_floor_ids(String(room["building_id"]), base), "diagnostics": []}
	return {"valid": false, "diagnostics": [{"code": "STAFF_MISSING"}]}


func commit_cleaning_task(task: Dictionary) -> Dictionary:
	var task_kind := String(task.get("task_kind", ""))
	var task_id := String(task.get("task_id", ""))
	var staff_id := String(task.get("staff_id", ""))
	var floor_id := String(task.get("floor_id", ""))
	if not CLEANING_TASK_KINDS.has(task_kind) or task_id.is_empty() or floor_id.is_empty():
		return {"committed": false, "diagnostics": [{"code": "TASK_KIND_INVALID"}]}
	var staff: Dictionary = _staff_by_id(staff_id)
	if staff.is_empty():
		return {"committed": false, "diagnostics": [{"code": "STAFF_MISSING"}]}
	if String(staff["staff_type"]) != "Cleaner":
		return {"committed": false, "diagnostics": [{"code": "TASK_KIND_INVALID", "message": "Security has passive coverage only"}]}
	var coverage := coverage_for_staff(staff_id)
	if not bool(coverage.get("valid", false)) or not coverage.get("covered_floor_ids", []).has(floor_id):
		return {"committed": false, "diagnostics": [{"code": "TASK_FLOOR_OUT_OF_COVERAGE"}]}
	var fact := {"task_id": task_id, "task_kind": task_kind, "floor_id": floor_id, "source_reference": String(task.get("source_reference", "")), "lifecycle_state": String(task.get("lifecycle_state", "committed")), "staff_id": staff_id}
	cleaning_tasks.append(fact)
	authority_revision += 1
	staff_cleaning_task_committed.emit(task_id, staff_id, task_kind)
	return {"committed": true, "authority_revision": authority_revision, "diagnostics": []}


func paid_staff_weekly_snapshot(simulation_week: int) -> Dictionary:
	var entries: Array[Dictionary] = []
	for record: Dictionary in all_staff:
		entries.append({"staff_id": String(record["staff_id"]), "staff_type": String(record["staff_type"]), "operations_room_id": String(record["operations_room_id"]), "wage_kreds": PaidStaffWeeklySnapshot.WAGE_KREDS})
	entries.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return String(first["staff_id"]) < String(second["staff_id"]))
	return {"schema_version": PaidStaffWeeklySnapshot.SCHEMA_VERSION, "simulation_week": simulation_week, "staff_revision": authority_revision, "entries": entries, "provenance": "staff_authority_revision_%d" % authority_revision}


func snapshot() -> Dictionary:
	var coverage: Array[Dictionary] = []
	for record: Dictionary in all_staff:
		var facts := coverage_for_staff(String(record["staff_id"]))
		coverage.append({"staff_id": String(record["staff_id"]), "building_id": facts.get("building_id", ""), "covered_floor_ids": facts.get("covered_floor_ids", [])})
	return {"schema_version": SCHEMA_VERSION, "staff_revision": authority_revision, "staff": all_staff.duplicate(true), "room_occupancy": _room_occupancy(), "coverage": coverage, "cleaning_tasks": cleaning_tasks.duplicate(true), "diagnostics": []}


func serialize() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "staff_revision": authority_revision, "staff_counter": _staff_counter, "rooms": operations_rooms.duplicate(true), "staff": all_staff.duplicate(true), "cleaning_tasks": cleaning_tasks.duplicate(true)}


func deserialize(data: Dictionary) -> void:
	if int(data.get("schema_version", -1)) != SCHEMA_VERSION or not data.get("rooms", {}) is Dictionary or not data.get("staff", []) is Array:
		return
	operations_rooms = data["rooms"].duplicate(true)
	all_staff = data["staff"].duplicate(true)
	cleaning_tasks = data.get("cleaning_tasks", []).duplicate(true)
	_staff_counter = int(data.get("staff_counter", 0))
	authority_revision = int(data.get("staff_revision", 0))
	if not _validate_restored_staff():
		operations_rooms.clear()
		all_staff.clear()
		cleaning_tasks.clear()


func _covered_floor_ids(building_id: String, base_elevation: int) -> Array[String]:
	var result: Array[String] = []
	var floor_map: Dictionary = {}
	for room: Dictionary in operations_rooms.values():
		if String(room.get("building_id", "")) != building_id:
			continue
		var room_floor_map: Dictionary = room.get("building_floor_ids", {})
		for elevation_key: Variant in room_floor_map.keys():
			floor_map[int(elevation_key)] = String(room_floor_map[elevation_key])
		if int(room.get("elevation", 0)) == base_elevation:
			floor_map[base_elevation] = String(room.get("floor_id", ""))
	for elevation: int in range(base_elevation - 1, base_elevation + 2):
		if floor_map.has(elevation):
			result.append(String(floor_map[elevation]))
	result.sort()
	return result


func _room_occupancy() -> Dictionary:
	var result: Dictionary = {}
	for room_id: String in operations_rooms:
		result[room_id] = {"Cleaner": staff_count(room_id, "Cleaner"), "Security": staff_count(room_id, "Security")}
	return result


func _staff_by_id(staff_id: String) -> Dictionary:
	for record: Dictionary in all_staff:
		if String(record.get("staff_id", "")) == staff_id:
			return record
	return {}


func _validate_restored_staff() -> bool:
	var counts: Dictionary = {}
	for record: Dictionary in all_staff:
		var room_id := String(record.get("operations_room_id", ""))
		var room: Dictionary = operations_rooms.get(room_id, {})
		if room.is_empty() or not bool(room.get("committed_valid_for_staffing", false)) or String(record.get("building_id", "")) != String(room.get("building_id", "")) or String(record.get("floor_id", "")) != String(room.get("floor_id", "")) or not STAFF_TYPES.has(String(record.get("staff_type", ""))):
			return false
		var key := "%s|%s" % [room_id, String(record["staff_type"])]
		counts[key] = int(counts.get(key, 0)) + 1
		if counts[key] > MAX_PER_TYPE_PER_ROOM:
			return false
	return true


static func _sort_staff(first: Dictionary, second: Dictionary) -> bool:
	return String(first.get("staff_id", "")) < String(second.get("staff_id", ""))
