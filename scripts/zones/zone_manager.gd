## ZoneManager — Central zone data lifecycle, tile marking, and synergy recalculation.
## Owns all ZoneData objects. Coordinates with ZoneSplitter, ZoneBusinessAssigner,
## GridManager, and ZoneTool.
class_name ZoneManager
extends Node


## All zones, keyed by zone ID.
var zones: Dictionary = {}  # Dictionary[String, ZoneData]

## Zone ID counter for generating unique IDs.
var _zone_counter: int = 0


# ── Zone CRUD ──────────────────────────────────────────────────────────

## Create a new zone from painted tiles.
func create_zone(
	zone_type: String,
	tiles: Array[Vector2i],
	floor: String,
	plot_id: String = GridManager.DEFAULT_PLOT,
	typologies: Dictionary = {}
) -> ZoneData:
	var zone := ZoneData.new()
	zone.id = _generate_zone_id()
	zone.type = zone_type
	zone.floor = floor
	zone.tiles = tiles.duplicate()
	zone.typologies = typologies
	zone.zone_name = zone_type  # Default name; player can rename.

	# Mark tiles in GridManager.
	for tile_pos: Vector2i in tiles:
		var grid_manager := _get_grid_manager()
		if grid_manager:
			grid_manager.set_tile_zone(tile_pos.x, tile_pos.y, zone.id, plot_id, floor)

	zones[zone.id] = zone
	_rebuild_pathfinding()

	# Emit event.
	EventBus.zone_created.emit(zone.id, zone.type, tiles.size())

	return zone


## Modify an existing zone (tiles added/removed, typologies changed).
func modify_zone(
	zone_id: String,
	new_tiles: Array[Vector2i],
	plot_id: String = GridManager.DEFAULT_PLOT,
	typologies: Dictionary = {}
) -> ZoneData:
	var zone: ZoneData = zones.get(zone_id, null)
	if zone == null:
		push_error("ZoneManager.modify_zone(): zone '%s' not found." % zone_id)
		return null

	var old_tiles: Array[Vector2i] = zone.tiles.duplicate()

	# Clear old tile markings.
	for tile_pos: Vector2i in old_tiles:
		var grid_manager := _get_grid_manager()
		if grid_manager:
			grid_manager.set_tile_zone(tile_pos.x, tile_pos.y, "", plot_id, zone.floor)

	# Set new tiles.
	zone.tiles = new_tiles.duplicate()
	if not typologies.is_empty():
		zone.typologies = typologies

	# Mark new tiles.
	for tile_pos: Vector2i in zone.tiles:
		var grid_manager := _get_grid_manager()
		if grid_manager:
			grid_manager.set_tile_zone(tile_pos.x, tile_pos.y, zone.id, plot_id, zone.floor)

	_rebuild_pathfinding()
	EventBus.zone_modified.emit(zone_id)
	return zone


## Delete a zone and clear its tiles.
func delete_zone(zone_id: String, plot_id: String = GridManager.DEFAULT_PLOT) -> void:
	var zone: ZoneData = zones.get(zone_id, null)
	if zone == null:
		return

	for tile_pos: Vector2i in zone.tiles:
		var grid_manager := _get_grid_manager()
		if grid_manager:
			grid_manager.sell_tile(tile_pos.x, tile_pos.y, plot_id, zone.floor)

	zones.erase(zone_id)
	_rebuild_pathfinding()
	EventBus.zone_deleted.emit(zone_id)


# ── Zone Queries ───────────────────────────────────────────────────────

## Get the zone containing a specific tile position.
func get_zone_at_tile(tile_pos: Vector2i, floor: String = "G", plot_id: String = GridManager.DEFAULT_PLOT) -> ZoneData:
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
func is_tile_in_zone(tile_pos: Vector2i, floor: String = "G", plot_id: String = GridManager.DEFAULT_PLOT) -> bool:
	return get_zone_at_tile(tile_pos, floor, plot_id) != null


# ── Splitting & Business Assignment ────────────────────────────────────

## Run the splitting algorithm on a zone and assign businesses.
func split_zone(zone_id: String) -> void:
	var zone: ZoneData = zones.get(zone_id, null)
	if zone == null:
		return

	var grid_manager := _get_grid_manager()
	if grid_manager == null:
		return

	# Run the splitter.
	var parcels: Array[Parcel] = ZoneSplitter.split(zone, grid_manager)
	zone.parcels = parcels

	# Assign business types.
	ZoneBusinessAssigner.assign(zone)


# ── Serialization ──────────────────────────────────────────────────────

func serialize() -> Dictionary:
	var data := {}
	for zone_id: String in zones:
		var zone: ZoneData = zones[zone_id]
		data[zone_id] = {
			"id": zone.id,
			"type": zone.type,
			"subtype": zone.subtype,
			"floor": zone.floor,
			"tiles": zone.tiles,
			"walls_enabled": zone.walls_enabled,
			"zone_name": zone.zone_name,
		}
	return {"zones": data, "zone_counter": _zone_counter}


func deserialize(data: Dictionary) -> void:
	zones.clear()
	_zone_counter = data.get("zone_counter", 0)
	var zones_data: Dictionary = data.get("zones", {})
	for zone_id: String in zones_data:
		var zd: Dictionary = zones_data[zone_id]
		var zone := ZoneData.new()
		zone.id = zd["id"]
		zone.type = zd["type"]
		zone.subtype = zd.get("subtype", "")
		zone.floor = zd["floor"]
		zone.tiles = zd["tiles"]
		zone.walls_enabled = zd.get("walls_enabled", true)
		zone.zone_name = zd.get("zone_name", "")
		zones[zone_id] = zone


# ── Internal ───────────────────────────────────────────────────────────

func _generate_zone_id() -> String:
	_zone_counter += 1
	return "zone_%d" % _zone_counter


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
