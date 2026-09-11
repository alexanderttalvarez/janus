class_name DistrictTransactionGate
extends RefCounted

## District barrier semantics wrapped around the sole session mutation gate.

var _session_gate: SessionMutationGate
var _held: bool = false
var _barrier_active: bool = false
var _owner_token: String = ""


func configure(session_gate: SessionMutationGate) -> Dictionary:
	if session_gate == null:
		return {"valid": false, "diagnostics": [{"code": "SESSION_GATE_REQUIRED", "message": "District transactions require the session mutation gate"}]}
	if _held:
		return {"valid": false, "diagnostics": [{"code": "SESSION_GATE_RECONFIGURE_BUSY", "message": "District transaction gate cannot be rebound while held"}]}
	_session_gate = session_gate
	return {"valid": true, "diagnostics": []}


func acquire(owner_token: String) -> bool:
	if _session_gate == null or _held or owner_token.is_empty():
		return false
	var acquired: Dictionary = _session_gate.acquire(owner_token)
	if not bool(acquired.get("valid", false)):
		return false
	_held = true
	_owner_token = owner_token
	return true


func enter_barrier(owner_token: String) -> bool:
	if not _held or owner_token != _owner_token or _barrier_active:
		return false
	_barrier_active = true
	return true


func release_barrier(owner_token: String) -> bool:
	if not _barrier_active or owner_token != _owner_token:
		return false
	_barrier_active = false
	return true


func release(owner_token: String) -> bool:
	if _session_gate == null or _barrier_active or not _held or owner_token != _owner_token:
		return false
	var released: Dictionary = _session_gate.release(owner_token)
	if not bool(released.get("valid", false)):
		return false
	_held = false
	_owner_token = ""
	return true


func is_held() -> bool:
	return _held


func is_barrier_active() -> bool:
	return _barrier_active


func can_observe() -> bool:
	return not _barrier_active
