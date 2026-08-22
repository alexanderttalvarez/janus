## ZoneSplitterTest — Self-contained deterministic geometry checks.
## Run with: godot --headless --path . -s res://tests/test_zone_splitter.gd
extends SceneTree


var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_perimeter_rectangle_splits_into_fronted_rectangles()
	_test_internal_transit_provides_frontage_without_becoming_parcel_area()
	_test_interior_zone_without_frontage_is_rejected()
	_test_disconnected_source_zone_is_rejected()
	_test_input_order_does_not_change_geometry()
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


func _make_zone(tiles: Array[Vector2i], typologies: Dictionary = {}) -> ZoneData:
	var zone := ZoneData.new()
	zone.id = "zone_test"
	zone.plot_id = "test_plot"
	zone.type = "Retail"
	zone.floor = "G"
	zone.tiles = tiles
	zone.typologies = typologies
	return zone


func _test_perimeter_rectangle_splits_into_fronted_rectangles() -> void:
	var context := _make_context(6, 6)
	var tiles: Array[Vector2i] = []
	for y: int in range(6):
		for x: int in range(6):
			tiles.append(Vector2i(x, y))
	var result := ZoneSplitter.split(_make_zone(tiles), context.floor_grid, context.plot)
	_assert(result.is_success(), "perimeter rectangle succeeds")
	_assert(result.parcels.size() == 6, "perimeter rectangle creates the target six parcels")
	_assert(result.residual_tiles.is_empty(), "perimeter rectangle has no residual tenant tiles")
	for parcel: Parcel in result.parcels:
		_assert(parcel.area == 6, "each Retail parcel meets the six-tile minimum")
		_assert(parcel.frontage_edges.size() > 0, "each parcel has a tenant-door candidate")
		_assert(parcel.bounds.size.x * parcel.bounds.size.y == parcel.tiles.size(), "each parcel is rectangular")


func _test_internal_transit_provides_frontage_without_becoming_parcel_area() -> void:
	var context := _make_context()
	var tiles: Array[Vector2i] = []
	var typologies: Dictionary = {}
	for x: int in range(1, 7):
		var transit := Vector2i(x, 1)
		var tenant := Vector2i(x, 2)
		tiles.append(transit)
		tiles.append(tenant)
		typologies[transit] = GridTile.TileTypology.TRANSIT
	var result := ZoneSplitter.split(_make_zone(tiles, typologies), context.floor_grid, context.plot)
	_assert(result.is_success(), "internal Transit frontage succeeds")
	_assert(result.parcels.size() == 1, "internal Transit frontage yields one minimum parcel")
	var parcel: Parcel = result.parcels[0]
	_assert(not parcel.tiles.any(func(tile: Vector2i) -> bool: return typologies.get(tile) == GridTile.TileTypology.TRANSIT), "Transit is excluded from parcel geometry")
	_assert(parcel.frontage_edges.any(func(edge: Dictionary) -> bool: return edge.get("access_kind") == "internal_transit"), "Transit creates directed frontage metadata")


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


func _test_input_order_does_not_change_geometry() -> void:
	var context := _make_context(6, 6)
	var ordered: Array[Vector2i] = []
	for y: int in range(6):
		for x: int in range(6):
			ordered.append(Vector2i(x, y))
	var reversed := ordered.duplicate()
	reversed.reverse()
	var first := ZoneSplitter.split(_make_zone(ordered), context.floor_grid, context.plot)
	var second := ZoneSplitter.split(_make_zone(reversed), context.floor_grid, context.plot)
	_assert(first.is_success() and second.is_success(), "both input orders split successfully")
	_assert(first.parcels.size() == second.parcels.size(), "input order preserves parcel count")
	for index: int in range(first.parcels.size()):
		_assert(first.parcels[index].bounds == second.parcels[index].bounds, "input order preserves parcel bounds %d" % index)
