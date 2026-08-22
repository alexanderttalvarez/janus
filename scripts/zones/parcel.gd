## Parcel — A valid rectangular tenant-space subdivision created by ZoneSplitter.
class_name Parcel
extends RefCounted


## Persistent parcel identifier allocated by ZoneManager after a successful split.
var id: String = ""

## Canonically sorted tile positions in this parcel.
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

## Business type assigned by a later handoff.
var business_type: String = ""

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


func serialize() -> Dictionary:
	var serialized_tiles: Array[Dictionary] = []
	for tile: Vector2i in tiles:
		serialized_tiles.append({"x": tile.x, "y": tile.y})

	var serialized_frontage: Array[Dictionary] = []
	for edge: Dictionary in frontage_edges:
		var tile: Vector2i = edge.get("tile", Vector2i.ZERO)
		var direction: Vector2i = edge.get("direction", Vector2i.ZERO)
		var access: Vector2i = edge.get("access", Vector2i.ZERO)
		serialized_frontage.append({
			"tile": {"x": tile.x, "y": tile.y},
			"direction": {"x": direction.x, "y": direction.y},
			"access": {"x": access.x, "y": access.y},
			"access_kind": edge.get("access_kind", ""),
		})

	return {
		"id": id,
		"tiles": serialized_tiles,
		"frontage_edges": serialized_frontage,
		"business_type": business_type,
		"has_tenant": has_tenant,
		"tenant_id": tenant_id,
	}


static func deserialize(data: Dictionary) -> Parcel:
	var parcel := Parcel.new()
	parcel.id = data.get("id", "")
	var restored_tiles: Array[Vector2i] = []
	for tile_data: Dictionary in data.get("tiles", []):
		restored_tiles.append(Vector2i(tile_data.get("x", 0), tile_data.get("y", 0)))

	var restored_frontage: Array[Dictionary] = []
	for edge_data: Dictionary in data.get("frontage_edges", []):
		var tile_data: Dictionary = edge_data.get("tile", {})
		var direction_data: Dictionary = edge_data.get("direction", {})
		var access_data: Dictionary = edge_data.get("access", {})
		restored_frontage.append({
			"tile": Vector2i(tile_data.get("x", 0), tile_data.get("y", 0)),
			"direction": Vector2i(direction_data.get("x", 0), direction_data.get("y", 0)),
			"access": Vector2i(access_data.get("x", 0), access_data.get("y", 0)),
			"access_kind": edge_data.get("access_kind", ""),
		})

	parcel.set_geometry(restored_tiles, restored_frontage)
	parcel.business_type = data.get("business_type", "")
	parcel.has_tenant = data.get("has_tenant", false)
	parcel.tenant_id = data.get("tenant_id", "")
	return parcel


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
