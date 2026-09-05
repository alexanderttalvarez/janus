class_name ConstructionAuthority
extends RefCounted

## Pure MVP construction resolver. It never writes District, Zone, Economy, or
## presentation state.

const SUPPORTED_KINDS: Array[String] = ["corridor", "stairs", "elevator", "operations_room"]


func resolve(
	intent: Dictionary,
	base_state: Dictionary,
	snapshot: ResolvedDistrictSnapshot,
	progression: Dictionary,
	policy: ConstructionPolicy
) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if snapshot == null:
		return _failure("CONSTRUCTION_SNAPSHOT_REQUIRED", "construction requires an immutable District snapshot")
	var request_id: String = String(intent.get("request_id", ""))
	if request_id.is_empty():
		return _failure("CONSTRUCTION_REQUEST_ID_REQUIRED", "construction intent requires a stable request ID")
	var kind: String = String(intent.get("construction_kind", ""))
	if not SUPPORTED_KINDS.has(kind):
		return _failure("CONSTRUCTION_TYPE_INVALID", "construction kind is not approved for MVP")
	if policy == null:
		return _failure("CONSTRUCTION_POLICY_UNAVAILABLE", "immutable construction policy is required")
	var policy_check: Dictionary = policy.validate()
	if not bool(policy_check.get("valid", false)):
		return _failure_diagnostics("CONSTRUCTION_POLICY_UNAVAILABLE", policy_check.get("diagnostics", []))
	var entry: Dictionary = policy.entry_for(kind)
	if entry.is_empty():
		return _failure("CONSTRUCTION_POLICY_UNAVAILABLE", "approved construction kind has no catalog entry")
	if not bool(entry.get("geometry_available", false)):
		return _failure("CONSTRUCTION_GEOMETRY_UNAVAILABLE", "approved construction geometry is not authored")
	if not _progression_allows(kind, progression):
		return _failure("PROGRESSION_ELIGIBILITY_REJECTED", "progression does not permit this construction kind")

	var normalized: Dictionary = _normalize_intent(intent)
	var orientation: String = String(normalized.get("connection", {}).get("orientation", "NONE"))
	if not ["NONE", "NORTH", "EAST", "SOUTH", "WEST"].has(orientation):
		return _failure("CONSTRUCTION_GEOMETRY_UNAVAILABLE", "construction orientation is not approved")
	var cells: Array[Dictionary] = normalized.get("cells", [])
	var shaft_cells: Array[Dictionary] = normalized.get("shaft_cells", [])
	var lobby_cells: Array[Dictionary] = normalized.get("lobby_cells", [])
	var all_cells: Array[Dictionary] = cells.duplicate(true)
	all_cells.append_array(shaft_cells)
	all_cells.append_array(lobby_cells)
	if kind == "elevator":
		all_cells = _unique_cells(all_cells)
	if all_cells.is_empty():
		return _failure("CONSTRUCTION_GEOMETRY_UNAVAILABLE", "construction requires explicit target cells")
	var common_result: Dictionary = _validate_cells(all_cells, base_state, snapshot)
	if not bool(common_result.get("valid", false)):
		return common_result
	var elevations: Array = progression.get("elevation_eligibility", [])
	if not bool(progression.get("god_mode", false)):
		for cell: Dictionary in all_cells:
			if not elevations.has(int(cell.get("elevation", 0))):
				return _failure("PROGRESSION_ELIGIBILITY_REJECTED", "progression does not permit the construction elevation")
	var shape_result: Dictionary = _validate_shape(kind, normalized, snapshot)
	if not bool(shape_result.get("valid", false)):
		return shape_result
	var construction_id: String = _construction_id(kind, all_cells)
	for record: Dictionary in base_state.get("construction_records", []):
		if String(record.get("construction_id", "")) == construction_id:
			return _failure("ELEMENT_CONFLICT", "the construction target is already committed")
		for occupied: Dictionary in record.get("cells", []):
			if _cell_key(occupied) in _cell_keys(all_cells):
				return _failure("CELL_ALREADY_OCCUPIED", "construction cells are occupied by another element")

	var record: Dictionary = {
		"construction_id": construction_id,
		"kind": kind,
		"plot_id": String(all_cells[0].get("plot_id", "")),
		"cells": all_cells.duplicate(true),
		"shaft_cells": shaft_cells.duplicate(true),
		"lobby_cells": lobby_cells.duplicate(true),
		"connection": normalized.get("connection", {}).duplicate(true),
	}
	var candidate: Dictionary = base_state.duplicate(true)
	_apply_cells(candidate, all_cells)
	var records: Array = candidate.get("construction_records", []).duplicate(true)
	records.append(record)
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.get("construction_id", "")) < String(right.get("construction_id", "")))
	candidate["construction_records"] = records
	candidate["construction_revision"] = int(candidate.get("construction_revision", 0)) + 1
	var lobby_count: int = lobby_cells.size()
	var lines: Array[Dictionary] = policy.charge_lines_for(kind, lobby_count)
	var delta: Dictionary = {
		"kind": "construction_committed",
		"construction_ids": [construction_id],
		"affected_ids": [construction_id],
		"affected_cells": all_cells.duplicate(true),
		"construction_kind": kind,
		"construction_revision": int(candidate.get("construction_revision", 0)),
		"construction_policy_revision": policy.get_revision(),
		"charge_lines": lines.duplicate(true),
		"operations_room_facts": [],
	}
	if kind == "operations_room":
		delta["operations_room_facts"] = [_operations_room_fact(record, candidate)]
	return {
		"valid": true,
		"state": candidate,
		"intent": _normalized_for_economy(normalized, policy, lines),
		"delta": delta,
		"construction_preview": {
			"construction_id": construction_id,
			"kind": kind,
			"cells": all_cells.duplicate(true),
			"charge_lines": lines.duplicate(true),
			"policy_revision": policy.get_revision(),
		},
		"diagnostics": [],
	}


func _normalize_intent(intent: Dictionary) -> Dictionary:
	var kind: String = String(intent.get("construction_kind", ""))
	var normalized: Dictionary = intent.duplicate(true)
	var cells: Array[Dictionary] = _normalize_cells(intent.get("cells", []), String(intent.get("floor_id", "")), int(intent.get("elevation", 0)), String(intent.get("runtime_plot_id", "")))
	var shaft_cells: Array[Dictionary] = _normalize_cells(intent.get("shaft_cells", []), "", 0, String(intent.get("runtime_plot_id", "")))
	var lobby_cells: Array[Dictionary] = _normalize_cells(intent.get("lobby_cells", []), "", 0, String(intent.get("runtime_plot_id", "")))
	if kind == "elevator":
		cells = []
	cells.sort_custom(_cell_less)
	shaft_cells.sort_custom(_cell_less)
	lobby_cells.sort_custom(_cell_less)
	normalized["cells"] = cells
	normalized["shaft_cells"] = shaft_cells
	normalized["lobby_cells"] = lobby_cells
	normalized["connection"] = {
		"orientation": String(intent.get("orientation", "NONE")),
		"stop_elevations": _elevations(shaft_cells if kind == "elevator" else cells),
	}
	return normalized


func _normalized_for_economy(intent: Dictionary, policy: ConstructionPolicy, lines: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = intent.duplicate(true)
	result["charge_category"] = "CONSTRUCTION_%s" % String(intent.get("construction_kind", "")).to_upper()
	result["construction_policy_snapshot"] = policy.duplicate_value()
	result["construction_policy_revision"] = policy.get_revision()
	result["construction_charge_lines"] = lines.duplicate(true)
	result["tile_count"] = int(intent.get("cells", []).size())
	return result


func _validate_shape(kind: String, intent: Dictionary, snapshot: ResolvedDistrictSnapshot) -> Dictionary:
	if kind == "corridor":
		return _valid() if intent.get("cells", []).size() == 1 else _failure("CONSTRUCTION_GEOMETRY_UNAVAILABLE", "corridors occupy exactly one tile")
	if kind == "stairs":
		var cells: Array[Dictionary] = intent.get("cells", [])
		if cells.size() != 8:
			return _failure("CONSTRUCTION_GEOMETRY_UNAVAILABLE", "stairs require an approved 2x2 footprint on two floors")
		var by_floor: Dictionary = {}
		for cell: Dictionary in cells:
			var floor_id: String = String(cell.get("floor_id", ""))
			if not by_floor.has(floor_id):
				by_floor[floor_id] = []
			by_floor[floor_id].append(cell)
		if by_floor.size() != 2:
			return _failure("CONSTRUCTION_GEOMETRY_UNAVAILABLE", "stairs require exactly two floors")
		var floor_ids: Array = by_floor.keys()
		var first: Dictionary = _floor(snapshot, String(floor_ids[0]))
		var second: Dictionary = _floor(snapshot, String(floor_ids[1]))
		if absi(int(first.get("elevation", 999)) - int(second.get("elevation", -999))) != 1:
			return _failure("CONSTRUCTION_GEOMETRY_UNAVAILABLE", "stairs connect only adjacent floors")
		for floor_id: String in floor_ids:
			if not _is_two_by_two(by_floor[floor_id]):
				return _failure("CONSTRUCTION_GEOMETRY_UNAVAILABLE", "stairs require contiguous 2x2 footprints")
		var first_footprint: Dictionary = _cell_keys_by_xy(by_floor[String(floor_ids[0])])
		for floor_id: String in floor_ids.slice(1):
			if _cell_keys_by_xy(by_floor[floor_id]) != first_footprint:
				return _failure("CONSTRUCTION_GEOMETRY_UNAVAILABLE", "stairs require the same footprint on both floors")
		return _valid()
	if kind == "elevator":
		var shaft: Array[Dictionary] = intent.get("shaft_cells", [])
		var lobby: Array[Dictionary] = intent.get("lobby_cells", [])
		if shaft.is_empty() or shaft.size() != lobby.size():
			return _failure("CONSTRUCTION_GEOMETRY_UNAVAILABLE", "elevators require one shaft and lobby per stop")
		var stop_elevations: Array[int] = _elevations(shaft)
		if not stop_elevations.has(0):
			return _failure("CONSTRUCTION_GEOMETRY_UNAVAILABLE", "elevator stops must include ground")
		for index: int in range(shaft.size()):
			if int(shaft[index].get("x", -1)) != int(shaft[0].get("x", -2)) or int(shaft[index].get("y", -1)) != int(shaft[0].get("y", -2)):
				return _failure("CONSTRUCTION_GEOMETRY_UNAVAILABLE", "elevator shaft must remain one local cell")
			if String(shaft[index].get("floor_id", "")) == String(lobby[index].get("floor_id", "")) and (int(shaft[index].get("x", -1)) == int(lobby[index].get("x", -2)) and int(shaft[index].get("y", -1)) == int(lobby[index].get("y", -2))):
				return _failure("ELEMENT_CONFLICT", "elevator lobby cannot overlap its shaft cell")
		for index: int in range(1, stop_elevations.size()):
			if stop_elevations[index] != stop_elevations[index - 1] + 1:
				return _failure("CONSTRUCTION_GEOMETRY_UNAVAILABLE", "elevator stops must be contiguous")
		return _valid()
	if kind == "operations_room":
		return _failure("CONSTRUCTION_GEOMETRY_UNAVAILABLE", "Operations Room footprint content is unresolved")
	return _failure("CONSTRUCTION_TYPE_INVALID", "unsupported construction kind")


func _validate_cells(cells: Array[Dictionary], state: Dictionary, snapshot: ResolvedDistrictSnapshot) -> Dictionary:
	var seen: Dictionary = {}
	var data: Dictionary = snapshot.get_data()
	var floor_by_id: Dictionary = {}
	for floor: Dictionary in data.get("floors", []):
		floor_by_id[String(floor.get("id", ""))] = floor
	for cell: Dictionary in cells:
		var floor_id: String = String(cell.get("floor_id", ""))
		var key: String = _cell_key(cell)
		if floor_id.is_empty() or not floor_by_id.has(floor_id):
			return _failure("VERTICAL_SPACE_UNAVAILABLE", "construction requires an explicit known FloorAddress")
		if seen.has(key):
			return _failure("CELL_ALREADY_OCCUPIED", "construction target cells must be unique")
		seen[key] = true
		var floor: Dictionary = floor_by_id[floor_id]
		var requested_plot_id: String = String(cell.get("plot_id", ""))
		if not requested_plot_id.is_empty() and requested_plot_id != String(floor.get("plot_id", "")):
			return _failure("CELL_NOT_OWNED", "construction cell plot does not match its immutable FloorAddress")
		if int(cell.get("elevation", 999)) != int(floor.get("elevation", -999)):
			return _failure("VERTICAL_SPACE_UNAVAILABLE", "cell elevation does not match its FloorAddress")
		if not _immutable_buildable(floor_id, int(cell.get("x", -1)), int(cell.get("y", -1)), data):
			return _failure("CELL_NOT_BUILDABLE", "construction cell is outside immutable buildability")
		if not _is_plot_active(state, String(floor.get("plot_id", "")), data):
			return _failure("CELL_NOT_OWNED", "construction requires an owned Active Plot")
		var floor_state: Dictionary = _floor_state(state, floor_id, int(floor.get("elevation", 0)))
		var pair: Array = [int(cell.get("x", -1)), int(cell.get("y", -1))]
		if not _contains_cell(floor_state.get("acquired_cells", []), pair):
			return _failure("VERTICAL_SPACE_UNAVAILABLE", "construction requires acquired vertical space")
		if _contains_cell(floor_state.get("constructed_cells", []), pair):
			return _failure("CELL_ALREADY_OCCUPIED", "construction cell is already occupied")
		if _fixed_occupies(floor_id, pair, data):
			return _failure("ELEMENT_CONFLICT", "construction conflicts with fixed occupancy")
	return _valid()


func _progression_allows(kind: String, progression: Dictionary) -> bool:
	if progression.is_empty():
		return false
	if bool(progression.get("god_mode", false)):
		return true
	var elevations: Array = progression.get("elevation_eligibility", [])
	var capabilities: Array = progression.get("construction_capabilities", [])
	if capabilities.is_empty():
		var unlocked: Array = progression.get("unlocked_node_ids", [])
		if unlocked.has("basic_corridors"):
			capabilities.append("corridor")
		if unlocked.has("stairs"):
			capabilities.append("stairs")
		if unlocked.has("elevator_1"):
			capabilities.append("elevator")
	if kind != "operations_room" and not capabilities.has(kind):
		return false
	return not elevations.is_empty()


func _immutable_buildable(floor_id: String, x: int, y: int, data: Dictionary) -> bool:
	for cell: Dictionary in data.get("cells", []):
		if String(cell.get("floor_id", "")) == floor_id and int(cell.get("x", -1)) == x and int(cell.get("y", -1)) == y:
			return bool(cell.get("buildable", true))
	return false


func _fixed_occupies(floor_id: String, pair: Array, data: Dictionary) -> bool:
	for occupant: Dictionary in data.get("fixed_occupants", []):
		for cell: Variant in occupant.get("cells", []):
			if cell is Dictionary and String(cell.get("floor_id", "")) == floor_id and int(cell.get("x", -1)) == int(pair[0]) and int(cell.get("y", -1)) == int(pair[1]):
				return true
			if cell is Array and cell.size() >= 2 and int(cell[0]) == int(pair[0]) and int(cell[1]) == int(pair[1]) and String(occupant.get("floor_id", "")) == floor_id:
				return true
	return false


func _is_plot_active(state: Dictionary, plot_id: String, data: Dictionary) -> bool:
	for section: Dictionary in data.get("sections", []):
		if String(section.get("plot_id", "")) != plot_id:
			continue
		if bool(section.get("initially_owned", false)):
			return true
	for plot_state: Dictionary in state.get("plot_states", []):
		if String(plot_state.get("runtime_plot_id", "")) != plot_id:
			continue
		for override: Dictionary in plot_state.get("section_state_overrides", []):
			if bool(override.get("owned", false)):
				return true
	return false


func _apply_cells(state: Dictionary, cells: Array[Dictionary]) -> void:
	for cell: Dictionary in cells:
		var floor_id: String = String(cell.get("floor_id", ""))
		var floor_state: Dictionary = _floor_state(state, floor_id, int(cell.get("elevation", 0)))
		floor_state["constructed_cells"].append([int(cell.get("x", 0)), int(cell.get("y", 0))])
		floor_state["constructed_cells"] = _sort_cells(floor_state["constructed_cells"])
		_upsert_floor_state(state, String(cell.get("plot_id", "")), floor_state)


func _floor_state(state: Dictionary, floor_id: String, elevation: int) -> Dictionary:
	for plot_state: Dictionary in state.get("plot_states", []):
		for floor_state: Dictionary in plot_state.get("floor_states", []):
			if String(floor_state.get("floor_id", "")) == floor_id:
				return floor_state
	return {"floor_id": floor_id, "elevation": elevation, "acquired_cells": [], "constructed_cells": []}


func _upsert_floor_state(state: Dictionary, plot_id: String, floor_state: Dictionary) -> void:
	for plot_state: Dictionary in state.get("plot_states", []):
		if String(plot_state.get("runtime_plot_id", "")) != plot_id:
			continue
		for index: int in range(plot_state.get("floor_states", []).size()):
			if String(plot_state["floor_states"][index].get("floor_id", "")) == String(floor_state.get("floor_id", "")):
				plot_state["floor_states"][index] = floor_state
				return
		plot_state["floor_states"].append(floor_state)
		return
	state["plot_states"].append({"runtime_plot_id": plot_id, "section_state_overrides": [], "floor_states": [floor_state]})


func _operations_room_fact(record: Dictionary, state: Dictionary) -> Dictionary:
	return {
		"operations_room_id": String(record.get("construction_id", "")),
		"building_id": String(record.get("plot_id", "")),
		"floor_id": String(record.get("cells", [{}])[0].get("floor_id", "")),
		"construction_revision": int(state.get("construction_revision", 0)),
		"committed_valid_for_staffing": true,
	}


func _construction_id(kind: String, cells: Array[Dictionary]) -> String:
	var parts: Array[String] = [kind]
	for cell: Dictionary in cells:
		parts.append("%s:%d:%d:%d" % [String(cell.get("floor_id", "")), int(cell.get("elevation", 0)), int(cell.get("x", 0)), int(cell.get("y", 0))])
	return "construction/%s" % ":".join(parts)


func _normalize_cells(values: Variant, default_floor_id: String, default_elevation: int, plot_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not values is Array:
		return result
	for value: Variant in values:
		var cell: Dictionary = {}
		if value is Dictionary:
			cell = value.duplicate(true)
		elif value is Array and value.size() >= 2:
			cell = {"x": int(value[0]), "y": int(value[1])}
		if cell.is_empty():
			continue
		cell["floor_id"] = String(cell.get("floor_id", default_floor_id))
		cell["elevation"] = int(cell.get("elevation", default_elevation))
		cell["plot_id"] = String(cell.get("plot_id", plot_id))
		cell["x"] = int(cell.get("x", -1))
		cell["y"] = int(cell.get("y", -1))
		result.append(cell)
	return result


func _floor(snapshot: ResolvedDistrictSnapshot, floor_id: String) -> Dictionary:
	for floor: Dictionary in snapshot.get_data().get("floors", []):
		if String(floor.get("id", "")) == floor_id:
			return floor
	return {}


func _elevations(cells: Array[Dictionary]) -> Array[int]:
	var result: Array[int] = []
	for cell: Dictionary in cells:
		var elevation: int = int(cell.get("elevation", 0))
		if not result.has(elevation):
			result.append(elevation)
	result.sort()
	return result


func _is_two_by_two(cells: Array) -> bool:
	if cells.size() != 4:
		return false
	var min_x: int = 999999
	var min_y: int = 999999
	var keys: Dictionary = {}
	for cell: Dictionary in cells:
		min_x = mini(min_x, int(cell.get("x", -1)))
		min_y = mini(min_y, int(cell.get("y", -1)))
		keys["%d,%d" % [int(cell.get("x", -1)), int(cell.get("y", -1))]] = true
	for y: int in range(min_y, min_y + 2):
		for x: int in range(min_x, min_x + 2):
			if not keys.has("%d,%d" % [x, y]):
				return false
	return true


func _cell_keys_by_xy(cells: Array) -> Dictionary:
	var result: Dictionary = {}
	for cell: Dictionary in cells:
		result["%d,%d" % [int(cell.get("x", -1)), int(cell.get("y", -1))]] = true
	return result


func _unique_cells(cells: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for cell: Dictionary in cells:
		if seen.has(_cell_key(cell)):
			continue
		seen[_cell_key(cell)] = true
		result.append(cell)
	return result


func _cell_keys(cells: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for cell: Dictionary in cells:
		result[_cell_key(cell)] = true
	return result


func _cell_key(cell: Dictionary) -> String:
	return "%s:%d:%d:%d" % [String(cell.get("floor_id", "")), int(cell.get("elevation", 0)), int(cell.get("x", 0)), int(cell.get("y", 0))]


func _cell_less(left: Dictionary, right: Dictionary) -> bool:
	return _cell_key(left) < _cell_key(right)


func _sort_cells(cells: Array) -> Array:
	var result: Array = cells.duplicate(true)
	result.sort_custom(func(left: Array, right: Array) -> bool: return int(left[1]) < int(right[1]) or (int(left[1]) == int(right[1]) and int(left[0]) < int(right[0])))
	return result


func _contains_cell(cells: Array, expected: Array) -> bool:
	for cell: Variant in cells:
		if cell is Array and cell.size() == 2 and int(cell[0]) == int(expected[0]) and int(cell[1]) == int(expected[1]):
			return true
	return false


func _valid() -> Dictionary:
	return {"valid": true, "diagnostics": []}


func _failure(code: String, message: String) -> Dictionary:
	return {"valid": false, "diagnostics": [{"code": code, "message": message}]}


func _failure_diagnostics(code: String, values: Array) -> Dictionary:
	var diagnostics: Array[Dictionary] = [{"code": code, "message": "construction policy validation failed"}]
	for value: Variant in values:
		if value is Dictionary:
			diagnostics.append(value.duplicate(true))
	return {"valid": false, "diagnostics": diagnostics}
