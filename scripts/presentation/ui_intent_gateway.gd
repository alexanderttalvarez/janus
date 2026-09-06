class_name UIIntentGateway
extends RefCounted

## Routes typed UI requests to registered owner ports without owning gameplay rules.
signal preview_completed(request_id: String, result: Dictionary)
signal confirm_completed(request_id: String, result: Dictionary)

var _owners: Dictionary = {}
var _in_flight: Dictionary = {}


func register_owner(owner_id: String, owner: Object) -> void:
	if not owner_id.is_empty() and owner != null:
		_owners[owner_id] = owner


func unregister_owner(owner_id: String) -> void:
	_owners.erase(owner_id)


func submit_preview(request: Dictionary) -> Dictionary:
	return _submit(request, true)


func submit_confirm(request: Dictionary) -> Dictionary:
	return _submit(request, false)


func complete(request_id: String, result: Dictionary) -> Dictionary:
	if not _in_flight.has(request_id):
		return {"accepted": false, "diagnostics": [{"code": "UI_INTENT_NOT_IN_FLIGHT"}]}
	_in_flight.erase(request_id)
	var completed: Dictionary = result.duplicate(true)
	completed["request_id"] = request_id
	return completed


func cancel(request_id: String) -> void:
	_in_flight.erase(request_id)


func is_in_flight(request_id: String) -> bool:
	return _in_flight.has(request_id)


func _submit(request: Dictionary, preview: bool) -> Dictionary:
	var request_id: String = String(request.get("request_id", ""))
	var owner_id: String = String(request.get("owner_id", ""))
	if request_id.is_empty() or owner_id.is_empty():
		return _failure("UI_INTENT_INVALID", request_id)
	if _in_flight.has(request_id):
		return _failure("UI_INTENT_DUPLICATE", request_id)
	var owner: Object = _owners.get(owner_id)
	if owner == null:
		return _failure("UI_INTENT_OWNER_UNAVAILABLE", request_id)
	var method_name: String = "preview_intent" if preview else "commit_intent"
	if not owner.has_method(method_name):
		return _failure("UI_INTENT_OWNER_UNAVAILABLE", request_id)
	_in_flight[request_id] = true
	var result: Variant = owner.call(method_name, request.duplicate(true))
	if not result is Dictionary:
		return _complete_failure(request_id, "UI_INTENT_RESULT_INVALID", preview)
	var typed_result: Dictionary = result
	var pending: bool = bool(typed_result.get("pending", false))
	if not pending:
		_in_flight.erase(request_id)
	typed_result["request_id"] = request_id
	if preview:
		preview_completed.emit(request_id, typed_result.duplicate(true))
	else:
		confirm_completed.emit(request_id, typed_result.duplicate(true))
	return typed_result


func _complete_failure(request_id: String, code: String, preview: bool) -> Dictionary:
	_in_flight.erase(request_id)
	var result: Dictionary = _failure(code, request_id)
	if preview:
		preview_completed.emit(request_id, result.duplicate(true))
	else:
		confirm_completed.emit(request_id, result.duplicate(true))
	return result


func _failure(code: String, request_id: String = "") -> Dictionary:
	var result: Dictionary = {"accepted": false, "diagnostics": [{"code": code}]}
	if not request_id.is_empty():
		result["request_id"] = request_id
	return result
