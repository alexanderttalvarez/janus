## ZoneManagerSplitCommitTest — Atomic ZoneManager integration checks.
## Run with: godot --headless --path . res://tests/test_zone_manager_split_commit.tscn
extends Node


var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	var context := _make_world()
	_test_successful_creation_commits_parcels(context)
	_test_inter_zone_frontage_cannot_be_a_door(context)
	_test_manual_doors_cannot_cross_zones(context)
	_test_adjacent_zone_cannot_block_existing_door(context)
	_test_successful_edit_reassigns_debug_subtypes(context)
	_test_preview_split_is_non_mutating(context)
	_test_create_zone_rejects_implicit_only_frontage(context)
	_test_door_count_and_selection_preservation(context)
	_test_rejected_edit_leaves_committed_zone_unchanged(context)
	print("ZoneManager split commit tests: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _make_world() -> Dictionary:
	var world := Node.new()
	world.name = "World"
	add_child(world)

	var grid_manager := GridManager.new()
	grid_manager.name = "GridManager"
	world.add_child(grid_manager)
	var zone_manager := ZoneManager.new()
	zone_manager.name = "ZoneManager"
	world.add_child(zone_manager)

	var plot := grid_manager.create_plot("test_plot", 20, 20)
	var floor_grid := plot.get_floor(GridManager.GROUND_FLOOR)
	for x: int in range(floor_grid.width):
		for y: int in range(floor_grid.height):
			var tile := floor_grid.get_tile(x, y)
			tile.owned = true
			tile.floor_built = true
	return {"grid_manager": grid_manager, "zone_manager": zone_manager}


func _test_successful_creation_commits_parcels(context: Dictionary) -> void:
	var tiles: Array[Vector2i] = []
	for y in range(2, 8):
		for x in range(2, 8):
			tiles.append(Vector2i(x, y))
	var zone_manager: ZoneManager = context.zone_manager
	var grid_manager: GridManager = context.grid_manager
	_set_external_circulation_frame(grid_manager, Rect2i(2, 2, 6, 6))
	var zone := zone_manager.create_zone("Retail", tiles, "G", "test_plot")
	_assert(zone != null, "fronted zone creation succeeds")
	if zone == null:
		return
	_assert(zone.plot_id == "test_plot", "zone persists explicit plot ownership")
	_assert(zone.parcel_layout_seed > 0, "zone commit allocates a persistent parcel layout seed")
	_assert(zone.parcels.size() == 6, "physical external circulation enables the six legal Retail cores")
	var ids: Dictionary = {}
	var display_numbers: Dictionary = {}
	for parcel: Parcel in zone.parcels:
		ids[parcel.id] = true
		display_numbers[parcel.display_number] = true
		_assert(parcel.display_number > 0, "committed parcel display number is positive")
		_assert(parcel.core_bounds.size.x >= 2, "committed core is at least two tiles wide")
		_assert(parcel.core_bounds.size.y >= 2, "committed core is at least two tiles deep")
		_assert(parcel.core_tiles.size() >= 6, "committed Retail core meets the six-tile minimum")
	_assert(ids.size() == zone.parcels.size(), "committed parcel IDs are globally unique")
	_assert(display_numbers.size() == zone.parcels.size(), "committed parcel display numbers are globally unique")
	var serialized_zones: Dictionary = zone_manager.serialize().get("zones", {})
	var serialized_zone: Dictionary = serialized_zones.get(zone.id, {})
	_assert(
		int(serialized_zone.get("parcel_layout_seed", 0)) == zone.parcel_layout_seed,
		"zone layout seed persists through ZoneManager serialization"
	)
	var first_tile := grid_manager.get_tile(2, 2, "test_plot", "G")
	_assert(first_tile.zone_id == zone.id, "grid markings are written only after successful split")
	_assert(zone_manager.last_assignment_result != null, "successful split produces a debug assignment result")
	_assert(not zone_manager.permits_tenant_lifecycle(), "DEBUG_IMMEDIATE mode disables tenant lifecycle handling")
	_assert(zone.subtype.is_empty(), "debug assignment does not write legacy zone subtype")
	for parcel: Parcel in zone.parcels:
		_assert(parcel.assigned_subtype_id.begins_with("retail."), "committed parcel receives a Retail subtype ID")
		var physical_positions := _physical_positions(parcel.frontage_edges)
		_assert(
			parcel.selected_door_edges.size() == ceili(float(physical_positions.size()) / 10.0),
			"committed parcel selects the required physical door count"
		)
		_assert(
			_physical_positions(parcel.selected_door_edges).size() == parcel.selected_door_edges.size(),
			"committed parcel selects at most one door per physical tile"
		)
		for edge: Dictionary in parcel.selected_door_edges:
			_assert(
				ZoneManager.PHYSICAL_DOOR_ACCESS_KINDS.has(edge.get("access_kind", "")),
				"selected door uses physical frontage only"
			)
		var restored_parcel := Parcel.deserialize(parcel.serialize())
		_assert(
			_door_edge_keys(restored_parcel.selected_door_edges) == _door_edge_keys(parcel.selected_door_edges),
			"selected door edges persist through parcel serialization"
		)
	for first_index: int in range(zone.parcels.size()):
		for second_index: int in range(first_index + 1, zone.parcels.size()):
			var first_parcel: Parcel = zone.parcels[first_index]
			var second_parcel: Parcel = zone.parcels[second_index]
			if _share_edge(first_parcel, second_parcel):
				_assert(
					first_parcel.assigned_subtype_id != second_parcel.assigned_subtype_id,
					"edge-adjacent committed parcels receive distinct subtype IDs"
				)


func _test_inter_zone_frontage_cannot_be_a_door(context: Dictionary) -> void:
	var grid_manager: GridManager = context.grid_manager
	var existing_zone: ZoneData = context.zone_manager.zones.get("zone_1", null)
	if existing_zone == null or existing_zone.tiles.is_empty():
		_assert(false, "existing zone exists before inter-zone frontage test")
		return
	var candidate_zone := ZoneData.new()
	candidate_zone.id = "zone_2"
	candidate_zone.plot_id = "test_plot"
	candidate_zone.floor = "G"
	var floor_grid := grid_manager.get_floor_grid("test_plot", "G")
	var plot := grid_manager.get_plot("test_plot")
	var access_context := FloorAccessContext.new(floor_grid, plot)
	var access_tile: Vector2i = existing_zone.tiles[0]
	var access_kind := access_context.access_kind_for(access_tile, candidate_zone, {})
	_assert(access_kind.is_empty(), "frontage to another zone is not physical door access")


func _test_manual_doors_cannot_cross_zones(context: Dictionary) -> void:
	var grid_manager: GridManager = context.grid_manager
	var existing_zone: ZoneData = context.zone_manager.zones.get("zone_1", null)
	if existing_zone == null or existing_zone.tiles.is_empty():
		_assert(false, "existing zone exists before manual door validation test")
		return
	var from_pos: Vector2i = existing_zone.tiles[0]
	var to_pos := Vector2i.ZERO
	var found_neighbor := false
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var candidate := from_pos + direction
		if grid_manager.get_floor_grid("test_plot", "G").is_valid_tile(candidate.x, candidate.y) and not existing_zone.tiles.has(candidate):
			to_pos = candidate
			found_neighbor = true
			break
	if not found_neighbor:
		_assert(false, "manual door validation has an adjacent external tile")
		return
	var from_tile := grid_manager.get_tile(from_pos.x, from_pos.y, "test_plot", "G")
	var to_tile := grid_manager.get_tile(to_pos.x, to_pos.y, "test_plot", "G")
	var original_typology := from_tile.typology
	from_tile.typology = GridTile.TileTypology.TRANSIT
	to_tile.zone_id = existing_zone.id
	to_tile.typology = GridTile.TileTypology.TRANSIT
	_assert(
		not grid_manager.can_place_door_between(from_pos, to_pos, "test_plot", "G"),
		"manual doors cannot connect Transit tiles within the same zone"
	)
	to_tile.zone_id = "zone_other"
	to_tile.typology = GridTile.TileTypology.TENANT
	to_tile.element = GridTile.TileElement.NONE
	_assert(
		not grid_manager.can_place_door_between(from_pos, to_pos, "test_plot", "G"),
		"manual doors cannot connect Transit to a non-Transit tile in another zone"
	)
	to_tile.typology = GridTile.TileTypology.TRANSIT
	_assert(
		grid_manager.can_place_door_between(from_pos, to_pos, "test_plot", "G"),
		"manual doors can connect Transit tiles across different zones"
	)
	to_tile.zone_id = ""
	to_tile.typology = GridTile.TileTypology.TENANT
	to_tile.element = GridTile.TileElement.CIRCULATION
	_assert(
		grid_manager.can_place_door_between(from_pos, to_pos, "test_plot", "G"),
		"manual Transit doors can connect to external circulation"
	)
	from_tile.typology = original_typology
	to_tile.element = GridTile.TileElement.CIRCULATION


func _test_adjacent_zone_cannot_block_existing_door(context: Dictionary) -> void:
	var zone_manager: ZoneManager = context.zone_manager
	var grid_manager: GridManager = context.grid_manager
	var existing_zone: ZoneData = zone_manager.zones.get("zone_1", null)
	if existing_zone == null or existing_zone.parcels.is_empty():
		_assert(false, "existing zone exists before adjacent blocking test")
		return
	var source_parcel: Parcel = existing_zone.parcels[0]
	if source_parcel.selected_door_edges.is_empty():
		_assert(false, "existing parcel has a selected door before adjacent blocking test")
		return
	var blocked_edge: Dictionary = source_parcel.selected_door_edges[0]
	var blocked_access: Vector2i = blocked_edge.get("access", Vector2i.ZERO)
	var blocked_direction: Vector2i = blocked_edge.get("direction", Vector2i.UP)
	var forward := Vector2i(signi(blocked_direction.x), signi(blocked_direction.y))
	var side := Vector2i.DOWN if forward.x != 0 else Vector2i.RIGHT
	var blocked_tiles: Array[Vector2i] = []
	for depth: int in range(2):
		for width: int in range(3):
			var candidate_tile := blocked_access + forward * depth + side * width
			if existing_zone.tiles.has(candidate_tile):
				continue
			blocked_tiles.append(candidate_tile)
	if blocked_tiles.size() < 6:
		_assert(false, "adjacent blocking candidate has enough tiles")
		return
	var original_door_keys := _door_edge_keys(source_parcel.selected_door_edges)
	var original_zone_count := zone_manager.zones.size()
	var original_serialized := zone_manager.serialize()
	var preview := zone_manager.preview_split("Retail", blocked_tiles, "G", "test_plot")
	_assert(
		preview.status == SplitResult.Status.EXISTING_DOOR_INVALIDATED,
		"preview rejects a new zone that blocks an existing door"
	)
	_assert(
		preview.diagnostics.size() == 1 and preview.diagnostics[0].begins_with("EXISTING_DOOR_INVALIDATED"),
		"preview reports the blocked existing door"
	)
	var rejected := zone_manager.create_zone("Retail", blocked_tiles, "G", "test_plot")
	_assert(rejected == null, "adjacent zone blocking an existing door is rejected")
	_assert(zone_manager.zones.size() == original_zone_count, "blocked-door rejection creates no new zone")
	_assert(
		_door_edge_keys(source_parcel.selected_door_edges) == original_door_keys,
		"blocked-door rejection preserves the previous door"
	)
	_assert(
		zone_manager.serialize() == original_serialized,
		"blocked-door rejection preserves committed zone and counter state"
	)
	_assert(
		grid_manager.get_tile(blocked_access.x, blocked_access.y, "test_plot", "G").zone_id.is_empty(),
		"blocked-door rejection preserves the access tile"
	)


func _test_successful_edit_reassigns_debug_subtypes(context: Dictionary) -> void:
	var zone_manager: ZoneManager = context.zone_manager
	var zone: ZoneData = zone_manager.zones.get("zone_1", null)
	if zone == null or zone.parcels.is_empty():
		_assert(false, "successful zone exists before successful edit")
		return
	var preview := zone_manager.preview_split(
		zone.type, zone.tiles, zone.floor, zone.plot_id, zone.typologies, zone.id
	)
	_assert(preview.is_success(), "edit preview uses the prospective physical-door transaction")
	_assert(
		_parcel_geometry_keys(preview.parcels) == _parcel_geometry_keys(zone.parcels),
		"edit preview uses the committed zone layout seed"
	)
	var original_display_numbers: Dictionary = {}
	var original_selected_door_keys: Dictionary = {}
	var original_layout_seed := zone.parcel_layout_seed
	for parcel: Parcel in zone.parcels:
		original_display_numbers[parcel.id] = parcel.display_number
		original_selected_door_keys[parcel.id] = _door_edge_keys(parcel.selected_door_edges)
	zone.parcels[0].assigned_subtype_id = "stale.subtype"
	var updated := zone_manager.modify_zone(zone.id, zone.tiles, "test_plot", zone.typologies)
	_assert(updated != null, "valid edit commits successfully")
	if updated == null:
		return
	_assert(
		updated.parcels[0].assigned_subtype_id != "stale.subtype",
		"successful edit recalculates parcel subtype assignments"
	)
	_assert(updated.subtype.is_empty(), "successful debug edit leaves legacy zone subtype untouched")
	_assert(updated.parcel_layout_seed == original_layout_seed, "successful edit preserves the parcel layout seed")
	for parcel: Parcel in updated.parcels:
		_assert(
			parcel.display_number == original_display_numbers.get(parcel.id, 0),
			"matched parcel retains its display number after a successful edit"
		)
		_assert(
			_door_edge_keys(parcel.selected_door_edges) == original_selected_door_keys.get(parcel.id, []),
			"matched parcel preserves legal selected doors after a successful edit"
		)


func _test_preview_split_is_non_mutating(context: Dictionary) -> void:
	var zone_manager: ZoneManager = context.zone_manager
	var grid_manager: GridManager = context.grid_manager
	var existing_zone: ZoneData = zone_manager.zones.get("zone_1", null)
	if existing_zone == null:
		_assert(false, "successful zone exists before preview validation")
		return
	var committed_zone_count := zone_manager.zones.size()
	var committed_tile_count := existing_zone.tiles.size()
	var last_status := zone_manager.last_split_result.status
	var first_tile := grid_manager.get_tile(2, 2, "test_plot", "G")
	var committed_zone_id := first_tile.zone_id
	var interior_tiles: Array[Vector2i] = [
		Vector2i(14, 14), Vector2i(15, 14), Vector2i(14, 15),
		Vector2i(15, 15), Vector2i(14, 16), Vector2i(15, 16),
	]
	var preview := zone_manager.preview_split("Retail", interior_tiles, "G", "test_plot")
	_assert(
		preview.status == SplitResult.Status.NO_PHYSICAL_DOOR_FRONTAGE,
		"preview reports missing physical door frontage"
	)
	_assert(not preview.parcels.is_empty(), "physical-door preview retains parcel evidence for diagnostics")
	_assert(zone_manager.zones.size() == committed_zone_count, "preview creates no zone")
	_assert(existing_zone.tiles.size() == committed_tile_count, "preview preserves committed zone data")
	_assert(first_tile.zone_id == committed_zone_id, "preview preserves grid markings")
	_assert(zone_manager.last_split_result.status == last_status, "preview preserves last committed result")


func _test_create_zone_rejects_implicit_only_frontage(context: Dictionary) -> void:
	var zone_manager: ZoneManager = context.zone_manager
	var grid_manager: GridManager = context.grid_manager
	var implicit_tiles: Array[Vector2i] = [
		Vector2i(14, 14), Vector2i(15, 14), Vector2i(14, 15),
		Vector2i(15, 15), Vector2i(14, 16), Vector2i(15, 16),
	]
	var zones_before := zone_manager.zones.size()
	var rejected_zone := zone_manager.create_zone("Retail", implicit_tiles, "G", "test_plot")
	_assert(rejected_zone == null, "implicit-only frontage cannot commit a parcel door")
	_assert(
		zone_manager.last_split_result.status == SplitResult.Status.NO_PHYSICAL_DOOR_FRONTAGE,
		"implicit-only frontage reports the physical-door failure"
	)
	_assert(zone_manager.zones.size() == zones_before, "physical-door rejection creates no zone")
	_assert(
		grid_manager.get_tile(14, 14, "test_plot", "G").zone_id.is_empty(),
		"physical-door rejection leaves grid markings unchanged"
	)


func _test_door_count_and_selection_preservation(context: Dictionary) -> void:
	var zone_manager: ZoneManager = context.zone_manager
	for test_case: Dictionary in [
		{"positions": 1, "doors": 1},
		{"positions": 10, "doors": 1},
		{"positions": 11, "doors": 2},
		{"positions": 20, "doors": 2},
		{"positions": 21, "doors": 3},
		{"positions": 30, "doors": 3},
	]:
		var position_count: int = test_case.get("positions", 0)
		var expected_doors: int = test_case.get("doors", 0)
		var parcel := _make_physical_frontage_parcel("count_%d" % position_count, position_count)
		_assert(
			zone_manager._assign_selected_door_edges([parcel], []),
			"physical candidates can allocate deterministic parcel doors"
		)
		_assert(
			parcel.selected_door_edges.size() == expected_doors,
			"%d physical positions allocate %d doors" % [position_count, expected_doors]
		)
		_assert(
			_physical_positions(parcel.selected_door_edges).size() == expected_doors,
			"allocated door positions remain unique"
		)

	var internal_transit_parcel := _make_physical_frontage_parcel("internal_transit", 1, "internal_transit")
	_assert(
		zone_manager._assign_selected_door_edges([internal_transit_parcel], []),
		"same-zone internal Transit frontage can allocate a parcel door"
	)
	_assert(
		internal_transit_parcel.selected_door_edges[0].get("access_kind", "") == "internal_transit",
		"internal Transit selection keeps its physical access kind"
	)

	var one_door_mixed := Parcel.new()
	one_door_mixed.id = "one_door_mixed"
	one_door_mixed.set_geometry(
		[Vector2i(0, 0)],
		[
			{"tile": Vector2i(0, 0), "direction": Vector2i.DOWN, "access": Vector2i(0, 1), "access_kind": "external_circulation"},
			{"tile": Vector2i(0, 0), "direction": Vector2i.UP, "access": Vector2i(0, -1), "access_kind": "internal_transit", "transit_area_key": "transit:a"},
		]
	)
	_assert(zone_manager._assign_selected_door_edges([one_door_mixed], []), "mixed one-door frontage allocates")
	_assert(
		one_door_mixed.selected_door_edges[0].get("access_kind", "") == "internal_transit",
		"one-door frontage prefers internal Transit"
	)

	var two_door_mixed := Parcel.new()
	two_door_mixed.id = "two_door_mixed"
	var mixed_tiles: Array[Vector2i] = []
	var mixed_edges: Array[Dictionary] = []
	for index: int in range(11):
		var mixed_tile := Vector2i(index, 0)
		mixed_tiles.append(mixed_tile)
		mixed_edges.append({
			"tile": mixed_tile,
			"direction": Vector2i.UP,
			"access": mixed_tile + Vector2i.UP,
			"access_kind": "internal_transit",
			"transit_area_key": "transit:a",
		})
	mixed_edges.append({
		"tile": Vector2i(10, 0),
		"direction": Vector2i.DOWN,
		"access": Vector2i(10, 1),
		"access_kind": "external_circulation",
	})
	two_door_mixed.set_geometry(mixed_tiles, mixed_edges)
	_assert(zone_manager._assign_selected_door_edges([two_door_mixed], []), "two-door mixed frontage allocates")
	_assert(
		two_door_mixed.selected_door_edges[0].get("access_kind", "") == "internal_transit",
		"first door prefers internal Transit"
	)
	_assert(
		two_door_mixed.selected_door_edges[1].get("access_kind", "") == "external_circulation",
		"second door prefers external circulation"
	)

	var transit_fallback := Parcel.new()
	transit_fallback.id = "transit_fallback"
	var transit_tiles: Array[Vector2i] = []
	var transit_edges: Array[Dictionary] = []
	for index: int in range(11):
		var transit_tile := Vector2i(index, 0)
		transit_tiles.append(transit_tile)
		transit_edges.append({
			"tile": transit_tile,
			"direction": Vector2i.UP,
			"access": transit_tile + Vector2i.UP,
			"access_kind": "internal_transit",
			"transit_area_key": "transit:a" if index < 10 else "transit:b",
		})
	transit_fallback.set_geometry(transit_tiles, transit_edges)
	_assert(zone_manager._assign_selected_door_edges([transit_fallback], []), "Transit-only two-door frontage allocates")
	_assert(
		_transit_area_keys(transit_fallback.selected_door_edges).size() == 2,
		"second door prefers a different internal Transit area when external is unavailable"
	)

	var previous := _make_physical_frontage_parcel("preserved", 20)
	previous.selected_door_edges = [previous.frontage_edges[15].duplicate()]
	var edited := _make_physical_frontage_parcel("preserved", 20)
	_assert(
		zone_manager._assign_selected_door_edges([edited], [previous]),
		"edited parcel allocates physical doors"
	)
	_assert(
		_door_edge_keys(edited.selected_door_edges).has(_door_edge_key(previous.selected_door_edges[0])),
		"edited parcel preserves a still-legal selected door"
	)


func _test_rejected_edit_leaves_committed_zone_unchanged(context: Dictionary) -> void:
	var zone_manager: ZoneManager = context.zone_manager
	var grid_manager: GridManager = context.grid_manager
	var zone: ZoneData = zone_manager.zones.get("zone_1", null)
	if zone == null:
		_assert(false, "successful zone exists before rejected edit")
		return
	var committed_tile_count := zone.tiles.size()
	var committed_parcel_ids: Array[String] = []
	for parcel: Parcel in zone.parcels:
		committed_parcel_ids.append(parcel.id)

	var interior_tiles: Array[Vector2i] = [
		Vector2i(14, 14), Vector2i(15, 14), Vector2i(14, 15),
		Vector2i(15, 15), Vector2i(14, 16), Vector2i(15, 16),
	]
	var interior_set: Dictionary = {}
	for tile_pos: Vector2i in interior_tiles:
		interior_set[tile_pos] = true
	for tile_pos: Vector2i in interior_tiles:
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor := tile_pos + direction
			if not interior_set.has(neighbor):
				grid_manager.get_tile(neighbor.x, neighbor.y, "test_plot", "G").owned = false
	var rejected := zone_manager.modify_zone(zone.id, interior_tiles, "test_plot")
	_assert(rejected == null, "interior edit without frontage is rejected")
	_assert(zone_manager.last_split_result.status == SplitResult.Status.NO_VALID_FRONTAGE, "rejected edit reports no frontage")
	_assert(zone.tiles.size() == committed_tile_count, "rejected edit leaves zone tile data unchanged")
	var retained_ids: Array[String] = []
	for parcel: Parcel in zone.parcels:
		retained_ids.append(parcel.id)
	_assert(retained_ids == committed_parcel_ids, "rejected edit leaves parcel IDs unchanged")
	var first_tile := grid_manager.get_tile(2, 2, "test_plot", "G")
	_assert(first_tile.zone_id == zone.id, "rejected edit leaves committed grid markings unchanged")


func _set_external_circulation_frame(grid_manager: GridManager, bounds: Rect2i) -> void:
	for y: int in range(bounds.position.y - 1, bounds.end.y + 1):
		for x: int in range(bounds.position.x - 1, bounds.end.x + 1):
			if x != bounds.position.x - 1 and x != bounds.end.x and y != bounds.position.y - 1 and y != bounds.end.y:
				continue
			grid_manager.get_tile(x, y, "test_plot", "G").element = GridTile.TileElement.CIRCULATION


func _make_physical_frontage_parcel(
	parcel_id: String, position_count: int, access_kind: String = "external_circulation"
) -> Parcel:
	var parcel := Parcel.new()
	parcel.id = parcel_id
	var tiles: Array[Vector2i] = []
	var frontage_edges: Array[Dictionary] = []
	for index: int in range(position_count):
		var tile := Vector2i(index, 0)
		tiles.append(tile)
		frontage_edges.append({
			"tile": tile,
			"direction": Vector2i.DOWN,
			"access": tile + Vector2i.DOWN,
			"access_kind": access_kind,
		})
	parcel.set_geometry(tiles, frontage_edges)
	return parcel


func _physical_positions(edges: Array[Dictionary]) -> Dictionary:
	var positions: Dictionary = {}
	for edge: Dictionary in edges:
		if ZoneManager.PHYSICAL_DOOR_ACCESS_KINDS.has(edge.get("access_kind", "")):
			positions[edge.get("tile", Vector2i.ZERO)] = true
	return positions


func _parcel_geometry_keys(parcels: Array[Parcel]) -> Array[String]:
	var keys: Array[String] = []
	for parcel: Parcel in parcels:
		var tile_parts: Array[String] = []
		for tile: Vector2i in parcel.tiles:
			tile_parts.append("%d,%d" % [tile.x, tile.y])
		keys.append(";".join(tile_parts))
	keys.sort()
	return keys


func _door_edge_keys(edges: Array[Dictionary]) -> Array[String]:
	var keys: Array[String] = []
	for edge: Dictionary in edges:
		keys.append(_door_edge_key(edge))
	keys.sort()
	return keys


func _transit_area_keys(edges: Array[Dictionary]) -> Dictionary:
	var keys: Dictionary = {}
	for edge: Dictionary in edges:
		var area_key: String = edge.get("transit_area_key", "")
		if not area_key.is_empty():
			keys[area_key] = true
	return keys


func _door_edge_key(edge: Dictionary) -> String:
	var tile: Vector2i = edge.get("tile", Vector2i.ZERO)
	var direction: Vector2i = edge.get("direction", Vector2i.ZERO)
	var access: Vector2i = edge.get("access", Vector2i.ZERO)
	return "%d,%d|%d,%d|%d,%d|%s" % [
		tile.x, tile.y, direction.x, direction.y, access.x, access.y, edge.get("access_kind", "")
	]


func _share_edge(first: Parcel, second: Parcel) -> bool:
	var second_tiles: Dictionary = {}
	for tile_pos: Vector2i in second.tiles:
		second_tiles[tile_pos] = true
	for tile_pos: Vector2i in first.tiles:
		for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if second_tiles.has(tile_pos + offset):
				return true
	return false
