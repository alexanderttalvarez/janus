## FloorAccessContext — Pure composition of matching immutable District and Zone views.
class_name FloorAccessContext
extends RefCounted

var spatial_snapshot: DistrictZoneSpatialSnapshot
var prospective_zone_ids: Dictionary = {}  # Dictionary[Vector2i, String]
var prospective_typologies: Dictionary = {}  # Dictionary[Vector2i, ZoneData.TileTypology]
var public_band_access_snapshot: PublicBandAccessSnapshot
var _manual_door_keys: Dictionary = {}


func _init(
	p_spatial_snapshot: DistrictZoneSpatialSnapshot,
	p_prospective_zone_ids: Dictionary = {},
	p_prospective_typologies: Dictionary = {},
	p_public_band_access_snapshot: PublicBandAccessSnapshot = null
) -> void:
	spatial_snapshot = p_spatial_snapshot
	prospective_zone_ids = p_prospective_zone_ids.duplicate()
	prospective_typologies = p_prospective_typologies.duplicate()
	public_band_access_snapshot = p_public_band_access_snapshot
	if spatial_snapshot != null:
		for edge: Dictionary in spatial_snapshot.get_manual_door_edges():
			_manual_door_keys[_manual_edge_key(edge)] = true


func is_valid_tile(tile_position: Vector2i) -> bool:
	return spatial_snapshot != null and spatial_snapshot.has_cell("valid_cells", tile_position)


func is_zone_eligible(tile_position: Vector2i) -> bool:
	return spatial_snapshot != null and spatial_snapshot.has_cell("zone_eligible_cells", tile_position)


func zone_id_at(tile_position: Vector2i) -> String:
	return String(prospective_zone_ids.get(tile_position, ""))


func typology_at(tile_position: Vector2i) -> int:
	return int(prospective_typologies.get(tile_position, ZoneData.TileTypology.TENANT))


func access_kind_for(access: Vector2i, candidate_zone: ZoneData, candidate_zone_tiles: Dictionary) -> String:
	if candidate_zone_tiles.has(access):
		return "internal_transit" if int(candidate_zone.typologies.get(access, ZoneData.TileTypology.TENANT)) == ZoneData.TileTypology.TRANSIT else ""
	if spatial_snapshot != null and spatial_snapshot.has_cell("explicit_circulation_cells", access) and zone_id_at(access).is_empty():
		return "external_circulation"
	if not public_band_edge_for(access, candidate_zone, candidate_zone_tiles).is_empty():
		return "public_band"
	return ""


func public_band_edge_for(access: Vector2i, candidate_zone: ZoneData, candidate_zone_tiles: Dictionary) -> Dictionary:
	if public_band_access_snapshot == null or candidate_zone == null:
		return {}
	var scope: Dictionary = spatial_snapshot.get_floor_scope() if spatial_snapshot != null else {}
	for edge: Dictionary in public_band_access_snapshot.access_edges:
		var endpoint: Dictionary = edge.get("parcel_endpoint", {})
		var cell: Dictionary = endpoint.get("local_cell", {})
		var tile := Vector2i(int(cell.get("x", -999999)), int(cell.get("y", -999999)))
		if not candidate_zone_tiles.has(tile) or access != tile + _direction_vector(String(edge.get("outward_direction", ""))):
			continue
		if String(endpoint.get("runtime_plot_id", "")) != candidate_zone.plot_id or String(endpoint.get("runtime_plot_id", "")) != String(scope.get("runtime_plot_id", "")) or int(endpoint.get("signed_elevation", -1)) != int(scope.get("signed_elevation", -2)):
			continue
		return edge.duplicate(true)
	return {}


func transit_area_key_for(access: Vector2i, candidate_zone: ZoneData, candidate_zone_tiles: Dictionary) -> String:
	if not candidate_zone_tiles.has(access) or candidate_zone == null or int(candidate_zone.typologies.get(access, ZoneData.TileTypology.TENANT)) != ZoneData.TileTypology.TRANSIT:
		return ""
	var pending: Array[Vector2i] = [access]
	var visited: Dictionary = {}
	var minimum := access
	while not pending.is_empty():
		var current: Vector2i = pending.pop_back()
		if visited.has(current) or not candidate_zone_tiles.has(current) or int(candidate_zone.typologies.get(current, ZoneData.TileTypology.TENANT)) != ZoneData.TileTypology.TRANSIT:
			continue
		visited[current] = true
		if current.y < minimum.y or (current.y == minimum.y and current.x < minimum.x):
			minimum = current
		for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			pending.append(current + direction)
	return "transit:%d,%d" % [minimum.x, minimum.y]


func has_manual_door_between(first: Vector2i, second: Vector2i) -> bool:
	if spatial_snapshot == null:
		return false
	var scope: Dictionary = spatial_snapshot.get_floor_scope()
	var first_endpoint: Dictionary = _endpoint(scope, first)
	var second_endpoint: Dictionary = _endpoint(scope, second)
	var edge: Dictionary = {"endpoint_a": first_endpoint, "endpoint_b": second_endpoint}
	if _endpoint_key(first_endpoint) > _endpoint_key(second_endpoint):
		edge = {"endpoint_a": second_endpoint, "endpoint_b": first_endpoint}
	return _manual_door_keys.has(_manual_edge_key(edge))


func _endpoint(scope: Dictionary, cell: Vector2i) -> Dictionary:
	return {"runtime_plot_id": String(scope.get("runtime_plot_id", "")), "signed_elevation": int(scope.get("signed_elevation", 0)), "local_cell": {"x": cell.x, "y": cell.y}}


func _manual_edge_key(edge: Dictionary) -> String:
	return "%s|%s" % [_endpoint_key(edge.get("endpoint_a", {})), _endpoint_key(edge.get("endpoint_b", {}))]


func _endpoint_key(endpoint: Dictionary) -> String:
	var cell: Dictionary = endpoint.get("local_cell", {})
	return "%s|%+011d|%011d|%011d" % [String(endpoint.get("runtime_plot_id", "")), int(endpoint.get("signed_elevation", 0)), int(cell.get("y", -1)), int(cell.get("x", -1))]


func _direction_vector(direction: String) -> Vector2i:
	match direction:
		"NORTH": return Vector2i.UP
		"EAST": return Vector2i.RIGHT
		"SOUTH": return Vector2i.DOWN
		"WEST": return Vector2i.LEFT
	return Vector2i.ZERO
