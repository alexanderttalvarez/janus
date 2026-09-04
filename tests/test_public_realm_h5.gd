## H5 tests for public-realm descriptors, conversion, graph merging, and H4 batches.
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


func _init() -> void:
	var factory: RefCounted = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
	var resolver: DistrictLayoutResolver = load("res://scripts/resources/district_layout_resolver.gd").new() as DistrictLayoutResolver
	var resolution: Dictionary = resolver.resolve(factory.build_fixture("C"))
	_assert(bool(resolution.get("valid", false)), "H5 fixture resolves through H1/H2")
	var snapshot: ResolvedDistrictSnapshot = resolution.get("snapshot") as ResolvedDistrictSnapshot
	var records: DistrictStateRecords = load("res://scripts/resources/district_state_records.gd").new() as DistrictStateRecords
	var state: Dictionary = records.create_baseline(snapshot)
	var traversal: DistrictTraversalReadView = load("res://scripts/district/district_traversal_read_view.gd").new() as DistrictTraversalReadView
	traversal.initialize(snapshot.get_fingerprint(), 0, 0, [], [], [])
	var metrics: ProjectionMetrics = load("res://scripts/projection/projection_metrics.gd").new() as ProjectionMetrics
	metrics.identity = "h5_test_metrics"
	metrics.revision = 1
	metrics.grid_unit_size = 1.0
	metrics.floor_height = 3.0
	metrics.origin = Vector3.ZERO
	var builder: PublicRealmDescriptorBuilder = load("res://scripts/public_realm/public_realm_descriptor_builder.gd").new() as PublicRealmDescriptorBuilder
	var built: Dictionary = builder.build(snapshot, state, traversal, metrics)
	_assert(bool(built.get("valid", false)), "H5 builds public-realm descriptors")
	var segments: Array[Dictionary] = built.get("segments", [])
	var intersections: Array[Dictionary] = built.get("intersections", [])
	var batch: ProjectionDescriptorBatch = built.get("batch") as ProjectionDescriptorBatch
	_assert(segments.size() == 24 and intersections.size() == 16, "H5 emits complete resolved segment and intersection coverage")
	_assert(batch != null and batch.primitives.size() > 0 and batch.owner_id == "H5PublicRealm", "H5 emits an immutable generic H4 projection batch")
	var zero_length_contacts: int = 0
	for segment: Dictionary in segments:
		for side_name: String in ["negative", "positive"]:
			for contact: Dictionary in segment.get("frontage", {}).get(side_name, {}).get("contacts", []):
				if int(contact.get("length_quarter", 0)) <= 0:
					zero_length_contacts += 1
	_assert(zero_length_contacts == 0, "corner-only contacts contribute zero frontage")
	var road_descriptor: Dictionary = segments[0]
	_assert(road_descriptor.get("lane_markings", []).size() >= 2, "road segments emit solid carriageway edge markings")
	_assert(road_descriptor.get("curbs", []).size() == 2 and road_descriptor.get("crosswalk", {}).get("stripe_count", 0) == 10, "road segments emit continuous curbs and ten alternating crosswalk stripes")
	_assert(road_descriptor.get("stop_lines", []).size() == 2 and bool(road_descriptor.get("stop_lines", [])[0].get("approach_only", false)), "road segments emit approach-only stop lines")
	var outer_plan: Dictionary = builder.build_conversion_plan(snapshot, state, String(segments[0]["id"]))
	_assert(not bool(outer_plan.get("eligible", false)) and bool(outer_plan.get("outer_ring", false)), "outer-ring conversion is rejected")
	var conversion_state: Dictionary = state.duplicate(true)
	var activation_candidate: Dictionary = builder.build_conversion_plan(snapshot, state, String(segments[3]["id"]))
	var activation_contacts: Array = activation_candidate.get("frontage", {}).get("positive", {}).get("contacts", [])
	var activation_plot_id: String = String(activation_contacts[0].get("plot_id", "")) if not activation_contacts.is_empty() else ""
	var activation_section_id: String = ""
	for section: Dictionary in snapshot.get_data().get("sections", []):
		if String(section.get("plot_id", "")) == activation_plot_id:
			activation_section_id = String(section.get("id", ""))
			break
	conversion_state["plot_states"].append({"runtime_plot_id": activation_plot_id, "section_state_overrides": [{"runtime_section_id": activation_section_id, "owned": true, "available": true}], "floor_states": []})
	var eligible_id: String = ""
	for segment: Dictionary in segments:
		var plan: Dictionary = builder.build_conversion_plan(snapshot, conversion_state, String(segment["id"]))
		if bool(plan.get("eligible", false)):
			eligible_id = String(segment["id"])
			break
	_assert(not eligible_id.is_empty(), "an internal segment can satisfy independent frontage thresholds")
	var internal_crosswalks: int = 0
	for segment: Dictionary in segments:
		if not bool(segment.get("outer_ring", false)) and bool(segment.get("crosswalk", {}).get("active", false)):
			internal_crosswalks += int(segment.get("crosswalk", {}).get("stripe_count", 0))
	_assert(internal_crosswalks > 0, "active internal segments emit centered 5-tile crosswalk stripes")
	var outer_crossing_edges: int = 0
	var graph: PedestrianGraphSnapshot = built.get("graph") as PedestrianGraphSnapshot
	for edge: Dictionary in graph.edges:
		if String(edge.get("kind", "")) == "midpoint_crosswalk" and bool(builder.build_conversion_plan(snapshot, state, String(edge.get("source_id", ""))).get("outer_ring", false)):
			outer_crossing_edges += 1
	_assert(outer_crossing_edges == 0, "outer-ring crosswalks do not create pedestrian graph crossings")
	var band_path_edges: int = 0
	for edge: Dictionary in graph.edges:
		if String(edge.get("kind", "")) == "public_band_path":
			band_path_edges += 1
	_assert(band_path_edges > 0, "adjacent public bands form longitudinal pedestrian paths")
	var public_band_id: String = String(snapshot.get_data().get("pedestrian_bands", [])[0].get("id", ""))
	var door_view: DistrictTraversalReadView = load("res://scripts/district/district_traversal_read_view.gd").new() as DistrictTraversalReadView
	door_view.initialize(snapshot.get_fingerprint(), 0, 0, [], [{"door_edge_id": "door_1", "floor_id": "floor_1", "interior_cell_id": "cell_1", "external_ref": public_band_id, "access_kind": "public_band_physical", "source_kind": "H3"}], [])
	var door_built: Dictionary = builder.build(snapshot, state, door_view, metrics)
	var door_graph: PedestrianGraphSnapshot = door_built.get("graph") as PedestrianGraphSnapshot
	var public_edge_found: bool = false
	for edge: Dictionary in door_graph.edges:
		if String(edge.get("kind", "")) == "public_band_physical":
			public_edge_found = true
	_assert(public_edge_found, "public-band physical access becomes a stable graph edge")
	var request: ProjectionRequest = load("res://scripts/projection/projection_request.gd").new() as ProjectionRequest
	request.definition_fingerprint = snapshot.get_fingerprint()
	request.district_revision = 0
	request.zone_revision = 0
	request.metrics = metrics
	request.snapshot = snapshot
	request.state = state
	request.descriptor_batches = [batch]
	_assert(bool(request.validate().get("valid", false)), "H4 accepts the H5 batch with matching revisions")
	var runtime: DistrictRuntime = load("res://scripts/district/district_runtime.gd").new() as DistrictRuntime
	var h3_ports: DistrictRuntimePorts.DistrictRuntimePortsBundle = DistrictRuntimePorts.DistrictRuntimePortsBundle.new()
	h3_ports.initialize(FakeEconomy.new(), DistrictRuntimePorts.DistrictZonePort.new(), FakeProgression.new())
	runtime.configure_ports(h3_ports)
	var created: Dictionary = runtime.create_session(snapshot)
	runtime.set_street_conversion_validator(Callable(builder, "validate_conversion_intent"))
	runtime.replace_session(snapshot, conversion_state)
	var plan_for_commit: Dictionary = builder.build_conversion_plan(snapshot, runtime.get_state(), eligible_id)
	var commit: Dictionary = runtime.commit_transaction({"operation": DistrictRuntime.OP_CONVERT_STREET, "expected_district_revision": runtime.get_revision(), "street_segment_id": eligible_id, "conversion_plan": plan_for_commit})
	_assert(bool(created.get("valid", false)) and bool(commit.get("valid", false)), "H3 commits an H5-validated street conversion atomically")
	_assert(runtime.get_state().get("street_segment_states", []).size() == 1, "street conversion is stored as sparse H3 street state")
	var converted_built: Dictionary = builder.build(snapshot, runtime.get_state(), runtime.get_traversal_read_view(), metrics)
	var converted_descriptor: Dictionary = {}
	for descriptor: Dictionary in converted_built.get("segments", []):
		if String(descriptor.get("id", "")) == eligible_id:
			converted_descriptor = descriptor
			break
	_assert(bool(converted_descriptor.get("converted", false)) and String(converted_descriptor.get("geometry_state", "")) == "unrestricted_pedestrian", "converted street becomes unrestricted pedestrian space")
	var converted_batch: ProjectionDescriptorBatch = converted_built.get("batch") as ProjectionDescriptorBatch
	var removed_carriageway: bool = true
	for primitive: Dictionary in converted_batch.primitives:
		if String(primitive.get("source_id", "")) == eligible_id and String(primitive.get("primitive_kind", "")) == "carriageway_surface":
			removed_carriageway = false
	_assert(removed_carriageway, "converted street removes carriageway projection primitives")
	var coordinator: ProjectionCoordinator = load("res://scripts/projection/projection_coordinator.gd").new() as ProjectionCoordinator
	get_root().add_child(coordinator)
	var coordinator_setup: Dictionary = coordinator.configure(runtime, metrics)
	var public_projection: PublicRealmProjection = load("res://scripts/public_realm/public_realm_projection.gd").new() as PublicRealmProjection
	var public_setup: Dictionary = public_projection.initialize(runtime, coordinator, metrics)
	var public_rebuild: Dictionary = public_projection.rebuild()
	var graph_delta: Dictionary = {"added_nodes": [], "added_edges": []}
	public_projection.pedestrian_graph_delta_published.connect(func(delta: Dictionary) -> void: graph_delta = delta)
	var second_rebuild: Dictionary = public_projection.rebuild()
	_assert(bool(coordinator_setup.get("valid", false)) and bool(public_setup.get("valid", false)) and bool(public_rebuild.get("valid", false)) and bool(second_rebuild.get("valid", false)), "H5 uses the shared H4 coordinator for runtime projection")
	_assert(graph_delta.get("added_nodes", []).is_empty() and graph_delta.get("added_edges", []).is_empty(), "rebuilding unchanged public realm publishes an empty graph delta")
	public_projection.dispose()
	coordinator.dispose()
	coordinator.queue_free()
	runtime.free()
	print("PublicRealm H5 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)
