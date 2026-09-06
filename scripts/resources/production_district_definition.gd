class_name ProductionDistrictDefinition
extends Resource

## Authored production content for Decision 29.
## This is immutable content data; it does not create mutable session state.

const LAYOUT_ID: String = "district.initial"
const TEMPLATE_ID: String = "district.initial.template"
const VARIANT_ID: String = "district.initial.variant.full"
const ROAD_PROFILE_ID: String = "district.initial.road.two_lane_p5"
const SLOT_ID: String = "initial_anchor"
const WIDTH: int = 25
const DEPTH: int = 25


func get_raw_record() -> Dictionary:
	var full_mask: Array = _rectangle_mask(WIDTH, DEPTH)
	var section: Dictionary = {
		"section_id": "whole_plot",
		"section_role": "FULL",
		"ordinal": 0,
		"mask": full_mask,
		"initially_owned": true,
		"initially_available": true,
		"initially_entry_eligible": true,
	}
	return {
		"definition_schema_version": 1,
		"layout_definition_version": 1,
		"canonical_schema_version": 1,
		"resolver_schema_version": 1,
		"layout": {
			"layout_id": LAYOUT_ID,
			"physical_elevation_range": {"minimum_elevation": -5, "maximum_elevation": 9},
			"row_tracks": [{"track_id": "row_0", "ordinal": 0, "size": DEPTH}],
			"column_tracks": [{"track_id": "col_0", "ordinal": 0, "size": WIDTH}],
			"horizontal_boundaries": [{"boundary_id": "h0", "ordinal": 0}, {"boundary_id": "h1", "ordinal": 1}],
			"vertical_boundaries": [{"boundary_id": "v0", "ordinal": 0}, {"boundary_id": "v1", "ordinal": 1}],
			"slots": [{
				"slot_id": SLOT_ID,
				"ordinal": 0,
				"row_track_id": "row_0",
				"column_track_id": "col_0",
				"role": "PLOT",
				"template_id": TEMPLATE_ID,
				"selected_variant_id": VARIANT_ID,
				"fixed_block_definition_id": null,
				"sections": [section],
				"buildability_mask": full_mask.duplicate(true),
				"fixed_occupants": [],
				"physical_elevation_cap_override": null,
			}],
			"outer_ring": {"complete": true, "permanent": true, "road_profile_id": ROAD_PROFILE_ID},
			"arrival_sources": [
				_source("gateway_north", "NORTH"),
				_source("gateway_east", "EAST"),
				_source("gateway_south", "SOUTH"),
				_source("gateway_west", "WEST"),
			],
		},
		"template_catalog": [{"template_id": TEMPLATE_ID, "template_version": 1, "physical_elevation_cap": null, "variant_ids": [VARIANT_ID]}],
		"variant_catalog": [{
			"variant_id": VARIANT_ID,
			"template_id": TEMPLATE_ID,
			"template_version": 1,
			"width": WIDTH,
			"depth": DEPTH,
			"section_mappings": [{"section_role": "FULL", "ordinal": 0, "mask": full_mask.duplicate(true)}],
		}],
		"fixed_block_catalog": [],
		"road_profile_catalog": [{
			"road_profile_id": ROAD_PROFILE_ID,
			"road_profile_version": 1,
			"pedestrian_width": 5,
			"carriageways": [{"ordinal": 0, "lanes": [
				{"ordinal": 0, "direction": "FORWARD", "width": 3},
				{"ordinal": 1, "direction": "REVERSE", "width": 3},
			]}],
		}],
	}


func _source(source_id: String, side: String) -> Dictionary:
	return {
		"arrival_source_id": source_id,
		"mode": "PEDESTRIAN",
		"selector": {"kind": "OUTER_PEDESTRIAN_BAND", "slot_id": SLOT_ID, "side": side},
		"initially_enabled": true,
		"capacity": null,
		"weight": null,
		"schedule": [],
		"presentation": {},
	}


func _rectangle_mask(width: int, depth: int) -> Array:
	var cells: Array = []
	for y: int in range(depth):
		for x: int in range(width):
			cells.append([x, y])
	return cells
