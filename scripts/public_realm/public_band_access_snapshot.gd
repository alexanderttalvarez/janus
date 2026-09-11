## PublicBandAccessSnapshot — Immutable, transient H5 public-band access authority.
class_name PublicBandAccessSnapshot
extends RefCounted

const SCHEMA_ID: String = "public_band_access_snapshot"
const SCHEMA_VERSION: int = 1
const _ROOT_KEYS: Array[String] = ["schema_id", "schema_version", "layout_ref", "district_revision", "access_edges"]
const _LAYOUT_KEYS: Array[String] = ["layout_id", "layout_definition_version", "definition_fingerprint"]
const _EDGE_KEYS: Array[String] = ["access_edge_id", "parcel_endpoint", "outward_direction", "pedestrian_band_id"]
const _ENDPOINT_KEYS: Array[String] = ["runtime_plot_id", "signed_elevation", "local_cell"]
const _CELL_KEYS: Array[String] = ["x", "y"]
const _DIRECTIONS: Array[String] = ["NORTH", "EAST", "SOUTH", "WEST"]

var layout_ref: Dictionary = {}
var district_revision: int = -1
var access_edges: Array[Dictionary] = []


func configure(value: Dictionary) -> Dictionary:
	var validation: Dictionary = validate_value(value)
	if not bool(validation.get("valid", false)):
		return validation
	layout_ref = value["layout_ref"].duplicate(true)
	district_revision = int(value["district_revision"])
	access_edges.clear()
	for edge: Dictionary in value["access_edges"]:
		access_edges.append(edge.duplicate(true))
	return {"valid": true, "diagnostics": []}


func duplicate_value() -> Dictionary:
	return {
		"schema_id": SCHEMA_ID,
		"schema_version": SCHEMA_VERSION,
		"layout_ref": layout_ref.duplicate(true),
		"district_revision": district_revision,
		"access_edges": access_edges.duplicate(true),
	}


func duplicate_snapshot() -> PublicBandAccessSnapshot:
	var copy := PublicBandAccessSnapshot.new()
	copy.configure(duplicate_value())
	return copy


static func derive(snapshot: ResolvedDistrictSnapshot, state: Dictionary, revision: int) -> Dictionary:
	if snapshot == null or revision < 0 or int(state.get("district_revision", -1)) != revision:
		return _fail("PUBLIC_BAND_ACCESS_STALE")
	var data: Dictionary = snapshot.get_data()
	var layout_ref: Dictionary = {
		"layout_id": snapshot.get_layout_id(),
		"layout_definition_version": int(data.get("layout_definition_version", -1)),
		"definition_fingerprint": snapshot.get_fingerprint(),
	}
	var edges: Array[Dictionary] = []
	var seen: Dictionary = {}
	for plot: Dictionary in data.get("plots", []):
		var plot_id: String = String(plot.get("id", ""))
		var owned_cells: Dictionary = _owned_cells(plot_id, data, state)
		if owned_cells.is_empty():
			continue
		var plot_rect: Dictionary = plot.get("rect_quarter", {})
		for cell: Vector2i in owned_cells:
			for direction: String in _DIRECTIONS:
				for band: Dictionary in data.get("pedestrian_bands", []):
					if not _cell_edge_touches_band(cell, direction, plot_rect, band.get("rect_quarter", {})):
						continue
					var band_id: String = String(band.get("id", ""))
					var edge_id: String = make_access_edge_id(band_id, plot_id, cell, direction)
					if seen.has(edge_id):
						return _fail("PUBLIC_BAND_ACCESS_UNAVAILABLE")
					seen[edge_id] = true
					edges.append({
						"access_edge_id": edge_id,
						"parcel_endpoint": {"runtime_plot_id": plot_id, "signed_elevation": 0, "local_cell": {"x": cell.x, "y": cell.y}},
						"outward_direction": direction,
						"pedestrian_band_id": band_id,
					})
	edges.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["access_edge_id"]) < String(right["access_edge_id"]))
	var value: Dictionary = {"schema_id": SCHEMA_ID, "schema_version": SCHEMA_VERSION, "layout_ref": layout_ref, "district_revision": revision, "access_edges": edges}
	var validation: Dictionary = validate_value(value)
	if not bool(validation.get("valid", false)):
		return validation
	var result := PublicBandAccessSnapshot.new()
	result.configure(value)
	return {"valid": true, "snapshot": result, "diagnostics": []}


static func make_access_edge_id(pedestrian_band_id: String, runtime_plot_id: String, cell: Vector2i, direction: String) -> String:
	var components: Array[String] = ["public_band_access", pedestrian_band_id, runtime_plot_id, "0", str(cell.x), str(cell.y), direction]
	var encoded: Array[String] = ["jid1"]
	for component: String in components:
		encoded.append(_encode_component(component))
	return "/".join(encoded)


static func validate_value(value: Dictionary) -> Dictionary:
	if not _has_exact_keys(value, _ROOT_KEYS):
		return _fail("PUBLIC_BAND_ACCESS_UNAVAILABLE")
	if value.get("schema_id") != SCHEMA_ID or not value.get("schema_version") is int or int(value["schema_version"]) != SCHEMA_VERSION or not value.get("district_revision") is int or int(value["district_revision"]) < 0:
		return _fail("PUBLIC_BAND_ACCESS_UNAVAILABLE")
	if not value.get("layout_ref") is Dictionary:
		return _fail("PUBLIC_BAND_ACCESS_UNAVAILABLE")
	var layout: Dictionary = value["layout_ref"]
	var fingerprint: String = String(layout.get("definition_fingerprint", ""))
	if not _has_exact_keys(layout, _LAYOUT_KEYS) or not layout.get("layout_id") is String or String(layout["layout_id"]).is_empty() or not layout.get("layout_definition_version") is int or int(layout["layout_definition_version"]) < 0 or fingerprint.length() != 64 or fingerprint != fingerprint.to_lower() or not fingerprint.is_valid_hex_number(false):
		return _fail("PUBLIC_BAND_ACCESS_UNAVAILABLE")
	if not value.get("access_edges") is Array:
		return _fail("PUBLIC_BAND_ACCESS_UNAVAILABLE")
	var previous_id: String = ""
	for edge_value: Variant in value["access_edges"]:
		if not edge_value is Dictionary:
			return _fail("PUBLIC_BAND_ACCESS_UNAVAILABLE")
		var edge: Dictionary = edge_value
		if not _has_exact_keys(edge, _EDGE_KEYS) or not edge.get("access_edge_id") is String or not edge.get("pedestrian_band_id") is String or not edge.get("outward_direction") is String or not edge.get("parcel_endpoint") is Dictionary:
			return _fail("PUBLIC_BAND_ACCESS_UNAVAILABLE")
		var edge_id: String = edge["access_edge_id"]
		var endpoint: Dictionary = edge["parcel_endpoint"]
		if edge_id.is_empty() or (not previous_id.is_empty() and edge_id <= previous_id) or String(edge["pedestrian_band_id"]).is_empty() or not _DIRECTIONS.has(String(edge["outward_direction"])) or not _has_exact_keys(endpoint, _ENDPOINT_KEYS):
			return _fail("PUBLIC_BAND_ACCESS_UNAVAILABLE")
		if not endpoint.get("runtime_plot_id") is String or String(endpoint["runtime_plot_id"]).is_empty() or not endpoint.get("signed_elevation") is int or int(endpoint["signed_elevation"]) != 0 or not endpoint.get("local_cell") is Dictionary:
			return _fail("PUBLIC_BAND_ACCESS_UNAVAILABLE")
		var cell: Dictionary = endpoint["local_cell"]
		if not _has_exact_keys(cell, _CELL_KEYS) or not cell.get("x") is int or not cell.get("y") is int:
			return _fail("PUBLIC_BAND_ACCESS_UNAVAILABLE")
		if edge_id != make_access_edge_id(String(edge["pedestrian_band_id"]), String(endpoint["runtime_plot_id"]), Vector2i(int(cell["x"]), int(cell["y"])), String(edge["outward_direction"])):
			return _fail("PUBLIC_BAND_ACCESS_UNAVAILABLE")
		previous_id = edge_id
	return {"valid": true, "diagnostics": []}


static func _owned_cells(plot_id: String, data: Dictionary, state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for section: Dictionary in data.get("sections", []):
		if String(section.get("plot_id", "")) != plot_id:
			continue
		var owned: bool = bool(section.get("initially_owned", false))
		for plot_state: Dictionary in state.get("plot_states", []):
			if String(plot_state.get("runtime_plot_id", "")) != plot_id:
				continue
			for override: Dictionary in plot_state.get("section_state_overrides", []):
				if String(override.get("runtime_section_id", "")) == String(section.get("id", "")):
					owned = bool(override.get("owned", owned))
		if owned:
			for cell: Array in section.get("mask", []):
				result[Vector2i(int(cell[0]), int(cell[1]))] = true
	return result


static func _cell_edge_touches_band(cell: Vector2i, direction: String, plot_rect: Dictionary, band_rect: Dictionary) -> bool:
	var minimum_x4: int = int(plot_rect.get("minimum_x4", 0)) + cell.x * 4
	var minimum_z4: int = int(plot_rect.get("minimum_z4", 0)) + cell.y * 4
	var maximum_x4: int = minimum_x4 + 4
	var maximum_z4: int = minimum_z4 + 4
	match direction:
		"NORTH": return int(band_rect.get("maximum_z4", -1)) == minimum_z4 and mini(maximum_x4, int(band_rect.get("maximum_x4", 0))) > maxi(minimum_x4, int(band_rect.get("minimum_x4", 0)))
		"EAST": return int(band_rect.get("minimum_x4", -1)) == maximum_x4 and mini(maximum_z4, int(band_rect.get("maximum_z4", 0))) > maxi(minimum_z4, int(band_rect.get("minimum_z4", 0)))
		"SOUTH": return int(band_rect.get("minimum_z4", -1)) == maximum_z4 and mini(maximum_x4, int(band_rect.get("maximum_x4", 0))) > maxi(minimum_x4, int(band_rect.get("minimum_x4", 0)))
		"WEST": return int(band_rect.get("maximum_x4", -1)) == minimum_x4 and mini(maximum_z4, int(band_rect.get("maximum_z4", 0))) > maxi(minimum_z4, int(band_rect.get("minimum_z4", 0)))
	return false


static func _has_exact_keys(value: Dictionary, keys: Array[String]) -> bool:
	if value.size() != keys.size():
		return false
	for key: String in keys:
		if not value.has(key):
			return false
	return true


static func _encode_component(value: String) -> String:
	var result: String = ""
	for byte: int in value.to_utf8_buffer():
		var unreserved: bool = (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122) or (byte >= 48 and byte <= 57) or byte in [45, 46, 95, 126]
		result += char(byte) if unreserved else "%%%02X" % byte
	return result


static func _fail(code: String) -> Dictionary:
	return {"valid": false, "diagnostics": [{"code": code}]}
