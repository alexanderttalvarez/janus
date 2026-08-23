## ZoneManagerSplitCommitTest — Atomic ZoneManager integration checks.
## Run with: godot --headless --path . res://tests/test_zone_manager_split_commit.tscn
extends Node


var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	var context := _make_world()
	_test_successful_creation_commits_parcels(context)
	_test_successful_edit_reassigns_debug_subtypes(context)
	_test_preview_split_is_non_mutating(context)
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

	var plot := grid_manager.create_plot("test_plot", 8, 8)
	var floor_grid := plot.get_floor(GridManager.GROUND_FLOOR)
	for x: int in range(floor_grid.width):
		for y: int in range(floor_grid.height):
			var tile := floor_grid.get_tile(x, y)
			tile.owned = true
			tile.floor_built = true
	return {"grid_manager": grid_manager, "zone_manager": zone_manager}


func _test_successful_creation_commits_parcels(context: Dictionary) -> void:
	var tiles: Array[Vector2i] = []
	for y: int in range(6):
		for x: int in range(6):
			tiles.append(Vector2i(x, y))
	var zone_manager: ZoneManager = context.zone_manager
	var grid_manager: GridManager = context.grid_manager
	var zone := zone_manager.create_zone("Retail", tiles, "G", "test_plot")
	_assert(zone != null, "fronted zone creation succeeds")
	if zone == null:
		return
	_assert(zone.plot_id == "test_plot", "zone persists explicit plot ownership")
	_assert(zone.parcel_layout_seed > 0, "zone commit allocates a persistent parcel layout seed")
	_assert(
		zone.parcels.size() == 4,
		"zone commit stores four legal 2x2+ Retail cores for the constrained frontage"
	)
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
	var first_tile := grid_manager.get_tile(0, 0, "test_plot", "G")
	_assert(first_tile.zone_id == zone.id, "grid markings are written only after successful split")
	_assert(zone_manager.last_assignment_result != null, "successful split produces a debug assignment result")
	_assert(not zone_manager.permits_tenant_lifecycle(), "DEBUG_IMMEDIATE mode disables tenant lifecycle handling")
	_assert(zone.subtype.is_empty(), "debug assignment does not write legacy zone subtype")
	for parcel: Parcel in zone.parcels:
		_assert(parcel.assigned_subtype_id.begins_with("retail."), "committed parcel receives a Retail subtype ID")
	for first_index: int in range(zone.parcels.size()):
		for second_index: int in range(first_index + 1, zone.parcels.size()):
			var first_parcel: Parcel = zone.parcels[first_index]
			var second_parcel: Parcel = zone.parcels[second_index]
			if _share_edge(first_parcel, second_parcel):
				_assert(
					first_parcel.assigned_subtype_id != second_parcel.assigned_subtype_id,
					"edge-adjacent committed parcels receive distinct subtype IDs"
				)


func _test_successful_edit_reassigns_debug_subtypes(context: Dictionary) -> void:
	var zone_manager: ZoneManager = context.zone_manager
	var zone: ZoneData = zone_manager.zones.get("zone_1", null)
	if zone == null or zone.parcels.is_empty():
		_assert(false, "successful zone exists before successful edit")
		return
	var original_display_numbers: Dictionary = {}
	var original_layout_seed := zone.parcel_layout_seed
	for parcel: Parcel in zone.parcels:
		original_display_numbers[parcel.id] = parcel.display_number
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
	var first_tile := grid_manager.get_tile(0, 0, "test_plot", "G")
	var committed_zone_id := first_tile.zone_id
	var interior_tiles: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2),
		Vector2i(2, 2), Vector2i(1, 3), Vector2i(2, 3),
	]
	var preview := zone_manager.preview_split("Retail", interior_tiles, "G", "test_plot")
	_assert(preview.status == SplitResult.Status.NO_VALID_FRONTAGE, "preview reports rejected geometry")
	_assert(zone_manager.zones.size() == committed_zone_count, "preview creates no zone")
	_assert(existing_zone.tiles.size() == committed_tile_count, "preview preserves committed zone data")
	_assert(first_tile.zone_id == committed_zone_id, "preview preserves grid markings")
	_assert(zone_manager.last_split_result.status == last_status, "preview preserves last committed result")


func _share_edge(first: Parcel, second: Parcel) -> bool:
	var second_tiles: Dictionary = {}
	for tile_pos: Vector2i in second.tiles:
		second_tiles[tile_pos] = true
	for tile_pos: Vector2i in first.tiles:
		for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if second_tiles.has(tile_pos + offset):
				return true
	return false


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
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2),
		Vector2i(2, 2), Vector2i(1, 3), Vector2i(2, 3),
	]
	var rejected := zone_manager.modify_zone(zone.id, interior_tiles, "test_plot")
	_assert(rejected == null, "interior edit without frontage is rejected")
	_assert(zone_manager.last_split_result.status == SplitResult.Status.NO_VALID_FRONTAGE, "rejected edit reports no frontage")
	_assert(zone.tiles.size() == committed_tile_count, "rejected edit leaves zone tile data unchanged")
	var retained_ids: Array[String] = []
	for parcel: Parcel in zone.parcels:
		retained_ids.append(parcel.id)
	_assert(retained_ids == committed_parcel_ids, "rejected edit leaves parcel IDs unchanged")
	var first_tile := grid_manager.get_tile(0, 0, "test_plot", "G")
	_assert(first_tile.zone_id == zone.id, "rejected edit leaves committed grid markings unchanged")
