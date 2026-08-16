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
##   - Every junction (L-corner, T-junction, or crossing) gets a CORNER CUBE
##     (thickness × height × thickness) centered on the junction point.
##   - Runs are SPLIT at junctions and trimmed flush against the cube faces.
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


## Wall height in world units — matches GridManager.FLOOR_HEIGHT.
const WALL_HEIGHT: float = 3.0
## Wall thickness — matches the floor tile height (0.1) so walls read as
## solid slabs, not paper planes.
const WALL_THICKNESS: float = 0.1
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

const _HALF_THICKNESS: float = WALL_THICKNESS * 0.5
const _DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]

var _materials: Dictionary = {}  # material cache key -> ShaderMaterial
var _box_meshes: Dictionary = {}  # size key -> BoxMesh


func _ready() -> void:
	# Force-load the wall shader NOW so its global uniforms (camera_direction,
	# wall_mode) register in the RenderingServer before GameManager sets them.
	_get_wall_material(Vector2(0.0, 1.0), 0.0, false)

	# Walls adapt automatically to zone changes and tile purchases.
	EventBus.zone_created.connect(func(_id: String, _t: String, _c: int): rebuild())
	EventBus.zone_modified.connect(func(_id: String): rebuild())
	EventBus.zone_deleted.connect(func(_id: String): rebuild())
	EventBus.zone_wall_mode_changed.connect(func(_id: String, _on: bool): rebuild())
	EventBus.tile_purchased.connect(func(_f: int, _x: int, _y: int): rebuild())


## Regenerate all wall meshes from the current grid + zone state.
func rebuild() -> void:
	var floor_node := _get_floor()
	if floor_node == null:
		return
	var gm := _get_grid_manager()
	if gm == null:
		return
	var fg := gm.get_floor_grid()
	if fg == null:
		return

	var container := _get_wall_container(floor_node)
	_clear_walls(container)

	# Collect tile membership.
	var zone_of: Dictionary = {}  # Vector2i -> zone_id
	var zm := _get_zone_manager()
	var zones: Array[ZoneData] = []
	if zm:
		for zone: ZoneData in zm.get_zones_on_floor("G"):
			if not zone.walls_enabled:
				continue
			zones.append(zone)
			for t: Vector2i in zone.tiles:
				zone_of[t] = zone.id

	var corridor: Dictionary = {}  # Vector2i -> true
	var built: Dictionary = {}     # Vector2i -> true
	for x in range(fg.width):
		for y in range(fg.height):
			var tile: GridTile = fg.get_tile(x, y)
			if tile == null or not (tile.owned and tile.floor_built):
				continue
			built[Vector2i(x, y)] = true
			if tile.element == GridTile.TileElement.CIRCULATION:
				corridor[Vector2i(x, y)] = true

	# Pipeline: edges -> pieces -> runs -> junctions -> boxes.
	var pieces := _collect_wall_pieces(built, corridor, zones, zone_of)
	var runs := _merge_pieces_into_runs(pieces)
	var joints_by_run: Dictionary = {}  # run index -> Array[float]
	var junctions := _find_wall_junctions(runs, joints_by_run)
	for junction: Dictionary in junctions:
		_build_corner_cube(container, junction["point"], junction["outward"])
	for i in range(runs.size()):
		_build_wall_segments(container, runs[i], joints_by_run.get(i, []))


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
	built: Dictionary, corridor: Dictionary, zones: Array[ZoneData], zone_of: Dictionary
) -> Array:
	var placed: Dictionary = {}  # edge key -> true
	var pieces: Array = []

	# 1) Floor perimeter — built tile edges facing non-built space.
	for pos: Vector2i in built.keys():
		for dir: Vector2i in _DIRS:
			var n: Vector2i = pos + dir
			if not built.has(n):
				_add_wall_piece(placed, pieces, pos, n, false)

	# 2) Zone perimeter — zone tile edges facing other built space.
	#    Door gap when the neighbor is a corridor tile.
	for zone: ZoneData in zones:
		for pos: Vector2i in zone.tiles:
			for dir: Vector2i in _DIRS:
				var n: Vector2i = pos + dir
				if zone_of.get(n, "") == zone.id:
					continue
				if not built.has(n):
					continue  # Exterior handled by the floor perimeter.
				_add_wall_piece(placed, pieces, pos, n, corridor.has(n))

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
			_add_wall_piece(placed, pieces, pos, n, false)

	return pieces


## Dedup an edge and record its wall piece(s) for merging. Door edges
## produce two short flank pieces leaving a centered DOOR_GAP opening.
func _add_wall_piece(
	placed: Dictionary, pieces: Array, pos: Vector2i, neighbor: Vector2i, has_door: bool
) -> void:
	var key := _edge_key(pos, neighbor)
	if placed.has(key):
		return
	placed[key] = true
	var normal := Vector3(float(neighbor.x - pos.x), 0.0, float(neighbor.y - pos.y))
	if has_door:
		pieces.append_array(_make_door_pieces(pos, normal))
	else:
		pieces.append(_make_edge_piece(pos, normal))


## Wall piece covering one full tile edge, centered on the boundary line.
func _make_edge_piece(pos: Vector2i, normal: Vector3) -> Dictionary:
	if normal.x != 0.0:
		# East/west edge — wall runs along Z at line x.
		return {
			"axis": "z",
			"line": float(pos.x) + 0.5 + normal.x * 0.5,
			"from": float(pos.y),
			"to": float(pos.y) + 1.0,
			"normal": normal,
		}
	# North/south edge — wall runs along X at line z.
	return {
		"axis": "x",
		"line": float(pos.y) + 0.5 + normal.z * 0.5,
		"from": float(pos.x),
		"to": float(pos.x) + 1.0,
		"normal": normal,
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


## Merge all recorded pieces: group by (axis, line, normal direction), then
## join adjacent spans into single runs.
func _merge_pieces_into_runs(pieces: Array) -> Array:
	var groups: Dictionary = {}  # key -> Array of pieces
	for piece: Dictionary in pieces:
		var normal: Vector3 = piece["normal"]
		var dir_key: String = "p" if (normal.x + normal.z) > 0.0 else "m"
		var key := "%s:%.4f:%s" % [piece["axis"], piece["line"], dir_key]
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
				})
				run_from = piece["from"]
				run_to = piece["to"]
		runs.append({
			"axis": group[0]["axis"],
			"line": group[0]["line"],
			"from": run_from,
			"to": run_to,
			"normal": group[0]["normal"],
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
			var outward := Vector2(run_x["normal"].x, run_x["normal"].z) \
				+ Vector2(run_z["normal"].x, run_z["normal"].z)
			junctions.append({"point": point, "outward": outward.normalized()})
			_add_joint(joints_by_run, i, point.x)
			_add_joint(joints_by_run, j, point.y)
	return junctions


## Whether the run's span contains `coord` (endpoints included).
func _span_covers(run: Dictionary, coord: float) -> bool:
	return coord >= run["from"] - MERGE_EPSILON and coord <= run["to"] + MERGE_EPSILON


## Record a junction coordinate on a run (sorted, deduplicated).
func _add_joint(joints_by_run: Dictionary, run_index: int, coord: float) -> void:
	if not joints_by_run.has(run_index):
		joints_by_run[run_index] = []
	var joints: Array = joints_by_run[run_index]
	for existing: float in joints:
		if absf(existing - coord) <= MERGE_EPSILON:
			return
	joints.append(coord)
	joints.sort()


## Whether the run has a junction at `coord` (span ends included).
func _has_joint_at(joints: Array, coord: float) -> bool:
	for joint: float in joints:
		if absf(joint - coord) <= MERGE_EPSILON:
			return true
	return false


## Build the wall boxes for one run: split at junction coords and trim each
## segment a half-thickness away from corner cubes, so boxes butt flush
## without overlapping. Free ends (e.g. door gaps) stay untrimmed.
func _build_wall_segments(container: Node3D, run: Dictionary, joints: Array) -> void:
	var cuts: Array[float] = [run["from"]]
	for joint: float in joints:
		if joint > run["from"] + MERGE_EPSILON and joint < run["to"] - MERGE_EPSILON:
			cuts.append(joint)
	cuts.append(run["to"])

	for i in range(cuts.size() - 1):
		var seg_from: float = cuts[i]
		var seg_to: float = cuts[i + 1]
		if _has_joint_at(joints, seg_from):
			seg_from += _HALF_THICKNESS
		if _has_joint_at(joints, seg_to):
			seg_to -= _HALF_THICKNESS
		if seg_to - seg_from < MERGE_EPSILON:
			continue
		_spawn_wall_box(container, run, seg_from, seg_to)


## Spawn one straight wall box (plus its cutaway cap) covering [from, to]
## along the run's axis, centered on the boundary line.
func _spawn_wall_box(container: Node3D, run: Dictionary, from: float, to: float) -> void:
	var length := to - from
	var mid := (from + to) * 0.5
	var line: float = run["line"]
	var size: Vector3
	var center: Vector3
	if run["axis"] == "z":
		size = Vector3(WALL_THICKNESS, WALL_HEIGHT, length)
		center = Vector3(line, WALL_HEIGHT * 0.5, mid)
	else:
		size = Vector3(length, WALL_HEIGHT, WALL_THICKNESS)
		center = Vector3(mid, WALL_HEIGHT * 0.5, line)
	var outward := Vector2(run["normal"].x, run["normal"].z)
	var label := "Wall_%s_%.1f_%.1f" % [run["axis"], line, mid]
	_spawn_box(container, center, size, outward, 0.0, false, label)
	_spawn_box(
		container, Vector3(center.x, CAP_Y, center.z),
		_inset_cap_size(size), outward, 0.0, true, label + "_cap"
	)


## Spawn a corner cube (plus its cap) at a junction point. The cube fills
## the square where the trimmed runs meet, so the wall outline stays
## continuous with no overlaps. Its outward direction is the corner diagonal.
func _build_corner_cube(container: Node3D, point: Vector2, outward: Vector2) -> void:
	var size := Vector3(WALL_THICKNESS, WALL_HEIGHT, WALL_THICKNESS)
	var center := Vector3(point.x, WALL_HEIGHT * 0.5, point.y)
	var label := "Corner_%.0f_%.0f" % [point.x, point.y]
	_spawn_box(container, center, size, outward, CORNER_FRONT_THRESHOLD, false, label)
	_spawn_box(
		container, Vector3(point.x, CAP_Y, point.y),
		_inset_cap_size(size), outward, CORNER_FRONT_THRESHOLD, true, label + "_cap"
	)


## Spawn a single wall box mesh instance. Meshes are shared per size.
func _spawn_box(
	container: Node3D, center: Vector3, size: Vector3,
	outward: Vector2, front_threshold: float, is_cap: bool, label: String
) -> void:
	var box := MeshInstance3D.new()
	box.mesh = _get_box_mesh(size)
	box.material_override = _get_wall_material(outward, front_threshold, is_cap)
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
func _get_wall_material(outward: Vector2, front_threshold: float, is_cap: bool) -> ShaderMaterial:
	var key := "%.2f|%.2f|%.2f|%s" % [outward.x, outward.y, front_threshold, "cap" if is_cap else "wall"]
	var mat := _materials.get(key) as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = load("res://assets/shaders/wall_clipping.gdshader") as Shader
		mat.set_shader_parameter("wall_color", WALL_COLOR)
		mat.set_shader_parameter("outward", outward)
		mat.set_shader_parameter("front_threshold", front_threshold)
		mat.set_shader_parameter("is_cap", is_cap)
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
	return world.get_node_or_null("floor_plot_0_G") as Node3D


func _get_grid_manager() -> GridManager:
	var root := get_tree().current_scene
	if root:
		return root.get_node_or_null("World/GridManager") as GridManager
	return null


func _get_zone_manager() -> ZoneManager:
	var root := get_tree().current_scene
	if root:
		return root.get_node_or_null("World/ZoneManager") as ZoneManager
	return null
