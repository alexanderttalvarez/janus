## ZoneTool — Handles mouse input for zone painting, editing, and preview.
class_name ZoneTool
extends Node


signal painting_state_changed(has_tiles: bool, transit_mode: bool)
signal preview_validation_changed(can_finish: bool, status: int)


const ZONE_COLORS: Dictionary = {
	"Retail": Color(0.5, 0.2, 0.8, 1.0),          # Purple
	"Food & Beverage": Color(0.2, 0.7, 0.3, 1.0),  # Green
	"Entertainment": Color(0.9, 0.5, 0.1, 1.0),    # Orange
	"Services": Color(0.2, 0.4, 0.9, 1.0),         # Blue
	"Anchor": Color(0.9, 0.2, 0.2, 1.0),           # Red
}

## Alpha for the hover preview — the tile currently under the cursor.
## Strongest, so it stands out from painted tiles.
const HOVER_ALPHA: float = 0.8
## Alpha for painted-but-unfinished zone tiles.
const PAINTED_ALPHA: float = 0.4
## Alpha for the rectangle shown while the left mouse button is held.
const DRAG_PREVIEW_ALPHA: float = 0.55

## World Y for all tile visuals. Must sit clearly above the GridOverlay plane
## (floor.tscn places it at y=0.1) or the meshes are hidden/z-fight with it.
const TILE_VISUAL_OFFSET: float = 0.15
const INVALID_PERIMETER_Y: float = 0.22
const INVALID_PERIMETER_THICKNESS: float = 0.05
const INVALID_PERIMETER_HEIGHT: float = 0.025
const INVALID_PERIMETER_COLOR := Color(1.0, 0.08, 0.08, 0.95)

var active_zone_type: String = ZoneData.ZONE_TYPE_NAMES[0]
var is_active: bool = false
var _painted_tiles: Array[Vector2i] = []
var _painted_typologies: Dictionary = {}
var _editing_zone_id: String = ""
var _typo_mode: int = ZoneData.TileTypology.TENANT
var _preview_mesh: MeshInstance3D
var _painting: bool = false
var _paint_start_tile: Vector2i = Vector2i.ZERO
var _remove_mode: bool = false
var _none_mode: bool = false
## Node3D container for all tool visuals. MeshInstance3D children of a plain
## Node never reach the RenderingServer, so every mesh lives under this root.
var _visual_root: Node3D
## Temporary rectangle preview shown during a left-button drag.
var _drag_preview_root: Node3D
## Painted tile position -> its visual mesh (visible during painting).
var _painted_meshes: Dictionary = {}
## Most recent non-mutating split validation of the pending zone data.
var preview_split_result: SplitResult
## True only when the pending zone passes the pure split contract.
var can_finish: bool = false
## Red perimeter feedback for invalid pending geometry.
var _invalid_perimeter_root: Node3D
var _projection_coordinator: ProjectionCoordinator
var _active_floor_address: Dictionary = {}
var _source_plot_id: String = ""
var _source_floor_label: String = ""


func configure_projection(
	coordinator: ProjectionCoordinator,
	floor_address: Dictionary,
	source_plot_id: String,
	source_floor_label: String
) -> void:
	_projection_coordinator = coordinator
	_active_floor_address = floor_address.duplicate(true)
	_source_plot_id = source_plot_id
	_source_floor_label = source_floor_label


func _ready() -> void:
	# Zone painting remains available while simulation time is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)
	_invalid_perimeter_root = Node3D.new()
	_invalid_perimeter_root.name = "InvalidPerimeter"
	_visual_root.add_child(_invalid_perimeter_root)
	_drag_preview_root = Node3D.new()
	_drag_preview_root.name = "DragPreview"
	_visual_root.add_child(_drag_preview_root)
	_create_preview_mesh()
	# Hover updates run in _process; painting uses _unhandled_input so UI clicks
	# (toolbar buttons) are consumed by the UI and never reach the tool.
	set_process_unhandled_input(true)


## Validate the pending ZoneTool state without committing any zone or grid mutation.
func _update_preview_validation() -> void:
	var previous_can_finish := can_finish
	var previous_status := _preview_status()
	if _painted_tiles.is_empty():
		preview_split_result = null
		can_finish = false
		_clear_invalid_perimeter()
	else:
		var pending_tiles: Array[Vector2i] = _combined_pending_tiles()
		var runtime := _get_district_runtime()
		var intent: Dictionary = _make_district_paint_intent()
		if runtime != null and not intent.is_empty():
			var preview: Dictionary = runtime.preview_transaction(intent)
			preview_split_result = preview.get("zone_preview", null) as SplitResult
			if preview_split_result == null:
				preview_split_result = SplitResult.failure(
					SplitResult.Status.INVALID_ZONE_GEOMETRY,
					"DISTRICT_ZONE_PREVIEW_REJECTED"
				)
		else:
			var zone_manager := _get_zone_manager()
			if zone_manager == null:
				preview_split_result = SplitResult.failure(
					SplitResult.Status.INVALID_ZONE_GEOMETRY,
					"ZONE_MANAGER_UNAVAILABLE"
				)
			else:
				preview_split_result = zone_manager.preview_split(
					_preview_zone_type(),
					pending_tiles,
					_preview_floor(),
					_preview_plot_id(),
					_combined_pending_typologies(),
					_editing_zone_id
				)
		can_finish = preview_split_result != null and preview_split_result.is_success()
		if can_finish:
			_clear_invalid_perimeter()
		else:
			_show_invalid_perimeter(pending_tiles)
	if previous_can_finish != can_finish or previous_status != _preview_status():
		preview_validation_changed.emit(can_finish, _preview_status())


func _preview_status() -> int:
	if preview_split_result == null:
		return SplitResult.Status.INVALID_ZONE_GEOMETRY
	return preview_split_result.status


func _editing_zone() -> ZoneData:
	if _editing_zone_id.is_empty():
		return null
	var zone_manager := _get_zone_manager()
	if zone_manager == null:
		return null
	return zone_manager.zones.get(_editing_zone_id, null) as ZoneData


func _combined_pending_tiles() -> Array[Vector2i]:
	var combined: Array[Vector2i] = []
	var existing := _editing_zone()
	if existing != null:
		combined = existing.tiles.duplicate()
	for tile_pos in _painted_tiles:
		if not combined.has(tile_pos):
			combined.append(tile_pos)
	return combined


func _combined_pending_typologies() -> Dictionary:
	var combined: Dictionary = {}
	var existing := _editing_zone()
	if existing != null:
		combined = existing.typologies.duplicate()
	for tile_pos in _painted_tiles:
		combined[tile_pos] = _painted_typologies.get(tile_pos, ZoneData.TileTypology.TENANT)
	return combined


func _preview_zone_type() -> String:
	var existing := _editing_zone()
	if existing != null:
		return existing.type
	if _none_mode:
		var zone_manager := _get_zone_manager()
		if zone_manager != null:
			for tile_pos: Vector2i in _painted_tiles:
				var zone := zone_manager.get_zone_at_tile(tile_pos, _preview_floor(), _preview_plot_id())
				if zone != null:
					return zone.type
	return active_zone_type


func _preview_floor() -> String:
	var existing := _editing_zone()
	if existing != null:
		return existing.floor
	return _source_floor_label


func _preview_plot_id() -> String:
	var existing := _editing_zone()
	if existing != null:
		return existing.plot_id
	return _source_plot_id


func _show_invalid_perimeter(tiles: Array[Vector2i]) -> void:
	_clear_invalid_perimeter()
	if tiles.is_empty() or _invalid_perimeter_root == null:
		return
	var tile_set: Dictionary = {}
	for tile_pos in tiles:
		tile_set[tile_pos] = true
	var tile_size := _get_projected_tile_size()
	if tile_size <= 0.0:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = INVALID_PERIMETER_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var horizontal_mesh := BoxMesh.new()
	horizontal_mesh.size = Vector3(tile_size + INVALID_PERIMETER_THICKNESS, INVALID_PERIMETER_HEIGHT, INVALID_PERIMETER_THICKNESS)
	var vertical_mesh := BoxMesh.new()
	vertical_mesh.size = Vector3(INVALID_PERIMETER_THICKNESS, INVALID_PERIMETER_HEIGHT, tile_size + INVALID_PERIMETER_THICKNESS)
	for tile_pos in tiles:
		if not tile_set.has(tile_pos + Vector2i.UP):
			_add_invalid_perimeter_segment(horizontal_mesh, material, tile_pos, Vector3(0.0, 0.0, -0.5))
		if not tile_set.has(tile_pos + Vector2i.DOWN):
			_add_invalid_perimeter_segment(horizontal_mesh, material, tile_pos, Vector3(0.0, 0.0, 0.5))
		if not tile_set.has(tile_pos + Vector2i.LEFT):
			_add_invalid_perimeter_segment(vertical_mesh, material, tile_pos, Vector3(-0.5, 0.0, 0.0))
		if not tile_set.has(tile_pos + Vector2i.RIGHT):
			_add_invalid_perimeter_segment(vertical_mesh, material, tile_pos, Vector3(0.5, 0.0, 0.0))


func _add_invalid_perimeter_segment(mesh: BoxMesh, material: StandardMaterial3D, tile_pos: Vector2i, offset: Vector3) -> void:
	var segment := MeshInstance3D.new()
	segment.mesh = mesh
	segment.material_override = material
	var projected_position := _project_grid_coordinate(Vector2(tile_pos) + Vector2(0.5, 0.5) + Vector2(offset.x, offset.z))
	if projected_position == Vector3.INF:
		segment.free()
		return
	segment.global_position = projected_position + Vector3(0.0, INVALID_PERIMETER_Y, 0.0)
	var floor := _get_projected_floor()
	if floor != null:
		segment.global_rotation.y = floor.global_rotation.y
	_invalid_perimeter_root.add_child(segment)


func _clear_invalid_perimeter() -> void:
	if _invalid_perimeter_root == null:
		return
	for child in _invalid_perimeter_root.get_children():
		child.queue_free()


func _create_preview_mesh() -> void:
	_preview_mesh = MeshInstance3D.new()
	_preview_mesh.name = "ZonePreview"
	_preview_mesh.visible = false
	var box := BoxMesh.new()
	box.size = Vector3(0.98, 0.06, 0.98)
	_preview_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.5, 0.2, 0.8, HOVER_ALPHA)
	_preview_mesh.material_override = mat
	_visual_root.add_child(_preview_mesh)


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var start_tile := _get_tile_under_mouse()
				var can_start := _painted_tiles.has(start_tile) if _remove_mode else _can_paint_tile_for_rectangle(start_tile)
				if can_start:
					_painting = true
					_paint_start_tile = start_tile
					_update_drag_preview(start_tile)
			else:
				if _painting:
					var end_tile := _get_tile_under_mouse()
					_painting = false
					_clear_drag_preview()
					if _remove_mode:
						_remove_rectangle(_paint_start_tile, end_tile)
					else:
						_paint_rectangle(_paint_start_tile, end_tile)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_erase_at_mouse()

	if event is InputEventMouseMotion:
		if _painting:
			_update_drag_preview(_get_tile_under_mouse())
		else:
			_update_hover()


func _process(_delta: float) -> void:
	if not is_active:
		_preview_mesh.visible = false
		_clear_drag_preview()
		return
	if not _painting:
		_update_hover()


func _update_drag_preview(end_tile: Vector2i) -> void:
	_clear_drag_preview()
	if _drag_preview_root == null:
		return
	for tile_pos: Vector2i in rectangle_tiles(_paint_start_tile, end_tile):
		if _remove_mode:
			if not _painted_tiles.has(tile_pos):
				continue
		else:
			if not _can_paint_tile_for_rectangle(tile_pos):
				continue
		var mesh := _make_tile_mesh(DRAG_PREVIEW_ALPHA)
		var projected_position := _project_cell_center(tile_pos)
		if projected_position == Vector3.INF:
			continue
		mesh.global_position = projected_position + Vector3(0.0, TILE_VISUAL_OFFSET + 0.01, 0.0)
		_drag_preview_root.add_child(mesh)


func _clear_drag_preview() -> void:
	if _drag_preview_root == null:
		return
	for child: Node in _drag_preview_root.get_children():
		child.free()


func _remove_rectangle(start_tile: Vector2i, end_tile: Vector2i) -> void:
	var removed := false
	for tile_pos: Vector2i in rectangle_tiles(start_tile, end_tile):
		if not _painted_tiles.has(tile_pos):
			continue
		_painted_tiles.erase(tile_pos)
		_painted_typologies.erase(tile_pos)
		_hide_painted_tile(tile_pos)
		removed = true
	if removed:
		painting_state_changed.emit(not _painted_tiles.is_empty(), is_transit_mode())
		_update_preview_validation()


func _paint_at_mouse() -> void:
	var tile_pos := _get_tile_under_mouse()
	_paint_rectangle(tile_pos, tile_pos)


func _paint_rectangle(start_tile: Vector2i, end_tile: Vector2i) -> void:
	if not _remove_mode and not _none_mode:
		for tile_pos: Vector2i in rectangle_tiles(start_tile, end_tile):
			if not _can_paint_tile_for_rectangle(tile_pos):
				_update_preview_validation()
				return
	var added_tiles := false
	var changed := false
	for tile_pos: Vector2i in rectangle_tiles(start_tile, end_tile):
		if not _can_paint_tile_for_rectangle(tile_pos):
			continue
		if not _painted_tiles.has(tile_pos):
			_painted_tiles.append(tile_pos)
			added_tiles = true
		if _painted_typologies.get(tile_pos, -1) != _typo_mode:
			changed = true
		_painted_typologies[tile_pos] = _typo_mode
		if _painted_meshes.has(tile_pos):
			_refresh_painted_tile(tile_pos)
		else:
			_show_painted_tile(tile_pos)
	if added_tiles:
		painting_state_changed.emit(not _painted_tiles.is_empty(), is_transit_mode())
	if changed:
		# Repainting an existing pending tile changes the split contract even
		# though the painted tile count is unchanged.
		_update_preview_validation()


static func rectangle_tiles(start_tile: Vector2i, end_tile: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var min_x := mini(start_tile.x, end_tile.x)
	var max_x := maxi(start_tile.x, end_tile.x)
	var min_y := mini(start_tile.y, end_tile.y)
	var max_y := maxi(start_tile.y, end_tile.y)
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			result.append(Vector2i(x, y))
	return result


func _can_paint_tile_for_rectangle(tile_pos: Vector2i) -> bool:
	if tile_pos.x < 0 or tile_pos.y < 0:
		return false
	var zm := _get_zone_manager()
	if zm == null:
		return false
	return zm.can_paint_tile_for_tool(
		tile_pos,
		_preview_floor(),
		_preview_plot_id(),
		_preview_zone_type(),
		_none_mode
	)


func _erase_at_mouse() -> void:
	var tile_pos := _get_tile_under_mouse()
	if _painted_tiles.has(tile_pos):
		_painted_tiles.erase(tile_pos)
		_painted_typologies.erase(tile_pos)
		_hide_painted_tile(tile_pos)
		painting_state_changed.emit(not _painted_tiles.is_empty(), is_transit_mode())
		_update_preview_validation()


func _can_paint(tile_pos: Vector2i) -> bool:
	if tile_pos.x < 0 or tile_pos.y < 0:
		return false
	if _remove_mode:
		return _painted_tiles.has(tile_pos)
	return _can_paint_tile_for_rectangle(tile_pos)


func _update_hover() -> void:
	if not is_active:
		_preview_mesh.visible = false
		return
	var tile_pos := _get_tile_under_mouse()
	if _can_paint(tile_pos):
		var projected_position := _project_cell_center(tile_pos)
		if projected_position == Vector3.INF:
			_preview_mesh.visible = false
			return
		_preview_mesh.visible = true
		_preview_mesh.global_position = projected_position + Vector3(0.0, TILE_VISUAL_OFFSET, 0.0)
		var color := _get_typology_color(_typo_mode)
		color.a = HOVER_ALPHA
		(_preview_mesh.material_override as StandardMaterial3D).albedo_color = color
	else:
		_preview_mesh.visible = false


## Create a tile-sized visual mesh in the current zone color at the given alpha.
func _make_tile_mesh(alpha: float) -> MeshInstance3D:
	var tile_size := _get_projected_tile_size()
	if tile_size <= 0.0:
		return MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(tile_size * 0.96, tile_size * 0.07, tile_size * 0.96)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var color := _get_typology_color(_typo_mode)
	color.a = alpha
	mat.albedo_color = color
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = mat
	return mesh


## Show the painted-but-unfinished tile visual (dimmer than the hover).
func _show_painted_tile(tile_pos: Vector2i) -> void:
	if _painted_meshes.has(tile_pos):
		_refresh_painted_tile(tile_pos)
		return
	var mesh := _make_tile_mesh(PAINTED_ALPHA)
	var projected_position := _project_cell_center(tile_pos)
	if projected_position == Vector3.INF:
		mesh.free()
		return
	mesh.global_position = projected_position + Vector3(0.0, TILE_VISUAL_OFFSET, 0.0)
	_visual_root.add_child(mesh)
	_painted_meshes[tile_pos] = mesh


func _refresh_painted_tile(tile_pos: Vector2i) -> void:
	var mesh := _painted_meshes.get(tile_pos) as MeshInstance3D
	if mesh == null:
		return
	var material := mesh.material_override as StandardMaterial3D
	if material:
		material.albedo_color = _get_typology_color(_painted_typologies.get(tile_pos, ZoneData.TileTypology.TENANT), PAINTED_ALPHA)


## Remove the painted-tile visual when erased.
func _hide_painted_tile(tile_pos: Vector2i) -> void:
	var mesh: Node = _painted_meshes.get(tile_pos, null)
	if mesh != null:
		mesh.free()
	_painted_meshes.erase(tile_pos)


## Commit only if the latest pure preview is valid. Invalid pending paint remains editable.
func finish() -> bool:
	_update_preview_validation()
	if not can_finish:
		return false
	var runtime := _get_district_runtime()
	var intent: Dictionary = _make_district_paint_intent()
	if runtime == null or intent.is_empty():
		return false
	var committed: Dictionary = runtime.commit_transaction(intent)
	if not bool(committed.get("valid", false)):
		_update_preview_validation()
		return false
	cancel()
	return true


## Cancel is the only operation that discards pending zone paint.
func cancel() -> void:
	var previous_can_finish := can_finish
	var previous_status := _preview_status()
	_painted_tiles.clear()
	_painted_typologies.clear()
	_editing_zone_id = ""
	_typo_mode = ZoneData.TileTypology.TENANT
	_remove_mode = false
	_none_mode = false
	preview_split_result = null
	can_finish = false
	_clear_invalid_perimeter()
	painting_state_changed.emit(false, false)
	if previous_can_finish or previous_status != _preview_status():
		preview_validation_changed.emit(false, _preview_status())
	_preview_mesh.visible = false
	_clear_drag_preview()
	for mesh: Node in _painted_meshes.values():
		mesh.free()
	_painted_meshes.clear()


func set_remove_mode(enabled: bool) -> void:
	_remove_mode = enabled
	if enabled:
		_none_mode = false
	if _painting:
		_painting = false
		_clear_drag_preview()
	_update_hover()


func is_remove_mode() -> bool:
	return _remove_mode


func set_none_mode(enabled: bool) -> void:
	_none_mode = enabled
	if enabled:
		_remove_mode = false
		_typo_mode = ZoneData.TileTypology.TENANT
	if _painting:
		_painting = false
		_clear_drag_preview()
	_update_hover()
	_update_preview_validation()


func is_none_mode() -> bool:
	return _none_mode


func set_transit_mode(enabled: bool) -> void:
	# Changing the toggle only changes the typology assigned to future paint
	# actions. Existing pending tiles change only when explicitly repainted.
	_typo_mode = ZoneData.TileTypology.TRANSIT if enabled else ZoneData.TileTypology.TENANT
	if enabled:
		_none_mode = false
		_remove_mode = false
	painting_state_changed.emit(not _painted_tiles.is_empty(), enabled)
	_update_preview_validation()


func is_transit_mode() -> bool:
	return _typo_mode == ZoneData.TileTypology.TRANSIT


func _get_typology_color(typology: int, alpha: float = 1.0) -> Color:
	var color := ZONE_COLORS.get(active_zone_type, Color.GRAY) as Color
	if typology == ZoneData.TileTypology.TRANSIT:
		color = color.lerp(Color.WHITE, 0.28)
	color.a = alpha
	return color


func _get_tile_under_mouse() -> Vector2i:
	var vp := get_viewport()
	if vp == null or _projection_coordinator == null or _active_floor_address.is_empty():
		return Vector2i(-1, -1)
	var cam := vp.get_camera_3d()
	if cam == null:
		return Vector2i(-1, -1)
	var pick: Dictionary = _projection_coordinator.pick_cell(
		_active_floor_address,
		cam.project_ray_origin(vp.get_mouse_position()),
		cam.project_ray_normal(vp.get_mouse_position())
	)
	if not bool(pick.get("valid", false)):
		return Vector2i(-1, -1)
	return pick.get("cell", Vector2i(-1, -1)) as Vector2i


func _make_district_paint_intent() -> Dictionary:
	var runtime := _get_district_runtime()
	if runtime == null or not runtime.has_session():
		return {}
	var runtime_plot_id: String = String(_active_floor_address.get("runtime_plot_id", ""))
	var floor_id: String = String(_active_floor_address.get("floor_id", ""))
	var elevation: int = int(_active_floor_address.get("elevation", 999))
	if runtime_plot_id.is_empty() or floor_id.is_empty() or elevation == 999:
		return {}
	var cells: Array = []
	for tile_pos: Vector2i in _combined_pending_tiles():
		cells.append([tile_pos.x, tile_pos.y])
	return {
		"operation": DistrictRuntime.OP_PAINT_ZONE,
		"expected_district_revision": runtime.get_revision(),
		"runtime_plot_id": runtime_plot_id,
		"floor_id": floor_id,
		"elevation": elevation,
		"zone_plot_id": _preview_plot_id(),
		"zone_floor_label": _preview_floor(),
		"zone_type": _preview_zone_type(),
		"cells": cells,
		"typologies": _combined_pending_typologies(),
		"paint_mode": "none" if _none_mode else "zone",
		"economy_value": 0,
	}


func _get_projected_floor() -> Floor:
	if _projection_coordinator == null or _active_floor_address.is_empty():
		return null
	return _projection_coordinator.get_projected_floor(_active_floor_address)


func _get_projected_tile_size() -> float:
	if _projection_coordinator == null or _active_floor_address.is_empty():
		return 0.0
	return _projection_coordinator.get_projected_tile_size(_active_floor_address)


func _project_grid_coordinate(grid_coordinate: Vector2) -> Vector3:
	if _projection_coordinator == null or _active_floor_address.is_empty():
		return Vector3.INF
	return _projection_coordinator.project_grid_coordinate(_active_floor_address, grid_coordinate)


func _project_cell_center(cell: Vector2i) -> Vector3:
	if _projection_coordinator == null or _active_floor_address.is_empty():
		return Vector3.INF
	return _projection_coordinator.project_cell_center(_active_floor_address, cell)


func _get_district_runtime() -> DistrictRuntime:
	var root := get_tree().current_scene
	if root:
		return root.get_node_or_null("DistrictRuntime") as DistrictRuntime
	return null


func _get_zone_manager() -> ZoneManager:
	var root: Node = get_tree().current_scene
	if root != null:
		var manager := root.get_node_or_null("World/ZoneManager") as ZoneManager
		if manager != null:
			return manager
	var sibling_manager := get_node_or_null("../World/ZoneManager") as ZoneManager
	if sibling_manager != null:
		return sibling_manager
	return get_tree().root.get_node_or_null("World/ZoneManager") as ZoneManager
