## H6 tests for Active Plot camera unions, H2 gateway pass-through, and eligibility.
extends SceneTree

class FakeEconomy extends DistrictRuntimePorts.DistrictEconomyPort:
	func get_policy_snapshot() -> Dictionary:
		return {"revision": 1, "schema_version": 1}

	func quote(_transaction: Dictionary, _state: Dictionary) -> Dictionary:
		return {"accepted": true, "value": 0, "economy_revision": 1, "diagnostics": []}

	func reserve(_quote: Dictionary) -> Dictionary:
		return {"accepted": true, "reservation_token": {"id": 1}, "diagnostics": []}

	func guarantee_capture(reservation: Dictionary) -> Dictionary:
		return {"accepted": true, "guaranteed_capture_token": reservation, "diagnostics": []}

	func capture(_token: Dictionary) -> Dictionary:
		return {"accepted": true, "diagnostics": []}

	func cancel(_token: Dictionary) -> Dictionary:
		return {"accepted": true, "diagnostics": []}


class FakeProgression extends DistrictRuntimePorts.DistrictProgressionPort:
	var selected_plot_ids: Array = []

	func get_policy_snapshot() -> Dictionary:
		return {"revision": 1, "elevation_eligibility": [0, 1, 2, -1, -2, -3], "selected_plot_ids": selected_plot_ids.duplicate(), "street_conversion_eligible": true}


var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_region_geometry()
	_test_fixture_projection()
	print("Camera H6 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_region_geometry() -> void:
	var bounds: CameraBoundsSnapshot = load("res://scripts/camera/camera_bounds_snapshot.gd").new() as CameraBoundsSnapshot
	bounds.initialize("test", 3, 7, ["plot_b", "plot_a"], [
		{"source_plot_id": "plot_b", "minimum_x4": 20.0, "maximum_x4": 30.0, "minimum_z4": 0.0, "maximum_z4": 10.0},
		{"source_plot_id": "plot_a", "minimum_x4": 0.0, "maximum_x4": 10.0, "minimum_z4": 0.0, "maximum_z4": 10.0},
	], 2.5, 5.0, 1.0, Vector3.ZERO)
	_assert(bounds.active_plot_ids == ["plot_a", "plot_b"], "camera bounds sort Active Plot IDs")
	bounds.selected_plot_ids = ["plot_selected"]
	_assert(bounds.selected_plot_ids == ["plot_selected"], "camera bounds retain selected/unlocked Plot IDs")
	_assert(bounds.contains_world_position(Vector3(1.25, 0.0, 1.25)), "camera union contains the first rectangle")
	_assert(bounds.contains_world_position(Vector3(6.25, 0.0, 1.25)), "camera union contains the disjoint rectangle")
	_assert(not bounds.contains_world_position(Vector3(3.75, 0.0, 1.25)), "camera union preserves a hole between disjoint rectangles")
	var tie: Vector3 = bounds.clamp_world_position(Vector3(3.75, 0.0, 1.25))
	_assert(is_equal_approx(tie.x, 2.5) and is_equal_approx(tie.z, 1.25), "nearest-point tie uses stable rectangle order")
	var corner: Vector3 = bounds.clamp_world_position(Vector3(-1.25, 0.0, -1.25))
	_assert(is_equal_approx(corner.x, 0.0) and is_equal_approx(corner.z, 0.0), "nearest-point clamp chooses the closest rectangle corner")
	var empty: CameraBoundsSnapshot = load("res://scripts/camera/camera_bounds_snapshot.gd").new() as CameraBoundsSnapshot
	empty.initialize("test", 3, 7, [], [], 0.0, 0.0, 1.0, Vector3.ZERO)
	var unchanged: Vector3 = empty.clamp_world_position(Vector3(8.0, 4.0, 9.0))
	_assert(unchanged == Vector3(8.0, 4.0, 9.0), "empty camera union leaves focus position unchanged for safe disable")


func _test_fixture_projection() -> void:
	var factory: RefCounted = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
	var resolver: DistrictLayoutResolver = load("res://scripts/resources/district_layout_resolver.gd").new() as DistrictLayoutResolver
	var resolution: Dictionary = resolver.resolve(factory.build_fixture("C"))
	_assert(bool(resolution.get("valid", false)), "H6 fixture resolves through H1/H2")
	var snapshot: ResolvedDistrictSnapshot = resolution.get("snapshot") as ResolvedDistrictSnapshot
	var runtime: DistrictRuntime = load("res://scripts/district/district_runtime.gd").new() as DistrictRuntime
	_assert(bool(runtime.configure_session_gate(SessionMutationGate.new()).get("valid", false)), "H6 injects the District Runtime session gate")
	var h3_ports: DistrictRuntimePorts.DistrictRuntimePortsBundle = DistrictRuntimePorts.DistrictRuntimePortsBundle.new()
	var progression_port: FakeProgression = FakeProgression.new()
	progression_port.selected_plot_ids = [String(snapshot.get_data().get("plots", [])[1].get("id", ""))]
	h3_ports.initialize(FakeEconomy.new(), DistrictRuntimePorts.DistrictZonePort.new(), progression_port)
	runtime.configure_ports(h3_ports)
	var session: Dictionary = runtime.create_session(snapshot)
	_assert(bool(session.get("valid", false)), "H6 creates a committed H3 session")
	var metrics: ProjectionMetrics = load("res://scripts/projection/projection_metrics.gd").new() as ProjectionMetrics
	metrics.identity = "h6_test_metrics"
	metrics.revision = 1
	metrics.grid_unit_size = 1.0
	metrics.floor_height = 3.0
	metrics.origin = Vector3.ZERO
	var coordinator: ProjectionCoordinator = load("res://scripts/projection/projection_coordinator.gd").new() as ProjectionCoordinator
	get_root().add_child(coordinator)
	_assert(bool(coordinator.configure(runtime, metrics).get("valid", false)), "H6 configures the shared H4 projection")
	_assert(bool(coordinator.rebuild().get("valid", false)), "H6 builds the shared H4 projection")
	var public_projection: PublicRealmProjection = load("res://scripts/public_realm/public_realm_projection.gd").new() as PublicRealmProjection
	_assert(bool(public_projection.initialize(runtime, coordinator, metrics).get("valid", false)), "H6 configures H5 public realm")
	_assert(bool(public_projection.rebuild().get("valid", false)), "H6 consumes the committed H5 projection")
	var h6: CameraGatewayProjection = load("res://scripts/camera/camera_gateway_projection.gd").new() as CameraGatewayProjection
	_assert(bool(h6.initialize(runtime, public_projection, null, metrics).get("valid", false)), "H6 configures camera/gateway composition")
	var built: Dictionary = h6.rebuild()
	_assert(bool(built.get("valid", false)), "H6 builds camera and gateway snapshots")
	public_projection._graph.zone_revision += 1
	var stale_result: Dictionary = h6.rebuild()
	_assert(not bool(stale_result.get("valid", true)) and stale_result.get("diagnostics", [])[0].get("code", "") == "H6_REVISION_MISMATCH", "H6 rejects a stale H5 topology revision")
	public_projection._graph.zone_revision = (built.get("gateway_eligibility") as GatewayEligibilitySnapshot).topology_revision
	_assert(bool(h6.rebuild().get("valid", false)), "H6 retains the last valid projection after stale input rejection")
	var bounds: CameraBoundsSnapshot = built.get("camera_bounds") as CameraBoundsSnapshot
	var gateways: GatewayEligibilitySnapshot = built.get("gateway_eligibility") as GatewayEligibilitySnapshot
	_assert(bounds != null and not bounds.empty and bounds.active_plot_ids.size() > 0, "H6 camera bounds include committed Active Plot records")
	_assert(bounds.selected_plot_ids.size() == 1 and bounds.selected_plot_ids[0] == progression_port.selected_plot_ids[0], "H6 camera bounds expose selected/unlocked Plot records separately")
	_assert(bounds.margin > 0.0 and bounds.margin_quarter > 0.0, "H6 uses a positive road-profile-relative margin")
	var margin_policy: CameraMarginPolicy = load("res://scripts/camera/camera_margin_policy.gd").new() as CameraMarginPolicy
	var narrow_profile: Dictionary = {"segments": [{"orientation": "HORIZONTAL", "carriageway": {"rect_quarter": {"minimum_z4": 0.0, "maximum_z4": 12.0}}, "pedestrian_bands": [{"rect_quarter": {"minimum_z4": -8.0, "maximum_z4": 0.0}}]}]}
	var wide_profile: Dictionary = {"segments": [{"orientation": "HORIZONTAL", "carriageway": {"rect_quarter": {"minimum_z4": 0.0, "maximum_z4": 24.0}}, "pedestrian_bands": [{"rect_quarter": {"minimum_z4": -16.0, "maximum_z4": 0.0}}]}]}
	_assert(float(margin_policy.calculate(wide_profile, 1.0).get("margin_quarter", 0.0)) > float(margin_policy.calculate(narrow_profile, 1.0).get("margin_quarter", 0.0)), "H6 road-profile-relative margin responds to variable road widths")
	_assert(gateways != null and gateways.entries.size() == 4, "H6 projects every H2 arrival source")
	var eligible_count: int = 0
	var h2_passthrough: bool = true
	for entry: Dictionary in gateways.entries:
		if bool(entry.get("eligible", false)):
			eligible_count += 1
		var projection: Dictionary = entry.get("gateway_projection", {})
		var original: Dictionary = {}
		for attachment: Dictionary in snapshot.get_data().get("arrival_source_attachments", []):
			if String(attachment.get("authored_id", "")) == String(entry.get("arrival_source_id", "")):
				original = attachment
				break
		h2_passthrough = h2_passthrough and String(projection.get("topology_attachment_id", "")) == String(original.get("resolved_target_topology_id", "")) and projection.get("baseline_pose", {}) == original.get("pose", {}) and projection.get("authored_selector", {}) == original.get("selector", {})
	_assert(eligible_count > 0, "H6 marks structurally valid enabled gateways eligible")
	_assert(h2_passthrough, "H6 passes H2 attachment, selector, and baseline pose without re-resolution")
	var before_state: Dictionary = runtime.get_state()
	var before_floor_count: int = 0
	for plot_state: Dictionary in before_state.get("plot_states", []):
		before_floor_count += plot_state.get("floor_states", []).size()
	h6.rebuild()
	var after_state: Dictionary = runtime.get_state()
	var after_floor_count: int = 0
	for plot_state: Dictionary in after_state.get("plot_states", []):
		after_floor_count += plot_state.get("floor_states", []).size()
	_assert(before_state == after_state and before_floor_count == after_floor_count, "H6 viewing and eligibility do not mutate district state or allocate FloorState")
	var disabled_source: Dictionary = runtime.commit_transaction({"operation": DistrictRuntime.OP_SET_SOURCE_ENABLED, "expected_district_revision": runtime.get_revision(), "arrival_source_id": "gateway_market_north", "enabled": false})
	_assert(bool(disabled_source.get("valid", false)), "H3 source-state writes remain the only gateway state mutation path")
	var disabled_snapshot: Dictionary = h6.rebuild()
	var disabled_entry: Dictionary = {}
	for entry: Dictionary in (disabled_snapshot.get("gateway_eligibility") as GatewayEligibilitySnapshot).entries:
		if String(entry.get("arrival_source_id", "")) == "gateway_market_north":
			disabled_entry = entry
			break
	_assert(not bool(disabled_entry.get("eligible", true)) and not bool(disabled_entry.get("source_enabled", true)) and disabled_entry.get("reason_codes", []).has("SOURCE_DISABLED"), "H6 reflects current disabled source state with a reason code")
	public_projection.dispose()
	coordinator.dispose()
	coordinator.queue_free()
	runtime.free()


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)
