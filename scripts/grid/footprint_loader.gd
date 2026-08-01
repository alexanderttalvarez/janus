## FootprintLoader — Static utility for parsing text-based footprint mask files.
##
## File format:
##   Each line is a row of the grid (Y axis). Each character is one tile.
##   '.' = valid tile, 'x' = invalid, 'o' = pre-occupied, '#' = comment (ignored).
class_name FootprintLoader
extends RefCounted


## Parse a footprint text file into an Array[Array[bool]].
## Returns true at positions where a tile exists ('.' or 'o').
## Returns an array of Vector2i for pre-occupied positions.
static func parse(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("FootprintLoader: Cannot open '%s'." % path)
		return {"footprint": [], "pre_occupied": []}

	var footprint: Array = []  # Array[Array[bool]]
	var pre_occupied: Array[Vector2i] = []

	var y := 0
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			# Skip comment and blank lines without advancing Y.
			continue

		var row: Array[bool] = []
		for x in range(line.length()):
			var ch := line[x]
			match ch:
				".":
					row.append(true)
				"o":
					row.append(true)
					pre_occupied.append(Vector2i(x, y))
				"x":
					row.append(false)
				_:
					# Unknown char: treat as invalid.
					row.append(false)

		if not row.is_empty():
			footprint.append(row)
			y += 1

	file.close()
	return {"footprint": footprint, "pre_occupied": pre_occupied}


## Load only the footprint mask (ignores pre-occupied data).
static func load_footprint(path: String) -> Array:
	var result := parse(path)
	return result["footprint"]


## Create a full rectangular footprint of given dimensions.
static func create_full(width: int, height: int) -> Array:
	var footprint: Array = []
	for y in range(height):
		var row: Array[bool] = []
		for x in range(width):
			row.append(true)
		footprint.append(row)
	return footprint
