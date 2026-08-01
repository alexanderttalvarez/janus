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

	return {
		"plot_id": plot_id,
		"floors": floor_data,
		"boundary": {"x": boundary.position.x, "y": boundary.position.y, "w": boundary.size.x, "h": boundary.size.y},
		"pedestrian_boundary": {"x": pedestrian_boundary.position.x, "y": pedestrian_boundary.position.y, "w": pedestrian_boundary.size.x, "h": pedestrian_boundary.size.y},
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
