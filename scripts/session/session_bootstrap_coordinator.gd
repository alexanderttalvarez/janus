class_name SessionBootstrapCoordinator
extends RefCounted

## Session lifecycle, deterministic boundary coordination, and readiness barrier.

signal session_ready(layout_id: String)
signal session_failed(diagnostic: Dictionary)

const PHASE_IDLE: String = "IDLE"
const PHASE_STAGING: String = "STAGING"
const PHASE_READY: String = "READY"
const PHASE_FAILED: String = "FAILED"
const BOUNDARY_KINDS: Array[String] = ["visitor", "hour", "day", "week", "month"]

var _phase: String = PHASE_IDLE
var _layout_id: String = ""
var _snapshot: ResolvedDistrictSnapshot
var _layout_ref: Dictionary = {}
var _authorities_ready: bool = false
var _projections_ready: bool = false
var _failure: Dictionary = {}
var _session_gate: SessionMutationGate
var _boundary_consumers: Dictionary = {}


func configure_session_gate(session_gate: SessionMutationGate) -> Dictionary:
	if session_gate == null:
		return _failure_result("SESSION_GATE_REQUIRED", "session bootstrap requires the mutation gate")
	_session_gate = session_gate
	return {"valid": true, "diagnostics": []}


## Consumer entries are ordered dictionaries with name, callable, and mandatory.
func configure_boundary_consumers(consumers: Dictionary) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	for kind: String in BOUNDARY_KINDS:
		var entries: Variant = consumers.get(kind, null)
		if not entries is Array:
			diagnostics.append({"code": "BOUNDARY_CONSUMERS_REQUIRED", "path": "$.%s" % kind, "message": "boundary consumer list is required"})
			continue
		for entry: Variant in entries:
			if not entry is Dictionary or String(entry.get("name", "")).is_empty() or not entry.get("callable", Callable()) is Callable or not (entry.get("callable") as Callable).is_valid():
				diagnostics.append({"code": "BOUNDARY_CONSUMER_INVALID", "path": "$.%s" % kind, "message": "boundary consumers require a stable name and valid Callable"})
	var day_entries: Array = consumers.get("day", [])
	if day_entries.size() < 2 or String(day_entries[0].get("name", "")) != "tenant_lifecycle" or String(day_entries[1].get("name", "")) != "economy_rent":
		diagnostics.append({"code": "DAY_CHAIN_INVALID", "path": "$.day", "message": "day chain must begin with Tenant lifecycle then Economy rent"})
	if not _starts_with_consumer(consumers.get("week", []), "economy_payroll"):
		diagnostics.append({"code": "WEEK_CHAIN_INVALID", "path": "$.week", "message": "weekly chain must begin with Economy payroll"})
	if not _starts_with_consumer(consumers.get("month", []), "economy_loans"):
		diagnostics.append({"code": "MONTH_CHAIN_INVALID", "path": "$.month", "message": "monthly chain must begin with Economy loans"})
	if not diagnostics.is_empty():
		return {"valid": false, "diagnostics": diagnostics}
	_boundary_consumers = consumers.duplicate(true)
	return {"valid": true, "diagnostics": []}


## Called directly by TimeManager while it owns the shared session gate.
func deliver_boundary(kind: String, boundary_id: int) -> Dictionary:
	if _session_gate == null or not _session_gate.is_held():
		return _failure_result("SESSION_GATE_REQUIRED", "calendar delivery requires the held session mutation gate")
	if not BOUNDARY_KINDS.has(kind) or not _boundary_consumers.has(kind):
		return _failure_result("BOUNDARY_KIND_INVALID", "calendar boundary kind is not configured")
	var trace: Array[String] = []
	for entry: Dictionary in _boundary_consumers[kind]:
		var consumer_name: String = String(entry["name"])
		var handler: Callable = entry["callable"]
		var value: Variant = handler.call(boundary_id)
		trace.append(consumer_name)
		if bool(entry.get("mandatory", true)) and not _consumer_succeeded(value):
			var diagnostics: Array[Dictionary] = _consumer_diagnostics(value)
			if diagnostics.is_empty():
				diagnostics.append({"code": "BOUNDARY_SUCCESSOR_FAILED", "message": "%s failed at %s:%d" % [consumer_name, kind, boundary_id]})
			return {"valid": false, "boundary_kind": kind, "boundary_id": boundary_id, "failed_consumer": consumer_name, "trace": trace, "diagnostics": diagnostics}
	return {"valid": true, "boundary_kind": kind, "boundary_id": boundary_id, "trace": trace, "diagnostics": []}


## Validate explicit content before any session owner is created.
func begin(layout_id: String, registry: RefCounted) -> Dictionary:
	if _phase != PHASE_IDLE:
		return _reject("SESSION_ALREADY_STARTED", "session bootstrap can only begin from IDLE")
	if registry == null:
		return _reject("CONTENT_REGISTRY_REQUIRED", "session bootstrap requires a content registry")
	if _session_gate == null:
		return _reject("SESSION_GATE_REQUIRED", "session bootstrap requires the mutation gate")
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
	return {"valid": true, "phase": _phase, "layout_id": _layout_id, "snapshot": _snapshot, "layout_ref": _layout_ref.duplicate(true), "diagnostics": []}


func mark_authorities_ready(results: Dictionary) -> Dictionary:
	if _phase != PHASE_STAGING:
		return _failure_result("SESSION_NOT_STAGING", "authority readiness requires a staging session")
	var validation: Dictionary = _validate_readiness_results(results, "authority")
	if not bool(validation.get("valid", false)):
		return validation
	_authorities_ready = true
	return _barrier_result()


func mark_projections_ready(results: Dictionary) -> Dictionary:
	if _phase != PHASE_STAGING:
		return _failure_result("SESSION_NOT_STAGING", "projection readiness requires a staging session")
	var validation: Dictionary = _validate_readiness_results(results, "projection")
	if not bool(validation.get("valid", false)):
		return validation
	_projections_ready = true
	return _barrier_result()


func commit_ready() -> Dictionary:
	if _phase != PHASE_STAGING:
		return _failure_result("SESSION_NOT_STAGING", "session readiness requires a staging session")
	if not _authorities_ready:
		return _failure_result("AUTHORITIES_NOT_READY", "all authority snapshots must be ready before presentation")
	if not _projections_ready:
		return _failure_result("PROJECTIONS_NOT_READY", "all projections must be ready before presentation")
	if _session_gate == null or _session_gate.is_busy():
		return _failure_result("SESSION_MUTATION_BUSY", "session readiness cannot publish during a mutation")
	_phase = PHASE_READY
	session_ready.emit(_layout_id)
	return {"valid": true, "phase": _phase, "layout_id": _layout_id, "diagnostics": []}


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
	_boundary_consumers.clear()


func can_accept_input() -> bool:
	return _phase == PHASE_READY and _session_gate != null and not _session_gate.is_busy()


func can_save() -> bool:
	return can_accept_input()


func is_ready() -> bool:
	return _phase == PHASE_READY


func get_phase() -> String:
	return _phase


func get_selected_layout_id() -> String:
	return _layout_id


func get_failure() -> Dictionary:
	return _failure.duplicate(true)


func _validate_readiness_results(results: Dictionary, kind: String) -> Dictionary:
	if results.is_empty():
		return _failure_result("%s_RESULTS_REQUIRED" % kind.to_upper(), "explicit %s initialization results are required" % kind)
	var diagnostics: Array[Dictionary] = []
	for result_name: String in results:
		var value: Variant = results[result_name]
		if not value is Dictionary or not bool(value.get("valid", false)):
			diagnostics.append({"code": "%s_INITIALIZATION_FAILED" % kind.to_upper(), "path": "$.%s.%s" % [kind, result_name], "message": "%s initialization did not return valid" % result_name})
			continue
		if String(value.get("layout_id", "")) != _layout_id or String(value.get("definition_fingerprint", "")) != String(_layout_ref.get("definition_fingerprint", "")):
			diagnostics.append({"code": "%s_IDENTITY_MISMATCH" % kind.to_upper(), "path": "$.%s.%s" % [kind, result_name], "message": "%s initialization result does not match selected content" % result_name})
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}


func _consumer_succeeded(value: Variant) -> bool:
	if value == null:
		return true
	if value is bool:
		return bool(value)
	if value is int:
		return int(value) == OK
	if value is Dictionary:
		if value.has("valid"):
			return bool(value["valid"])
		if value.has("committed"):
			return bool(value["committed"]) or bool(value.get("already_settled", false))
		if value.has("accepted"):
			return bool(value["accepted"])
	return false


func _consumer_diagnostics(value: Variant) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	if value is Dictionary:
		for diagnostic: Variant in value.get("diagnostics", []):
			if diagnostic is Dictionary:
				diagnostics.append(diagnostic.duplicate(true))
	return diagnostics


func _starts_with_consumer(entries: Variant, expected_name: String) -> bool:
	return entries is Array and not entries.is_empty() and entries[0] is Dictionary and String(entries[0].get("name", "")) == expected_name


func _barrier_result() -> Dictionary:
	return {"valid": true, "phase": _phase, "authorities_ready": _authorities_ready, "projections_ready": _projections_ready, "diagnostics": []}


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
