## FloorGrid — 2D array of GridTile representing one floor layer.
## Each floor has fixed dimensions and a footprint mask defining valid tiles.
class_name FloorGrid
extends RefCounted


## Width in tiles (X dimension).
var width: int = 0

## Depth in tiles (Y dimension).
var height: int = 0

## 2D array of GridTile: tiles[0..width-1][0..height-1].
var tiles: Array = []  # Array[Array[GridTile]]

## Footprint mask: footprint[y][x] = true if tile exists at (x, y).
var footprint: Array = []  # Array[Array[bool]]


## Initialize the floor with given dimensions and an optional footprint.
## If no footprint is provided, creates a full rectangular footprint.
func initialize(p_width: int, p_height: int, p_footprint: Array = []) -> void:
	width = p_width
	height = p_height

	# Build tile array.
	tiles.clear()
	for x in range(width):
		var column: Array[GridTile] = []
		for y in range(height):
			column.append(GridTile.new())
		tiles.append(column)

	# Build footprint mask.
	if p_footprint.is_empty():
		# Full rectangular floor.
		footprint.clear()
		for y in range(height):
			var row: Array[bool] = []
			for x in range(width):
				row.append(true)
			footprint.append(row)
	else:
		footprint = p_footprint


## Check if a tile position is within bounds and valid per the footprint.
func is_valid_tile(x: int, y: int) -> bool:
	if x < 0 or x >= width or y < 0 or y >= height:
		return false
	if not footprint.is_empty() and y < footprint.size() and x < footprint[y].size():
		return footprint[y][x]
	return true


## Get the GridTile at (x, y). Returns null if out of bounds or invalid.
func get_tile(x: int, y: int) -> GridTile:
	if not is_valid_tile(x, y):
		return null
	return tiles[x][y]


## Check if a tile is walkable (valid, owned, floor built, and not blocked).
func is_walkable(x: int, y: int) -> bool:
	var tile := get_tile(x, y)
	if tile == null:
		return false
	return tile.owned and tile.floor_built


## Get all valid, walkable tile positions on this floor.
func get_walkable_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for x in range(width):
		for y in range(height):
			if is_walkable(x, y):
				positions.append(Vector2i(x, y))
	return positions


## Get all tiles belonging to a zone.
func get_zone_tiles(p_zone_id: String) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for x in range(width):
		for y in range(height):
	var tile: GridTile = get_tile(x, y)
			if tile != null and tile.zone_id == p_zone_id:
				positions.append(Vector2i(x, y))
	return positions


## Get the 4-directional neighbors of a tile position (up, down, left, right).
func get_neighbors(x: int, y: int) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for offset: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var nx: int = x + offset.x
		var ny: int = y + offset.y
		if is_valid_tile(nx, ny):
			neighbors.append(Vector2i(nx, ny))
	return neighbors


## Get only walkable neighbors (valid + owned + floor_built).
func get_walkable_neighbors(x: int, y: int) -> Array[Vector2i]:
	var neighbors := get_neighbors(x, y)
	var walkable: Array[Vector2i] = []
	for n in neighbors:
		if is_walkable(n.x, n.y):
			walkable.append(n)
	return walkable


## Serialize this floor to a dictionary for save/load.
func serialize() -> Dictionary:
	var data := {
		"width": width,
		"height": height,
		"tiles": [],
		"footprint": footprint,
	}

	for x in range(width):
		var column := []
		for y in range(height):
			var tile: GridTile = tiles[x][y]
			column.append({
				"owned": tile.owned,
				"floor_built": tile.floor_built,
				"walls_built": tile.walls_built,
				"zone_id": tile.zone_id,
				"element": tile.element,
				"typology": tile.typology,
				"condition": tile.condition,
			})
		data["tiles"].append(column)

	return data


## Deserialize from a dictionary (save/load).
func deserialize(data: Dictionary) -> void:
	width = data["width"]
	height = data["height"]
	footprint = data.get("footprint", [])

	tiles.clear()
	for x in range(width):
		var column: Array[GridTile] = []
		var column_data = data["tiles"][x] if x < data["tiles"].size() else []
		for y in range(height):
			var tile := GridTile.new()
			if y < column_data.size():
				tile.owned = column_data[y]["owned"]
				tile.floor_built = column_data[y]["floor_built"]
				tile.walls_built = column_data[y]["walls_built"]
				tile.zone_id = column_data[y]["zone_id"]
				tile.element = column_data[y]["element"]
				tile.typology = column_data[y]["typology"]
				tile.condition = column_data[y].get("condition", 100)
			column.append(tile)
		tiles.append(column)
