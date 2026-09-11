class_name SessionMutationGate
extends RefCounted

## Session-scoped synchronous mutation boundary. It never queues or yields.

var _held: bool = false
var _owner_token: String = ""
var _blocked: bool = false
var _blocking_diagnostic: Dictionary = {}


func acquire(owner_token: String, allow_blocked_retry: bool = false) -> Dictionary:
	if owner_token.is_empty():
		return _busy("SESSION_GATE_OWNER_REQUIRED", "session mutation owner token is required")
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return _busy("SESSION_GATE_MAIN_THREAD_REQUIRED", "session mutations are restricted to the main thread")
	if _held:
		return _busy("SESSION_MUTATION_BUSY", "another session mutation is active")
	if _blocked and not allow_blocked_retry:
		return _busy("SESSION_BOUNDARY_BLOCKED", "a failed calendar boundary must be retried first")
	_held = true
	_owner_token = owner_token
	return {"valid": true, "owner_token": owner_token, "diagnostics": []}


func release(owner_token: String) -> Dictionary:
	if not _held or owner_token != _owner_token:
		return _busy("SESSION_GATE_OWNER_MISMATCH", "only the active mutation owner can release the gate")
	_held = false
	_owner_token = ""
	return {"valid": true, "diagnostics": []}


func block(owner_token: String, diagnostic: Dictionary) -> Dictionary:
	if not _held or owner_token != _owner_token:
		return _busy("SESSION_GATE_OWNER_MISMATCH", "only the active mutation owner can block the session")
	_blocked = true
	_blocking_diagnostic = diagnostic.duplicate(true)
	return {"valid": true, "diagnostics": []}


func clear_block(owner_token: String) -> Dictionary:
	if not _held or owner_token != _owner_token:
		return _busy("SESSION_GATE_OWNER_MISMATCH", "only the active retry owner can clear the session block")
	_blocked = false
	_blocking_diagnostic.clear()
	return {"valid": true, "diagnostics": []}


func is_held() -> bool:
	return _held


func is_blocked() -> bool:
	return _blocked


func is_busy() -> bool:
	return _held or _blocked


func get_owner_token() -> String:
	return _owner_token


func get_blocking_diagnostic() -> Dictionary:
	return _blocking_diagnostic.duplicate(true)


func _busy(code: String, message: String) -> Dictionary:
	return {"valid": false, "error": ERR_BUSY, "diagnostics": [{"code": code, "message": message}]}
