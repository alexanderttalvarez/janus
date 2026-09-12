## StaffManager — record-based MVP staff authority.
class_name StaffManager
extends Node

signal staff_hired(staff_id: String, staff_type: String, operations_room_id: String)
signal staff_fired(staff_id: String, operations_room_id: String)
signal staff_cleaning_task_committed(task_id: String, staff_id: String, task_kind: String)
signal staff_snapshot_changed(snapshot: Dictionary)

const SCHEMA_VERSION: int = 2
const MAX_PER_TYPE_PER_ROOM: int = 2
const STAFF_TYPES: Array[String] = ["Cleaner", "Security"]
const CLEANING_TASK_KINDS: Array[String] = ["garbage_removal", "bathroom_cleaning"]
const WAGE_POLICY_ID: String = "element_03_staff_wage"
const WAGE_POLICY_REVISION: int = 1
const PERSISTENCE_FIELDS: Array[String] = ["schema_version", "staff_revision", "staff_counter", "rooms", "staff", "pending_payroll", "cleaning_tasks"]
const ROOM_FIELDS: Array[String] = ["operations_room_id", "building_id", "floor_id", "elevation", "building_floor_ids", "committed_valid_for_staffing", "source_revision"]
const STAFF_FIELDS: Array[String] = ["staff_id", "staff_type", "operations_room_id", "building_id", "floor_id", "schema_version", "hired_revision"]
const PAYROLL_FIELDS: Array[String] = ["schema_version", "simulation_week", "staff_revision", "wage_policy_id", "wage_policy_revision", "entries", "provenance"]
const PAYROLL_ENTRY_FIELDS: Array[String] = ["staff_id", "staff_type", "operations_room_id", "wage_kreds"]

var operations_rooms: Dictionary = {}
var all_staff: Array[Dictionary] = []
var cleaning_tasks: Array[Dictionary] = []
var pending_payroll: Array[Dictionary] = []
var authority_revision: int = 0
var _staff_counter: int = 0

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
	var capture := capture_due_payroll(simulation_week)
	return capture.get("snapshot", {}).duplicate(true) if bool(capture.get("valid", false)) else {}


func capture_due_payroll(simulation_week: int) -> Dictionary:
	if simulation_week < 0:
		return {"valid": false, "diagnostics": [{"code": "PAID_STAFF_SNAPSHOT_INVALID", "path": "$.simulation_week"}]}
	for due: Dictionary in pending_payroll:
		if int(due["simulation_week"]) == simulation_week:
			return {"valid": true, "snapshot": due.duplicate(true), "diagnostics": []}
	if not pending_payroll.is_empty():
		return {"valid": false, "diagnostics": [{"code": "PAYROLL_WEEK_BLOCKED", "pending_simulation_week": int(pending_payroll[0]["simulation_week"])}]}
	var entries: Array[Dictionary] = []
	for record: Dictionary in all_staff:
		entries.append({"staff_id": String(record["staff_id"]), "staff_type": String(record["staff_type"]), "operations_room_id": String(record["operations_room_id"]), "wage_kreds": PaidStaffWeeklySnapshot.WAGE_KREDS})
	entries.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return String(first["staff_id"]) < String(second["staff_id"]))
	var due := {
		"schema_version": PaidStaffWeeklySnapshot.SCHEMA_VERSION,
		"simulation_week": simulation_week,
		"staff_revision": authority_revision,
		"wage_policy_id": WAGE_POLICY_ID,
		"wage_policy_revision": WAGE_POLICY_REVISION,
		"entries": entries,
		"provenance": "staff_authority_revision_%d" % authority_revision,
	}
	pending_payroll.append(due)
	return {"valid": true, "snapshot": due.duplicate(true), "diagnostics": []}


func acknowledge_payroll_settled(simulation_week: int) -> Dictionary:
	if pending_payroll.is_empty() or int(pending_payroll[0]["simulation_week"]) != simulation_week:
		return {"valid": false, "diagnostics": [{"code": "PAYROLL_WEEK_NOT_PENDING"}]}
	pending_payroll.remove_at(0)
	return {"valid": true, "diagnostics": []}


func snapshot() -> Dictionary:
	var coverage: Array[Dictionary] = []
	for record: Dictionary in all_staff:
		var facts := coverage_for_staff(String(record["staff_id"]))
		coverage.append({"staff_id": String(record["staff_id"]), "building_id": facts.get("building_id", ""), "covered_floor_ids": facts.get("covered_floor_ids", [])})
	return {"schema_version": SCHEMA_VERSION, "staff_revision": authority_revision, "staff": all_staff.duplicate(true), "room_occupancy": _room_occupancy(), "coverage": coverage, "cleaning_tasks": cleaning_tasks.duplicate(true), "diagnostics": []}


func serialize() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "staff_revision": authority_revision, "staff_counter": _staff_counter, "rooms": operations_rooms.duplicate(true), "staff": all_staff.duplicate(true), "pending_payroll": pending_payroll.duplicate(true), "cleaning_tasks": []}


func validate_serialized(data: Dictionary) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	_validate_exact_fields(data, PERSISTENCE_FIELDS, "$", diagnostics)
	if not _is_json_integer(data.get("schema_version"), SCHEMA_VERSION) or int(data.get("schema_version", -1)) != SCHEMA_VERSION:
		diagnostics.append({"code": "STAFF_SCHEMA_INVALID", "path": "$.schema_version"})
	if not _is_json_integer(data.get("staff_revision"), 0):
		diagnostics.append({"code": "STAFF_REVISION_INVALID", "path": "$.staff_revision"})
	if not _is_json_integer(data.get("staff_counter"), 0):
		diagnostics.append({"code": "STAFF_COUNTER_INVALID", "path": "$.staff_counter"})
	if not data.get("rooms") is Dictionary:
		diagnostics.append({"code": "STAFF_ROOMS_INVALID", "path": "$.rooms"})
	if not data.get("staff") is Array:
		diagnostics.append({"code": "STAFF_RECORD_INVALID", "path": "$.staff"})
	if not data.get("pending_payroll") is Array:
		diagnostics.append({"code": "STAFF_PAYROLL_INVALID", "path": "$.pending_payroll"})
	if not data.get("cleaning_tasks") is Array or not (data.get("cleaning_tasks", []) as Array).is_empty():
		diagnostics.append({"code": "STAFF_TASKS_NOT_SUPPORTED", "path": "$.cleaning_tasks"})
	if not diagnostics.is_empty():
		return {"valid": false, "diagnostics": diagnostics}
	var rooms: Dictionary = data["rooms"]
	for room_key: Variant in rooms:
		var room_path := "$.rooms.%s" % String(room_key)
		if typeof(room_key) != TYPE_STRING or not rooms[room_key] is Dictionary:
			diagnostics.append({"code": "STAFF_ROOM_INVALID", "path": room_path})
			continue
		var room: Dictionary = rooms[room_key]
		_validate_exact_fields(room, ROOM_FIELDS, room_path, diagnostics)
		if String(room_key).is_empty() or String(room.get("operations_room_id", "")) != String(room_key) or String(room.get("building_id", "")).is_empty() or String(room.get("floor_id", "")).is_empty():
			diagnostics.append({"code": "STAFF_ROOM_ID_INVALID", "path": room_path})
		if not _is_json_integer(room.get("elevation")) or not _is_json_integer(room.get("source_revision"), 0) or typeof(room.get("committed_valid_for_staffing")) != TYPE_BOOL or not bool(room.get("committed_valid_for_staffing", false)):
			diagnostics.append({"code": "STAFF_ROOM_REVISION_INVALID", "path": room_path})
		if not room.get("building_floor_ids") is Dictionary:
			diagnostics.append({"code": "STAFF_ROOM_FLOORS_INVALID", "path": "%s.building_floor_ids" % room_path})
		else:
			var building_floor_ids: Dictionary = room["building_floor_ids"]
			for elevation_key: Variant in building_floor_ids:
				var floor_value: Variant = building_floor_ids[elevation_key]
				if not str(elevation_key).is_valid_int() or typeof(floor_value) != TYPE_STRING or str(floor_value).is_empty():
					diagnostics.append({"code": "STAFF_ROOM_FLOORS_INVALID", "path": "%s.building_floor_ids" % room_path})
	var staff_records: Array = data["staff"]
	var seen_staff: Dictionary = {}
	var counts: Dictionary = {}
	var previous_staff_id: String = ""
	var max_staff_ordinal: int = 0
	for index: int in range(staff_records.size()):
		var record_path := "$.staff[%d]" % index
		if not staff_records[index] is Dictionary:
			diagnostics.append({"code": "STAFF_RECORD_INVALID", "path": record_path})
			continue
		var record: Dictionary = staff_records[index]
		_validate_exact_fields(record, STAFF_FIELDS, record_path, diagnostics)
		var staff_id := String(record.get("staff_id", ""))
		var ordinal := _stable_ordinal(staff_id, "staff_")
		if ordinal < 1 or seen_staff.has(staff_id) or (not previous_staff_id.is_empty() and previous_staff_id >= staff_id):
			diagnostics.append({"code": "STAFF_ID_INVALID", "path": "%s.staff_id" % record_path})
		seen_staff[staff_id] = true
		previous_staff_id = staff_id
		max_staff_ordinal = maxi(max_staff_ordinal, ordinal)
		var room_id := String(record.get("operations_room_id", ""))
		var room: Dictionary = rooms.get(room_id, {})
		if room.is_empty() or String(record.get("building_id", "")) != String(room.get("building_id", "")) or String(record.get("floor_id", "")) != String(room.get("floor_id", "")):
			diagnostics.append({"code": "STAFF_REFERENCE_INVALID", "path": record_path})
		if not STAFF_TYPES.has(String(record.get("staff_type", ""))) or not _is_json_integer(record.get("schema_version"), SCHEMA_VERSION) or int(record.get("schema_version", -1)) != SCHEMA_VERSION or not _is_json_integer(record.get("hired_revision"), 1) or int(record.get("hired_revision", -1)) > int(data["staff_revision"]):
			diagnostics.append({"code": "STAFF_RECORD_INVALID", "path": record_path})
		var count_key := "%s|%s" % [room_id, String(record.get("staff_type", ""))]
		counts[count_key] = int(counts.get(count_key, 0)) + 1
		if int(counts[count_key]) > MAX_PER_TYPE_PER_ROOM:
			diagnostics.append({"code": "STAFF_CAPACITY_INVALID", "path": record_path})
	if max_staff_ordinal > int(data["staff_counter"]):
		diagnostics.append({"code": "STAFF_COUNTER_INVALID", "path": "$.staff_counter"})
	_validate_pending_payroll(data["pending_payroll"], rooms, int(data["staff_revision"]), int(data["staff_counter"]), diagnostics)
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}


func deserialize(data: Dictionary) -> Dictionary:
	var validation := validate_serialized(data)
	if not bool(validation["valid"]):
		return validation
	operations_rooms.clear()
	for room_id: String in data["rooms"]:
		var room: Dictionary = data["rooms"][room_id].duplicate(true)
		room["elevation"] = int(room["elevation"])
		room["source_revision"] = int(room["source_revision"])
		operations_rooms[room_id] = room
	all_staff.clear()
	for record_value: Dictionary in data["staff"]:
		var record := record_value.duplicate(true)
		record["schema_version"] = int(record["schema_version"])
		record["hired_revision"] = int(record["hired_revision"])
		all_staff.append(record)
	pending_payroll.clear()
	for due_value: Dictionary in data["pending_payroll"]:
		var due := due_value.duplicate(true)
		due["schema_version"] = int(due["schema_version"])
		due["simulation_week"] = int(due["simulation_week"])
		due["staff_revision"] = int(due["staff_revision"])
		due["wage_policy_revision"] = int(due["wage_policy_revision"])
		for entry: Dictionary in due["entries"]:
			entry["wage_kreds"] = int(entry["wage_kreds"])
		pending_payroll.append(due)
	cleaning_tasks.clear()
	_staff_counter = int(data["staff_counter"])
	authority_revision = int(data["staff_revision"])
	return {"valid": true, "diagnostics": []}


func _validate_pending_payroll(values: Array, rooms: Dictionary, current_revision: int, staff_counter: int, diagnostics: Array[Dictionary]) -> void:
	var previous_week: int = -1
	for index: int in range(values.size()):
		var payroll_path := "$.pending_payroll[%d]" % index
		if not values[index] is Dictionary:
			diagnostics.append({"code": "STAFF_PAYROLL_INVALID", "path": payroll_path})
			continue
		var payroll: Dictionary = values[index]
		_validate_exact_fields(payroll, PAYROLL_FIELDS, payroll_path, diagnostics)
		var week_valid: bool = _is_json_integer(payroll.get("simulation_week"), 0)
		var captured_revision_valid: bool = _is_json_integer(payroll.get("staff_revision"), 0) and int(payroll.get("staff_revision", -1)) <= current_revision
		if not _is_json_integer(payroll.get("schema_version"), PaidStaffWeeklySnapshot.SCHEMA_VERSION) or int(payroll.get("schema_version", -1)) != PaidStaffWeeklySnapshot.SCHEMA_VERSION or not week_valid or not captured_revision_valid:
			diagnostics.append({"code": "STAFF_PAYROLL_INVALID", "path": payroll_path})
		if week_valid and int(payroll["simulation_week"]) <= previous_week:
			diagnostics.append({"code": "STAFF_PAYROLL_ORDER_INVALID", "path": payroll_path})
		if week_valid:
			previous_week = int(payroll["simulation_week"])
		if typeof(payroll.get("wage_policy_id")) != TYPE_STRING or String(payroll.get("wage_policy_id", "")) != WAGE_POLICY_ID or not _is_json_integer(payroll.get("wage_policy_revision"), WAGE_POLICY_REVISION) or int(payroll.get("wage_policy_revision", -1)) != WAGE_POLICY_REVISION:
			diagnostics.append({"code": "STAFF_PAYROLL_POLICY_INVALID", "path": payroll_path})
		if not captured_revision_valid or typeof(payroll.get("provenance")) != TYPE_STRING or String(payroll.get("provenance", "")) != "staff_authority_revision_%d" % int(payroll.get("staff_revision", -1)):
			diagnostics.append({"code": "STAFF_PAYROLL_PROVENANCE_INVALID", "path": payroll_path})
		if not payroll.get("entries") is Array:
			diagnostics.append({"code": "STAFF_PAYROLL_INVALID", "path": "%s.entries" % payroll_path})
			continue
		var seen_entries: Dictionary = {}
		var previous_staff_id: String = ""
		for entry_index: int in range((payroll["entries"] as Array).size()):
			var entry_path := "%s.entries[%d]" % [payroll_path, entry_index]
			var entry_value: Variant = payroll["entries"][entry_index]
			if not entry_value is Dictionary:
				diagnostics.append({"code": "STAFF_PAYROLL_ENTRY_INVALID", "path": entry_path})
				continue
			var entry: Dictionary = entry_value
			_validate_exact_fields(entry, PAYROLL_ENTRY_FIELDS, entry_path, diagnostics)
			var staff_id := String(entry.get("staff_id", ""))
			var ordinal: int = _stable_ordinal(staff_id, "staff_")
			if ordinal < 1 or ordinal > staff_counter or seen_entries.has(staff_id) or (not previous_staff_id.is_empty() and previous_staff_id >= staff_id):
				diagnostics.append({"code": "STAFF_PAYROLL_STAFF_ID_INVALID", "path": "%s.staff_id" % entry_path})
			seen_entries[staff_id] = true
			previous_staff_id = staff_id
			if not STAFF_TYPES.has(String(entry.get("staff_type", ""))) or String(entry.get("operations_room_id", "")).is_empty() or not rooms.has(String(entry.get("operations_room_id", ""))) or not _is_json_integer(entry.get("wage_kreds"), PaidStaffWeeklySnapshot.WAGE_KREDS) or int(entry.get("wage_kreds", -1)) != PaidStaffWeeklySnapshot.WAGE_KREDS:
				diagnostics.append({"code": "STAFF_PAYROLL_ENTRY_INVALID", "path": entry_path})


func _validate_exact_fields(value: Dictionary, fields: Array[String], path: String, diagnostics: Array[Dictionary]) -> void:
	if value.size() != fields.size():
		diagnostics.append({"code": "STAFF_FIELDS_INVALID", "path": path})
	for field: String in fields:
		if not value.has(field):
			diagnostics.append({"code": "STAFF_FIELD_MISSING", "path": "%s.%s" % [path, field]})


func _is_json_integer(value: Variant, minimum: int = -2147483648) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= minimum
	if typeof(value) != TYPE_FLOAT:
		return false
	var numeric := float(value)
	return is_finite(numeric) and numeric == floor(numeric) and numeric >= minimum


func _stable_ordinal(stable_id: String, prefix: String) -> int:
	if not stable_id.begins_with(prefix):
		return -1
	var suffix := stable_id.trim_prefix(prefix)
	if not suffix.is_valid_int():
		return -1
	var ordinal := int(suffix)
	return ordinal if ordinal > 0 and stable_id == "%s%d" % [prefix, ordinal] else -1


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


static func _sort_staff(first: Dictionary, second: Dictionary) -> bool:
	return String(first.get("staff_id", "")) < String(second.get("staff_id", ""))
