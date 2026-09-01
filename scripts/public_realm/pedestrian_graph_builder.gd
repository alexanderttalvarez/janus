class_name PedestrianGraphBuilder
extends RefCounted

## H5 final pedestrian graph builder. It merges public topology with the H3
## traversal view and never allocates tenant doors or writes authority.


func build(
	snapshot: ResolvedDistrictSnapshot,
	state: Dictionary,
	traversal: DistrictTraversalReadView,
	segments: Array[Dictionary],
	intersections: Array[Dictionary]
) -> Dictionary:
	if snapshot == null or traversal == null:
		return _failure("GRAPH_INPUT_REQUIRED", "pedestrian graph requires snapshot and traversal view")
	var validation: Dictionary = traversal.validate(snapshot)
	if not bool(validation.get("valid", false)):
		return {"valid": false, "diagnostics": validation.get("diagnostics", [])}
	var nodes: Dictionary = {}
	var edges: Array[Dictionary] = []
	var data: Dictionary = snapshot.get_data()
	var bands_by_id: Dictionary = {}
	for band: Dictionary in data.get("pedestrian_bands", []):
		var band_id: String = String(band.get("id", ""))
		bands_by_id[band_id] = band
		_add_node(nodes, "public_band/%s" % band_id, {"kind": "PUBLIC_BAND", "source_id": band_id, "rect_quarter": band.get("rect_quarter", {})})
	for segment: Dictionary in segments:
		var street_id: String = String(segment.get("id", ""))
		var bands: Array = segment.get("pedestrian_bands", [])
		if bool(segment.get("converted", false)):
			_add_edge(edges, "converted_street/%s" % street_id, "public_band/%s" % String(bands[0].get("id", "")) if bands.size() > 0 else street_id, "public_band/%s" % String(bands[1].get("id", "")) if bands.size() > 1 else street_id, "converted_street", street_id)
		elif not bool(segment.get("outer_ring", false)):
			var crosswalk: Dictionary = segment.get("crosswalk", {})
			if bool(crosswalk.get("active", false)):
				_add_edge(edges, "crosswalk/%s" % street_id, "public_band/%s" % String(bands[0].get("id", "")) if bands.size() > 0 else street_id, "public_band/%s" % String(bands[1].get("id", "")) if bands.size() > 1 else street_id, "midpoint_crosswalk", street_id)
	_add_public_band_path_edges(edges, segments)
	for intersection: Dictionary in intersections:
		var incident: Array = intersection.get("incident_segment_ids", [])
		var exterior_by_side: Dictionary = {}
		for street_id: String in incident:
			var segment: Dictionary = _segment_by_id(segments, street_id)
			if bool(segment.get("converted", false)):
				continue
			for band: Dictionary in segment.get("pedestrian_bands", []):
				var side: String = String(band.get("side", ""))
				if not exterior_by_side.has(side):
					exterior_by_side[side] = []
				exterior_by_side[side].append(String(band.get("id", "")))
		for side: String in exterior_by_side:
			var side_bands: Array = exterior_by_side[side]
			for index: int in range(1, side_bands.size()):
				_add_edge(edges, "band_turn/%s/%s/%d" % [intersection.get("id", ""), side, index], "public_band/%s" % side_bands[index - 1], "public_band/%s" % side_bands[index], "band_intersection_exterior", String(intersection.get("id", "")))
	for record: Dictionary in traversal.floor_circulation_edges:
		_add_node(nodes, "floor_cell/%s" % String(record.get("from_cell_id", "")), {"kind": "FLOOR_CELL", "source_id": record.get("from_cell_id", "")})
		_add_node(nodes, "floor_cell/%s" % String(record.get("to_cell_id", "")), {"kind": "FLOOR_CELL", "source_id": record.get("to_cell_id", "")})
		_add_edge(edges, "floor_circulation/%s" % String(record.get("edge_id", "")), "floor_cell/%s" % String(record.get("from_cell_id", "")), "floor_cell/%s" % String(record.get("to_cell_id", "")), String(record.get("kind", "floor_circulation")), String(record.get("edge_id", "")))
	for record: Dictionary in traversal.vertical_links:
		_add_node(nodes, "floor_cell/%s" % String(record.get("from_cell_id", "")), {"kind": "FLOOR_CELL", "source_id": record.get("from_cell_id", "")})
		_add_node(nodes, "floor_cell/%s" % String(record.get("to_cell_id", "")), {"kind": "FLOOR_CELL", "source_id": record.get("to_cell_id", "")})
		_add_edge(edges, "vertical_link/%s" % String(record.get("link_id", "")), "floor_cell/%s" % String(record.get("from_cell_id", "")), "floor_cell/%s" % String(record.get("to_cell_id", "")), String(record.get("kind", "vertical")), String(record.get("link_id", "")))
	for record: Dictionary in traversal.door_access_edges:
		var external_ref: String = String(record.get("external_ref", ""))
		if not bands_by_id.has(external_ref) or String(record.get("access_kind", "")) != "public_band_physical":
			continue
		var from_id: String = "floor_cell/%s" % String(record.get("interior_cell_id", ""))
		var to_id: String = "public_band/%s" % external_ref
		_add_node(nodes, from_id, {"kind": "FLOOR_CELL", "source_id": record.get("interior_cell_id", "")})
		_add_edge(edges, "public_band_edge/%s/%s" % [external_ref, record.get("door_edge_id", "")], from_id, to_id, "public_band_physical", String(record.get("door_edge_id", "")))
	var ordered_nodes: Array[Dictionary] = []
	for node_id: String in nodes.keys():
		var node: Dictionary = nodes[node_id].duplicate(true)
		node["id"] = node_id
		ordered_nodes.append(node)
	ordered_nodes.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["id"]) < String(right["id"]))
	edges.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["id"]) < String(right["id"]))
	var graph: PedestrianGraphSnapshot = load("res://scripts/public_realm/pedestrian_graph_snapshot.gd").new() as PedestrianGraphSnapshot
	graph.initialize(snapshot.get_fingerprint(), traversal.district_revision, traversal.zone_revision, ordered_nodes, edges)
	return {"valid": true, "snapshot": graph, "diagnostics": []}


func _add_public_band_path_edges(edges: Array[Dictionary], segments: Array[Dictionary]) -> void:
	var segments_by_boundary: Dictionary = {}
	for segment: Dictionary in segments:
		var boundary_id: String = String(segment.get("boundary_id", ""))
		var track_index: int = _suffix_index(String(segment.get("track_id", "")))
		if not segments_by_boundary.has(boundary_id):
			segments_by_boundary[boundary_id] = {}
		segments_by_boundary[boundary_id][track_index] = segment
	for boundary_id: String in segments_by_boundary:
		var by_track: Dictionary = segments_by_boundary[boundary_id]
		for track_key: Variant in by_track.keys():
			var track_index: int = int(track_key)
			if not by_track.has(track_index + 1):
				continue
			var left: Dictionary = by_track[track_index]
			var right: Dictionary = by_track[track_index + 1]
			var left_bands: Dictionary = _bands_by_side(left.get("pedestrian_bands", []))
			var right_bands: Dictionary = _bands_by_side(right.get("pedestrian_bands", []))
			for side: String in left_bands:
				if right_bands.has(side):
					_add_edge(edges, "public_band_path/%s/%s/%s" % [boundary_id, track_index, side], "public_band/%s" % String(left_bands[side]), "public_band/%s" % String(right_bands[side]), "public_band_path", boundary_id)


func _bands_by_side(bands: Array) -> Dictionary:
	var result: Dictionary = {}
	for band: Variant in bands:
		if band is Dictionary:
			result[String(band.get("side", ""))] = String(band.get("id", ""))
	return result


func _suffix_index(value: String) -> int:
	var digits: String = ""
	for character: String in value:
		if character.is_valid_int():
			digits += character
	return digits.to_int() if not digits.is_empty() else -1


func _add_node(nodes: Dictionary, node_id: String, value: Dictionary) -> void:
	if not nodes.has(node_id):
		nodes[node_id] = value.duplicate(true)


func _add_edge(edges: Array[Dictionary], edge_id: String, from_id: String, to_id: String, kind: String, source_id: String) -> void:
	if from_id.is_empty() or to_id.is_empty():
		return
	edges.append({"id": edge_id, "from": from_id, "to": to_id, "kind": kind, "source_id": source_id})


func _segment_by_id(segments: Array[Dictionary], segment_id: String) -> Dictionary:
	for segment: Dictionary in segments:
		if String(segment.get("id", "")) == segment_id:
			return segment
	return {}


func _failure(code: String, message: String) -> Dictionary:
	return {"valid": false, "snapshot": null, "diagnostics": [{"code": code, "message": message}]}
