class_name TrafficTopology
extends Node

## H7 sole owner of the immutable RoadGraphSnapshot and ordered deltas.
## TrafficManager receives snapshots and owns only transient cars/reservations.

signal road_graph_published(snapshot: RoadGraphSnapshot)
signal road_graph_delta_published(delta: RoadGraphDelta)

var _district_runtime: DistrictRuntime
var _public_realm_projection: PublicRealmProjection
var _metrics: ProjectionMetrics
var _graph: RoadGraphSnapshot
var _graph_revision: int = 0
var _subscribed: bool = false
var _delta_handler: Callable
var _last_built_district_revision: int = -1
var _last_built_state: Dictionary = {}


func initialize(p_runtime: DistrictRuntime, p_public_realm: PublicRealmProjection, p_metrics: ProjectionMetrics) -> Dictionary:
	if p_runtime == null or p_public_realm == null or p_metrics == null:
		return {"valid": false, "diagnostics": [{"code": "H7_DEPENDENCY_REQUIRED", "message": "District Runtime, H5 public realm, and metrics are required"}]}
	var metrics_validation: Dictionary = p_metrics.validate()
	if not bool(metrics_validation.get("valid", false)):
		return {"valid": false, "diagnostics": metrics_validation.get("diagnostics", [])}
	_district_runtime = p_runtime
	_public_realm_projection = p_public_realm
	_metrics = p_metrics
	if not _subscribed:
		_delta_handler = Callable(self, "_on_district_delta_committed")
		_district_runtime.district_delta_committed.connect(_delta_handler)
		_subscribed = true
	return {"valid": true, "diagnostics": []}


func rebuild() -> Dictionary:
	if _district_runtime != null and _graph != null and _last_built_district_revision == _district_runtime.get_revision() and _last_built_state == _district_runtime.get_state():
		var unchanged_delta: RoadGraphDelta = _build_delta(_graph, _graph, "unchanged")
		return {"valid": true, "snapshot": _graph, "delta": unchanged_delta, "skipped": true, "diagnostics": []}
	if _district_runtime == null or not _district_runtime.has_session():
		return _failure("H7_SESSION_REQUIRED", "a committed district session is required")
	var snapshot: ResolvedDistrictSnapshot = _district_runtime.get_snapshot()
	var state: Dictionary = _district_runtime.get_state()
	var h5_graph: PedestrianGraphSnapshot = _public_realm_projection.get_graph_snapshot()
	var road_profile: Dictionary = _public_realm_projection.get_road_profile_snapshot()
	if h5_graph == null or h5_graph.definition_fingerprint != snapshot.get_fingerprint() or h5_graph.district_revision != int(state.get("district_revision", -1)):
		return _failure("H5_GRAPH_REVISION_MISMATCH", "H7 requires a matching committed H5 graph")
	var built: Dictionary = _build_graph(snapshot, state, h5_graph, road_profile)
	if not bool(built.get("valid", false)):
		return built
	_graph_revision += 1
	var graph: RoadGraphSnapshot = load("res://scripts/traffic/road_graph_snapshot.gd").new() as RoadGraphSnapshot
	graph.initialize(snapshot.get_layout_id(), snapshot.get_fingerprint(), int(state.get("district_revision", -1)), h5_graph.zone_revision, _graph_revision, built.get("lanes", []), built.get("segments", []), built.get("intersections", []), built.get("crosswalks", []), built.get("stops", []), built.get("route_attachments", []), built.get("control_anchors", []), built.get("traffic_controls", []), built.get("outer_ring", {}))
	var delta: RoadGraphDelta = _build_delta(_graph, graph, "initial" if _graph == null else "committed_district_delta")
	_graph = graph
	_last_built_district_revision = int(state.get("district_revision", -1))
	_last_built_state = state.duplicate(true)
	road_graph_published.emit(graph.duplicate_value())
	road_graph_delta_published.emit(delta.duplicate_value())
	return {"valid": true, "snapshot": graph, "delta": delta, "diagnostics": []}


func get_graph_snapshot() -> RoadGraphSnapshot:
	return null if _graph == null else _graph.duplicate_value()


func get_graph_revision() -> int:
	return _graph_revision


func dispose() -> void:
	if _subscribed and _district_runtime != null and _district_runtime.district_delta_committed.is_connected(_delta_handler):
		_district_runtime.district_delta_committed.disconnect(_delta_handler)
	_graph = null
	_district_runtime = null
	_public_realm_projection = null
	_metrics = null
	_last_built_district_revision = -1
	_last_built_state = {}
	_delta_handler = Callable()
	_subscribed = false


static func invalidates_district_operation(operation: String) -> bool:
	return operation == DistrictRuntime.OP_ACQUIRE_SECTION or operation == DistrictRuntime.OP_CONVERT_STREET


func _on_district_delta_committed(envelope: Dictionary) -> void:
	var operation: String = String(envelope.get("delta", {}).get("operation", ""))
	if not invalidates_district_operation(operation):
		return
	var result: Dictionary = rebuild()
	if not bool(result.get("valid", false)):
		push_error("H7 rebuild rejected committed district delta: %s" % result.get("diagnostics", []))


func _build_graph(snapshot: ResolvedDistrictSnapshot, state: Dictionary, h5_graph: PedestrianGraphSnapshot, road_profile: Dictionary) -> Dictionary:
	var profile_segments: Array = road_profile.get("segments", [])
	if profile_segments.is_empty():
		return _failure("H5_ROAD_PROFILE_REQUIRED", "H7 requires committed H5 road-profile descriptors")
	var controlled: Dictionary = _controlled_area(snapshot, state, profile_segments)
	if not bool(controlled.get("connected", false)):
		return {"valid": false, "snapshot": null, "delta": null, "diagnostics": controlled.get("diagnostics", [])}
	var descriptors: Dictionary = {}
	for descriptor: Dictionary in profile_segments:
		descriptors[String(descriptor.get("id", ""))] = descriptor
	var intersections: Array[Dictionary] = []
	for intersection: Dictionary in road_profile.get("intersections", []):
		var incident_ids: Array = intersection.get("incident_segment_ids", []).duplicate(true)
		intersections.append({"id": String(intersection.get("id", "")), "rect_quarter": intersection.get("rect_quarter", {}).duplicate(true), "incident_segment_ids": incident_ids, "surface": String(intersection.get("surface", "")), "owned": bool(intersection.get("owned", false)), "controlled": _intersection_controlled(incident_ids, controlled.get("active_segment_ids", {}))})
	var lanes: Array[Dictionary] = []
	var segments: Array[Dictionary] = []
	var crosswalks: Array[Dictionary] = []
	var stops: Array[Dictionary] = []
	var route_attachments: Array[Dictionary] = []
	var control_anchors: Array[Dictionary] = []
	var traffic_controls: Array[Dictionary] = []
	var segment_active: Dictionary = {}
	for segment: Dictionary in profile_segments:
		var segment_id: String = String(segment.get("id", ""))
		var active: bool = bool(controlled.get("active_segment_ids", {}).get(segment_id, false)) and not bool(segment.get("converted", false)) and String(segment.get("geometry_state", "road")) == "road"
		segment_active[segment_id] = active
		segments.append({"id": segment_id, "orientation": String(segment.get("orientation", "")), "rect_quarter": segment.get("rect_quarter", {}).duplicate(true), "outer_ring": bool(segment.get("outer_ring", false)), "converted": bool(segment.get("converted", false)), "active": active, "controlled": bool(controlled.get("active_segment_ids", {}).get(segment_id, false)), "track_id": String(segment.get("track_id", ""))})
		var crosswalk: Dictionary = segment.get("crosswalk", {})
		if active and bool(crosswalk.get("active", false)):
			var crosswalk_id: String = "%s/midpoint_crosswalk" % segment_id
			var bands: Array = segment.get("pedestrian_bands", [])
			var pole_positions: Array = []
			for band: Dictionary in bands:
				pole_positions.append(_band_world_center(band.get("rect_quarter", {}), 2.5))
			var carriageway: Dictionary = segment.get("carriageway", {})
			var crossing_depth: float = _crossing_depth_tiles(carriageway, String(segment.get("orientation", "")))
			crosswalks.append({"id": crosswalk_id, "segment_id": segment_id, "rect_quarter": crosswalk.get("stripes", []).front().get("rect_quarter", {}) if not crosswalk.get("stripes", []).is_empty() else segment.get("rect_quarter", {}), "outer_ring": bool(segment.get("outer_ring", false)), "traffic_functional": true, "pedestrian_graph_crossing": not bool(segment.get("outer_ring", false)), "pole_positions": pole_positions, "pole_count": pole_positions.size()})
			var offset: float = TrafficControlClock.EAST_WEST_OFFSET_T if String(segment.get("orientation", "")) == "HORIZONTAL" else 0.0
			traffic_controls.append({"id": "%s/control" % crosswalk_id, "crosswalk_id": crosswalk_id, "orientation": String(segment.get("orientation", "")), "outer_ring": bool(segment.get("outer_ring", false)), "pedestrian_graph_crossing": not bool(segment.get("outer_ring", false)), "vehicle_cycle_t": 10.0, "vehicle_green_t": 5.0, "vehicle_yellow_t": 1.0, "vehicle_red_t": 4.0, "pedestrian_red_t": 6.0, "pedestrian_green_t": 4.0, "offset_t": offset, "signal_height_tiles": 2.5, "pole_positions": pole_positions, "pole_count": pole_positions.size(), "canonical_crosswalk_speed_tiles_per_second": TrafficControlClock.CANONICAL_CROSSWALK_SPEED_TILES_PER_SECOND, "crossing_distance_tiles": crossing_depth, "canonical_crossing_time_t": crossing_depth / TrafficControlClock.CANONICAL_CROSSWALK_SPEED_TILES_PER_SECOND})
		if active:
			for stop: Dictionary in segment.get("stop_lines", []):
				stops.append({"id": String(stop.get("id", "")), "segment_id": segment_id, "approach": String(stop.get("approach", "")), "rect_quarter": stop.get("rect_quarter", {}).duplicate(true), "approach_only": bool(stop.get("approach_only", false)), "distance_before_boundary_tiles": float(stop.get("distance_before_boundary_tiles", 0.0))})
	for lane: Dictionary in snapshot.get_data().get("lanes", []):
		var carriageway_id: String = String(lane.get("carriageway_id", ""))
		var carriageway: Dictionary = _record_by_id(snapshot.get_data().get("carriageways", []), carriageway_id)
		var segment_id: String = String(carriageway.get("street_segment_id", ""))
		if segment_id.is_empty() or not bool(segment_active.get(segment_id, false)):
			continue
		var orientation: String = String(descriptors.get(segment_id, {}).get("orientation", ""))
		var endpoints: Dictionary = _lane_endpoints(lane.get("rect_quarter", {}), orientation, String(lane.get("direction", "FORWARD")))
		var start: Vector3 = _world_point(endpoints.get("start", Vector2.ZERO), int(lane.get("pose", {}).get("elevation", 0)))
		var finish: Vector3 = _world_point(endpoints.get("finish", Vector2.ZERO), int(lane.get("pose", {}).get("elevation", 0)))
		var direction: Vector3 = (finish - start).normalized()
		var length: float = start.distance_to(finish)
		var lane_id: String = String(lane.get("id", ""))
		var source_zone: String = _endpoint_intersection_id(endpoints.get("start", Vector2.ZERO), intersections, lane_id + "/source")
		var destination_zone: String = _endpoint_intersection_id(endpoints.get("finish", Vector2.ZERO), intersections, lane_id + "/destination")
		var lane_record: Dictionary = {"id": lane_id, "segment_id": segment_id, "direction": String(lane.get("direction", "")), "rect_quarter": lane.get("rect_quarter", {}).duplicate(true), "start_position": start, "finish_position": finish, "direction_vector": direction, "length": length, "stop_distance": _lane_stop_distance(descriptors.get(segment_id, {}), endpoints.get("start", Vector2.ZERO), String(lane.get("direction", "FORWARD")), length), "source_zone_id": source_zone, "destination_zone_id": destination_zone, "outer_ring": bool(descriptors.get(segment_id, {}).get("outer_ring", false))}
		lanes.append(lane_record)
		var route_id: String = "route/straight/%s" % lane_id
		route_attachments.append({"id": route_id, "kind": "straight_through", "lane_id": lane_id, "segment_id": segment_id, "turn_capable": false, "from_position": start, "to_position": finish, "active": true})
		if lane_record["outer_ring"] or controlled.get("perimeter_segment_ids", {}).has(segment_id) or _is_controlled_perimeter_lane(source_zone, destination_zone, segment_id, controlled.get("active_segment_ids", {}), intersections):
			var anchor_offset: Vector3 = direction * _metrics.grid_unit_size
			control_anchors.append({"id": "%s/spawn" % lane_id, "kind": "spawn", "lane_id": lane_id, "position": start - anchor_offset, "direction": direction, "outside_controlled_area": true})
			control_anchors.append({"id": "%s/despawn" % lane_id, "kind": "despawn", "lane_id": lane_id, "position": finish + anchor_offset, "direction": direction, "outside_controlled_area": true})
	var active_segment_ids: Array[String] = []
	for active_segment_id: String in controlled.get("active_segment_ids", {}).keys():
		active_segment_ids.append(active_segment_id)
	active_segment_ids.sort()
	return {"valid": true, "lanes": lanes, "segments": segments, "intersections": intersections, "crosswalks": crosswalks, "stops": stops, "route_attachments": route_attachments, "control_anchors": control_anchors, "traffic_controls": traffic_controls, "outer_ring": {"segments": _outer_segment_ids(segments), "active_plot_ids": controlled.get("active_plot_ids", []), "rectangles": controlled.get("rectangles", []), "active_segments": active_segment_ids, "connected_controlled_area": controlled.get("connected", false)}, "diagnostics": []}


func _build_delta(previous: RoadGraphSnapshot, current: RoadGraphSnapshot, reason: String) -> RoadGraphDelta:
	var categories: Array[String] = ["lanes", "segments", "intersections", "crosswalks", "stops", "route_attachments", "control_anchors", "traffic_controls"]
	var added: Dictionary = {}
	var changed: Dictionary = {}
	var removed: Dictionary = {}
	for category: String in categories:
		var before: Array = [] if previous == null else previous.get(category)
		var after: Array = current.get(category)
		var before_map: Dictionary = _index_records(before)
		var after_map: Dictionary = _index_records(after)
		for id: String in after_map:
			if not before_map.has(id):
				_add_id(added, category, id)
			elif before_map[id] != after_map[id]:
				_add_id(changed, category, id)
		for id: String in before_map:
			if not after_map.has(id):
				_add_id(removed, category, id)
	var invalid_routes: Array[String] = []
	var invalid_reservations: Array[String] = []
	for category: String in ["route_attachments", "lanes"]:
		for id: Variant in removed.get(category, []):
			invalid_routes.append(String(id))
			invalid_reservations.append(String(id))
		for id: Variant in changed.get(category, []):
			invalid_routes.append(String(id))
			invalid_reservations.append(String(id))
	var attachments: Array[String] = []
	for category: String in ["route_attachments", "control_anchors", "crosswalks", "stops", "traffic_controls"]:
		attachments.append_array(added.get(category, []))
		attachments.append_array(changed.get(category, []))
		attachments.append_array(removed.get(category, []))
	var delta: RoadGraphDelta = load("res://scripts/traffic/road_graph_delta.gd").new() as RoadGraphDelta
	delta.initialize(-1 if previous == null else previous.graph_revision, current.graph_revision, current.district_revision, current.topology_revision, added, changed, removed, invalid_routes, invalid_reservations, attachments, reason)
	return delta


func _controlled_area(snapshot: ResolvedDistrictSnapshot, state: Dictionary, profile_segments: Array) -> Dictionary:
	var rectangles: Array[Dictionary] = []
	var active_ids: Array[String] = []
	for plot: Dictionary in snapshot.get_data().get("plots", []):
		if not _plot_active(snapshot, state, String(plot.get("id", ""))):
			continue
		var rect: Dictionary = plot.get("rect_quarter", {})
		if rect.is_empty():
			continue
		active_ids.append(String(plot.get("id", "")))
		rectangles.append(rect.duplicate(true))
	active_ids.sort()
	var active_segment_ids: Dictionary = {}
	var perimeter_segment_ids: Dictionary = {}
	for descriptor: Dictionary in profile_segments:
		if _has_active_frontage(descriptor.get("frontage", {})):
			var segment_id: String = String(descriptor.get("id", ""))
			active_segment_ids[segment_id] = true
			if _has_inactive_frontage(descriptor.get("frontage", {})):
				perimeter_segment_ids[segment_id] = true
	# H3 owns Plot activation and its orthogonal adjacency gate. H7 consumes
	# that committed result; it does not turn road connectivity into a second
	# acquisition veto (conversion connectivity is explicitly non-blocking).
	var connected: bool = true
	return {"connected": connected, "active_plot_ids": active_ids, "rectangles": rectangles, "active_segment_ids": active_segment_ids, "perimeter_segment_ids": perimeter_segment_ids, "diagnostics": [] if connected else [{"code": "CONTROLLED_AREA_DISCONNECTED", "message": "Active Plot controlled topology must be connected"}]}


func _plot_active(snapshot: ResolvedDistrictSnapshot, state: Dictionary, plot_id: String) -> bool:
	for section: Dictionary in snapshot.get_data().get("sections", []):
		if String(section.get("plot_id", "")) != plot_id:
			continue
		var owned: bool = bool(section.get("initially_owned", false))
		for plot_state: Dictionary in state.get("plot_states", []):
			for override: Dictionary in plot_state.get("section_state_overrides", []):
				if String(override.get("runtime_section_id", "")) == String(section.get("id", "")):
					owned = bool(override.get("owned", owned))
		if owned:
			return true
	return false


func _has_active_frontage(frontage: Dictionary) -> bool:
	for side: String in ["negative", "positive"]:
		for contact: Dictionary in frontage.get(side, {}).get("contacts", []):
			if bool(contact.get("active", false)) and int(contact.get("length_quarter", 0)) > 0:
				return true
	return false


func _has_inactive_frontage(frontage: Dictionary) -> bool:
	for side: String in ["negative", "positive"]:
		for contact: Dictionary in frontage.get(side, {}).get("contacts", []):
			if not bool(contact.get("active", false)) and int(contact.get("length_quarter", 0)) > 0:
				return true
	return false


func _intersection_controlled(incident_ids: Array, active_segment_ids: Dictionary) -> bool:
	for segment_id: String in incident_ids:
		if active_segment_ids.has(segment_id):
			return true
	return false


func _is_controlled_perimeter_lane(source_zone: String, destination_zone: String, segment_id: String, active_segment_ids: Dictionary, intersections: Array[Dictionary]) -> bool:
	for intersection: Dictionary in intersections:
		var intersection_id: String = String(intersection.get("id", ""))
		if intersection_id != source_zone and intersection_id != destination_zone:
			continue
		var active_incident_count: int = 0
		for incident_id: String in intersection.get("incident_segment_ids", []):
			if active_segment_ids.has(incident_id):
				active_incident_count += 1
		if active_incident_count <= 1 and active_segment_ids.has(segment_id):
			return true
	return false


func _lane_endpoints(rectangle: Dictionary, orientation: String, direction: String) -> Dictionary:
	var minimum_x: float = float(rectangle.get("minimum_x4", 0.0))
	var maximum_x: float = float(rectangle.get("maximum_x4", 0.0))
	var minimum_z: float = float(rectangle.get("minimum_z4", 0.0))
	var maximum_z: float = float(rectangle.get("maximum_z4", 0.0))
	var start: Vector2
	var finish: Vector2
	if orientation == "VERTICAL":
		start = Vector2((minimum_x + maximum_x) * 0.5, minimum_z)
		finish = Vector2((minimum_x + maximum_x) * 0.5, maximum_z)
	else:
		start = Vector2(minimum_x, (minimum_z + maximum_z) * 0.5)
		finish = Vector2(maximum_x, (minimum_z + maximum_z) * 0.5)
	if direction == "REVERSE":
		var swap: Vector2 = start
		start = finish
		finish = swap
	return {"start": start, "finish": finish}


func _world_point(quarter: Vector2, elevation: int) -> Vector3:
	return Vector3(_metrics.origin.x + quarter.x * _metrics.grid_unit_size / 4.0, _metrics.origin.y + elevation * _metrics.floor_height, _metrics.origin.z + quarter.y * _metrics.grid_unit_size / 4.0)


func _band_world_center(rectangle: Dictionary, height_tiles: float) -> Vector3:
	var center: Vector2 = Vector2((float(rectangle.get("minimum_x4", 0.0)) + float(rectangle.get("maximum_x4", 0.0))) * 0.5, (float(rectangle.get("minimum_z4", 0.0)) + float(rectangle.get("maximum_z4", 0.0))) * 0.5)
	var result: Vector3 = _world_point(center, 0)
	result.y += height_tiles * _metrics.grid_unit_size
	return result


func _endpoint_intersection_id(position: Vector2, intersections: Array[Dictionary], fallback: String) -> String:
	var best_id: String = fallback
	for intersection: Dictionary in intersections:
		var rect: Dictionary = intersection.get("rect_quarter", {})
		if position.x >= float(rect.get("minimum_x4", 0.0)) and position.x <= float(rect.get("maximum_x4", 0.0)) and position.y >= float(rect.get("minimum_z4", 0.0)) and position.y <= float(rect.get("maximum_z4", 0.0)):
			return String(intersection.get("id", ""))
	return best_id


func _crossing_depth_tiles(carriageway: Dictionary, orientation: String) -> float:
	var rect: Dictionary = carriageway.get("rect_quarter", {})
	var depth_quarter: float = float(rect.get("maximum_z4", 0.0)) - float(rect.get("minimum_z4", 0.0)) if orientation == "HORIZONTAL" else float(rect.get("maximum_x4", 0.0)) - float(rect.get("minimum_x4", 0.0))
	return depth_quarter / 4.0


func _lane_stop_distance(segment: Dictionary, start_quarter: Vector2, direction: String, fallback: float) -> float:
	var stop_name: String = "NEGATIVE_APPROACH" if direction == "FORWARD" else "POSITIVE_APPROACH"
	for stop: Dictionary in segment.get("stop_lines", []):
		if String(stop.get("approach", "")) != stop_name:
			continue
		var rect: Dictionary = stop.get("rect_quarter", {})
		var stop_quarter: Vector2 = Vector2((float(rect.get("minimum_x4", 0.0)) + float(rect.get("maximum_x4", 0.0))) * 0.5, (float(rect.get("minimum_z4", 0.0)) + float(rect.get("maximum_z4", 0.0))) * 0.5)
		var along_quarter: float = stop_quarter.x - start_quarter.x if String(segment.get("orientation", "")) == "HORIZONTAL" else stop_quarter.y - start_quarter.y
		return absf(along_quarter) * _metrics.grid_unit_size / 4.0
	return fallback * 0.45


func _record_by_id(records: Array, record_id: String) -> Dictionary:
	for record: Variant in records:
		if record is Dictionary and String(record.get("id", "")) == record_id:
			return record
	return {}


func _index_records(records: Array) -> Dictionary:
	var result: Dictionary = {}
	for record: Variant in records:
		if record is Dictionary:
			result[String(record.get("id", ""))] = record
	return result


func _add_id(target: Dictionary, category: String, record_id: String) -> void:
	if not target.has(category):
		target[category] = []
	target[category].append(record_id)


func _outer_segment_ids(segments: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for segment: Dictionary in segments:
		if bool(segment.get("outer_ring", false)):
			result.append(String(segment.get("id", "")))
	result.sort()
	return result


func _failure(code: String, message: String) -> Dictionary:
	return {"valid": false, "snapshot": null, "delta": null, "diagnostics": [{"code": code, "message": message}]}
