@tool
class_name ProjectionPreviewController
extends Node3D

## Editor-only lifecycle controller. It owns a preview shell under a transient,
## Handoff controller reload marker.
## ownerless scene-tree node and never writes authored or district authority data.

signal preview_committed(manifest: Dictionary)
signal preview_rejected(diagnostics: Array[Dictionary])
signal preview_cleaned

var _preview: ProjectionPreview
var _attached_scene_root: Node


func _ready() -> void:
	_ensure_preview()


func attach_to_scene(scene_root: Node) -> Dictionary:
	if scene_root == null:
		return _reject("SCENE_ROOT_REQUIRED", "an edited scene root is required")
	if _attached_scene_root == scene_root:
		return {"valid": true, "diagnostics": []}
	detach_from_scene()
	if get_parent() != null:
		get_parent().remove_child(self)
	scene_root.add_child(self)
	owner = null
	set_meta("generated_projection", true)
	set_meta("editor_preview_controller", true)
	_attached_scene_root = scene_root
	return {"valid": true, "diagnostics": []}


func rebuild(request: ProjectionRequest, expected_source_revision: int, current_source_revision: int) -> Dictionary:
	_ensure_preview()
	if expected_source_revision != current_source_revision:
		var stale: Array[Dictionary] = [{"code": "STALE_EDITOR_PREVIEW", "message": "editor source changed before preview commit"}]
		preview_rejected.emit(stale)
		return {"valid": false, "diagnostics": stale}
	var result: ProjectionResult = _preview.build_preview(request)
	if not result.valid:
		preview_rejected.emit(result.diagnostics)
		return {"valid": false, "diagnostics": result.diagnostics}
	if expected_source_revision != current_source_revision:
		if result.candidate_root != null and is_instance_valid(result.candidate_root):
			result.candidate_root.queue_free()
		var stale_after_build: Array[Dictionary] = [{"code": "STALE_EDITOR_PREVIEW", "message": "editor source changed during preview build"}]
		preview_rejected.emit(stale_after_build)
		return {"valid": false, "diagnostics": stale_after_build}
	var committed: Dictionary = _preview.commit_preview(result)
	if bool(committed.get("valid", false)):
		preview_committed.emit(committed.get("manifest", {}))
	else:
		preview_rejected.emit(committed.get("diagnostics", []))
	return committed


func cleanup() -> void:
	if _preview != null and is_instance_valid(_preview):
		_preview.clear_preview()
	preview_cleaned.emit()


func detach_from_scene() -> void:
	cleanup()
	_attached_scene_root = null
	if get_parent() != null:
		get_parent().remove_child(self)


func get_preview_root() -> Node3D:
	if _preview == null or not is_instance_valid(_preview):
		return null
	return _preview.get_preview_root()


func get_preview_manifest() -> Dictionary:
	if _preview == null or not is_instance_valid(_preview):
		return {}
	return _preview.get_preview_manifest()


func _ensure_preview() -> void:
	if _preview != null and is_instance_valid(_preview):
		return
	_preview = load("res://scripts/projection/projection_preview.gd").new() as ProjectionPreview
	_preview.name = "PreviewShell"
	_preview.owner = null
	add_child(_preview)
	_preview.owner = null


func _reject(code: String, message: String) -> Dictionary:
	var diagnostics: Array[Dictionary] = [{"code": code, "message": message}]
	preview_rejected.emit(diagnostics)
	return {"valid": false, "diagnostics": diagnostics}


func _exit_tree() -> void:
	cleanup()
	_preview = null
	_attached_scene_root = null
