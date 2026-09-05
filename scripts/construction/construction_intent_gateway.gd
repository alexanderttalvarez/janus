class_name ConstructionIntentGateway
extends RefCounted

## Presentation-facing typed gateway. Preview and confirm always re-enter H3.

var _runtime: DistrictRuntime
var _confirmed_requests: Dictionary = {}


func initialize(runtime: DistrictRuntime) -> Dictionary:
	_runtime = runtime
	return {"valid": _runtime != null, "diagnostics": [] if _runtime != null else [{"code": "DISTRICT_RUNTIME_REQUIRED", "message": "construction gateway requires District Runtime"}]}


func preview(intent: Dictionary) -> Dictionary:
	var normalized: Dictionary = _normalize_request(intent)
	if not bool(normalized.get("valid", false)):
		return normalized
	if _runtime == null:
		return _failure("DISTRICT_RUNTIME_REQUIRED", "construction gateway is not initialized")
	var result: Dictionary = _runtime.preview_construction(normalized["intent"])
	result["request_id"] = String(normalized["intent"].get("request_id", ""))
	return result


func confirm(intent: Dictionary) -> Dictionary:
	var normalized: Dictionary = _normalize_request(intent)
	if not bool(normalized.get("valid", false)):
		return normalized
	var request_id: String = String(normalized["intent"].get("request_id", ""))
	if _confirmed_requests.has(request_id):
		return _failure("CONSTRUCTION_REQUEST_ALREADY_CONFIRMED", "construction confirmation is single-use")
	if _runtime == null:
		return _failure("DISTRICT_RUNTIME_REQUIRED", "construction gateway is not initialized")
	var result: Dictionary = _runtime.commit_construction(normalized["intent"])
	if bool(result.get("valid", false)):
		_confirmed_requests[request_id] = true
	result["request_id"] = request_id
	return result


func _normalize_request(input: Dictionary) -> Dictionary:
	var intent: Dictionary = input.duplicate(true)
	var request_id: String = String(intent.get("request_id", ""))
	if request_id.is_empty():
		return _failure("CONSTRUCTION_REQUEST_ID_REQUIRED", "construction request requires a stable request ID")
	intent["operation"] = DistrictRuntime.OP_CONSTRUCT
	if not intent.has("expected_district_revision"):
		return _failure("REVISION_REQUIRED", "construction request requires expected district revision")
	return {"valid": true, "intent": intent, "diagnostics": []}


func _failure(code: String, message: String) -> Dictionary:
	return {"valid": false, "diagnostics": [{"code": code, "message": message}]}
