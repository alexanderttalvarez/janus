## GridManager — Central authority for tile grids, plots, floors, and pathfinding.
##
## Manages:
##   - Multiple plots (MVP: single plot_0)
##   - Floor creation via floor.tscn instances
##   - Tile data access and mutation
##   - Pathfinding graph updates
##
## This is NOT an autoload — it is a child of main_game.tscn.
class_name GridManager
extends Node


## Name of the default plot used by convenience methods.
const DEFAULT_PLOT: String = "plot_0"

## Default floor level (ground floor).
const GROUND_FLOOR: String = "G"

## Tile size in world units. Matches the 1.0-unit visual tile grid in floor.tscn.
const TILE_SIZE: float = 1.0

## Floor height spacing in world units.
const FLOOR_HEIGHT: float = 3.0


## All plots managed by this GridManager.
var plots: Dictionary = {}  # Dictionary[String, PlotData]

## Pathfinding graph for all plots and floors.
var pathfinding_graph: PathfindingGraph = PathfindingGraph.new()

## Scene references to instantiated floor.tscn nodes, keyed by "plot_id:floor_level".
var _floor_instances: Dictionary = {}  # Dictionary[String, Node3D]


func _ready() -> void:
	pass  # Initialization is done by the caller (main_game.tscn or test scene).


# ── Plot Management ────────────────────────────────────────────────────


## Create a new plot with the given dimensions and footprint.
func create_plot(
	plot_id: String,
	width: int,
	height: int,
	footprint_path: String = "",
	boundary: Rect2i = Rect2i()
) -> PlotData:
	var plot := PlotData.new()
	plot.plot_id = plot_id
	plot.boundary = boundary

	var footprint: Array
	if not footprint_path.is_empty():
		footprint = FootprintLoader.load_footprint(footprint_path)
	else:
		footprint = FootprintLoader.create_full(width, height)

	# Create ground floor.
	var ground_floor := FloorGrid.new()
	ground_floor.initialize(width, height, footprint)
	plot.add_floor(GROUND_FLOOR, ground_floor)

	plots[plot_id] = plot
	return plot


## Get a plot by ID. Returns null if not found.
func get_plot(plot_id: String = DEFAULT_PLOT) -> PlotData:
	return plots.get(plot_id, null)


## Remove a plot and all its floors.
func remove_plot(plot_id: String) -> void:
	plots.erase(plot_id)
	# TODO: Remove floor scene instances.


# ── Floor Management ───────────────────────────────────────────────────


## Add a new floor level to a plot.
func add_floor(plot_id: String, floor_level: String, floor_grid: FloorGrid) -> void:
	var plot := get_plot(plot_id)
	if plot == null:
		push_error("GridManager.add_floor(): plot '%s' not found." % plot_id)
		return
	plot.add_floor(floor_level, floor_grid)
	pathfinding_graph.mark_dirty()


## Get the FloorGrid for a specific plot and floor level.
func get_floor_grid(plot_id: String = DEFAULT_PLOT, floor_level: String = GROUND_FLOOR) -> FloorGrid:
	var plot := get_plot(plot_id)
	if plot == null:
		return null
	return plot.get_floor(floor_level)


## Get all floor levels for a plot.
func get_floor_levels(plot_id: String = DEFAULT_PLOT) -> Array[String]:
	var plot := get_plot(plot_id)
	if plot == null:
		return []
	return plot.get_floor_levels()


## Get world-space Y position for a floor level.
func get_floor_world_y(floor_level: String) -> float:
	# Ground floor is at Y=0. Floors above are positive, below are negative.
	var level_num := 0
	if floor_level != GROUND_FLOOR:
		# Parse "F1", "F2", ..., "B1", "B2", ...
		var prefix := floor_level[0]
		var num_str := floor_level.substr(1)
		level_num = num_str.to_int()
		if prefix == "B":
			level_num = -level_num
	return level_num * FLOOR_HEIGHT


# ── Tile Data Access ───────────────────────────────────────────────────


## Get a tile at (x, y) on a specific plot and floor.
func get_tile(x: int, y: int, plot_id: String = DEFAULT_PLOT, floor_level: String = GROUND_FLOOR) -> GridTile:
	var fg := get_floor_grid(plot_id, floor_level)
	if fg == null:
		return null
	return fg.get_tile(x, y)


## Check if a tile is walkable.
func is_walkable(x: int, y: int, plot_id: String = DEFAULT_PLOT, floor_level: String = GROUND_FLOOR) -> bool:
	var fg := get_floor_grid(plot_id, floor_level)
	if fg == null:
		return false
	return fg.is_walkable(x, y)


## Purchase a tile (mark as owned, floor built).
func purchase_tile(x: int, y: int, plot_id: String = DEFAULT_PLOT, floor_level: String = GROUND_FLOOR) -> void:
	var tile := get_tile(x, y, plot_id, floor_level)
	if tile == null:
		return
	tile.owned = true
	tile.floor_built = true
	pathfinding_graph.mark_dirty()
	EventBus.tile_purchased.emit(floor_level.to_int() if floor_level.is_valid_int() else 0, x, y)


## Sell/demolish a tile.
func sell_tile(x: int, y: int, plot_id: String = DEFAULT_PLOT, floor_level: String = GROUND_FLOOR) -> void:
	var tile := get_tile(x, y, plot_id, floor_level)
	if tile == null:
		return
	tile.owned = false
	tile.floor_built = false
	tile.walls_built = false
	tile.zone_id = ""
	tile.element = GridTile.TileElement.NONE
	tile.typology = GridTile.TileTypology.TENANT
	pathfinding_graph.mark_dirty()
	EventBus.tile_sold.emit(floor_level.to_int() if floor_level.is_valid_int() else 0, x, y)


## Set a tile's zone assignment.
func set_tile_zone(x: int, y: int, zone_id: String, plot_id: String = DEFAULT_PLOT, floor_level: String = GROUND_FLOOR) -> void:
	var tile := get_tile(x, y, plot_id, floor_level)
	if tile == null:
		return
	tile.zone_id = zone_id


## Set a tile's element type.
func set_tile_element(x: int, y: int, element: GridTile.TileElement, plot_id: String = DEFAULT_PLOT, floor_level: String = GROUND_FLOOR) -> void:
	var tile := get_tile(x, y, plot_id, floor_level)
	if tile == null:
		return
	tile.element = element
	if element == GridTile.TileElement.CIRCULATION:
		pathfinding_graph.mark_dirty()


## Set a tile's typology.
func set_tile_typology(x: int, y: int, typology: GridTile.TileTypology, plot_id: String = DEFAULT_PLOT, floor_level: String = GROUND_FLOOR) -> void:
	var tile := get_tile(x, y, plot_id, floor_level)
	if tile == null:
		return
	tile.typology = typology


## Convert grid position to world-space position (center of tile).
func grid_to_world(x: int, y: int, floor_level: String = GROUND_FLOOR) -> Vector3:
	return Vector3(
		(x + 0.5) * TILE_SIZE,
		get_floor_world_y(floor_level),
		(y + 0.5) * TILE_SIZE
	)


## Convert world position to grid position.
func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(world_pos.x / TILE_SIZE),
		int(world_pos.z / TILE_SIZE)
	)


# ── Pathfinding ────────────────────────────────────────────────────────


## Rebuild the pathfinding graph from current tile state.
func rebuild_pathfinding() -> void:
	pathfinding_graph.rebuild(plots)


## Add a cross-floor circulation edge.
func add_circulation_edge(
	from_pos: Vector2i, from_floor: String, from_plot: String,
	to_pos: Vector2i, to_floor: String, to_plot: String
) -> void:
	pathfinding_graph.add_circulation_edge(from_plot, from_floor, from_pos, to_plot, to_floor, to_pos)
	EventBus.circulation_placed.emit("stairs", from_floor.to_int() if from_floor.is_valid_int() else 0, from_pos.x, from_pos.y)


## Remove a cross-floor circulation edge.
func remove_circulation_edge(
	from_pos: Vector2i, from_floor: String, from_plot: String,
	to_pos: Vector2i, to_floor: String, to_plot: String
) -> void:
	pathfinding_graph.remove_circulation_edge(from_plot, from_floor, from_pos, to_plot, to_floor, to_pos)


## Find a path between two positions.
func find_path(
	start_pos: Vector2i, start_floor: String, start_plot: String,
	end_pos: Vector2i, end_floor: String, end_plot: String
) -> Array[PathfindingGraph.PathNode]:
	return pathfinding_graph.find_path(start_plot, start_floor, start_pos, end_plot, end_floor, end_pos)


# ── Serialization ──────────────────────────────────────────────────────


## Serialize all grid state for save/load.
func serialize() -> Dictionary:
	var plot_data := {}
	for plot_id in plots:
		plot_data[plot_id] = plots[plot_id].serialize()
	return {"plots": plot_data}


## Deserialize from save data.
func deserialize(data: Dictionary) -> void:
	plots.clear()
	var plot_data: Dictionary = data.get("plots", {})
	for plot_id in plot_data:
		var plot := PlotData.new()
		plot.deserialize(plot_data[plot_id])
		plots[plot_id] = plot
	pathfinding_graph.mark_dirty()
