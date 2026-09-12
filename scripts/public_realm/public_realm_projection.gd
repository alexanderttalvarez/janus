class_name PublicRealmProjection
extends RefCounted

## H5 runtime adapter. It owns public-realm descriptors and the pedestrian
## graph while delegating every generated Node/lifecycle operation to H4.

signal public_realm_rebuilt(manifest: Dictionary)
signal pedestrian_graph_delta_published(delta: Dictionary)
signal public_realm_rejected(diagnostics: Array[Dictionary])

var _runtime: DistrictRuntime
var _coordinator: ProjectionCoordinator
var _metrics: ProjectionMetrics
var _builder: PublicRealmDescriptorBuilder
var _graph: PedestrianGraphSnapshot
var _latest_realm: Dictionary = {}
var _latest_state: Dictionary = {}
var _proxy_anchor_resolutions: Dictionary = {}
var _disposed: bool = false

enum InvalidationScope { NONE, GEOMETRY, TOPOLOGY }


func initialize(runtime: DistrictRuntime, coordinator: ProjectionCoordinator, metrics: ProjectionMetrics) -> Dictionary:
	if runtime == null or coordinator == null or metrics == null:
		return _reject("PUBLIC_REALM_CONFIGURATION_INVALID", "public realm requires runtime, coordinator, and metrics")
	var validation: Dictionary = metrics.validate()
	if not bool(validation.get("valid", false)):
		return {"valid": false, "diagnostics": validation.get("diagnostics", [])}
	_runtime = runtime
	_coordinator = coordinator
	_metrics = metrics.duplicate(true) as ProjectionMetrics
	_builder = load("res://scripts/public_realm/public_realm_descriptor_builder.gd").new() as PublicRealmDescriptorBuilder
	_runtime.set_street_conversion_validator(Callable(_builder, "validate_conversion_intent"))
	if not _runtime.district_delta_committed.is_connected(_on_district_delta_committed):
		_runtime.district_delta_committed.connect(_on_district_delta_committed)
	return {"valid": true, "diagnostics": []}


func rebuild() -> Dictionary:
	if _disposed or _runtime == null or _coordinator == null or _builder == null:
		return _reject("PUBLIC_REALM_DISPOSED", "public realm projection is not configured")
	var current_traversal: DistrictTraversalReadView = _runtime.get_traversal_read_view()
	var current_state: Dictionary = _runtime.get_state()
	if _graph != null and current_traversal != null and int(_latest_realm.get("district_revision", -1)) == _runtime.get_revision() and int(_latest_realm.get("zone_revision", -1)) == current_traversal.zone_revision and _latest_state == current_state:
		return {"valid": true, "manifest": _coordinator.get_manifest(), "graph": _graph, "skipped": true, "diagnostics": []}
	var captured: Dictionary = _runtime.get_state_read()
	var snapshot: ResolvedDistrictSnapshot = captured.get("snapshot") as ResolvedDistrictSnapshot
	var traversal: DistrictTraversalReadView = _runtime.get_traversal_read_view()
	if snapshot == null or traversal == null:
		return _reject("PUBLIC_REALM_INPUT_MISSING", "public realm projection inputs are unavailable")
	var built: Dictionary = _builder.build(snapshot, captured.get("state", {}), traversal, _metrics)
	if not bool(built.get("valid", false)):
		return _reject_diagnostics(built.get("diagnostics", []))
	var request: ProjectionRequest = load("res://scripts/projection/projection_request.gd").new() as ProjectionRequest
	request.definition_fingerprint = snapshot.get_fingerprint()
	request.district_revision = int(captured.get("district_revision", -1))
	request.zone_revision = traversal.zone_revision
	request.affected_scope = {"h5_public_realm": true}
	request.layers = ["PublicRealmProjections"]
	request.editor_mode = false
	request.metrics = _metrics.duplicate(true) as ProjectionMetrics
	request.snapshot = snapshot
	request.state = captured.get("state", {}).duplicate(true)
	request.descriptor_batches = [built.get("batch") as ProjectionDescriptorBatch]
	var request_validation: Dictionary = request.validate()
	if not bool(request_validation.get("valid", false)):
		return _reject_diagnostics(request_validation.get("diagnostics", []))
	var result: ProjectionResult = _coordinator.build(request)
	if not result.valid:
		return _reject_diagnostics(result.diagnostics)
	var previous_graph: PedestrianGraphSnapshot = _graph
	var committed: Dictionary = _coordinator.commit_result(result)
	if not bool(committed.get("valid", false)):
		return _reject_diagnostics(committed.get("diagnostics", []))
	_graph = built.get("graph") as PedestrianGraphSnapshot
	_latest_realm = {"definition_fingerprint": snapshot.get_fingerprint(), "district_revision": int(captured.get("district_revision", -1)), "zone_revision": traversal.zone_revision, "segments": built.get("segments", []).duplicate(true), "intersections": built.get("intersections", []).duplicate(true)}
	_latest_state = captured.get("state", {}).duplicate(true)
	pedestrian_graph_delta_published.emit(_graph_delta(previous_graph, _graph))
	public_realm_rebuilt.emit(committed.get("manifest", {}))
	return {"valid": true, "manifest": committed.get("manifest", {}), "graph": _graph, "diagnostics": []}


## Refresh committed traversal facts without replacing H4/public-realm geometry.
func refresh_topology() -> Dictionary:
	if _disposed or _runtime == null or _builder == null:
		return _reject("PUBLIC_REALM_DISPOSED", "public realm projection is not configured")
	var captured: Dictionary = _runtime.get_state_read()
	var snapshot: ResolvedDistrictSnapshot = captured.get("snapshot") as ResolvedDistrictSnapshot
	var traversal: DistrictTraversalReadView = _runtime.get_traversal_read_view()
	if snapshot == null or traversal == null:
		return _reject("PUBLIC_REALM_INPUT_MISSING", "public realm topology inputs are unavailable")
	var built: Dictionary = _builder.build(snapshot, captured.get("state", {}), traversal, _metrics)
	if not bool(built.get("valid", false)):
		return _reject_diagnostics(built.get("diagnostics", []))
	var previous_graph: PedestrianGraphSnapshot = _graph
	_graph = built.get("graph") as PedestrianGraphSnapshot
	_latest_realm = {
		"definition_fingerprint": snapshot.get_fingerprint(),
		"district_revision": int(captured.get("district_revision", -1)),
		"zone_revision": traversal.zone_revision,
		"segments": built.get("segments", []).duplicate(true),
		"intersections": built.get("intersections", []).duplicate(true),
	}
	_latest_state = captured.get("state", {}).duplicate(true)
	pedestrian_graph_delta_published.emit(_graph_delta(previous_graph, _graph))
	return {"valid": true, "graph": _graph, "geometry_rebuilt": false, "diagnostics": []}


func preview_conversion(street_segment_id: String) -> Dictionary:
	if _runtime == null or _builder == null:
		return _reject("PUBLIC_REALM_DISPOSED", "public realm projection is not configured")
	var snapshot: ResolvedDistrictSnapshot = _runtime.get_snapshot()
	if snapshot == null:
		return _reject("SNAPSHOT_REQUIRED", "conversion preview requires an active district snapshot")
	var plan: Dictionary = _builder.build_conversion_plan(snapshot, _runtime.get_state(), street_segment_id)
	if not bool(plan.get("eligible", false)):
		return _reject_diagnostics(plan.get("diagnostics", []))
	return {"valid": true, "plan": plan, "diagnostics": []}


func commit_conversion(plan: Dictionary) -> Dictionary:
	if _runtime == null:
		return _reject("PUBLIC_REALM_DISPOSED", "public realm projection is not configured")
	if not bool(plan.get("eligible", false)):
		return _reject("CONVERSION_PLAN_INVALID", "only an eligible conversion plan can be committed")
	var intent: Dictionary = {
		"operation": DistrictRuntime.OP_CONVERT_STREET,
		"expected_district_revision": _runtime.get_revision(),
		"street_segment_id": plan.get("street_segment_id", ""),
		"conversion_plan": plan.duplicate(true),
	}
	return _runtime.commit_transaction(intent)


func _graph_delta(previous: PedestrianGraphSnapshot, current: PedestrianGraphSnapshot) -> Dictionary:
	var delta: Dictionary = {"previous_revision": -1, "revision": current.district_revision if current != null else -1, "added_nodes": [], "removed_nodes": [], "changed_nodes": [], "added_edges": [], "removed_edges": [], "changed_edges": []}
	if previous != null:
		delta["previous_revision"] = previous.district_revision
	var previous_nodes: Dictionary = _records_by_id(previous.nodes if previous != null else [])
	var current_nodes: Dictionary = _records_by_id(current.nodes if current != null else [])
	var previous_edges: Dictionary = _records_by_id(previous.edges if previous != null else [])
	var current_edges: Dictionary = _records_by_id(current.edges if current != null else [])
	_fill_delta_records(delta, "nodes", previous_nodes, current_nodes)
	_fill_delta_records(delta, "edges", previous_edges, current_edges)
	return delta


func _records_by_id(records: Array) -> Dictionary:
	var result: Dictionary = {}
	for record: Variant in records:
		if record is Dictionary:
			result[String(record.get("id", ""))] = record
	return result


func _fill_delta_records(delta: Dictionary, label: String, previous: Dictionary, current: Dictionary) -> void:
	for record_id: String in current:
		if not previous.has(record_id):
			delta["added_%s" % label].append(current[record_id].duplicate(true))
		elif previous[record_id] != current[record_id]:
			delta["changed_%s" % label].append(current[record_id].duplicate(true))
	for record_id: String in previous:
		if not current.has(record_id):
			delta["removed_%s" % label].append(previous[record_id].duplicate(true))
	for key: String in ["added_%s" % label, "removed_%s" % label, "changed_%s" % label]:
		delta[key].sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.get("id", "")) < String(right.get("id", "")))


func get_road_profile_snapshot() -> Dictionary:
	return _latest_realm.duplicate(true)


## Return detached public-corridor attachments for committed parcel-door proxies.
func get_service_proxy_attachments() -> Array[Dictionary]:
	var attachments: Array[Dictionary] = []
	if _graph == null:
		return attachments
	for edge: Dictionary in _graph.edges:
		if String(edge.get("kind", "")) != "public_band_physical":
			continue
		var door_id: String = String(edge.get("source_id", ""))
		if door_id.is_empty():
			continue
		attachments.append({
			"door_id": door_id,
			"corridor_anchor_id": "proxy_anchor/%s" % door_id,
			"public_corridor_reachable": true,
			"proxy_enabled": true,
			"topology_revision": _graph.zone_revision,
		})
	attachments.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["door_id"]) < String(right["door_id"]))
	return attachments


## Register derived anchor resolution without making the anchor ID coordinate-derived.
func set_service_proxy_anchor_resolution(anchor_id: String, resolution: Dictionary) -> void:
	if anchor_id.is_empty():
		return
	_proxy_anchor_resolutions[anchor_id] = resolution.duplicate(true)


func resolve_service_proxy_anchor(anchor_id: String) -> Dictionary:
	if not _proxy_anchor_resolutions.has(anchor_id):
		return {"valid": false, "diagnostics": [{"code": "CORRIDOR_ANCHOR_UNRESOLVED"}]}
	var resolution: Dictionary = _proxy_anchor_resolutions[anchor_id].duplicate(true)
	if not bool(resolution.get("valid", false)) or not resolution.get("position", null) is Vector3:
		return {"valid": false, "diagnostics": resolution.get("diagnostics", [{"code": "CORRIDOR_ANCHOR_UNRESOLVED"}])}
	return resolution


func get_graph_snapshot() -> PedestrianGraphSnapshot:
	return null if _graph == null else _graph.duplicate_value()


func dispose() -> void:
	if _runtime != null and _runtime.district_delta_committed.is_connected(_on_district_delta_committed):
		_runtime.district_delta_committed.disconnect(_on_district_delta_committed)
	_disposed = true
	_runtime = null
	_coordinator = null
	_metrics = null
	_builder = null
	_graph = null
	_latest_realm = {}
	_latest_state = {}
	_proxy_anchor_resolutions.clear()


static func invalidation_for_operation(operation: String) -> int:
	if operation == DistrictRuntime.OP_ACQUIRE_SECTION or operation == DistrictRuntime.OP_CONVERT_STREET:
		return InvalidationScope.GEOMETRY
	if operation in [
		DistrictRuntime.OP_CONSTRUCT,
		DistrictRuntime.OP_DEMOLISH_CONSTRUCTION,
		DistrictRuntime.OP_DEMOLISH_FIXED_OCCUPANT,
		DistrictRuntime.OP_PAINT_ZONE,
		DistrictRuntime.OP_SET_MANUAL_DOOR,
	]:
		return InvalidationScope.TOPOLOGY
	return InvalidationScope.NONE


func _on_district_delta_committed(envelope: Dictionary) -> void:
	var operation: String = String(envelope.get("delta", {}).get("operation", ""))
	match invalidation_for_operation(operation):
		InvalidationScope.GEOMETRY:
			rebuild()
		InvalidationScope.TOPOLOGY:
			refresh_topology()


func _reject(code: String, message: String) -> Dictionary:
	return _reject_diagnostics([{"code": code, "message": message}])


func _reject_diagnostics(diagnostics: Array) -> Dictionary:
	var typed: Array[Dictionary] = []
	for diagnostic: Variant in diagnostics:
		if diagnostic is Dictionary:
			typed.append(diagnostic.duplicate(true))
	public_realm_rejected.emit(typed)
	return {"valid": false, "diagnostics": typed}
