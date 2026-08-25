## WallManagerTest — Parcel boundary wall geometry checks.
## Run with: godot --headless --path . res://tests/test_wall_manager.tscn
extends Node


var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	var wall_manager := WallManager.new()
	_test_adjacent_parcels_create_one_thin_run(wall_manager)
	_test_internal_transit_creates_one_thin_wall(wall_manager)
	_test_external_circulation_does_not_create_thin_wall(wall_manager)
	_test_non_parcel_neighbors_do_not_create_thin_walls(wall_manager)
	_test_thin_junctions_keep_the_parcel_profile(wall_manager)
	_test_t_junctions_do_not_spawn_corner_pillars(wall_manager)
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


func _test_internal_transit_creates_one_thin_wall(wall_manager: WallManager) -> void:
	var zone := _make_zone([["parcel_tenant", [Vector2i(0, 0)]]])
	var transit_tile := Vector2i(1, 0)
	zone.tiles.append(transit_tile)
	zone.typologies[transit_tile] = GridTile.TileTypology.TRANSIT
	zone.parcels[0].selected_door_edges = [{
		"tile": Vector2i(0, 0),
		"direction": Vector2i.RIGHT,
		"access": transit_tile,
		"access_kind": "internal_transit",
	}]
	var parcel_pieces := _parcel_pieces(_collect_pieces(wall_manager, zone))
	_assert(parcel_pieces.size() == 3, "selected internal Transit door creates thin-wall jambs and lintel")
	if parcel_pieces.is_empty():
		return
	for piece: Dictionary in parcel_pieces:
		_assert(
			is_equal_approx(float(piece["thickness"]), WallManager.PARCEL_WALL_THICKNESS),
			"internal Transit door geometry uses the thin parcel-wall profile"
		)
	_assert(
		parcel_pieces.any(func(piece: Dictionary) -> bool: return float(piece["height_from"]) > 0.0),
		"internal Transit door includes a lintel over its centered opening"
	)
	var has_uninterrupted_thin_wall := false
	for piece: Dictionary in parcel_pieces:
		if (
			is_equal_approx(float(piece["from"]), 0.0)
			and is_equal_approx(float(piece["to"]), 1.0)
			and is_zero_approx(float(piece["height_from"]))
		):
			has_uninterrupted_thin_wall = true
	_assert(
		not has_uninterrupted_thin_wall,
		"internal Transit selected edge no longer has an uninterrupted thin wall"
	)


func _test_external_circulation_does_not_create_thin_wall(wall_manager: WallManager) -> void:
	var zone := _make_zone([["parcel_tenant", [Vector2i(0, 0)]]])
	zone.parcels[0].selected_door_edges = [{
		"tile": Vector2i(0, 0),
		"direction": Vector2i.RIGHT,
		"access": Vector2i(1, 0),
		"access_kind": "external_circulation",
	}]
	var pieces := _collect_pieces(wall_manager, zone, [Vector2i(1, 0)])
	var parcel_pieces := _parcel_pieces(pieces)
	_assert(parcel_pieces.is_empty(), "external circulation does not create a parcel-to-Transit thin wall")
	var structural_door_pieces: Array[Dictionary] = []
	for piece: Dictionary in pieces:
		if piece["axis"] == "z" and is_equal_approx(float(piece["line"]), 1.0):
			structural_door_pieces.append(piece)
	_assert(
		structural_door_pieces.size() == 3,
		"selected external circulation door creates structural jambs and lintel"
	)
	var retains_structural_profile := true
	for piece: Dictionary in structural_door_pieces:
		if piece["is_parcel_boundary"] or not is_equal_approx(
			float(piece["thickness"]), WallManager.WALL_THICKNESS
		):
			retains_structural_profile = false
	_assert(
		retains_structural_profile,
		"selected external circulation door retains the structural wall profile"
	)


func _test_non_parcel_neighbors_do_not_create_thin_walls(wall_manager: WallManager) -> void:
	var zone := _make_zone([
		["parcel_left", [Vector2i(0, 0)]],
		["parcel_right", [Vector2i(2, 0)]],
	])
	zone.tiles = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var pieces := _collect_pieces(wall_manager, zone)
	_assert(
		_parcel_pieces(pieces).is_empty(),
		"Decoration and residual gaps do not create parcel boundary walls"
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


func _test_t_junctions_do_not_spawn_corner_pillars(wall_manager: WallManager) -> void:
	var t_runs: Array = [
		{"axis": "x", "line": 0.0, "from": 0.0, "to": 3.0, "normal": Vector3.RIGHT, "thickness": WallManager.WALL_THICKNESS, "is_parcel_boundary": false},
		{"axis": "z", "line": 1.0, "from": 0.0, "to": 1.0, "normal": Vector3.FORWARD, "thickness": WallManager.PARCEL_WALL_THICKNESS, "is_parcel_boundary": true},
	]
	var t_joints: Dictionary = {}
	var t_junctions := wall_manager._find_wall_junctions(t_runs, t_joints)
	_assert(t_junctions.is_empty(), "Tenant/Transit T-junctions do not spawn corner pillars")
	_assert(t_joints.has(1), "T-junction trims the terminating parcel wall")
	_assert(not t_joints.has(0), "T-junction leaves the continuous structural wall untrimmed")

	var l_runs: Array = [
		{"axis": "x", "line": 0.0, "from": 0.0, "to": 1.0, "normal": Vector3.RIGHT, "thickness": WallManager.PARCEL_WALL_THICKNESS, "is_parcel_boundary": true},
		{"axis": "z", "line": 1.0, "from": 0.0, "to": 1.0, "normal": Vector3.FORWARD, "thickness": WallManager.PARCEL_WALL_THICKNESS, "is_parcel_boundary": true},
	]
	var l_joints: Dictionary = {}
	var l_junctions := wall_manager._find_wall_junctions(l_runs, l_joints)
	_assert(l_junctions.size() == 1, "L-junctions retain one corner cube")

	var crossing_runs: Array = [
		{"axis": "x", "line": 0.0, "from": -1.0, "to": 1.0, "normal": Vector3.RIGHT, "thickness": WallManager.PARCEL_WALL_THICKNESS, "is_parcel_boundary": true},
		{"axis": "z", "line": 0.0, "from": -1.0, "to": 1.0, "normal": Vector3.FORWARD, "thickness": WallManager.PARCEL_WALL_THICKNESS, "is_parcel_boundary": true},
	]
	var crossing_joints: Dictionary = {}
	var crossing_junctions := wall_manager._find_wall_junctions(crossing_runs, crossing_joints)
	_assert(crossing_junctions.size() == 1, "crossings retain one corner cube")


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


func _collect_pieces(
	wall_manager: WallManager, zone: ZoneData, external_circulation: Array[Vector2i] = []
) -> Array:
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
	var corridor: Dictionary = {}
	for tile_pos: Vector2i in external_circulation:
		built[tile_pos] = true
		corridor[tile_pos] = true
	var automatic_parcel_door_edges: Dictionary = {}
	for parcel: Parcel in zone.parcels:
		for edge: Dictionary in parcel.selected_door_edges:
			automatic_parcel_door_edges[wall_manager._edge_key(
				edge.get("tile", Vector2i.ZERO), edge.get("access", Vector2i.ZERO)
			)] = true
	var zones: Array[ZoneData] = []
	zones.append(zone)
	return wall_manager._collect_wall_pieces(
		built, corridor, zones, zone_of, parcel_of, parcel_zone_of, {}, automatic_parcel_door_edges
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
