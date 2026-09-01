class_name RoadGraphSnapshot
extends RefCounted

## Immutable H7 road graph. Traffic agents may read this snapshot but never
## write topology, controls, or district state through it.

var layout_id: String = ""
var definition_fingerprint: String = ""
var district_revision: int = -1
var topology_revision: int = -1
var graph_revision: int = -1
var lanes: Array[Dictionary] = []
var segments: Array[Dictionary] = []
var intersections: Array[Dictionary] = []
var crosswalks: Array[Dictionary] = []
var stops: Array[Dictionary] = []
var route_attachments: Array[Dictionary] = []
var control_anchors: Array[Dictionary] = []
var traffic_controls: Array[Dictionary] = []
var outer_ring: Dictionary = {}
var _lane_index: Dictionary = {}
var _route_index: Dictionary = {}


func initialize(
	p_layout_id: String,
	p_definition_fingerprint: String,
	p_district_revision: int,
	p_topology_revision: int,
	p_graph_revision: int,
	p_lanes: Array,
	p_segments: Array,
	p_intersections: Array,
	p_crosswalks: Array,
	p_stops: Array,
	p_route_attachments: Array,
	p_control_anchors: Array,
	p_traffic_controls: Array,
	p_outer_ring: Dictionary
) -> void:
	layout_id = p_layout_id
	definition_fingerprint = p_definition_fingerprint
	district_revision = p_district_revision
	topology_revision = p_topology_revision
	graph_revision = p_graph_revision
	lanes = _copy_sorted(p_lanes, "id")
	segments = _copy_sorted(p_segments, "id")
	intersections = _copy_sorted(p_intersections, "id")
	crosswalks = _copy_sorted(p_crosswalks, "id")
	stops = _copy_sorted(p_stops, "id")
	route_attachments = _copy_sorted(p_route_attachments, "id")
	control_anchors = _copy_sorted(p_control_anchors, "id")
	traffic_controls = _copy_sorted(p_traffic_controls, "id")
	outer_ring = p_outer_ring.duplicate(true)
	_rebuild_indexes()


func duplicate_value() -> RoadGraphSnapshot:
	var copy: RoadGraphSnapshot = load("res://scripts/traffic/road_graph_snapshot.gd").new() as RoadGraphSnapshot
	copy.initialize(layout_id, definition_fingerprint, district_revision, topology_revision, graph_revision, lanes, segments, intersections, crosswalks, stops, route_attachments, control_anchors, traffic_controls, outer_ring)
	return copy


func get_lane(lane_id: String) -> Dictionary:
	return {} if not _lane_index.has(lane_id) else _lane_index[lane_id].duplicate(true)


func get_route(route_id: String) -> Dictionary:
	return {} if not _route_index.has(route_id) else _route_index[route_id].duplicate(true)


func value() -> Dictionary:
	return {
		"layout_id": layout_id,
		"definition_fingerprint": definition_fingerprint,
		"district_revision": district_revision,
		"topology_revision": topology_revision,
		"graph_revision": graph_revision,
		"lanes": lanes.duplicate(true),
		"segments": segments.duplicate(true),
		"intersections": intersections.duplicate(true),
		"crosswalks": crosswalks.duplicate(true),
		"stops": stops.duplicate(true),
		"route_attachments": route_attachments.duplicate(true),
		"control_anchors": control_anchors.duplicate(true),
		"traffic_controls": traffic_controls.duplicate(true),
		"outer_ring": outer_ring.duplicate(true),
	}


func _rebuild_indexes() -> void:
	_lane_index.clear()
	_route_index.clear()
	for lane: Dictionary in lanes:
		_lane_index[String(lane.get("id", ""))] = lane
	for route: Dictionary in route_attachments:
		_route_index[String(route.get("id", ""))] = route


func _copy_sorted(records: Array, key: String) -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	for record: Variant in records:
		if record is Dictionary:
			copied.append(record.duplicate(true))
	copied.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.get(key, "")) < String(right.get(key, "")))
	return copied
