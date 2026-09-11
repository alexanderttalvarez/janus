## WallManager — Generates and updates wall meshes for the current floor.
##
## Rules (documents/game_design/elements/12_wall_system.md):
##   - Floor perimeter: wall around all built tiles (exterior walls).
##   - Zone perimeter: wall around each zone boundary; door gap where a
##     corridor tile borders the zone.
##   - Corridor walls: 4 walls per corridor tile, shared walls removed.
##
## Geometry follows the design doc's "corner cube" approach:
##   - Walls are CENTERED on the boundary line — half the thickness on each
##     side, shared between the two adjacent tiles.
##   - Contiguous wall edges on the same line are MERGED into runs.
##   - L-corners and crossings get a CORNER CUBE (thickness × height ×
##     thickness) centered on the junction point.
##   - T-junctions suppress the redundant cube and trim only the terminating
##     run against the continuous wall.
## Consequence: wall boxes never overlap and never share coplanar faces with
## same-facing normals — no z-fighting by construction.
##
## Caps: a thin plate rendered on top of the strip kept visible in
## Cutaway/Partial mode, so a cut wall reads as a real low wall instead of a
## hollow interior. Caps are INSET by CAP_INSET so their side faces are never
## coplanar with the wall's side faces (the classic cap z-fight).
##
## Rendering: walls use wall_clipping.gdshader, which classifies each box by
## the outward direction baked into its material (NOT per-face normals), so a
## whole wall or cube opens/stays solid as one piece. Straight walls bake
## their axis normal with a front threshold of 0.0; corner cubes bake the
## corner diagonal with a threshold of 0.5, so only the corner facing the
## camera opens while the other three always stay solid.
##
## Public API:
##   rebuild() — Regenerate every wall mesh from the current grid + zones.
class_name WallManager
extends Node


## Wall height in world units — matches the explicit production projection metrics.
const WALL_HEIGHT: float = 3.0
## Structural wall thickness — matches the floor tile height (0.1) so walls
## read as solid slabs, not paper planes.
const WALL_THICKNESS: float = 0.1
## Interior boundary walls distinguish parcel divisions from structural walls.
const PARCEL_WALL_THICKNESS: float = 0.04
## Wall color (concrete beige). Materials are post-MVP.
const WALL_COLOR: Color = Color(0.85, 0.82, 0.78)
## Fraction of the wall height kept visible at the bottom in Cutaway/Partial
## (matches KEEP_FRACTION in wall_clipping.gdshader).
const CUTAWAY_KEEP_FRACTION: float = 0.10
## Height of the cap plate rendered on top of a cut wall (its "top").
const CAP_HEIGHT: float = 0.04
## World Y of the cap plate's center (strip top + half cap height).
const CAP_Y: float = CUTAWAY_KEEP_FRACTION * WALL_HEIGHT + CAP_HEIGHT * 0.5
## How much the cap plates are shrunk per side in XZ, so cap side faces are
## never coplanar with the wall's side faces.
const CAP_INSET: float = 0.002
## Opening width at corridor connections (door).
const DOOR_GAP: float = 0.6
## Adjacency tolerance when merging edge spans and matching junctions.
const MERGE_EPSILON: float = 0.01
## Front-facing threshold for corner cubes (see wall_clipping.gdshader).
## Side corners sit perpendicular to the camera (dot ≈ 0), so 0.5 keeps them
## solid while only the camera-facing corner (dot ≈ 1) opens.
const CORNER_FRONT_THRESHOLD: float = 0.5

const _DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]

var _materials: Dictionary = {}  # material cache key -> ShaderMaterial
var _box_meshes: Dictionary = {}  # size key -> BoxMesh
var _district_runtime: DistrictRuntime
var _production_floor_address: Dictionary = {}


func _ready() -> void:
	# Force-load the wall shader NOW so its global uniforms (camera_direction,
	# wall_mode) register in the RenderingServer before GameManager sets them.
	_get_wall_material(Vector2(0.0, 1.0), 0.0, false)

	# Walls adapt automatically to zone changes and tile purchases. Resolve the
	# registered autoload at runtime so standalone wall tests can load this
	# script without requiring editor-only global-symbol resolution.
	var event_bus: Node = get_tree().root.get_node_or_null("EventBus")
	if event_bus == null:
		return
	event_bus.connect("zone_created", func(_id: String, _t: String, _c: int): rebuild())
	event_bus.connect("zone_modified", func(_id: String): rebuild())
	event_bus.connect("zone_deleted", func(_id: String): rebuild())
	event_bus.connect("door_changed", func(_from: Vector2i, _to: Vector2i, _enabled: bool): rebuild())
	event_bus.connect("tile_purchased", func(_f: int, _x: int, _y: int): rebuild())


## Configure the production wall path. It consumes detached H3 state and
## ZoneManager records only; the archive legacy-grid path remains available to
## isolated test scenes.
func configure_production(runtime: DistrictRuntime, floor_address: Dictionary) -> void:
	_district_runtime = runtime
	_production_floor_address = floor_address.duplicate(true)
	if _district_runtime != null and not _district_runtime.district_delta_committed.is_connected(_on_district_delta_committed):
		_district_runtime.district_delta_committed.connect(_on_district_delta_committed)


func _on_district_delta_committed(_envelope: Dictionary) -> void:
	rebuild()


## Regenerate all wall meshes from the current district and zone snapshots.
func rebuild() -> void:
	if _district_runtime == null:
		return
	_rebuild_production()


func _rebuild_production() -> void:
	if not _district_runtime.has_session() or _production_floor_address.is_empty():
		return
	var floor_node: Floor = _get_production_floor()
	if floor_node == null:
		return
	var container: Node3D = _get_wall_container(floor_node)
	_clear_walls(container)
	var state: Dictionary = _district_runtime.get_state()
	var floor_id: String = String(_production_floor_address.get("floor_id", ""))
	var floor_label: String = _floor_label(int(_production_floor_address.get("elevation", 0)))
	var built: Dictionary = {}
	var corridor: Dictionary = {}
	for plot_state: Variant in state.get("plot_states", []):
		if not plot_state is Dictionary or String(plot_state.get("runtime_plot_id", "")) != String(_production_floor_address.get("runtime_plot_id", "")):
			continue
		for floor_state: Variant in plot_state.get("floor_states", []):
			if not floor_state is Dictionary or String(floor_state.get("floor_id", "")) != floor_id:
				continue
			for cell: Variant in floor_state.get("constructed_cells", []):
				if cell is Array and cell.size() == 2:
					built[Vector2i(int(cell[0]), int(cell[1]))] = true
			for cell: Variant in floor_state.get("explicit_circulation_cells", []):
				if cell is Array and cell.size() == 2:
					corridor[Vector2i(int(cell[0]), int(cell[1]))] = true
	if built.is_empty():
		return
	var zone_of: Dictionary = {}
	var parcel_of: Dictionary = {}
	var parcel_zone_of: Dictionary = {}
	var zones: Array[ZoneData] = []
	var zone_manager: ZoneManager = _get_zone_manager()
	if zone_manager != null:
		for zone: ZoneData in zone_manager.get_zones_on_floor(floor_label):
			if zone.plot_id != String(_production_floor_address.get("runtime_plot_id", "")):
				continue
			zones.append(zone)
			for tile: Vector2i in zone.tiles:
				zone_of[tile] = zone.id
			for parcel: Parcel in zone.parcels:
				for tile: Vector2i in parcel.tiles:
					parcel_of[tile] = parcel.id
					parcel_zone_of[tile] = zone.id
	var manual_door_edges: Dictionary = {}
	for record: Variant in state.get("manual_door_edges", []):
		if not record is Dictionary:
			continue
		var endpoint_a: Dictionary = record.get("endpoint_a", {})
		var endpoint_b: Dictionary = record.get("endpoint_b", {})
		if String(endpoint_a.get("runtime_plot_id", "")) != String(_production_floor_address.get("runtime_plot_id", "")) or int(endpoint_a.get("signed_elevation", 999999)) != int(_production_floor_address.get("elevation", 0)):
			continue
		var cell_a: Dictionary = endpoint_a.get("local_cell", {})
		var cell_b: Dictionary = endpoint_b.get("local_cell", {})
		manual_door_edges[_edge_key(Vector2i(int(cell_a.get("x", -1)), int(cell_a.get("y", -1))), Vector2i(int(cell_b.get("x", -1)), int(cell_b.get("y", -1))))] = true
	var automatic_parcel_door_edges: Dictionary = {}
	for zone: ZoneData in zones:
		for parcel: Parcel in zone.parcels:
			for edge: Dictionary in parcel.selected_door_edges:
				automatic_parcel_door_edges[_edge_key(edge.get("tile", Vector2i.ZERO), edge.get("access", Vector2i.ZERO))] = true
	var pieces: Array = _collect_wall_pieces(built, corridor, zones, zone_of, parcel_of, parcel_zone_of, manual_door_edges, automatic_parcel_door_edges)
	var runs: Array = _merge_pieces_into_runs(pieces)
	var joints_by_run: Dictionary = {}
	var junctions: Array = _find_wall_junctions(runs, joints_by_run)
	for junction: Dictionary in junctions:
		_build_corner_cube(container, junction["point"], junction["outward"], junction["thickness"], junction["is_parcel_boundary"])
	for index: int in range(runs.size()):
		_build_wall_segments(container, runs[index], joints_by_run.get(index, []))


func _floor_label(elevation: int) -> String:
	return "G" if elevation == 0 else ("F%d" % elevation if elevation > 0 else "B%d" % absi(elevation))


func _get_production_floor() -> Floor:
	var root: Node = get_tree().current_scene
	if root == null:
		return null
	var world: Node3D = root.get_node_or_null("World") as Node3D
	if world == null:
		return null
	var projection: Node = world.get_node_or_null("ProjectionCoordinator")
	if projection != null and projection.has_method("get_projected_floor"):
		var projected: Floor = projection.call("get_projected_floor", _production_floor_address) as Floor
		if projected != null:
			return projected
	var target_floor_id: String = String(_production_floor_address.get("floor_id", ""))
	var pending: Array[Node] = [world]
	while not pending.is_empty():
		var candidate: Node = pending.pop_back()
		var floor: Floor = candidate as Floor
		if floor != null and floor.runtime_floor_id == target_floor_id and floor.runtime_plot_id == String(_production_floor_address.get("runtime_plot_id", "")) and floor.elevation == int(_production_floor_address.get("elevation", 0)):
			return floor
		for child: Node in candidate.get_children():
			pending.append(child)
	return null


## Remove previous wall meshes. Immediate free (not queue_free) so a rebuild
## never leaves a one-frame double-wall flicker behind.
func _clear_walls(container: Node3D) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.free()


## Collect one wall piece per tile edge that needs a wall, in three passes:
## floor perimeter, zone perimeters (with door gaps), and corridor walls.
## Edges are deduplicated canonically, so each boundary produces one wall.
func _collect_wall_pieces(
	built: Dictionary, corridor: Dictionary, zones: Array[ZoneData], zone_of: Dictionary,
	parcel_of: Dictionary, parcel_zone_of: Dictionary, manual_door_edges: Dictionary,
	automatic_parcel_door_edges: Dictionary = {}
) -> Array:
	var placed: Dictionary = {}  # edge key -> true
	var pieces: Array = []
	var all_door_edges := manual_door_edges.duplicate()
	for edge_key: String in automatic_parcel_door_edges:
		all_door_edges[edge_key] = true

	# 1) Floor perimeter — built tile edges facing non-built space.
	for pos: Vector2i in built.keys():
		for dir: Vector2i in _DIRS:
			var n: Vector2i = pos + dir
			if not built.has(n):
				var edge_key := _edge_key(pos, n)
				_add_wall_piece(placed, pieces, pos, n, false, manual_door_edges.has(edge_key), all_door_edges)

	# 2) Zone perimeter — zone tile edges facing other built space.
	#    Door gaps come from manual flags or automatic parcel selections.
	for zone: ZoneData in zones:
		for pos: Vector2i in zone.tiles:
			for dir: Vector2i in _DIRS:
				var n: Vector2i = pos + dir
				if zone_of.get(n, "") == zone.id:
					continue
				if not built.has(n):
					continue  # Exterior handled by the floor perimeter.
				var edge_key := _edge_key(pos, n)
				_add_wall_piece(
					placed, pieces, pos, n,
					manual_door_edges.has(edge_key) or automatic_parcel_door_edges.has(edge_key),
					false, all_door_edges
				)

	# 3) Corridor walls — corridor tile edges facing non-corridor built space.
	#    Skip zone-facing edges (door handled on the zone side) and exterior.
	for pos: Vector2i in corridor.keys():
		for dir: Vector2i in _DIRS:
			var n: Vector2i = pos + dir
			if corridor.has(n):
				continue
			if not built.has(n):
				continue
			if zone_of.has(n):
				continue
			_add_wall_piece(placed, pieces, pos, n, false, false, all_door_edges)

	# 4) Parcel boundaries — shared edges between distinct parcels, plus
	#    Parcel Tenant edges facing same-zone internal Transit, receive thin
	#    interior walls. External circulation, Decoration, residual, and
	#    zone-boundary edges retain their existing structural behavior.
	for zone: ZoneData in zones:
		for parcel: Parcel in zone.parcels:
			for pos: Vector2i in parcel.tiles:
				for dir: Vector2i in _DIRS:
					var n: Vector2i = pos + dir
					var is_other_parcel: bool = parcel_zone_of.get(n, "") == zone.id and parcel_of.get(n, "") != parcel.id
					var is_internal_transit: bool = (
						zone_of.get(n, "") == zone.id
						and zone.typologies.get(n, 0) == 2
					)
					if not is_other_parcel and not is_internal_transit:
						continue
					_add_wall_piece(
						placed, pieces, pos, n, automatic_parcel_door_edges.has(_edge_key(pos, n)),
						false, all_door_edges, true
					)

	return pieces


## Dedup an edge and record its wall piece(s) for merging. Door edges
## produce either a full-height corridor opening or an exterior door shape.
func _add_wall_piece(
	placed: Dictionary, pieces: Array, pos: Vector2i, neighbor: Vector2i,
	has_door: bool, is_exterior_door: bool = false,
	door_edges: Dictionary = {}, is_parcel_boundary: bool = false
) -> void:
	var key := _edge_key(pos, neighbor)
	if placed.has(key):
		return
	placed[key] = true
	var normal := Vector3(float(neighbor.x - pos.x), 0.0, float(neighbor.y - pos.y))
	if is_exterior_door:
		var adjacent_start := _has_adjacent_door(pos, normal, true, door_edges)
		var adjacent_end := _has_adjacent_door(pos, normal, false, door_edges)
		pieces.append_array(_make_exterior_door_pieces(
			pos, normal, adjacent_start, adjacent_end, is_parcel_boundary
		))
	elif has_door:
		# Manual and automatic doors use the existing side sections and upper
		# lintel profile rather than cutting a full-height hole.
		var adjacent_start := _has_adjacent_door(pos, normal, true, door_edges)
		var adjacent_end := _has_adjacent_door(pos, normal, false, door_edges)
		pieces.append_array(_make_exterior_door_pieces(
			pos, normal, adjacent_start, adjacent_end, is_parcel_boundary
		))
	else:
		pieces.append(_make_edge_piece(pos, normal, is_parcel_boundary))


## Wall piece covering one full tile edge, centered on the boundary line.
func _make_edge_piece(
	pos: Vector2i, normal: Vector3, is_parcel_boundary: bool = false
) -> Dictionary:
	if normal.x != 0.0:
		# East/west edge — wall runs along Z at line x.
		return {
			"axis": "z",
			"line": float(pos.x) + 0.5 + normal.x * 0.5,
			"from": float(pos.y),
			"to": float(pos.y) + 1.0,
			"normal": normal,
			"height_from": 0.0,
			"height_to": WALL_HEIGHT,
			"thickness": PARCEL_WALL_THICKNESS if is_parcel_boundary else WALL_THICKNESS,
			"is_parcel_boundary": is_parcel_boundary,
		}
	# North/south edge — wall runs along X at line z.
	return {
		"axis": "x",
		"line": float(pos.y) + 0.5 + normal.z * 0.5,
		"from": float(pos.x),
		"to": float(pos.x) + 1.0,
		"normal": normal,
		"height_from": 0.0,
		"height_to": WALL_HEIGHT,
		"thickness": PARCEL_WALL_THICKNESS if is_parcel_boundary else WALL_THICKNESS,
		"is_parcel_boundary": is_parcel_boundary,
	}


## Two short pieces flanking a centered door opening on one tile edge.
func _make_door_pieces(pos: Vector2i, normal: Vector3) -> Array:
	var seg_width := (1.0 - DOOR_GAP) * 0.5
	var half_span := DOOR_GAP * 0.5 + seg_width
	var piece := _make_edge_piece(pos, normal)
	var mid: float = (piece["from"] + piece["to"]) * 0.5
	var seg_a: Dictionary = piece.duplicate()
	seg_a["from"] = mid - half_span
	seg_a["to"] = mid - half_span + seg_width
	var seg_b: Dictionary = piece.duplicate()
	seg_b["from"] = mid + half_span - seg_width
	seg_b["to"] = mid + half_span
	return [seg_a, seg_b]


## Exterior door geometry keeps 10% side sections at full height and a
## centered lintel over the upper 25% of the wall.
func _make_exterior_door_pieces(
	pos: Vector2i, normal: Vector3, adjacent_start: bool = false, adjacent_end: bool = false,
	is_parcel_boundary: bool = false
) -> Array:
	var piece := _make_edge_piece(pos, normal, is_parcel_boundary)
	var side_width := 0.1
	var side_a: Dictionary = piece.duplicate()
	side_a["to"] = side_a["from"] + side_width
	if adjacent_start:
		side_a["height_from"] = WALL_HEIGHT * 0.75
	var side_b: Dictionary = piece.duplicate()
	side_b["from"] = side_b["to"] - side_width
	if adjacent_end:
		side_b["height_from"] = WALL_HEIGHT * 0.75
	var lintel: Dictionary = piece.duplicate()
	lintel["from"] = piece["from"] + side_width
	lintel["to"] = piece["to"] - side_width
	lintel["height_from"] = WALL_HEIGHT * 0.75
	lintel["height_to"] = WALL_HEIGHT
	return [side_a, side_b, lintel]


func _has_adjacent_door(
	pos: Vector2i, normal: Vector3, at_start: bool, door_edges: Dictionary
) -> bool:
	var along := Vector2i.DOWN if normal.x != 0.0 else Vector2i.RIGHT
	var adjacent_pos := pos - along if at_start else pos + along
	var normal_grid := Vector2i(int(normal.x), int(normal.z))
	return door_edges.has(_edge_key(adjacent_pos, adjacent_pos + normal_grid))


## Merge all recorded pieces: group by (axis, line, normal direction), then
## join adjacent spans into single runs.
func _merge_pieces_into_runs(pieces: Array) -> Array:
	var groups: Dictionary = {}  # key -> Array of pieces
	for piece: Dictionary in pieces:
		var normal: Vector3 = piece["normal"]
		var dir_key: String = "p" if (normal.x + normal.z) > 0.0 else "m"
		var key := "%s:%.4f:%s:%.2f:%.2f:%.3f:%s" % [
			piece["axis"], piece["line"], dir_key, piece["height_from"], piece["height_to"],
			piece["thickness"], "parcel" if piece["is_parcel_boundary"] else "structural"
		]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(piece)

	var runs: Array = []
	for key: String in groups:
		var group: Array = groups[key]
		group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["from"] < b["from"])
		var run_from: float = group[0]["from"]
		var run_to: float = group[0]["to"]
		for i in range(1, group.size()):
			var piece: Dictionary = group[i]
			if piece["from"] <= run_to + MERGE_EPSILON:
				run_to = maxf(run_to, piece["to"])
			else:
				runs.append({
					"axis": group[0]["axis"],
					"line": group[0]["line"],
					"from": run_from,
					"to": run_to,
					"normal": group[0]["normal"],
					"height_from": group[0]["height_from"],
					"height_to": group[0]["height_to"],
					"thickness": group[0]["thickness"],
					"is_parcel_boundary": group[0]["is_parcel_boundary"],
				})
				run_from = piece["from"]
				run_to = piece["to"]
		runs.append({
			"axis": group[0]["axis"],
			"line": group[0]["line"],
			"from": run_from,
			"to": run_to,
			"normal": group[0]["normal"],
			"height_from": group[0]["height_from"],
			"height_to": group[0]["height_to"],
			"thickness": group[0]["thickness"],
			"is_parcel_boundary": group[0]["is_parcel_boundary"],
		})
	return runs


## Find every point where an X-run and a Z-run meet — L-corners, T-junctions
## and crossings alike. Each junction gets a corner cube, and both runs are
## split/trimmed flush against it. Returns the junction list and fills
## `joints_by_run` (run index -> sorted junction coords along the run).
##
## Each junction always involves exactly one X-run and one Z-run (collinear
## duplicates were merged away), so the cube's outward direction — the sum of
## both run normals — is always a clean corner diagonal.
func _find_wall_junctions(runs: Array, joints_by_run: Dictionary) -> Array:
	var junctions: Array = []
	for i in range(runs.size()):
		var run_x: Dictionary = runs[i]
		if run_x["axis"] != "x":
			continue
		for j in range(runs.size()):
			var run_z: Dictionary = runs[j]
			if run_z["axis"] != "z":
				continue
			var point := Vector2(run_z["line"], run_x["line"])
			if not _span_covers(run_x, point.x) or not _span_covers(run_z, point.y):
				continue
			var thickness := maxf(float(run_x["thickness"]), float(run_z["thickness"]))
			var x_passes_through := _run_passes_through(run_x, point.x)
			var z_passes_through := _run_passes_through(run_z, point.y)
			if x_passes_through != z_passes_through:
				# A T-junction does not need a corner cube. The continuous run
				# already owns the junction volume; trim only the terminating run
				# against its face to avoid a false Cutaway pillar.
				if x_passes_through:
					_add_joint(joints_by_run, j, point.y, thickness)
				else:
					_add_joint(joints_by_run, i, point.x, thickness)
				continue
			if x_passes_through and z_passes_through and run_x["is_parcel_boundary"] != run_z["is_parcel_boundary"]:
				# Aligned Tenant↔Transit boundaries can continue across adjacent
				# zones and meet a continuous structural inter-zone wall. This is
				# semantically two thin runs terminating at a structural wall, not
				# a real crossing; a structural cube would become a Cutaway pillar.
				var parcel_run_index := i if run_x["is_parcel_boundary"] else j
				var parcel_coord := point.x if run_x["is_parcel_boundary"] else point.y
				_add_joint(joints_by_run, parcel_run_index, parcel_coord, thickness)
				continue

			var outward := Vector2(run_x["normal"].x, run_x["normal"].z) \
				+ Vector2(run_z["normal"].x, run_z["normal"].z)
			var is_parcel_boundary: bool = run_x["is_parcel_boundary"] and run_z["is_parcel_boundary"]
			junctions.append({
				"point": point,
				"outward": outward.normalized(),
				"thickness": thickness,
				"is_parcel_boundary": is_parcel_boundary,
			})
			_add_joint(joints_by_run, i, point.x, thickness)
			_add_joint(joints_by_run, j, point.y, thickness)
	return junctions


## Whether the run's span contains `coord` (endpoints included).
func _span_covers(run: Dictionary, coord: float) -> bool:
	return coord >= run["from"] - MERGE_EPSILON and coord <= run["to"] + MERGE_EPSILON


## Whether the run continues on both sides of an intersection coordinate.
func _run_passes_through(run: Dictionary, coord: float) -> bool:
	return (
		coord > float(run["from"]) + MERGE_EPSILON
		and coord < float(run["to"]) - MERGE_EPSILON
	)

## Record a junction coordinate on a run (sorted, deduplicated).
func _add_joint(joints_by_run: Dictionary, run_index: int, coord: float, thickness: float) -> void:
	if not joints_by_run.has(run_index):
		joints_by_run[run_index] = []
	var joints: Array = joints_by_run[run_index]
	for existing: Dictionary in joints:
		if absf(float(existing["coord"]) - coord) <= MERGE_EPSILON:
			existing["thickness"] = maxf(float(existing["thickness"]), thickness)
			return
	joints.append({"coord": coord, "thickness": thickness})
	joints.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return float(first["coord"]) < float(second["coord"])
	)


## Thickness of the junction cube that trims this run at `coord`.
func _joint_thickness_at(joints: Array, coord: float) -> float:
	for joint: Dictionary in joints:
		if absf(float(joint["coord"]) - coord) <= MERGE_EPSILON:
			return float(joint["thickness"])
	return 0.0


## Build the wall boxes for one run: split at junction coords and trim each
## segment a half-thickness away from corner cubes, so boxes butt flush
## without overlapping. Free ends (e.g. door gaps) stay untrimmed.
func _build_wall_segments(container: Node3D, run: Dictionary, joints: Array) -> void:
	var cuts: Array[float] = [run["from"]]
	for joint: Dictionary in joints:
		var coord: float = joint["coord"]
		if coord > run["from"] + MERGE_EPSILON and coord < run["to"] - MERGE_EPSILON:
			cuts.append(coord)
	cuts.append(run["to"])

	for i in range(cuts.size() - 1):
		var seg_from: float = cuts[i]
		var seg_to: float = cuts[i + 1]
		var start_joint_thickness := _joint_thickness_at(joints, seg_from)
		var end_joint_thickness := _joint_thickness_at(joints, seg_to)
		if start_joint_thickness > 0.0:
			seg_from += start_joint_thickness * 0.5
		if end_joint_thickness > 0.0:
			seg_to -= end_joint_thickness * 0.5
		if seg_to - seg_from < MERGE_EPSILON:
			continue
		_spawn_wall_box(container, run, seg_from, seg_to)


## Spawn one straight wall box (plus its cutaway cap) covering [from, to]
## along the run's axis, centered on the boundary line.
func _spawn_wall_box(container: Node3D, run: Dictionary, from: float, to: float) -> void:
	var length := to - from
	var mid := (from + to) * 0.5
	var line: float = run["line"]
	var height_from: float = run.get("height_from", 0.0)
	var height_to: float = run.get("height_to", WALL_HEIGHT)
	var height := height_to - height_from
	var thickness: float = run["thickness"]
	var is_parcel_boundary: bool = run["is_parcel_boundary"]
	var size: Vector3
	var center: Vector3
	if run["axis"] == "z":
		size = Vector3(thickness, height, length)
		center = Vector3(line, (height_from + height_to) * 0.5, mid)
	else:
		size = Vector3(length, height, thickness)
		center = Vector3(mid, (height_from + height_to) * 0.5, line)
	var outward := Vector2(run["normal"].x, run["normal"].z)
	var label := "Wall_%s_%.1f_%.1f_%.2f" % [run["axis"], line, mid, height_from]
	var is_door_lintel := not is_zero_approx(height_from)
	# Keep the 25% lintel visible; only its cap/thickness bar is hidden
	# outside Full mode.
	_spawn_box(container, center, size, outward, 0.0, false, label, false, is_parcel_boundary)
	var cap_y := CAP_Y if is_zero_approx(height_from) else height_to + CAP_HEIGHT * 0.5
	_spawn_box(
		container, Vector3(center.x, cap_y, center.z),
		_inset_cap_size(size), outward, 0.0, true, label + "_cap", is_door_lintel, is_parcel_boundary
	)


## Spawn a corner cube (plus its cap) at a junction point. The cube fills
## the square where the trimmed runs meet, so the wall outline stays
## continuous with no overlaps. Its outward direction is the corner diagonal.
func _build_corner_cube(
	container: Node3D, point: Vector2, outward: Vector2, thickness: float, is_parcel_boundary: bool
) -> void:
	var size := Vector3(thickness, WALL_HEIGHT, thickness)
	var center := Vector3(point.x, WALL_HEIGHT * 0.5, point.y)
	var label := "ParcelCorner_%.0f_%.0f" % [point.x, point.y] if is_parcel_boundary else "Corner_%.0f_%.0f" % [point.x, point.y]
	_spawn_box(container, center, size, outward, CORNER_FRONT_THRESHOLD, false, label, false, is_parcel_boundary)
	_spawn_box(
		container, Vector3(point.x, CAP_Y, point.y),
		_inset_cap_size(size), outward, CORNER_FRONT_THRESHOLD, true, label + "_cap", false, is_parcel_boundary
	)


## Spawn a single wall box mesh instance. Meshes are shared per size.
func _spawn_box(
	container: Node3D, center: Vector3, size: Vector3,
	outward: Vector2, front_threshold: float, is_cap: bool, label: String,
	is_door_lintel: bool = false, is_parcel_boundary: bool = false
) -> void:
	var box := MeshInstance3D.new()
	box.mesh = _get_box_mesh(size)
	box.material_override = _get_wall_material(outward, front_threshold, is_cap, is_door_lintel, is_parcel_boundary)
	box.position = center
	box.name = label
	container.add_child(box)


## Cap footprint slightly smaller than the wall's, so the cap's side faces
## are never coplanar with the wall's (avoids z-fighting in the cut strip).
func _inset_cap_size(wall_size: Vector3) -> Vector3:
	return Vector3(
		maxf(wall_size.x - CAP_INSET * 2.0, CAP_INSET),
		CAP_HEIGHT,
		maxf(wall_size.z - CAP_INSET * 2.0, CAP_INSET)
	)


## Shared BoxMesh per size — segments of equal size reuse the same mesh.
func _get_box_mesh(size: Vector3) -> BoxMesh:
	var key := "%.3f|%.3f|%.3f" % [size.x, size.y, size.z]
	var mesh := _box_meshes.get(key) as BoxMesh
	if mesh == null:
		mesh = BoxMesh.new()
		mesh.size = size
		_box_meshes[key] = mesh
	return mesh


## Wall material, cached per outward direction + threshold + cap flag. The
## shader classifies the whole box by the baked outward direction, so every
## face of a wall or cube opens or stays solid together.
func _get_wall_material(
	outward: Vector2, front_threshold: float, is_cap: bool, is_door_lintel: bool = false,
	is_parcel_boundary: bool = false
) -> ShaderMaterial:
	var key := "%.2f|%.2f|%.2f|%s|%s|%s" % [
		outward.x, outward.y, front_threshold,
		"cap" if is_cap else "wall", "door_lintel" if is_door_lintel else "normal",
		"parcel" if is_parcel_boundary else "structural"
	]
	var mat := _materials.get(key) as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = load("res://assets/shaders/wall_clipping.gdshader") as Shader
		mat.set_shader_parameter("wall_color", WALL_COLOR)
		mat.set_shader_parameter("outward", outward)
		mat.set_shader_parameter("front_threshold", front_threshold)
		mat.set_shader_parameter("is_cap", is_cap)
		mat.set_shader_parameter("is_door_lintel", is_door_lintel)
		mat.set_shader_parameter("is_parcel_boundary", is_parcel_boundary)
		_materials[key] = mat
	return mat


func _edge_key(a: Vector2i, b: Vector2i) -> String:
	if b < a:
		var tmp := a
		a = b
		b = tmp
	return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]


func _get_wall_container(floor_node: Node3D) -> Node3D:
	var container := floor_node.get_node_or_null("WallContainer") as Node3D
	if container == null:
		container = Node3D.new()
		container.name = "WallContainer"
		floor_node.add_child(container)
	return container


func _get_floor() -> Node3D:
	var root := get_tree().current_scene
	if root == null:
		return null
	var world := root.get_node_or_null("World") as Node3D
	if world == null:
		return null
	for candidate: Node in world.find_children("*", "Floor", true, false):
		var floor: Floor = candidate as Floor
		if floor != null and floor.floor_level == "G":
			return floor
	return null


func _get_zone_manager() -> ZoneManager:
	var root := get_tree().current_scene
	if root:
		return root.get_node_or_null("World/ZoneManager") as ZoneManager
	return null
