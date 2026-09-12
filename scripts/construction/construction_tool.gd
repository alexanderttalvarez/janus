## ConstructionTool — Presentation-only atomic rectangle acquisition and corridor workflow.
class_name ConstructionTool
extends Node

signal preview_changed(can_confirm: bool, status_text: String, result: Dictionary)
signal commit_completed(result: Dictionary)

const MODE_ACQUIRE: String = "acquire_ground_space"
const MODE_CORRIDOR: String = "build_corridor"
const TILE_VISUAL_OFFSET: float = 0.19

var is_active: bool = false
var _mode: String = ""
var _runtime: DistrictRuntime
var _projection_coordinator: ProjectionCoordinator
var _game_ui: Object
var _floor_address: Dictionary = {}
var _hovered_cell: Vector2i = Vector2i(-1, -1)
var _selected_cell: Vector2i = Vector2i(-1, -1)
var _selected_cells: Array[Vector2i] = []
var _selected_expected_revision: int = -1
var _dragging: bool = false
var _drag_start_cell: Vector2i = Vector2i(-1, -1)
var _drag_end_cell: Vector2i = Vector2i(-1, -1)
var _latest_preview: Dictionary = {}
var _can_confirm: bool = false
var _committed_feedback: bool = false
var _request_counter: int = 0
var _visual_root: Node3D
var _preview_mesh: MeshInstance3D
var _status_overlay_root: Node3D
var _status_overlay_revision: int = -1
var _status_overlay_visible: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)
	_preview_mesh = _make_preview_mesh()
	_visual_root.add_child(_preview_mesh)
	_status_overlay_root = Node3D.new()
	_status_overlay_root.name = "GodModeAcquisitionStatus"
	add_child(_status_overlay_root)
	set_process_unhandled_input(true)


func configure(
	runtime: DistrictRuntime,
	projection_coordinator: ProjectionCoordinator,
	game_ui: Object,
	floor_address: Dictionary
) -> Dictionary:
	_runtime = runtime
	_projection_coordinator = projection_coordinator
	_game_ui = game_ui
	_floor_address = floor_address.duplicate(true)
	if _runtime != null and _runtime.district_delta_committed.is_connected(_on_district_delta_committed):
		_runtime.district_delta_committed.disconnect(_on_district_delta_committed)
	if _runtime != null and not _runtime.district_delta_committed.is_connected(_on_district_delta_committed):
		_runtime.district_delta_committed.connect(_on_district_delta_committed)
	_status_overlay_revision = -1
	var valid: bool = (
		_runtime != null
		and _projection_coordinator != null
		and _game_ui != null
		and not _floor_address.is_empty()
	)
	return {
		"valid": valid,
		"diagnostics": [] if valid else [{"code": "CONSTRUCTION_TOOL_DEPENDENCY_REQUIRED"}],
	}


func activate(mode: String) -> bool:
	if mode != MODE_ACQUIRE and mode != MODE_CORRIDOR:
		return false
	_mode = mode
	is_active = true
	clear_selection()
	return true


func deactivate() -> void:
	is_active = false
	_mode = ""
	_hovered_cell = Vector2i(-1, -1)
	clear_selection()
	_refresh_status_overlay(true)


func get_mode() -> String:
	return _mode


func can_confirm() -> bool:
	return _can_confirm


func get_selected_cell() -> Vector2i:
	return _selected_cell


func get_selected_cells() -> Array[Vector2i]:
	return _selected_cells.duplicate()


func get_status_text() -> String:
	if _committed_feedback:
		return _mode_title() + " — Committed; select another tile"
	if _latest_preview.is_empty():
		return _mode_title() + " — Select one tile"
	return _status_text(_latest_preview)


func select_cell(cell: Vector2i) -> Dictionary:
	return select_cells([cell])


func select_cells(cells: Array[Vector2i], expected_revision: int = -1) -> Dictionary:
	_committed_feedback = false
	_selected_cells = _canonical_cells(cells)
	_selected_cell = _selected_cells[0] if not _selected_cells.is_empty() else Vector2i(-1, -1)
	_selected_expected_revision = expected_revision if expected_revision >= 0 else (_runtime.get_revision() if _runtime != null and _runtime.has_session() else -1)
	_latest_preview = _submit_preview(_selected_cells, _selected_expected_revision)
	_can_confirm = _result_valid(_latest_preview)
	_refresh_visual()
	preview_changed.emit(_can_confirm, _status_text(_latest_preview), _latest_preview.duplicate(true))
	return _latest_preview.duplicate(true)


func clear_selection() -> void:
	_committed_feedback = false
	_dragging = false
	_drag_start_cell = Vector2i(-1, -1)
	_drag_end_cell = Vector2i(-1, -1)
	_selected_cell = Vector2i(-1, -1)
	_selected_cells.clear()
	_selected_expected_revision = -1
	_latest_preview.clear()
	_can_confirm = false
	_refresh_visual()
	preview_changed.emit(false, _mode_title() + " — Select one tile", {})


func confirm_selected() -> Dictionary:
	if not is_active or _selected_cells.is_empty() or not _can_confirm:
		return {"valid": false, "diagnostics": [{"code": "CONSTRUCTION_SELECTION_NOT_CONFIRMABLE"}]}
	var request: Dictionary = _build_request(_selected_cells, false, _selected_expected_revision)
	var result: Dictionary = _game_ui.submit_intent_confirm(request) if _game_ui != null else {
		"valid": false,
		"diagnostics": [{"code": "UI_INTENT_GATEWAY_UNAVAILABLE"}],
	}
	if _result_valid(result):
		_committed_feedback = true
		_latest_preview = result.duplicate(true)
		_can_confirm = false
		_refresh_visual()
		preview_changed.emit(false, _mode_title() + " — Committed; select another tile", result.duplicate(true))
	else:
		_latest_preview = result.duplicate(true)
		_can_confirm = false
		_refresh_visual()
		preview_changed.emit(false, _status_text(result), result.duplicate(true))
	commit_completed.emit(result.duplicate(true))
	return result


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var cell: Vector2i = _pick_cell_under_mouse()
			if event.pressed and cell.x >= 0:
				_dragging = true
				_drag_start_cell = cell
				_drag_end_cell = cell
				_selected_expected_revision = _runtime.get_revision() if _runtime != null and _runtime.has_session() else -1
				_refresh_visual()
				get_viewport().set_input_as_handled()
			elif not event.pressed and _dragging:
				_dragging = false
				if _drag_start_cell.x >= 0 and cell.x >= 0:
					select_cells(rectangle_cells(_drag_start_cell, cell), _selected_expected_revision)
				else:
					clear_selection()
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			clear_selection()
			get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and _dragging:
		var cell: Vector2i = _pick_cell_under_mouse()
		if cell.x >= 0:
			_drag_end_cell = cell
			_refresh_visual()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_refresh_status_overlay(false)
	if not is_active:
		if _preview_mesh != null:
			_preview_mesh.visible = false
		return
	var cell: Vector2i = _pick_cell_under_mouse()
	if cell != _hovered_cell:
		_hovered_cell = cell
		if _selected_cells.is_empty() and not _dragging and cell.x >= 0:
			_latest_preview = _submit_preview([cell])
			_can_confirm = false
			preview_changed.emit(false, _status_text(_latest_preview), _latest_preview.duplicate(true))
		_refresh_visual()


func _submit_preview(cells: Array[Vector2i], expected_revision: int = -1) -> Dictionary:
	if _game_ui == null:
		return {"valid": false, "diagnostics": [{"code": "UI_INTENT_GATEWAY_UNAVAILABLE"}]}
	return _game_ui.submit_intent_preview(_build_request(cells, true, expected_revision))


func _build_request(cells: Array[Vector2i], preview: bool, expected_revision: int = -1) -> Dictionary:
	_request_counter += 1
	var runtime_plot_id: String = String(_floor_address.get("runtime_plot_id", ""))
	var floor_id: String = String(_floor_address.get("floor_id", ""))
	var elevation: int = int(_floor_address.get("elevation", 0))
	if expected_revision < 0:
		expected_revision = _runtime.get_revision() if _runtime != null and _runtime.has_session() else -1
	var request: Dictionary = {
		"request_id": "construction_tool:%s:%s:%d" % [_mode, "preview" if preview else "confirm", _request_counter],
		"owner_id": ConstructionIntentGateway.OWNER_ID,
		"operation": DistrictRuntime.OP_ACQUIRE_SPACE if _mode == MODE_ACQUIRE else DistrictRuntime.OP_CONSTRUCT,
		"expected_district_revision": expected_revision,
		"runtime_plot_id": runtime_plot_id,
		"floor_id": floor_id,
		"elevation": elevation,
	}
	if _mode == MODE_ACQUIRE:
		request["cells"] = []
		for cell: Vector2i in cells:
			request["cells"].append([cell.x, cell.y])
	else:
		request["construction_kind"] = "corridor"
		request["cells"] = []
		for cell: Vector2i in cells:
			request["cells"].append({
				"plot_id": runtime_plot_id,
				"floor_id": floor_id,
				"elevation": elevation,
				"x": cell.x,
				"y": cell.y,
			})
	return request


func _pick_cell_under_mouse() -> Vector2i:
	var viewport: Viewport = get_viewport()
	if viewport == null or _projection_coordinator == null or _floor_address.is_empty():
		return Vector2i(-1, -1)
	var camera: Camera3D = viewport.get_camera_3d()
	if camera == null:
		return Vector2i(-1, -1)
	var mouse_position: Vector2 = viewport.get_mouse_position()
	var pick: Dictionary = _projection_coordinator.pick_cell(
		_floor_address,
		camera.project_ray_origin(mouse_position),
		camera.project_ray_normal(mouse_position),
	)
	return pick.get("cell", Vector2i(-1, -1)) as Vector2i if bool(pick.get("valid", false)) else Vector2i(-1, -1)


func _refresh_visual() -> void:
	if _preview_mesh == null:
		return
	var cells: Array[Vector2i] = _selected_cells
	if _dragging and _drag_start_cell.x >= 0 and _drag_end_cell.x >= 0:
		cells = rectangle_cells(_drag_start_cell, _drag_end_cell)
	elif cells.is_empty() and _hovered_cell.x >= 0:
		cells = [_hovered_cell]
	if not is_active or cells.is_empty() or _projection_coordinator == null:
		_preview_mesh.visible = false
		return
	var min_cell: Vector2i = cells[0]
	var max_cell: Vector2i = cells[0]
	for cell: Vector2i in cells:
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)
	var minimum: Vector3 = _projection_coordinator.project_grid_coordinate(_floor_address, Vector2(min_cell))
	var maximum: Vector3 = _projection_coordinator.project_grid_coordinate(_floor_address, Vector2(max_cell + Vector2i.ONE))
	var tile_size: float = _projection_coordinator.get_projected_tile_size(_floor_address)
	if minimum == Vector3.INF or maximum == Vector3.INF or tile_size <= 0.0:
		_preview_mesh.visible = false
		return
	(_preview_mesh.mesh as BoxMesh).size = Vector3(maximum.x - minimum.x, 0.08, maximum.z - minimum.z)
	_preview_mesh.global_position = (minimum + maximum) * 0.5 + Vector3(0.0, TILE_VISUAL_OFFSET, 0.0)
	var material: StandardMaterial3D = _preview_mesh.material_override as StandardMaterial3D
	var valid: bool = _result_valid(_latest_preview)
	material.albedo_color = Color(0.15, 0.85, 0.35, 0.82) if valid else Color(0.92, 0.16, 0.12, 0.82)
	_preview_mesh.visible = true


static func rectangle_cells(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(mini(start_cell.y, end_cell.y), maxi(start_cell.y, end_cell.y) + 1):
		for x: int in range(mini(start_cell.x, end_cell.x), maxi(start_cell.x, end_cell.x) + 1):
			result.append(Vector2i(x, y))
	return result


static func _canonical_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if cell.x < 0 or cell.y < 0 or result.has(cell):
			continue
		result.append(cell)
	result.sort_custom(func(left: Vector2i, right: Vector2i) -> bool: return left.y < right.y or (left.y == right.y and left.x < right.x))
	return result


func _on_district_delta_committed(_envelope: Dictionary) -> void:
	_refresh_status_overlay(true)


func _refresh_status_overlay(force: bool) -> void:
	var god_mode: bool = _god_mode_active()
	var revision: int = _runtime.get_revision() if _runtime != null and _runtime.has_session() else -1
	if not force and god_mode == _status_overlay_visible and revision == _status_overlay_revision:
		return
	_status_overlay_visible = god_mode
	_status_overlay_revision = revision
	_clear_status_overlay()
	if not god_mode or _runtime == null or _projection_coordinator == null or _floor_address.is_empty():
		return
	var snapshot: ResolvedDistrictSnapshot = _runtime.get_snapshot()
	if snapshot == null:
		return
	var data: Dictionary = snapshot.get_data()
	var plot_id: String = String(_floor_address.get("runtime_plot_id", ""))
	var floor_id: String = String(_floor_address.get("floor_id", ""))
	var buildable: Array[Vector2i] = []
	for plot: Dictionary in data.get("plots", []):
		if String(plot.get("id", "")) != plot_id:
			continue
		for value: Variant in plot.get("buildability_mask", []):
			if value is Array and value.size() >= 2:
				buildable.append(Vector2i(int(value[0]), int(value[1])))
	var floor_state: Dictionary = _status_floor_state(_runtime.get_state(), floor_id)
	var acquired: Dictionary = {}
	for value: Variant in floor_state.get("acquired_cells", []):
		if value is Array and value.size() >= 2:
			acquired[Vector2i(int(value[0]), int(value[1]))] = true
	var buildable_set: Dictionary = {}
	var unacquired_cells: Array[Vector2i] = []
	var acquired_cells: Array[Vector2i] = []
	for cell: Vector2i in buildable:
		buildable_set[cell] = true
		if acquired.has(cell):
			acquired_cells.append(cell)
		else:
			unacquired_cells.append(cell)
	_add_status_tiles(unacquired_cells, Color(0.55, 0.18, 0.18, 0.2))
	_add_status_tiles(acquired_cells, Color(0.52, 0.52, 0.52, 0.2))
	var pending: Dictionary = buildable_set.duplicate()
	while not pending.is_empty():
		var start: Vector2i = pending.keys()[0]
		var status: bool = acquired.has(start)
		var component: Array[Vector2i] = []
		var queue: Array[Vector2i] = [start]
		pending.erase(start)
		while not queue.is_empty():
			var current: Vector2i = queue.pop_front()
			component.append(current)
			for neighbor: Vector2i in [current + Vector2i.UP, current + Vector2i.DOWN, current + Vector2i.LEFT, current + Vector2i.RIGHT]:
				if pending.has(neighbor) and acquired.has(neighbor) == status:
					pending.erase(neighbor)
					queue.append(neighbor)
		_add_status_label(component, status)


func _clear_status_overlay() -> void:
	if _status_overlay_root == null:
		return
	for child: Node in _status_overlay_root.get_children():
		child.free()


func _status_floor_state(state: Dictionary, floor_id: String) -> Dictionary:
	for plot_state: Dictionary in state.get("plot_states", []):
		for floor_state: Dictionary in plot_state.get("floor_states", []):
			if String(floor_state.get("floor_id", "")) == floor_id:
				return floor_state
	return {}


func _add_status_tiles(cells: Array[Vector2i], color: Color) -> void:
	if cells.is_empty():
		return
	var tile_size: float = _projection_coordinator.get_projected_tile_size(_floor_address)
	if tile_size <= 0.0:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(tile_size * 0.94, 0.035, tile_size * 0.94)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = cells.size()
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	instance.material_override = material
	for index: int in range(cells.size()):
		var position: Vector3 = _projection_coordinator.project_cell_center(_floor_address, cells[index])
		if position != Vector3.INF:
			multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, position + Vector3(0.0, TILE_VISUAL_OFFSET - 0.03, 0.0)))
	_status_overlay_root.add_child(instance)


func _add_status_label(component: Array[Vector2i], is_acquired: bool) -> void:
	if component.is_empty():
		return
	var center := Vector3.ZERO
	for cell: Vector2i in component:
		center += _projection_coordinator.project_cell_center(_floor_address, cell)
	center /= float(component.size())
	var label := Label3D.new()
	label.text = "ACQUIRED" if is_acquired else "UNACQUIRED"
	label.modulate = Color(0.55, 0.55, 0.55, 0.2) if is_acquired else Color(0.85, 0.25, 0.25, 0.2)
	label.font_size = 48
	label.outline_size = 2
	label.outline_modulate = Color(0.05, 0.05, 0.05, 0.2)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.global_position = center + Vector3(0.0, 0.55, 0.0)
	_status_overlay_root.add_child(label)


func _god_mode_active() -> bool:
	if OS.has_feature("release") or not is_inside_tree():
		return false
	var debug_manager: Node = get_tree().root.get_node_or_null("DebugManager")
	return debug_manager != null and bool(debug_manager.get("god_mode"))


func _make_preview_mesh() -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "CellPreview"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.92, 0.08, 0.92)
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.92, 0.16, 0.12, 0.82)
	mesh_instance.material_override = material
	mesh_instance.visible = false
	return mesh_instance


func _result_valid(result: Dictionary) -> bool:
	return bool(result.get("valid", result.get("accepted", false)))


func _status_text(result: Dictionary) -> String:
	var title: String = _mode_title()
	if _result_valid(result):
		var quote: Dictionary = result.get("quote", {})
		var value: int = int(quote.get("value", 0))
		return "%s — Ready (%s Kreds)" % [title, _format_value(value)]
	var diagnostics: Array = result.get("diagnostics", [])
	if diagnostics.is_empty() or not diagnostics[0] is Dictionary:
		return title + " — Unavailable"
	var diagnostic: Dictionary = diagnostics[0]
	var message: String = String(diagnostic.get("message", ""))
	return "%s — %s" % [title, message if not message.is_empty() else String(diagnostic.get("code", "Unavailable"))]


func _mode_title() -> String:
	return "Acquire Ground Space" if _mode == MODE_ACQUIRE else "Build Corridor"


func _format_value(value: int) -> String:
	var digits: String = str(absi(value))
	var formatted: String = ""
	while digits.length() > 3:
		formatted = "," + digits.right(3) + formatted
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + formatted
