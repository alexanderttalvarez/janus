## H8 tests for demand/source separation, immediate realization, rollback, and lifecycle.
extends SceneTree

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
	_test_token_contract()
	_test_immediate_commit_and_event_order()
	_test_pre_append_rollback_and_save_boundary()
	_test_exit_selection()
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
	if _projection_coordinator != null:
		_projection_coordinator.dispose()
		_projection_coordinator.queue_free()
	if _runtime != null:
		_runtime.free()


func _test_demand_independence_and_ordering() -> void:
	var first: Dictionary = _coordinator.allocate_source(_demand)
	var alternate := ArrivalDemandSnapshot.new()
	alternate.initialize("demand_other", 20, [{"purpose": "dining", "budget_band": "high"}])
	var second: Dictionary = _coordinator.allocate_source(alternate)
	_assert(bool(first.get("valid", false)) and bool(second.get("valid", false)), "eligible-source allocation accepts independent demand profiles")
	_assert(String(first.get("source", {}).get("arrival_source_id", "")) == "gateway_east", "allocation chooses the first NFC UTF-8 ordered source")
	_assert(String(first.get("source", {}).get("arrival_source_id", "")) == String(second.get("source", {}).get("arrival_source_id", "")), "demand profile does not affect spatial source selection")
	_assert(not first.get("source", {}).has("weight") and not first.get("source", {}).has("capacity"), "MVP allocation does not introduce weighting or capacity policy")


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
	_coordinator.get_dispatcher().append_preflight_enabled = false
	var rejected: Dictionary = _coordinator.realize_arrival(_demand)
	_coordinator.get_dispatcher().append_preflight_enabled = true
	_assert(not bool(rejected.get("valid", false)) and _has_code(rejected.get("diagnostics", []), "ARRIVAL_APPEND_PREFLIGHT_FAILED"), "append-capability rejection occurs before commit")
	_assert(_visitor_manager.get_active_visitor_count() == before_count and _runtime.get_revision() == before_revision, "pre-append failure restores visitor state and leaves District Runtime unchanged")
	var serialized: Dictionary = _visitor_manager.serialize()
	var records: Array = serialized.get("visitors", [])
	_assert(records.size() == before_count and records[0].has("arrival_source_id") and not records[0].has("spawn_point_id"), "conforming visitor saves use arrival_source_id, not legacy corner IDs")
	_assert(not records[0].has("pose") and not records[0].has("gateway_projection"), "visitor saves exclude source geometry")


func _test_exit_selection() -> void:
	var visitors: Array = _visitor_manager.all_visitors
	var visitor: VisitorData = visitors[0] as VisitorData
	_visitor_manager.request_visitor_leave(visitor.id)
	_assert(visitor.current_state == "leaving" and visitor.arrival_source_id == "gateway_east", "visitor exit uses canonical eligible-source ordering")


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
