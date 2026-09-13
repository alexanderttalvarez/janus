## Canonicalizes detached prospective topology without querying live owners.
class_name ProspectivePedestrianGraphBuilder
extends RefCounted


func build(input: Dictionary) -> Dictionary:
	var expected: Array[String] = ["layout_ref", "district_revision", "zone_revision", "nodes", "edges"]
	if not _exact_keys(input, expected) or not input.get("nodes") is Array or not input.get("edges") is Array:
		return {"valid": false, "diagnostics": [_d("GRAPH_INPUT_INVALID", "$", {})]}
	var nodes: Array = input["nodes"].duplicate(true)
	nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("semantic_key", "")) < String(b.get("semantic_key", "")))
	var edges: Array = input["edges"].duplicate(true)
	for edge_value: Variant in edges:
		if edge_value is Dictionary and String(edge_value.get("from_semantic_key", "")) > String(edge_value.get("to_semantic_key", "")):
			var swap: Variant = edge_value["from_semantic_key"]
			edge_value["from_semantic_key"] = edge_value["to_semantic_key"]
			edge_value["to_semantic_key"] = swap
	edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("semantic_key", "")) < String(b.get("semantic_key", "")))
	var made := ProspectivePedestrianGraphSnapshot.make_value(input["layout_ref"], int(input["district_revision"]), int(input["zone_revision"]), nodes, edges)
	if not bool(made.get("valid", false)): return made
	var snapshot := ProspectivePedestrianGraphSnapshot.new()
	var configured := snapshot.configure(made["value"])
	if not bool(configured.get("valid", false)): return configured
	return {"valid": true, "snapshot": snapshot, "value": snapshot.duplicate_value(), "diagnostics": []}


func _exact_keys(value: Dictionary, expected: Array[String]) -> bool:
	var actual: Array[String] = []
	for key: Variant in value.keys(): actual.append(String(key))
	actual.sort(); var wanted := expected.duplicate(); wanted.sort(); return actual == wanted


func _d(code: String, path: String, values: Dictionary) -> Dictionary:
	return {"code": code, "path": path, "values": values.duplicate(true)}
