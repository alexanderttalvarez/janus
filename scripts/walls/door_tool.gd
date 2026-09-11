## DoorTool — Preview and placement/removal of manual wall doors.
class_name DoorTool
extends Node


const PREVIEW_Y: float = 1.2
const DOOR_HEIGHT: float = 2.4
const DOOR_WIDTH: float = 0.6
## Preview thickness intentionally exceeds the 0.1 m wall thickness so the
## translucent placeholder remains visible in Full wall mode.
const DOOR_THICKNESS: float = 0.22
const ADD_COLOR: Color = Color(0.2, 0.9, 0.35, 0.65)
const REMOVE_COLOR: Color = Color(0.95, 0.2, 0.2, 0.65)
const NEUTRAL_COLOR: Color = Color(0.55, 0.58, 0.62, 0.65)


var is_active: bool = false
var remove_mode: bool = false
var _preview_mesh: MeshInstance3D
var _preview_material: StandardMaterial3D
var _horizontal_mesh: BoxMesh
var _vertical_mesh: BoxMesh
var _manual_door_authority: ManualDoorAuthority
var _projection_coordinator: ProjectionCoordinator
var _active_floor_address: Dictionary = {}


func configure_production(authority: ManualDoorAuthority, projection_coordinator: ProjectionCoordinator, floor_address: Dictionary) -> void:
	_manual_door_authority = authority
	_projection_coordinator = projection_coordinator
	_active_floor_address = floor_address.duplicate(true)


func _ready() -> void:
	# Door placement remains available while simulation time is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Node3D.new()
	root.name = "VisualRoot"
	add_child(root)
	_preview_mesh = MeshInstance3D.new()
	_preview_mesh.name = "DoorPreview"
	_preview_mesh.visible = false
	_preview_material = StandardMaterial3D.new()
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_mesh.material_override = _preview_material
	_horizontal_mesh = BoxMesh.new()
	_horizontal_mesh.size = Vector3(DOOR_WIDTH, DOOR_HEIGHT, DOOR_THICKNESS)
	_vertical_mesh = BoxMesh.new()
	_vertical_mesh.size = Vector3(DOOR_THICKNESS, DOOR_HEIGHT, DOOR_WIDTH)
	_preview_mesh.mesh = _horizontal_mesh
	root.add_child(_preview_mesh)
	set_process(false)
	set_process_unhandled_input(true)


func set_active(enabled: bool, p_remove_mode: bool = false) -> void:
	is_active = enabled
	remove_mode = p_remove_mode
	set_process(enabled)
	if not is_active:
		_preview_mesh.visible = false


func _process(_delta: float) -> void:
	if not is_active:
		_preview_mesh.visible = false
		return
	_update_preview()


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_commit_at_mouse()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			set_active(false)
			get_viewport().set_input_as_handled()


func _update_preview() -> void:
	if _manual_door_authority != null:
		_update_production_preview()
		return
	var edge := _get_edge_under_mouse()
	if edge.is_empty():
		_preview_mesh.visible = false
		return
	var gm: Variant = _get_spatial_view()
	if gm == null:
		_preview_mesh.visible = false
		return
	var from: Vector2i = edge["from"]
	var to: Vector2i = edge["to"]
	var has_door: bool = bool(gm.has_door_between(from, to))
	var valid: bool = bool(gm.can_place_door_between(from, to)) if not remove_mode else has_door
	var preview_color := (
		REMOVE_COLOR if has_door else NEUTRAL_COLOR
	) if remove_mode else (
		ADD_COLOR if valid else NEUTRAL_COLOR
	)
	_preview_mesh.visible = true
	_preview_mesh.position = (
		gm.grid_to_world(from.x, from.y) + gm.grid_to_world(to.x, to.y)
	) * 0.5
	_preview_mesh.position.y = PREVIEW_Y
	var delta: Vector2i = to - from
	_preview_mesh.mesh = _vertical_mesh if delta.x != 0 else _horizontal_mesh
	_preview_material.albedo_color = preview_color


func _commit_at_mouse() -> void:
	if _manual_door_authority != null:
		_commit_production_at_mouse()
		return
	var edge := _get_edge_under_mouse()
	if edge.is_empty():
		return
	var gm: Variant = _get_spatial_view()
	if gm == null:
		return
	var from: Vector2i = edge["from"]
	var to: Vector2i = edge["to"]
	if remove_mode:
		if gm.has_door_between(from, to):
			gm.set_door_between(from, to, false)
		return
	if gm.can_place_door_between(from, to):
		gm.set_door_between(from, to, true)


func _update_production_preview() -> void:
	var edge: Dictionary = _get_edge_under_mouse()
	if edge.is_empty():
		_preview_mesh.visible = false
		return
	var intent: Dictionary = _make_production_intent(edge, not remove_mode)
	var preview: Dictionary = _manual_door_authority.preview_manual_door(intent)
	var has_door: bool = _manual_door_authority.has_manual_door(intent)
	var valid: bool = bool(preview.get("valid", false))
	_preview_mesh.visible = true
	_preview_mesh.global_position = edge["world_position"] + Vector3.UP * PREVIEW_Y
	var delta: Vector2i = edge["to"] - edge["from"]
	_preview_mesh.mesh = _vertical_mesh if delta.x != 0 else _horizontal_mesh
	_preview_material.albedo_color = REMOVE_COLOR if remove_mode and has_door else (ADD_COLOR if valid else NEUTRAL_COLOR)


func _commit_production_at_mouse() -> void:
	var edge: Dictionary = _get_edge_under_mouse()
	if edge.is_empty():
		return
	var result: Dictionary = _manual_door_authority.commit_manual_door(_make_production_intent(edge, not remove_mode))
	if not bool(result.get("valid", false)):
		push_warning("DoorTool: manual door command rejected: %s" % result.get("diagnostics", []))


func _make_production_intent(edge: Dictionary, enabled: bool) -> Dictionary:
	return {
		"operation": DistrictRuntime.OP_SET_MANUAL_DOOR,
		"runtime_plot_id": String(_active_floor_address.get("runtime_plot_id", "")),
		"floor_id": String(_active_floor_address.get("floor_id", "")),
		"elevation": int(_active_floor_address.get("elevation", 0)),
		"from_cell": edge["from"],
		"to_cell": edge["to"],
		"enabled": enabled,
		"expected_district_revision": _manual_door_authority.get_district_revision(),
		"expected_zone_revision": _manual_door_authority.get_zone_revision(),
	}


func _get_edge_under_mouse() -> Dictionary:
	if _manual_door_authority != null:
		return _get_production_edge_under_mouse()
	var hit_variant: Variant = _get_mouse_hit()
	if hit_variant == null:
		return {}
	var hit: Vector3 = hit_variant as Vector3
	var grid_manager: Variant = _get_spatial_view()
	if grid_manager == null:
		return {}
	var tile_pos: Vector2i = grid_manager.world_to_grid(hit)
	var local_x: float = hit.x - float(tile_pos.x)
	var local_z: float = hit.z - float(tile_pos.y)
	var distances := {
		"west": local_x,
		"east": 1.0 - local_x,
		"north": local_z,
		"south": 1.0 - local_z,
	}
	var nearest := "west"
	for side: String in distances:
		if distances[side] < distances[nearest]:
			nearest = side
	var neighbor := tile_pos
	match nearest:
		"west": neighbor += Vector2i.LEFT
		"east": neighbor += Vector2i.RIGHT
		"north": neighbor += Vector2i.UP
		"south": neighbor += Vector2i.DOWN
	return {"from": tile_pos, "to": neighbor}


func _get_production_edge_under_mouse() -> Dictionary:
	if _projection_coordinator == null or _active_floor_address.is_empty():
		return {}
	var viewport: Viewport = get_viewport()
	var camera: Camera3D = viewport.get_camera_3d()
	if camera == null:
		return {}
	var origin: Vector3 = camera.project_ray_origin(viewport.get_mouse_position())
	var direction: Vector3 = camera.project_ray_normal(viewport.get_mouse_position())
	var picked: Dictionary = _projection_coordinator.pick_cell(_active_floor_address, origin, direction)
	if not bool(picked.get("valid", false)):
		return {}
	var from: Vector2i = picked.get("cell", Vector2i(-1, -1))
	var hit_position: Vector3 = picked.get("world_position", Vector3.INF)
	if hit_position == Vector3.INF:
		return {}
	var neighbors: Array[Vector2i] = [from + Vector2i.LEFT, from + Vector2i.RIGHT, from + Vector2i.UP, from + Vector2i.DOWN]
	var nearest_from: Vector2i = from
	var nearest_to: Vector2i = neighbors[0]
	var nearest_distance: float = INF
	for neighbor: Vector2i in neighbors:
		var midpoint: Vector3 = (_projection_coordinator.project_cell_center(_active_floor_address, from) + _projection_coordinator.project_cell_center(_active_floor_address, neighbor)) * 0.5
		var distance: float = midpoint.distance_squared_to(hit_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_to = neighbor
	var midpoint_result: Vector3 = (_projection_coordinator.project_cell_center(_active_floor_address, nearest_from) + _projection_coordinator.project_cell_center(_active_floor_address, nearest_to)) * 0.5
	return {"from": nearest_from, "to": nearest_to, "world_position": midpoint_result}


func _get_mouse_hit() -> Variant:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d()
	if camera == null:
		return null
	var origin := camera.project_ray_origin(viewport.get_mouse_position())
	var direction := camera.project_ray_normal(viewport.get_mouse_position())
	if absf(direction.y) < 0.001:
		return null
	var distance := -origin.y / direction.y
	if distance < 0.0:
		return null
	return origin + direction * distance


func _get_spatial_view() -> Node:
	# Only Archive-policy test scenes may provide this legacy spatial view.
	return get_tree().get_first_node_in_group("archive_legacy_spatial") as Node
