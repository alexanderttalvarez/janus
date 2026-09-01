class_name RoadGraphDelta
extends RefCounted

## Ordered immutable graph replacement delta. Invalid routes and reservations
## are listed for TrafficManager cleanup; H7 never owns those reservations.

var previous_graph_revision: int = -1
var graph_revision: int = -1
var district_revision: int = -1
var topology_revision: int = -1
var added_ids: Dictionary = {}
var changed_ids: Dictionary = {}
var removed_ids: Dictionary = {}
var invalid_route_ids: Array[String] = []
var invalid_reservation_ids: Array[String] = []
var attachment_ids: Array[String] = []
var reason: String = ""


func initialize(
	p_previous_graph_revision: int,
	p_graph_revision: int,
	p_district_revision: int,
	p_topology_revision: int,
	p_added_ids: Dictionary,
	p_changed_ids: Dictionary,
	p_removed_ids: Dictionary,
	p_invalid_route_ids: Array,
	p_invalid_reservation_ids: Array,
	p_attachment_ids: Array,
	p_reason: String
) -> void:
	previous_graph_revision = p_previous_graph_revision
	graph_revision = p_graph_revision
	district_revision = p_district_revision
	topology_revision = p_topology_revision
	added_ids = _copy_id_map(p_added_ids)
	changed_ids = _copy_id_map(p_changed_ids)
	removed_ids = _copy_id_map(p_removed_ids)
	invalid_route_ids = _sorted_strings(p_invalid_route_ids)
	invalid_reservation_ids = _sorted_strings(p_invalid_reservation_ids)
	attachment_ids = _sorted_strings(p_attachment_ids)
	reason = p_reason


func duplicate_value() -> RoadGraphDelta:
	var copy: RoadGraphDelta = load("res://scripts/traffic/road_graph_delta.gd").new() as RoadGraphDelta
	copy.initialize(previous_graph_revision, graph_revision, district_revision, topology_revision, added_ids, changed_ids, removed_ids, invalid_route_ids, invalid_reservation_ids, attachment_ids, reason)
	return copy


func value() -> Dictionary:
	return {
		"previous_graph_revision": previous_graph_revision,
		"graph_revision": graph_revision,
		"district_revision": district_revision,
		"topology_revision": topology_revision,
		"added_ids": added_ids.duplicate(true),
		"changed_ids": changed_ids.duplicate(true),
		"removed_ids": removed_ids.duplicate(true),
		"invalid_route_ids": invalid_route_ids.duplicate(),
		"invalid_reservation_ids": invalid_reservation_ids.duplicate(),
		"attachment_ids": attachment_ids.duplicate(),
		"reason": reason,
	}


func _copy_id_map(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source.keys():
		var values: Array = source[key].duplicate(true)
		values.sort()
		result[String(key)] = values
	return result


func _sorted_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		result.append(String(value))
	result.sort()
	return result
