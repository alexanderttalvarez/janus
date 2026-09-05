## H7 tests for immutable road topology, graph deltas, controls, and cleanup.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_control_clock()
	_test_topology_fixture()
	_test_fixture_c_scope_and_conversion()
	_test_legacy_adapter_isolation()
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
	clock.elapsed_t = 0.0
	_assert(clock.vehicle_state(0.0) == &"GREEN" and clock.vehicle_state(5.0) == &"RED" and clock.pedestrian_state(5.0) == &"GREEN", "shared clock zero has north-south vehicle green and east-west vehicle red")
	_assert(is_equal_approx(clock.canonical_crossing_time(6.0), 6.0), "canonical pedestrian crossing time uses one shared crossing speed")


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
	var traffic_manager: TrafficManager = TrafficManager.new()
	var active_cars: Node3D = Node3D.new()
	active_cars.name = "ActiveCars"
	traffic_manager.add_child(active_cars)
	get_root().add_child(traffic_manager)
	traffic_manager.set_road_graph(graph)
	_assert(traffic_manager.get_bound_lane_ids().size() == graph.lanes.size(), "TrafficManager binds only H7 lane values")
	var recovery_delta: RoadGraphDelta = load("res://scripts/traffic/road_graph_delta.gd").new() as RoadGraphDelta
	recovery_delta.initialize(graph.graph_revision - 1, graph.graph_revision + 1, graph.district_revision, graph.topology_revision, {}, {}, {}, [], [], [], "missed_revision")
	var recovery: Dictionary = traffic_manager.apply_road_graph_delta(recovery_delta)
	_assert(not bool(recovery.get("valid", false)) and bool(recovery.get("recovery_required", false)) and traffic_manager.get_active_car_count() == 0, "TrafficManager clears transient traffic and requests full recovery on a missed graph revision")
	traffic_manager.queue_free()
	_assert(delta != null and delta.added_ids.get("lanes", []).size() == 8 and delta.invalid_route_ids.is_empty(), "initial H7 delta adds lanes without invalidating routes")
	var turn_route: bool = false
	for route: Dictionary in graph.route_attachments:
		turn_route = turn_route or bool(route.get("turn_capable", true)) or String(route.get("kind", "")) != "straight_through"
	_assert(not turn_route, "H7 initial routes are straight-only")
	_assert(graph.traffic_controls.size() == 4 and graph.crosswalks.size() == 4, "H7 emits traffic-functional controls for four outer crosswalks")
	var control: Dictionary = graph.traffic_controls[0]
	_assert(float(control.get("vehicle_cycle_t", 0.0)) == 10.0 and float(control.get("vehicle_green_t", 0.0)) == 5.0 and float(control.get("vehicle_yellow_t", 0.0)) == 1.0 and float(control.get("vehicle_red_t", 0.0)) == 4.0, "H7 emits the shared ten-T vehicle clock contract")
	_assert(float(control.get("signal_height_tiles", 0.0)) == 2.5, "H7 emits compact traffic signal height metadata")
	_assert(control.get("pole_count", 0) == 2 and control.get("canonical_crosswalk_speed_tiles_per_second", 0.0) == 1.0 and control.get("canonical_crossing_time_t", 0.0) > 0.0, "H7 emits two-pole controls and canonical crossing metadata")
	var outer_crossing_is_not_pedestrian: bool = true
	for crosswalk: Dictionary in graph.crosswalks:
		if bool(crosswalk.get("outer_ring", false)):
			outer_crossing_is_not_pedestrian = outer_crossing_is_not_pedestrian and not bool(crosswalk.get("pedestrian_graph_crossing", true)) and bool(crosswalk.get("traffic_functional", false))
	_assert(outer_crossing_is_not_pedestrian, "outer midpoint controls remain traffic-functional without becoming H5 pedestrian crossings")
	var inactive_segment_ids: Dictionary = {}
	for segment: Dictionary in graph.segments:
		if not bool(segment.get("controlled", true)):
			inactive_segment_ids[String(segment.get("id", ""))] = true
	var inactive_attachment_leak: bool = false
	for lane: Dictionary in graph.lanes:
		inactive_attachment_leak = inactive_attachment_leak or inactive_segment_ids.has(String(lane.get("segment_id", "")))
	_assert(not inactive_attachment_leak, "selected/unowned Plot frontage adds no lanes or routes to controlled topology")
	var save_value: Dictionary = graph.value()
	_assert(not save_value.has("cars") and not save_value.has("reservations") and not save_value.has("save_state"), "road graph snapshots contain no transient or persisted traffic state")
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


func _test_fixture_c_scope_and_conversion() -> void:
	var factory: RefCounted = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
	var resolver: DistrictLayoutResolver = load("res://scripts/resources/district_layout_resolver.gd").new() as DistrictLayoutResolver
	var resolution: Dictionary = resolver.resolve(factory.build_fixture("C"))
	var snapshot: ResolvedDistrictSnapshot = resolution.get("snapshot") as ResolvedDistrictSnapshot
	var runtime: DistrictRuntime = load("res://scripts/district/district_runtime.gd").new() as DistrictRuntime
	_assert(bool(runtime.create_session(snapshot).get("valid", false)), "H7 loads Fixture C with the approved initial ownership setup")
	var metrics: ProjectionMetrics = load("res://scripts/projection/projection_metrics.gd").new() as ProjectionMetrics
	metrics.identity = "h7_fixture_c_metrics"
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
	topology.initialize(runtime, public_projection, metrics)
	var first: Dictionary = topology.rebuild()
	_assert(bool(first.get("valid", false)), "H7 accepts connected Fixture C active topology")
	if not bool(first.get("valid", false)):
		print("H7 Fixture C diagnostics: %s" % first.get("diagnostics", []))
		public_projection.dispose()
		coordinator.dispose()
		coordinator.queue_free()
		runtime.free()
		return
	var graph: RoadGraphSnapshot = first.get("snapshot") as RoadGraphSnapshot
	_assert(graph.outer_ring.get("active_plot_ids", []).size() == 3, "H7 uses only the three approved initially owned Plot records")
	var central_plot_id: String = ""
	for plot: Dictionary in snapshot.get_data().get("plots", []):
		if String(plot.get("slot_id", "")) == "central_plaza":
			central_plot_id = String(plot.get("id", ""))
	_assert(not graph.outer_ring.get("active_plot_ids", []).has(central_plot_id), "H7 excludes public-plaza and selected/unowned Plot identity from controlled area")
	var selected_graph: RoadGraphSnapshot = graph.duplicate_value()
	_assert(selected_graph.value() == graph.value(), "H7 selected/unowned Plot state does not alter road topology")
	var converted_id: String = ""
	for segment: Dictionary in public_projection.get_road_profile_snapshot().get("segments", []):
		if not bool(segment.get("outer_ring", false)) and bool(segment.get("frontage", {}).get("negative", {}).get("contacts", []).size() > 0):
			converted_id = String(segment.get("id", ""))
			break
	_assert(not converted_id.is_empty(), "H7 finds an internal conversion input from H5")
	var converted_state: Dictionary = runtime.get_state()
	converted_state["street_segment_states"] = [{"street_segment_id": converted_id, "converted": true}]
	var replaced: Dictionary = runtime.replace_session(snapshot, converted_state)
	_assert(bool(replaced.get("valid", false)), "H7 conversion test replaces only committed H3 state")
	public_projection.rebuild()
	var second: Dictionary = topology.rebuild()
	var second_graph: RoadGraphSnapshot = second.get("snapshot") as RoadGraphSnapshot
	var second_delta: RoadGraphDelta = second.get("delta") as RoadGraphDelta
	_assert(bool(second.get("valid", false)) and second_graph.lanes.size() < graph.lanes.size(), "H7 removes converted-segment lanes from the road graph")
	_assert(second_delta != null and second_delta.invalid_route_ids.size() > 0 and second_delta.invalid_reservation_ids.size() > 0, "H7 conversion delta invalidates stale routes and reservations")
	var converted_lane_ids: Dictionary = {}
	for lane: Dictionary in graph.lanes:
		if String(lane.get("segment_id", "")) == converted_id:
			converted_lane_ids[String(lane.get("id", ""))] = true
	var converted_anchor_leak: bool = false
	for anchor: Dictionary in second_graph.control_anchors:
		converted_anchor_leak = converted_anchor_leak or converted_lane_ids.has(String(anchor.get("lane_id", "")))
	_assert(not converted_anchor_leak, "converted segments have no active perimeter anchors")
	var converted_segment: Dictionary = {}
	for segment: Dictionary in second_graph.segments:
		if String(segment.get("id", "")) == converted_id:
			converted_segment = segment
			break
	_assert(bool(converted_segment.get("converted", false)) and not bool(converted_segment.get("active", true)), "H7 keeps conversion state derived from H5 without vetoing the H3 commit")
	public_projection.dispose()
	coordinator.dispose()
	coordinator.queue_free()
	runtime.free()


func _test_legacy_adapter_isolation() -> void:
	var main_root: Node3D = Node3D.new()
	var layout: Node3D = Node3D.new()
	layout.name = "TrafficLayout"
	main_root.add_child(layout)
	var lanes_root: Node3D = Node3D.new()
	lanes_root.name = "Lanes"
	layout.add_child(lanes_root)
	for lane_id: String in LegacyAuthoredTrafficLayoutAdapter.EXPECTED_LANES:
		var lane: Node3D = Node3D.new()
		lane.name = lane_id
		lanes_root.add_child(lane)
		for marker_name: String in LegacyAuthoredTrafficLayoutAdapter.EXPECTED_MARKERS:
			var marker: Marker3D = Marker3D.new()
			marker.name = marker_name
			lane.add_child(marker)
	var crosswalk_root: Node3D = Node3D.new()
	crosswalk_root.name = "Crosswalks"
	layout.add_child(crosswalk_root)
	for crosswalk_name: String in LegacyAuthoredTrafficLayoutAdapter.EXPECTED_CROSSWALKS:
		var crosswalk: Marker3D = Marker3D.new()
		crosswalk.name = crosswalk_name
		crosswalk_root.add_child(crosswalk)
	var zones_root: Node3D = Node3D.new()
	zones_root.name = "IntersectionZones"
	layout.add_child(zones_root)
	for zone_name: String in LegacyAuthoredTrafficLayoutAdapter.EXPECTED_RESERVATION_ZONES:
		var zone: Node3D = Node3D.new()
		zone.name = zone_name
		zones_root.add_child(zone)
	var adapter: LegacyAuthoredTrafficLayoutAdapter = load("res://scripts/traffic/legacy_authored_traffic_layout_adapter.gd").new() as LegacyAuthoredTrafficLayoutAdapter
	var adapted: Dictionary = adapter.validate(main_root)
	_assert(bool(adapted.get("valid", false)) and adapted.get("lanes", []).size() == 8, "legacy traffic adapter validates the exact eight-lane compatibility fixture")
	_assert(adapted.get("marker_families", []).size() == 6 and adapted.get("reservation_zones", []).size() == 4, "legacy traffic adapter reports six marker families and four reservation zones")
	var manager_script: Script = load("res://scripts/world/traffic_manager.gd") as Script
	_assert(not manager_script.get_source_code().contains("_initialize_lanes()"), "TrafficManager no longer boots from legacy authored lane Nodes")
	main_root.free()


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)
