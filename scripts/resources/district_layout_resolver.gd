class_name DistrictLayoutResolver
extends RefCounted

## Pure H2 resolver. It consumes an H1-normalized definition and emits a
## deterministic runtime snapshot without scene-tree, filesystem, time, or RNG access.

const ROOT_MINIMUM_ELEVATION: int = -5
const ROOT_MAXIMUM_ELEVATION: int = 9
const QUARTER_TILES_PER_TILE: int = 4


func resolve(input: Variant) -> Dictionary:
	var validation: Dictionary = DistrictLayoutValidator.new().normalize_and_validate(input)
	if not bool(validation.get("valid", false)):
		return {"valid": false, "snapshot": null, "diagnostics": validation.get("diagnostics", [])}
	var record: Dictionary = validation.get("record", {})
	var encoder := DistrictLayoutCanonicalEncoder.new()
	var canonical: Dictionary = encoder.encode(record, int(record.get("canonical_schema_version", 1)))
	if not bool(canonical.get("valid", false)):
		return {"valid": false, "snapshot": null, "diagnostics": canonical.get("diagnostics", [])}
	var data: Dictionary = _resolve_record(record)
	if data.has("resolver_diagnostics"):
		return {"valid": false, "snapshot": null, "diagnostics": data.get("resolver_diagnostics", [])}
	var snapshot := ResolvedDistrictSnapshot.new()
	snapshot.initialize(data, String(canonical.get("canonical_json", "")), canonical.get("bytes", PackedByteArray()), String(canonical.get("fingerprint", "")))
	return {"valid": true, "snapshot": snapshot, "diagnostics": []}


func _resolve_record(record: Dictionary) -> Dictionary:
	var layout: Dictionary = record["layout"]
	var row_tracks: Array = layout["row_tracks"]
	var column_tracks: Array = layout["column_tracks"]
	var road_profile: Dictionary = _find_record(record["road_profile_catalog"], "road_profile_id", String(layout["outer_ring"]["road_profile_id"]))
	var pedestrian_width: int = int(road_profile["pedestrian_width"])
	var lane_width: int = 0
	for carriageway: Dictionary in road_profile["carriageways"]:
		for lane: Dictionary in carriageway["lanes"]:
			lane_width += int(lane["width"])
	var corridor_width: int = pedestrian_width * 2 + lane_width
	var horizontal_starts: Array[int] = _boundary_starts(row_tracks, corridor_width)
	var vertical_starts: Array[int] = _boundary_starts(column_tracks, corridor_width)
	var district_rect: Dictionary = _scale_rect(_rect(0, 0, _axis_end(column_tracks, corridor_width), _axis_end(row_tracks, corridor_width)))
	var grid: Dictionary = {
		"quarter_tiles_per_tile": QUARTER_TILES_PER_TILE,
		"corridor_width_tiles": corridor_width,
		"corridor_width_quarter": corridor_width * QUARTER_TILES_PER_TILE,
		"horizontal_boundary_starts_quarter": _scale_array(horizontal_starts),
		"vertical_boundary_starts_quarter": _scale_array(vertical_starts),
		"district_rect_quarter": district_rect,
	}
	var slots: Array = []
	var plots: Array = []
	var sections: Array = []
	var fixed_occupants: Array = []
	var floors: Array = []
	var cells: Array = []
	var slot_lookup: Dictionary = {}
	var row_lookup: Dictionary = _index_by_id(row_tracks, "track_id")
	var column_lookup: Dictionary = _index_by_id(column_tracks, "track_id")
	var templates: Array = record["template_catalog"]
	var variants: Array = record["variant_catalog"]
	var fixed_catalog: Array = record["fixed_block_catalog"]
	for authored_slot: Dictionary in layout["slots"]:
		var row_index: int = int(row_lookup[String(authored_slot["row_track_id"])])
		var column_index: int = int(column_lookup[String(authored_slot["column_track_id"])])
		var slot_rect: Dictionary = _slot_rect(row_index, column_index, row_tracks, column_tracks, horizontal_starts, vertical_starts, corridor_width)
		var slot_id: String = _id("slot", [String(layout["layout_id"]), String(authored_slot["slot_id"]), int(authored_slot["ordinal"])])
		var template: Dictionary = _find_record(templates, "template_id", str(authored_slot.get("template_id", "")))
		var variant: Dictionary = _find_record(variants, "variant_id", str(authored_slot.get("selected_variant_id", "")))
		var effective_cap: Dictionary = _effective_cap(record["layout"]["physical_elevation_range"], template.get("physical_elevation_cap", null), authored_slot.get("physical_elevation_cap_override", null))
		var slot_result: Dictionary = {
			"id": slot_id,
			"authored_id": String(authored_slot["slot_id"]),
			"ordinal": int(authored_slot["ordinal"]),
			"row_track_id": String(authored_slot["row_track_id"]),
			"column_track_id": String(authored_slot["column_track_id"]),
			"role": String(authored_slot["role"]),
			"template_id": null if template.is_empty() else String(template["template_id"]),
			"selected_variant_id": null if variant.is_empty() else String(variant["variant_id"]),
			"physical_elevation_cap": effective_cap,
			"rect_quarter": slot_rect,
			"pose": _nw_pose(slot_rect, 0, "NONE"),
		}
		slots.append(slot_result)
		slot_lookup[String(authored_slot["slot_id"])] = {"slot": slot_result, "row_index": row_index, "column_index": column_index}
		if String(authored_slot["role"]) == "PLOT":
			var plot_id: String = _id("plot", [String(layout["layout_id"]), slot_id, int(authored_slot["ordinal"])])
			var plot_result: Dictionary = {
				"id": plot_id,
				"slot_id": slot_id,
				"ordinal": int(authored_slot["ordinal"]),
				"variant_id": String(variant["variant_id"]),
				"rect_quarter": slot_rect,
				"pose": _nw_pose(slot_rect, 0, "NONE"),
				"buildability_mask": authored_slot["buildability_mask"],
				"physical_elevation_cap": effective_cap,
			}
			plots.append(plot_result)
			var minimum_elevation: int = int(effective_cap["minimum_elevation"])
			var maximum_elevation: int = int(effective_cap["maximum_elevation"])
			for elevation: int in range(minimum_elevation, maximum_elevation + 1):
				var floor_id: String = _id("floor", [plot_id, elevation])
				floors.append({"id": floor_id, "plot_id": plot_id, "elevation": elevation, "rect_quarter": slot_rect, "pose": _nw_pose(slot_rect, elevation, "NONE")})
				for cell: Array in authored_slot["buildability_mask"]:
					var cell_id: String = _id("cell", [floor_id, int(cell[0]), int(cell[1])])
					cells.append({"id": cell_id, "floor_id": floor_id, "x": int(cell[0]), "y": int(cell[1]), "pose": {"x4": int(slot_rect["minimum_x4"]) + int(cell[0]) * 4 + 2, "z4": int(slot_rect["minimum_z4"]) + int(cell[1]) * 4 + 2, "elevation": elevation, "facing": "NONE"}})
			for authored_section: Dictionary in authored_slot["sections"]:
				var section_id: String = _id("section", [plot_id, String(authored_section["section_id"]), int(authored_section["ordinal"])])
				var section_result: Dictionary = {
					"id": section_id,
					"plot_id": plot_id,
					"slot_id": slot_id,
					"authored_id": String(authored_section["section_id"]),
					"section_role": String(authored_section["section_role"]),
					"ordinal": int(authored_section["ordinal"]),
					"mask": authored_section["mask"],
					"initially_owned": bool(authored_section["initially_owned"]),
					"initially_available": bool(authored_section["initially_available"]),
					"initially_entry_eligible": bool(authored_section["initially_entry_eligible"]),
				}
				sections.append(section_result)
		for authored_occupant: Dictionary in authored_slot["fixed_occupants"]:
			fixed_occupants.append(_resolve_occupant(authored_occupant, slot_id, "SLOT"))
		if authored_slot.get("fixed_block_definition_id", null) != null:
			var fixed_block: Dictionary = _find_record(fixed_catalog, "fixed_block_definition_id", String(authored_slot["fixed_block_definition_id"]))
			for authored_occupant: Dictionary in fixed_block.get("fixed_occupants", []):
				fixed_occupants.append(_resolve_occupant(authored_occupant, slot_id, "FIXED_BLOCK"))
		if not variant.is_empty():
			_assert_variant_matches_slot(variant, int(column_tracks[column_index]["size"]), int(row_tracks[row_index]["size"]))
	var topology: Dictionary = _resolve_topology(layout, row_tracks, column_tracks, horizontal_starts, vertical_starts, corridor_width, pedestrian_width, road_profile)
	var source_result: Dictionary = _resolve_sources(layout["arrival_sources"], slot_lookup, topology["pedestrian_bands"], String(layout["layout_id"]))
	if not bool(source_result.get("valid", false)):
		return {"resolver_diagnostics": source_result.get("diagnostics", [])}
	return {
		"resolver_schema_version": int(record["resolver_schema_version"]),
		"definition_schema_version": int(record["definition_schema_version"]),
		"layout_definition_version": int(record["layout_definition_version"]),
		"layout_id": String(layout["layout_id"]),
		"physical_elevation_range": layout["physical_elevation_range"],
		"grid": grid,
		"slots": slots,
		"plots": plots,
		"sections": sections,
		"fixed_occupants": fixed_occupants,
		"floors": floors,
		"cells": cells,
		"district_rect_quarter": district_rect,
		"street_segments": topology["street_segments"],
		"intersections": topology["intersections"],
		"pedestrian_bands": topology["pedestrian_bands"],
		"carriageways": topology["carriageways"],
		"lanes": topology["lanes"],
		"arrival_source_attachments": source_result.get("attachments", []),
	}


func _resolve_topology(layout: Dictionary, row_tracks: Array, column_tracks: Array, horizontal_starts: Array[int], vertical_starts: Array[int], corridor_width: int, pedestrian_width: int, road_profile: Dictionary) -> Dictionary:
	var street_segments: Array = []
	var intersections: Array = []
	var pedestrian_bands: Array = []
	var carriageways: Array = []
	var lanes: Array = []
	for row_index: int in range(horizontal_starts.size()):
		for column_index: int in range(column_tracks.size()):
			var street_id: String = _id("street_h", [String(layout["layout_id"]), String(layout["horizontal_boundaries"][row_index]["boundary_id"]), String(column_tracks[column_index]["track_id"])])
			var x_min: int = vertical_starts[column_index] + corridor_width
			var x_max: int = vertical_starts[column_index + 1]
			var z_min: int = horizontal_starts[row_index]
			var street_rect: Dictionary = _rect(x_min, z_min, x_max, z_min + corridor_width)
			var street_result: Dictionary = {"id": street_id, "orientation": "HORIZONTAL", "boundary_id": String(layout["horizontal_boundaries"][row_index]["boundary_id"]), "track_id": String(column_tracks[column_index]["track_id"]), "rect_quarter": _scale_rect(street_rect), "pose": _center_pose(_scale_rect(street_rect), 0, "NONE")}
			street_segments.append(street_result)
			_resolve_road_layers(street_result, street_rect, "HORIZONTAL", corridor_width, pedestrian_width, road_profile, carriageways, lanes, pedestrian_bands)
	for column_index: int in range(vertical_starts.size()):
		for row_index: int in range(row_tracks.size()):
			var street_id: String = _id("street_v", [String(layout["layout_id"]), String(layout["vertical_boundaries"][column_index]["boundary_id"]), String(row_tracks[row_index]["track_id"])])
			var x_min: int = vertical_starts[column_index]
			var x_max: int = vertical_starts[column_index] + corridor_width
			var z_min: int = horizontal_starts[row_index] + corridor_width
			var z_max: int = horizontal_starts[row_index + 1]
			var street_rect: Dictionary = _rect(x_min, z_min, x_max, z_max)
			var street_result: Dictionary = {"id": street_id, "orientation": "VERTICAL", "boundary_id": String(layout["vertical_boundaries"][column_index]["boundary_id"]), "track_id": String(row_tracks[row_index]["track_id"]), "rect_quarter": _scale_rect(street_rect), "pose": _center_pose(_scale_rect(street_rect), 0, "NONE")}
			street_segments.append(street_result)
			_resolve_road_layers(street_result, street_rect, "VERTICAL", corridor_width, pedestrian_width, road_profile, carriageways, lanes, pedestrian_bands)
	for row_index: int in range(horizontal_starts.size()):
		for column_index: int in range(vertical_starts.size()):
			var intersection_id: String = _id("intersection", [String(layout["layout_id"]), String(layout["horizontal_boundaries"][row_index]["boundary_id"]), String(layout["vertical_boundaries"][column_index]["boundary_id"])])
			var intersection_rect: Dictionary = _scale_rect(_rect(vertical_starts[column_index], horizontal_starts[row_index], vertical_starts[column_index] + corridor_width, horizontal_starts[row_index] + corridor_width))
			intersections.append({"id": intersection_id, "horizontal_boundary_id": String(layout["horizontal_boundaries"][row_index]["boundary_id"]), "vertical_boundary_id": String(layout["vertical_boundaries"][column_index]["boundary_id"]), "rect_quarter": intersection_rect, "pose": _center_pose(intersection_rect, 0, "NONE")})
	return {"street_segments": street_segments, "intersections": intersections, "pedestrian_bands": pedestrian_bands, "carriageways": carriageways, "lanes": lanes}


func _resolve_road_layers(street: Dictionary, street_rect: Dictionary, orientation: String, corridor_width: int, pedestrian_width: int, road_profile: Dictionary, carriageways: Array, lanes: Array, pedestrian_bands: Array) -> void:
	var street_id: String = String(street["id"])
	var negative_rect: Dictionary
	var positive_rect: Dictionary
	var carriageway_rect: Dictionary
	if orientation == "HORIZONTAL":
		negative_rect = _rect(street_rect["min_x"], street_rect["min_z"], street_rect["max_x"], street_rect["min_z"] + pedestrian_width)
		positive_rect = _rect(street_rect["min_x"], street_rect["max_z"] - pedestrian_width, street_rect["max_x"], street_rect["max_z"])
		carriageway_rect = _rect(street_rect["min_x"], street_rect["min_z"] + pedestrian_width, street_rect["max_x"], street_rect["max_z"] - pedestrian_width)
	else:
		negative_rect = _rect(street_rect["min_x"], street_rect["min_z"], street_rect["min_x"] + pedestrian_width, street_rect["max_z"])
		positive_rect = _rect(street_rect["max_x"] - pedestrian_width, street_rect["min_z"], street_rect["max_x"], street_rect["max_z"])
		carriageway_rect = _rect(street_rect["min_x"] + pedestrian_width, street_rect["min_z"], street_rect["max_x"] - pedestrian_width, street_rect["max_z"])
	var negative_id: String = _id("ped_band", [street_id, "NEGATIVE"])
	var positive_id: String = _id("ped_band", [street_id, "POSITIVE"])
	pedestrian_bands.append({"id": negative_id, "street_segment_id": street_id, "side": "NEGATIVE", "rect_quarter": _scale_rect(negative_rect), "pose": _center_pose(_scale_rect(negative_rect), 0, "NONE")})
	pedestrian_bands.append({"id": positive_id, "street_segment_id": street_id, "side": "POSITIVE", "rect_quarter": _scale_rect(positive_rect), "pose": _center_pose(_scale_rect(positive_rect), 0, "NONE")})
	var carriageway_id: String = _id("carriageway", [street_id, 0])
	var carriageway_result: Dictionary = {"id": carriageway_id, "street_segment_id": street_id, "ordinal": 0, "rect_quarter": _scale_rect(carriageway_rect), "pose": _center_pose(_scale_rect(carriageway_rect), 0, "NONE")}
	carriageways.append(carriageway_result)
	var forward_cursor: int = 0
	var reverse_cursor: int = 0
	for authored_carriageway: Dictionary in road_profile["carriageways"]:
		for authored_lane: Dictionary in authored_carriageway["lanes"]:
			var width: int = int(authored_lane["width"])
			var lane_rect: Dictionary
			var direction: String = String(authored_lane["direction"])
			var cursor: int = forward_cursor if direction == "FORWARD" else reverse_cursor
			if orientation == "HORIZONTAL":
				if direction == "FORWARD":
					lane_rect = _rect(carriageway_rect["min_x"], carriageway_rect["min_z"] + cursor, carriageway_rect["max_x"], carriageway_rect["min_z"] + cursor + width)
				else:
					lane_rect = _rect(carriageway_rect["min_x"], carriageway_rect["max_z"] - cursor - width, carriageway_rect["max_x"], carriageway_rect["max_z"] - cursor)
			else:
				if direction == "FORWARD":
					lane_rect = _rect(carriageway_rect["min_x"] + cursor, carriageway_rect["min_z"], carriageway_rect["min_x"] + cursor + width, carriageway_rect["max_z"])
				else:
					lane_rect = _rect(carriageway_rect["max_x"] - cursor - width, carriageway_rect["min_z"], carriageway_rect["max_x"] - cursor, carriageway_rect["max_z"])
			var lane_id: String = _id("lane", [carriageway_id, int(authored_lane["ordinal"])])
			lanes.append({"id": lane_id, "carriageway_id": carriageway_id, "ordinal": int(authored_lane["ordinal"]), "direction": direction, "rect_quarter": _scale_rect(lane_rect), "pose": _center_pose(_scale_rect(lane_rect), 0, "NONE")})
			if direction == "FORWARD":
				forward_cursor += width
			else:
				reverse_cursor += width


func _resolve_sources(sources: Array, slot_lookup: Dictionary, bands: Array, layout_id: String) -> Dictionary:
	var by_id: Dictionary = {}
	for band: Dictionary in bands:
		by_id[String(band["id"])] = band
	var result: Array = []
	var diagnostics: Array[Dictionary] = []
	for source: Dictionary in sources:
		var selector: Dictionary = source["selector"]
		if String(selector.get("kind", "")) != "OUTER_PEDESTRIAN_BAND" or not slot_lookup.has(String(selector.get("slot_id", ""))):
			diagnostics.append({"code": "SOURCE_SELECTOR_UNRESOLVED", "path": "$.layout.arrival_sources", "message": "source selector does not resolve to a known outer-ring slot"})
			continue
		var slot_entry: Dictionary = slot_lookup[String(selector["slot_id"])]
		var slot: Dictionary = slot_entry["slot"]
		if String(slot.get("role", "")) != "PLOT":
			diagnostics.append({"code": "SOURCE_SLOT_INVALID", "path": "$.layout.arrival_sources", "message": "arrival source slot must be a Plot"})
			continue
		var row_index: int = int(slot_entry["row_index"])
		var column_index: int = int(slot_entry["column_index"])
		var side: String = String(selector["side"])
		var street_id: String = ""
		var band_side: String = ""
		var facing: String = "NONE"
		match side:
			"NORTH":
				street_id = _id("street_h", [layout_id, "h0", String(slot["column_track_id"])])
				band_side = "POSITIVE"
				facing = "SOUTH"
			"EAST":
				street_id = _id("street_v", [layout_id, "v" + str(column_index + 1), String(slot["row_track_id"])])
				band_side = "NEGATIVE"
				facing = "WEST"
			"SOUTH":
				street_id = _id("street_h", [layout_id, "h" + str(row_index + 1), String(slot["column_track_id"])])
				band_side = "NEGATIVE"
				facing = "NORTH"
			"WEST":
				street_id = _id("street_v", [layout_id, "v0", String(slot["row_track_id"])])
				band_side = "POSITIVE"
				facing = "EAST"
			_:
				diagnostics.append({"code": "SOURCE_SIDE_INVALID", "path": "$.layout.arrival_sources", "message": "source side must be NORTH, EAST, SOUTH, or WEST"})
				continue
		var target_id: String = _id("ped_band", [street_id, band_side])
		var target: Dictionary = by_id.get(target_id, {})
		if target.is_empty():
			diagnostics.append({"code": "SOURCE_TARGET_UNRESOLVED", "path": "$.layout.arrival_sources", "message": "source selector resolved to zero topology targets"})
			continue
		var gateway_rect: Dictionary = _gateway_rect(slot, target, side)
		result.append({
			"id": _id("source_attachment", [layout_id, String(source["arrival_source_id"]), target_id]),
			"authored_id": String(source["arrival_source_id"]),
			"mode": String(source["mode"]),
			"initially_enabled": bool(source["initially_enabled"]),
			"selector": selector,
			"resolved_target_topology_id": target_id,
			"gateway_rect_quarter": gateway_rect,
			"pose": _center_pose(gateway_rect, 0, facing),
		})
	return {"valid": diagnostics.is_empty(), "attachments": result, "diagnostics": diagnostics}


func _gateway_rect(slot: Dictionary, target: Dictionary, side: String) -> Dictionary:
	var slot_rect: Dictionary = slot["rect_quarter"]
	var target_rect: Dictionary = target["rect_quarter"]
	var minimum_x4: int = maxi(int(slot_rect["minimum_x4"]), int(target_rect["minimum_x4"]))
	var maximum_x4: int = mini(int(slot_rect["maximum_x4"]), int(target_rect["maximum_x4"]))
	var minimum_z4: int = maxi(int(slot_rect["minimum_z4"]), int(target_rect["minimum_z4"]))
	var maximum_z4: int = mini(int(slot_rect["maximum_z4"]), int(target_rect["maximum_z4"]))
	if side == "NORTH" or side == "SOUTH":
		minimum_z4 = int(target_rect["minimum_z4"])
		maximum_z4 = int(target_rect["maximum_z4"])
	else:
		minimum_x4 = int(target_rect["minimum_x4"])
		maximum_x4 = int(target_rect["maximum_x4"])
	return {"minimum_x4": minimum_x4, "minimum_z4": minimum_z4, "maximum_x4": maximum_x4, "maximum_z4": maximum_z4}


func _resolve_occupant(authored: Dictionary, slot_id: String, source_kind: String) -> Dictionary:
	var occupant_id: String = _id("fixed_occupant", [slot_id, String(authored["occupant_id"]), int(authored["ordinal"])])
	var masks: Array = []
	for elevation_mask: Dictionary in authored["elevation_masks"]:
		masks.append({"elevation": int(elevation_mask["elevation"]), "mask": elevation_mask["mask"]})
	return {"id": occupant_id, "runtime_slot_id": slot_id, "authored_id": String(authored["occupant_id"]), "ordinal": int(authored["ordinal"]), "source_kind": source_kind, "elevation_masks": masks}


func _assert_variant_matches_slot(variant: Dictionary, width: int, depth: int) -> void:
	# H1 already rejects mismatches. Keeping this assertion local documents that
	# H2 must never silently resize or crop an authored variant.
	assert(int(variant["width"]) == width and int(variant["depth"]) == depth)


func _effective_cap(root: Dictionary, template_cap: Variant, override_cap: Variant) -> Dictionary:
	var minimum: int = int(root["minimum_elevation"])
	var maximum: int = int(root["maximum_elevation"])
	if template_cap != null:
		minimum = maxi(minimum, int(template_cap["minimum_elevation"]))
		maximum = mini(maximum, int(template_cap["maximum_elevation"]))
	if override_cap != null:
		minimum = maxi(minimum, int(override_cap["minimum_elevation"]))
		maximum = mini(maximum, int(override_cap["maximum_elevation"]))
	return {"minimum_elevation": minimum, "maximum_elevation": maximum}


func _slot_rect(row_index: int, column_index: int, rows: Array, columns: Array, horizontal_starts: Array[int], vertical_starts: Array[int], corridor_width: int) -> Dictionary:
	var min_x: int = vertical_starts[column_index] + corridor_width
	var min_z: int = horizontal_starts[row_index] + corridor_width
	return _scale_rect(_rect(min_x, min_z, min_x + int(columns[column_index]["size"]), min_z + int(rows[row_index]["size"])))


func _boundary_starts(tracks: Array, corridor_width: int) -> Array[int]:
	var starts: Array[int] = [0]
	var cursor: int = 0
	for track: Dictionary in tracks:
		cursor += int(track["size"]) + corridor_width
		starts.append(cursor)
	return starts


func _axis_end(tracks: Array, corridor_width: int) -> int:
	var total: int = corridor_width * (tracks.size() + 1)
	for track: Dictionary in tracks:
		total += int(track["size"])
	return total


func _rect(min_x: int, min_z: int, max_x: int, max_z: int) -> Dictionary:
	return {"min_x": min_x, "min_z": min_z, "max_x": max_x, "max_z": max_z, "width": max_x - min_x, "depth": max_z - min_z}


func _scale_rect(rect: Dictionary) -> Dictionary:
	return {"minimum_x4": int(rect["min_x"]) * QUARTER_TILES_PER_TILE, "minimum_z4": int(rect["min_z"]) * QUARTER_TILES_PER_TILE, "maximum_x4": int(rect["max_x"]) * QUARTER_TILES_PER_TILE, "maximum_z4": int(rect["max_z"]) * QUARTER_TILES_PER_TILE}


func _nw_pose(rect: Dictionary, elevation: int, facing: String) -> Dictionary:
	return {"x4": int(rect["minimum_x4"]), "z4": int(rect["minimum_z4"]), "elevation": elevation, "facing": facing}


func _center_pose(rect: Dictionary, elevation: int, facing: String) -> Dictionary:
	var x_sum: int = int(rect["minimum_x4"]) + int(rect["maximum_x4"])
	var z_sum: int = int(rect["minimum_z4"]) + int(rect["maximum_z4"])
	return {"x4": x_sum / 2, "z4": z_sum / 2, "elevation": elevation, "facing": facing}


func _scale_array(values: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for value: int in values:
		result.append(value * QUARTER_TILES_PER_TILE)
	return result


func _index_by_id(records: Array, key: String) -> Dictionary:
	var result: Dictionary = {}
	for index: int in range(records.size()):
		result[String(records[index][key])] = index
	return result


func _find_record(records: Array, key: String, expected: String) -> Dictionary:
	for record: Variant in records:
		if record is Dictionary and String(record.get(key, "")) == expected:
			return record
	return {}


func _id(type_tag: String, components: Array) -> String:
	var parts: Array[String] = ["jid1", _encode_component(type_tag)]
	for component: Variant in components:
		parts.append(_encode_component(str(component)))
	return "/".join(parts)


func _encode_component(value: String) -> String:
	var bytes: PackedByteArray = value.to_utf8_buffer()
	var result: String = ""
	const hex: String = "0123456789ABCDEF"
	for byte_value: int in bytes:
		var safe: bool = (byte_value >= 0x41 and byte_value <= 0x5A) or (byte_value >= 0x61 and byte_value <= 0x7A) or (byte_value >= 0x30 and byte_value <= 0x39) or byte_value == 0x2D or byte_value == 0x2E or byte_value == 0x5F or byte_value == 0x7E
		if safe:
			result += String.chr(byte_value)
		else:
			result += "%" + hex[(byte_value >> 4) & 0x0F] + hex[byte_value & 0x0F]
	return result
