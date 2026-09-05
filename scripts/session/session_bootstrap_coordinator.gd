class_name SessionBootstrapCoordinator
extends RefCounted

## Lifecycle-only session barrier. It never owns domain state or projection Nodes.

signal session_ready(layout_id: String)
signal session_failed(diagnostic: Dictionary)

const PHASE_IDLE: String = "IDLE"
const PHASE_STAGING: String = "STAGING"
const PHASE_READY: String = "READY"
const PHASE_FAILED: String = "FAILED"

var _phase: String = PHASE_IDLE
var _layout_id: String = ""
var _snapshot: ResolvedDistrictSnapshot
var _layout_ref: Dictionary = {}
var _authorities_ready: bool = false
var _projections_ready: bool = false
var _failure: Dictionary = {}


## Validate explicit content before any session owner is created.
func begin(layout_id: String, registry: RefCounted) -> Dictionary:
	if _phase != PHASE_IDLE:
		return _reject("SESSION_ALREADY_STARTED", "session bootstrap can only begin from IDLE")
	if registry == null:
		return _reject("CONTENT_REGISTRY_REQUIRED", "session bootstrap requires a content registry")
	var selection: Variant = registry.call("resolve_layout", layout_id)
	if not selection is Dictionary or not bool(selection.get("valid", false)):
		var diagnostics: Array = [] if not selection is Dictionary else selection.get("diagnostics", [])
		return _reject_diagnostics(diagnostics, "CONTENT_SELECTION_REJECTED")
	var snapshot: ResolvedDistrictSnapshot = selection.get("snapshot") as ResolvedDistrictSnapshot
	if snapshot == null:
		return _reject("LAYOUT_SNAPSHOT_REQUIRED", "validated content must provide a resolved snapshot")
	_phase = PHASE_STAGING
	_layout_id = layout_id
	_snapshot = snapshot
	_layout_ref = selection.get("layout_ref", {}).duplicate(true)
	_authorities_ready = false
	_projections_ready = false
	_failure.clear()
	return {
		"valid": true,
		"phase": _phase,
		"layout_id": _layout_id,
		"snapshot": _snapshot,
		"layout_ref": _layout_ref.duplicate(true),
		"diagnostics": [],
	}


func mark_authorities_ready() -> Dictionary:
	if _phase != PHASE_STAGING:
		return _failure_result("SESSION_NOT_STAGING", "authority readiness requires a staging session")
	_authorities_ready = true
	return _barrier_result()


func mark_projections_ready() -> Dictionary:
	if _phase != PHASE_STAGING:
		return _failure_result("SESSION_NOT_STAGING", "projection readiness requires a staging session")
	_projections_ready = true
	return _barrier_result()


## Open the presentation/input gate only after both barriers report success.
func commit_ready() -> Dictionary:
	if _phase != PHASE_STAGING:
		return _failure_result("SESSION_NOT_STAGING", "session readiness requires a staging session")
	if not _authorities_ready:
		return _failure_result("AUTHORITIES_NOT_READY", "all authority snapshots must be ready before presentation")
	if not _projections_ready:
		return _failure_result("PROJECTIONS_NOT_READY", "all projections must be ready before presentation")
	_phase = PHASE_READY
	session_ready.emit(_layout_id)
	return {"valid": true, "phase": _phase, "layout_id": _layout_id, "diagnostics": []}


## Fail and dispose staged lifecycle state without publishing readiness.
func fail(diagnostic: Dictionary) -> Dictionary:
	_phase = PHASE_FAILED
	_failure = diagnostic.duplicate(true)
	_layout_id = ""
	_snapshot = null
	_layout_ref.clear()
	_authorities_ready = false
	_projections_ready = false
	session_failed.emit(_failure.duplicate(true))
	return {"valid": false, "phase": _phase, "diagnostics": [_failure.duplicate(true)]}


func dispose() -> void:
	_phase = PHASE_IDLE
	_layout_id = ""
	_snapshot = null
	_layout_ref.clear()
	_authorities_ready = false
	_projections_ready = false
	_failure.clear()


func can_accept_input() -> bool:
	return _phase == PHASE_READY


func is_ready() -> bool:
	return _phase == PHASE_READY


func get_phase() -> String:
	return _phase


func get_selected_layout_id() -> String:
	return _layout_id


func get_failure() -> Dictionary:
	return _failure.duplicate(true)


func _barrier_result() -> Dictionary:
	return {
		"valid": true,
		"phase": _phase,
		"authorities_ready": _authorities_ready,
		"projections_ready": _projections_ready,
		"diagnostics": [],
	}


func _reject(code: String, message: String) -> Dictionary:
	return _reject_diagnostics([{"code": code, "message": message}], code)


func _reject_diagnostics(diagnostics: Array, fallback_code: String) -> Dictionary:
	var first: Dictionary = {"code": fallback_code, "message": "session content selection was rejected"}
	for diagnostic: Variant in diagnostics:
		if diagnostic is Dictionary:
			first = diagnostic.duplicate(true)
			break
	return fail(first)


func _failure_result(code: String, message: String) -> Dictionary:
	return {"valid": false, "phase": _phase, "diagnostics": [{"code": code, "message": message}]}
