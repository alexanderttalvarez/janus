## ManualDoorAuthority — transient endpoint composition and command gateway.
class_name ManualDoorAuthority
extends RefCounted


const TRANSIT_TYPOLOGY: int = 2

var _district_runtime: DistrictRuntime
var _zone_manager: Node


func configure(district_runtime: DistrictRuntime, zone_manager: Node) -> void:
	_district_runtime = district_runtime
	_zone_manager = zone_manager


func get_district_revision() -> int:
	return -1 if _district_runtime == null else _district_runtime.get_revision()


func get_zone_revision() -> int:
	if _zone_manager == null or not _zone_manager.has_method("get_district_revision"):
		return -1
	return int(_zone_manager.call("get_district_revision"))


func get_records() -> Array[Dictionary]:
	if _district_runtime == null or not _district_runtime.has_session():
		return []
	var records: Array[Dictionary] = []
	for value: Variant in _district_runtime.get_state().get("manual_door_records", []):
		if value is Dictionary:
			records.append(value.duplicate(true))
	return records


func has_manual_door(intent: Dictionary) -> bool:
	var normalized: Dictionary = _normalize_intent(intent)
	if not bool(normalized.get("valid", false)):
		return false
	var key: String = _record_key(normalized["intent"])
	for record: Dictionary in get_records():
		if _record_key(record) == key:
			return true
	return false


func preview_manual_door(intent: Dictionary) -> Dictionary:
	var prepared: Dictionary = _prepare_intent(intent)
	if not bool(prepared.get("valid", false)):
		return prepared
	var context_result: Dictionary = _compose_context(prepared["intent"])
	if not bool(context_result.get("valid", false)):
		return context_result
	var legality: Dictionary = _evaluate_legality(prepared["intent"], context_result["from_district"], context_result["to_district"], context_result["from_zone"], context_result["to_zone"])
	if not bool(legality.get("valid", false)):
		return legality
	var result: Dictionary = _district_runtime.preview_transaction(prepared["intent"])
	result["manual_door_context"] = context_result["context"].duplicate(true)
	return result


func commit_manual_door(intent: Dictionary) -> Dictionary:
	var prepared: Dictionary = _prepare_intent(intent)
	if not bool(prepared.get("valid", false)):
		return prepared
	var context_result: Dictionary = _compose_context(prepared["intent"])
	if not bool(context_result.get("valid", false)):
		return context_result
	var legality: Dictionary = _evaluate_legality(prepared["intent"], context_result["from_district"], context_result["to_district"], context_result["from_zone"], context_result["to_zone"])
	if not bool(legality.get("valid", false)):
		return legality
	var result: Dictionary = _district_runtime.commit_transaction(prepared["intent"])
	if bool(result.get("valid", false)):
		result["manual_door_context"] = context_result["context"].duplicate(true)
	return result


func _prepare_intent(intent: Dictionary) -> Dictionary:
	if _district_runtime == null or not _district_runtime.has_session():
		return _failure("SESSION_REQUIRED", "ManualDoorAuthority requires an active District Runtime session")
	var normalized_result: Dictionary = _normalize_intent(intent)
	if not bool(normalized_result.get("valid", false)):
		return normalized_result
	var normalized: Dictionary = normalized_result["intent"]
	if not intent.has("expected_district_revision") or typeof(intent["expected_district_revision"]) != TYPE_INT:
		return _failure("REVISION_REQUIRED", "manual door commands require expected_district_revision")
	if not intent.has("expected_zone_revision") or typeof(intent["expected_zone_revision"]) != TYPE_INT:
		return _failure("ZONE_REVISION_REQUIRED", "manual door commands require expected_zone_revision")
	normalized["expected_district_revision"] = int(intent["expected_district_revision"])
	normalized["expected_zone_revision"] = int(intent["expected_zone_revision"])
	return {"valid": true, "intent": normalized, "diagnostics": []}


func _normalize_intent(intent: Dictionary) -> Dictionary:
	var required: Array[String] = ["runtime_plot_id", "floor_id", "elevation", "from_cell", "to_cell", "enabled"]
	for key: String in required:
		if not intent.has(key):
			return _failure("MANUAL_DOOR_FIELD_REQUIRED", "manual door intent requires %s" % key)
	if typeof(intent["runtime_plot_id"]) != TYPE_STRING or typeof(intent["floor_id"]) != TYPE_STRING or typeof(intent["elevation"]) != TYPE_INT or typeof(intent["enabled"]) != TYPE_BOOL:
		return _failure("MANUAL_DOOR_INTENT_TYPE_INVALID", "manual door intent fields have invalid types")
	var from_value: Variant = intent["from_cell"]
	var to_value: Variant = intent["to_cell"]
	if not _valid_cell(from_value) or not _valid_cell(to_value):
		return _failure("MANUAL_DOOR_CELL_INVALID", "manual door endpoints must be integer [x,y] pairs")
	var from: Array = [int(from_value[0]), int(from_value[1])]
	var to: Array = [int(to_value[0]), int(to_value[1])]
	if from == to or absi(from[0] - to[0]) + absi(from[1] - to[1]) != 1:
		return _failure("MANUAL_DOOR_EDGE_INVALID", "manual door endpoints must be orthogonally adjacent")
	if from[1] > to[1] or (from[1] == to[1] and from[0] > to[0]):
		var swap: Array = from
		from = to
		to = swap
	var normalized: Dictionary = intent.duplicate(true)
	normalized["operation"] = DistrictRuntime.OP_SET_MANUAL_DOOR
	normalized["from_cell"] = from
	normalized["to_cell"] = to
	return {"valid": true, "intent": normalized, "diagnostics": []}


func _compose_context(intent: Dictionary) -> Dictionary:
	var plot_id: String = String(intent["runtime_plot_id"])
	var floor_id: String = String(intent["floor_id"])
	var elevation: int = int(intent["elevation"])
	var from_address: Dictionary = {"runtime_plot_id": plot_id, "floor_id": floor_id, "elevation": elevation, "cell": intent["from_cell"]}
	var to_address: Dictionary = {"runtime_plot_id": plot_id, "floor_id": floor_id, "elevation": elevation, "cell": intent["to_cell"]}
	var from_district: Dictionary = _district_runtime.get_manual_door_district_view(from_address)
	var to_district: Dictionary = _district_runtime.get_manual_door_district_view(to_address)
	if not bool(from_district.get("resolved", false)) or not bool(to_district.get("resolved", false)):
		return _failure("MANUAL_DOOR_ENDPOINT_UNRESOLVED", "manual door endpoint is not in the resolved district")
	if int(intent["expected_district_revision"]) != int(from_district.get("district_revision", -1)):
		return _failure("STALE_DISTRICT_REVISION", "district endpoint view is stale")
	if int(intent["expected_district_revision"]) != int(to_district.get("district_revision", -1)):
		return _failure("STALE_DISTRICT_REVISION", "district endpoint view is stale")
	if _zone_manager == null or not _zone_manager.has_method("get_manual_door_zone_view"):
		return _failure("ZONE_ENDPOINT_VIEW_REQUIRED", "ZoneManager endpoint view is required")
	var from_zone: Dictionary = _zone_manager.call("get_manual_door_zone_view", from_address)
	var to_zone: Dictionary = _zone_manager.call("get_manual_door_zone_view", to_address)
	var zone_revision: int = int(from_zone.get("zone_revision", -1))
	if zone_revision != int(to_zone.get("zone_revision", -2)) or int(intent["expected_zone_revision"]) != zone_revision:
		return _failure("STALE_ZONE_REVISION", "zone endpoint view is stale")
	var context: Dictionary = {"district_revision": int(from_district["district_revision"]), "zone_revision": zone_revision, "from": {"district": from_district, "zone": from_zone}, "to": {"district": to_district, "zone": to_zone}}
	return {"valid": true, "from_district": from_district, "to_district": to_district, "from_zone": from_zone, "to_zone": to_zone, "context": context, "diagnostics": []}


func _evaluate_legality(intent: Dictionary, from_district: Dictionary, to_district: Dictionary, from_zone: Dictionary, to_zone: Dictionary) -> Dictionary:
	for endpoint: Dictionary in [from_district, to_district]:
		if not bool(endpoint.get("acquired", false)) or not bool(endpoint.get("constructed", false)):
			return _failure("MANUAL_DOOR_ENDPOINT_NOT_BUILT", "manual door endpoints require acquired and constructed floor cells")
	if not bool(intent["enabled"]):
		if not has_manual_door(intent):
			return _failure("MANUAL_DOOR_NOT_FOUND", "manual door is not committed")
		return {"valid": true, "diagnostics": []}
	var from_zone_id: String = String(from_zone.get("zone_id", ""))
	var to_zone_id: String = String(to_zone.get("zone_id", ""))
	if from_zone_id.is_empty() and to_zone_id.is_empty():
		return _failure("MANUAL_DOOR_CONNECTION_INVALID", "manual doors require a zone endpoint")
	if not from_zone_id.is_empty() and from_zone_id == to_zone_id:
		return _failure("SAME_ZONE_FORBIDDEN", "manual doors cannot connect two cells in the same zone")
	if not from_zone_id.is_empty() and not to_zone_id.is_empty():
		if int(from_zone.get("typology", -1)) != TRANSIT_TYPOLOGY or int(to_zone.get("typology", -1)) != TRANSIT_TYPOLOGY:
			return _failure("INTER_ZONE_REQUIRES_TRANSIT", "inter-zone manual doors require Transit at both endpoints")
		return {"valid": true, "diagnostics": []}
	var zoned: Dictionary = from_zone if not from_zone_id.is_empty() else to_zone
	var external_district: Dictionary = to_district if not from_zone_id.is_empty() else from_district
	if int(zoned.get("typology", -1)) != TRANSIT_TYPOLOGY:
		return _failure("ZONE_TO_CIRCULATION_REQUIRES_TRANSIT", "zone-to-circulation manual doors require Transit")
	if not bool(external_district.get("explicit_circulation", false)):
		return _failure("ZONE_TO_CIRCULATION_REQUIRES_EXPLICIT_CIRCULATION", "zone-to-circulation manual doors require explicit constructed circulation")
	return {"valid": true, "diagnostics": []}


func _valid_cell(value: Variant) -> bool:
	return value is Array and value.size() == 2 and typeof(value[0]) == TYPE_INT and typeof(value[1]) == TYPE_INT and int(value[0]) >= 0 and int(value[1]) >= 0


func _record_key(record: Dictionary) -> String:
	return "%s|%s|%d|%d,%d|%d,%d" % [String(record.get("runtime_plot_id", "")), String(record.get("floor_id", "")), int(record.get("elevation", 0)), int(record.get("from_cell", [0, 0])[0]), int(record.get("from_cell", [0, 0])[1]), int(record.get("to_cell", [0, 0])[0]), int(record.get("to_cell", [0, 0])[1])]


func _failure(code: String, message: String) -> Dictionary:
	return {"valid": false, "diagnostics": [{"code": code, "message": message}]}
