## ZoneManager — Owns zone lifecycle and atomically commits valid parcel splits.
class_name ZoneManager
extends Node


enum AssignmentMode { DEBUG_IMMEDIATE }

const PHYSICAL_DOOR_ACCESS_KINDS: Array[String] = ["external_circulation", "internal_transit"]

## Active parcel-subtype assignment policy for this handoff.
var assignment_mode: AssignmentMode = AssignmentMode.DEBUG_IMMEDIATE

## All zones, keyed by zone ID.
var zones: Dictionary = {}  # Dictionary[String, ZoneData]

## Zone ID counter for generating unique IDs.
var _zone_counter: int = 0

## Parcel ID counter for globally unique, persistent parcel IDs.
var _parcel_counter: int = 0

## Parcel display-number counter. Numbers are positive and never reused.
var _parcel_display_number_counter: int = 0

## Most recent pure split attempt for future UI/debug feedback.
var last_split_result: SplitResult

## Most recent committed debug subtype assignment result.
var last_assignment_result: BusinessAssignmentResult


# ── Assignment Mode ───────────────────────────────────────────────────


## Whether the active assignment mode permits the normal tenant lifecycle.
func permits_tenant_lifecycle() -> bool:
	return assignment_mode != AssignmentMode.DEBUG_IMMEDIATE


# ── Zone CRUD ──────────────────────────────────────────────────────────


## Create, split, and atomically commit a new zone. Returns null on rejection.
func create_zone(
	zone_type: String,
	tiles: Array[Vector2i],
	floor: String,
	plot_id: String,
	typologies: Dictionary = {}
) -> ZoneData:
	var counter_snapshot := _counter_snapshot()
	var candidate := ZoneData.new()
	candidate.id = _generate_zone_id()
	candidate.parcel_layout_seed = _generate_parcel_layout_seed(candidate.id)
	candidate.plot_id = plot_id
	candidate.type = zone_type
	candidate.floor = floor
	candidate.tiles = _normalized_tiles(tiles)
	candidate.typologies = _normalize_typologies(candidate.tiles, typologies)
	candidate.zone_name = zone_type

	if not _validate_candidate_tiles(candidate, ""):
		_restore_counters(counter_snapshot)
		return null
	var transaction := _prepare_access_transaction(candidate, null)
	if transaction.is_empty():
		_restore_counters(counter_snapshot)
		return null
	candidate = transaction[0]
	zones[candidate.id] = candidate
	for committed_zone: ZoneData in transaction:
		if committed_zone != candidate:
			var existing: ZoneData = zones.get(committed_zone.id, null)
			if existing != null:
				_copy_zone_state(committed_zone, existing)
				committed_zone = existing
		_mark_zone_tiles(committed_zone)
	_rebuild_pathfinding()
	EventBus.zone_created.emit(candidate.id, candidate.type, candidate.tiles.size())
	for committed_zone: ZoneData in transaction:
		if committed_zone != candidate:
			EventBus.zone_modified.emit(committed_zone.id)
	return candidate


## Modify, fully re-split, and atomically commit a zone. Returns null on rejection.
func modify_zone(
	zone_id: String,
	new_tiles: Array[Vector2i],
	plot_id: String,
	typologies: Dictionary = {}
) -> ZoneData:
	var counter_snapshot := _counter_snapshot()
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
		_restore_counters(counter_snapshot)
		return null
	var transaction := _prepare_access_transaction(candidate, zone)
	if transaction.is_empty():
		_restore_counters(counter_snapshot)
		return null
	candidate = transaction[0]
	var old_tiles: Array[Vector2i] = zone.tiles.duplicate()
	_clear_zone_tiles(old_tiles, zone.plot_id, zone.floor)
	_copy_zone_state(candidate, zone)
	for committed_zone: ZoneData in transaction:
		if committed_zone != candidate:
			var existing: ZoneData = zones.get(committed_zone.id, null)
			if existing != null:
				_copy_zone_state(committed_zone, existing)
				_mark_zone_tiles(existing)
	_mark_zone_tiles(zone)
	_rebuild_pathfinding()
	EventBus.zone_modified.emit(zone_id)
	for committed_zone: ZoneData in transaction:
		if committed_zone != candidate:
			EventBus.zone_modified.emit(committed_zone.id)
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


## Validate pending ZoneTool data without mutating zones, grid state, counters, or events.
func preview_split(
	zone_type: String,
	tiles: Array[Vector2i],
	floor: String,
	plot_id: String,
	typologies: Dictionary = {},
	preview_zone_id: String = ""
) -> SplitResult:
	var grid_manager := _get_grid_manager()
	if grid_manager == null:
		return SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "GRID_MANAGER_UNAVAILABLE")
	var preview_zone := ZoneData.new()
	var replaced_zone: ZoneData = zones.get(preview_zone_id, null)
	if replaced_zone != null:
		preview_zone.id = replaced_zone.id
		preview_zone.parcel_layout_seed = replaced_zone.parcel_layout_seed
	else:
		# Match the ID and deterministic growth seed that the next create commit
		# will allocate without advancing any persistent counters.
		preview_zone.id = "zone_%d" % (_zone_counter + 1)
		preview_zone.parcel_layout_seed = _generate_parcel_layout_seed(preview_zone.id)
	preview_zone.plot_id = plot_id
	preview_zone.type = zone_type
	preview_zone.floor = floor
	preview_zone.tiles = _normalized_tiles(tiles)
	preview_zone.typologies = _normalize_typologies(preview_zone.tiles, typologies)
	return _preview_access_transaction(preview_zone, replaced_zone)


## Plan the same pure split and physical-door validation transaction as commit
## without assigning IDs, mutating counters, grid state, or existing zones.
func _preview_access_transaction(candidate: ZoneData, replaced_zone: ZoneData) -> SplitResult:
	var grid_manager := _get_grid_manager()
	if grid_manager == null:
		return SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "GRID_MANAGER_UNAVAILABLE")
	var overlay: Dictionary = {}
	if replaced_zone != null:
		for tile_pos: Vector2i in replaced_zone.tiles:
			overlay[tile_pos] = ""
	for tile_pos: Vector2i in candidate.tiles:
		overlay[tile_pos] = candidate.id
	var context := FloorAccessContext.new(
		grid_manager.get_floor_grid(candidate.plot_id, candidate.floor),
		grid_manager.get_plot(candidate.plot_id),
		overlay
	)
	var result := ZoneSplitter.split(candidate, context.floor_grid, context.plot, context)
	if not result.is_success():
		return result
	if replaced_zone != null:
		_match_preview_parcels(result.parcels, replaced_zone.parcels)
		var invalidated_door := _prior_door_invalidation_diagnostic(
			candidate.id, result.parcels, replaced_zone.parcels
		)
		if not invalidated_door.is_empty():
			return _existing_door_failure(result.parcels, invalidated_door)
	if not _all_parcels_have_physical_door_frontage(result.parcels):
		return _physical_door_failure(result.parcels, "NO_PHYSICAL_DOOR_FRONTAGE")

	for affected_zone: ZoneData in _affected_zones(candidate, replaced_zone):
		var affected_result := ZoneSplitter.split(affected_zone, context.floor_grid, context.plot, context)
		if not affected_result.is_success():
			return affected_result
		_match_preview_parcels(affected_result.parcels, affected_zone.parcels)
		var affected_invalidated_door := _prior_door_invalidation_diagnostic(
			affected_zone.id, affected_result.parcels, affected_zone.parcels
		)
		if not affected_invalidated_door.is_empty():
			return _existing_door_failure(affected_result.parcels, affected_invalidated_door)
		if not _all_parcels_have_physical_door_frontage(affected_result.parcels):
			return _physical_door_failure(
				affected_result.parcels,
				"AFFECTED_ZONE_NO_PHYSICAL_DOOR_FRONTAGE:%s" % affected_zone.id
			)
	return result


func _physical_door_failure(parcels: Array[Parcel], diagnostic: String) -> SplitResult:
	var failure := SplitResult.failure(SplitResult.Status.NO_PHYSICAL_DOOR_FRONTAGE, diagnostic)
	failure.parcels = parcels
	return failure


func _existing_door_failure(parcels: Array[Parcel], diagnostic: String) -> SplitResult:
	var failure := SplitResult.failure(SplitResult.Status.EXISTING_DOOR_INVALIDATED, diagnostic)
	failure.parcels = parcels
	return failure


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
			"parcel_layout_seed": zone.parcel_layout_seed,
			"typologies": _serialize_typologies(zone.typologies),
			"zone_name": zone.zone_name,
			"parcels": serialized_parcels,
		}
	return {
		"zones": data,
		"zone_counter": _zone_counter,
		"parcel_counter": _parcel_counter,
		"parcel_display_number_counter": _parcel_display_number_counter,
	}


func deserialize(data: Dictionary) -> void:
	zones.clear()
	_zone_counter = data.get("zone_counter", 0)
	_parcel_counter = data.get("parcel_counter", 0)
	_parcel_display_number_counter = data.get("parcel_display_number_counter", 0)
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
		zone.parcel_layout_seed = int(zone_data.get("parcel_layout_seed", _generate_parcel_layout_seed(zone.id)))
		if zone.parcel_layout_seed <= 0:
			zone.parcel_layout_seed = _generate_parcel_layout_seed(zone.id)
		zone.typologies = _deserialize_typologies(zone_data.get("typologies", []))
		zone.zone_name = zone_data.get("zone_name", "")
		for parcel_data: Dictionary in zone_data.get("parcels", []):
			var parcel := Parcel.deserialize(parcel_data)
			zone.parcels.append(parcel)
			_parcel_display_number_counter = maxi(_parcel_display_number_counter, parcel.display_number)
		zones[zone.id] = zone


# ── Atomic Split Preparation ───────────────────────────────────────────


func _prepare_access_transaction(candidate: ZoneData, replaced_zone: ZoneData) -> Array[ZoneData]:
	var grid_manager := _get_grid_manager()
	if grid_manager == null:
		last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "GRID_MANAGER_UNAVAILABLE")
		return []
	var overlay: Dictionary = {}
	if replaced_zone != null:
		for tile_pos: Vector2i in replaced_zone.tiles:
			overlay[tile_pos] = ""
	for tile_pos: Vector2i in candidate.tiles:
		overlay[tile_pos] = candidate.id
	var context := FloorAccessContext.new(
		grid_manager.get_floor_grid(candidate.plot_id, candidate.floor),
		grid_manager.get_plot(candidate.plot_id),
		overlay
	)
	if not _prepare_split(candidate, context):
		return []
	var prior_parcels: Array[Parcel] = []
	if replaced_zone != null:
		prior_parcels = replaced_zone.parcels
	_assign_persistent_ids(candidate.parcels, prior_parcels)
	if not prior_parcels.is_empty() and not _validate_prior_selected_doors(
		candidate.id, candidate.parcels, prior_parcels
	):
		return []
	if not _assign_selected_door_edges(candidate.parcels, prior_parcels):
		return []
	_assign_debug_subtypes(candidate)
	var prepared: Array[ZoneData] = [candidate]
	for affected_zone: ZoneData in _affected_zones(candidate, replaced_zone):
		var affected_candidate := _copy_zone(affected_zone)
		if not _prepare_split(affected_candidate, context):
			return []
		_assign_persistent_ids(affected_candidate.parcels, affected_zone.parcels)
		if not _validate_prior_selected_doors(
			affected_zone.id, affected_candidate.parcels, affected_zone.parcels
		):
			return []
		if not _assign_selected_door_edges(affected_candidate.parcels, affected_zone.parcels):
			return []
		_assign_debug_subtypes(affected_candidate)
		prepared.append(affected_candidate)
	return prepared


func _affected_zones(candidate: ZoneData, replaced_zone: ZoneData) -> Array[ZoneData]:
	var changed_tiles: Dictionary = {}
	for tile_pos: Vector2i in candidate.tiles:
		changed_tiles[tile_pos] = true
	if replaced_zone != null:
		for tile_pos: Vector2i in replaced_zone.tiles:
			changed_tiles[tile_pos] = true
	var affected: Array[ZoneData] = []
	for zone_id: String in zones:
		var zone: ZoneData = zones[zone_id]
		if zone.id == candidate.id or zone.plot_id != candidate.plot_id or zone.floor != candidate.floor:
			continue
		var touches_changed_tile := false
		for tile_pos: Vector2i in zone.tiles:
			for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if changed_tiles.has(tile_pos + direction):
					touches_changed_tile = true
					break
			if touches_changed_tile:
				break
		if touches_changed_tile:
			affected.append(zone)
	affected.sort_custom(func(first: ZoneData, second: ZoneData) -> bool: return first.id < second.id)
	return affected


func _prepare_split(candidate: ZoneData, access_context: FloorAccessContext = null) -> bool:
	var grid_manager := _get_grid_manager()
	if grid_manager == null:
		last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "GRID_MANAGER_UNAVAILABLE")
		return false
	var floor_grid := grid_manager.get_floor_grid(candidate.plot_id, candidate.floor)
	var plot := grid_manager.get_plot(candidate.plot_id)
	last_split_result = ZoneSplitter.split(candidate, floor_grid, plot, access_context)
	if not last_split_result.is_success():
		return false
	for residual_tile: Vector2i in last_split_result.residual_tiles:
		candidate.typologies[residual_tile] = GridTile.TileTypology.DECORATION
	candidate.parcels = last_split_result.parcels
	return true


## Apply the pure debug assignment result to the uncommitted zone candidate.
func _assign_debug_subtypes(candidate: ZoneData) -> void:
	if assignment_mode != AssignmentMode.DEBUG_IMMEDIATE:
		return
	var catalog_snapshot := DebugBusinessSubtypeCatalog.snapshot_for_zone_type(candidate.type)
	var assignment_result := ZoneBusinessAssigner.assign(
		candidate.parcels,
		candidate.type,
		catalog_snapshot
	)
	for parcel: Parcel in candidate.parcels:
		parcel.assigned_subtype_id = assignment_result.subtype_for(parcel.id)
	last_assignment_result = assignment_result


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
		if tile.element != GridTile.TileElement.NONE and tile.element != GridTile.TileElement.CIRCULATION:
			last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "OCCUPIED_ZONE_TILE")
			return false
		if not tile.zone_id.is_empty() and tile.zone_id != existing_zone_id:
			last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "OVERLAPPING_ZONE_TILE")
			return false
	return true


## Select deterministic physical door edges after parcel IDs are stable and before commit.
func _assign_selected_door_edges(new_parcels: Array[Parcel], old_parcels: Array[Parcel]) -> bool:
	var old_parcels_by_id: Dictionary = {}
	for old_parcel: Parcel in old_parcels:
		if not old_parcel.id.is_empty():
			old_parcels_by_id[old_parcel.id] = old_parcel

	for parcel: Parcel in new_parcels:
		var physical_candidates := _physical_door_candidates(parcel)
		if physical_candidates.is_empty():
			last_split_result = SplitResult.failure(
				SplitResult.Status.NO_PHYSICAL_DOOR_FRONTAGE,
				"NO_PHYSICAL_DOOR_FRONTAGE"
			)
			return false

		var eligible_positions: Dictionary = {}
		var candidates_by_key: Dictionary = {}
		for edge: Dictionary in physical_candidates:
			eligible_positions[edge.get("tile", Vector2i.ZERO)] = true
			candidates_by_key[_door_edge_key(edge)] = edge
		var required_count := ceili(float(eligible_positions.size()) / 10.0)

		var selected: Array[Dictionary] = []
		var selected_positions: Dictionary = {}
		var previous: Parcel = old_parcels_by_id.get(parcel.id, null)
		if previous != null:
			var prior_edges := previous.selected_door_edges.duplicate()
			prior_edges.sort_custom(_compare_door_edges)
			for prior_edge: Dictionary in prior_edges:
				var legal_edge: Dictionary = candidates_by_key.get(_door_edge_key(prior_edge), {})
				var tile: Vector2i = legal_edge.get("tile", Vector2i.ZERO)
				if legal_edge.is_empty() or selected_positions.has(tile) or selected.size() >= required_count:
					continue
				selected.append(legal_edge.duplicate())
				selected_positions[tile] = true

		var covered_transit_areas: Dictionary = {}
		for selected_edge: Dictionary in selected:
			var selected_area := _transit_area_key(selected_edge)
			if not selected_area.is_empty():
				covered_transit_areas[selected_area] = true

		while selected.size() < required_count:
			var next_edge := _preferred_door_candidate(
				physical_candidates, selected.size(), selected_positions, covered_transit_areas
			)
			if next_edge.is_empty():
				break
			selected.append(next_edge.duplicate())
			var selected_tile: Vector2i = next_edge.get("tile", Vector2i.ZERO)
			selected_positions[selected_tile] = true
			var transit_area := _transit_area_key(next_edge)
			if not transit_area.is_empty():
				covered_transit_areas[transit_area] = true
		parcel.selected_door_edges = selected
	return true


func _preferred_door_candidate(
	candidates: Array[Dictionary],
	slot_index: int,
	selected_positions: Dictionary,
	covered_transit_areas: Dictionary
) -> Dictionary:
	var preferred: Array[Dictionary] = []
	var fallback: Array[Dictionary] = []
	for edge: Dictionary in candidates:
		var tile: Vector2i = edge.get("tile", Vector2i.ZERO)
		if selected_positions.has(tile):
			continue
		fallback.append(edge)
		var access_kind: String = edge.get("access_kind", "")
		var transit_area := _transit_area_key(edge)
		if slot_index == 0:
			if access_kind == "internal_transit":
				preferred.append(edge)
		elif slot_index == 1:
			if access_kind == "external_circulation":
				preferred.append(edge)
			elif access_kind == "internal_transit" and not covered_transit_areas.has(transit_area):
				# Used only when no external candidate exists; see fallback below.
				pass
		else:
			if access_kind == "internal_transit" and not covered_transit_areas.has(transit_area):
				preferred.append(edge)
	if not preferred.is_empty():
		return preferred[0]
	if slot_index == 1:
		for edge: Dictionary in fallback:
			if edge.get("access_kind", "") == "internal_transit":
				if not covered_transit_areas.has(_transit_area_key(edge)):
					return edge
	return fallback[0] if not fallback.is_empty() else {}


func _transit_area_key(edge: Dictionary) -> String:
	if edge.get("access_kind", "") != "internal_transit":
		return ""
	var explicit_key: String = edge.get("transit_area_key", "")
	if not explicit_key.is_empty():
		return explicit_key
	var access: Vector2i = edge.get("access", Vector2i.ZERO)
	return "transit:%d,%d" % [access.x, access.y]


func _all_parcels_have_physical_door_frontage(parcels: Array[Parcel]) -> bool:
	for parcel: Parcel in parcels:
		if _physical_door_candidates(parcel).is_empty():
			return false
	return true


func _physical_door_candidates(parcel: Parcel) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for edge: Dictionary in parcel.frontage_edges:
		var tile: Vector2i = edge.get("tile", Vector2i.ZERO)
		var direction: Vector2i = edge.get("direction", Vector2i.ZERO)
		var access: Vector2i = edge.get("access", Vector2i.ZERO)
		var access_kind: String = edge.get("access_kind", "")
		if direction == Vector2i.ZERO or access != tile + direction:
			continue
		if not PHYSICAL_DOOR_ACCESS_KINDS.has(access_kind):
			continue
		candidates.append(edge.duplicate())
	candidates.sort_custom(_compare_door_edges)
	return candidates


static func _door_edge_key(edge: Dictionary) -> String:
	var tile: Vector2i = edge.get("tile", Vector2i.ZERO)
	var direction: Vector2i = edge.get("direction", Vector2i.ZERO)
	var access: Vector2i = edge.get("access", Vector2i.ZERO)
	return "%d,%d|%d,%d|%d,%d|%s" % [
		tile.x, tile.y, direction.x, direction.y, access.x, access.y, edge.get("access_kind", "")
	]


static func _compare_door_edges(first: Dictionary, second: Dictionary) -> bool:
	var first_tile: Vector2i = first.get("tile", Vector2i.ZERO)
	var second_tile: Vector2i = second.get("tile", Vector2i.ZERO)
	if first_tile != second_tile:
		return _compare_tile_positions(first_tile, second_tile)
	return _door_direction_rank(first.get("direction", Vector2i.ZERO)) < _door_direction_rank(
		second.get("direction", Vector2i.ZERO)
	)


static func _door_direction_rank(direction: Vector2i) -> int:
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]
	for index: int in range(directions.size()):
		if directions[index] == direction:
			return index
	return directions.size()


func _validate_prior_selected_doors(
	zone_id: String, new_parcels: Array[Parcel], old_parcels: Array[Parcel]
) -> bool:
	var diagnostic := _prior_door_invalidation_diagnostic(zone_id, new_parcels, old_parcels)
	if diagnostic.is_empty():
		return true
	last_split_result = SplitResult.failure(SplitResult.Status.EXISTING_DOOR_INVALIDATED, diagnostic)
	return false


func _prior_door_invalidation_diagnostic(
	zone_id: String, new_parcels: Array[Parcel], old_parcels: Array[Parcel]
) -> String:
	var new_parcels_by_id: Dictionary = {}
	for parcel: Parcel in new_parcels:
		new_parcels_by_id[parcel.id] = parcel
	for old_parcel: Parcel in old_parcels:
		if old_parcel.selected_door_edges.is_empty():
			continue
		var new_parcel: Parcel = new_parcels_by_id.get(old_parcel.id, null)
		if new_parcel == null:
			return "EXISTING_DOOR_INVALIDATED:%s:%s:PARCEL_NO_LONGER_MATCHED" % [zone_id, old_parcel.id]
		var candidate_keys: Dictionary = {}
		for edge: Dictionary in _physical_door_candidates(new_parcel):
			candidate_keys[_door_edge_key(edge)] = true
		for old_edge: Dictionary in old_parcel.selected_door_edges:
			if not candidate_keys.has(_door_edge_key(old_edge)):
				return "EXISTING_DOOR_INVALIDATED:%s:%s:%s:EDGE_NOT_IN_PROSPECTIVE_PARCEL" % [
					zone_id, old_parcel.id, _door_edge_key(old_edge)
				]
	return ""


func _match_preview_parcels(new_parcels: Array[Parcel], old_parcels: Array[Parcel]) -> void:
	var counter_snapshot := _counter_snapshot()
	_assign_persistent_ids(new_parcels, old_parcels)
	_restore_counters(counter_snapshot)


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
			parcel.display_number = matched_parcel.display_number if matched_parcel.display_number > 0 else _generate_parcel_display_number()
			used_old_ids[matched_parcel.id] = true
		else:
			parcel.id = _generate_parcel_id()
			parcel.display_number = _generate_parcel_display_number()


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
		# Zone-owned tiles are no longer public circulation; their semantic
		# access comes from Tenant/Transit typology and frontage metadata.
		grid_manager.set_tile_element(
			tile_pos.x, tile_pos.y, GridTile.TileElement.NONE, zone.plot_id, zone.floor
		)
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
		grid_manager.set_tile_element(tile_pos.x, tile_pos.y, GridTile.TileElement.CIRCULATION, plot_id, floor)
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
	copy.parcel_layout_seed = source.parcel_layout_seed
	copy.typologies = source.typologies.duplicate()
	copy.zone_name = source.zone_name
	copy.parcels = source.parcels.duplicate()
	return copy


func _copy_zone_state(source: ZoneData, destination: ZoneData) -> void:
	destination.plot_id = source.plot_id
	destination.type = source.type
	destination.subtype = source.subtype
	destination.floor = source.floor
	destination.tiles = source.tiles.duplicate()
	destination.parcel_layout_seed = source.parcel_layout_seed
	destination.typologies = source.typologies.duplicate()
	destination.zone_name = source.zone_name
	destination.parcels = source.parcels.duplicate()


func _counter_snapshot() -> Dictionary:
	return {
		"zone": _zone_counter,
		"parcel": _parcel_counter,
		"display": _parcel_display_number_counter,
	}


func _restore_counters(snapshot: Dictionary) -> void:
	_zone_counter = int(snapshot.get("zone", _zone_counter))
	_parcel_counter = int(snapshot.get("parcel", _parcel_counter))
	_parcel_display_number_counter = int(snapshot.get("display", _parcel_display_number_counter))


func _generate_zone_id() -> String:
	_zone_counter += 1
	return "zone_%d" % _zone_counter


func _generate_parcel_id() -> String:
	_parcel_counter += 1
	return "parcel_%d" % _parcel_counter


## Derive a stable random-looking seed from the persistent zone ID.
func _generate_parcel_layout_seed(zone_id: String) -> int:
	var seed: int = ("parcel_layout:%s" % zone_id).hash()
	return -seed if seed < 0 else seed


func _generate_parcel_display_number() -> int:
	_parcel_display_number_counter += 1
	return _parcel_display_number_counter


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
