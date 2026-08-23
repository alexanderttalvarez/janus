## FloorAccessContext — Immutable prospective occupancy view used by ZoneSplitter.
class_name FloorAccessContext
extends RefCounted


var floor_grid: FloorGrid
var plot: PlotData
var prospective_zone_ids: Dictionary = {}  # Dictionary[Vector2i, String]


func _init(
	p_floor_grid: FloorGrid,
	p_plot: PlotData,
	p_prospective_zone_ids: Dictionary = {}
) -> void:
	floor_grid = p_floor_grid
	plot = p_plot
	prospective_zone_ids = p_prospective_zone_ids.duplicate()


func is_valid_tile(tile_position: Vector2i) -> bool:
	return floor_grid != null and floor_grid.is_valid_tile(tile_position.x, tile_position.y)


func zone_id_at(tile_position: Vector2i) -> String:
	if prospective_zone_ids.has(tile_position):
		return prospective_zone_ids[tile_position]
	if not is_valid_tile(tile_position):
		return ""
	var tile := floor_grid.get_tile(tile_position.x, tile_position.y)
	return tile.zone_id if tile != null else ""


func access_kind_for(
	access: Vector2i,
	candidate_zone: ZoneData,
	candidate_zone_tiles: Dictionary
) -> String:
	if candidate_zone_tiles.has(access):
		if candidate_zone.typologies.get(access, GridTile.TileTypology.TENANT) == GridTile.TileTypology.TRANSIT:
			return "internal_transit"
		return ""

	if is_valid_tile(access):
		var tile := floor_grid.get_tile(access.x, access.y)
		if tile == null or not tile.owned or not tile.floor_built or not zone_id_at(access).is_empty():
			return ""
		if tile.element == GridTile.TileElement.CIRCULATION:
			return "external_circulation"
		if tile.element == GridTile.TileElement.NONE:
			return "implicit_unzoned_circulation"
		return ""

	if plot == null or plot.boundary.has_point(access):
		return ""
	if plot.pedestrian_boundary.has_point(access):
		return "virtual_exterior"
	return ""
