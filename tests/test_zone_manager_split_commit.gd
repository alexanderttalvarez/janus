## ZoneManagerSplitCommitTest — Atomic ZoneManager integration checks.
## Run with: godot --headless --path . res://tests/test_zone_manager_split_commit.tscn
extends Node


var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	var context := _make_world()
	_test_successful_creation_commits_parcels(context)
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
	_assert(zone.parcels.size() == 6, "zone commit stores six parcels")
	var ids: Dictionary = {}
	for parcel: Parcel in zone.parcels:
		ids[parcel.id] = true
	_assert(ids.size() == zone.parcels.size(), "committed parcel IDs are globally unique")
	var first_tile := grid_manager.get_tile(0, 0, "test_plot", "G")
	_assert(first_tile.zone_id == zone.id, "grid markings are written only after successful split")


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
