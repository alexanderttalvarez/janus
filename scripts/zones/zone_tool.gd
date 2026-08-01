## ZoneTool — Handles mouse input for zone painting, editing, and preview.
## Works with CameraManager for grid coordinate projection.
##
## Modes:
##   - Paint: LMB adds tiles, RMB removes, shift+LMB fills contiguous areas.
##   - Edit: Click a zone to enter edit mode, then paint/remove tiles.
##
## Coordinates with ZoneManager for CRUD and GridManager for validation.
class_name ZoneTool
extends Node


## Current zone type being painted.
var active_zone_type: String = ZoneData.ZONE_TYPE_NAMES[0]

## Whether the zone tool is active (in paint mode).
var is_active: bool = false

## Tiles painted in the current session (before finishing).
var _painted_tiles: Dictionary = {}  # Dictionary[Vector2i, bool] (true = tenant, false = unset)

## The zone being edited (in Edit Zone mode).
var _editing_zone_id: String = ""

## Current floor being painted on.
var _current_floor: String = "G"


# ── Input Handling ─────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not is_active and _editing_zone_id.is_empty():
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	var tile_pos := _get_tile_under_mouse()
	if not _is_valid_tile(tile_pos):
		return

	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_paint_tile(tile_pos)
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_erase_tile(tile_pos)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_preview(_get_tile_under_mouse())
		return

	var tile_pos := _get_tile_under_mouse()
	if _is_valid_tile(tile_pos):
		_paint_tile(tile_pos)


# ── Painting ───────────────────────────────────────────────────────────

func _paint_tile(tile_pos: Vector2i) -> void:
	var grid_manager := _get_grid_manager()
	if grid_manager == null:
		return

	var tile: GridTile = grid_manager.get_tile(tile_pos.x, tile_pos.y)
	if tile == null or not tile.owned or not tile.floor_built:
		return

	# Check if tile is already in another zone (in paint mode).
	if _editing_zone_id.is_empty():
		var zone_manager := _get_zone_manager()
		if zone_manager and zone_manager.is_tile_in_zone(tile_pos, _current_floor):
			return  # Can't paint on another zone.

	_painted_tiles[tile_pos] = true


func _erase_tile(tile_pos: Vector2i) -> void:
	_painted_tiles.erase(tile_pos)


# ── Finishing ──────────────────────────────────────────────────────────

## Finish the current paint/edit session and create/modify the zone.
func finish() -> void:
	var tiles: Array[Vector2i] = _painted_tiles.keys()
	if tiles.is_empty():
		_cancel()
		return

	var zone_manager := _get_zone_manager()
	if zone_manager == null:
		return

	if not _editing_zone_id.is_empty():
		# Modify existing zone.
		var existing := zone_manager.zones.get(_editing_zone_id, null)
		if existing:
			# Combine existing tiles with new painted tiles.
			var combined: Array[Vector2i] = existing.tiles.duplicate()
			for t: Vector2i in tiles:
				if not combined.has(t):
					combined.append(t)
			zone_manager.modify_zone(_editing_zone_id, combined)
			zone_manager.split_zone(_editing_zone_id)
	else:
		# Create new zone.
		var zone := zone_manager.create_zone(active_zone_type, tiles, _current_floor)
		if zone:
			zone_manager.split_zone(zone.id)

	_painted_tiles.clear()
	_editing_zone_id = ""


## Cancel the current paint/edit session.
func _cancel() -> void:
	_painted_tiles.clear()
	_editing_zone_id = ""


# ── Edit Mode ──────────────────────────────────────────────────────────

## Enter edit mode for an existing zone.
func enter_edit_mode(zone_id: String) -> void:
	var zone_manager := _get_zone_manager()
	if zone_manager == null:
		return
	var zone: ZoneData = zone_manager.zones.get(zone_id, null)
	if zone == null:
		return

	_editing_zone_id = zone_id
	_painted_tiles.clear()
	for tile_pos: Vector2i in zone.tiles:
		_painted_tiles[tile_pos] = true
	is_active = true


# ── Preview ────────────────────────────────────────────────────────────

func _update_preview(tile_pos: Vector2i) -> void:
	# TODO: Update shader hover preview.
	# In full implementation: set a hover_uniform on the zone overlay shader.
	pass


# ── Grid Interaction ───────────────────────────────────────────────────

## Get the tile position under the mouse cursor in the 3D world.
func _get_tile_under_mouse() -> Vector2i:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2i.ZERO

	var camera := viewport.get_camera_3d()
	if camera == null:
		return Vector2i.ZERO

	var mouse_pos := viewport.get_mouse_position()
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)

	# Intersect with the XZ plane at current floor height.
	# Plane equation: Y = floor_height * FLOOR_HEIGHT
	var floor_y: float = 0.0
	if _current_floor != "G":
		var prefix := _current_floor[0]
		var num := _current_floor.substr(1).to_int()
		floor_y = float(num * 3)
		if prefix == "B":
			floor_y = -floor_y

	# Ray-plane intersection.
	if abs(direction.y) < 0.0001:
		return Vector2i.ZERO

	var t: float = (floor_y - origin.y) / direction.y
	if t < 0:
		return Vector2i.ZERO

	var hit := origin + direction * t
	var grid_manager := _get_grid_manager()
	if grid_manager:
		return grid_manager.world_to_grid(hit)

	return Vector2i(int(hit.x / 2.0), int(hit.z / 2.0))


func _is_valid_tile(tile_pos: Vector2i) -> bool:
	var grid_manager := _get_grid_manager()
	if grid_manager == null:
		return false
	return grid_manager.get_tile(tile_pos.x, tile_pos.y) != null


# ── Helpers ────────────────────────────────────────────────────────────

func _get_grid_manager() -> GridManager:
	var root := get_tree().current_scene
	if root == null:
		return null
	var world := root.get_node_or_null("World")
	if world == null:
		return null
	return world.get_node_or_null("GridManager") as GridManager


func _get_zone_manager() -> ZoneManager:
	var root := get_tree().current_scene
	if root == null:
		return null
	var world := root.get_node_or_null("World")
	if world == null:
		return null
	return world.get_node_or_null("ZoneManager") as ZoneManager
