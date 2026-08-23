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

## World Y for all tile visuals. Must sit clearly above the GridOverlay plane
## (floor.tscn places it at y=0.1) or the meshes are hidden/z-fight with it.
const TILE_VISUAL_Y: float = 0.15
const TILE_SIZE: float = 1.0
const INVALID_PERIMETER_Y: float = 0.22
const INVALID_PERIMETER_THICKNESS: float = 0.05
const INVALID_PERIMETER_HEIGHT: float = 0.025
const INVALID_PERIMETER_COLOR := Color(1.0, 0.08, 0.08, 0.95)

var active_zone_type: String = ZoneData.ZONE_TYPE_NAMES[0]
var is_active: bool = false
var _painted_tiles: Array[Vector2i] = []
var _painted_typologies: Dictionary = {}
var _editing_zone_id: String = ""
var _typo_mode: GridTile.TileTypology = GridTile.TileTypology.TENANT
var _preview_mesh: MeshInstance3D
var _painting: bool = false
## Node3D container for all tool visuals. MeshInstance3D children of a plain
## Node never reach the RenderingServer, so every mesh lives under this root.
var _visual_root: Node3D
## Painted tile position -> its visual mesh (visible during painting).
var _painted_meshes: Dictionary = {}
## Most recent non-mutating split validation of the pending zone data.
var preview_split_result: SplitResult
## True only when the pending zone passes the pure split contract.
var can_finish: bool = false
## Red perimeter feedback for invalid pending geometry.
var _invalid_perimeter_root: Node3D


func _ready() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)
	_invalid_perimeter_root = Node3D.new()
	_invalid_perimeter_root.name = "InvalidPerimeter"
	_visual_root.add_child(_invalid_perimeter_root)
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
		var zone_manager := _get_zone_manager()
		var pending_tiles := _combined_pending_tiles()
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
				_combined_pending_typologies()
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
		combined[tile_pos] = _painted_typologies.get(tile_pos, GridTile.TileTypology.TENANT)
	return combined


func _preview_zone_type() -> String:
	var existing := _editing_zone()
	return existing.type if existing != null else active_zone_type


func _preview_floor() -> String:
	var existing := _editing_zone()
	return existing.floor if existing != null else "G"


func _preview_plot_id() -> String:
	var existing := _editing_zone()
	return existing.plot_id if existing != null else GridManager.DEFAULT_PLOT


func _show_invalid_perimeter(tiles: Array[Vector2i]) -> void:
	_clear_invalid_perimeter()
	if tiles.is_empty() or _invalid_perimeter_root == null:
		return
	var tile_set: Dictionary = {}
	for tile_pos in tiles:
		tile_set[tile_pos] = true
	var material := StandardMaterial3D.new()
	material.albedo_color = INVALID_PERIMETER_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var horizontal_mesh := BoxMesh.new()
	horizontal_mesh.size = Vector3(TILE_SIZE + INVALID_PERIMETER_THICKNESS, INVALID_PERIMETER_HEIGHT, INVALID_PERIMETER_THICKNESS)
	var vertical_mesh := BoxMesh.new()
	vertical_mesh.size = Vector3(INVALID_PERIMETER_THICKNESS, INVALID_PERIMETER_HEIGHT, TILE_SIZE + INVALID_PERIMETER_THICKNESS)
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
	segment.position = Vector3(float(tile_pos.x) + 0.5, INVALID_PERIMETER_Y, float(tile_pos.y) + 0.5) + offset
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
				_painting = true
				_paint_at_mouse()
			else:
				_painting = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_erase_at_mouse()

	if event is InputEventMouseMotion:
		if _painting:
			_paint_at_mouse()
		else:
			_update_hover()


func _process(_delta: float) -> void:
	if not is_active:
		_preview_mesh.visible = false
		return
	_update_hover()


func _paint_at_mouse() -> void:
	var tile_pos := _get_tile_under_mouse()
	if not _can_paint(tile_pos):
		return
	if not _painted_tiles.has(tile_pos):
		_painted_tiles.append(tile_pos)
		_painted_typologies[tile_pos] = _typo_mode
		_show_painted_tile(tile_pos)
		painting_state_changed.emit(true, is_transit_mode())
		_update_preview_validation()
	else:
		# Repainting an existing pending tile intentionally overrides its
		# typology, allowing tenant/transit correction before finishing.
		_painted_typologies[tile_pos] = _typo_mode
		_refresh_painted_tile(tile_pos)
		_update_preview_validation()


func _erase_at_mouse() -> void:
	var tile_pos := _get_tile_under_mouse()
	if _painted_tiles.has(tile_pos):
		_painted_tiles.erase(tile_pos)
		_painted_typologies.erase(tile_pos)
		_hide_painted_tile(tile_pos)
		painting_state_changed.emit(not _painted_tiles.is_empty(), is_transit_mode())
		_update_preview_validation()


func _can_paint(tile_pos: Vector2i) -> bool:
	var gm := _get_grid_manager()
	if gm == null:
		return false
	var tile: GridTile = gm.get_tile(tile_pos.x, tile_pos.y)
	if tile == null or not tile.owned:
		return false
	# Can't paint on occupied tiles (other zones).
	var zm := _get_zone_manager()
	if zm and zm.is_tile_in_zone(tile_pos):
		return false
	# Adjacency: first tile always ok, subsequent must be adjacent.
	if _painted_tiles.is_empty():
		return true
	for existing: Vector2i in _painted_tiles:
		if absi(tile_pos.x - existing.x) + absi(tile_pos.y - existing.y) == 1:
			return true
	return false


func _update_hover() -> void:
	if not is_active:
		_preview_mesh.visible = false
		return
	var tile_pos := _get_tile_under_mouse()
	if _can_paint(tile_pos):
		_preview_mesh.visible = true
		_preview_mesh.position = Vector3(float(tile_pos.x) + 0.5, TILE_VISUAL_Y, float(tile_pos.y) + 0.5)
		var color := _get_typology_color(_typo_mode)
		color.a = HOVER_ALPHA
		(_preview_mesh.material_override as StandardMaterial3D).albedo_color = color
	else:
		_preview_mesh.visible = false


## Create a tile-sized visual mesh in the current zone color at the given alpha.
func _make_tile_mesh(alpha: float) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(0.96, 0.07, 0.96)
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
	mesh.position = Vector3(float(tile_pos.x) + 0.5, TILE_VISUAL_Y, float(tile_pos.y) + 0.5)
	_visual_root.add_child(mesh)
	_painted_meshes[tile_pos] = mesh


func _refresh_painted_tile(tile_pos: Vector2i) -> void:
	var mesh := _painted_meshes.get(tile_pos) as MeshInstance3D
	if mesh == null:
		return
	var material := mesh.material_override as StandardMaterial3D
	if material:
		material.albedo_color = _get_typology_color(_painted_typologies.get(tile_pos, GridTile.TileTypology.TENANT), PAINTED_ALPHA)


## Remove the painted-tile visual when erased.
func _hide_painted_tile(tile_pos: Vector2i) -> void:
	var mesh: Node = _painted_meshes.get(tile_pos, null)
	if mesh != null:
		mesh.queue_free()
	_painted_meshes.erase(tile_pos)


## Commit only if the latest pure preview is valid. Invalid pending paint remains editable.
func finish() -> bool:
	_update_preview_validation()
	if not can_finish:
		return false
	var zone_manager := _get_zone_manager()
	if zone_manager == null:
		return false
	var committed_zone: ZoneData = null
	var existing := _editing_zone()
	if existing != null:
		committed_zone = zone_manager.modify_zone(
			existing.id,
			_combined_pending_tiles(),
			existing.plot_id,
			_combined_pending_typologies()
		)
	else:
		committed_zone = zone_manager.create_zone(
			active_zone_type,
			_painted_tiles,
			"G",
			GridManager.DEFAULT_PLOT,
			_painted_typologies
		)
	if committed_zone == null:
		_update_preview_validation()
		return false
	if existing == null:
		_show_zone_tiles(committed_zone)
	cancel()
	return true


## Cancel is the only operation that discards pending zone paint.
func cancel() -> void:
	var previous_can_finish := can_finish
	var previous_status := _preview_status()
	_painted_tiles.clear()
	_painted_typologies.clear()
	_editing_zone_id = ""
	_typo_mode = GridTile.TileTypology.TENANT
	preview_split_result = null
	can_finish = false
	_clear_invalid_perimeter()
	painting_state_changed.emit(false, false)
	if previous_can_finish or previous_status != _preview_status():
		preview_validation_changed.emit(false, _preview_status())
	_preview_mesh.visible = false
	for mesh: Node in _painted_meshes.values():
		mesh.queue_free()
	_painted_meshes.clear()


func _show_zone_tiles(zone: ZoneData) -> void:
	var color := ZONE_COLORS.get(zone.type, Color.GRAY) as Color
	color.a = 0.4
	var root := get_tree().current_scene
	var floor_name := "floor_plot_0_G"
	var world: Node3D = root.get_node_or_null("World") as Node3D
	if world == null:
		return
	var floor := world.get_node_or_null(floor_name)
	if floor == null:
		return
	var zone_container := floor.get_node_or_null("ZoneContainer") as Node3D
	if zone_container == null:
		return

	var box := BoxMesh.new()
	box.size = Vector3(0.96, 0.07, 0.96)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color

	for tile_pos: Vector2i in zone.tiles:
		var mesh := MeshInstance3D.new()
		mesh.mesh = box
		var tile_color := _get_typology_color(zone.typologies.get(tile_pos, GridTile.TileTypology.TENANT), 0.4)
		var tile_material := mat.duplicate() as StandardMaterial3D
		tile_material.albedo_color = tile_color
		mesh.material_override = tile_material
		mesh.position = Vector3(float(tile_pos.x) + 0.5, TILE_VISUAL_Y, float(tile_pos.y) + 0.5)
		mesh.name = "zone_%s_tile_%d_%d" % [zone.id, tile_pos.x, tile_pos.y]
		zone_container.add_child(mesh)


func set_transit_mode(enabled: bool) -> void:
	# Changing the toggle only changes the typology assigned to future paint
	# actions. Existing pending tiles change only when explicitly repainted.
	_typo_mode = GridTile.TileTypology.TRANSIT if enabled else GridTile.TileTypology.TENANT
	painting_state_changed.emit(not _painted_tiles.is_empty(), enabled)
	_update_preview_validation()


func is_transit_mode() -> bool:
	return _typo_mode == GridTile.TileTypology.TRANSIT


func _get_typology_color(typology: GridTile.TileTypology, alpha: float = 1.0) -> Color:
	var color := ZONE_COLORS.get(active_zone_type, Color.GRAY) as Color
	if typology == GridTile.TileTypology.TRANSIT:
		color = color.lerp(Color.WHITE, 0.28)
	color.a = alpha
	return color


func _get_tile_under_mouse() -> Vector2i:
	var vp := get_viewport()
	if vp == null:
		return Vector2i.ZERO
	var cam := vp.get_camera_3d()
	if cam == null:
		return Vector2i.ZERO
	var origin := cam.project_ray_origin(vp.get_mouse_position())
	var dir := cam.project_ray_normal(vp.get_mouse_position())
	if abs(dir.y) < 0.001:
		return Vector2i.ZERO
	var t := (0.0 - origin.y) / dir.y
	var hit := origin + dir * t
	var gm := _get_grid_manager()
	if gm:
		return gm.world_to_grid(hit)
	return Vector2i.ZERO


func _get_grid_manager() -> GridManager:
	var root := get_tree().current_scene
	if root: return root.get_node_or_null("World/GridManager") as GridManager
	return null

func _get_zone_manager() -> ZoneManager:
	var root := get_tree().current_scene
	if root: return root.get_node_or_null("World/ZoneManager") as ZoneManager
	return null
