## ZoneManager — Owns zone lifecycle and atomically commits valid parcel splits.
class_name ZoneManager
extends Node


## All zones, keyed by zone ID.
var zones: Dictionary = {}  # Dictionary[String, ZoneData]

## Zone ID counter for generating unique IDs.
var _zone_counter: int = 0

## Parcel ID counter for globally unique, persistent parcel IDs.
var _parcel_counter: int = 0

## Most recent pure split attempt for future UI/debug feedback.
var last_split_result: SplitResult


# ── Zone CRUD ──────────────────────────────────────────────────────────


## Create, split, and atomically commit a new zone. Returns null on rejection.
func create_zone(
	zone_type: String,
	tiles: Array[Vector2i],
	floor: String,
	plot_id: String,
	typologies: Dictionary = {}
) -> ZoneData:
	var candidate := ZoneData.new()
	candidate.id = _generate_zone_id()
	candidate.plot_id = plot_id
	candidate.type = zone_type
	candidate.floor = floor
	candidate.tiles = _normalized_tiles(tiles)
	candidate.typologies = _normalize_typologies(candidate.tiles, typologies)
	candidate.zone_name = zone_type

	if not _validate_candidate_tiles(candidate, ""):
		return null
	if not _prepare_split(candidate):
		return null

	_assign_persistent_ids(candidate.parcels, [])
	zones[candidate.id] = candidate
	_mark_zone_tiles(candidate)
	_rebuild_pathfinding()
	EventBus.zone_created.emit(candidate.id, candidate.type, candidate.tiles.size())
	return candidate


## Modify, fully re-split, and atomically commit a zone. Returns null on rejection.
func modify_zone(
	zone_id: String,
	new_tiles: Array[Vector2i],
	plot_id: String,
	typologies: Dictionary = {}
) -> ZoneData:
	var zone: ZoneData = zones.get(zone_id, null)
	if zone == null:
		push_error("ZoneManager.modify_zone(): zone '%s' not found." % zone_id)
		return null
	if zone.plot_id != plot_id:
		last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "PLOT_MISMATCH")
		return null

	var candidate := _copy_zone(zone)
	candidate.tiles = _normalized_tiles(new_tiles)
	candidate.typologies = _normalize_typologies(
		candidate.tiles, typologies if not typologies.is_empty() else zone.typologies
	)
	if not _validate_candidate_tiles(candidate, zone.id):
		return null
	if not _prepare_split(candidate):
		return null

	_assign_persistent_ids(candidate.parcels, zone.parcels)
	var old_tiles: Array[Vector2i] = zone.tiles.duplicate()
	_clear_zone_tiles(old_tiles, zone.plot_id, zone.floor)
	_copy_zone_state(candidate, zone)
	_mark_zone_tiles(zone)
	_rebuild_pathfinding()
	EventBus.zone_modified.emit(zone_id)
	return zone


## Recalculate an existing zone with its current geometry and typologies.
func split_zone(zone_id: String) -> SplitResult:
	var zone: ZoneData = zones.get(zone_id, null)
	if zone == null:
		last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "ZONE_NOT_FOUND")
		return last_split_result
	var result_zone := modify_zone(zone_id, zone.tiles, zone.plot_id, zone.typologies)
	if result_zone == null:
		return last_split_result
	return last_split_result


## Delete a zone using the project's existing floor-demolition behavior.
func delete_zone(zone_id: String, plot_id: String = "") -> void:
	var zone: ZoneData = zones.get(zone_id, null)
	if zone == null:
		return
	if not plot_id.is_empty() and plot_id != zone.plot_id:
		push_error("ZoneManager.delete_zone(): plot mismatch for zone '%s'." % zone_id)
		return

	var grid_manager := _get_grid_manager()
	if grid_manager:
		for tile_pos: Vector2i in zone.tiles:
			grid_manager.sell_tile(tile_pos.x, tile_pos.y, zone.plot_id, zone.floor)
	zones.erase(zone_id)
	_rebuild_pathfinding()
	EventBus.zone_deleted.emit(zone_id)


# ── Zone Queries ───────────────────────────────────────────────────────


## Get the zone containing a specific tile position.
func get_zone_at_tile(
	tile_pos: Vector2i, floor: String = GridManager.GROUND_FLOOR, plot_id: String = GridManager.DEFAULT_PLOT
) -> ZoneData:
	var grid_manager := _get_grid_manager()
	if grid_manager == null:
		return null
	var tile := grid_manager.get_tile(tile_pos.x, tile_pos.y, plot_id, floor)
	if tile == null or tile.zone_id.is_empty():
		return null
	return zones.get(tile.zone_id, null)


## Get all zones on a specific floor.
func get_zones_on_floor(floor: String) -> Array[ZoneData]:
	var result: Array[ZoneData] = []
	for zone_id: String in zones:
		var zone: ZoneData = zones[zone_id]
		if zone.floor == floor:
			result.append(zone)
	return result


## Check if a tile is inside any zone.
func is_tile_in_zone(
	tile_pos: Vector2i, floor: String = GridManager.GROUND_FLOOR, plot_id: String = GridManager.DEFAULT_PLOT
) -> bool:
	return get_zone_at_tile(tile_pos, floor, plot_id) != null


# ── Serialization ──────────────────────────────────────────────────────


func serialize() -> Dictionary:
	var data: Dictionary = {}
	for zone_id: String in zones:
		var zone: ZoneData = zones[zone_id]
		var serialized_parcels: Array[Dictionary] = []
		for parcel: Parcel in zone.parcels:
			serialized_parcels.append(parcel.serialize())
		data[zone_id] = {
			"id": zone.id,
			"plot_id": zone.plot_id,
			"type": zone.type,
			"subtype": zone.subtype,
			"floor": zone.floor,
			"tiles": zone.tiles,
			"typologies": _serialize_typologies(zone.typologies),
			"walls_enabled": zone.walls_enabled,
			"zone_name": zone.zone_name,
			"parcels": serialized_parcels,
		}
	return {
		"zones": data,
		"zone_counter": _zone_counter,
		"parcel_counter": _parcel_counter,
	}


func deserialize(data: Dictionary) -> void:
	zones.clear()
	_zone_counter = data.get("zone_counter", 0)
	_parcel_counter = data.get("parcel_counter", 0)
	var zones_data: Dictionary = data.get("zones", {})
	for zone_id: String in zones_data:
		var zone_data: Dictionary = zones_data[zone_id]
		var zone := ZoneData.new()
		zone.id = zone_data.get("id", zone_id)
		zone.plot_id = zone_data.get("plot_id", "")
		zone.type = zone_data.get("type", "")
		zone.subtype = zone_data.get("subtype", "")
		zone.floor = zone_data.get("floor", GridManager.GROUND_FLOOR)
		zone.tiles = zone_data.get("tiles", [])
		zone.typologies = _deserialize_typologies(zone_data.get("typologies", []))
		zone.walls_enabled = zone_data.get("walls_enabled", true)
		zone.zone_name = zone_data.get("zone_name", "")
		for parcel_data: Dictionary in zone_data.get("parcels", []):
			zone.parcels.append(Parcel.deserialize(parcel_data))
		zones[zone.id] = zone


# ── Atomic Split Preparation ───────────────────────────────────────────


func _prepare_split(candidate: ZoneData) -> bool:
	var grid_manager := _get_grid_manager()
	if grid_manager == null:
		last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "GRID_MANAGER_UNAVAILABLE")
		return false
	var floor_grid := grid_manager.get_floor_grid(candidate.plot_id, candidate.floor)
	var plot := grid_manager.get_plot(candidate.plot_id)
	last_split_result = ZoneSplitter.split(candidate, floor_grid, plot)
	if not last_split_result.is_success():
		return false
	for residual_tile: Vector2i in last_split_result.residual_tiles:
		candidate.typologies[residual_tile] = GridTile.TileTypology.DECORATION
	candidate.parcels = last_split_result.parcels
	return true


func _validate_candidate_tiles(candidate: ZoneData, existing_zone_id: String) -> bool:
	if candidate.plot_id.is_empty() or candidate.tiles.is_empty():
		last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "MISSING_ZONE_CONTEXT")
		return false
	var grid_manager := _get_grid_manager()
	if grid_manager == null:
		last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "GRID_MANAGER_UNAVAILABLE")
		return false
	for tile_pos: Vector2i in candidate.tiles:
		var tile := grid_manager.get_tile(tile_pos.x, tile_pos.y, candidate.plot_id, candidate.floor)
		if tile == null or not tile.owned or not tile.floor_built:
			last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "INVALID_OR_UNOWNED_ZONE_TILE")
			return false
		if tile.element != GridTile.TileElement.NONE:
			last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "OCCUPIED_ZONE_TILE")
			return false
		if not tile.zone_id.is_empty() and tile.zone_id != existing_zone_id:
			last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "OVERLAPPING_ZONE_TILE")
			return false
	return true


func _assign_persistent_ids(new_parcels: Array[Parcel], old_parcels: Array[Parcel]) -> void:
	var used_old_ids: Dictionary = {}
	for parcel: Parcel in new_parcels:
		var matched_parcel: Parcel
		var best_overlap: int = 0
		for old_parcel: Parcel in old_parcels:
			if old_parcel.id.is_empty() or used_old_ids.has(old_parcel.id):
				continue
			var overlap := _tile_overlap(parcel.tiles, old_parcel.tiles)
			if overlap > best_overlap or (
				overlap == best_overlap and overlap > 0 and matched_parcel != null and old_parcel.id < matched_parcel.id
			):
				matched_parcel = old_parcel
				best_overlap = overlap
		if matched_parcel != null and best_overlap > 0:
			parcel.id = matched_parcel.id
			used_old_ids[matched_parcel.id] = true
		else:
			parcel.id = _generate_parcel_id()


func _tile_overlap(first: Array[Vector2i], second: Array[Vector2i]) -> int:
	var second_set: Dictionary = {}
	for tile: Vector2i in second:
		second_set[tile] = true
	var overlap: int = 0
	for tile: Vector2i in first:
		if second_set.has(tile):
			overlap += 1
	return overlap


# ── Grid Commit ────────────────────────────────────────────────────────


func _mark_zone_tiles(zone: ZoneData) -> void:
	var grid_manager := _get_grid_manager()
	if grid_manager == null:
		return
	for tile_pos: Vector2i in zone.tiles:
		grid_manager.set_tile_zone(tile_pos.x, tile_pos.y, zone.id, zone.plot_id, zone.floor)
		grid_manager.set_tile_typology(
			tile_pos.x,
			tile_pos.y,
			zone.typologies.get(tile_pos, GridTile.TileTypology.TENANT),
			zone.plot_id,
			zone.floor
		)


func _clear_zone_tiles(tiles: Array[Vector2i], plot_id: String, floor: String) -> void:
	var grid_manager := _get_grid_manager()
	if grid_manager == null:
		return
	for tile_pos: Vector2i in tiles:
		grid_manager.set_tile_zone(tile_pos.x, tile_pos.y, "", plot_id, floor)
		grid_manager.set_tile_typology(tile_pos.x, tile_pos.y, GridTile.TileTypology.TENANT, plot_id, floor)


# ── Zone Copying & Serialization Helpers ───────────────────────────────


func _copy_zone(source: ZoneData) -> ZoneData:
	var copy := ZoneData.new()
	copy.id = source.id
	copy.plot_id = source.plot_id
	copy.type = source.type
	copy.subtype = source.subtype
	copy.floor = source.floor
	copy.tiles = source.tiles.duplicate()
	copy.typologies = source.typologies.duplicate()
	copy.walls_enabled = source.walls_enabled
	copy.zone_name = source.zone_name
	copy.parcels = source.parcels.duplicate()
	return copy


func _copy_zone_state(source: ZoneData, destination: ZoneData) -> void:
	destination.plot_id = source.plot_id
	destination.type = source.type
	destination.subtype = source.subtype
	destination.floor = source.floor
	destination.tiles = source.tiles.duplicate()
	destination.typologies = source.typologies.duplicate()
	destination.walls_enabled = source.walls_enabled
	destination.zone_name = source.zone_name
	destination.parcels = source.parcels.duplicate()


func _generate_zone_id() -> String:
	_zone_counter += 1
	return "zone_%d" % _zone_counter


func _generate_parcel_id() -> String:
	_parcel_counter += 1
	return "parcel_%d" % _parcel_counter


func _normalize_typologies(tiles: Array[Vector2i], typologies: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for tile_pos: Vector2i in tiles:
		normalized[tile_pos] = typologies.get(tile_pos, GridTile.TileTypology.TENANT)
	return normalized


func _normalized_tiles(tiles: Array[Vector2i]) -> Array[Vector2i]:
	var unique: Dictionary = {}
	for tile: Vector2i in tiles:
		unique[tile] = true
	var normalized: Array[Vector2i] = []
	for tile: Vector2i in unique:
		normalized.append(tile)
	normalized.sort_custom(_compare_tile_positions)
	return normalized


func _serialize_typologies(typologies: Dictionary) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for tile_pos: Vector2i in typologies:
		serialized.append({
			"x": tile_pos.x,
			"y": tile_pos.y,
			"typology": int(typologies[tile_pos]),
		})
	serialized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("y", 0) < b.get("y", 0) or (
			a.get("y", 0) == b.get("y", 0) and a.get("x", 0) < b.get("x", 0)
		)
	)
	return serialized


func _deserialize_typologies(data: Array) -> Dictionary:
	var typologies: Dictionary = {}
	for entry: Dictionary in data:
		typologies[Vector2i(entry.get("x", 0), entry.get("y", 0))] = entry.get(
			"typology", GridTile.TileTypology.TENANT
		)
	return typologies


func _rebuild_pathfinding() -> void:
	var grid_manager := _get_grid_manager()
	if grid_manager:
		grid_manager.rebuild_pathfinding()


func _get_grid_manager() -> GridManager:
	var root := get_tree().current_scene
	if root == null:
		return null
	var world := root.get_node_or_null("World")
	if world == null:
		return null
	return world.get_node_or_null("GridManager") as GridManager


static func _compare_tile_positions(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)
