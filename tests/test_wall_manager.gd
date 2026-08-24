## WallManagerTest — Parcel boundary wall geometry checks.
## Run with: godot --headless --path . -s res://tests/test_wall_manager.gd
extends Node


var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	var wall_manager := WallManager.new()
	_test_adjacent_parcels_create_one_thin_run(wall_manager)
	_test_non_parcel_neighbors_do_not_create_thin_walls(wall_manager)
	_test_thin_junctions_keep_the_parcel_profile(wall_manager)
	wall_manager.free()
	print("WallManager tests: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _test_adjacent_parcels_create_one_thin_run(wall_manager: WallManager) -> void:
	var zone := _make_zone([
		["parcel_left", [Vector2i(0, 0), Vector2i(0, 1)]],
		["parcel_right", [Vector2i(1, 0), Vector2i(1, 1)]],
	])
	var pieces := _collect_pieces(wall_manager, zone)
	var parcel_pieces := _parcel_pieces(pieces)
	_assert(parcel_pieces.size() == 2, "adjacent parcels create one thin edge piece per shared tile edge")
	var parcel_runs := _parcel_runs(wall_manager, pieces)
	_assert(parcel_runs.size() == 1, "adjacent parcel edges merge into one interior wall run")
	if parcel_runs.is_empty():
		return
	var run: Dictionary = parcel_runs[0]
	_assert(is_equal_approx(float(run["thickness"]), WallManager.PARCEL_WALL_THICKNESS), "parcel wall run is thinner than structural walls")
	_assert(run["axis"] == "z" and is_equal_approx(float(run["line"]), 1.0), "parcel wall run lies on the shared parcel boundary")


func _test_non_parcel_neighbors_do_not_create_thin_walls(wall_manager: WallManager) -> void:
	var zone := _make_zone([
		["parcel_left", [Vector2i(0, 0)]],
		["parcel_right", [Vector2i(2, 0)]],
	])
	zone.tiles = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var pieces := _collect_pieces(wall_manager, zone)
	_assert(
		_parcel_pieces(pieces).is_empty(),
		"Transit, Decoration, and residual gaps do not create parcel boundary walls"
	)


func _test_thin_junctions_keep_the_parcel_profile(wall_manager: WallManager) -> void:
	var zone := _make_zone([
		["parcel_1", [Vector2i(0, 0)]],
		["parcel_2", [Vector2i(1, 0)]],
		["parcel_3", [Vector2i(0, 1)]],
		["parcel_4", [Vector2i(1, 1)]],
	])
	var pieces := _collect_pieces(wall_manager, zone)
	var runs := wall_manager._merge_pieces_into_runs(pieces)
	var joints_by_run: Dictionary = {}
	var junctions := wall_manager._find_wall_junctions(runs, joints_by_run)
	var parcel_junctions: Array[Dictionary] = []
	for junction: Dictionary in junctions:
		if junction["is_parcel_boundary"]:
			parcel_junctions.append(junction)
	_assert(parcel_junctions.size() == 1, "crossing parcel walls create one parcel-boundary junction")
	if parcel_junctions.is_empty():
		return
	_assert(
		is_equal_approx(float(parcel_junctions[0]["thickness"]), WallManager.PARCEL_WALL_THICKNESS),
		"thin-only junctions use thin corner cubes and trimming"
	)


func _make_zone(parcel_definitions: Array) -> ZoneData:
	var zone := ZoneData.new()
	zone.id = "zone_test"
	for definition: Array in parcel_definitions:
		var parcel := Parcel.new()
		parcel.id = definition[0]
		for tile_pos: Vector2i in definition[1]:
			parcel.tiles.append(tile_pos)
			zone.tiles.append(tile_pos)
		zone.parcels.append(parcel)
	return zone


func _collect_pieces(wall_manager: WallManager, zone: ZoneData) -> Array:
	var built: Dictionary = {}
	var zone_of: Dictionary = {}
	var parcel_of: Dictionary = {}
	var parcel_zone_of: Dictionary = {}
	for tile_pos: Vector2i in zone.tiles:
		built[tile_pos] = true
		zone_of[tile_pos] = zone.id
	for parcel: Parcel in zone.parcels:
		for tile_pos: Vector2i in parcel.tiles:
			parcel_of[tile_pos] = parcel.id
			parcel_zone_of[tile_pos] = zone.id
	var zones: Array[ZoneData] = []
	zones.append(zone)
	return wall_manager._collect_wall_pieces(
		built, {}, zones, zone_of, parcel_of, parcel_zone_of, {}
	)


func _parcel_pieces(pieces: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for piece: Dictionary in pieces:
		if piece["is_parcel_boundary"]:
			result.append(piece)
	return result


func _parcel_runs(wall_manager: WallManager, pieces: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for run: Dictionary in wall_manager._merge_pieces_into_runs(pieces):
		if run["is_parcel_boundary"]:
			result.append(run)
	return result
