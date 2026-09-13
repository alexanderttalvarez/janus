## Immutable canonical prospective topology used only by detached H2 planning.
class_name ProspectivePedestrianGraphSnapshot
extends RefCounted

const SCHEMA_ID: String = "prospective_pedestrian_graph"
const SCHEMA_VERSION: int = 1
const FINGERPRINT_DOMAIN: String = "JANUS_TENANT_PROSPECTIVE_GRAPH"
const NODE_KINDS: Array[String] = ["PUBLIC_BAND", "FLOOR_CELL", "VERTICAL_LINK_ENDPOINT"]
const EDGE_KINDS: Array[String] = ["PUBLIC_PATH", "CROSSWALK", "FLOOR_CIRCULATION", "VERTICAL_LINK", "PARCEL_DOOR"]
var _value: Dictionary = {}


func configure(value: Dictionary) -> Dictionary:
	var diagnostics := validate_value(value)
	if not diagnostics.is_empty(): return {"valid": false, "diagnostics": diagnostics}
	_value = value.duplicate(true)
	return {"valid": true, "diagnostics": []}


func duplicate_value() -> Dictionary:
	return _value.duplicate(true)


static func make_value(layout_ref: Dictionary, district_revision: int, zone_revision: int, nodes: Array, edges: Array) -> Dictionary:
	var payload := {"layout_ref": layout_ref.duplicate(true), "district_revision": district_revision, "zone_revision": zone_revision, "nodes": nodes.duplicate(true), "edges": edges.duplicate(true)}
	var hashed := CanonicalJsonFingerprint.new().fingerprint(payload, FINGERPRINT_DOMAIN, SCHEMA_VERSION)
	if not bool(hashed.get("valid", false)): return {"valid": false, "diagnostics": hashed.get("diagnostics", [])}
	var value := payload.duplicate(true)
	value["schema_id"] = SCHEMA_ID; value["schema_version"] = SCHEMA_VERSION; value["topology_fingerprint"] = hashed["fingerprint"]
	return {"valid": true, "value": value, "diagnostics": []}


static func validate_value(value: Dictionary) -> Array[Dictionary]:
	var keys: Array[String] = ["schema_id", "schema_version", "layout_ref", "district_revision", "zone_revision", "nodes", "edges", "topology_fingerprint"]
	if not _exact_keys(value, keys) or value.get("schema_id") != SCHEMA_ID or value.get("schema_version") != SCHEMA_VERSION:
		return [_d("GRAPH_SCHEMA_INVALID", "$", {})]
	if not value.get("nodes") is Array or not value.get("edges") is Array or not value.get("district_revision") is int or int(value["district_revision"]) < 0 or not value.get("zone_revision") is int or int(value["zone_revision"]) < 0:
		return [_d("GRAPH_VALUE_INVALID", "$", {})]
	var node_keys: Dictionary = {}; var previous := ""
	for index: int in range(value["nodes"].size()):
		var node: Variant = value["nodes"][index]
		if not node is Dictionary or not _exact_keys(node, ["semantic_key", "kind", "source_id"]) or String(node.get("semantic_key", "")).is_empty() or not NODE_KINDS.has(String(node.get("kind", ""))) or String(node.get("source_id", "")).is_empty() or node_keys.has(node["semantic_key"]) or (not previous.is_empty() and String(node["semantic_key"]) < previous): return [_d("GRAPH_NODE_INVALID", "$.nodes[%d]" % index, {})]
		node_keys[node["semantic_key"]] = true; previous = node["semantic_key"]
	previous = ""
	for index: int in range(value["edges"].size()):
		var edge: Variant = value["edges"][index]
		if not edge is Dictionary or not _exact_keys(edge, ["semantic_key", "from_semantic_key", "to_semantic_key", "kind", "source_id"]) or String(edge.get("semantic_key", "")).is_empty() or not EDGE_KINDS.has(String(edge.get("kind", ""))) or not node_keys.has(edge.get("from_semantic_key")) or not node_keys.has(edge.get("to_semantic_key")) or String(edge["from_semantic_key"]) >= String(edge["to_semantic_key"]) or (not previous.is_empty() and String(edge["semantic_key"]) <= previous): return [_d("GRAPH_EDGE_INVALID", "$.edges[%d]" % index, {})]
		previous = edge["semantic_key"]
	var payload := {"layout_ref": value["layout_ref"], "district_revision": value["district_revision"], "zone_revision": value["zone_revision"], "nodes": value["nodes"], "edges": value["edges"]}
	var hashed := CanonicalJsonFingerprint.new().fingerprint(payload, FINGERPRINT_DOMAIN, SCHEMA_VERSION)
	if not bool(hashed.get("valid", false)) or hashed.get("fingerprint") != value.get("topology_fingerprint"): return [_d("GRAPH_FINGERPRINT_INVALID", "$.topology_fingerprint", {})]
	return []


static func _exact_keys(value: Dictionary, expected: Array[String]) -> bool:
	var actual: Array[String] = []; for key: Variant in value.keys(): actual.append(String(key))
	actual.sort(); var wanted := expected.duplicate(); wanted.sort(); return actual == wanted


static func _d(code: String, path: String, values: Dictionary) -> Dictionary:
	return {"code": code, "path": path, "values": values.duplicate(true)}
