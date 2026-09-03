## H7 tests for immutable road topology, graph deltas, controls, and cleanup.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_control_clock()
	_test_topology_fixture()
	print("Traffic Topology H7 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_control_clock() -> void:
	var clock: TrafficControlClock = load("res://scripts/traffic/traffic_control_clock.gd").new() as TrafficControlClock
	_assert(clock.vehicle_state() == &"GREEN" and clock.pedestrian_state() == &"RED", "traffic clock starts with vehicles green and pedestrians red")
	clock.advance(5.0)
	_assert(clock.vehicle_state() == &"YELLOW", "traffic clock enters one-T vehicle yellow phase")
	clock.advance(1.0)
	_assert(clock.vehicle_state() == &"RED" and clock.pedestrian_state() == &"GREEN", "traffic clock enters four-T pedestrian green phase")
	clock.set_paused(true)
	var paused_phase: float = clock.elapsed_t
	clock.advance(4.0)
	_assert(is_equal_approx(clock.elapsed_t, paused_phase), "paused traffic clock does not advance")
	clock.set_paused(false)
	clock.set_time_scale(2.0)
	clock.advance(1.0)
	_assert(is_equal_approx(clock.elapsed_t, fmod(paused_phase + 2.0, 10.0)), "traffic clock applies simulation time scale")
	_assert(clock.vehicle_state(5.0) != clock.vehicle_state(0.0), "east-west control offset produces a half-cycle phase shift")


func _test_topology_fixture() -> void:
	var factory: RefCounted = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
	var resolver: DistrictLayoutResolver = load("res://scripts/resources/district_layout_resolver.gd").new() as DistrictLayoutResolver
	var resolution: Dictionary = resolver.resolve(factory.build_fixture("A"))
	_assert(bool(resolution.get("valid", false)), "H7 fixture A resolves through H1/H2")
	var snapshot: ResolvedDistrictSnapshot = resolution.get("snapshot") as ResolvedDistrictSnapshot
	var runtime: DistrictRuntime = load("res://scripts/district/district_runtime.gd").new() as DistrictRuntime
	_assert(bool(runtime.create_session(snapshot).get("valid", false)), "H7 creates a committed H3 session")
	var metrics: ProjectionMetrics = load("res://scripts/projection/projection_metrics.gd").new() as ProjectionMetrics
	metrics.identity = "h7_test_metrics"
	metrics.revision = 1
	metrics.grid_unit_size = 1.0
	metrics.floor_height = 3.0
	metrics.origin = Vector3.ZERO
	var coordinator: ProjectionCoordinator = load("res://scripts/projection/projection_coordinator.gd").new() as ProjectionCoordinator
	get_root().add_child(coordinator)
	coordinator.configure(runtime, metrics)
	coordinator.rebuild()
	var public_projection: PublicRealmProjection = load("res://scripts/public_realm/public_realm_projection.gd").new() as PublicRealmProjection
	public_projection.initialize(runtime, coordinator, metrics)
	public_projection.rebuild()
	var topology: TrafficTopology = load("res://scripts/traffic/traffic_topology.gd").new() as TrafficTopology
	get_root().add_child(topology)
	_assert(bool(topology.initialize(runtime, public_projection, metrics).get("valid", false)), "H7 configures from H3, H4 metrics, and H5 public realm")
	var first: Dictionary = topology.rebuild()
	_assert(bool(first.get("valid", false)), "H7 builds a complete road graph snapshot")
	var graph: RoadGraphSnapshot = first.get("snapshot") as RoadGraphSnapshot
	var delta: RoadGraphDelta = first.get("delta") as RoadGraphDelta
	_assert(graph != null and graph.lanes.size() == 8 and graph.route_attachments.size() == 8, "H7 emits eight straight-through lanes and routes for legacy fixture A")
	_assert(graph.control_anchors.size() == 16, "H7 emits paired perimeter spawn/despawn anchors")
	_assert(delta != null and delta.added_ids.get("lanes", []).size() == 8 and delta.invalid_route_ids.is_empty(), "initial H7 delta adds lanes without invalidating routes")
	var turn_route: bool = false
	for route: Dictionary in graph.route_attachments:
		turn_route = turn_route or bool(route.get("turn_capable", true)) or String(route.get("kind", "")) != "straight_through"
	_assert(not turn_route, "H7 initial routes are straight-only")
	_assert(graph.traffic_controls.size() == 4 and graph.crosswalks.size() == 4, "H7 emits traffic-functional controls for four outer crosswalks")
	var control: Dictionary = graph.traffic_controls[0]
	_assert(float(control.get("vehicle_cycle_t", 0.0)) == 10.0 and float(control.get("vehicle_green_t", 0.0)) == 5.0 and float(control.get("vehicle_yellow_t", 0.0)) == 1.0 and float(control.get("vehicle_red_t", 0.0)) == 4.0, "H7 emits the shared ten-T vehicle clock contract")
	_assert(float(control.get("signal_height_tiles", 0.0)) == 2.5, "H7 emits compact traffic signal height metadata")
	var copy: RoadGraphSnapshot = graph.duplicate_value()
	copy.lanes.clear()
	_assert(graph.lanes.size() == 8, "H7 graph snapshots are detached immutable-value reads")
	var second: Dictionary = topology.rebuild()
	var second_delta: RoadGraphDelta = second.get("delta") as RoadGraphDelta
	_assert(bool(second.get("valid", false)) and second_delta.added_ids.is_empty() and second_delta.changed_ids.is_empty() and second_delta.removed_ids.is_empty(), "unchanged H7 rebuild publishes an empty structural delta")
	topology.dispose()
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
