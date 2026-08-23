## ZoneSplitterTest — Deterministic two-phase parcel-core and growth checks.
## Run with: godot --headless --path . -s res://tests/test_zone_splitter.gd
extends SceneTree


var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_perimeter_rectangle_creates_valid_cores_and_full_coverage()
	_test_residual_tiles_expand_from_cores()
	_test_internal_transit_provides_frontage_without_becoming_parcel_area()
	_test_single_row_component_is_rejected_without_a_valid_core()
	_test_interior_zone_without_frontage_is_rejected()
	_test_disconnected_source_zone_is_rejected()
	_test_input_order_and_seed_preserve_geometry()
	print("ZoneSplitter tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _make_context(width: int = 8, height: int = 8) -> Dictionary:
	var floor_grid := FloorGrid.new()
	floor_grid.initialize(width, height)
	for x: int in range(width):
		for y: int in range(height):
			var tile := floor_grid.get_tile(x, y)
			tile.owned = true
			tile.floor_built = true

	var plot := PlotData.new()
	plot.plot_id = "test_plot"
	plot.boundary = Rect2i(0, 0, width, height)
	plot.pedestrian_boundary = Rect2i(-2, -2, width + 4, height + 4)
	return {"floor_grid": floor_grid, "plot": plot}


func _make_zone(tiles: Array[Vector2i], typologies: Dictionary = {}, layout_seed: int = 0) -> ZoneData:
	var zone := ZoneData.new()
	zone.id = "zone_test"
	zone.plot_id = "test_plot"
	zone.type = "Retail"
	zone.floor = "G"
	zone.tiles = tiles
	zone.typologies = typologies
	zone.parcel_layout_seed = layout_seed
	return zone


func _test_perimeter_rectangle_creates_valid_cores_and_full_coverage() -> void:
	var context := _make_context(6, 6)
	var tiles: Array[Vector2i] = []
	for y: int in range(6):
		for x: int in range(6):
			tiles.append(Vector2i(x, y))
	var result := ZoneSplitter.split(_make_zone(tiles), context.floor_grid, context.plot)
	_assert(result.is_success(), "perimeter rectangle succeeds")
	_assert(result.parcels.size() == 6, "perimeter rectangle creates the target six parcel cores")
	_assert(result.residual_tiles.is_empty(), "perimeter rectangle leaves no residual tenant tiles")
	var covered_tiles: Dictionary = {}
	for parcel: Parcel in result.parcels:
		_assert_valid_core(parcel, 6)
		_assert(parcel.frontage_edges.size() > 0, "each final parcel has a tenant-door candidate")
		_assert(_is_connected(parcel.tiles), "each final parcel remains 4-connected")
		for tile: Vector2i in parcel.tiles:
			covered_tiles[tile] = true
	_assert(covered_tiles.size() == tiles.size(), "final parcels cover every reachable Tenant tile")


func _test_residual_tiles_expand_from_cores() -> void:
	var context := _make_context(7, 2)
	var tiles: Array[Vector2i] = []
	for x: int in range(7):
		tiles.append(Vector2i(x, 0))
	for x: int in [0, 1, 2, 4, 5, 6]:
		tiles.append(Vector2i(x, 1))
	var result := ZoneSplitter.split(_make_zone(tiles, {}, 137), context.floor_grid, context.plot)
	_assert(result.is_success(), "core-and-growth zone succeeds")
	_assert(result.parcels.size() == 2, "two Retail cores are allocated before growth")
	_assert(result.residual_tiles.is_empty(), "reachable residual Tenant tiles are absorbed")
	var covered_tiles: Dictionary = {}
	var has_expanded_parcel := false
	for parcel: Parcel in result.parcels:
		_assert_valid_core(parcel, 6)
		if parcel.area > parcel.core_tiles.size():
			has_expanded_parcel = true
		for tile: Vector2i in parcel.tiles:
			covered_tiles[tile] = true
	_assert(has_expanded_parcel, "a parcel grows beyond its rectangular core")
	_assert(covered_tiles.size() == tiles.size(), "growth claims every reachable Tenant tile")


func _test_internal_transit_provides_frontage_without_becoming_parcel_area() -> void:
	var context := _make_context()
	var tiles: Array[Vector2i] = []
	var typologies: Dictionary = {}
	for x: int in range(1, 7):
		var transit := Vector2i(x, 1)
		tiles.append(transit)
		typologies[transit] = GridTile.TileTypology.TRANSIT
		for y: int in range(2, 4):
			tiles.append(Vector2i(x, y))
	var result := ZoneSplitter.split(_make_zone(tiles, typologies), context.floor_grid, context.plot)
	_assert(result.is_success(), "internal Transit frontage succeeds")
	_assert(result.parcels.size() == 2, "internal Transit frontage yields two valid Retail cores")
	for parcel: Parcel in result.parcels:
		_assert_valid_core(parcel, 6)
		_assert(
			not parcel.tiles.any(func(tile: Vector2i) -> bool: return typologies.get(tile) == GridTile.TileTypology.TRANSIT),
			"Transit is excluded from final parcel geometry"
		)
		_assert(
			parcel.frontage_edges.any(func(edge: Dictionary) -> bool: return edge.get("access_kind") == "internal_transit"),
			"Transit creates directed frontage metadata"
		)


func _test_single_row_component_is_rejected_without_a_valid_core() -> void:
	var context := _make_context(6, 1)
	var tiles: Array[Vector2i] = []
	for x: int in range(6):
		tiles.append(Vector2i(x, 0))
	var result := ZoneSplitter.split(_make_zone(tiles), context.floor_grid, context.plot)
	_assert(
		result.status == SplitResult.Status.INSUFFICIENT_RENTABLE_SPACE,
		"single-row Tenant component is rejected because no 2x2 core exists"
	)


func _test_interior_zone_without_frontage_is_rejected() -> void:
	var context := _make_context()
	var tiles: Array[Vector2i] = [
		Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4),
		Vector2i(4, 4), Vector2i(3, 5), Vector2i(4, 5),
	]
	var result := ZoneSplitter.split(_make_zone(tiles), context.floor_grid, context.plot)
	_assert(result.status == SplitResult.Status.NO_VALID_FRONTAGE, "interior zone without circulation is rejected")
	_assert(result.parcels.is_empty(), "rejected zone returns no parcel")


func _test_disconnected_source_zone_is_rejected() -> void:
	var context := _make_context()
	var tiles: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
		Vector2i(6, 6), Vector2i(7, 6), Vector2i(7, 7),
	]
	var result := ZoneSplitter.split(_make_zone(tiles), context.floor_grid, context.plot)
	_assert(result.status == SplitResult.Status.INVALID_ZONE_GEOMETRY, "disconnected source zone is rejected")


func _test_input_order_and_seed_preserve_geometry() -> void:
	var context := _make_context(7, 2)
	var ordered: Array[Vector2i] = []
	for x: int in range(7):
		ordered.append(Vector2i(x, 0))
	for x: int in [0, 1, 2, 4, 5, 6]:
		ordered.append(Vector2i(x, 1))
	var reversed := ordered.duplicate()
	reversed.reverse()
	var first := ZoneSplitter.split(_make_zone(ordered, {}, 943), context.floor_grid, context.plot)
	var second := ZoneSplitter.split(_make_zone(reversed, {}, 943), context.floor_grid, context.plot)
	_assert(first.is_success() and second.is_success(), "both input orders split successfully")
	_assert(first.parcels.size() == second.parcels.size(), "input order preserves parcel count")
	_assert(
		_parcel_geometry_signature(first.parcels) == _parcel_geometry_signature(second.parcels),
		"input order and layout seed preserve core and final parcel geometry"
	)


func _assert_valid_core(parcel: Parcel, minimum_area: int) -> void:
	_assert(parcel.core_bounds.size.x >= 2, "each core is at least two tiles wide")
	_assert(parcel.core_bounds.size.y >= 2, "each core is at least two tiles deep")
	_assert(parcel.core_tiles.size() >= minimum_area, "each core meets the zone-type minimum area")
	_assert(
		parcel.core_bounds.size.x * parcel.core_bounds.size.y == parcel.core_tiles.size(),
		"each core is rectangular"
	)
	for core_tile: Vector2i in parcel.core_tiles:
		_assert(parcel.tiles.has(core_tile), "each final parcel retains every core tile")


func _is_connected(tiles: Array[Vector2i]) -> bool:
	if tiles.is_empty():
		return false
	var remaining: Dictionary = {}
	for tile: Vector2i in tiles:
		remaining[tile] = true
	var stack: Array[Vector2i] = [tiles[0]]
	var visited: Dictionary = {}
	while not stack.is_empty():
		var tile: Vector2i = stack.pop_back()
		if visited.has(tile):
			continue
		visited[tile] = true
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor := tile + direction
			if remaining.has(neighbor) and not visited.has(neighbor):
				stack.append(neighbor)
	return visited.size() == remaining.size()


func _parcel_geometry_signature(parcels: Array[Parcel]) -> String:
	var parts: Array[String] = []
	for parcel: Parcel in parcels:
		parts.append("core=%s;final=%s" % [parcel.core_tiles, parcel.tiles])
	return "|".join(parts)
