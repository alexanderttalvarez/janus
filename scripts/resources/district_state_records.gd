class_name DistrictStateRecords
extends RefCounted

## H2 closed sparse authority-state validator. H3 owns lifecycle and mutation.

const STATE_SCHEMA_VERSION: int = 2
const DISTRICT_FIELDS: Array[String] = ["state_schema_version", "district_revision", "layout_id", "layout_definition_version", "definition_fingerprint", "plot_states", "street_segment_states", "arrival_source_states", "demolished_fixed_occupant_ids"]
const PLOT_FIELDS: Array[String] = ["runtime_plot_id", "section_state_overrides", "floor_states"]
const SECTION_FIELDS: Array[String] = ["runtime_section_id", "owned", "available"]
const FLOOR_FIELDS: Array[String] = ["floor_id", "elevation", "acquired_cells", "constructed_cells"]
const STREET_FIELDS: Array[String] = ["street_segment_id", "converted"]
const SOURCE_FIELDS: Array[String] = ["arrival_source_id", "enabled"]


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
	}


func validate(state: Variant, snapshot: ResolvedDistrictSnapshot) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if not state is Dictionary:
		return _failure("STATE_NOT_OBJECT", "state must be an object")
	var value: Dictionary = state
	_check_exact_fields(value, DISTRICT_FIELDS, "$", diagnostics)
	_check_int(value, "state_schema_version", "$", diagnostics)
	_check_int(value, "district_revision", "$", diagnostics)
	if int(value.get("state_schema_version", -1)) != STATE_SCHEMA_VERSION:
		_add(diagnostics, "STATE_SCHEMA_VERSION_INVALID", "$.state_schema_version", "state schema version must be 2")
	if int(value.get("district_revision", -1)) < 0:
		_add(diagnostics, "DISTRICT_REVISION_INVALID", "$.district_revision", "district revision must be nonnegative")
	if String(value.get("layout_id", "")) != snapshot.get_layout_id():
		_add(diagnostics, "LAYOUT_ID_MISMATCH", "$.layout_id", "state layout ID must match the snapshot")
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
		if not acquired is Array or not constructed is Array:
			_add(diagnostics, "CELL_SET_INVALID", child_path, "floor cell sets must be arrays")
			continue
		if acquired.is_empty() and constructed.is_empty():
			_add(diagnostics, "EMPTY_FLOOR_STATE", child_path, "empty floor state records are forbidden")
		_validate_cells(acquired, "%s.acquired_cells" % child_path, diagnostics)
		_validate_cells(constructed, "%s.constructed_cells" % child_path, diagnostics)
		var allowed_cells: Dictionary = allowed_cells_by_floor.get(floor_id, {})
		for cell: Array in acquired:
			if not allowed_cells.has("%d,%d" % [int(cell[0]), int(cell[1])]):
				_add(diagnostics, "ACQUIRED_CELL_FORBIDDEN", child_path, "acquired cells must satisfy immutable definition rights")
		for cell: Array in constructed:
			if not _contains_cell(acquired, cell):
				_add(diagnostics, "CONSTRUCTION_WITHOUT_ACQUISITION", child_path, "constructed cells must be acquired")


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
