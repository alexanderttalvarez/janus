@tool
extends EditorPlugin

## Opt-in editor tooling only. It owns a transient preview controller and dock;
## runtime authority and authored scene resources remain untouched.

const PREVIEW_CONTROLLER_PATH: String = "res://scripts/projection/projection_preview_controller.gd"
const SOURCE_PATH: String = "res://scripts/projection/projection_editor_source.gd"
const METRICS_PATH: String = "res://scripts/projection/projection_metrics.gd"

var _dock: VBoxContainer
var _fixture_selector: OptionButton
var _identity_edit: LineEdit
var _revision_edit: LineEdit
var _grid_unit_edit: LineEdit
var _floor_height_edit: LineEdit
var _origin_x_edit: LineEdit
var _origin_y_edit: LineEdit
var _origin_z_edit: LineEdit
var _diagnostics_label: Label
var _preview: ProjectionPreviewController
var _source: ProjectionEditorSource


func _enter_tree() -> void:
	_source = load(SOURCE_PATH).new() as ProjectionEditorSource
	_dock = _build_dock()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	if not scene_changed.is_connected(_on_scene_changed):
		scene_changed.connect(_on_scene_changed)
	if not scene_closed.is_connected(_on_scene_closed):
		scene_closed.connect(_on_scene_closed)
	_attach_preview()


func _exit_tree() -> void:
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if scene_closed.is_connected(_on_scene_closed):
		scene_closed.disconnect(_on_scene_closed)
	_release_preview()
	if _dock != null and is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.queue_free()
	_dock = null
	_source = null


func _build_dock() -> VBoxContainer:
	var dock: VBoxContainer = VBoxContainer.new()
	dock.name = "DistrictProjectionPreviewDock"
	dock.custom_minimum_size = Vector2(280.0, 0.0)
	var title: Label = Label.new()
	title.text = "District Projection Preview"
	dock.add_child(title)
	var help: Label = Label.new()
	help.text = "Opt-in, disposable editor projection"
	dock.add_child(help)
	var fixture_label: Label = Label.new()
	fixture_label.text = "Layout source"
	dock.add_child(fixture_label)
	_fixture_selector = OptionButton.new()
	_fixture_selector.add_item("fixture.legacy_25_single", 0)
	_fixture_selector.add_item("fixture.variable_30x40_single", 1)
	_fixture_selector.add_item("fixture.mixed_3x3", 2)
	_fixture_selector.item_selected.connect(_on_fixture_selected)
	dock.add_child(_fixture_selector)
	dock.add_child(_labeled_edit("Metrics identity", "", "identity"))
	_identity_edit = dock.get_node("identity_group/identity") as LineEdit
	dock.add_child(_labeled_edit("Metrics revision", "0", "revision"))
	_revision_edit = dock.get_node("revision_group/revision") as LineEdit
	dock.add_child(_labeled_edit("Grid unit size", "", "grid_unit"))
	_grid_unit_edit = dock.get_node("grid_unit_group/grid_unit") as LineEdit
	dock.add_child(_labeled_edit("Floor height", "", "floor_height"))
	_floor_height_edit = dock.get_node("floor_height_group/floor_height") as LineEdit
	dock.add_child(_labeled_edit("Origin X", "0", "origin_x"))
	_origin_x_edit = dock.get_node("origin_x_group/origin_x") as LineEdit
	dock.add_child(_labeled_edit("Origin Y", "0", "origin_y"))
	_origin_y_edit = dock.get_node("origin_y_group/origin_y") as LineEdit
	dock.add_child(_labeled_edit("Origin Z", "0", "origin_z"))
	_origin_z_edit = dock.get_node("origin_z_group/origin_z") as LineEdit
	var actions: HBoxContainer = HBoxContainer.new()
	var validate_button: Button = Button.new()
	validate_button.text = "Validate"
	validate_button.pressed.connect(_on_validate_pressed)
	actions.add_child(validate_button)
	var rebuild_button: Button = Button.new()
	rebuild_button.text = "Rebuild Preview"
	rebuild_button.pressed.connect(_on_rebuild_pressed)
	actions.add_child(rebuild_button)
	var cleanup_button: Button = Button.new()
	cleanup_button.text = "Cleanup"
	cleanup_button.pressed.connect(_on_cleanup_pressed)
	actions.add_child(cleanup_button)
	dock.add_child(actions)
	_diagnostics_label = Label.new()
	_diagnostics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diagnostics_label.text = "Set metrics, then validate or rebuild."
	dock.add_child(_diagnostics_label)
	return dock


func _labeled_edit(label_text: String, default_text: String, node_name: String) -> VBoxContainer:
	var group: VBoxContainer = VBoxContainer.new()
	group.name = "%s_group" % node_name
	var label: Label = Label.new()
	label.text = label_text
	group.add_child(label)
	var edit: LineEdit = LineEdit.new()
	edit.name = node_name
	edit.text = default_text
	group.add_child(edit)
	return group


func _selected_fixture_id() -> String:
	if _fixture_selector == null:
		return ""
	return String(_fixture_selector.get_item_text(_fixture_selector.selected))


func _load_selected_source() -> Dictionary:
	if _source == null:
		return {"valid": false, "diagnostics": [{"code": "EDITOR_SOURCE_UNAVAILABLE", "message": "editor source is unavailable"}]}
	return _source.load_fixture(_selected_fixture_id())


func _make_metrics() -> ProjectionMetrics:
	var metrics: ProjectionMetrics = load(METRICS_PATH).new() as ProjectionMetrics
	metrics.identity = _identity_edit.text.strip_edges()
	metrics.revision = _revision_edit.text.to_int()
	metrics.grid_unit_size = _grid_unit_edit.text.to_float()
	metrics.floor_height = _floor_height_edit.text.to_float()
	metrics.origin = Vector3(_origin_x_edit.text.to_float(), _origin_y_edit.text.to_float(), _origin_z_edit.text.to_float())
	return metrics


func _on_fixture_selected(_index: int) -> void:
	_on_validate_pressed()


func _on_validate_pressed() -> void:
	var loaded: Dictionary = _load_selected_source()
	if bool(loaded.get("valid", false)):
		_set_diagnostics("Valid H1/H2 source: %s" % _source.get_fingerprint())
	else:
		_set_diagnostics(_format_diagnostics(loaded.get("diagnostics", [])))


func _on_rebuild_pressed() -> void:
	var loaded: Dictionary = _load_selected_source()
	if not bool(loaded.get("valid", false)):
		_set_diagnostics(_format_diagnostics(loaded.get("diagnostics", [])))
		return
	var request_result: Dictionary = _source.build_request(_make_metrics())
	if not bool(request_result.get("valid", false)):
		_set_diagnostics(_format_diagnostics(request_result.get("diagnostics", [])))
		return
	_attach_preview()
	if _preview == null:
		_set_diagnostics("No edited scene is open; preview has nowhere to attach.")
		return
	var revision: int = _source.get_revision()
	var rebuilt: Dictionary = _preview.rebuild(request_result.get("request") as ProjectionRequest, revision, revision)
	if bool(rebuilt.get("valid", false)):
		_set_diagnostics("Preview committed: %s" % JSON.stringify(rebuilt.get("manifest", {})))
	else:
		_set_diagnostics(_format_diagnostics(rebuilt.get("diagnostics", [])))


func _on_cleanup_pressed() -> void:
	if _preview != null and is_instance_valid(_preview):
		_preview.cleanup()
	_set_diagnostics("Preview cleaned up.")


func _on_scene_changed(_scene_root: Node) -> void:
	_release_preview()
	_attach_preview()


func _on_scene_closed(_scene_file_path: String) -> void:
	_release_preview()


func _attach_preview() -> void:
	if _preview != null and is_instance_valid(_preview):
		return
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return
	_preview = load(PREVIEW_CONTROLLER_PATH).new() as ProjectionPreviewController
	_preview.name = "EditorProjectionPreview"
	var attached: Dictionary = _preview.attach_to_scene(scene_root)
	if not bool(attached.get("valid", false)):
		_preview.free()
		_preview = null


func _release_preview() -> void:
	if _preview == null or not is_instance_valid(_preview):
		_preview = null
		return
	_preview.detach_from_scene()
	_preview.queue_free()
	_preview = null


func _set_diagnostics(text: String) -> void:
	if _diagnostics_label != null and is_instance_valid(_diagnostics_label):
		_diagnostics_label.text = text


func _format_diagnostics(diagnostics: Array) -> String:
	if diagnostics.is_empty():
		return "Operation rejected without diagnostics."
	var lines: PackedStringArray = []
	for diagnostic: Variant in diagnostics:
		if diagnostic is Dictionary:
			lines.append("%s: %s" % [String(diagnostic.get("code", "ERROR")), String(diagnostic.get("message", ""))])
	return "\n".join(lines)
