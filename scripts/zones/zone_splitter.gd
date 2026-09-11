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

## Every phase-one parcel core must have at least this width and depth.
const MINIMUM_CORE_DIMENSION: int = 2

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.DOWN,
]


## Split a zone into fronted rectangular cores, then grow reachable residual Tenant tiles without mutating input.
static func split(zone: ZoneData, access_context: FloorAccessContext) -> SplitResult:
	if zone == null or access_context == null or access_context.spatial_snapshot == null:
		return SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "MISSING_SPLIT_CONTEXT")
	var scope: Dictionary = access_context.spatial_snapshot.get_floor_scope()
	if zone.plot_id.is_empty() or zone.plot_id != String(scope.get("runtime_plot_id", "")):
		return SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "INVALID_FLOOR_SCOPE")
	var active_access_context := access_context

	var source_tiles := _normalized_tiles(zone.tiles)
	if source_tiles.is_empty():
		return SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "EMPTY_ZONE")
	for tile: Vector2i in source_tiles:
		if not active_access_context.is_zone_eligible(tile):
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
		var frontage_edges := _frontage_edges(component, zone_tile_set, zone, active_access_context)
		if frontage_edges.is_empty():
			residual_tiles.append_array(component)
			diagnostics.append("COMPONENT_NO_VALID_FRONTAGE")
			continue
		had_frontage = true

		var component_result := _split_component(component, frontage_edges, zone_tile_set, zone, active_access_context, minimum_area)
		parcels.append_array(component_result.get("parcels", []))
		residual_tiles.append_array(component_result.get("residual_tiles", []))
		for diagnostic: String in component_result.get("diagnostics", []):
			diagnostics.append(diagnostic)

	if parcels.is_empty():
		if not had_frontage:
			return SplitResult.failure(SplitResult.Status.NO_VALID_FRONTAGE, "NO_VALID_FRONTAGE")
		return SplitResult.failure(SplitResult.Status.INSUFFICIENT_RENTABLE_SPACE, "NO_MINIMUM_SIZED_FRONTED_PARCEL")

	# Phase two begins only after every component has allocated its rectangular cores.
	var residual_tile_set := _tile_set(residual_tiles)
	_grow_reachable_residuals(parcels, residual_tile_set, zone.parcel_layout_seed)
	residual_tiles = _sorted_set_positions(residual_tile_set)
	if not residual_tiles.is_empty():
		diagnostics.append("TENANT_RESIDUALS_PROPOSED_FOR_DECORATION")

	# Final parcels may be non-rectangular, so rebuild their full geometry and frontage metadata.
	for parcel: Parcel in parcels:
		var final_tiles := _normalized_tiles(parcel.tiles)
		parcel.set_geometry(final_tiles, _frontage_edges(final_tiles, zone_tile_set, zone, active_access_context))
	parcels.sort_custom(_compare_parcels)
	return SplitResult.success(parcels, residual_tiles, _normalized_diagnostics(diagnostics))


static func minimum_area_for_zone_type(zone_type: String) -> int:
	return int(MINIMUM_AREA_BY_ZONE_TYPE.get(zone_type, 0))


static func _split_component(
	component: Array[Vector2i],
	frontage_edges: Array[Dictionary],
	zone_tile_set: Dictionary,
	zone: ZoneData,
	access_context: FloorAccessContext,
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
			available, zone_tile_set, zone, access_context, minimum_area, desired_area
		)
		if candidate.is_empty():
			break

		var parcel := Parcel.new()
		parcel.set_geometry(candidate.get("tiles", []), candidate.get("frontage_edges", []))
		parcel.set_core_geometry(parcel.tiles)
		parcels.append(parcel)
		for tile: Vector2i in parcel.tiles:
			available.erase(tile)

	if parcels.is_empty() and not available.is_empty():
		diagnostics.append("COMPONENT_NO_VALID_RECTANGULAR_CORE")
	return {
		"parcels": parcels,
		"residual_tiles": _sorted_set_positions(available),
		"diagnostics": diagnostics,
	}


static func _select_candidate(
	available: Dictionary,
	zone_tile_set: Dictionary,
	zone: ZoneData,
	access_context: FloorAccessContext,
	minimum_area: int,
	desired_area: int
) -> Dictionary:
	var source_tiles := _sorted_set_positions(available)
	var source_edges := _frontage_edges(source_tiles, zone_tile_set, zone, access_context)
	var candidates: Array[Dictionary] = []
	for edge: Dictionary in source_edges:
		var seed: Vector2i = edge.get("tile", Vector2i.ZERO)
		if not available.has(seed):
			continue
		var bounds := _grow_inward_rectangle(edge, available, desired_area, minimum_area)
		if bounds.size == Vector2i.ZERO:
			continue
		var tiles := _tiles_in_bounds(bounds)
		var candidate_edges := _frontage_edges(tiles, zone_tile_set, zone, access_context)
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


## Select the best available rectangular core that preserves the supplied frontage seed.
## Final parcel growth is intentionally deferred until every core has been selected.
static func _grow_inward_rectangle(
	edge: Dictionary, available: Dictionary, desired_area: int, minimum_area: int
) -> Rect2i:
	var seed: Vector2i = edge.get("tile", Vector2i.ZERO)
	var outward: Vector2i = edge.get("direction", Vector2i.ZERO)
	if outward == Vector2i.ZERO or not available.has(seed):
		return Rect2i()

	var available_bounds := _bounds_for_tile_set(available)
	if available_bounds.size.x < MINIMUM_CORE_DIMENSION or available_bounds.size.y < MINIMUM_CORE_DIMENSION:
		return Rect2i()
	var dimensions: Array[Vector2i] = []
	for width: int in range(MINIMUM_CORE_DIMENSION, available_bounds.size.x + 1):
		for height: int in range(MINIMUM_CORE_DIMENSION, available_bounds.size.y + 1):
			if width * height >= minimum_area:
				dimensions.append(Vector2i(width, height))
	dimensions.sort_custom(func(first: Vector2i, second: Vector2i) -> bool:
		var first_difference := absi(first.x * first.y - desired_area)
		var second_difference := absi(second.x * second.y - desired_area)
		if first_difference != second_difference:
			return first_difference < second_difference
		var first_area := first.x * first.y
		var second_area := second.x * second.y
		if first_area != second_area:
			return first_area > second_area
		return first.y < second.y or (first.y == second.y and first.x < second.x)
	)

	var selected := Rect2i()
	for size: Vector2i in dimensions:
		for candidate_bounds: Rect2i in _bounds_from_frontage_seed(seed, outward, size):
			if not _bounds_are_available(candidate_bounds, available):
				continue
			if selected.size == Vector2i.ZERO or _is_better_core_bounds(candidate_bounds, selected, desired_area):
				selected = candidate_bounds
		var selected_difference := absi(_bounds_area(selected) - desired_area) if selected.size != Vector2i.ZERO else -1
		var current_difference := absi(size.x * size.y - desired_area)
		if selected_difference >= 0 and current_difference > selected_difference:
			break
	return selected


static func _bounds_for_tile_set(tile_set: Dictionary) -> Rect2i:
	var positions := _sorted_set_positions(tile_set)
	if positions.is_empty():
		return Rect2i()
	var min_x: int = positions[0].x
	var max_x: int = positions[0].x
	var min_y: int = positions[0].y
	var max_y: int = positions[0].y
	for position: Vector2i in positions:
		min_x = mini(min_x, position.x)
		max_x = maxi(max_x, position.x)
		min_y = mini(min_y, position.y)
		max_y = maxi(max_y, position.y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


static func _bounds_from_frontage_seed(seed: Vector2i, outward: Vector2i, size: Vector2i) -> Array[Rect2i]:
	var candidates: Array[Rect2i] = []
	if absi(outward.y) == 1:
		var y := seed.y if outward == Vector2i.UP else seed.y - size.y + 1
		for horizontal_offset: int in range(size.x):
			candidates.append(Rect2i(Vector2i(seed.x - horizontal_offset, y), size))
	else:
		var x := seed.x if outward == Vector2i.LEFT else seed.x - size.x + 1
		for vertical_offset: int in range(size.y):
			candidates.append(Rect2i(Vector2i(x, seed.y - vertical_offset), size))
	return candidates


static func _is_better_core_bounds(candidate: Rect2i, selected: Rect2i, desired_area: int) -> bool:
	var candidate_difference := absi(_bounds_area(candidate) - desired_area)
	var selected_difference := absi(_bounds_area(selected) - desired_area)
	if candidate_difference != selected_difference:
		return candidate_difference < selected_difference
	var candidate_area := _bounds_area(candidate)
	var selected_area := _bounds_area(selected)
	if candidate_area != selected_area:
		return candidate_area > selected_area
	if candidate.position != selected.position:
		return _compare_positions(candidate.position, selected.position)
	return candidate.size.y < selected.size.y or (
		candidate.size.y == selected.size.y and candidate.size.x < selected.size.x
	)


## Assign every residual Tenant tile reachable from a core using simultaneous breadth-first growth.
static func _grow_reachable_residuals(parcels: Array[Parcel], residual_tiles: Dictionary, layout_seed: int) -> void:
	if parcels.is_empty() or residual_tiles.is_empty():
		return
	parcels.sort_custom(_compare_parcels)
	var pending_claims: Dictionary = {}
	for parcel_index: int in range(parcels.size()):
		for core_tile: Vector2i in parcels[parcel_index].tiles:
			for direction: Vector2i in CARDINAL_DIRECTIONS:
				var neighbor := core_tile + direction
				if residual_tiles.has(neighbor):
					_append_growth_claim(pending_claims, neighbor, parcel_index)

	while not pending_claims.is_empty():
		var current_tiles := _sorted_set_positions(pending_claims)
		var winners: Dictionary = {}
		for tile_position: Vector2i in current_tiles:
			var candidate_owners: Array[int] = []
			for owner: int in pending_claims.get(tile_position, []):
				candidate_owners.append(owner)
			winners[tile_position] = _select_growth_owner(candidate_owners, tile_position, layout_seed)

		for tile_position: Vector2i in current_tiles:
			if not residual_tiles.has(tile_position):
				continue
			var winning_owner: int = winners.get(tile_position, -1)
			if winning_owner < 0:
				continue
			residual_tiles.erase(tile_position)
			parcels[winning_owner].tiles.append(tile_position)

		var next_claims: Dictionary = {}
		for tile_position: Vector2i in current_tiles:
			var winning_owner: int = winners.get(tile_position, -1)
			if winning_owner < 0:
				continue
			for direction: Vector2i in CARDINAL_DIRECTIONS:
				var neighbor := tile_position + direction
				if residual_tiles.has(neighbor):
					_append_growth_claim(next_claims, neighbor, winning_owner)
		pending_claims = next_claims

	for parcel: Parcel in parcels:
		parcel.tiles = _normalized_tiles(parcel.tiles)


static func _append_growth_claim(claims: Dictionary, tile_position: Vector2i, owner_index: int) -> void:
	var owners: Array[int] = []
	for existing_owner: int in claims.get(tile_position, []):
		owners.append(existing_owner)
	if not owners.has(owner_index):
		owners.append(owner_index)
	claims[tile_position] = owners


static func _select_growth_owner(candidate_owners: Array[int], tile_position: Vector2i, layout_seed: int) -> int:
	if candidate_owners.is_empty():
		return -1
	var ordered_owners := candidate_owners.duplicate()
	ordered_owners.sort()
	if ordered_owners.size() == 1:
		return ordered_owners[0]
	var hash_value: int = ("%d:%d:%d" % [layout_seed, tile_position.x, tile_position.y]).hash()
	if hash_value < 0:
		hash_value = -hash_value
	return ordered_owners[hash_value % ordered_owners.size()]


static func _frontage_edges(
	tiles: Array[Vector2i],
	zone_tile_set: Dictionary,
	zone: ZoneData,
	access_context: FloorAccessContext
) -> Array[Dictionary]:
	var edges: Array[Dictionary] = []
	for tile: Vector2i in _normalized_tiles(tiles):
		for direction: Vector2i in CARDINAL_DIRECTIONS:
			var access: Vector2i = tile + direction
			var access_kind := _access_kind(access, zone_tile_set, zone, access_context)
			if not access_kind.is_empty():
				var edge := {
					"tile": tile,
					"direction": direction,
					"access": access,
					"access_kind": access_kind,
				}
				if access_kind == "internal_transit":
					edge["transit_area_key"] = access_context.transit_area_key_for(
						access, zone, zone_tile_set
					)
				elif access_kind == "public_band":
					var public_edge: Dictionary = access_context.public_band_edge_for(access, zone, zone_tile_set)
					if public_edge.is_empty():
						continue
					edge["public_band_access_edge_id"] = String(public_edge["access_edge_id"])
				edges.append(edge)
	edges.sort_custom(_compare_frontage_edges)
	return edges


static func _access_kind(
	access: Vector2i,
	zone_tile_set: Dictionary,
	zone: ZoneData,
	access_context: FloorAccessContext
) -> String:
	return access_context.access_kind_for(access, zone, zone_tile_set)


static func _tenant_tiles(zone: ZoneData, source_tiles: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tile: Vector2i in source_tiles:
		if zone.typologies.get(tile, ZoneData.TileTypology.TENANT) == ZoneData.TileTypology.TENANT:
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
	var a_anchor := a.core_bounds.position if not a.core_tiles.is_empty() else a.bounds.position
	var b_anchor := b.core_bounds.position if not b.core_tiles.is_empty() else b.bounds.position
	return _compare_positions(a_anchor, b_anchor)


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
