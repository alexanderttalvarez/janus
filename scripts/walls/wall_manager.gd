## WallManager — Generates and updates wall meshes for the current floor.
##
## Rules (documents/game_design/elements/12_wall_system.md):
##   - Floor perimeter: wall around all built tiles (exterior walls).
##   - Zone perimeter: wall around each zone boundary; door gap where a
##     corridor tile borders the zone.
##   - Corridor walls: 4 walls per corridor tile, shared walls removed.
##
## Contiguous wall edges on the same line are MERGED into a single box.
## Walls are CENTERED on the boundary line — half the thickness on each
## side, shared between the two adjacent tiles (a building perimeter wall
## overhangs the floor edge by half a thickness).
## Corners get their own solid cube (0.1 x 3.0 x 0.1): where an X-axis run's
## end meets a Z-axis run's end, both runs are trimmed flush against the
## cube's inner faces. No wall boxes ever overlap (no coplanar faces, no
## z-fighting), and the cube's outward direction points away from the room's
## interior, so in Cutaway the corner facing the camera opens while the back
## corners stay solid.
##
## Walls use wall_clipping.gdshader, which classifies the whole wall by its
## outward direction (mesh local +Z): walls facing the camera disappear in
## Cutaway mode, walls facing away stay solid.
class_name WallManager
extends Node


## Wall height in world units — matches GridManager.FLOOR_HEIGHT.
const WALL_HEIGHT: float = 3.0
## Wall thickness — matches the floor tile height (0.1) so walls read as
## solid slabs, not paper planes.
const WALL_THICKNESS: float = 0.1
## Wall color (concrete beige). Materials are post-MVP.
const WALL_COLOR: Color = Color(0.85, 0.82, 0.78)
## Opening width at corridor connections (door).
const DOOR_GAP: float = 0.6
## Adjacency tolerance when merging edge spans.
const MERGE_EPSILON: float = 0.01

var _wall_material: ShaderMaterial = null


func _ready() -> void:
	# Force-load the wall shader NOW so its global uniforms (camera_direction,
	# wall_mode) register in the RenderingServer before GameManager sets them.
	_get_wall_material()

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

	# Remove previous wall meshes. Immediate free (not queue_free) so a
	# rebuild never leaves a one-frame double-wall flicker behind.
	for child: Node in container.get_children():
		container.remove_child(child)
		child.free()

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

	# Edges already placed, keyed canonically to avoid doubles.
	var placed: Dictionary = {}
	# Non-door edges awaiting merge into runs.
	var pieces: Array = []

	# 1) Floor perimeter — built tile edges facing non-built space.
	for pos: Vector2i in built.keys():
		for dir: Vector2i in _DIRS:
			var n: Vector2i = pos + dir
			if not built.has(n):
				_record_edge(placed, pieces, container, pos, n, false)

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
				_record_edge(placed, pieces, container, pos, n, corridor.has(n))

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
			_record_edge(placed, pieces, container, pos, n, false)

	# 4) Merge contiguous pieces into runs, then place the wall boxes.
	var runs := _merge_runs(pieces)
	_place_corner_cubes(container, runs)
	for run: Dictionary in runs:
		_create_wall_mesh(container, run)


const _DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]


## Dedup an edge and either record it for merging or (for door edges) spawn
## the two door segments immediately.
func _record_edge(
	placed: Dictionary, pieces: Array, container: Node3D,
	pos: Vector2i, neighbor: Vector2i, door: bool
) -> void:
	var key := _edge_key(pos, neighbor)
	if placed.has(key):
		return
	placed[key] = true
	var dx: int = neighbor.x - pos.x
	var dz: int = neighbor.y - pos.y
	var normal := Vector3(float(dx), 0.0, float(dz))

	if door:
		_create_door_segments(container, pos, neighbor, normal)
		return

	if dx != 0:
		# East/west edge — wall runs along Z at line x.
		pieces.append({
			"axis": "z",
			"line": float(pos.x) + 0.5 + float(dx) * 0.5,
			"from": float(pos.y),
			"to": float(pos.y) + 1.0,
			"normal": normal,
		})
	else:
		# North/south edge — wall runs along X at line z.
		pieces.append({
			"axis": "x",
			"line": float(pos.y) + 0.5 + float(dz) * 0.5,
			"from": float(pos.x),
			"to": float(pos.x) + 1.0,
			"normal": normal,
		})


## Merge all recorded pieces: group by (axis, line, normal direction), then
## join adjacent spans into single runs.
func _merge_runs(pieces: Array) -> Array:
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


## Whether one of `run`'s span ends sits on `coord` (within merge tolerance).
func _span_end_at(run: Dictionary, coord: float) -> bool:
	return absf(run["from"] - coord) <= MERGE_EPSILON or absf(run["to"] - coord) <= MERGE_EPSILON


## Fill every convex corner with a solid cube and trim the meeting runs so
## they butt flush against it. A convex corner exists where an X-axis run's
## span end sits on a Z-axis run's line AND the Z-axis run's span end sits
## on the X-axis run's line — both walls end at the same point. The cube
## occupies the corner square between the two wall bodies (interior side of
## both). T-junctions — where ONE run ends at the other run's line while the
## other runs through (e.g. a zone wall meeting the building perimeter) —
## get a cube too: the short run is trimmed flush against it and the long
## run is split so both sides butt the cube cleanly.
func _place_corner_cubes(container: Node3D, runs: Array) -> void:
	# T-junction splits (long run key -> cut intervals), applied after the
	# pass so multiple junctions on one long run combine correctly.
	var t_splits: Dictionary = {}
	for run_x: Dictionary in runs:
		if run_x["axis"] != "x":
			continue
		for run_z: Dictionary in runs:
			if run_z["axis"] != "z":
				continue
			var x_line: float = run_z["line"]
			var z_line: float = run_x["line"]
			var x_end := _span_end_at(run_x, x_line)
			var z_end := _span_end_at(run_z, z_line)
			if x_end and z_end:
				_place_convex_corner(container, run_x, run_z, x_line, z_line)
			elif x_end != z_end:
				_place_t_junction(container, run_x, run_z, x_line, z_line, x_end, t_splits)
	_apply_t_splits(runs, t_splits)


## Corner junction: both runs end at the junction point. The cube fills the
## corner square — the walls' overlap for convex corners, or the open notch
## between the end caps for concave (inner) corners. In both cases the walls
## already butt the cube flush, so no span checks are needed.
func _place_convex_corner(container: Node3D, run_x: Dictionary, run_z: Dictionary, x_line: float, z_line: float) -> void:
	var in_x: float = 1.0 if run_z["normal"].x < 0.0 else -1.0
	var in_z: float = 1.0 if run_x["normal"].z < 0.0 else -1.0
	var t2 := WALL_THICKNESS * 0.5
	_create_corner_cube(container, run_x, run_z, in_x, in_z)


## Create one corner cube at the junction of `run_x` (X-axis) and `run_z`
## (Z-axis), trimming the runs whose spans overlap the cube. The cube is
## axis-aligned (its faces match the wall lines) and gets a per-corner
## material whose baked outward direction points away from the room's
## interior — the shader opens only the camera-facing corner.
func _create_corner_cube(container: Node3D, run_x: Dictionary, run_z: Dictionary, in_x: float, in_z: float) -> void:
	var x_line: float = run_z["line"]
	var z_line: float = run_x["line"]
	var t2 := WALL_THICKNESS * 0.5
	# The cube is centered on the junction lines. Each run's end at the
	# junction is trimmed to the cube's face on its side: the run extends
	# from the line in its span direction, so its end moves by half a
	# thickness (convex and concave corners alike).
	if absf(run_x["from"] - x_line) <= MERGE_EPSILON:
		run_x["from"] = x_line + t2
	elif absf(run_x["to"] - x_line) <= MERGE_EPSILON:
		run_x["to"] = x_line - t2
	if absf(run_z["from"] - z_line) <= MERGE_EPSILON:
		run_z["from"] = z_line + t2
	elif absf(run_z["to"] - z_line) <= MERGE_EPSILON:
		run_z["to"] = z_line - t2

	_spawn_corner_cube(container, Vector3(x_line, WALL_HEIGHT * 0.5, z_line), Vector2(-in_x, -in_z).normalized(), "Corner_%.1f_%.1f" % [x_line, z_line])


## Create one corner cube mesh: axis-aligned box with the corner's outward
## direction baked into its material (see wall_clipping.gdshader).
func _spawn_corner_cube(container: Node3D, center: Vector3, outward: Vector2, cube_name: String) -> void:
	var cube := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(WALL_THICKNESS, WALL_HEIGHT, WALL_THICKNESS)
	box.material = _get_corner_material(outward)
	cube.mesh = box
	cube.position = center
	cube.name = cube_name
	container.add_child(cube)


## T-junction: one run ends at the other run's line while the other runs
## through the junction point (e.g. a zone wall meeting the building
## perimeter). Their bodies overlap in the corner square — fill it with a
## corner cube, trim the short run flush against the cube's far face, and
## record a split of the long run so both sides butt the cube cleanly.
func _place_t_junction(container: Node3D, run_x: Dictionary, run_z: Dictionary, x_line: float, z_line: float, x_ends: bool, t_splits: Dictionary) -> void:
	var t2 := WALL_THICKNESS * 0.5
	var in_x: float = 1.0 if run_z["normal"].x < 0.0 else -1.0
	var in_z: float = 1.0 if run_x["normal"].z < 0.0 else -1.0
	# The cube (centered on the junction) must sit inside both spans —
	# rejects phantom junctions where the runs don't actually reach each
	# other.
	if x_line < minf(run_x["from"], run_x["to"]) - MERGE_EPSILON or x_line > maxf(run_x["from"], run_x["to"]) + MERGE_EPSILON:
		return
	if z_line < minf(run_z["from"], run_z["to"]) - MERGE_EPSILON or z_line > maxf(run_z["from"], run_z["to"]) + MERGE_EPSILON:
		return
	_spawn_corner_cube(container, Vector3(x_line, WALL_HEIGHT * 0.5, z_line), Vector2(-in_x, -in_z).normalized(), "Corner_%.1f_%.1f" % [x_line, z_line])
	if x_ends:
		# run_x ends at run_z's line: trim its end to the cube's face.
		if absf(run_x["from"] - x_line) <= MERGE_EPSILON:
			run_x["from"] = x_line + t2
		else:
			run_x["to"] = x_line - t2
		var key := _t_run_key(run_z)
		var cuts: Array = t_splits.get(key, [])
		cuts.append([z_line - t2, z_line + t2])
		t_splits[key] = cuts
	else:
		# run_z ends at run_x's line: trim its end to the cube's face.
		if absf(run_z["from"] - z_line) <= MERGE_EPSILON:
			run_z["from"] = z_line + t2
		else:
			run_z["to"] = z_line - t2
		var key := _t_run_key(run_x)
		var cuts: Array = t_splits.get(key, [])
		cuts.append([x_line - t2, x_line + t2])
		t_splits[key] = cuts


## Identity key for a run along the shared line (line + facing direction).
func _t_run_key(run: Dictionary) -> String:
	var dir: String = "p" if (run["normal"].x + run["normal"].z) > 0.0 else "m"
	return "%s:%.4f:%s" % [run["axis"], run["line"], dir]


## Apply recorded T-junction splits: cut each long run at its recorded
## intervals, keeping the original run as the first segment and appending
## new run dicts for the rest.
func _apply_t_splits(runs: Array, t_splits: Dictionary) -> void:
	for key: String in t_splits:
		var cuts: Array = t_splits[key]
		# Distribute cuts to the matching runs (same line, same facing) by
		# span containment — a line can hold several separate runs.
		for run: Dictionary in runs:
			if _t_run_key(run) != key:
				continue
			var span_from: float = run["from"]
			var span_to: float = run["to"]
			var run_cuts: Array = []
			var remaining: Array = []
			for cut: Array in cuts:
				var c0: float = minf(cut[0], cut[1])
				var c1: float = maxf(cut[0], cut[1])
				if c0 >= minf(span_from, span_to) - MERGE_EPSILON and c1 <= maxf(span_from, span_to) + MERGE_EPSILON:
					run_cuts.append([c0, c1])
				else:
					remaining.append(cut)
			cuts = remaining
			if run_cuts.is_empty():
				continue
			run_cuts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
			var segments: Array = []
			var cursor: float = span_from
			for cut: Array in run_cuts:
				var c0: float = cut[0]
				var c1: float = cut[1]
				if c0 < cursor - MERGE_EPSILON:
					continue
				if c0 > cursor + MERGE_EPSILON:
					segments.append([cursor, c0])
				cursor = maxf(cursor, c1)
			if span_to > cursor + MERGE_EPSILON:
				segments.append([cursor, span_to])
			if segments.is_empty():
				continue
			run["from"] = segments[0][0]
			run["to"] = segments[0][1]
			for i in range(1, segments.size()):
				var seg := run.duplicate()
				seg["from"] = segments[i][0]
				seg["to"] = segments[i][1]
				runs.append(seg)


## Create one wall box. The wall is centered on the run's line — half the
## thickness on each side, shared between the two adjacent tiles. Corners
## are filled by dedicated cubes (see _place_corner_cubes), so wall boxes
## never overlap — all walls are full run length at full WALL_HEIGHT.
func _create_wall_mesh(container: Node3D, run: Dictionary) -> void:
	var axis: String = run["axis"]
	var line: float = run["line"]
	var from: float = run["from"]
	var to: float = run["to"]
	var normal: Vector3 = run["normal"]
	var height := WALL_HEIGHT

	var center: Vector3
	if axis == "z":
		center = Vector3(line, height * 0.5, (from + to) * 0.5)
	else:
		center = Vector3((from + to) * 0.5, height * 0.5, line)

	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(to - from, height, WALL_THICKNESS)
	box.material = _get_wall_material()
	wall.mesh = box
	wall.position = center
	if axis == "z":
		wall.rotation.y = deg_to_rad(90.0) if normal.x > 0.0 else deg_to_rad(-90.0)
	else:
		wall.rotation.y = 0.0 if normal.z > 0.0 else deg_to_rad(180.0)
	wall.name = "Wall_%s_%.1f_%.1f" % [axis, line, (from + to) * 0.5]
	container.add_child(wall)


## Two short segments flanking a centered door opening on one edge.
func _create_door_segments(
	container: Node3D, pos: Vector2i, neighbor: Vector2i, normal: Vector3
) -> void:
	var dx: int = neighbor.x - pos.x
	var dz: int = neighbor.y - pos.y
	var line: float = float(pos.x) + 0.5 + float(dx) * 0.5 if dx != 0 else float(pos.y) + 0.5 + float(dz) * 0.5
	var mid_along: float = float(pos.y) + 0.5 if dx != 0 else float(pos.x) + 0.5
	var t2 := WALL_THICKNESS * 0.5
	var seg_width := (1.0 - DOOR_GAP) * 0.5
	var offset := DOOR_GAP * 0.5 + seg_width

	var seg_a := {"axis": "z" if dx != 0 else "x", "line": line, "normal": normal,
		"from": mid_along - offset, "to": mid_along - offset + seg_width}
	var seg_b := {"axis": "z" if dx != 0 else "x", "line": line, "normal": normal,
		"from": mid_along + offset - seg_width, "to": mid_along + offset}
	_create_wall_mesh(container, seg_a)
	_create_wall_mesh(container, seg_b)


func _edge_key(a: Vector2i, b: Vector2i) -> String:
	if b < a:
		var tmp := a
		a = b
		b = tmp
	return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]


func _get_wall_material() -> ShaderMaterial:
	if _wall_material == null:
		_wall_material = ShaderMaterial.new()
		_wall_material.shader = load("res://assets/shaders/wall_clipping.gdshader") as Shader
		_wall_material.set_shader_parameter("wall_color", WALL_COLOR)
	return _wall_material


## Per-corner material: the cube stays axis-aligned (faces match the walls),
## so its cutaway classification uses the corner's outward diagonal (away
## from the room interior) baked into the material, with the shader's 0.5
## front-face threshold for corners.
func _get_corner_material(outward: Vector2) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/wall_clipping.gdshader") as Shader
	mat.set_shader_parameter("wall_color", WALL_COLOR)
	mat.set_shader_parameter("is_corner", true)
	mat.set_shader_parameter("corner_outward", outward)
	return mat


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
