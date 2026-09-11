## DistrictZoneSpatialSnapshot — Immutable, transient floor-scoped ADR 36 value.
class_name DistrictZoneSpatialSnapshot
extends RefCounted

const SCHEMA_ID: String = "district_zone_spatial_snapshot"
const SCHEMA_VERSION: int = 1
const _ROOT_KEYS: Array[String] = ["schema_id", "schema_version", "layout_ref", "district_revision", "floor_scope", "valid_cells", "acquired_cells", "constructed_cells", "zone_eligible_cells", "explicit_circulation_cells", "manual_door_edges"]
const _LAYOUT_KEYS: Array[String] = ["layout_id", "layout_definition_version", "definition_fingerprint"]
const _SCOPE_KEYS: Array[String] = ["floor_id", "runtime_plot_id", "signed_elevation"]
const _CELL_KEYS: Array[String] = ["x", "y"]
const _EDGE_KEYS: Array[String] = ["endpoint_a", "endpoint_b"]
const _ENDPOINT_KEYS: Array[String] = ["runtime_plot_id", "signed_elevation", "local_cell"]

var _value: Dictionary = {}
var _indexes: Dictionary = {}


func configure(value: Dictionary) -> Dictionary:
	var validation: Dictionary = validate_value(value)
	if not bool(validation.get("valid", false)):
		return validation
	_value = value.duplicate(true)
	_rebuild_indexes()
	return {"valid": true, "diagnostics": []}


func duplicate_value() -> Dictionary:
	return _value.duplicate(true)


func duplicate_snapshot() -> DistrictZoneSpatialSnapshot:
	var copy := DistrictZoneSpatialSnapshot.new()
	copy.configure(duplicate_value())
	return copy


func get_layout_ref() -> Dictionary:
	return _value.get("layout_ref", {}).duplicate(true)


func get_district_revision() -> int:
	return int(_value.get("district_revision", -1))


func get_floor_scope() -> Dictionary:
	return _value.get("floor_scope", {}).duplicate(true)


func get_cells(collection_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell: Dictionary in _value.get(collection_name, []):
		result.append(cell.duplicate(true))
	return result


func get_manual_door_edges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for edge: Dictionary in _value.get("manual_door_edges", []):
		result.append(edge.duplicate(true))
	return result


func has_cell(collection_name: String, cell: Vector2i) -> bool:
	return _indexes.get(collection_name, {}).has(_cell_key(cell.x, cell.y))


static func derive(snapshot: ResolvedDistrictSnapshot, state: Dictionary, floor_scope: Dictionary) -> Dictionary:
	if snapshot == null or state.is_empty():
		return _failure("DISTRICT_ZONE_SPATIAL_UNAVAILABLE")
	var state_validation: Dictionary = DistrictStateRecords.new().validate(state, snapshot)
	if not bool(state_validation.get("valid", false)):
		return _failure("INVALID_DISTRICT_ZONE_SPATIAL_SNAPSHOT", state_validation.get("diagnostics", []))
	var data: Dictionary = snapshot.get_data()
	if String(state.get("layout_id", "")) != snapshot.get_layout_id() or int(state.get("layout_definition_version", -1)) != int(data.get("layout_definition_version", -2)) or String(state.get("definition_fingerprint", "")) != snapshot.get_fingerprint():
		return _failure("DISTRICT_ZONE_SPATIAL_STALE")
	if not _has_exact_keys(floor_scope, _SCOPE_KEYS) or not floor_scope.get("floor_id") is String or not floor_scope.get("runtime_plot_id") is String or not floor_scope.get("signed_elevation") is int:
		return _failure("DISTRICT_ZONE_SPATIAL_SCOPE_MISMATCH")
	var floor_id: String = String(floor_scope["floor_id"])
	var plot_id: String = String(floor_scope["runtime_plot_id"])
	var elevation: int = int(floor_scope["signed_elevation"])
	var floor: Dictionary = _resolved_floor(data, floor_id, plot_id, elevation)
	var plot: Dictionary = _record_by_id(data.get("plots", []), plot_id)
	if floor.is_empty() or plot.is_empty():
		return _failure("DISTRICT_ZONE_SPATIAL_SCOPE_MISMATCH")
	var valid_cells: Array[Dictionary] = []
	var buildable: Dictionary = {}
	for cell: Dictionary in data.get("cells", []):
		if String(cell.get("floor_id", "")) != floor_id:
			continue
		var x: int = int(cell.get("x", -1))
		var y: int = int(cell.get("y", -1))
		valid_cells.append({"x": x, "y": y})
		if bool(cell.get("buildable", true)):
			buildable[_cell_key(x, y)] = true
	var floor_state: Dictionary = _floor_state(state, plot_id, floor_id)
	var acquired_cells: Array[Dictionary] = _cell_records(floor_state.get("acquired_cells", []))
	var constructed_cells: Array[Dictionary] = _cell_records(floor_state.get("constructed_cells", []))
	var circulation_cells: Array[Dictionary] = _cell_records(floor_state.get("explicit_circulation_cells", []))
	var zone_eligible_cells: Array[Dictionary] = []
	var cap: Dictionary = plot.get("physical_elevation_cap", {})
	var elevation_eligible: bool = elevation >= int(cap.get("minimum_elevation", elevation)) and elevation <= int(cap.get("maximum_elevation", elevation))
	var active_occupancy: Dictionary = _active_fixed_occupancy(data, state, plot, elevation)
	for cell: Dictionary in constructed_cells:
		var position := Vector2i(int(cell["x"]), int(cell["y"]))
		if elevation_eligible and buildable.has(_cell_key(position.x, position.y)) and _cell_has_owned_available_section(position, plot_id, data, state) and not active_occupancy.has(_cell_key(position.x, position.y)):
			zone_eligible_cells.append(cell.duplicate(true))
	var manual_edges: Array[Dictionary] = []
	for edge: Dictionary in state.get("manual_door_edges", []):
		var endpoint: Dictionary = edge.get("endpoint_a", {})
		if String(endpoint.get("runtime_plot_id", "")) == plot_id and int(endpoint.get("signed_elevation", 999999)) == elevation:
			manual_edges.append(edge.duplicate(true))
	var value: Dictionary = {
		"schema_id": SCHEMA_ID,
		"schema_version": SCHEMA_VERSION,
		"layout_ref": {"layout_id": snapshot.get_layout_id(), "layout_definition_version": int(data.get("layout_definition_version", -1)), "definition_fingerprint": snapshot.get_fingerprint()},
		"district_revision": int(state.get("district_revision", -1)),
		"floor_scope": floor_scope.duplicate(true),
		"valid_cells": _sort_cells(valid_cells),
		"acquired_cells": _sort_cells(acquired_cells),
		"constructed_cells": _sort_cells(constructed_cells),
		"zone_eligible_cells": _sort_cells(zone_eligible_cells),
		"explicit_circulation_cells": _sort_cells(circulation_cells),
		"manual_door_edges": manual_edges,
	}
	var validation: Dictionary = validate_value(value)
	if not bool(validation.get("valid", false)):
		return validation
	var result := DistrictZoneSpatialSnapshot.new()
	result.configure(value)
	return {"valid": true, "snapshot": result, "diagnostics": []}


static func validate_value(value: Dictionary) -> Dictionary:
	if not _has_exact_keys(value, _ROOT_KEYS) or value.get("schema_id") != SCHEMA_ID or not value.get("schema_version") is int or int(value["schema_version"]) != SCHEMA_VERSION:
		return _failure("INVALID_DISTRICT_ZONE_SPATIAL_SNAPSHOT")
	if not value.get("district_revision") is int or int(value["district_revision"]) < 0:
		return _failure("INVALID_DISTRICT_ZONE_SPATIAL_SNAPSHOT")
	var layout: Variant = value.get("layout_ref", null)
	if not layout is Dictionary or not _has_exact_keys(layout, _LAYOUT_KEYS) or not layout.get("layout_id") is String or String(layout["layout_id"]).is_empty() or not layout.get("layout_definition_version") is int:
		return _failure("INVALID_DISTRICT_ZONE_SPATIAL_SNAPSHOT")
	var fingerprint: String = String(layout.get("definition_fingerprint", ""))
	if fingerprint.length() != 64 or fingerprint != fingerprint.to_lower() or not fingerprint.is_valid_hex_number(false):
		return _failure("INVALID_DISTRICT_ZONE_SPATIAL_SNAPSHOT")
	var scope: Variant = value.get("floor_scope", null)
	if not scope is Dictionary or not _has_exact_keys(scope, _SCOPE_KEYS) or not scope.get("floor_id") is String or String(scope["floor_id"]).is_empty() or not scope.get("runtime_plot_id") is String or String(scope["runtime_plot_id"]).is_empty() or not scope.get("signed_elevation") is int:
		return _failure("INVALID_DISTRICT_ZONE_SPATIAL_SNAPSHOT")
	var indexes: Dictionary = {}
	for field: String in ["valid_cells", "acquired_cells", "constructed_cells", "zone_eligible_cells", "explicit_circulation_cells"]:
		var validation: Dictionary = _validate_cell_array(value.get(field), field)
		if not bool(validation.get("valid", false)):
			return validation
		indexes[field] = validation["index"]
	if not _is_subset(indexes["acquired_cells"], indexes["valid_cells"]) or not _is_subset(indexes["constructed_cells"], indexes["acquired_cells"]) or not _is_subset(indexes["zone_eligible_cells"], indexes["constructed_cells"]) or not _is_subset(indexes["explicit_circulation_cells"], indexes["constructed_cells"]) or not _is_subset(indexes["explicit_circulation_cells"], indexes["zone_eligible_cells"]):
		return _failure("INVALID_DISTRICT_ZONE_SPATIAL_SNAPSHOT")
	if not value.get("manual_door_edges") is Array:
		return _failure("INVALID_DISTRICT_ZONE_SPATIAL_SNAPSHOT")
	var previous_edge: String = ""
	for edge_value: Variant in value["manual_door_edges"]:
		if not edge_value is Dictionary or not _has_exact_keys(edge_value, _EDGE_KEYS):
			return _failure("INVALID_DISTRICT_ZONE_SPATIAL_SNAPSHOT")
		var a: Variant = edge_value.get("endpoint_a")
		var b: Variant = edge_value.get("endpoint_b")
		if not _valid_endpoint(a, scope) or not _valid_endpoint(b, scope):
			return _failure("INVALID_DISTRICT_ZONE_SPATIAL_SNAPSHOT")
		var a_cell: Dictionary = a["local_cell"]
		var b_cell: Dictionary = b["local_cell"]
		if absi(int(a_cell["x"]) - int(b_cell["x"])) + absi(int(a_cell["y"]) - int(b_cell["y"])) != 1:
			return _failure("INVALID_DISTRICT_ZONE_SPATIAL_SNAPSHOT")
		var edge_key: String = "%s|%s" % [_endpoint_key(a), _endpoint_key(b)]
		if _endpoint_key(a) >= _endpoint_key(b) or (not previous_edge.is_empty() and edge_key <= previous_edge):
			return _failure("INVALID_DISTRICT_ZONE_SPATIAL_SNAPSHOT")
		previous_edge = edge_key
	return {"valid": true, "diagnostics": []}


func _rebuild_indexes() -> void:
	_indexes.clear()
	for field: String in ["valid_cells", "acquired_cells", "constructed_cells", "zone_eligible_cells", "explicit_circulation_cells"]:
		var index: Dictionary = {}
		for cell: Dictionary in _value.get(field, []):
			index[_cell_key(int(cell["x"]), int(cell["y"]))] = true
		_indexes[field] = index


static func _validate_cell_array(value: Variant, _field: String) -> Dictionary:
	if not value is Array:
		return _failure("INVALID_DISTRICT_ZONE_SPATIAL_SNAPSHOT")
	var index: Dictionary = {}
	var previous := Vector2i(-1, -1)
	for cell_value: Variant in value:
		if not cell_value is Dictionary or not _has_exact_keys(cell_value, _CELL_KEYS) or not cell_value.get("x") is int or not cell_value.get("y") is int:
			return _failure("INVALID_DISTRICT_ZONE_SPATIAL_SNAPSHOT")
		var cell := Vector2i(int(cell_value["x"]), int(cell_value["y"]))
		var key: String = _cell_key(cell.x, cell.y)
		if index.has(key) or (previous != Vector2i(-1, -1) and (cell.y < previous.y or (cell.y == previous.y and cell.x <= previous.x))):
			return _failure("INVALID_DISTRICT_ZONE_SPATIAL_SNAPSHOT")
		index[key] = true
		previous = cell
	return {"valid": true, "index": index, "diagnostics": []}


static func _valid_endpoint(value: Variant, scope: Dictionary) -> bool:
	if not value is Dictionary or not _has_exact_keys(value, _ENDPOINT_KEYS) or not value.get("runtime_plot_id") is String or not value.get("signed_elevation") is int or not value.get("local_cell") is Dictionary:
		return false
	var cell: Dictionary = value["local_cell"]
	return _has_exact_keys(cell, _CELL_KEYS) and cell.get("x") is int and cell.get("y") is int and String(value["runtime_plot_id"]) == String(scope["runtime_plot_id"]) and int(value["signed_elevation"]) == int(scope["signed_elevation"])


static func _is_subset(candidate: Dictionary, parent: Dictionary) -> bool:
	for key: String in candidate:
		if not parent.has(key):
			return false
	return true


static func _resolved_floor(data: Dictionary, floor_id: String, plot_id: String, elevation: int) -> Dictionary:
	var result: Dictionary = {}
	for floor: Dictionary in data.get("floors", []):
		if String(floor.get("id", "")) == floor_id and String(floor.get("plot_id", "")) == plot_id and int(floor.get("elevation", 999999)) == elevation:
			if not result.is_empty():
				return {}
			result = floor
	return result


static func _record_by_id(records: Array, identity: String) -> Dictionary:
	for record: Dictionary in records:
		if String(record.get("id", "")) == identity:
			return record
	return {}


static func _floor_state(state: Dictionary, plot_id: String, floor_id: String) -> Dictionary:
	for plot_state: Dictionary in state.get("plot_states", []):
		if String(plot_state.get("runtime_plot_id", "")) != plot_id:
			continue
		for floor_state: Dictionary in plot_state.get("floor_states", []):
			if String(floor_state.get("floor_id", "")) == floor_id:
				return floor_state
	return {}


static func _cell_records(values: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pair: Array in values:
		result.append({"x": int(pair[0]), "y": int(pair[1])})
	return result


static func _cell_has_owned_available_section(cell: Vector2i, plot_id: String, data: Dictionary, state: Dictionary) -> bool:
	for section: Dictionary in data.get("sections", []):
		if String(section.get("plot_id", "")) != plot_id or not _mask_has(section.get("mask", []), cell):
			continue
		var owned: bool = bool(section.get("initially_owned", false))
		var available: bool = bool(section.get("initially_available", false))
		for plot_state: Dictionary in state.get("plot_states", []):
			if String(plot_state.get("runtime_plot_id", "")) != plot_id:
				continue
			for override: Dictionary in plot_state.get("section_state_overrides", []):
				if String(override.get("runtime_section_id", "")) == String(section.get("id", "")):
					owned = bool(override.get("owned", owned))
					available = bool(override.get("available", available))
		return owned and available
	return false


static func _active_fixed_occupancy(data: Dictionary, state: Dictionary, plot: Dictionary, elevation: int) -> Dictionary:
	var occupied: Dictionary = {}
	var demolished: Array = state.get("demolished_fixed_occupant_ids", [])
	for occupant: Dictionary in data.get("fixed_occupants", []):
		if demolished.has(String(occupant.get("id", ""))) or String(occupant.get("runtime_slot_id", "")) != String(plot.get("slot_id", "")):
			continue
		for elevation_mask: Dictionary in occupant.get("elevation_masks", []):
			if int(elevation_mask.get("elevation", 999999)) != elevation:
				continue
			for pair: Array in elevation_mask.get("mask", []):
				occupied[_cell_key(int(pair[0]), int(pair[1]))] = true
	return occupied


static func _mask_has(mask: Array, cell: Vector2i) -> bool:
	for pair: Array in mask:
		if int(pair[0]) == cell.x and int(pair[1]) == cell.y:
			return true
	return false


static func _sort_cells(cells: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = cells.duplicate(true)
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left["y"]) < int(right["y"]) or (int(left["y"]) == int(right["y"]) and int(left["x"]) < int(right["x"])))
	return result


static func _endpoint_key(endpoint: Dictionary) -> String:
	var cell: Dictionary = endpoint.get("local_cell", {})
	return "%s|%+011d|%011d|%011d" % [String(endpoint.get("runtime_plot_id", "")), int(endpoint.get("signed_elevation", 0)), int(cell.get("y", -1)), int(cell.get("x", -1))]


static func _cell_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


static func _has_exact_keys(value: Dictionary, keys: Array[String]) -> bool:
	if value.size() != keys.size():
		return false
	for key: String in keys:
		if not value.has(key):
			return false
	return true


static func _failure(code: String, nested: Array = []) -> Dictionary:
	var diagnostics: Array = [{"code": code}]
	diagnostics.append_array(nested)
	return {"valid": false, "diagnostics": diagnostics}
