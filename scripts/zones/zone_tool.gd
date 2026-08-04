## ZoneTool — Handles mouse input for zone painting, editing, and preview.
class_name ZoneTool
extends Node


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

var active_zone_type: String = ZoneData.ZONE_TYPE_NAMES[0]
var is_active: bool = false
var _painted_tiles: Array[Vector2i] = []
var _editing_zone_id: String = ""
var _typo_mode: GridTile.TileTypology = GridTile.TileTypology.TENANT
var _preview_mesh: MeshInstance3D
var _painting: bool = false
## Node3D container for all tool visuals. MeshInstance3D children of a plain
## Node never reach the RenderingServer, so every mesh lives under this root.
var _visual_root: Node3D
## Painted tile position -> its visual mesh (visible during painting).
var _painted_meshes: Dictionary = {}


func _ready() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)
	_create_preview_mesh()
	# Hover updates run in _process; painting uses _unhandled_input so UI clicks
	# (toolbar buttons) are consumed by the UI and never reach the tool.
	set_process_unhandled_input(true)


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
		_show_painted_tile(tile_pos)


func _erase_at_mouse() -> void:
	var tile_pos := _get_tile_under_mouse()
	if _painted_tiles.has(tile_pos):
		_painted_tiles.erase(tile_pos)
		_hide_painted_tile(tile_pos)


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
		var color := ZONE_COLORS.get(active_zone_type, Color.GRAY) as Color
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
	var color := ZONE_COLORS.get(active_zone_type, Color.GRAY) as Color
	color.a = alpha
	mat.albedo_color = color
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = mat
	return mesh


## Show the painted-but-unfinished tile visual (dimmer than the hover).
func _show_painted_tile(tile_pos: Vector2i) -> void:
	if _painted_meshes.has(tile_pos):
		return
	var mesh := _make_tile_mesh(PAINTED_ALPHA)
	mesh.position = Vector3(float(tile_pos.x) + 0.5, TILE_VISUAL_Y, float(tile_pos.y) + 0.5)
	_visual_root.add_child(mesh)
	_painted_meshes[tile_pos] = mesh


## Remove the painted-tile visual when erased.
func _hide_painted_tile(tile_pos: Vector2i) -> void:
	var mesh: Node = _painted_meshes.get(tile_pos, null)
	if mesh != null:
		mesh.queue_free()
	_painted_meshes.erase(tile_pos)


func finish() -> void:
	if _painted_tiles.is_empty():
		cancel()
		return
	var zm := _get_zone_manager()
	if zm == null:
		return
	if not _editing_zone_id.is_empty():
		var existing: Variant = zm.zones.get(_editing_zone_id, null)
		if existing:
			var combined: Array[Vector2i] = existing.tiles.duplicate()
			for t: Vector2i in _painted_tiles:
				if not combined.has(t):
					combined.append(t)
			zm.modify_zone(_editing_zone_id, combined)
			zm.split_zone(_editing_zone_id)
	else:
		var zone := zm.create_zone(active_zone_type, _painted_tiles, "G")
		if zone:
			zm.split_zone(zone.id)
			_show_zone_tiles(zone)
	cancel()


func cancel() -> void:
	_painted_tiles.clear()
	_editing_zone_id = ""
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
		mesh.material_override = mat
		mesh.position = Vector3(float(tile_pos.x) + 0.5, TILE_VISUAL_Y, float(tile_pos.y) + 0.5)
		mesh.name = "zone_%s_tile_%d_%d" % [zone.id, tile_pos.x, tile_pos.y]
		zone_container.add_child(mesh)


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
