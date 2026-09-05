@tool
class_name ProjectionPreview
extends Node3D

## Editor/runtime preview shell. It delegates build and generated-root ownership
## Handoff preview shell reload marker.
## to ProjectionCoordinator and removes all generated nodes on disable/close.

signal preview_shown(manifest: Dictionary)
signal preview_rejected(diagnostics: Array[Dictionary])

@export var preview_enabled: bool = true

var _coordinator: ProjectionCoordinator


func show_preview(request: ProjectionRequest) -> Dictionary:
	var result: ProjectionResult = build_preview(request)
	if not result.valid:
		preview_rejected.emit(result.diagnostics)
		return {"valid": false, "diagnostics": result.diagnostics}
	var committed: Dictionary = commit_preview(result)
	if not bool(committed.get("valid", false)):
		preview_rejected.emit(committed.get("diagnostics", []))
	return committed


## Builds without touching the currently committed preview. The caller may
## perform an editor-source revision check before committing the detached result.
func build_preview(request: ProjectionRequest) -> ProjectionResult:
	if not preview_enabled:
		return _failure_result("PREVIEW_DISABLED", "projection preview is disabled")
	_ensure_coordinator()
	return _coordinator.preview(request)


## Commits a detached result through the shared coordinator lifecycle.
func commit_preview(result: ProjectionResult) -> Dictionary:
	if not preview_enabled:
		return {"valid": false, "diagnostics": [{"code": "PREVIEW_DISABLED", "message": "projection preview is disabled"}]}
	_ensure_coordinator()
	var committed: Dictionary = _coordinator.commit_result(result)
	if bool(committed.get("valid", false)):
		preview_shown.emit(committed.get("manifest", {}))
	return committed


func clear_preview() -> void:
	if _coordinator != null and is_instance_valid(_coordinator):
		_coordinator.dispose()
		_coordinator.queue_free()
	_coordinator = null


func set_preview_enabled(enabled: bool) -> void:
	preview_enabled = enabled
	if not enabled:
		clear_preview()


func get_preview_root() -> Node3D:
	if _coordinator == null or not is_instance_valid(_coordinator):
		return null
	return _coordinator.get_active_root()


func get_preview_manifest() -> Dictionary:
	if _coordinator == null or not is_instance_valid(_coordinator):
		return {}
	return _coordinator.get_manifest()


func _ensure_coordinator() -> void:
	if _coordinator != null and is_instance_valid(_coordinator):
		return
	_coordinator = load("res://scripts/projection/projection_coordinator.gd").new() as ProjectionCoordinator
	_coordinator.name = "ProjectionCoordinator"
	add_child(_coordinator)
	_coordinator.owner = null


func _failure_result(code: String, message: String) -> ProjectionResult:
	var result: ProjectionResult = load("res://scripts/projection/projection_result.gd").new() as ProjectionResult
	result.valid = false
	result.diagnostics.append({"code": code, "message": message})
	return result


func _exit_tree() -> void:
	clear_preview()
