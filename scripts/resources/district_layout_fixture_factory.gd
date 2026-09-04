class_name DistrictLayoutFixtureFactory
extends RefCounted

## Mechanical proof-fixture generator for H1.
## It emits the complete normalized semantic shape consumed by the validator.

const ROOT_MINIMUM_ELEVATION: int = -5
const ROOT_MAXIMUM_ELEVATION: int = 9


func build_fixture(fixture_id: String) -> Dictionary:
	match fixture_id:
		"A", "fixture.legacy_25_single":
			return _build_a()
		"B", "fixture.variable_30x40_single":
			return _build_b()
		"C", "fixture.mixed_3x3":
			return _build_c()
		_:
			return {}


func _build_a() -> Dictionary:
	var full: Array = _rectangle_mask(25, 25)
	var section: Dictionary = _section("whole_plot", "FULL", 0, full, true, true, true)
	var variant_id: String = "fixture.variant.legacy_25.full"
	return _root(
		"fixture.legacy_25_single",
		[25], [25],
		[_slot("legacy_anchor", 0, "row_0", "col_0", "PLOT", "fixture.template.legacy_25", variant_id, null, [section], [], null)],
		[_template("fixture.template.legacy_25", null, [variant_id])],
		[_variant(variant_id, "fixture.template.legacy_25", 25, 25, [{"section_role": "FULL", "ordinal": 0, "mask": full}])],
		[],
		[_road("fixture.road.two_lane_p5", 5)],
		[_source("gateway_north", "legacy_anchor", "NORTH"), _source("gateway_east", "legacy_anchor", "EAST"), _source("gateway_south", "legacy_anchor", "SOUTH"), _source("gateway_west", "legacy_anchor", "WEST")],
		"fixture.road.two_lane_p5"
	)


func _build_b() -> Dictionary:
	var arrival: Array = _union(_rectangle_mask(12, 20, 0, 0), _rectangle_mask(8, 8, 0, 20))
	var east: Array = _union(_rectangle_mask(18, 20, 12, 0), _rectangle_mask(22, 8, 8, 20))
	var south: Array = _rectangle_mask(30, 12, 0, 28)
	var sections: Array = [
		_section("arrival_section", "ARRIVAL", 0, arrival, true, true, true),
		_section("east_section", "EAST", 1, east, false, true, false),
		_section("south_section", "SOUTH", 2, south, false, true, false),
	]
	var variant_id: String = "fixture.variant.variable_30x40.proof"
	return _root(
		"fixture.variable_30x40_single",
		[40], [30],
		[_slot("variable_anchor", 0, "row_0", "col_0", "PLOT", "fixture.template.variable_30x40", variant_id, null, sections, [], _cap(-1, 4))],
		[_template("fixture.template.variable_30x40", _cap(-2, 6), [variant_id])],
		[_variant(variant_id, "fixture.template.variable_30x40", 30, 40, [
			{"section_role": "ARRIVAL", "ordinal": 0, "mask": arrival},
			{"section_role": "EAST", "ordinal": 1, "mask": east},
			{"section_role": "SOUTH", "ordinal": 2, "mask": south},
		])],
		[],
		[_road("fixture.road.two_lane_p5", 5)],
		[],
		"fixture.road.two_lane_p5"
	)


func _build_c() -> Dictionary:
	var market_entry: Array = _p3(20, 18, 0)
	var market_rear: Array = _p3(20, 18, 1)
	var market_court: Array = _p3(20, 18, 2)
	var station_entry: Array = _p3(20, 24, 0)
	var station_wing: Array = _p3(20, 24, 1)
	var station_yard: Array = _p3(20, 24, 2)
	var canal_entry: Array = _p2(36, 18, 0)
	var canal_rear: Array = _p2(36, 18, 1)
	var garden_entry: Array = _p2(36, 24, 0)
	var garden_rear: Array = _p2(36, 24, 1)
	var workshop_entry: Array = _p2(20, 30, 0)
	var workshop_rear: Array = _p2(20, 30, 1)
	var arcade_entry: Array = _p2(28, 30, 0)
	var arcade_rear: Array = _p2(28, 30, 1)
	var tower_entry: Array = _p2(36, 30, 0)
	var tower_rear: Array = _p2(36, 30, 1)
	var market_sections: Array = [
		_section("market_entry", "ENTRY", 0, market_entry, true, true, true),
		_section("market_rear", "REAR", 1, market_rear, false, true, false),
		_section("market_court", "COURT", 2, market_court, false, true, false),
	]
	var station_sections: Array = [
		_section("station_entry", "ENTRY", 0, station_entry, true, true, true),
		_section("station_wing", "REAR", 1, station_wing, false, true, false),
		_section("station_yard", "COURT", 2, station_yard, false, true, false),
	]
	var canal_sections: Array = [_section("canal_entry", "ENTRY", 0, canal_entry, false, true, true), _section("canal_rear", "REAR", 1, canal_rear, false, true, false)]
	var garden_sections: Array = [_section("garden_entry", "ENTRY", 0, garden_entry, true, true, true), _section("garden_rear", "REAR", 1, garden_rear, false, true, false)]
	var workshop_sections: Array = [_section("workshop_entry", "ENTRY", 0, workshop_entry, false, true, true), _section("workshop_rear", "REAR", 1, workshop_rear, false, true, false)]
	var arcade_sections: Array = [_section("arcade_entry", "ENTRY", 0, arcade_entry, false, true, true), _section("arcade_rear", "REAR", 1, arcade_rear, false, true, false)]
	var tower_sections: Array = [_section("tower_entry", "ENTRY", 0, tower_entry, false, true, true), _section("tower_rear", "REAR", 1, tower_rear, false, true, false)]
	var monument_occupant: Dictionary = _occupant("monument_mass", 0, [{"elevation": 0, "mask": _rectangle_mask(10, 10, 9, 4)}])
	var workshop_core: Dictionary = _occupant("service_core_workshop", 0, [{"elevation": 0, "mask": _rectangle_mask(4, 6, 8, 12)}])
	var tower_core_mask: Array = _rectangle_mask(6, 6, 15, 12)
	var tower_core: Dictionary = _occupant("service_core_tower", 0, [{"elevation": 0, "mask": tower_core_mask}, {"elevation": 1, "mask": tower_core_mask}])
	var slots: Array = [
		_slot("market_hall", 0, "row_0", "col_0", "PLOT", "fixture.template.market", "fixture.variant.market.market_hall", null, market_sections, [], _cap(-2, 5)),
		_slot("civic_monument", 1, "row_0", "col_1", "DECORATIVE_FIXED", null, null, "fixture.fixed.civic_monument", [], [], null),
		_slot("canal_plot", 2, "row_0", "col_2", "PLOT", "fixture.template.market", "fixture.variant.market.canal_plot", null, canal_sections, [], _cap(-1, 3)),
		_slot("station_plot", 3, "row_1", "col_0", "PLOT", "fixture.template.courtyard", "fixture.variant.courtyard.station_plot", null, station_sections, [], null),
		_slot("central_plaza", 4, "row_1", "col_1", "PUBLIC_PLAZA", null, null, null, [], [], null),
		_slot("garden_plot", 5, "row_1", "col_2", "PLOT", "fixture.template.courtyard", "fixture.variant.courtyard.garden_plot", null, garden_sections, [], _cap(0, 2)),
		_slot("workshop_plot", 6, "row_2", "col_0", "PLOT", "fixture.template.tower", "fixture.variant.tower.workshop_plot", null, workshop_sections, [workshop_core], _cap(-1, 2)),
		_slot("arcade_plot", 7, "row_2", "col_1", "PLOT", "fixture.template.market", "fixture.variant.market.arcade_plot", null, arcade_sections, [], null),
		_slot("tower_plot", 8, "row_2", "col_2", "PLOT", "fixture.template.tower", "fixture.variant.tower.tower_plot", null, tower_sections, [tower_core], _cap(-4, 7)),
	]
	return _root(
		"fixture.mixed_3x3",
		[18, 24, 30], [20, 28, 36], slots,
		[
			_template("fixture.template.market", _cap(-3, 6), ["fixture.variant.market.market_hall", "fixture.variant.market.canal_plot", "fixture.variant.market.arcade_plot"]),
			_template("fixture.template.courtyard", _cap(-2, 4), ["fixture.variant.courtyard.station_plot", "fixture.variant.courtyard.garden_plot"]),
			_template("fixture.template.tower", _cap(-5, 9), ["fixture.variant.tower.workshop_plot", "fixture.variant.tower.tower_plot"]),
		],
		[
			_variant("fixture.variant.market.market_hall", "fixture.template.market", 20, 18, _p3_mappings(["market_entry", "market_rear", "market_court"], [market_entry, market_rear, market_court])),
			_variant("fixture.variant.market.canal_plot", "fixture.template.market", 36, 18, _p2_mappings(["canal_entry", "canal_rear"], [canal_entry, canal_rear])),
			_variant("fixture.variant.market.arcade_plot", "fixture.template.market", 28, 30, _p2_mappings(["arcade_entry", "arcade_rear"], [arcade_entry, arcade_rear])),
			_variant("fixture.variant.courtyard.station_plot", "fixture.template.courtyard", 20, 24, _p3_mappings(["station_entry", "station_wing", "station_yard"], [station_entry, station_wing, station_yard])),
			_variant("fixture.variant.courtyard.garden_plot", "fixture.template.courtyard", 36, 24, _p2_mappings(["garden_entry", "garden_rear"], [garden_entry, garden_rear])),
			_variant("fixture.variant.tower.workshop_plot", "fixture.template.tower", 20, 30, _p2_mappings(["workshop_entry", "workshop_rear"], [workshop_entry, workshop_rear])),
			_variant("fixture.variant.tower.tower_plot", "fixture.template.tower", 36, 30, _p2_mappings(["tower_entry", "tower_rear"], [tower_entry, tower_rear])),
		],
		[_fixed_block("fixture.fixed.civic_monument", [monument_occupant])],
		[_road("fixture.road.two_lane_p6", 6)],
		[_source("gateway_market_north", "market_hall", "NORTH"), _source("gateway_canal_east", "canal_plot", "EAST"), _source("gateway_tower_south", "tower_plot", "SOUTH"), _source("gateway_workshop_west", "workshop_plot", "WEST")],
		"fixture.road.two_lane_p6"
	)


func _root(layout_id: String, row_sizes: Array, column_sizes: Array, slots: Array, templates: Array, variants: Array, fixed_blocks: Array, roads: Array, sources: Array, road_profile_id: String) -> Dictionary:
	return {
		"definition_schema_version": 1,
		"layout_definition_version": 1,
		"canonical_schema_version": 1,
		"resolver_schema_version": 1,
		"layout": {
			"layout_id": layout_id,
			"physical_elevation_range": {"minimum_elevation": ROOT_MINIMUM_ELEVATION, "maximum_elevation": ROOT_MAXIMUM_ELEVATION},
			"row_tracks": _tracks("row", row_sizes),
			"column_tracks": _tracks("col", column_sizes),
			"horizontal_boundaries": _boundaries("h", row_sizes.size() + 1),
			"vertical_boundaries": _boundaries("v", column_sizes.size() + 1),
			"slots": slots,
			"outer_ring": {"complete": true, "permanent": true, "road_profile_id": road_profile_id},
			"arrival_sources": sources,
		},
		"template_catalog": templates,
		"variant_catalog": variants,
		"fixed_block_catalog": fixed_blocks,
		"road_profile_catalog": roads,
	}


func _tracks(prefix: String, sizes: Array) -> Array:
	var tracks: Array = []
	for index: int in range(sizes.size()):
		tracks.append({"track_id": "%s_%d" % [prefix, index], "ordinal": index, "size": int(sizes[index])})
	return tracks


func _boundaries(prefix: String, count: int) -> Array:
	var boundaries: Array = []
	for index: int in range(count):
		boundaries.append({"boundary_id": "%s%d" % [prefix, index], "ordinal": index})
	return boundaries


func _slot(slot_id: String, ordinal: int, row_track_id: String, column_track_id: String, role: String, template_id: Variant, variant_id: Variant, fixed_block_id: Variant, sections: Array, occupants: Array, cap: Variant) -> Dictionary:
	var buildability: Array = []
	if role == "PLOT":
		var cells: Dictionary = {}
		for section: Dictionary in sections:
			for cell: Array in section["mask"]:
				cells["%d,%d" % [cell[0], cell[1]]] = cell
		buildability = _sorted_cells(cells.values())
	return {
		"slot_id": slot_id,
		"ordinal": ordinal,
		"row_track_id": row_track_id,
		"column_track_id": column_track_id,
		"role": role,
		"template_id": template_id,
		"selected_variant_id": variant_id,
		"fixed_block_definition_id": fixed_block_id,
		"sections": sections,
		"buildability_mask": buildability,
		"fixed_occupants": occupants,
		"physical_elevation_cap_override": cap,
	}


func _section(section_id: String, section_role: String, ordinal: int, mask: Array, initially_owned: bool, initially_available: bool, initially_entry_eligible: bool) -> Dictionary:
	return {
		"section_id": section_id,
		"section_role": section_role,
		"ordinal": ordinal,
		"mask": mask,
		"initially_owned": initially_owned,
		"initially_available": initially_available,
		"initially_entry_eligible": initially_entry_eligible,
	}


func _occupant(occupant_id: String, ordinal: int, elevation_masks: Array) -> Dictionary:
	return {"occupant_id": occupant_id, "ordinal": ordinal, "elevation_masks": elevation_masks}


func _fixed_block(definition_id: String, occupants: Array) -> Dictionary:
	return {"fixed_block_definition_id": definition_id, "fixed_block_definition_version": 1, "fixed_occupants": occupants}


func _template(template_id: String, cap: Variant, variant_ids: Array) -> Dictionary:
	return {"template_id": template_id, "template_version": 1, "physical_elevation_cap": cap, "variant_ids": variant_ids}


func _variant(variant_id: String, template_id: String, width: int, depth: int, mappings: Array) -> Dictionary:
	return {"variant_id": variant_id, "template_id": template_id, "template_version": 1, "width": width, "depth": depth, "section_mappings": mappings}


func _p2_mappings(ids: Array, masks: Array) -> Array:
	return [{"section_role": "ENTRY", "ordinal": 0, "mask": masks[0]}, {"section_role": "REAR", "ordinal": 1, "mask": masks[1]}]


func _p3_mappings(ids: Array, masks: Array) -> Array:
	return [{"section_role": "ENTRY", "ordinal": 0, "mask": masks[0]}, {"section_role": "REAR", "ordinal": 1, "mask": masks[1]}, {"section_role": "COURT", "ordinal": 2, "mask": masks[2]}]


func _road(road_profile_id: String, pedestrian_width: int) -> Dictionary:
	return {
		"road_profile_id": road_profile_id,
		"road_profile_version": 1,
		"pedestrian_width": pedestrian_width,
		"carriageways": [{"ordinal": 0, "lanes": [{"ordinal": 0, "direction": "FORWARD", "width": 3}, {"ordinal": 1, "direction": "REVERSE", "width": 3}]}],
	}


func _source(source_id: String, slot_id: String, side: String) -> Dictionary:
	return {
		"arrival_source_id": source_id,
		"mode": "PEDESTRIAN",
		"selector": {"kind": "OUTER_PEDESTRIAN_BAND", "slot_id": slot_id, "side": side},
		"initially_enabled": true,
		"capacity": null,
		"weight": null,
		"schedule": [],
		"presentation": {},
	}


func _cap(minimum: int, maximum: int) -> Dictionary:
	return {"minimum_elevation": minimum, "maximum_elevation": maximum}


func _rectangle_mask(width: int, depth: int, offset_x: int = 0, offset_y: int = 0) -> Array:
	var cells: Array = []
	for y: int in range(offset_y, offset_y + depth):
		for x: int in range(offset_x, offset_x + width):
			cells.append([x, y])
	return cells


func _union(first: Array, second: Array) -> Array:
	var cells: Dictionary = {}
	for cell: Array in first:
		cells["%d,%d" % [cell[0], cell[1]]] = cell
	for cell: Array in second:
		cells["%d,%d" % [cell[0], cell[1]]] = cell
	return _sorted_cells(cells.values())


func _p2(width: int, depth: int, index: int) -> Array:
	var half: int = floori(float(width) / 2.0)
	var third: int = floori(float(depth) / 3.0)
	if index == 0:
		return _union(_rectangle_mask(half, depth), _rectangle_mask(width - half, third, half, 0))
	return _rectangle_mask(width - half, depth - third, half, third)


func _p3(width: int, depth: int, index: int) -> Array:
	var first: int = floori(float(width) / 3.0)
	var second: int = floori(float(width) * 2.0 / 3.0)
	var middle: int = floori(float(depth) / 2.0)
	if index == 0:
		return _union(_rectangle_mask(first, depth), _rectangle_mask(second - first, middle, first, 0))
	if index == 1:
		return _rectangle_mask(second - first, depth - middle, first, middle)
	return _rectangle_mask(width - second, depth, second, 0)


func _sorted_cells(cells: Array) -> Array:
	var result: Array = cells.duplicate(true)
	result.sort_custom(func(a: Array, b: Array) -> bool:
		return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0])
	)
	return result
