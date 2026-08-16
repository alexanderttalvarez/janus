## PathfindingGraph — Layered A* pathfinding across multiple floors.
##
## Maintains a graph of walkable tiles with:
##   - Intra-floor edges: adjacent walkable tiles on the same floor.
##   - Cross-floor edges: circulation elements (stairs, elevators) connecting floors.
##
## Visitors query the graph, not individual tile arrays.
class_name PathfindingGraph
extends RefCounted


## Plot ID used for the pedestrian ring outside a building plot.
const EXTERIOR_PLOT_ID: String = "exterior"


## Internal node representation.
class PathNode:
	var plot_id: String
	var floor_level: String
	var position: Vector2i

	func _init(p_plot: String, p_floor: String, p_pos: Vector2i) -> void:
		plot_id = p_plot
		floor_level = p_floor
		position = p_pos

	func get_key() -> String:
		return "%s:%s:%d,%d" % [plot_id, floor_level, position.x, position.y]

	func _to_string() -> String:
		return get_key()


## Adjacency list: node_key → Array[PathNode].
var _edges: Dictionary = {}  # Dictionary[String, Array[PathNode]]

## Whether the graph needs rebuilding.
var _dirty: bool = false


## Mark the graph as needing a rebuild.
func mark_dirty() -> void:
	_dirty = true


## Rebuild the entire graph from all plots and floors.
## Called after significant changes (zone placement, tile purchase, circulation changes).
func rebuild(plots: Dictionary) -> void:
	_edges.clear()
	_dirty = false

	for plot_id in plots:
		var plot: PlotData = plots[plot_id]
		for floor_level in plot.floors:
			var floor_grid: FloorGrid = plot.floors[floor_level]
			_add_floor_edges(plot_id, floor_level, floor_grid)

	# Cross-floor edges from circulation elements are added separately.
	# See add_circulation_edge().


## Add intra-floor edges for a single floor.
func _add_floor_edges(plot_id: String, floor_level: String, floor_grid: FloorGrid) -> void:
	for x in range(floor_grid.width):
		for y in range(floor_grid.height):
			if not floor_grid.is_walkable(x, y):
				continue
			var node := PathNode.new(plot_id, floor_level, Vector2i(x, y))
			var key := node.get_key()
			if not _edges.has(key):
				_edges[key] = []

			for n_pos in floor_grid.get_walkable_neighbors(x, y):
				var neighbor := PathNode.new(plot_id, floor_level, n_pos)
				_edges[key].append(neighbor)


## Add a bidirectional edge between a building boundary tile and its exterior door tile.
func add_exterior_door_edge(
	plot_id: String, floor_level: String, interior_pos: Vector2i, exterior_pos: Vector2i
) -> void:
	var interior_key := PathNode.new(plot_id, floor_level, interior_pos).get_key()
	var exterior_key := PathNode.new(EXTERIOR_PLOT_ID, floor_level, exterior_pos).get_key()
	if not _edges.has(interior_key):
		_edges[interior_key] = []
	if not _edges.has(exterior_key):
		_edges[exterior_key] = []
	_edges[interior_key].append(PathNode.new(EXTERIOR_PLOT_ID, floor_level, exterior_pos))
	_edges[exterior_key].append(PathNode.new(plot_id, floor_level, interior_pos))


## Add a cross-floor circulation edge (e.g., stair connects tile_a to tile_b on different floors).
func add_circulation_edge(
	plot_a: String, floor_a: String, pos_a: Vector2i,
	plot_b: String, floor_b: String, pos_b: Vector2i
) -> void:
	var key_a := PathNode.new(plot_a, floor_a, pos_a).get_key()
	var key_b := PathNode.new(plot_b, floor_b, pos_b).get_key()

	if not _edges.has(key_a):
		_edges[key_a] = []
	_edges[key_a].append(PathNode.new(plot_b, floor_b, pos_b))

	if not _edges.has(key_b):
		_edges[key_b] = []
	_edges[key_b].append(PathNode.new(plot_a, floor_a, pos_a))


## Remove a cross-floor circulation edge.
func remove_circulation_edge(
	plot_a: String, floor_a: String, pos_a: Vector2i,
	plot_b: String, floor_b: String, pos_b: Vector2i
) -> void:
	var key_a := PathNode.new(plot_a, floor_a, pos_a).get_key()
	var key_b := PathNode.new(plot_b, floor_b, pos_b).get_key()

	if _edges.has(key_a):
		_edges[key_a] = _edges[key_a].filter(
			func(n: PathNode): return not (n.plot_id == plot_b and n.floor_level == floor_b and n.position == pos_b)
		)

	if _edges.has(key_b):
		_edges[key_b] = _edges[key_b].filter(
			func(n: PathNode): return not (n.plot_id == plot_a and n.floor_level == floor_a and n.position == pos_a)
		)


## Find a path from start to end using A*.
## Returns an Array of PathNode from start to end, or empty if no path.
func find_path(
	start_plot: String, start_floor: String, start_pos: Vector2i,
	end_plot: String, end_floor: String, end_pos: Vector2i
) -> Array[PathNode]:
	if _dirty:
		push_warning("PathfindingGraph.find_path(): graph is dirty, results may be stale.")

	var start := PathNode.new(start_plot, start_floor, start_pos)
	var end := PathNode.new(end_plot, end_floor, end_pos)
	var start_key := start.get_key()
	var end_key := end.get_key()

	if not _edges.has(start_key) or not _edges.has(end_key):
		return []

	return _a_star(start, end)


## A* implementation.
func _a_star(start: PathNode, goal: PathNode) -> Array[PathNode]:
	var start_key := start.get_key()
	var goal_key := goal.get_key()

	var open_set: Array = [start_key]
	var came_from: Dictionary = {}

	# g_score: cost from start to node.
	var g_score: Dictionary = {}
	g_score[start_key] = 0.0

	# f_score: g_score + heuristic.
	var f_score: Dictionary = {}
	f_score[start_key] = _heuristic(start, goal)

	while not open_set.is_empty():
		# Find node with lowest f_score.
		var current_key: String = open_set[0]
		for k in open_set:
			if f_score.get(k, INF) < f_score.get(current_key, INF):
				current_key = k

		if current_key == goal_key:
			return _reconstruct_path(came_from, current_key)

		open_set.erase(current_key)

		var neighbors: Array[PathNode] = _edges.get(current_key, [])
		for neighbor in neighbors:
			var neighbor_key := neighbor.get_key()
			var tentative_g: float = g_score.get(current_key, INF) + 1.0  # Cost of 1 per step.

			if tentative_g < g_score.get(neighbor_key, INF):
				came_from[neighbor_key] = current_key
				g_score[neighbor_key] = tentative_g
				f_score[neighbor_key] = tentative_g + _heuristic(neighbor, goal)
				if not open_set.has(neighbor_key):
					open_set.append(neighbor_key)

	return []


## Manhattan distance heuristic.
func _heuristic(a: PathNode, b: PathNode) -> float:
	return absi(a.position.x - b.position.x) + absi(a.position.y - b.position.y)


## Reconstruct the path from came_from dictionary.
func _reconstruct_path(came_from: Dictionary, current_key: String) -> Array[PathNode]:
	var path: Array[PathNode] = []

	# Parse the key back into a PathNode and prepend.
	var keys: Array[String] = []
	while came_from.has(current_key):
		keys.push_front(current_key)
		current_key = came_from[current_key]
	keys.push_front(current_key)  # Add start node.

	for k in keys:
		path.append(_parse_key(k))

	return path


## Parse a key string back into a PathNode.
func _parse_key(key: String) -> PathNode:
	var parts := key.split(":")
	if parts.size() < 3:
		return PathNode.new("", "", Vector2i.ZERO)

	var plot_id := parts[0]
	var floor_level := parts[1]
	var pos_parts := parts[2].split(",")
	var x := pos_parts[0].to_int() if pos_parts.size() > 0 else 0
	var y := pos_parts[1].to_int() if pos_parts.size() > 1 else 0

	return PathNode.new(plot_id, floor_level, Vector2i(x, y))


## Get the number of nodes in the graph.
func get_node_count() -> int:
	return _edges.size()
