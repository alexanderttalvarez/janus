class_name VisitorServiceProxy
extends RefCounted

const SCHEMA_VERSION: int = 1
const FIELDS: Array[String] = ["schema_version", "parcel_door_proxy_id", "tenant_id", "parcel_id", "door_id", "corridor_anchor_id", "tenant_active", "public_corridor_reachable", "proxy_enabled", "queue_accepting", "proxy_policy_revision", "topology_revision", "tenant_revision"]
var _data: Dictionary = {}


func configure(values: Dictionary) -> void:
	_data = values.duplicate(true)


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


func validate() -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	for key: Variant in _data.keys():
		if not FIELDS.has(String(key)):
			diagnostics.append({"code": "SERVICE_PROXY_UNKNOWN_FIELD", "path": "$.%s" % String(key)})
	for field: String in FIELDS:
		if not _data.has(field):
			diagnostics.append({"code": "SERVICE_PROXY_INVALID", "path": "$.%s" % field})
	for field: String in ["parcel_door_proxy_id", "tenant_id", "parcel_id", "door_id", "corridor_anchor_id"]:
		if String(_data.get(field, "")).is_empty():
			diagnostics.append({"code": "SERVICE_PROXY_INVALID", "path": "$.%s" % field})
	for field: String in ["proxy_policy_revision", "topology_revision", "tenant_revision"]:
		if int(_data.get(field, -1)) < 0:
			diagnostics.append({"code": "SERVICE_PROXY_INVALID", "path": "$.%s" % field})
	for field: String in ["node", "node_path", "tenant_scene", "interior_geometry", "price", "revenue", "capacity", "satisfaction"]:
		if _data.has(field):
			diagnostics.append({"code": "SERVICE_PROXY_FORBIDDEN_FIELD", "path": "$.%s" % field})
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}


static func select_canonical(proxies: Array[Dictionary]) -> Dictionary:
	var eligible: Array[Dictionary] = []
	for proxy_data: Dictionary in proxies:
		var proxy := VisitorServiceProxy.new()
		proxy.configure(proxy_data)
		if not bool(proxy.validate().get("valid", false)):
			continue
		if not bool(proxy_data.get("tenant_active", false)) or not bool(proxy_data.get("public_corridor_reachable", false)) or not bool(proxy_data.get("proxy_enabled", false)) or not bool(proxy_data.get("queue_accepting", false)):
			continue
		eligible.append(proxy_data.duplicate(true))
	eligible.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return _canonical_id_less(String(first["parcel_door_proxy_id"]), String(second["parcel_door_proxy_id"])))
	if eligible.is_empty():
		return {"valid": false, "diagnostics": [{"code": "SERVICE_PROXY_UNAVAILABLE"}]}
	return {"valid": true, "proxy": eligible[0], "diagnostics": []}


static func _canonical_id_less(left: String, right: String) -> bool:
	var left_bytes: PackedByteArray = left.to_utf8_buffer()
	var right_bytes: PackedByteArray = right.to_utf8_buffer()
	var count: int = mini(left_bytes.size(), right_bytes.size())
	for index: int in range(count):
		if left_bytes[index] == right_bytes[index]:
			continue
		return left_bytes[index] < right_bytes[index]
	return left_bytes.size() < right_bytes.size()
