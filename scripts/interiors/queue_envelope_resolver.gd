## Pure deterministic resolver for exclusive quarter-tile exterior queue envelopes.
class_name QueueEnvelopeResolver
extends RefCounted

const INPUT_DOMAIN: String = "JANUS_TENANT_QUEUE_INPUT"
const ENVELOPE_DOMAIN: String = "JANUS_TENANT_QUEUE_ENVELOPES"
const DIRECTIONS: Dictionary = {"NORTH": Vector2i(0, -1), "EAST": Vector2i(1, 0), "SOUTH": Vector2i(0, 1), "WEST": Vector2i(-1, 0)}


func resolve(selected_doors: Array, graph: ProspectivePedestrianGraphSnapshot, queue_input: QueueResolutionSnapshot, policy: QueueGeometryPolicy) -> Dictionary:
	if graph == null or queue_input == null or policy == null or not policy.validate_revision_one():
		return _failure("INPUT_INVALID", "QUEUE_RESOLUTION_INPUT_INVALID", {})
	var input_value := queue_input.duplicate_value()
	var diagnostics := QueueResolutionSnapshot.validate_value(input_value)
	if not diagnostics.is_empty(): return {"status": "INPUT_INVALID", "candidate_envelopes": [], "queue_input_fingerprint": "", "queue_envelopes_fingerprint": "", "diagnostics": diagnostics}
	var graph_value := graph.duplicate_value()
	if input_value.get("layout_ref") != graph_value.get("layout_ref") or int(input_value.get("district_revision", -1)) != int(graph_value.get("district_revision", -2)) or int(input_value.get("zone_revision", -1)) != int(graph_value.get("zone_revision", -2)):
		return _failure("INPUT_INVALID", "QUEUE_INPUT_STALE", {})
	var input_hash := CanonicalJsonFingerprint.new().fingerprint(input_value, INPUT_DOMAIN, 1)
	if not bool(input_hash.get("valid", false)): return {"status": "INPUT_INVALID", "candidate_envelopes": [], "queue_input_fingerprint": "", "queue_envelopes_fingerprint": "", "diagnostics": input_hash.get("diagnostics", [])}
	var doors: Array = selected_doors.duplicate(true)
	doors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("door_semantic_key", "")) < String(b.get("door_semantic_key", "")))
	var public_tiles := _point_set(input_value["public_queue_tiles"], "x", "y")
	var forbidden: Dictionary = {}
	for name: String in QueueResolutionSnapshot.QUARTER_COLLECTIONS:
		for key: String in _point_set(input_value[name], "x4", "y4").keys(): forbidden[key] = true
	var work: Array[Dictionary] = []
	for door_value: Variant in doors:
		if not door_value is Dictionary or not _exact_keys(door_value, ["door_semantic_key", "edge", "queue_envelope_key", "minimum_positions", "maximum_positions"]): return _failure("INPUT_INVALID", "QUEUE_DOOR_INVALID", {})
		var edge: Dictionary = door_value["edge"]
		var direction_name := String(edge.get("direction", ""))
		if not DIRECTIONS.has(direction_name) or int(door_value["minimum_positions"]) < 0 or int(door_value["maximum_positions"]) < int(door_value["minimum_positions"]): return _failure("INPUT_INVALID", "QUEUE_DOOR_INVALID", {})
		work.append({"door": door_value, "candidates": _candidates_for_door(door_value, public_tiles, forbidden, policy), "accepted": []})
	var claimed: Dictionary = {}
	for item: Dictionary in work:
		while item["accepted"].size() < int(item["door"]["minimum_positions"]):
			var candidate: Dictionary = _take_next(item, claimed)
			if candidate.is_empty(): return _failure("INPUT_INVALID", "INSUFFICIENT_QUEUE_CAPACITY", {"door_semantic_key": item["door"]["door_semantic_key"]})
			_claim(candidate, claimed); item["accepted"].append(candidate)
	var progressed := true
	while progressed:
		progressed = false
		for item: Dictionary in work:
			if item["accepted"].size() >= int(item["door"]["maximum_positions"]): continue
			var candidate := _take_next(item, claimed)
			if not candidate.is_empty(): _claim(candidate, claimed); item["accepted"].append(candidate); progressed = true
	var envelopes: Array[Dictionary] = []
	for item: Dictionary in work:
		var positions: Array = item["accepted"]
		for index: int in range(positions.size()): positions[index]["position_id"] = "jplan1/queue-position/%s/%d" % [_encode(String(item["door"]["queue_envelope_key"])), index]
		envelopes.append({"queue_envelope_key": item["door"]["queue_envelope_key"], "door_semantic_key": item["door"]["door_semantic_key"], "positions": positions})
	var envelope_hash := CanonicalJsonFingerprint.new().fingerprint(envelopes, ENVELOPE_DOMAIN, 1)
	if not bool(envelope_hash.get("valid", false)): return {"status":"INPUT_INVALID","candidate_envelopes":[],"queue_input_fingerprint":input_hash["fingerprint"],"queue_envelopes_fingerprint":"","diagnostics":envelope_hash.get("diagnostics",[])}
	return {"status": "VALID", "candidate_envelopes": envelopes, "queue_input_fingerprint": input_hash["fingerprint"], "queue_envelopes_fingerprint": envelope_hash["fingerprint"], "diagnostics": []}


func _candidates_for_door(door: Dictionary, public_tiles: Dictionary, forbidden: Dictionary, policy: QueueGeometryPolicy) -> Array[Dictionary]:
	var edge: Dictionary = door["edge"]; var parcel: Dictionary = edge.get("parcel_cell", {})
	var outward: Vector2i = DIRECTIONS[String(edge["direction"])]
	var tangent := Vector2i(-outward.y, outward.x)
	var public_cell := Vector2i(int(parcel.get("x", 0)), int(parcel.get("y", 0))) + outward
	if edge.get("access_cell") is Dictionary: public_cell = Vector2i(int(edge["access_cell"].get("x", 0)), int(edge["access_cell"].get("y", 0)))
	var candidates: Array[Dictionary] = []
	for distance: int in range(1, policy.max_scan_distance_tiles + 1):
		for sign_value: int in [-1, 1]:
			var tile := public_cell + tangent * distance * sign_value
			if not public_tiles.has(_key(tile.x, tile.y)): continue
			for offset: Dictionary in policy.position_offsets:
				var point4 := Vector2i(tile.x * 4 + 2, tile.y * 4 + 2) + tangent * int(offset["frontage_offset4"]) + outward * int(offset["outward_offset4"])
				var conflicts := _conflict_keys(point4, policy.position_reservation_half_extent4)
				var blocked := false
				for key: String in conflicts:
					if forbidden.has(key): blocked = true; break
				if not blocked: candidates.append({"position_id": "", "x4": point4.x, "y4": point4.y, "conflict_keys": conflicts})
	return candidates


func _take_next(item: Dictionary, claimed: Dictionary) -> Dictionary:
	while not item["candidates"].is_empty():
		var candidate: Dictionary = item["candidates"].pop_front()
		var conflict := false
		for key: String in candidate["conflict_keys"]:
			if claimed.has(key): conflict = true; break
		if not conflict: return candidate
	return {}


func _claim(candidate: Dictionary, claimed: Dictionary) -> void:
	for key: String in candidate["conflict_keys"]: claimed[key] = true


func _conflict_keys(point: Vector2i, half_extent: int) -> Array[String]:
	var keys: Array[String] = []
	for y4: int in range(point.y - half_extent, point.y + half_extent):
		for x4: int in range(point.x - half_extent, point.x + half_extent): keys.append(_key(x4, y4))
	return keys


func _point_set(points: Array, x_key: String, y_key: String) -> Dictionary:
	var result: Dictionary = {}
	for point: Dictionary in points: result[_key(int(point[x_key]), int(point[y_key]))] = true
	return result


func _exact_keys(value: Dictionary, expected: Array[String]) -> bool:
	var actual: Array[String] = []; for key: Variant in value.keys(): actual.append(String(key))
	actual.sort(); var wanted := expected.duplicate(); wanted.sort(); return actual == wanted


func _encode(value: String) -> String:
	return value.uri_encode().replace("/", "%2F")


func _key(x: int, y: int) -> String: return "%d,%d" % [x, y]
func _failure(status: String, code: String, values: Dictionary) -> Dictionary: return {"status":status,"candidate_envelopes":[],"queue_input_fingerprint":"","queue_envelopes_fingerprint":"","diagnostics":[{"code":code,"path":"$","values":values.duplicate(true)}]}
