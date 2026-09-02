class_name ArrivalCommitGate
extends RefCounted

## Shared synchronous gate for an arrival transaction. The gate remains held
## while the committed envelope is flushed, so no other transaction, save, or
## input can intervene between append and observer notification.

var _held: bool = false
var _barrier_active: bool = false
var _owner_token: String = ""


func acquire(owner_token: String) -> bool:
	if _held or owner_token.is_empty():
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
	if _barrier_active or not _held or owner_token != _owner_token:
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
