class_name CameraGatewayProjection
extends RefCounted

## H6 composition: Active Plot camera envelope plus structural gateway view.
## Both outputs are immutable projections and rebuild from committed reads.

signal rebuilt(camera_bounds: CameraBoundsSnapshot, gateway_eligibility: GatewayEligibilitySnapshot)

var _district_runtime: DistrictRuntime
var _public_realm_projection: PublicRealmProjection
var _camera_manager: Node3D
var _metrics: ProjectionMetrics
var _margin_policy: CameraMarginPolicy = CameraMarginPolicy.new()
var _legacy_camera_adapter: LegacyCameraBoundsAdapter = LegacyCameraBoundsAdapter.new()
var _camera_bounds: CameraBoundsSnapshot
var _gateway_eligibility: GatewayEligibilitySnapshot
var _subscribed: bool = false
var _delta_handler: Callable
var _session_handler: Callable


func initialize(
	p_district_runtime: DistrictRuntime,
	p_public_realm_projection: PublicRealmProjection,
	p_camera_manager: Node3D,
	p_metrics: ProjectionMetrics
) -> Dictionary:
	if p_district_runtime == null or p_public_realm_projection == null or p_metrics == null:
		return {"valid": false, "diagnostics": [{"code": "H6_DEPENDENCY_REQUIRED", "message": "District Runtime, H5 projection, and metrics are required"}]}
	_district_runtime = p_district_runtime
	_public_realm_projection = p_public_realm_projection
	_camera_manager = p_camera_manager
	_metrics = p_metrics
	if not _subscribed:
		_delta_handler = Callable(self, "_on_district_delta_committed")
		_session_handler = Callable(self, "_on_session_replaced")
		_district_runtime.district_delta_committed.connect(_delta_handler)
		_district_runtime.session_replaced.connect(_session_handler)
		_subscribed = true
	return {"valid": true, "diagnostics": []}


func rebuild() -> Dictionary:
	if _district_runtime == null or not _district_runtime.has_session():
		return {"valid": false, "diagnostics": [{"code": "H6_SESSION_REQUIRED", "message": "a committed district session is required"}]}
	var snapshot: ResolvedDistrictSnapshot = _district_runtime.get_snapshot()
	var state: Dictionary = _district_runtime.get_state()
	var graph: PedestrianGraphSnapshot = _public_realm_projection.get_graph_snapshot()
	var road_profile: Dictionary = _public_realm_projection.get_road_profile_snapshot()
	if graph == null:
		return {"valid": false, "diagnostics": [{"code": "H5_GRAPH_REQUIRED", "message": "H6 requires the committed H5 pedestrian graph"}]}
	if graph.definition_fingerprint != snapshot.get_fingerprint() or graph.district_revision != int(state.get("district_revision", -1)):
		return {"valid": false, "diagnostics": [{"code": "H6_REVISION_MISMATCH", "message": "H5 graph does not match the committed district snapshot"}]}
	var margin_result: Dictionary = _margin_policy.calculate(road_profile, _metrics.grid_unit_size)
	if not bool(margin_result.get("valid", false)):
		return {"valid": false, "diagnostics": margin_result.get("diagnostics", [])}
	var active: Array[Dictionary] = _legacy_camera_adapter.get_active_plot_records(snapshot, state)
	var active_ids: Array[String] = []
	var rectangles: Array[Dictionary] = []
	for plot: Dictionary in active:
		var plot_id: String = String(plot.get("id", ""))
		active_ids.append(plot_id)
		var expanded: Dictionary = _expand_rect(plot.get("rect_quarter", {}), float(margin_result["margin_quarter"]), plot_id)
		if not expanded.is_empty():
			rectangles.append(expanded)
	active_ids.sort()
	var bounds: CameraBoundsSnapshot = load("res://scripts/camera/camera_bounds_snapshot.gd").new() as CameraBoundsSnapshot
	bounds.initialize(snapshot.get_fingerprint(), int(state.get("district_revision", -1)), graph.zone_revision, active_ids, rectangles, float(margin_result["margin"]), float(margin_result["margin_quarter"]), _metrics.grid_unit_size, _metrics.origin)
	var gateways: GatewayEligibilitySnapshot = _build_gateway_snapshot(snapshot, state, graph)
	_camera_bounds = bounds
	_gateway_eligibility = gateways
	if _camera_manager != null and _camera_manager.has_method("set_camera_bounds_snapshot"):
		_camera_manager.call("set_camera_bounds_snapshot", bounds)
	rebuilt.emit(bounds.duplicate_value(), gateways.duplicate_value())
	return {"valid": true, "camera_bounds": bounds, "gateway_eligibility": gateways, "diagnostics": []}


func get_camera_bounds_snapshot() -> CameraBoundsSnapshot:
	return null if _camera_bounds == null else _camera_bounds.duplicate_value()


func get_gateway_eligibility_snapshot() -> GatewayEligibilitySnapshot:
	return null if _gateway_eligibility == null else _gateway_eligibility.duplicate_value()


func dispose() -> void:
	if _subscribed and _district_runtime != null:
		if _district_runtime.district_delta_committed.is_connected(_delta_handler):
			_district_runtime.district_delta_committed.disconnect(_delta_handler)
		if _district_runtime.session_replaced.is_connected(_session_handler):
			_district_runtime.session_replaced.disconnect(_session_handler)
	_camera_bounds = null
	_gateway_eligibility = null
	if _camera_manager != null and _camera_manager.has_method("set_camera_bounds_snapshot"):
		_camera_manager.call("set_camera_bounds_snapshot", null)
	_district_runtime = null
	_public_realm_projection = null
	_camera_manager = null
	_metrics = null
	_subscribed = false
	_delta_handler = Callable()
	_session_handler = Callable()


func _on_district_delta_committed(_envelope: Dictionary) -> void:
	var result: Dictionary = rebuild()
	if not bool(result.get("valid", false)):
		push_error("H6 rebuild rejected committed district delta: %s" % result.get("diagnostics", []))


func _on_session_replaced(_layout_id: String, _fingerprint: String) -> void:
	var result: Dictionary = rebuild()
	if not bool(result.get("valid", false)):
		push_error("H6 rebuild rejected replaced district session: %s" % result.get("diagnostics", []))


func _expand_rect(rectangle: Dictionary, margin_quarter: float, source_plot_id: String) -> Dictionary:
	if rectangle.is_empty():
		return {}
	return {
		"source_plot_id": source_plot_id,
		"minimum_x4": float(rectangle.get("minimum_x4", 0.0)) - margin_quarter,
		"maximum_x4": float(rectangle.get("maximum_x4", 0.0)) + margin_quarter,
		"minimum_z4": float(rectangle.get("minimum_z4", 0.0)) - margin_quarter,
		"maximum_z4": float(rectangle.get("maximum_z4", 0.0)) + margin_quarter,
	}


func _build_gateway_snapshot(snapshot: ResolvedDistrictSnapshot, state: Dictionary, graph: PedestrianGraphSnapshot) -> GatewayEligibilitySnapshot:
	var entries: Array[Dictionary] = []
	var attachments: Array = snapshot.get_data().get("arrival_source_attachments", [])
	attachments.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.get("authored_id", "")) < String(right.get("authored_id", "")))
	for attachment: Dictionary in attachments:
		var projection: GatewayProjection = load("res://scripts/camera/gateway_projection.gd").new() as GatewayProjection
		projection.initialize(attachment)
		var reasons: Array[String] = []
		var static_attachment: bool = not projection.topology_attachment_id.is_empty()
		if not static_attachment:
			reasons.append("MISSING_STATIC_ATTACHMENT")
		var graph_present: bool = _graph_contains_node(graph, projection.topology_attachment_id)
		if not graph_present:
			reasons.append("ATTACHMENT_ABSENT_FROM_COMMITTED_GRAPH")
		var source_enabled: bool = _source_enabled(attachment, state)
		if not source_enabled:
			reasons.append("SOURCE_DISABLED")
		var active_plot: bool = _selector_plot_active(snapshot, state, projection.authored_selector)
		if not active_plot:
			reasons.append("SOURCE_PLOT_INACTIVE")
		var structural: bool = static_attachment and graph_present and String(attachment.get("mode", "")) == "PEDESTRIAN"
		if String(attachment.get("mode", "")) != "PEDESTRIAN":
			reasons.append("SOURCE_MODE_NOT_PEDESTRIAN")
		entries.append({
			"arrival_source_id": projection.arrival_source_id,
			"gateway_projection": projection.value(),
			"source_enabled": source_enabled,
			"structurally_eligible": structural,
			"active_plot": active_plot,
			"eligible": structural and source_enabled and active_plot,
			"reason_codes": reasons,
		})
	var result: GatewayEligibilitySnapshot = load("res://scripts/camera/gateway_eligibility_snapshot.gd").new() as GatewayEligibilitySnapshot
	result.initialize(snapshot.get_fingerprint(), int(state.get("district_revision", -1)), graph.zone_revision, entries)
	return result


func _graph_contains_node(graph: PedestrianGraphSnapshot, node_id: String) -> bool:
	var expected_id: String = "public_band/%s" % node_id
	for node: Dictionary in graph.nodes:
		if String(node.get("id", "")) == expected_id or String(node.get("source_id", "")) == node_id:
			return true
	return false


func _source_enabled(attachment: Dictionary, state: Dictionary) -> bool:
	var source_id: String = String(attachment.get("authored_id", ""))
	for source_state: Dictionary in state.get("arrival_source_states", []):
		if String(source_state.get("arrival_source_id", "")) == source_id:
			return bool(source_state.get("enabled", false))
	return bool(attachment.get("initially_enabled", false))


func _selector_plot_active(snapshot: ResolvedDistrictSnapshot, state: Dictionary, selector: Dictionary) -> bool:
	var authored_slot_id: String = String(selector.get("slot_id", ""))
	for plot: Dictionary in snapshot.get_data().get("plots", []):
		var resolved_slot_id: String = String(plot.get("slot_id", ""))
		var slot_parts: PackedStringArray = resolved_slot_id.split("/")
		if resolved_slot_id == authored_slot_id or slot_parts.has(authored_slot_id):
			if _legacy_camera_adapter.is_plot_active(snapshot, state, String(plot.get("id", ""))):
				return true
	return false
