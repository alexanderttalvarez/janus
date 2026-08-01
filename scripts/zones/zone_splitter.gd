## ZoneSplitter — Static class that splits a zone into parcels.
## Pure GDScript, no Godot dependencies beyond basic types.
## 5-phase algorithm: frontage → reserve → grow → validate → repair.
##
## Each parcel represents a contiguous group of tiles that will be
## assigned to a single business/tenant.
class_name ZoneSplitter
extends RefCounted


const MIN_PARCEL_TILES: int = 2


## Split a zone into an array of Parcel objects.
static func split(zone: ZoneData, grid_manager: GridManager) -> Array[Parcel]:
	if zone.tiles.is_empty():
		return []

	var fg := grid_manager.get_floor_grid(GridManager.DEFAULT_PLOT, zone.floor)
	if fg == null:
		return []

	# Phase 1: Detect frontage tiles (bordering walkable areas).
	var frontage: Array[Vector2i] = _detect_frontage(zone, fg)
	if frontage.is_empty():
		# No frontage — all tiles are interior. Create a single parcel.
		return [_create_single_parcel(zone)]

	# Phase 2: Reserve frontage segments and distribute to target store count.
	var target_count: int = _calculate_target_count(zone.tiles.size())
	var frontage_segments: Array[Array] = _group_frontage_segments(frontage, zone.tiles)
	var seeds: Array[Array] = _distribute_frontage(frontage_segments, target_count)

	# Phase 3: Grow each seed into a rectangle.
	var parcels: Array[Parcel] = _grow_parcels(seeds, zone, fg)

	# Phase 4: Validate and repair.
	parcels = _validate_and_repair(parcels, zone, fg)

	# Phase 5: Business assignment is handled by ZoneBusinessAssigner.
	return parcels


# ── Phase 1: Frontage Detection ────────────────────────────────────────

## Find zone tiles that border walkable areas (corridors or unowned tiles).
static func _detect_frontage(zone: ZoneData, fg: FloorGrid) -> Array[Vector2i]:
	var frontage: Array[Vector2i] = []
	for tile_pos: Vector2i in zone.tiles:
		for offset: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var nx: int = tile_pos.x + offset.x
			var ny: int = tile_pos.y + offset.y
			if not fg.is_valid_tile(nx, ny):
				continue
			var neighbor: GridTile = fg.get_tile(nx, ny)
			# A tile is frontage if it borders:
			# - An unowned tile (outside the building)
			# - A corridor/circulation tile
			if neighbor != null and (not neighbor.owned or neighbor.element == GridTile.TileElement.CIRCULATION):
				if not frontage.has(tile_pos):
					frontage.append(tile_pos)
				break
	return frontage


# ── Phase 2: Frontage Reservation ──────────────────────────────────────

## Calculate target number of stores based on total tile count.
static func _calculate_target_count(total_tiles: int) -> int:
	if total_tiles <= 4:
		return 1
	if total_tiles <= 9:
		return 2
	if total_tiles <= 16:
		return 3
	return 4


## Group contiguous frontage tiles into segments.
static func _group_frontage_segments(frontage: Array[Vector2i], _all_tiles: Array[Vector2i]) -> Array[Array]:
	var visited: Dictionary = {}
	var segments: Array[Array] = []

	for tile_pos: Vector2i in frontage:
		if visited.has(tile_pos):
			continue
		var segment: Array[Vector2i] = []
		_flood_fill_frontage(tile_pos, frontage, visited, segment)
		if not segment.is_empty():
			segments.append(segment)

	return segments


## Simple flood-fill for frontage grouping.
static func _flood_fill_frontage(start: Vector2i, frontage: Array[Vector2i], visited: Dictionary, segment: Array) -> void:
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var pos: Vector2i = stack.pop_back()
		if visited.has(pos):
			continue
		visited[pos] = true
		segment.append(pos)
		for offset: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var nx: int = pos.x + offset.x
			var ny: int = pos.y + offset.y
			var neighbor := Vector2i(nx, ny)
			if frontage.has(neighbor) and not visited.has(neighbor):
				stack.append(neighbor)


## Distribute frontage segments among target store count.
static func _distribute_frontage(segments: Array[Array], target_count: int) -> Array[Array]:
	var seeds: Array[Array] = []
	# Assign each segment as a seed, up to target_count.
	for i in range(min(segments.size(), target_count)):
		seeds.append(segments[i])
	# If we have fewer segments than target, we'll handle it in growth.
	return seeds


# ── Phase 3: Grow Parcels ──────────────────────────────────────────────

## Grow each seed into a full parcel by expanding inward.
static func _grow_parcels(seeds: Array[Array], zone: ZoneData, fg: FloorGrid) -> Array[Parcel]:
	var parcel_tiles: Array[Dictionary] = []  # [{tiles: [], center: pos}]
	var used: Dictionary = {}  # Track which tiles are assigned to parcels.

	# Initialize parcels from seeds.
	for seed: Array in seeds:
		var tiles_arr: Array[Vector2i] = seed.duplicate()
		for t: Vector2i in seed:
			used[t] = true
		var center: Vector2i = _calculate_center(seed)
		parcel_tiles.append({"tiles": tiles_arr, "center": center})

	if parcel_tiles.is_empty():
		return [_create_single_parcel(zone)]

	# Assign remaining unassigned zone tiles to nearest parcel.
	var target_per_parcel: int = ceili(float(zone.tiles.size()) / float(parcel_tiles.size()))
	for tile_pos: Vector2i in zone.tiles:
		if used.has(tile_pos):
			continue
		var best_idx: int = -1
		var best_dist: float = INF
		for i in range(parcel_tiles.size()):
			var center: Vector2i = parcel_tiles[i]["center"]
			var dist := tile_pos.distance_squared_to(Vector2(center.x, center.y))
			if dist < best_dist:
				best_dist = dist
				best_idx = i
		if best_idx >= 0:
			parcel_tiles[best_idx]["tiles"].append(tile_pos)
			used[tile_pos] = true

	# Convert to Parcel objects.
	var result: Array[Parcel] = []
	var counter := 0
	for pt: Dictionary in parcel_tiles:
		var parcel := Parcel.new()
		parcel.id = "parcel_%d" % counter
		parcel.tiles = pt["tiles"]
		# Recalculate frontage for this parcel.
		parcel.frontage_tiles = _calc_parcel_frontage(parcel, fg)
		result.append(parcel)
		counter += 1

	return result


# ── Phase 4: Validate & Repair ─────────────────────────────────────────

## Merge undersized parcels into neighbors.
static func _validate_and_repair(parcels: Array[Parcel], _zone: ZoneData, _fg: FloorGrid) -> Array[Parcel]:
	if parcels.size() <= 1:
		return parcels

	var valid: Array[Parcel] = []
	var undersized: Array[Parcel] = []

	for p: Parcel in parcels:
		if p.tiles.size() < MIN_PARCEL_TILES:
			undersized.append(p)
		else:
			valid.append(p)

	# Merge undersized into nearest valid parcel.
	for u: Parcel in undersized:
		if valid.is_empty():
			valid.append(u)
			continue
		var best_idx: int = 0
		var best_dist: float = INF
		for i in range(valid.size()):
			var dist := _parcel_distance(u, valid[i])
			if dist < best_dist:
				best_dist = dist
				best_idx = i
		# Merge tiles.
		for t: Vector2i in u.tiles:
			valid[best_idx].tiles.append(t)

	return valid


# ── Helpers ────────────────────────────────────────────────────────────

static func _create_single_parcel(zone: ZoneData) -> Parcel:
	var parcel := Parcel.new()
	parcel.id = "parcel_0"
	parcel.tiles = zone.tiles.duplicate()
	return parcel


static func _calculate_center(tiles: Array) -> Vector2i:
	if tiles.is_empty():
		return Vector2i.ZERO
	var sum_x: int = 0
	var sum_y: int = 0
	for t: Vector2i in tiles:
		sum_x += t.x
		sum_y += t.y
	return Vector2i(sum_x / tiles.size(), sum_y / tiles.size())


static func _calc_parcel_frontage(parcel: Parcel, fg: FloorGrid) -> Array[Vector2i]:
	var frontage: Array[Vector2i] = []
	for tile_pos: Vector2i in parcel.tiles:
		for offset: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var nx: int = tile_pos.x + offset.x
			var ny: int = tile_pos.y + offset.y
			if not fg.is_valid_tile(nx, ny):
				continue
			var neighbor: GridTile = fg.get_tile(nx, ny)
			if neighbor != null and (not neighbor.owned or neighbor.element == GridTile.TileElement.CIRCULATION):
				frontage.append(tile_pos)
				break
	return frontage


static func _parcel_distance(a: Parcel, b: Parcel) -> float:
	var ca: Vector2i = _calculate_center(a.tiles)
	var cb: Vector2i = _calculate_center(b.tiles)
	return ca.distance_squared_to(cb)
