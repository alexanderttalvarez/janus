class_name DistrictStateRecords
extends RefCounted

## H2 closed sparse authority-state validator. H3 owns lifecycle and mutation.

const STATE_SCHEMA_VERSION: int = 3
const DISTRICT_FIELDS: Array[String] = ["state_schema_version", "district_revision", "layout_id", "layout_definition_version", "definition_fingerprint", "plot_states", "street_segment_states", "arrival_source_states", "demolished_fixed_occupant_ids", "construction_schema_version", "construction_revision", "construction_records", "manual_door_edges"]
const PLOT_FIELDS: Array[String] = ["runtime_plot_id", "section_state_overrides", "floor_states"]
const SECTION_FIELDS: Array[String] = ["runtime_section_id", "owned", "available"]
const FLOOR_FIELDS: Array[String] = ["floor_id", "elevation", "acquired_cells", "constructed_cells", "explicit_circulation_cells"]
const STREET_FIELDS: Array[String] = ["street_segment_id", "converted"]
const SOURCE_FIELDS: Array[String] = ["arrival_source_id", "enabled"]
const CONSTRUCTION_RECORD_FIELDS: Array[String] = ["construction_id", "kind", "plot_id", "cells", "shaft_cells", "lobby_cells", "connection"]
const CONSTRUCTION_CELL_FIELDS: Array[String] = ["plot_id", "floor_id", "elevation", "x", "y"]
const CONSTRUCTION_CONNECTION_FIELDS: Array[String] = ["orientation", "stop_elevations"]
const CONSTRUCTION_SCHEMA_VERSION: int = 1
const MANUAL_DOOR_EDGE_FIELDS: Array[String] = ["endpoint_a", "endpoint_b"]
const FLOOR_CELL_ADDRESS_FIELDS: Array[String] = ["runtime_plot_id", "signed_elevation", "local_cell"]
const LOCAL_CELL_FIELDS: Array[String] = ["x", "y"]


func create_baseline(snapshot: ResolvedDistrictSnapshot) -> Dictionary:
	return {
		"state_schema_version": STATE_SCHEMA_VERSION,
		"district_revision": 0,
		"layout_id": snapshot.get_layout_id(),
		"layout_definition_version": int(snapshot.get_data().get("layout_definition_version", 0)),
		"definition_fingerprint": snapshot.get_fingerprint(),
		"plot_states": [],
		"street_segment_states": [],
		"arrival_source_states": [],
		"demolished_fixed_occupant_ids": [],
		"construction_schema_version": CONSTRUCTION_SCHEMA_VERSION,
		"construction_revision": 0,
		"construction_records": [],
		"manual_door_edges": [],
	}


func validate(state: Variant, snapshot: ResolvedDistrictSnapshot) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if not state is Dictionary:
		return _failure("STATE_NOT_OBJECT", "state must be an object")
	var value: Dictionary = state
	_check_exact_fields(value, DISTRICT_FIELDS, "$", diagnostics)
	_check_int(value, "state_schema_version", "$", diagnostics)
	_check_int(value, "district_revision", "$", diagnostics)
	_check_int(value, "construction_schema_version", "$", diagnostics)
	_check_int(value, "construction_revision", "$", diagnostics)
	if int(value.get("state_schema_version", -1)) != STATE_SCHEMA_VERSION:
		_add(diagnostics, "STATE_SCHEMA_VERSION_INVALID", "$.state_schema_version", "state schema version must be 3")
	if int(value.get("district_revision", -1)) < 0:
		_add(diagnostics, "DISTRICT_REVISION_INVALID", "$.district_revision", "district revision must be nonnegative")
	if int(value.get("construction_schema_version", -1)) != CONSTRUCTION_SCHEMA_VERSION:
		_add(diagnostics, "CONSTRUCTION_SCHEMA_VERSION_INVALID", "$.construction_schema_version", "construction schema version must be 1")
	if int(value.get("construction_revision", -1)) < 0 or int(value.get("construction_revision", -1)) > int(value.get("district_revision", -1)):
		_add(diagnostics, "CONSTRUCTION_REVISION_INVALID", "$.construction_revision", "construction revision must be nonnegative and cannot exceed district revision")
	if String(value.get("layout_id", "")) != snapshot.get_layout_id():
		_add(diagnostics, "LAYOUT_ID_MISMATCH", "$.layout_id", "state layout ID must match the snapshot")
	if int(value.get("layout_definition_version", -1)) != int(snapshot.get_data().get("layout_definition_version", -2)):
		_add(diagnostics, "LAYOUT_DEFINITION_VERSION_MISMATCH", "$.layout_definition_version", "state layout definition version must match the snapshot")
	if String(value.get("definition_fingerprint", "")) != snapshot.get_fingerprint():
		_add(diagnostics, "FINGERPRINT_MISMATCH", "$.definition_fingerprint", "state fingerprint must match the snapshot")
	var data: Dictionary = snapshot.get_data()
	var plot_ids: Dictionary = _records_by_id(data.get("plots", []))
	var section_by_id: Dictionary = _records_by_id(data.get("sections", []))
	var floor_by_id: Dictionary = _records_by_id(data.get("floors", []))
	var allowed_cells_by_floor: Dictionary = _allowed_cells_by_floor(data.get("cells", []))
	var street_by_id: Dictionary = _records_by_id(data.get("street_segments", []))
	var source_by_id: Dictionary = _records_by_authored_id(data.get("arrival_source_attachments", []), "authored_id")
	var occupant_by_id: Dictionary = _records_by_id(data.get("fixed_occupants", []))
	_validate_plot_states(value.get("plot_states", []), plot_ids, section_by_id, floor_by_id, allowed_cells_by_floor, diagnostics)
	_validate_street_states(value.get("street_segment_states", []), street_by_id, data, diagnostics)
	_validate_source_states(value.get("arrival_source_states", []), source_by_id, diagnostics)
	_validate_demolished(value.get("demolished_fixed_occupant_ids", []), occupant_by_id, diagnostics)
	_validate_construction_records(value.get("construction_records", []), value, plot_ids, floor_by_id, allowed_cells_by_floor, diagnostics)
	_validate_manual_door_edges(value.get("manual_door_edges", []), plot_ids, floor_by_id, allowed_cells_by_floor, diagnostics)
	return {"valid": diagnostics.is_empty(), "state": value.duplicate(true) if diagnostics.is_empty() else {}, "diagnostics": diagnostics}


func _validate_plot_states(value: Variant, plot_ids: Dictionary, section_by_id: Dictionary, floor_by_id: Dictionary, allowed_cells_by_floor: Dictionary, diagnostics: Array[Dictionary]) -> void:
	if not value is Array:
		_add(diagnostics, "PLOT_STATES_INVALID", "$.plot_states", "plot_states must be an array")
		return
	var previous_id: String = ""
	for index: int in range(value.size()):
		var path: String = "$.plot_states[%d]" % index
		var plot_state: Variant = value[index]
		if not plot_state is Dictionary:
			_add(diagnostics, "PLOT_STATE_INVALID", path, "Plot state must be an object")
			continue
		_check_exact_fields(plot_state, PLOT_FIELDS, path, diagnostics)
		_check_string(plot_state, "runtime_plot_id", path, diagnostics)
		var plot_id: String = String(plot_state.get("runtime_plot_id", ""))
		if not plot_ids.has(plot_id):
			_add(diagnostics, "PLOT_ID_UNKNOWN", path, "Plot state references an unknown runtime Plot")
		if index > 0 and plot_id <= previous_id:
			_add(diagnostics, "STATE_ORDER_INVALID", path, "Plot states must be stable-ID ascending")
		previous_id = plot_id
		var section_overrides: Variant = plot_state.get("section_state_overrides", null)
		var floors: Variant = plot_state.get("floor_states", null)
		if not section_overrides is Array or not floors is Array:
			_add(diagnostics, "PLOT_CHILDREN_INVALID", path, "Plot child collections must be arrays")
			continue
		if section_overrides.is_empty() and floors.is_empty():
			_add(diagnostics, "EMPTY_PLOT_STATE", path, "empty Plot state records are forbidden")
		_validate_section_overrides(section_overrides, section_by_id, plot_id, path, diagnostics)
		_validate_floor_states(floors, floor_by_id, allowed_cells_by_floor, plot_id, path, diagnostics)


func _validate_section_overrides(value: Array, section_by_id: Dictionary, plot_id: String, path: String, diagnostics: Array[Dictionary]) -> void:
	var previous_id: String = ""
	for index: int in range(value.size()):
		var child_path: String = "%s.section_state_overrides[%d]" % [path, index]
		var child: Variant = value[index]
		if not child is Dictionary:
			_add(diagnostics, "SECTION_STATE_INVALID", child_path, "section override must be an object")
			continue
		_check_exact_fields(child, SECTION_FIELDS, child_path, diagnostics)
		_check_string(child, "runtime_section_id", child_path, diagnostics)
		_check_bool(child, "owned", child_path, diagnostics)
		_check_bool(child, "available", child_path, diagnostics)
		var section_id: String = String(child.get("runtime_section_id", ""))
		if not section_by_id.has(section_id) or String(section_by_id.get(section_id, {}).get("plot_id", "")) != plot_id:
			_add(diagnostics, "SECTION_ID_UNKNOWN", child_path, "section override must belong to its Plot")
		if index > 0 and section_id <= previous_id:
			_add(diagnostics, "STATE_ORDER_INVALID", child_path, "section overrides must be stable-ID ascending")
		previous_id = section_id
		if section_by_id.has(section_id) and bool(child.get("owned", false)) == bool(section_by_id[section_id].get("initially_owned", false)) and bool(child.get("available", false)) == bool(section_by_id[section_id].get("initially_available", false)):
			_add(diagnostics, "BASELINE_SECTION_STATE", child_path, "baseline section state must be omitted")


func _validate_floor_states(value: Array, floor_by_id: Dictionary, allowed_cells_by_floor: Dictionary, plot_id: String, path: String, diagnostics: Array[Dictionary]) -> void:
	var previous_elevation: int = -9223372036854775807
	var previous_id: String = ""
	for index: int in range(value.size()):
		var child_path: String = "%s.floor_states[%d]" % [path, index]
		var child: Variant = value[index]
		if not child is Dictionary:
			_add(diagnostics, "FLOOR_STATE_INVALID", child_path, "floor state must be an object")
			continue
		_check_exact_fields(child, FLOOR_FIELDS, child_path, diagnostics)
		_check_string(child, "floor_id", child_path, diagnostics)
		_check_int(child, "elevation", child_path, diagnostics)
		var floor_id: String = String(child.get("floor_id", ""))
		var elevation: int = int(child.get("elevation", 0))
		if not floor_by_id.has(floor_id) or String(floor_by_id.get(floor_id, {}).get("plot_id", "")) != plot_id:
			_add(diagnostics, "FLOOR_ID_UNKNOWN", child_path, "floor state must belong to its Plot")
		elif elevation != int(floor_by_id[floor_id].get("elevation", 0)):
			_add(diagnostics, "FLOOR_ELEVATION_MISMATCH", child_path, "floor state elevation must match its immutable floor")
		if index > 0 and (elevation < previous_elevation or (elevation == previous_elevation and floor_id <= previous_id)):
			_add(diagnostics, "STATE_ORDER_INVALID", child_path, "floor states must be signed-elevation ascending then stable ID")
		previous_elevation = elevation
		previous_id = floor_id
		var acquired: Variant = child.get("acquired_cells", null)
		var constructed: Variant = child.get("constructed_cells", null)
		var circulation: Variant = child.get("explicit_circulation_cells", null)
		if not acquired is Array or not constructed is Array or not circulation is Array:
			_add(diagnostics, "CELL_SET_INVALID", child_path, "floor cell sets must be arrays")
			continue
		if acquired.is_empty() and constructed.is_empty() and circulation.is_empty():
			_add(diagnostics, "EMPTY_FLOOR_STATE", child_path, "empty floor state records are forbidden")
		_validate_cells(acquired, "%s.acquired_cells" % child_path, diagnostics)
		_validate_cells(constructed, "%s.constructed_cells" % child_path, diagnostics)
		_validate_cells(circulation, "%s.explicit_circulation_cells" % child_path, diagnostics)
		var allowed_cells: Dictionary = allowed_cells_by_floor.get(floor_id, {})
		for cell: Array in acquired:
			if not allowed_cells.has("%d,%d" % [int(cell[0]), int(cell[1])]):
				_add(diagnostics, "ACQUIRED_CELL_FORBIDDEN", child_path, "acquired cells must satisfy immutable definition rights")
		for cell: Array in constructed:
			if not _contains_cell(acquired, cell):
				_add(diagnostics, "CONSTRUCTION_WITHOUT_ACQUISITION", child_path, "constructed cells must be acquired")
		for cell: Array in circulation:
			if not _contains_cell(constructed, cell) or not _contains_cell(acquired, cell):
				_add(diagnostics, "CIRCULATION_WITHOUT_CONSTRUCTION", child_path, "explicit circulation cells must be constructed and acquired")


func _validate_street_states(value: Variant, street_by_id: Dictionary, snapshot_data: Dictionary, diagnostics: Array[Dictionary]) -> void:
	if not value is Array:
		_add(diagnostics, "STREET_STATES_INVALID", "$.street_segment_states", "street_segment_states must be an array")
		return
	var previous_id: String = ""
	var boundary_count_h: int = snapshot_data.get("grid", {}).get("horizontal_boundary_starts_quarter", []).size() - 1
	var boundary_count_v: int = snapshot_data.get("grid", {}).get("vertical_boundary_starts_quarter", []).size() - 1
	for index: int in range(value.size()):
		var path: String = "$.street_segment_states[%d]" % index
		var child: Variant = value[index]
		if not child is Dictionary:
			_add(diagnostics, "STREET_STATE_INVALID", path, "street state must be an object")
			continue
		_check_exact_fields(child, STREET_FIELDS, path, diagnostics)
		_check_string(child, "street_segment_id", path, diagnostics)
		_check_bool(child, "converted", path, diagnostics)
		var street_id: String = String(child.get("street_segment_id", ""))
		if not street_by_id.has(street_id):
			_add(diagnostics, "STREET_ID_UNKNOWN", path, "street state references an unknown segment")
		else:
			var boundary_id: String = String(street_by_id[street_id].get("boundary_id", ""))
			if boundary_id == "h0" or boundary_id == "h%d" % boundary_count_h or boundary_id == "v0" or boundary_id == "v%d" % boundary_count_v:
				_add(diagnostics, "OUTER_RING_CONVERSION", path, "outer-ring street segments cannot be converted")
		if index > 0 and street_id <= previous_id:
			_add(diagnostics, "STATE_ORDER_INVALID", path, "street states must be stable-ID ascending")
		previous_id = street_id
		if not bool(child.get("converted", false)):
			_add(diagnostics, "BASELINE_STREET_STATE", path, "false street conversion baseline must be omitted")


func _validate_source_states(value: Variant, source_by_id: Dictionary, diagnostics: Array[Dictionary]) -> void:
	if not value is Array:
		_add(diagnostics, "SOURCE_STATES_INVALID", "$.arrival_source_states", "arrival_source_states must be an array")
		return
	var previous_id: String = ""
	for index: int in range(value.size()):
		var path: String = "$.arrival_source_states[%d]" % index
		var child: Variant = value[index]
		if not child is Dictionary:
			_add(diagnostics, "SOURCE_STATE_INVALID", path, "arrival source state must be an object")
			continue
		_check_exact_fields(child, SOURCE_FIELDS, path, diagnostics)
		_check_string(child, "arrival_source_id", path, diagnostics)
		_check_bool(child, "enabled", path, diagnostics)
		var source_id: String = String(child.get("arrival_source_id", ""))
		if not source_by_id.has(source_id):
			_add(diagnostics, "SOURCE_ID_UNKNOWN", path, "arrival source state references an unknown source")
		if index > 0 and source_id <= previous_id:
			_add(diagnostics, "STATE_ORDER_INVALID", path, "arrival source states must be stable-ID ascending")
		previous_id = source_id
		if source_by_id.has(source_id) and bool(child.get("enabled", false)) == bool(source_by_id[source_id].get("initially_enabled", false)):
			_add(diagnostics, "BASELINE_SOURCE_STATE", path, "baseline source state must be omitted")


func _validate_demolished(value: Variant, occupant_by_id: Dictionary, diagnostics: Array[Dictionary]) -> void:
	if not value is Array:
		_add(diagnostics, "DEMOLISHED_INVALID", "$.demolished_fixed_occupant_ids", "demolished occupant IDs must be an array")
		return
	var previous_id: String = ""
	for index: int in range(value.size()):
		var path: String = "$.demolished_fixed_occupant_ids[%d]" % index
		if typeof(value[index]) != TYPE_STRING:
			_add(diagnostics, "DEMOLISHED_ID_INVALID", path, "demolished occupant ID must be a string")
			continue
		var occupant_id: String = String(value[index])
		if not occupant_by_id.has(occupant_id):
			_add(diagnostics, "OCCUPANT_ID_UNKNOWN", path, "demolished occupant ID is not in immutable occupancy")
		if index > 0 and occupant_id <= previous_id:
			_add(diagnostics, "STATE_ORDER_INVALID", path, "demolished occupant IDs must be stable-ID ascending")
		previous_id = occupant_id


func _validate_construction_records(value: Variant, state: Dictionary, plot_ids: Dictionary, floor_by_id: Dictionary, allowed_cells_by_floor: Dictionary, diagnostics: Array[Dictionary]) -> void:
	if not value is Array:
		_add(diagnostics, "CONSTRUCTION_RECORDS_INVALID", "$.construction_records", "construction_records must be an array")
		return
	var previous_id: String = ""
	var occupied: Dictionary = {}
	for index: int in range(value.size()):
		var path: String = "$.construction_records[%d]" % index
		var record: Variant = value[index]
		if not record is Dictionary:
			_add(diagnostics, "CONSTRUCTION_RECORD_INVALID", path, "construction record must be an object")
			continue
		_check_exact_fields(record, CONSTRUCTION_RECORD_FIELDS, path, diagnostics)
		var construction_id: String = String(record.get("construction_id", ""))
		var kind: String = String(record.get("kind", ""))
		var plot_id: String = String(record.get("plot_id", ""))
		if construction_id.is_empty() or (index > 0 and construction_id <= previous_id):
			_add(diagnostics, "CONSTRUCTION_ORDER_INVALID", path, "construction records must be unique and construction-ID ascending")
		previous_id = construction_id
		if not ["stairs", "elevator", "operations_room"].has(kind):
			_add(diagnostics, "CONSTRUCTION_TYPE_INVALID", path, "construction records permit only stairs, elevator, and operations_room")
		if not plot_ids.has(plot_id):
			_add(diagnostics, "CONSTRUCTION_PLOT_UNKNOWN", path, "construction Plot must resolve")
		var cells: Variant = record.get("cells", null)
		var shaft_cells: Variant = record.get("shaft_cells", null)
		var lobby_cells: Variant = record.get("lobby_cells", null)
		var connection: Variant = record.get("connection", null)
		if not cells is Array or cells.is_empty() or not shaft_cells is Array or not lobby_cells is Array:
			_add(diagnostics, "CONSTRUCTION_CELL_SET_INVALID", path, "construction cell collections must be arrays and cells must be nonempty")
			continue
		if not connection is Dictionary or not _has_exact_fields(connection, CONSTRUCTION_CONNECTION_FIELDS) or not connection.get("orientation") is String or not connection.get("stop_elevations") is Array:
			_add(diagnostics, "CONSTRUCTION_CONNECTION_INVALID", path, "construction connection must have exact orientation and stop_elevations")
			continue
		for field: String in ["cells", "shaft_cells", "lobby_cells"]:
			_validate_construction_cell_array(record[field], plot_id, state, floor_by_id, allowed_cells_by_floor, occupied if field == "cells" else {}, "%s.%s" % [path, field], diagnostics)
		_validate_construction_shape(kind, cells, shaft_cells, lobby_cells, connection, path, diagnostics)


func _validate_construction_cell_array(cells: Array, plot_id: String, state: Dictionary, floor_by_id: Dictionary, allowed_cells_by_floor: Dictionary, occupied: Dictionary, path: String, diagnostics: Array[Dictionary]) -> void:
	var previous: Dictionary = {}
	var seen: Dictionary = {}
	for index: int in range(cells.size()):
		var cell_path: String = "%s[%d]" % [path, index]
		var value: Variant = cells[index]
		if not value is Dictionary or not _has_exact_fields(value, CONSTRUCTION_CELL_FIELDS):
			_add(diagnostics, "CONSTRUCTION_CELL_INVALID", cell_path, "construction cell must be an exact ConstructionCellAddress")
			continue
		var cell: Dictionary = value
		if not cell.get("plot_id") is String or not cell.get("floor_id") is String or not cell.get("elevation") is int or not cell.get("x") is int or not cell.get("y") is int:
			_add(diagnostics, "CONSTRUCTION_CELL_INVALID", cell_path, "construction cell fields have invalid types")
			continue
		var floor_id: String = String(cell["floor_id"])
		var x: int = int(cell["x"])
		var y: int = int(cell["y"])
		if String(cell["plot_id"]) != plot_id or not floor_by_id.has(floor_id) or String(floor_by_id[floor_id].get("plot_id", "")) != plot_id or int(floor_by_id[floor_id].get("elevation", 999999)) != int(cell["elevation"]):
			_add(diagnostics, "CONSTRUCTION_CELL_SCOPE_INVALID", cell_path, "construction cell must resolve to its record Plot and floor")
		if not allowed_cells_by_floor.get(floor_id, {}).has("%d,%d" % [x, y]):
			_add(diagnostics, "CONSTRUCTION_CELL_FORBIDDEN", cell_path, "construction cell must belong to immutable floor rights")
		var key: String = "%s:%d:%d" % [floor_id, x, y]
		if seen.has(key):
			_add(diagnostics, "CONSTRUCTION_CELL_DUPLICATE", cell_path, "construction cell arrays must be duplicate-free")
		seen[key] = true
		if not previous.is_empty() and not _construction_cell_less(previous, cell):
			_add(diagnostics, "CONSTRUCTION_CELL_ORDER_INVALID", cell_path, "construction cells must use canonical elevation/floor/y/x order")
		previous = cell
		if not _state_has_floor_cell(state, plot_id, floor_id, [x, y], "constructed_cells"):
			_add(diagnostics, "CONSTRUCTION_RECORD_CELL_NOT_CONSTRUCTED", cell_path, "record cells must be present in FloorState.constructed_cells")
		if not occupied.is_empty() and occupied.has(key):
			_add(diagnostics, "CONSTRUCTION_CELL_OVERLAP", cell_path, "construction records cannot overlap")
		occupied[key] = true


func _validate_construction_shape(kind: String, cells: Array, shaft_cells: Array, lobby_cells: Array, connection: Dictionary, path: String, diagnostics: Array[Dictionary]) -> void:
	var stops: Array = connection.get("stop_elevations", [])
	for stop: Variant in stops:
		if typeof(stop) != TYPE_INT:
			_add(diagnostics, "CONSTRUCTION_STOP_INVALID", path, "stop elevations must be integers")
			return
	for index: int in range(1, stops.size()):
		if int(stops[index]) <= int(stops[index - 1]):
			_add(diagnostics, "CONSTRUCTION_STOP_ORDER_INVALID", path, "stop elevations must be unique and ascending")
	if kind == "stairs":
		if not shaft_cells.is_empty() or not lobby_cells.is_empty() or cells.size() != 8 or stops.size() != 2 or int(stops[1]) != int(stops[0]) + 1 or not ["NORTH", "EAST", "SOUTH", "WEST"].has(String(connection.get("orientation", ""))):
			_add(diagnostics, "STAIRS_GEOMETRY_INVALID", path, "stairs require two adjacent 2x2 floors and cardinal orientation")
		elif not _two_by_two_per_stop(cells, stops):
			_add(diagnostics, "STAIRS_GEOMETRY_INVALID", path, "stairs require matching 2x2 footprints")
	elif kind == "operations_room":
		if not shaft_cells.is_empty() or not lobby_cells.is_empty() or cells.size() != 4 or stops.size() != 1 or String(connection.get("orientation", "")) != "NONE" or not _two_by_two_per_stop(cells, stops):
			_add(diagnostics, "OPERATIONS_ROOM_GEOMETRY_INVALID", path, "Operations Room requires one 2x2 floor and NONE orientation")
	elif kind == "elevator":
		if shaft_cells.is_empty() or shaft_cells.size() != lobby_cells.size() or stops.size() != shaft_cells.size() or not stops.has(0) or String(connection.get("orientation", "")) != "NONE":
			_add(diagnostics, "ELEVATOR_GEOMETRY_INVALID", path, "elevator requires one shaft and distinct lobby per contiguous stop including ground")
			return
		for index: int in range(1, stops.size()):
			if int(stops[index]) != int(stops[index - 1]) + 1:
				_add(diagnostics, "ELEVATOR_GEOMETRY_INVALID", path, "elevator stops must be contiguous")
		var union: Dictionary = {}
		for cell: Dictionary in shaft_cells + lobby_cells:
			union[_construction_cell_key(cell)] = true
		if union.size() != cells.size():
			_add(diagnostics, "ELEVATOR_UNION_INVALID", path, "elevator cells must be the exact shaft/lobby union")
		for cell: Dictionary in cells:
			if not union.has(_construction_cell_key(cell)):
				_add(diagnostics, "ELEVATOR_UNION_INVALID", path, "elevator cells must be the exact shaft/lobby union")


func _two_by_two_per_stop(cells: Array, stops: Array) -> bool:
	for stop: int in stops:
		var floor_cells: Array = []
		for cell: Dictionary in cells:
			if int(cell.get("elevation", 999999)) == stop:
				floor_cells.append(cell)
		if floor_cells.size() != 4:
			return false
		var minimum_x: int = 999999
		var minimum_y: int = 999999
		var keys: Dictionary = {}
		for cell: Dictionary in floor_cells:
			minimum_x = mini(minimum_x, int(cell["x"]))
			minimum_y = mini(minimum_y, int(cell["y"]))
			keys["%d,%d" % [int(cell["x"]), int(cell["y"])]] = true
		for y: int in range(minimum_y, minimum_y + 2):
			for x: int in range(minimum_x, minimum_x + 2):
				if not keys.has("%d,%d" % [x, y]):
					return false
	return true


func _construction_cell_less(left: Dictionary, right: Dictionary) -> bool:
	if int(left.get("elevation", 0)) != int(right.get("elevation", 0)):
		return int(left.get("elevation", 0)) < int(right.get("elevation", 0))
	if String(left.get("floor_id", "")) != String(right.get("floor_id", "")):
		return String(left.get("floor_id", "")) < String(right.get("floor_id", ""))
	if int(left.get("y", 0)) != int(right.get("y", 0)):
		return int(left.get("y", 0)) < int(right.get("y", 0))
	return int(left.get("x", 0)) < int(right.get("x", 0))


func _construction_cell_key(cell: Dictionary) -> String:
	return "%s|%+011d|%s|%011d|%011d" % [String(cell.get("plot_id", "")), int(cell.get("elevation", 0)), String(cell.get("floor_id", "")), int(cell.get("y", -1)), int(cell.get("x", -1))]


func _state_has_floor_cell(state: Dictionary, plot_id: String, floor_id: String, cell: Array, field: String) -> bool:
	for plot_state: Dictionary in state.get("plot_states", []):
		if String(plot_state.get("runtime_plot_id", "")) != plot_id:
			continue
		for floor_state: Dictionary in plot_state.get("floor_states", []):
			if String(floor_state.get("floor_id", "")) == floor_id and _contains_cell(floor_state.get(field, []), cell):
				return true
	return false


func _validate_manual_door_edges(value: Variant, plot_ids: Dictionary, floor_by_id: Dictionary, allowed_cells_by_floor: Dictionary, diagnostics: Array[Dictionary]) -> void:
	if not value is Array:
		_add(diagnostics, "MANUAL_DOOR_EDGES_INVALID", "$.manual_door_edges", "manual_door_edges must be an array")
		return
	var previous_key: String = ""
	for index: int in range(value.size()):
		var path: String = "$.manual_door_edges[%d]" % index
		var record: Variant = value[index]
		if not record is Dictionary:
			_add(diagnostics, "MANUAL_DOOR_EDGE_INVALID", path, "manual door edge must be an object")
			continue
		_check_exact_fields(record, MANUAL_DOOR_EDGE_FIELDS, path, diagnostics)
		var endpoint_a: Variant = record.get("endpoint_a", null)
		var endpoint_b: Variant = record.get("endpoint_b", null)
		if not _valid_floor_cell_address(endpoint_a) or not _valid_floor_cell_address(endpoint_b):
			_add(diagnostics, "MANUAL_DOOR_ENDPOINT_INVALID", path, "manual door endpoints must be exact FloorCellAddress values")
			continue
		var a: Dictionary = endpoint_a
		var b: Dictionary = endpoint_b
		var plot_id: String = String(a["runtime_plot_id"])
		var elevation: int = int(a["signed_elevation"])
		if plot_id != String(b["runtime_plot_id"]) or elevation != int(b["signed_elevation"]):
			_add(diagnostics, "MANUAL_DOOR_SCOPE_MISMATCH", path, "manual door endpoints must share Plot and elevation")
		if not plot_ids.has(plot_id):
			_add(diagnostics, "MANUAL_DOOR_PLOT_UNKNOWN", path, "manual door Plot is unknown")
		var floor_id: String = _floor_id_for_scope(floor_by_id, plot_id, elevation)
		if floor_id.is_empty():
			_add(diagnostics, "MANUAL_DOOR_FLOOR_UNKNOWN", path, "manual door floor scope must resolve exactly")
		var cell_a: Dictionary = a["local_cell"]
		var cell_b: Dictionary = b["local_cell"]
		if absi(int(cell_a["x"]) - int(cell_b["x"])) + absi(int(cell_a["y"]) - int(cell_b["y"])) != 1:
			_add(diagnostics, "MANUAL_DOOR_EDGE_INVALID", path, "manual door endpoints must be distinct and orthogonally adjacent")
		if _compare_floor_cell_addresses(a, b) >= 0:
			_add(diagnostics, "MANUAL_DOOR_EDGE_NON_CANONICAL", path, "manual door endpoint order must be canonical")
		var allowed: Dictionary = allowed_cells_by_floor.get(floor_id, {})
		if not allowed.has("%d,%d" % [int(cell_a["x"]), int(cell_a["y"])]) or not allowed.has("%d,%d" % [int(cell_b["x"]), int(cell_b["y"])]):
			_add(diagnostics, "MANUAL_DOOR_CELL_FORBIDDEN", path, "manual door endpoints must resolve in the immutable floor")
		var identity: String = _manual_door_edge_key(record)
		if index > 0 and identity <= previous_key:
			_add(diagnostics, "STATE_ORDER_INVALID", path, "manual door edges must be duplicate-free and canonically ordered")
		previous_key = identity


func _valid_floor_cell_address(value: Variant) -> bool:
	if not value is Dictionary or not _has_exact_fields(value, FLOOR_CELL_ADDRESS_FIELDS):
		return false
	var cell: Variant = value.get("local_cell", null)
	return value.get("runtime_plot_id") is String and not String(value["runtime_plot_id"]).is_empty() and value.get("signed_elevation") is int and cell is Dictionary and _has_exact_fields(cell, LOCAL_CELL_FIELDS) and cell.get("x") is int and cell.get("y") is int and int(cell["x"]) >= 0 and int(cell["y"]) >= 0


func _floor_id_for_scope(floor_by_id: Dictionary, plot_id: String, elevation: int) -> String:
	var result: String = ""
	for floor_id: String in floor_by_id:
		var floor: Dictionary = floor_by_id[floor_id]
		if String(floor.get("plot_id", "")) == plot_id and int(floor.get("elevation", 999999)) == elevation:
			if not result.is_empty():
				return ""
			result = floor_id
	return result


func _compare_floor_cell_addresses(left: Dictionary, right: Dictionary) -> int:
	var left_key: String = _floor_cell_address_key(left)
	var right_key: String = _floor_cell_address_key(right)
	return -1 if left_key < right_key else (1 if left_key > right_key else 0)


func _floor_cell_address_key(endpoint: Dictionary) -> String:
	var cell: Dictionary = endpoint.get("local_cell", {})
	return "%s|%+011d|%011d|%011d" % [String(endpoint.get("runtime_plot_id", "")), int(endpoint.get("signed_elevation", 0)), int(cell.get("y", -1)), int(cell.get("x", -1))]


func _manual_door_edge_key(record: Dictionary) -> String:
	return "%s|%s" % [_floor_cell_address_key(record.get("endpoint_a", {})), _floor_cell_address_key(record.get("endpoint_b", {}))]


func _has_exact_fields(value: Dictionary, fields: Array[String]) -> bool:
	if value.size() != fields.size():
		return false
	for field: String in fields:
		if not value.has(field):
			return false
	return true


func _validate_cells(value: Array, path: String, diagnostics: Array[Dictionary]) -> void:
	var seen: Dictionary = {}
	var previous: Array = [-1, -1]
	for index: int in range(value.size()):
		var cell: Variant = value[index]
		if not cell is Array or cell.size() != 2 or typeof(cell[0]) != TYPE_INT or typeof(cell[1]) != TYPE_INT or int(cell[0]) < 0 or int(cell[1]) < 0:
			_add(diagnostics, "STATE_CELL_INVALID", "%s[%d]" % [path, index], "state cell must be a nonnegative [x,y] integer pair")
			continue
		var normalized: Array = [int(cell[0]), int(cell[1])]
		var key: String = "%d,%d" % [normalized[0], normalized[1]]
		if seen.has(key):
			_add(diagnostics, "STATE_CELL_DUPLICATE", "%s[%d]" % [path, index], "state cell sets must be duplicate-free")
		seen[key] = true
		if index > 0 and (normalized[1] < previous[1] or (normalized[1] == previous[1] and normalized[0] <= previous[0])):
			_add(diagnostics, "STATE_CELL_ORDER_INVALID", "%s[%d]" % [path, index], "state cells must be row-major")
		previous = normalized


func _allowed_cells_by_floor(records: Array) -> Dictionary:
	var result: Dictionary = {}
	for record: Variant in records:
		if not record is Dictionary:
			continue
		var floor_id: String = String(record.get("floor_id", ""))
		if not result.has(floor_id):
			result[floor_id] = {}
		result[floor_id]["%d,%d" % [int(record.get("x", -1)), int(record.get("y", -1))]] = true
	return result


func _contains_cell(cells: Array, expected: Array) -> bool:
	for cell: Variant in cells:
		if cell is Array and cell == expected:
			return true
	return false


func _records_by_id(records: Array) -> Dictionary:
	var result: Dictionary = {}
	for record: Variant in records:
		if record is Dictionary:
			result[String(record.get("id", ""))] = record
	return result


func _records_by_authored_id(records: Array, key: String) -> Dictionary:
	var result: Dictionary = {}
	for record: Variant in records:
		if record is Dictionary:
			result[String(record.get(key, ""))] = record
	return result


func _check_exact_fields(value: Dictionary, fields: Array[String], path: String, diagnostics: Array[Dictionary]) -> void:
	for field: String in fields:
		if not value.has(field):
			_add(diagnostics, "FIELD_MISSING", "%s.%s" % [path, field], "required state field is missing")
	for field: Variant in value.keys():
		if not fields.has(String(field)):
			_add(diagnostics, "UNKNOWN_FIELD", "%s.%s" % [path, String(field)], "unknown state field is forbidden")


func _check_string(value: Dictionary, key: String, path: String, diagnostics: Array[Dictionary]) -> void:
	if value.has(key) and typeof(value[key]) != TYPE_STRING:
		_add(diagnostics, "TYPE_INVALID", "%s.%s" % [path, key], "state field must be a string")


func _check_int(value: Dictionary, key: String, path: String, diagnostics: Array[Dictionary]) -> void:
	if value.has(key) and typeof(value[key]) != TYPE_INT:
		_add(diagnostics, "TYPE_INVALID", "%s.%s" % [path, key], "state field must be an integer")


func _check_bool(value: Dictionary, key: String, path: String, diagnostics: Array[Dictionary]) -> void:
	if value.has(key) and typeof(value[key]) != TYPE_BOOL:
		_add(diagnostics, "TYPE_INVALID", "%s.%s" % [path, key], "state field must be a boolean")


func _failure(code: String, message: String) -> Dictionary:
	return {"valid": false, "state": {}, "diagnostics": [{"code": code, "path": "$", "message": message}]}


func _add(diagnostics: Array[Dictionary], code: String, path: String, message: String) -> void:
	diagnostics.append({"code": code, "path": path, "message": message})
