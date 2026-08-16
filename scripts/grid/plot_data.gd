## PlotData — Represents a single building plot with its floors and boundaries.
## MVP has one plot (plot_0). Post-MVP adds multiple interconnected plots.
class_name PlotData
extends RefCounted


## Unique identifier for this plot (e.g., "plot_0").
var plot_id: String = ""

## Floors owned by this plot, keyed by floor level string (e.g., "G", "F1", "B1").
var floors: Dictionary = {}  # Dictionary[String, FloorGrid]

## Total plot boundary in grid coordinates (Rect2i).
var boundary: Rect2i = Rect2i()

## Pedestrian-only boundary (cross-plot connections, road-level).
var pedestrian_boundary: Rect2i = Rect2i()

## Cross-plot connections (empty in MVP).
var connections: Array = []  # Array[PlotConnection]

## Four derived visitor spawn points, one at each pedestrian-ring corner.
var spawn_points: Array[Dictionary] = []


## Derive stable visitor spawn points from the plot boundary.
func initialize_spawn_points(pedestrian_margin: float = 2.0) -> void:
	spawn_points.clear()
	if boundary.size == Vector2i.ZERO:
		return
	var half_margin := pedestrian_margin * 0.5
	var min_x := float(boundary.position.x) - half_margin
	var min_z := float(boundary.position.y) - half_margin
	var max_x := float(boundary.position.x + boundary.size.x) + half_margin
	var max_z := float(boundary.position.y + boundary.size.y) + half_margin
	spawn_points = [
		{"id": "%s_corner_nw" % plot_id, "position": Vector3(min_x, 0.0, min_z), "direction": Vector3(1.0, 0.0, 1.0)},
		{"id": "%s_corner_ne" % plot_id, "position": Vector3(max_x, 0.0, min_z), "direction": Vector3(-1.0, 0.0, 1.0)},
		{"id": "%s_corner_se" % plot_id, "position": Vector3(max_x, 0.0, max_z), "direction": Vector3(-1.0, 0.0, -1.0)},
		{"id": "%s_corner_sw" % plot_id, "position": Vector3(min_x, 0.0, max_z), "direction": Vector3(1.0, 0.0, -1.0)},
	]


## Return a spawn point by stable ID, or null when not found.
func get_spawn_point(spawn_point_id: String) -> Dictionary:
	for point: Dictionary in spawn_points:
		if point.get("id", "") == spawn_point_id:
			return point
	return {}


## Add a floor to this plot.
func add_floor(level: String, floor_grid: FloorGrid) -> void:
	floors[level] = floor_grid


## Get a floor by level. Returns null if not found.
func get_floor(level: String) -> FloorGrid:
	return floors.get(level, null)


## Remove a floor by level.
func remove_floor(level: String) -> void:
	floors.erase(level)


## Check if this plot has a floor at the given level.
func has_floor(level: String) -> bool:
	return floors.has(level)


## Get all floor levels in this plot.
func get_floor_levels() -> Array[String]:
	var levels: Array[String] = []
	levels.assign(floors.keys())
	return levels


## Serialize to dictionary for save/load.
func serialize() -> Dictionary:
	var floor_data := {}
	for level in floors:
		floor_data[level] = floors[level].serialize()
	var spawn_data: Array[Dictionary] = []
	for point: Dictionary in spawn_points:
		var position: Vector3 = point.get("position", Vector3.ZERO)
		var direction: Vector3 = point.get("direction", Vector3.ZERO)
		spawn_data.append({
			"id": point.get("id", ""),
			"position": {"x": position.x, "y": position.y, "z": position.z},
			"direction": {"x": direction.x, "y": direction.y, "z": direction.z},
		})

	return {
		"plot_id": plot_id,
		"floors": floor_data,
		"boundary": {"x": boundary.position.x, "y": boundary.position.y, "w": boundary.size.x, "h": boundary.size.y},
		"pedestrian_boundary": {"x": pedestrian_boundary.position.x, "y": pedestrian_boundary.position.y, "w": pedestrian_boundary.size.x, "h": pedestrian_boundary.size.y},
		"spawn_points": spawn_data,
	}


## Deserialize from dictionary (save/load).
func deserialize(data: Dictionary) -> void:
	plot_id = data.get("plot_id", "")
	floors.clear()

	var floor_data: Dictionary = data.get("floors", {})
	for level in floor_data:
		var fg := FloorGrid.new()
		fg.deserialize(floor_data[level])
		floors[level] = fg

	var bd: Dictionary = data.get("boundary", {})
	boundary = Rect2i(bd.get("x", 0), bd.get("y", 0), bd.get("w", 0), bd.get("h", 0))

	var pd: Dictionary = data.get("pedestrian_boundary", {})
	pedestrian_boundary = Rect2i(pd.get("x", 0), pd.get("y", 0), pd.get("w", 0), pd.get("h", 0))
	spawn_points.clear()
	for point_data: Dictionary in data.get("spawn_points", []):
		var position_data: Dictionary = point_data.get("position", {})
		var direction_data: Dictionary = point_data.get("direction", {})
		spawn_points.append({
			"id": point_data.get("id", ""),
			"position": Vector3(position_data.get("x", 0.0), position_data.get("y", 0.0), position_data.get("z", 0.0)),
			"direction": Vector3(direction_data.get("x", 0.0), direction_data.get("y", 0.0), direction_data.get("z", 0.0)),
		})
	if spawn_points.is_empty():
		initialize_spawn_points()
