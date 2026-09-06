## H8 tests for demand/source separation, immediate realization, rollback, and lifecycle.
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
	func get_policy_snapshot() -> Dictionary:
		return {"revision": 1, "elevation_eligibility": [0, 1, 2, -1, -2, -3], "selected_plot_ids": [], "street_conversion_eligible": true}


var _passed: int = 0
var _failed: int = 0
var _runtime: DistrictRuntime
var _public_projection: PublicRealmProjection
var _h6: CameraGatewayProjection
var _projection_coordinator: ProjectionCoordinator
var _coordinator: ArrivalCoordinator
var _visitor_manager: VisitorManager
var _demand: ArrivalDemandSnapshot


func _init() -> void:
	_setup()
	_test_demand_independence_and_ordering()
	_test_revision_and_eligibility_contracts()
	_test_token_contract()
	_test_immediate_commit_and_event_order()
	_test_pre_append_rollback_and_save_boundary()
	_test_exit_selection()
	_test_global_population_budget()
	_cleanup()
	print("Visitor Arrival H8 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _setup() -> void:
	var factory: RefCounted = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
	var resolver: DistrictLayoutResolver = load("res://scripts/resources/district_layout_resolver.gd").new() as DistrictLayoutResolver
	var resolution: Dictionary = resolver.resolve(factory.build_fixture("A"))
	_assert(bool(resolution.get("valid", false)), "H8 fixture resolves through H1/H2")
	var snapshot: ResolvedDistrictSnapshot = resolution.get("snapshot") as ResolvedDistrictSnapshot
	_runtime = load("res://scripts/district/district_runtime.gd").new() as DistrictRuntime
	var ports: DistrictRuntimePorts.DistrictRuntimePortsBundle = DistrictRuntimePorts.DistrictRuntimePortsBundle.new()
	ports.initialize(FakeEconomy.new(), DistrictRuntimePorts.DistrictZonePort.new(), FakeProgression.new())
	_runtime.configure_ports(ports)
	_assert(bool(_runtime.create_session(snapshot).get("valid", false)), "H8 creates a committed District Runtime session")
	var metrics: ProjectionMetrics = load("res://scripts/projection/projection_metrics.gd").new() as ProjectionMetrics
	metrics.identity = "h8_test_metrics"
	metrics.revision = 1
	metrics.grid_unit_size = 1.0
	metrics.floor_height = 3.0
	metrics.origin = Vector3.ZERO
	_projection_coordinator = load("res://scripts/projection/projection_coordinator.gd").new() as ProjectionCoordinator
	get_root().add_child(_projection_coordinator)
	_assert(bool(_projection_coordinator.configure(_runtime, metrics).get("valid", false)), "H8 configures the shared H4 projection")
	_assert(bool(_projection_coordinator.rebuild().get("valid", false)), "H8 builds the shared H4 projection")
	_public_projection = load("res://scripts/public_realm/public_realm_projection.gd").new() as PublicRealmProjection
	_assert(bool(_public_projection.initialize(_runtime, _projection_coordinator, metrics).get("valid", false)), "H8 configures H5 public realm")
	_assert(bool(_public_projection.rebuild().get("valid", false)), "H8 builds the H5 pedestrian graph")
	_h6 = load("res://scripts/camera/camera_gateway_projection.gd").new() as CameraGatewayProjection
	_assert(bool(_h6.initialize(_runtime, _public_projection, null, metrics).get("valid", false)), "H8 configures H6 eligibility")
	var h6_result: Dictionary = _h6.rebuild()
	_assert(bool(h6_result.get("valid", false)), "H8 builds H6 gateway eligibility")
	_visitor_manager = VisitorManager.new()
	_coordinator = load("res://scripts/simulation/arrival_coordinator.gd").new() as ArrivalCoordinator
	_assert(bool(_coordinator.initialize(_runtime, _public_projection.get_graph_snapshot(), h6_result.get("gateway_eligibility"), _visitor_manager).get("valid", false)), "H8 configures the immediate arrival coordinator")
	_demand = ArrivalDemandSnapshot.new()
	_assert(bool(_demand.initialize("demand_test", 20, [{"purpose": "shopping"}]).get("valid", false)), "H8 accepts a demand-only snapshot")


func _cleanup() -> void:
	if _h6 != null:
		_h6.dispose()
	if _public_projection != null:
		_public_projection.dispose()
	if _visitor_manager != null:
		_visitor_manager.all_visitors.clear()
		_visitor_manager.free()
		_visitor_manager = null
	if _projection_coordinator != null:
		_projection_coordinator.dispose()
		_projection_coordinator.free()
		_projection_coordinator = null
	if _runtime != null:
		_runtime.free()
		_runtime = null


func _test_demand_independence_and_ordering() -> void:
	var first: Dictionary = _coordinator.allocate_source(_demand)
	var alternate := ArrivalDemandSnapshot.new()
	alternate.initialize("demand_other", 20, [{"purpose": "dining", "budget_band": "high"}])
	var second: Dictionary = _coordinator.allocate_source(alternate)
	_assert(bool(first.get("valid", false)) and bool(second.get("valid", false)), "eligible-source allocation accepts independent demand profiles")
	_assert(String(first.get("source", {}).get("arrival_source_id", "")) == "gateway_east", "allocation chooses the first NFC UTF-8 ordered source")
	_assert(String(first.get("source", {}).get("arrival_source_id", "")) == String(second.get("source", {}).get("arrival_source_id", "")), "demand profile does not affect spatial source selection")
	_assert(not first.get("source", {}).has("weight") and not first.get("source", {}).has("capacity"), "MVP allocation does not introduce weighting or capacity policy")
	var invalid_demand := ArrivalDemandSnapshot.new()
	var invalid_result: Dictionary = invalid_demand.initialize("invalid_demand", 1, [{"position": Vector3.ZERO}])
	_assert(not bool(invalid_result.get("valid", false)) and _has_code(invalid_result.get("diagnostics", []), "DEMAND_SPATIAL_FIELD_FORBIDDEN"), "demand rejects spatial source fields")
	_assert(_coordinator._canonical_source_less("e\u0301a", "\u00E9b"), "source ordering normalizes NFC before comparing UTF-8 bytes")


func _test_token_contract() -> void:
	var before_state: Dictionary = _runtime.get_state()
	var gate: ArrivalCommitGate = _coordinator.get_gate()
	var owner: String = "token_test"
	_assert(gate.acquire(owner) and gate.enter_barrier(owner), "shared arrival gate protects source validation")
	var capture: Dictionary = _coordinator.allocate_source(_demand)
	var revisions: Dictionary = capture.get("revisions", {})
	var source_id: String = String(capture.get("source", {}).get("arrival_source_id", ""))
	var issued: Dictionary = _runtime.validate_arrival_source(source_id, _demand.snapshot_id, revisions.get("district_revision", -1), revisions.get("topology_revision", -1), revisions.get("eligibility_revision", -1))
	var token: ArrivalSourceValidationToken = issued.get("token", null) as ArrivalSourceValidationToken
	_assert(bool(issued.get("valid", false)) and token != null and token.is_valid(), "District Runtime issues an ephemeral validation token")
	_assert(_runtime.consume_arrival_source_token(token) and not token.is_valid(), "validation token is single-use")
	_assert(not _runtime.consume_arrival_source_token(token), "consumed token cannot be reused")
	var blocked_mutation: Dictionary = _runtime.commit_transaction({"operation": DistrictRuntime.OP_SET_SOURCE_ENABLED, "arrival_source_id": source_id, "enabled": false, "expected_district_revision": 0})
	_assert(not bool(blocked_mutation.get("valid", false)) and _has_code(blocked_mutation.get("diagnostics", []), "ARRIVAL_TRANSACTION_BUSY"), "arrival barrier blocks intervening district mutation")
	gate.release_barrier(owner)
	gate.release(owner)
	_assert(before_state == _runtime.get_state(), "token validation and consumption do not mutate source state or revision")
	var stale_owner: String = "stale_revision_test"
	_assert(gate.acquire(stale_owner) and gate.enter_barrier(stale_owner), "stale-token test acquires the shared gate")
	var stale_capture: Dictionary = _coordinator.allocate_source(_demand)
	var stale_revisions: Dictionary = stale_capture.get("revisions", {})
	var stale_issued: Dictionary = _runtime.validate_arrival_source(String(stale_capture.get("source", {}).get("arrival_source_id", "")), _demand.snapshot_id, int(stale_revisions.get("district_revision", -1)), int(stale_revisions.get("topology_revision", -1)), int(stale_revisions.get("eligibility_revision", -1)))
	var stale_token: ArrivalSourceValidationToken = stale_issued.get("token", null) as ArrivalSourceValidationToken
	_runtime.set_arrival_revision_context(int(stale_revisions.get("topology_revision", -1)) + 1, int(stale_revisions.get("eligibility_revision", -1)))
	_assert(stale_token != null and not stale_token.is_valid(), "revision changes invalidate unconsumed source tokens")
	_runtime.set_arrival_revision_context(int(stale_revisions.get("topology_revision", -1)), int(stale_revisions.get("eligibility_revision", -1)))
	gate.release_barrier(stale_owner)
	gate.release(stale_owner)


func _test_revision_and_eligibility_contracts() -> void:
	var entries: Array[Dictionary] = _h6.get_gateway_eligibility_snapshot().entries
	for entry: Dictionary in entries:
		entry["structurally_eligible"] = false
	var altered: GatewayEligibilitySnapshot = GatewayEligibilitySnapshot.new()
	var snapshot: ResolvedDistrictSnapshot = _runtime.get_snapshot()
	var graph: PedestrianGraphSnapshot = _public_projection.get_graph_snapshot()
	altered.initialize(snapshot.get_fingerprint(), _runtime.get_revision(), graph.zone_revision, entries)
	_coordinator.set_snapshots(graph, altered)
	var rejected: Dictionary = _coordinator.allocate_source(_demand)
	_assert(not bool(rejected.get("valid", false)) and _has_code(rejected.get("diagnostics", []), "NO_ELIGIBLE_PEDESTRIAN_SOURCE"), "H8 filters out sources that are not structurally eligible")
	_coordinator.set_snapshots(graph, _h6.get_gateway_eligibility_snapshot())
	_assert(bool(_coordinator.allocate_source(_demand).get("valid", false)), "restoring matching H5/H6 snapshots restores allocation")


func _test_immediate_commit_and_event_order() -> void:
	var observed: Array[Dictionary] = []
	_coordinator.arrival_realized.connect(func(envelope: Dictionary) -> void: observed.append(envelope))
	var result: Dictionary = _coordinator.realize_arrival(_demand)
	var visitor: VisitorData = result.get("visitor", null) as VisitorData
	_assert(bool(result.get("valid", false)), "immediate pedestrian realization commits")
	_assert(visitor != null and _visitor_manager.get_active_visitor_count() == 1, "VisitorManager owns the realized visitor after commit")
	_assert(observed.size() == 1 and _coordinator.get_dispatcher().get_entry_count() == 1, "one complete envelope is appended and flushed once")
	_assert(String(visitor.arrival_source_id) == "gateway_east" and String(result.get("envelope", {}).get("demand_snapshot_id", "")) == "demand_test", "realized visitor carries stable source and demand identities")
	_assert(not _coordinator.get_gate().is_held() and not _coordinator.get_gate().is_barrier_active(), "arrival gate and barrier release after synchronous flush")
	_coordinator.get_dispatcher().subscribe(Callable(self, "_fault_subscriber"))
	_coordinator.get_dispatcher().subscribe(Callable(self, "_second_subscriber"))
	var fault_result: Dictionary = _coordinator.realize_arrival(_demand)
	_assert(bool(fault_result.get("valid", false)) and fault_result.get("subscriber_diagnostics", []).size() == 1, "subscriber faults remain isolated after append")


func _test_pre_append_rollback_and_save_boundary() -> void:
	var before_count: int = _visitor_manager.get_active_visitor_count()
	var before_revision: int = _runtime.get_revision()
	_coordinator.get_dispatcher().append_enabled = false
	var append_rejected: Dictionary = _coordinator.realize_arrival(_demand)
	_coordinator.get_dispatcher().append_enabled = true
	_assert(not bool(append_rejected.get("valid", false)) and _has_code(append_rejected.get("diagnostics", []), "ARRIVAL_APPEND_PREFLIGHT_FAILED"), "disabled append capability rejects before state swap")
	_coordinator.get_dispatcher().append_preflight_enabled = true
	_visitor_manager.prepare_arrival_enabled = false
	var prepare_rejected: Dictionary = _coordinator.realize_arrival(_demand)
	_visitor_manager.prepare_arrival_enabled = true
	_assert(not bool(prepare_rejected.get("valid", false)) and _has_code(prepare_rejected.get("diagnostics", []), "VISITOR_PREPARE_FAILED"), "detached visitor preparation failure is pre-append")
	_visitor_manager.commit_arrival_enabled = false
	var commit_rejected: Dictionary = _coordinator.realize_arrival(_demand)
	_visitor_manager.commit_arrival_enabled = true
	_assert(not bool(commit_rejected.get("valid", false)) and _has_code(commit_rejected.get("diagnostics", []), "VISITOR_COMMIT_FAILED"), "visitor state swap failure is pre-append")
	_coordinator.get_dispatcher().append_preflight_enabled = false
	var rejected: Dictionary = _coordinator.realize_arrival(_demand)
	_coordinator.get_dispatcher().append_preflight_enabled = true
	_assert(not bool(rejected.get("valid", false)) and _has_code(rejected.get("diagnostics", []), "ARRIVAL_APPEND_PREFLIGHT_FAILED"), "append-capability rejection occurs before commit")
	_assert(_visitor_manager.get_active_visitor_count() == before_count and _runtime.get_revision() == before_revision, "pre-append failure restores visitor state and leaves District Runtime unchanged")
	var save_manager: Node = get_root().get_node_or_null("SaveManager")
	var gate: ArrivalCommitGate = _coordinator.get_gate()
	if save_manager != null:
		save_manager.set_arrival_commit_gate(gate)
		var owner: String = "save_barrier_test"
		_assert(gate.acquire(owner) and gate.enter_barrier(owner), "save barrier test acquires the shared arrival gate")
		var blocked_load: Dictionary = save_manager.load_game(1)
		var blocked_save: Error = save_manager.save_game(1)
		_assert(_has_code(blocked_load.get("diagnostics", []), "ARRIVAL_TRANSACTION_BUSY") and blocked_save == ERR_BUSY, "direct SaveManager entry points remain blocked through the arrival barrier")
		gate.release_barrier(owner)
		gate.release(owner)
	var serialized: Dictionary = _visitor_manager.serialize()
	var records: Array = serialized.get("visitors", [])
	_assert(records.size() == before_count and records[0].has("arrival_source_id") and not records[0].has("spawn_point_id"), "conforming visitor saves use arrival_source_id, not legacy corner IDs")
	_assert(not records[0].has("pose") and not records[0].has("gateway_projection"), "visitor saves exclude source geometry")


func _test_exit_selection() -> void:
	var visitors: Array = _visitor_manager.all_visitors
	var visitor: VisitorData = visitors[0] as VisitorData
	_visitor_manager.request_visitor_leave(visitor.id)
	_assert(visitor.current_state == "leaving" and visitor.arrival_source_id == "gateway_east", "visitor exit uses canonical eligible-source ordering")
	var source_state: Dictionary = _runtime.commit_transaction({"operation": DistrictRuntime.OP_SET_SOURCE_ENABLED, "arrival_source_id": "gateway_east", "enabled": false, "expected_district_revision": _runtime.get_revision()})
	_assert(bool(source_state.get("valid", false)), "H3 source state change commits before exit revalidation")
	for state: Dictionary in _runtime.get_state().get("arrival_source_states", []):
		_assert(not state.has("source_revision") and not state.has("concurrency_revision"), "source state exposes no source-specific revision authority")
	var refreshed_h6: Dictionary = _h6.rebuild()
	_coordinator.set_snapshots(_public_projection.get_graph_snapshot(), refreshed_h6.get("gateway_eligibility"))
	var revalidated: Dictionary = _coordinator.revalidate_exit_source(visitor.arrival_source_id)
	_assert(bool(revalidated.get("valid", false)) and String(revalidated.get("source", {}).get("arrival_source_id", "")) != "gateway_east", "invalid exit sources reselect canonically without coordinate fallback")


func _test_global_population_budget() -> void:
	var cap_demand := ArrivalDemandSnapshot.new()
	_assert(bool(cap_demand.initialize("cap_demand", 999).get("valid", false)), "demand may request more than the global MVP cap")
	while _visitor_manager.get_active_visitor_count() < VisitorManager.MAX_VISITORS:
		var result: Dictionary = _coordinator.realize_arrival(cap_demand)
		if not bool(result.get("valid", false)):
			_assert(false, "realization continues until the global visitor cap")
			return
	var rejected: Dictionary = _coordinator.realize_arrival(cap_demand)
	_assert(not bool(rejected.get("valid", false)) and _has_code(rejected.get("diagnostics", []), "MAX_ACTIVE_VISITORS_REACHED"), "VisitorManager enforces one global 200-active-visitor budget")
	_assert(_visitor_manager.get_active_visitor_count() == 200, "active visitors never exceed the global 200 cap")


func _fault_subscriber(_envelope: Dictionary) -> Dictionary:
	return {"ok": false, "detail": "injected H8 subscriber fault"}


func _second_subscriber(_envelope: Dictionary) -> Dictionary:
	return {"ok": true}


func _has_code(diagnostics: Array, code: String) -> bool:
	for diagnostic: Variant in diagnostics:
		if diagnostic is Dictionary and String(diagnostic.get("code", "")) == code:
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)
