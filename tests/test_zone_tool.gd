## ZoneTool rectangle-painting tests.
## Run with: godot --headless --path . -s res://tests/test_zone_tool.gd
extends Node


var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	_test_forward_rectangle()
	_test_reverse_rectangle()
	_test_single_tile_rectangle()
	_test_repainting_existing_tiles_revalidates_typology()
	print("ZoneTool tests: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _test_forward_rectangle() -> void:
	var tiles := ZoneTool.rectangle_tiles(Vector2i(2, 3), Vector2i(4, 5))
	_assert(tiles.size() == 9, "forward drag selects the full inclusive rectangle")
	_assert(tiles.has(Vector2i(2, 3)), "forward rectangle includes its start tile")
	_assert(tiles.has(Vector2i(4, 5)), "forward rectangle includes its end tile")


func _test_reverse_rectangle() -> void:
	var tiles := ZoneTool.rectangle_tiles(Vector2i(4, 5), Vector2i(2, 3))
	_assert(tiles.size() == 9, "reverse drag selects the same rectangle")
	_assert(tiles == ZoneTool.rectangle_tiles(Vector2i(2, 3), Vector2i(4, 5)), "drag direction does not change selection")


func _test_single_tile_rectangle() -> void:
	var tiles := ZoneTool.rectangle_tiles(Vector2i(7, 8), Vector2i(7, 8))
	_assert(tiles == [Vector2i(7, 8)], "click without movement selects one tile")


func _test_repainting_existing_tiles_revalidates_typology() -> void:
	var world := Node.new()
	world.name = "World"
	add_child(world)
	var grid_manager := GridManager.new()
	grid_manager.name = "GridManager"
	world.add_child(grid_manager)
	var zone_manager := ZoneManager.new()
	zone_manager.name = "ZoneManager"
	world.add_child(zone_manager)
	var plot := grid_manager.create_plot(GridManager.DEFAULT_PLOT, 8, 8)
	var floor_grid := plot.get_floor(GridManager.GROUND_FLOOR)
	for x: int in range(floor_grid.width):
		for y: int in range(floor_grid.height):
			var tile := floor_grid.get_tile(x, y)
			tile.owned = true
			tile.floor_built = true
	for y: int in range(1, 6):
		for x: int in range(1, 5):
			if x != 1 and x != 4 and y != 1 and y != 5:
				continue
			grid_manager.get_tile(x, y).element = GridTile.TileElement.CIRCULATION

	var tool := ZoneTool.new()
	tool.is_active = true
	add_child(tool)
	tool._paint_rectangle(Vector2i(2, 2), Vector2i(3, 4))
	_assert(tool.can_finish, "physical Tenant rectangle starts as finishable")
	tool.set_transit_mode(true)
	tool._paint_rectangle(Vector2i(2, 2), Vector2i(3, 4))
	_assert(not tool.can_finish, "repainting existing tiles as Transit immediately revalidates")
	tool.set_transit_mode(false)
	tool._paint_rectangle(Vector2i(2, 2), Vector2i(3, 4))
	_assert(tool.can_finish, "repainting existing Transit tiles as Tenant immediately revalidates")
	tool.queue_free()
	world.queue_free()
