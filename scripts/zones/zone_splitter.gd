## ZoneSplitter — Pure, deterministic geometry pass for one zone.
## It reads immutable zone/grid snapshots and returns SplitResult without mutations.
class_name ZoneSplitter
extends RefCounted


const MINIMUM_AREA_BY_ZONE_TYPE: Dictionary = {
	"Retail": 6,
	"Food & Beverage": 8,
	"Entertainment": 12,
	"Services": 5,
	"Anchor": 30,
}

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.DOWN,
]


## Split a zone into valid, fronted Tenant rectangles without mutating input.
static func split(zone: ZoneData, floor_grid: FloorGrid, plot: PlotData) -> SplitResult:
	if zone == null or floor_grid == null or plot == null:
		return SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "MISSING_SPLIT_CONTEXT")
	if zone.plot_id.is_empty() or zone.plot_id != plot.plot_id:
		return SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "INVALID_PLOT_CONTEXT")

	var source_tiles := _normalized_tiles(zone.tiles)
	if source_tiles.is_empty():
		return SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "EMPTY_ZONE")
	for tile: Vector2i in source_tiles:
		if not floor_grid.is_valid_tile(tile.x, tile.y):
			return SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "INVALID_ZONE_TILE")
	if not _is_connected(source_tiles):
		return SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "DISCONNECTED_ZONE")

	var minimum_area := minimum_area_for_zone_type(zone.type)
	if minimum_area <= 0:
		return SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "UNKNOWN_ZONE_TYPE")

	var tenant_tiles := _tenant_tiles(zone, source_tiles)
	if tenant_tiles.is_empty():
		return SplitResult.failure(SplitResult.Status.INSUFFICIENT_RENTABLE_SPACE, "NO_TENANT_TILES")

	var zone_tile_set := _tile_set(source_tiles)
	var components := _tenant_components(tenant_tiles)
	var parcels: Array[Parcel] = []
	var residual_tiles: Array[Vector2i] = []
	var diagnostics: Array[String] = []
	var had_frontage := false

	for component: Array[Vector2i] in components:
		var frontage_edges := _frontage_edges(component, zone_tile_set, zone, floor_grid, plot)
		if frontage_edges.is_empty():
			residual_tiles.append_array(component)
			diagnostics.append("COMPONENT_NO_VALID_FRONTAGE")
			continue
		had_frontage = true

		var component_result := _split_component(component, frontage_edges, zone_tile_set, zone, floor_grid, plot, minimum_area)
		parcels.append_array(component_result.get("parcels", []))
		residual_tiles.append_array(component_result.get("residual_tiles", []))
		for diagnostic: String in component_result.get("diagnostics", []):
			diagnostics.append(diagnostic)

	if parcels.is_empty():
		if not had_frontage:
			return SplitResult.failure(SplitResult.Status.NO_VALID_FRONTAGE, "NO_VALID_FRONTAGE")
		return SplitResult.failure(SplitResult.Status.INSUFFICIENT_RENTABLE_SPACE, "NO_MINIMUM_SIZED_FRONTED_PARCEL")

	parcels.sort_custom(_compare_parcels)
	residual_tiles = _normalized_tiles(residual_tiles)
	return SplitResult.success(parcels, residual_tiles, _normalized_diagnostics(diagnostics))


static func minimum_area_for_zone_type(zone_type: String) -> int:
	return int(MINIMUM_AREA_BY_ZONE_TYPE.get(zone_type, 0))


static func _split_component(
	component: Array[Vector2i],
	frontage_edges: Array[Dictionary],
	zone_tile_set: Dictionary,
	zone: ZoneData,
	floor_grid: FloorGrid,
	plot: PlotData,
	minimum_area: int
) -> Dictionary:
	var available := _tile_set(component)
	var unique_frontage_tiles: Dictionary = {}
	for edge: Dictionary in frontage_edges:
		unique_frontage_tiles[edge.get("tile", Vector2i.ZERO)] = true
	var target_count := mini(component.size() / minimum_area, unique_frontage_tiles.size())
	if target_count <= 0:
		return {
			"parcels": [],
			"residual_tiles": component,
			"diagnostics": ["COMPONENT_BELOW_MINIMUM_AREA"],
		}

	var parcels: Array[Parcel] = []
	var diagnostics: Array[String] = []
	for parcel_index: int in range(target_count):
		var remaining_slots: int = target_count - parcel_index
		var desired_area: int = maxi(minimum_area, ceili(float(available.size()) / float(remaining_slots)))
		var candidate := _select_candidate(
			available, zone_tile_set, zone, floor_grid, plot, minimum_area, desired_area
		)
		if candidate.is_empty():
			break

		var parcel := Parcel.new()
		parcel.set_geometry(candidate.get("tiles", []), candidate.get("frontage_edges", []))
		parcels.append(parcel)
		for tile: Vector2i in parcel.tiles:
			available.erase(tile)

	if not available.is_empty():
		diagnostics.append("TENANT_RESIDUALS_PROPOSED_FOR_DECORATION")
	return {
		"parcels": parcels,
		"residual_tiles": _sorted_set_positions(available),
		"diagnostics": diagnostics,
	}


static func _select_candidate(
	available: Dictionary,
	zone_tile_set: Dictionary,
	zone: ZoneData,
	floor_grid: FloorGrid,
	plot: PlotData,
	minimum_area: int,
	desired_area: int
) -> Dictionary:
	var source_tiles := _sorted_set_positions(available)
	var source_edges := _frontage_edges(source_tiles, zone_tile_set, zone, floor_grid, plot)
	var candidates: Array[Dictionary] = []
	for edge: Dictionary in source_edges:
		var seed: Vector2i = edge.get("tile", Vector2i.ZERO)
		if not available.has(seed):
			continue
		var bounds := _grow_inward_rectangle(edge, available, desired_area, minimum_area)
		if bounds.size == Vector2i.ZERO:
			continue
		var tiles := _tiles_in_bounds(bounds)
		var candidate_edges := _frontage_edges(tiles, zone_tile_set, zone, floor_grid, plot)
		if candidate_edges.is_empty():
			continue
		candidates.append({
			"tiles": tiles,
			"frontage_edges": candidate_edges,
			"area_difference": absi(tiles.size() - desired_area),
			"area": tiles.size(),
			"bounds": bounds,
			"seed_direction": edge.get("direction", Vector2i.ZERO),
		})

	if candidates.is_empty():
		return {}
	candidates.sort_custom(_compare_candidates)
	return candidates[0]


## Grow from a frontage seed inward. It never expands toward the access edge,
## so the seed remains a valid tenant-door candidate.
static func _grow_inward_rectangle(
	edge: Dictionary, available: Dictionary, desired_area: int, minimum_area: int
) -> Rect2i:
	var seed: Vector2i = edge.get("tile", Vector2i.ZERO)
	var outward: Vector2i = edge.get("direction", Vector2i.ZERO)
	if outward == Vector2i.ZERO or not available.has(seed):
		return Rect2i()

	var bounds := Rect2i(seed, Vector2i.ONE)
	var inward := -outward
	var side_a := Vector2i.LEFT if absi(outward.y) == 1 else Vector2i.UP
	var side_b := Vector2i.RIGHT if absi(outward.y) == 1 else Vector2i.DOWN

	while _bounds_area(bounds) < desired_area:
		var inward_bounds := _expanded_bounds(bounds, inward)
		if _bounds_are_available(inward_bounds, available):
			bounds = inward_bounds
			continue
		if _bounds_area(bounds) >= minimum_area:
			break
		var side_a_bounds := _expanded_bounds(bounds, side_a)
		if _bounds_are_available(side_a_bounds, available):
			bounds = side_a_bounds
			continue
		var side_b_bounds := _expanded_bounds(bounds, side_b)
		if _bounds_are_available(side_b_bounds, available):
			bounds = side_b_bounds
			continue
		break

	if _bounds_area(bounds) < minimum_area:
		return Rect2i()
	return bounds


static func _frontage_edges(
	tiles: Array[Vector2i], zone_tile_set: Dictionary, zone: ZoneData, floor_grid: FloorGrid, plot: PlotData
) -> Array[Dictionary]:
	var edges: Array[Dictionary] = []
	for tile: Vector2i in _normalized_tiles(tiles):
		for direction: Vector2i in CARDINAL_DIRECTIONS:
			var access: Vector2i = tile + direction
			var access_kind := _access_kind(access, zone_tile_set, zone, floor_grid, plot)
			if not access_kind.is_empty():
				edges.append({
					"tile": tile,
					"direction": direction,
					"access": access,
					"access_kind": access_kind,
				})
	edges.sort_custom(_compare_frontage_edges)
	return edges


static func _access_kind(
	access: Vector2i, zone_tile_set: Dictionary, zone: ZoneData, floor_grid: FloorGrid, plot: PlotData
) -> String:
	if zone_tile_set.has(access):
		if zone.typologies.get(access, GridTile.TileTypology.TENANT) == GridTile.TileTypology.TRANSIT:
			return "internal_transit"
		return ""

	if floor_grid.is_valid_tile(access.x, access.y):
		var tile := floor_grid.get_tile(access.x, access.y)
		if tile != null and tile.owned and tile.floor_built and tile.element == GridTile.TileElement.CIRCULATION:
			return "external_circulation"
		return ""

	if plot.boundary.has_point(access):
		return ""
	if plot.pedestrian_boundary.has_point(access):
		return "virtual_exterior"
	return ""


static func _tenant_tiles(zone: ZoneData, source_tiles: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tile: Vector2i in source_tiles:
		if zone.typologies.get(tile, GridTile.TileTypology.TENANT) == GridTile.TileTypology.TENANT:
			result.append(tile)
	return result


static func _tenant_components(tiles: Array[Vector2i]) -> Array:
	var remaining := _tile_set(tiles)
	var components: Array = []
	while not remaining.is_empty():
		var starts := _sorted_set_positions(remaining)
		var start: Vector2i = starts[0]
		var stack: Array[Vector2i] = [start]
		var component: Array[Vector2i] = []
		remaining.erase(start)
		while not stack.is_empty():
			var current: Vector2i = stack.pop_back()
			component.append(current)
			for direction: Vector2i in CARDINAL_DIRECTIONS:
				var neighbor := current + direction
				if remaining.has(neighbor):
					remaining.erase(neighbor)
					stack.append(neighbor)
		component.sort_custom(_compare_positions)
		components.append(component)
	components.sort_custom(_compare_components)
	return components


static func _is_connected(tiles: Array[Vector2i]) -> bool:
	if tiles.is_empty():
		return false
	var remaining := _tile_set(tiles)
	var stack: Array[Vector2i] = [tiles[0]]
	var visited: Dictionary = {}
	while not stack.is_empty():
		var current: Vector2i = stack.pop_back()
		if visited.has(current):
			continue
		visited[current] = true
		for direction: Vector2i in CARDINAL_DIRECTIONS:
			var neighbor := current + direction
			if remaining.has(neighbor) and not visited.has(neighbor):
				stack.append(neighbor)
	return visited.size() == remaining.size()


static func _tile_set(tiles: Array[Vector2i]) -> Dictionary:
	var result: Dictionary = {}
	for tile: Vector2i in tiles:
		result[tile] = true
	return result


static func _normalized_tiles(tiles: Array[Vector2i]) -> Array[Vector2i]:
	var normalized := _sorted_set_positions(_tile_set(tiles))
	return normalized


static func _sorted_set_positions(tile_set: Dictionary) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for tile: Vector2i in tile_set:
		positions.append(tile)
	positions.sort_custom(_compare_positions)
	return positions


static func _expanded_bounds(bounds: Rect2i, direction: Vector2i) -> Rect2i:
	var position := bounds.position
	var size := bounds.size
	if direction == Vector2i.UP:
		position.y -= 1
		size.y += 1
	elif direction == Vector2i.DOWN:
		size.y += 1
	elif direction == Vector2i.LEFT:
		position.x -= 1
		size.x += 1
	elif direction == Vector2i.RIGHT:
		size.x += 1
	return Rect2i(position, size)


static func _bounds_are_available(bounds: Rect2i, available: Dictionary) -> bool:
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return false
	for x: int in range(bounds.position.x, bounds.end.x):
		for y: int in range(bounds.position.y, bounds.end.y):
			if not available.has(Vector2i(x, y)):
				return false
	return true


static func _bounds_area(bounds: Rect2i) -> int:
	return bounds.size.x * bounds.size.y


static func _tiles_in_bounds(bounds: Rect2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			tiles.append(Vector2i(x, y))
	return tiles


static func _compare_positions(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


static func _compare_components(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	return _compare_positions(a[0], b[0])


static func _compare_frontage_edges(a: Dictionary, b: Dictionary) -> bool:
	var a_tile: Vector2i = a.get("tile", Vector2i.ZERO)
	var b_tile: Vector2i = b.get("tile", Vector2i.ZERO)
	if a_tile != b_tile:
		return _compare_positions(a_tile, b_tile)
	return _direction_rank(a.get("direction", Vector2i.ZERO)) < _direction_rank(b.get("direction", Vector2i.ZERO))


static func _compare_candidates(a: Dictionary, b: Dictionary) -> bool:
	var a_difference: int = a.get("area_difference", 0)
	var b_difference: int = b.get("area_difference", 0)
	if a_difference != b_difference:
		return a_difference < b_difference
	var a_area: int = a.get("area", 0)
	var b_area: int = b.get("area", 0)
	if a_area != b_area:
		return a_area > b_area
	var a_bounds: Rect2i = a.get("bounds", Rect2i())
	var b_bounds: Rect2i = b.get("bounds", Rect2i())
	if a_bounds.position != b_bounds.position:
		return _compare_positions(a_bounds.position, b_bounds.position)
	if a_bounds.size != b_bounds.size:
		return a_bounds.size.y < b_bounds.size.y or (
			a_bounds.size.y == b_bounds.size.y and a_bounds.size.x < b_bounds.size.x
		)
	return _direction_rank(a.get("seed_direction", Vector2i.ZERO)) < _direction_rank(
		b.get("seed_direction", Vector2i.ZERO)
	)


static func _compare_parcels(a: Parcel, b: Parcel) -> bool:
	return _compare_positions(a.bounds.position, b.bounds.position)


static func _direction_rank(direction: Vector2i) -> int:
	for index: int in range(CARDINAL_DIRECTIONS.size()):
		if CARDINAL_DIRECTIONS[index] == direction:
			return index
	return CARDINAL_DIRECTIONS.size()


static func _normalized_diagnostics(diagnostics: Array[String]) -> Array[String]:
	var unique: Dictionary = {}
	for diagnostic: String in diagnostics:
		unique[diagnostic] = true
	var result: Array[String] = []
	for diagnostic: String in unique:
		result.append(diagnostic)
	result.sort()
	return result
