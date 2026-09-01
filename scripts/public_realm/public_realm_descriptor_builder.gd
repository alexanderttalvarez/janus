class_name PublicRealmDescriptorBuilder
extends RefCounted

## H5 pure public-realm builder. It consumes H2 topology, H3 state/read views,
## and emits semantic descriptors only; H4 owns all Node materialization.

const QUARTER_TILES_PER_TILE: int = 4
const MARKING_WIDTH_QUARTER: int = 1 # 0.25 tile.
const STOP_LINE_WIDTH_QUARTER: int = 2 # 0.50 tile.
const CROSSWALK_STRIPE_WIDTH_QUARTER: int = 2 # 0.50 tile.
const CROSSWALK_LENGTH_QUARTER: int = 20 # 5 tiles along-road.
const LAYER: String = "PublicRealmProjections"
const OWNER_ID: String = "H5PublicRealm"


func build(
	snapshot: ResolvedDistrictSnapshot,
	state: Dictionary,
	traversal: DistrictTraversalReadView,
	metrics: ProjectionMetrics
) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if snapshot == null:
		return _failure("SNAPSHOT_REQUIRED", "public realm requires an immutable H2 snapshot")
	if traversal == null:
		return _failure("TRAVERSAL_VIEW_REQUIRED", "public realm requires the H3 traversal read view")
	var traversal_validation: Dictionary = traversal.validate(snapshot)
	if not bool(traversal_validation.get("valid", false)):
		return {"valid": false, "diagnostics": traversal_validation.get("diagnostics", [])}
	if traversal.district_revision != int(state.get("district_revision", -1)):
		return _failure("TRAVERSAL_REVISION_MISMATCH", "public realm traversal revision does not match district state")
	if metrics == null or not bool(metrics.validate().get("valid", false)):
		return _failure("METRICS_REQUIRED", "public realm projection requires valid presentation metrics")
	var data: Dictionary = snapshot.get_data()
	var batch: ProjectionDescriptorBatch = _new_batch(snapshot, state, traversal)
	var frontage_index: Dictionary = _build_frontage_index(data)
	var segments: Array[Dictionary] = []
	var conversion_plans: Array[Dictionary] = []
	for segment: Dictionary in data.get("street_segments", []):
		var descriptor: Dictionary = _build_segment_descriptor(segment, data, state, frontage_index)
		segments.append(descriptor)
		conversion_plans.append(build_conversion_plan(snapshot, state, String(segment.get("id", "")), frontage_index))
		_add_segment_primitives(batch, descriptor, data)
	var intersections: Array[Dictionary] = []
	for intersection: Dictionary in data.get("intersections", []):
		var intersection_descriptor: Dictionary = _build_intersection_descriptor(intersection, data, state)
		intersections.append(intersection_descriptor)
		_add_intersection_primitive(batch, intersection_descriptor)
	var graph_builder: PedestrianGraphBuilder = load("res://scripts/public_realm/pedestrian_graph_builder.gd").new() as PedestrianGraphBuilder
	var graph_result: Dictionary = graph_builder.build(snapshot, state, traversal, segments, intersections)
	if not bool(graph_result.get("valid", false)):
		return {"valid": false, "diagnostics": graph_result.get("diagnostics", [])}
	return {
		"valid": true,
		"segments": segments,
		"intersections": intersections,
		"conversion_plans": conversion_plans,
		"graph": graph_result.get("snapshot"),
		"batch": batch,
		"diagnostics": diagnostics,
	}


func build_conversion_plan(snapshot: ResolvedDistrictSnapshot, state: Dictionary, street_segment_id: String, frontage_index: Dictionary = {}) -> Dictionary:
	var data: Dictionary = snapshot.get_data() if snapshot != null else {}
	if frontage_index.is_empty() and not data.is_empty():
		frontage_index = _build_frontage_index(data)
	var segment: Dictionary = _record_by_id(data.get("street_segments", []), street_segment_id)
	if segment.is_empty():
		return _conversion_failure(street_segment_id, "STREET_SEGMENT_UNKNOWN", "street segment is unknown")
	var frontage: Dictionary = _frontage_for_segment(segment, data, state, frontage_index)
	var outer: bool = _is_outer_segment(segment, data)
	var converted: bool = _street_is_converted(state, street_segment_id)
	var eligible: bool = not outer and not converted and bool(frontage["negative"]["eligible"]) and bool(frontage["positive"]["eligible"])
	var reason: String = "eligible"
	if outer:
		reason = "outer_ring_immutable"
	elif converted:
		reason = "already_converted"
	elif not bool(frontage["negative"]["eligible"]) or not bool(frontage["positive"]["eligible"]):
		reason = "independent_frontage_threshold"
	var affected_ids: Array[String] = [street_segment_id]
	for band: Dictionary in data.get("pedestrian_bands", []):
		if String(band.get("street_segment_id", "")) == street_segment_id:
			affected_ids.append(String(band.get("id", "")))
	for carriageway: Dictionary in data.get("carriageways", []):
		if String(carriageway.get("street_segment_id", "")) == street_segment_id:
			affected_ids.append(String(carriageway.get("id", "")))
	return {
		"valid": eligible,
		"eligible": eligible,
		"street_segment_id": street_segment_id,
		"outer_ring": outer,
		"already_converted": converted,
		"reason": reason,
		"frontage": frontage,
		"affected_ids": affected_ids,
		"removes": ["road_graph_edges", "carriageway", "lane_markings", "curbs", "midpoint_crosswalk", "stop_lines"],
		"connectivity_disclosed": true,
		"diagnostics": [] if eligible else [{"code": "STREET_CONVERSION_INELIGIBLE", "message": reason}],
	}


func validate_conversion_intent(intent: Dictionary, state: Dictionary, snapshot: ResolvedDistrictSnapshot) -> Dictionary:
	var street_id: String = String(intent.get("street_segment_id", ""))
	var plan: Dictionary = build_conversion_plan(snapshot, state, street_id)
	if not bool(plan.get("eligible", false)):
		return {"valid": false, "diagnostics": plan.get("diagnostics", [])}
	var requested_plan: Dictionary = intent.get("conversion_plan", {})
	if not requested_plan.is_empty() and String(requested_plan.get("street_segment_id", "")) != street_id:
		return _failure("CONVERSION_PLAN_MISMATCH", "conversion plan does not match the requested segment")
	return {"valid": true, "plan": plan, "diagnostics": []}


func _build_segment_descriptor(segment: Dictionary, data: Dictionary, state: Dictionary, frontage_index: Dictionary) -> Dictionary:
	var street_id: String = String(segment.get("id", ""))
	var converted: bool = _street_is_converted(state, street_id)
	var frontage: Dictionary = _frontage_for_segment(segment, data, state, frontage_index)
	var outer: bool = _is_outer_segment(segment, data)
	var bands: Array = []
	for band: Dictionary in data.get("pedestrian_bands", []):
		if String(band.get("street_segment_id", "")) == street_id:
			bands.append({"id": band.get("id", ""), "side": band.get("side", ""), "rect_quarter": band.get("rect_quarter", {})})
	var carriageway: Dictionary = {}
	for candidate: Dictionary in data.get("carriageways", []):
		if String(candidate.get("street_segment_id", "")) == street_id:
			carriageway = candidate
			break
	var lane_markings: Array = _lane_markings(segment, data, carriageway)
	var crosswalk: Dictionary = _crosswalk(segment, carriageway, outer, converted)
	var stop_lines: Array = _stop_lines(segment, carriageway, converted)
	var curbs: Array = _curbs(segment, carriageway, converted, crosswalk)
	return {
		"id": street_id,
		"orientation": segment.get("orientation", ""),
		"boundary_id": segment.get("boundary_id", ""),
		"track_id": segment.get("track_id", ""),
		"rect_quarter": segment.get("rect_quarter", {}),
		"outer_ring": outer,
		"converted": converted,
		"pedestrian_bands": bands,
		"carriageway": carriageway,
		"frontage": frontage,
		"lane_markings": lane_markings,
		"crosswalk": crosswalk,
		"stop_lines": stop_lines,
		"curbs": curbs,
		"geometry_state": "unrestricted_pedestrian" if converted else "road",
	}


func _build_intersection_descriptor(intersection: Dictionary, data: Dictionary, state: Dictionary) -> Dictionary:
	var incident: Array[String] = _incident_segments(intersection, data)
	var internal: Array[String] = []
	for street_id: String in incident:
		var segment: Dictionary = _record_by_id(data.get("street_segments", []), street_id)
		if not _is_outer_segment(segment, data):
			internal.append(street_id)
	var owned: bool = not internal.is_empty()
	for street_id: String in internal:
		if not _street_is_converted(state, street_id):
			owned = false
	return {
		"id": intersection.get("id", ""),
		"rect_quarter": intersection.get("rect_quarter", {}),
		"incident_segment_ids": incident,
		"incident_internal_segment_ids": internal,
		"owned": owned,
		"surface": "unrestricted_pedestrian" if owned else "road",
		"markings": [],
	}


func _add_segment_primitives(batch: ProjectionDescriptorBatch, descriptor: Dictionary, data: Dictionary) -> void:
	var street_id: String = String(descriptor["id"])
	if bool(descriptor["converted"]):
		_add_primitive(batch, "converted_%s" % street_id, street_id, "converted_pedestrian_surface", descriptor["rect_quarter"], {"color": Color(0.72, 0.72, 0.68), "thickness": 0.04})
	else:
		for band: Dictionary in descriptor["pedestrian_bands"]:
			_add_primitive(batch, "%s_band_%s" % [street_id, band["side"]], String(band["id"]), "pedestrian_band_surface", band["rect_quarter"], {"color": Color(0.64, 0.62, 0.56), "thickness": 0.04})
		_add_primitive(batch, "%s_carriageway" % street_id, street_id, "carriageway_surface", descriptor["carriageway"].get("rect_quarter", {}), {"color": Color(0.12, 0.12, 0.13), "thickness": 0.08})
		for marking: Dictionary in descriptor["lane_markings"]:
			_add_primitive(batch, String(marking["id"]), street_id, String(marking["kind"]), marking["rect_quarter"], {"color": Color(0.95, 0.95, 0.9), "thickness": 0.02})
		for curb: Dictionary in descriptor["curbs"]:
			_add_primitive(batch, String(curb["id"]), street_id, "curb", curb["rect_quarter"], {"color": Color(0.38, 0.38, 0.36), "thickness": float(curb["height_tiles"])})
		for stripe: Dictionary in descriptor["crosswalk"].get("stripes", []):
			_add_primitive(batch, String(stripe["id"]), street_id, String(stripe["kind"]), stripe["rect_quarter"], {"color": Color(0.97, 0.97, 0.94) if String(stripe["kind"]) == "crosswalk_white" else Color(0.12, 0.12, 0.13), "thickness": 0.025})
		for stop_line: Dictionary in descriptor["stop_lines"]:
			_add_primitive(batch, String(stop_line["id"]), street_id, "stop_line", stop_line["rect_quarter"], {"color": Color(0.95, 0.95, 0.9), "thickness": 0.025})


func _add_intersection_primitive(batch: ProjectionDescriptorBatch, descriptor: Dictionary) -> void:
	_add_primitive(batch, String(descriptor["id"]), String(descriptor["id"]), "intersection_surface", descriptor["rect_quarter"], {"color": Color(0.12, 0.12, 0.13), "thickness": 0.06})


func _add_primitive(batch: ProjectionDescriptorBatch, primitive_id: String, source_id: String, kind: String, rect: Dictionary, payload: Dictionary) -> void:
	batch.add_primitive({
		"primitive_id": primitive_id,
		"source_id": source_id,
		"layer": LAYER,
		"primitive_kind": kind,
		"rect_quarter": rect.duplicate(true),
		"elevation": 0,
		"presentation_payload": payload.duplicate(true),
	})


func _new_batch(snapshot: ResolvedDistrictSnapshot, state: Dictionary, traversal: DistrictTraversalReadView) -> ProjectionDescriptorBatch:
	var batch: ProjectionDescriptorBatch = load("res://scripts/projection/projection_descriptor_batch.gd").new() as ProjectionDescriptorBatch
	batch.initialize("h5_public_realm", OWNER_ID, snapshot.get_fingerprint(), int(state.get("district_revision", 0)), traversal.zone_revision, {"owner": OWNER_ID}, [])
	return batch


func _frontage_for_segment(segment: Dictionary, data: Dictionary, state: Dictionary, frontage_index: Dictionary) -> Dictionary:
	var sides: Dictionary = {"negative": _frontage_side("NEGATIVE"), "positive": _frontage_side("POSITIVE")}
	var segment_rect: Dictionary = segment.get("rect_quarter", {})
	var orientation: String = String(segment.get("orientation", ""))
	var candidate_plots: Array[Dictionary] = []
	var seen_plot_ids: Dictionary = {}
	var index_prefix: String = "h" if orientation == "HORIZONTAL" else "v"
	var coordinates: Array = [int(segment_rect.get("minimum_z4", 0)), int(segment_rect.get("maximum_z4", 0))] if orientation == "HORIZONTAL" else [int(segment_rect.get("minimum_x4", 0)), int(segment_rect.get("maximum_x4", 0))]
	for coordinate: int in coordinates:
		for plot: Dictionary in frontage_index.get("%s:%d" % [index_prefix, coordinate], []):
			var plot_id: String = String(plot.get("id", ""))
			if not seen_plot_ids.has(plot_id):
				seen_plot_ids[plot_id] = true
				candidate_plots.append(plot)
	for plot: Dictionary in candidate_plots:
		var plot_rect: Dictionary = plot.get("rect_quarter", {})
		var side: String = ""
		var length: int = 0
		if orientation == "HORIZONTAL":
			var overlap_x: int = mini(int(segment_rect.get("maximum_x4", 0)), int(plot_rect.get("maximum_x4", 0))) - maxi(int(segment_rect.get("minimum_x4", 0)), int(plot_rect.get("minimum_x4", 0)))
			if int(plot_rect.get("maximum_z4", 0)) == int(segment_rect.get("minimum_z4", 0)) and overlap_x > 0:
				side = "negative"
				length = overlap_x
			elif int(plot_rect.get("minimum_z4", 0)) == int(segment_rect.get("maximum_z4", 0)) and overlap_x > 0:
				side = "positive"
				length = overlap_x
		else:
			var overlap_z: int = mini(int(segment_rect.get("maximum_z4", 0)), int(plot_rect.get("maximum_z4", 0))) - maxi(int(segment_rect.get("minimum_z4", 0)), int(plot_rect.get("minimum_z4", 0)))
			if int(plot_rect.get("maximum_x4", 0)) == int(segment_rect.get("minimum_x4", 0)) and overlap_z > 0:
				side = "negative"
				length = overlap_z
			elif int(plot_rect.get("minimum_x4", 0)) == int(segment_rect.get("maximum_x4", 0)) and overlap_z > 0:
				side = "positive"
				length = overlap_z
		if not side.is_empty():
			var entry: Dictionary = {"plot_id": plot.get("id", ""), "length_quarter": length, "active": _plot_active(plot, data, state), "contact_kind": "COLLINEAR"}
			sides[side]["contacts"].append(entry)
			sides[side]["total_length_quarter"] += length
			if bool(entry["active"]):
				sides[side]["owned_length_quarter"] += length
	for side_name: String in sides:
		var side_data: Dictionary = sides[side_name]
		side_data["eligible"] = side_data["total_length_quarter"] > 0 and side_data["owned_length_quarter"] * 2 >= side_data["total_length_quarter"]
	return sides


func _build_frontage_index(data: Dictionary) -> Dictionary:
	var index: Dictionary = {}
	for plot: Dictionary in data.get("plots", []):
		var rect: Dictionary = plot.get("rect_quarter", {})
		for key: String in ["h:%d" % int(rect.get("minimum_z4", 0)), "h:%d" % int(rect.get("maximum_z4", 0)), "v:%d" % int(rect.get("minimum_x4", 0)), "v:%d" % int(rect.get("maximum_x4", 0))]:
			if not index.has(key):
				index[key] = []
			index[key].append(plot)
	return index


func _frontage_side(side: String) -> Dictionary:
	return {"side": side, "contacts": [], "total_length_quarter": 0, "owned_length_quarter": 0, "eligible": false}


func _plot_active(plot: Dictionary, data: Dictionary, state: Dictionary) -> bool:
	for section: Dictionary in data.get("sections", []):
		if String(section.get("plot_id", "")) != String(plot.get("id", "")):
			continue
		var owned: bool = bool(section.get("initially_owned", false))
		for plot_state: Dictionary in state.get("plot_states", []):
			if String(plot_state.get("runtime_plot_id", "")) != String(plot.get("id", "")):
				continue
			for override: Dictionary in plot_state.get("section_state_overrides", []):
				if String(override.get("runtime_section_id", "")) == String(section.get("id", "")):
					owned = bool(override.get("owned", owned))
		if owned:
			return true
	return false


func _lane_markings(segment: Dictionary, data: Dictionary, carriageway: Dictionary) -> Array[Dictionary]:
	var lanes: Array[Dictionary] = []
	var carriageway_id: String = String(carriageway.get("id", ""))
	for lane: Dictionary in data.get("lanes", []):
		if String(lane.get("carriageway_id", "")) == carriageway_id:
			lanes.append(lane)
	var markings: Array[Dictionary] = []
	var orientation: String = String(segment.get("orientation", ""))
	if not lanes.is_empty():
		markings.append({"id": "%s_edge_negative" % segment.get("id", ""), "kind": "lane_edge_solid", "side": "NEGATIVE", "rect_quarter": _boundary_line_rect(lanes[0].get("rect_quarter", {}), orientation, "NEGATIVE"), "width_quarter": MARKING_WIDTH_QUARTER})
		markings.append({"id": "%s_edge_positive" % segment.get("id", ""), "kind": "lane_edge_solid", "side": "POSITIVE", "rect_quarter": _boundary_line_rect(lanes[lanes.size() - 1].get("rect_quarter", {}), orientation, "POSITIVE"), "width_quarter": MARKING_WIDTH_QUARTER})
	var previous_direction: String = ""
	for index: int in range(lanes.size()):
		var lane: Dictionary = lanes[index]
		var direction: String = String(lane.get("direction", ""))
		if index > 0:
			var same_direction: bool = direction == previous_direction
			var kind: String = "lane_divider_dashed" if same_direction else "lane_divider_solid"
			var rects: Array[Dictionary] = _divider_rects(lanes[index - 1].get("rect_quarter", {}), lane.get("rect_quarter", {}), orientation, same_direction)
			for rect_index: int in range(rects.size()):
				markings.append({"id": "%s_marking_%d_%d" % [segment.get("id", ""), index, rect_index], "kind": kind, "rect_quarter": rects[rect_index], "width_quarter": MARKING_WIDTH_QUARTER, "direction_group": direction, "pattern": "one_tile_white_one_tile_gap" if same_direction else "solid"})
		previous_direction = direction
	return markings


func _boundary_line_rect(rect: Dictionary, orientation: String, side: String) -> Dictionary:
	if orientation == "HORIZONTAL":
		var z: int = int(rect.get("minimum_z4", 0)) if side == "NEGATIVE" else int(rect.get("maximum_z4", 0)) - MARKING_WIDTH_QUARTER
		return {"minimum_x4": rect.get("minimum_x4", 0), "minimum_z4": z, "maximum_x4": rect.get("maximum_x4", 0), "maximum_z4": z + MARKING_WIDTH_QUARTER}
	var x: int = int(rect.get("minimum_x4", 0)) if side == "NEGATIVE" else int(rect.get("maximum_x4", 0)) - MARKING_WIDTH_QUARTER
	return {"minimum_x4": x, "minimum_z4": rect.get("minimum_z4", 0), "maximum_x4": x + MARKING_WIDTH_QUARTER, "maximum_z4": rect.get("maximum_z4", 0)}


func _divider_rects(left: Dictionary, right: Dictionary, orientation: String, dashed: bool) -> Array[Dictionary]:
	var boundary: int = int(left.get("maximum_z4", 0)) if orientation == "HORIZONTAL" else int(left.get("maximum_x4", 0))
	var minimum: int = int(left.get("minimum_x4", 0)) if orientation == "HORIZONTAL" else int(left.get("minimum_z4", 0))
	var maximum: int = int(left.get("maximum_x4", 0)) if orientation == "HORIZONTAL" else int(left.get("maximum_z4", 0))
	if not dashed:
		return [_span_line_rect(orientation, minimum, maximum, boundary)]
	var result: Array[Dictionary] = []
	var cursor: int = minimum
	var dash_length: int = QUARTER_TILES_PER_TILE
	while cursor < maximum:
		var white_end: int = mini(cursor + dash_length, maximum)
		result.append(_span_line_rect(orientation, cursor, white_end, boundary))
		cursor += dash_length * 2
	return result


func _span_line_rect(orientation: String, minimum: int, maximum: int, boundary: int) -> Dictionary:
	if orientation == "HORIZONTAL":
		return {"minimum_x4": minimum, "minimum_z4": boundary, "maximum_x4": maximum, "maximum_z4": boundary + MARKING_WIDTH_QUARTER}
	return {"minimum_x4": boundary, "minimum_z4": minimum, "maximum_x4": boundary + MARKING_WIDTH_QUARTER, "maximum_z4": maximum}


func _crosswalk(segment: Dictionary, carriageway: Dictionary, outer: bool, converted: bool) -> Dictionary:
	if carriageway.is_empty() or converted:
		return {"active": false, "width_along_road_tiles": 5.0, "stripe_width_tiles": 0.5, "stripes": []}
	var rect: Dictionary = carriageway.get("rect_quarter", {})
	var orientation: String = String(segment.get("orientation", ""))
	var midpoint: int = (int(rect.get("minimum_x4", 0)) + int(rect.get("maximum_x4", 0))) / 2 if orientation == "HORIZONTAL" else (int(rect.get("minimum_z4", 0)) + int(rect.get("maximum_z4", 0))) / 2
	var stripes: Array[Dictionary] = []
	for index: int in range(10):
		var start: int = midpoint - CROSSWALK_LENGTH_QUARTER / 2 + index * CROSSWALK_STRIPE_WIDTH_QUARTER
		var stripe_rect: Dictionary
		if orientation == "HORIZONTAL":
			stripe_rect = {"minimum_x4": start, "minimum_z4": rect.get("minimum_z4", 0), "maximum_x4": start + CROSSWALK_STRIPE_WIDTH_QUARTER, "maximum_z4": rect.get("maximum_z4", 0)}
		else:
			stripe_rect = {"minimum_x4": rect.get("minimum_x4", 0), "minimum_z4": start, "maximum_x4": rect.get("maximum_x4", 0), "maximum_z4": start + CROSSWALK_STRIPE_WIDTH_QUARTER}
		stripes.append({"id": "%s_crosswalk_stripe_%d" % [segment.get("id", ""), index], "kind": "crosswalk_white" if index % 2 == 0 else "crosswalk_exposed_gap", "rect_quarter": stripe_rect, "width_along_road_quarter": CROSSWALK_STRIPE_WIDTH_QUARTER})
	return {"active": true, "outer_ring": outer, "width_along_road_tiles": 5.0, "stripe_width_tiles": 0.5, "stripe_count": 10, "stripes": stripes}


func _stop_lines(segment: Dictionary, carriageway: Dictionary, converted: bool) -> Array[Dictionary]:
	if carriageway.is_empty() or converted:
		return []
	var rect: Dictionary = carriageway.get("rect_quarter", {})
	var orientation: String = String(segment.get("orientation", ""))
	var result: Array[Dictionary] = []
	var minimum: int = int(rect.get("minimum_x4", 0)) if orientation == "HORIZONTAL" else int(rect.get("minimum_z4", 0))
	var maximum: int = int(rect.get("maximum_x4", 0)) if orientation == "HORIZONTAL" else int(rect.get("maximum_z4", 0))
	if maximum - minimum < 16:
		return result
	for side: String in ["NEGATIVE_APPROACH", "POSITIVE_APPROACH"]:
		var center: int = minimum + 8 if side == "NEGATIVE_APPROACH" else maximum - 8
		var line_rect: Dictionary
		if orientation == "HORIZONTAL":
			line_rect = {"minimum_x4": center - STOP_LINE_WIDTH_QUARTER / 2, "minimum_z4": rect.get("minimum_z4", 0), "maximum_x4": center + STOP_LINE_WIDTH_QUARTER / 2, "maximum_z4": rect.get("maximum_z4", 0)}
		else:
			line_rect = {"minimum_x4": rect.get("minimum_x4", 0), "minimum_z4": center - STOP_LINE_WIDTH_QUARTER / 2, "maximum_x4": rect.get("maximum_x4", 0), "maximum_z4": center + STOP_LINE_WIDTH_QUARTER / 2}
		result.append({"id": "%s_stop_%s" % [segment.get("id", ""), side], "approach": side, "approach_only": true, "target": "midpoint_crosswalk_or_intersection_boundary", "distance_before_boundary_tiles": 2.0, "width_quarter": STOP_LINE_WIDTH_QUARTER, "rect_quarter": line_rect})
	return result


func _curbs(segment: Dictionary, carriageway: Dictionary, converted: bool, crosswalk: Dictionary) -> Array[Dictionary]:
	if carriageway.is_empty() or converted:
		return []
	var rect: Dictionary = carriageway.get("rect_quarter", {})
	var orientation: String = String(segment.get("orientation", ""))
	var result: Array[Dictionary] = []
	var gap_start: int = 0
	var gap_end: int = 0
	if bool(crosswalk.get("active", false)):
		if orientation == "HORIZONTAL":
			gap_start = (int(rect.get("minimum_x4", 0)) + int(rect.get("maximum_x4", 0))) / 2 - CROSSWALK_LENGTH_QUARTER / 2
			gap_end = gap_start + CROSSWALK_LENGTH_QUARTER
		else:
			gap_start = (int(rect.get("minimum_z4", 0)) + int(rect.get("maximum_z4", 0))) / 2 - CROSSWALK_LENGTH_QUARTER / 2
			gap_end = gap_start + CROSSWALK_LENGTH_QUARTER
	for side: String in ["NEGATIVE", "POSITIVE"]:
		result.append({"id": "%s_curb_%s" % [segment.get("id", ""), side], "side": side, "continuous": true, "flush_crosswalk_interval": [gap_start, gap_end], "height_tiles": 0.10, "width_tiles": 0.15, "rect_quarter": _boundary_line_rect(rect, orientation, side)})
	return result


func _incident_segments(intersection: Dictionary, data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var h_id: String = String(intersection.get("horizontal_boundary_id", ""))
	var v_id: String = String(intersection.get("vertical_boundary_id", ""))
	var h_index: int = _suffix_index(h_id)
	var v_index: int = _suffix_index(v_id)
	for segment: Dictionary in data.get("street_segments", []):
		var boundary_id: String = String(segment.get("boundary_id", ""))
		var track_id: String = String(segment.get("track_id", ""))
		var track_index: int = _suffix_index(track_id)
		if String(segment.get("orientation", "")) == "HORIZONTAL" and boundary_id == h_id and (track_index == v_index - 1 or track_index == v_index):
			result.append(String(segment.get("id", "")))
		elif String(segment.get("orientation", "")) == "VERTICAL" and boundary_id == v_id and (track_index == h_index - 1 or track_index == h_index):
			result.append(String(segment.get("id", "")))
	result.sort()
	return result


func _suffix_index(value: String) -> int:
	var digits: String = ""
	for character: String in value:
		if character.is_valid_int():
			digits += character
	return digits.to_int() if not digits.is_empty() else -1


func _is_outer_segment(segment: Dictionary, data: Dictionary) -> bool:
	var boundary_id: String = String(segment.get("boundary_id", ""))
	var grid: Dictionary = data.get("grid", {})
	var h_count: int = grid.get("horizontal_boundary_starts_quarter", []).size() - 1
	var v_count: int = grid.get("vertical_boundary_starts_quarter", []).size() - 1
	return (boundary_id == "h0" or boundary_id == "h%d" % h_count or boundary_id == "v0" or boundary_id == "v%d" % v_count)


func _street_is_converted(state: Dictionary, street_id: String) -> bool:
	for street_state: Dictionary in state.get("street_segment_states", []):
		if String(street_state.get("street_segment_id", "")) == street_id:
			return bool(street_state.get("converted", false))
	return false


func _record_by_id(records: Array, record_id: String) -> Dictionary:
	for record: Variant in records:
		if record is Dictionary and String(record.get("id", "")) == record_id:
			return record
	return {}


func _conversion_failure(street_id: String, code: String, message: String) -> Dictionary:
	return {"valid": false, "eligible": false, "street_segment_id": street_id, "diagnostics": [{"code": code, "message": message}]}


func _failure(code: String, message: String) -> Dictionary:
	return {"valid": false, "diagnostics": [{"code": code, "message": message}]}
