## Parcel — A valid rectangular tenant-space subdivision created by ZoneSplitter.
class_name Parcel
extends RefCounted


## Persistent parcel identifier allocated by ZoneManager after a successful split.
var id: String = ""

## Globally unique, positive debug display number allocated by ZoneManager.
var display_number: int = 0

## Canonically sorted rectangular core geometry allocated during split phase one.
var core_tiles: Array[Vector2i] = []
var core_bounds: Rect2i = Rect2i()

## Canonically sorted final tile positions after residual growth.

var tiles: Array[Vector2i] = []

## Axis-aligned bounds containing exactly the parcel tiles.
var bounds: Rect2i = Rect2i()

## Cached count of rentable Tenant tiles.
var area: int = 0

## Directed tenant-door candidates. Each dictionary contains tile, direction,
## access, and access_kind values; the splitter never creates a physical door.
var frontage_edges: Array[Dictionary] = []

## Legacy tile-only frontage view retained for compatibility with existing code.
var frontage_tiles: Array[Vector2i] = []

## Deterministically selected physical door edges owned by ZoneManager.
## Each dictionary uses the same tile/direction/access/access_kind schema as frontage_edges.
var selected_door_edges: Array[Dictionary] = []

## Stable debug subtype ID assigned by Handoff 02; this is not a tenant ID.
var assigned_subtype_id: String = ""

## Whether a later tenant lifecycle has occupied this parcel.
var has_tenant: bool = false

## Reference to a future tenant occupying this parcel.
var tenant_id: String = ""


func set_geometry(p_tiles: Array[Vector2i], p_frontage_edges: Array[Dictionary]) -> void:
	tiles = p_tiles.duplicate()
	tiles.sort_custom(_sort_tile_positions)
	frontage_edges = p_frontage_edges.duplicate()
	frontage_tiles.clear()
	for edge: Dictionary in frontage_edges:
		var tile: Vector2i = edge.get("tile", Vector2i.ZERO)
		if not frontage_tiles.has(tile):
			frontage_tiles.append(tile)
	frontage_tiles.sort_custom(_sort_tile_positions)
	area = tiles.size()
	bounds = _calculate_bounds(tiles)


func set_core_geometry(p_tiles: Array[Vector2i]) -> void:
	core_tiles = p_tiles.duplicate()
	core_tiles.sort_custom(_sort_tile_positions)
	core_bounds = _calculate_bounds(core_tiles)


## Choose a deterministic final-parcel tile nearest its geometric centroid.
## This keeps non-rectangular parcel labels inside the parcel footprint.
func label_anchor_tile() -> Vector2i:
	if tiles.is_empty():
		return Vector2i.ZERO
	var centroid := Vector2.ZERO
	for tile: Vector2i in tiles:
		centroid += Vector2(float(tile.x) + 0.5, float(tile.y) + 0.5)
	centroid /= float(tiles.size())

	var selected := tiles[0]
	var best_distance_squared := Vector2(float(selected.x) + 0.5, float(selected.y) + 0.5).distance_squared_to(centroid)
	for tile: Vector2i in tiles:
		var tile_center := Vector2(float(tile.x) + 0.5, float(tile.y) + 0.5)
		var distance_squared := tile_center.distance_squared_to(centroid)
		if distance_squared < best_distance_squared or (
			is_equal_approx(distance_squared, best_distance_squared) and _sort_tile_positions(tile, selected)
		):
			selected = tile
			best_distance_squared = distance_squared
	return selected


func serialize() -> Dictionary:
	var serialized_tiles: Array[Dictionary] = []
	for tile: Vector2i in tiles:
		serialized_tiles.append({"x": tile.x, "y": tile.y})

	var serialized_core_tiles: Array[Dictionary] = []
	for tile: Vector2i in core_tiles:
		serialized_core_tiles.append({"x": tile.x, "y": tile.y})

	var serialized_frontage := _serialize_edges(frontage_edges)
	var serialized_selected_door_edges := _serialize_edges(selected_door_edges)

	return {
		"id": id,
		"display_number": display_number,
		"tiles": serialized_tiles,
		"core_tiles": serialized_core_tiles,
		"frontage_edges": serialized_frontage,
		"selected_door_edges": serialized_selected_door_edges,
		"assigned_subtype_id": assigned_subtype_id,
		"has_tenant": has_tenant,
		"tenant_id": tenant_id,
	}


static func deserialize(data: Dictionary) -> Parcel:
	var parcel := Parcel.new()
	parcel.id = data.get("id", "")
	parcel.display_number = data.get("display_number", 0)
	var restored_tiles: Array[Vector2i] = []
	for tile_data: Dictionary in data.get("tiles", []):
		restored_tiles.append(Vector2i(tile_data.get("x", 0), tile_data.get("y", 0)))

	var restored_core_tiles: Array[Vector2i] = []
	for tile_data: Dictionary in data.get("core_tiles", []):
		restored_core_tiles.append(Vector2i(tile_data.get("x", 0), tile_data.get("y", 0)))

	var restored_frontage := _deserialize_edges(data.get("frontage_edges", []))
	parcel.selected_door_edges = _deserialize_edges(data.get("selected_door_edges", []))

	parcel.set_geometry(restored_tiles, restored_frontage)
	# Legacy saves predate core geometry; adopt the old footprint as a compatibility core.
	parcel.set_core_geometry(restored_core_tiles if not restored_core_tiles.is_empty() else restored_tiles)
	parcel.assigned_subtype_id = data.get("assigned_subtype_id", "")
	parcel.has_tenant = data.get("has_tenant", false)
	parcel.tenant_id = data.get("tenant_id", "")
	return parcel


static func _serialize_edges(edges: Array[Dictionary]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for edge: Dictionary in edges:
		var tile: Vector2i = edge.get("tile", Vector2i.ZERO)
		var direction: Vector2i = edge.get("direction", Vector2i.ZERO)
		var access: Vector2i = edge.get("access", Vector2i.ZERO)
		serialized.append({
			"tile": {"x": tile.x, "y": tile.y},
			"direction": {"x": direction.x, "y": direction.y},
			"access": {"x": access.x, "y": access.y},
			"access_kind": edge.get("access_kind", ""),
		})
	return serialized


static func _deserialize_edges(data: Array) -> Array[Dictionary]:
	var restored: Array[Dictionary] = []
	for edge_data: Dictionary in data:
		var tile_data: Dictionary = edge_data.get("tile", {})
		var direction_data: Dictionary = edge_data.get("direction", {})
		var access_data: Dictionary = edge_data.get("access", {})
		restored.append({
			"tile": Vector2i(tile_data.get("x", 0), tile_data.get("y", 0)),
			"direction": Vector2i(direction_data.get("x", 0), direction_data.get("y", 0)),
			"access": Vector2i(access_data.get("x", 0), access_data.get("y", 0)),
			"access_kind": edge_data.get("access_kind", ""),
		})
	return restored


static func _sort_tile_positions(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


static func _calculate_bounds(p_tiles: Array[Vector2i]) -> Rect2i:
	if p_tiles.is_empty():
		return Rect2i()
	var min_x: int = p_tiles[0].x
	var max_x: int = p_tiles[0].x
	var min_y: int = p_tiles[0].y
	var max_y: int = p_tiles[0].y
	for tile: Vector2i in p_tiles:
		min_x = mini(min_x, tile.x)
		max_x = maxi(max_x, tile.x)
		min_y = mini(min_y, tile.y)
		max_y = maxi(max_y, tile.y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
