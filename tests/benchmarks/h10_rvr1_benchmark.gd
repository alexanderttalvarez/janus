## H10 RVR-1 benchmark harness.
## Run with: godot --headless --path . --script tests/benchmarks/h10_rvr1_benchmark.gd
extends SceneTree


class BenchmarkEconomy extends DistrictRuntimePorts.DistrictEconomyPort:
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


class BenchmarkProgression extends DistrictRuntimePorts.DistrictProgressionPort:
	func get_policy_snapshot() -> Dictionary:
		return {"revision": 1, "elevation_eligibility": [0, 1, 2, -1, -2, -3], "selected_plot_ids": [], "street_conversion_eligible": true}


const VISITOR_TARGET: int = 200
const REBUILD_CYCLES: int = 30
const SAVE_LOAD_CYCLES: int = 20

var _runtime: DistrictRuntime
var _projection: ProjectionCoordinator
var _public_realm: PublicRealmProjection
var _camera_gateway: CameraGatewayProjection
var _traffic: TrafficTopology
var _visitor_manager: VisitorManager
var _arrival: ArrivalCoordinator
var _demand: ArrivalDemandSnapshot
var _failed: int = 0


func _init() -> void:
	var setup_result: Dictionary = _setup()
	if not bool(setup_result.get("valid", false)):
		push_error("RVR-1 setup failed: %s" % setup_result.get("diagnostics", []))
		quit(1)
		return
	var report: Dictionary = _run_benchmark()
	var destination: String = "user://h10_rvr1_report.json"
	var report_file: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "  "))
		print("RVR-1 report: %s" % destination)
	print(JSON.stringify(report, "  "))
	_cleanup()
	quit(_failed)


func _setup() -> Dictionary:
	var factory: RefCounted = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
	var resolver: DistrictLayoutResolver = load("res://scripts/resources/district_layout_resolver.gd").new() as DistrictLayoutResolver
	print("RVR-1: resolving fixture.mixed_3x3")
	var resolution: Dictionary = resolver.resolve(factory.build_fixture("C"))
	print("RVR-1: fixture resolved")
	if not bool(resolution.get("valid", false)):
		return resolution
	var snapshot: ResolvedDistrictSnapshot = resolution.get("snapshot") as ResolvedDistrictSnapshot
	_runtime = load("res://scripts/district/district_runtime.gd").new() as DistrictRuntime
	var ports: DistrictRuntimePorts.DistrictRuntimePortsBundle = DistrictRuntimePorts.DistrictRuntimePortsBundle.new()
	ports.initialize(BenchmarkEconomy.new(), DistrictRuntimePorts.DistrictZonePort.new(), BenchmarkProgression.new())
	_runtime.configure_ports(ports)
	print("RVR-1: creating runtime session")
	var session: Dictionary = _runtime.create_session(snapshot)
	print("RVR-1: runtime session created")
	if not bool(session.get("valid", false)):
		return session
	var metrics: ProjectionMetrics = load("res://scripts/projection/projection_metrics.gd").new() as ProjectionMetrics
	metrics.identity = "h10_rvr1_metrics"
	metrics.revision = 1
	metrics.grid_unit_size = 1.0
	metrics.floor_height = 3.0
	metrics.origin = Vector3.ZERO
	_projection = load("res://scripts/projection/projection_coordinator.gd").new() as ProjectionCoordinator
	get_root().add_child(_projection)
	var projection_setup: Dictionary = _projection.configure(_runtime, metrics)
	if not bool(projection_setup.get("valid", false)):
		return projection_setup
	print("RVR-1: rebuilding H4 projection")
	if not bool(_projection.rebuild().get("valid", false)):
		return {"valid": false, "diagnostics": [{"code": "PROJECTION_BUILD_FAILED"}]}
	_public_realm = load("res://scripts/public_realm/public_realm_projection.gd").new() as PublicRealmProjection
	var public_setup: Dictionary = _public_realm.initialize(_runtime, _projection, metrics)
	if not bool(public_setup.get("valid", false)):
		return public_setup
	print("RVR-1: rebuilding H5 public realm")
	if not bool(_public_realm.rebuild().get("valid", false)):
		return {"valid": false, "diagnostics": [{"code": "PUBLIC_REALM_BUILD_FAILED"}]}
	_camera_gateway = load("res://scripts/camera/camera_gateway_projection.gd").new() as CameraGatewayProjection
	var gateway_setup: Dictionary = _camera_gateway.initialize(_runtime, _public_realm, null, metrics)
	if not bool(gateway_setup.get("valid", false)):
		return gateway_setup
	print("RVR-1: rebuilding H6 gateways")
	var gateway_result: Dictionary = _camera_gateway.rebuild()
	if not bool(gateway_result.get("valid", false)):
		return gateway_result
	_traffic = load("res://scripts/traffic/traffic_topology.gd").new() as TrafficTopology
	var traffic_setup: Dictionary = _traffic.initialize(_runtime, _public_realm, metrics)
	if not bool(traffic_setup.get("valid", false)):
		return traffic_setup
	print("RVR-1: rebuilding H7 traffic")
	if not bool(_traffic.rebuild().get("valid", false)):
		return {"valid": false, "diagnostics": [{"code": "TRAFFIC_BUILD_FAILED"}]}
	_visitor_manager = VisitorManager.new()
	_arrival = load("res://scripts/simulation/arrival_coordinator.gd").new() as ArrivalCoordinator
	var arrival_setup: Dictionary = _arrival.initialize(_runtime, _public_realm.get_graph_snapshot(), gateway_result.get("gateway_eligibility"), _visitor_manager)
	if not bool(arrival_setup.get("valid", false)):
		return arrival_setup
	_demand = ArrivalDemandSnapshot.new()
	return _demand.initialize("rvr1_demand", VISITOR_TARGET)


func _run_benchmark() -> Dictionary:
	print("RVR-1: realizing 200 visitors")
	var arrival_start: int = Time.get_ticks_msec()
	var source_entries: Array[Dictionary] = _camera_gateway.get_gateway_eligibility_snapshot().entries
	print("RVR-1: source entries=%d" % source_entries.size())
	if source_entries.is_empty():
		_failed = 1
		return {"valid": false, "diagnostics": [{"code": "RVR1_SOURCES_MISSING"}]}
	for index: int in range(VISITOR_TARGET):
		var visitor := VisitorData.new()
		var source_id: String = String(source_entries[index % source_entries.size()].get("arrival_source_id", ""))
		visitor.initialize("rvr1_visitor_%d" % index, "G", Vector3(float(index % 20), 0.0, float(index / 20)))
		visitor.arrival_source_id = source_id
		visitor.location_type = "pedestrian_area"
		visitor.current_state = "moving"
		_visitor_manager.all_visitors.append(visitor)
		if index % 25 == 0:
			print("RVR-1: seeded %d visitors" % (index + 1))
	var arrival_ms: int = Time.get_ticks_msec() - arrival_start
	print("RVR-1: seeded all visitors")
	var rebuild_samples: Array[int] = []
	for cycle: int in range(REBUILD_CYCLES):
		print("RVR-1: rebuild cycle %d" % (cycle + 1))
		var start: int = Time.get_ticks_msec()
		_projection.rebuild()
		_public_realm.rebuild()
		_camera_gateway.rebuild()
		_traffic.rebuild()
		rebuild_samples.append(Time.get_ticks_msec() - start)
	print("RVR-1: rebuild cycles complete")
	var save_load_samples: Array[int] = []
	var saved_state: Dictionary = _runtime.get_state()
	for cycle: int in range(SAVE_LOAD_CYCLES):
		print("RVR-1: save/load cycle %d" % (cycle + 1))
		var start: int = Time.get_ticks_msec()
		var restored: Dictionary = _runtime.replace_session(_runtime.get_snapshot(), saved_state)
		if not bool(restored.get("valid", false)):
			_failed = 1
			return {"valid": false, "diagnostics": restored.get("diagnostics", [])}
		save_load_samples.append(Time.get_ticks_msec() - start)
	return {
		"valid": true,
		"policy": "hybrid_r1",
		"fixture": "fixture.mixed_3x3",
		"realized_visitors": _visitor_manager.get_active_visitor_count(),
		"arrival_ms": arrival_ms,
		"rebuild_cycles": REBUILD_CYCLES,
		"rebuild_ms": rebuild_samples,
		"save_load_cycles": SAVE_LOAD_CYCLES,
		"save_load_ms": save_load_samples,
		"save_state_bytes": JSON.stringify(saved_state).to_utf8_buffer().size(),
		"notes": ["The headless harness seeds 200 immutable VisitorData records after exercising H3-H8 setup; release RVR-1 FPS, draw-call, node, and VRAM sampling remains an external release-build measurement."],
	}


func _cleanup() -> void:
	if _camera_gateway != null:
		_camera_gateway.dispose()
	if _public_realm != null:
		_public_realm.dispose()
	if _traffic != null:
		_traffic.dispose()
		_traffic.free()
		_traffic = null
	if _visitor_manager != null:
		_visitor_manager.all_visitors.clear()
		_visitor_manager.free()
		_visitor_manager = null
	_arrival = null
	_demand = null
	if _projection != null:
		_projection.dispose()
		_projection.queue_free()
		_projection = null
	if _runtime != null:
		_runtime.free()
		_runtime = null
