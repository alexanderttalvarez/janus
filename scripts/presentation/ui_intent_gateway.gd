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


func submit_preview(request: Dictionary) -> Dictionary:
	return _submit(request, true)


func submit_confirm(request: Dictionary) -> Dictionary:
	return _submit(request, false)


func cancel(request_id: String) -> void:
	_in_flight.erase(request_id)


func _submit(request: Dictionary, preview: bool) -> Dictionary:
	var request_id := String(request.get("request_id", ""))
	var owner_id := String(request.get("owner_id", ""))
	if request_id.is_empty() or owner_id.is_empty():
		return _failure("UI_INTENT_INVALID")
	if _in_flight.has(request_id):
		return _failure("UI_INTENT_DUPLICATE")
	var owner: Object = _owners.get(owner_id)
	if owner == null:
		return _failure("UI_INTENT_OWNER_UNAVAILABLE")
	var method_name := "preview_intent" if preview else "commit_intent"
	if not owner.has_method(method_name):
		return _failure("UI_INTENT_OWNER_UNAVAILABLE")
	_in_flight[request_id] = true
	var result: Dictionary = owner.call(method_name, request.duplicate(true))
	_in_flight.erase(request_id)
	result["request_id"] = request_id
	if preview:
		preview_completed.emit(request_id, result.duplicate(true))
	else:
		confirm_completed.emit(request_id, result.duplicate(true))
	return result


func _failure(code: String) -> Dictionary:
	return {"accepted": false, "diagnostics": [{"code": code}]}
