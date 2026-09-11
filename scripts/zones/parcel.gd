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
	var serialized_selected_door_edges := _serialize_selected_door_edges(selected_door_edges)

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
	parcel.selected_door_edges = _deserialize_selected_door_edges(data.get("selected_door_edges", []))

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


static func validate_serialized_selected_door_edges(data: Variant) -> Dictionary:
	if not data is Array:
		return _invalid_public_door()
	var seen_records: Dictionary = {}
	var seen_origins: Dictionary = {}
	var previous_key: String = ""
	for value: Variant in data:
		if not value is Dictionary:
			return _invalid_public_door()
		var edge: Dictionary = value
		if not _has_exact_keys(edge, ["parcel_cell", "direction", "access_kind", "access_cell", "public_band_access_edge_id"]):
			return _invalid_public_door()
		if not edge.get("parcel_cell") is Dictionary or not _valid_cell(edge["parcel_cell"]):
			return _invalid_public_door()
		var direction: String = String(edge.get("direction", ""))
		var access_kind: String = String(edge.get("access_kind", ""))
		if not direction in ["NORTH", "EAST", "SOUTH", "WEST"] or not access_kind in ["SAME_ZONE_TRANSIT", "EXPLICIT_CIRCULATION", "PUBLIC_BAND"]:
			return _invalid_public_door()
		var public_id: Variant = edge.get("public_band_access_edge_id")
		var access_cell: Variant = edge.get("access_cell")
		if access_kind == "PUBLIC_BAND":
			if access_cell != null or not public_id is String or String(public_id).is_empty():
				return _invalid_public_door()
		else:
			if not access_cell is Dictionary or not _valid_cell(access_cell) or public_id != null:
				return _invalid_public_door()
		var cell: Dictionary = edge["parcel_cell"]
		var origin_key := "%d,%d" % [int(cell["x"]), int(cell["y"])]
		var record_key := "%s|%s|%s|%s|%s" % [origin_key, direction, access_kind, str(access_cell), str(public_id)]
		var sort_key := "%012d|%012d|%s" % [int(cell["y"]) + 1000000, int(cell["x"]) + 1000000, direction]
		if seen_origins.has(origin_key) or seen_records.has(record_key) or (not previous_key.is_empty() and sort_key <= previous_key):
			return _invalid_public_door()
		seen_origins[origin_key] = true
		seen_records[record_key] = true
		previous_key = sort_key
	return {"valid": true, "diagnostics": []}


static func _serialize_selected_door_edges(edges: Array[Dictionary]) -> Array[Dictionary]:
	var ordered: Array[Dictionary] = edges.duplicate(true)
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_tile: Vector2i = left.get("tile", Vector2i.ZERO)
		var right_tile: Vector2i = right.get("tile", Vector2i.ZERO)
		if left_tile != right_tile:
			return left_tile.y < right_tile.y or (left_tile.y == right_tile.y and left_tile.x < right_tile.x)
		return _direction_name(left.get("direction", Vector2i.ZERO)) < _direction_name(right.get("direction", Vector2i.ZERO))
	)
	var serialized: Array[Dictionary] = []
	for edge: Dictionary in ordered:
		var tile: Vector2i = edge.get("tile", Vector2i.ZERO)
		var access: Vector2i = edge.get("access", Vector2i.ZERO)
		var kind: String = String(edge.get("access_kind", ""))
		serialized.append({
			"parcel_cell": {"x": tile.x, "y": tile.y},
			"direction": _direction_name(edge.get("direction", Vector2i.ZERO)),
			"access_kind": _serialized_access_kind(kind),
			"access_cell": null if kind == "public_band" else {"x": access.x, "y": access.y},
			"public_band_access_edge_id": String(edge.get("public_band_access_edge_id", "")) if kind == "public_band" else null,
		})
	return serialized


static func _deserialize_selected_door_edges(data: Array) -> Array[Dictionary]:
	var restored: Array[Dictionary] = []
	for edge: Dictionary in data:
		var tile_data: Dictionary = edge.get("parcel_cell", {})
		var tile := Vector2i(int(tile_data.get("x", 0)), int(tile_data.get("y", 0)))
		var direction: Vector2i = _direction_vector(String(edge.get("direction", "")))
		var kind: String = _runtime_access_kind(String(edge.get("access_kind", "")))
		var access_data: Variant = edge.get("access_cell")
		var access: Vector2i = tile + direction
		if access_data is Dictionary:
			access = Vector2i(int(access_data.get("x", 0)), int(access_data.get("y", 0)))
		var restored_edge: Dictionary = {"tile": tile, "direction": direction, "access": access, "access_kind": kind}
		if kind == "public_band":
			restored_edge["public_band_access_edge_id"] = String(edge.get("public_band_access_edge_id", ""))
		restored.append(restored_edge)
	return restored


static func _serialized_access_kind(kind: String) -> String:
	match kind:
		"internal_transit": return "SAME_ZONE_TRANSIT"
		"external_circulation": return "EXPLICIT_CIRCULATION"
		"public_band": return "PUBLIC_BAND"
	return ""


static func _runtime_access_kind(kind: String) -> String:
	match kind:
		"SAME_ZONE_TRANSIT": return "internal_transit"
		"EXPLICIT_CIRCULATION": return "external_circulation"
		"PUBLIC_BAND": return "public_band"
	return ""


static func _direction_name(direction: Vector2i) -> String:
	if direction == Vector2i.UP: return "NORTH"
	if direction == Vector2i.RIGHT: return "EAST"
	if direction == Vector2i.DOWN: return "SOUTH"
	if direction == Vector2i.LEFT: return "WEST"
	return ""


static func _direction_vector(direction: String) -> Vector2i:
	match direction:
		"NORTH": return Vector2i.UP
		"EAST": return Vector2i.RIGHT
		"SOUTH": return Vector2i.DOWN
		"WEST": return Vector2i.LEFT
	return Vector2i.ZERO


static func _valid_cell(value: Dictionary) -> bool:
	return _has_exact_keys(value, ["x", "y"]) and value.get("x") is int and value.get("y") is int


static func _has_exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size(): return false
	for key: String in keys:
		if not value.has(key): return false
	return true


static func _invalid_public_door() -> Dictionary:
	return {"valid": false, "diagnostics": [{"code": "INVALID_PUBLIC_BAND_DOOR_PROVENANCE"}]}


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
