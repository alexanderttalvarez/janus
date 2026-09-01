class_name PedestrianGraphSnapshot
extends RefCounted

## Immutable derived pedestrian graph. It contains stable IDs and value data,
## never Node references or mutable authority objects.

var definition_fingerprint: String = ""
var district_revision: int = -1
var zone_revision: int = -1
var nodes: Array[Dictionary] = []
var edges: Array[Dictionary] = []


func initialize(p_fingerprint: String, p_district_revision: int, p_zone_revision: int, p_nodes: Array, p_edges: Array) -> void:
	definition_fingerprint = p_fingerprint
	district_revision = p_district_revision
	zone_revision = p_zone_revision
	nodes = _typed_copy(p_nodes)
	edges = _typed_copy(p_edges)


func duplicate_value() -> PedestrianGraphSnapshot:
	var copy: PedestrianGraphSnapshot = load("res://scripts/public_realm/pedestrian_graph_snapshot.gd").new() as PedestrianGraphSnapshot
	copy.initialize(definition_fingerprint, district_revision, zone_revision, nodes, edges)
	return copy


func value() -> Dictionary:
	return {
		"definition_fingerprint": definition_fingerprint,
		"district_revision": district_revision,
		"zone_revision": zone_revision,
		"nodes": nodes.duplicate(true),
		"edges": edges.duplicate(true),
	}


func _typed_copy(records: Array) -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	for record: Variant in records:
		if record is Dictionary:
			copied.append(record.duplicate(true))
	return copied
