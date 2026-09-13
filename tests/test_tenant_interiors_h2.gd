## Detached Tenant Interiors H2 contract tests.
extends SceneTree

var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	_test_policies()
	_test_queue()
	_test_graph_and_parity()
	_test_formation()
	_test_full_planner_pipeline()
	_test_mutations()
	_test_old_request_rejected()
	print("TenantInteriors H2 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)

func _test_policies() -> void:
	var policy := ParcelFormationPolicy.new()
	_assert(policy.validate_revision_one(), "formation policy revision 1 is normalized")
	_assert(policy.scale_for_area(12) == "COMPACT" and policy.scale_for_area(13) == "STANDARD", "compact/standard boundary is exact")
	_assert(policy.scale_for_area(24) == "STANDARD" and policy.scale_for_area(25) == "LARGE", "standard/large boundary is exact")
	_assert(QueueGeometryPolicy.new().validate_revision_one(), "queue policy revision 1 is normalized")
	var formation_asset := load("res://resources/interiors/policies/parcel_formation_default.tres") as ParcelFormationPolicy
	var queue_asset := load("res://resources/interiors/policies/queue_geometry_default.tres") as QueueGeometryPolicy
	_assert(formation_asset != null and formation_asset.validate_revision_one() and queue_asset != null and queue_asset.validate_revision_one(), "default H2 policy resources load with exact revision-one values")

func _test_queue() -> void:
	var snapshot := QueueResolutionSnapshot.new()
	var value := _queue_value()
	_assert(bool(snapshot.configure(value).get("valid", false)), "canonical queue snapshot is accepted")
	var malformed := value.duplicate(true)
	malformed["unknown"] = true
	_assert(not QueueResolutionSnapshot.validate_value(malformed).is_empty(), "unknown queue snapshot fields reject")
	var resolver := QueueEnvelopeResolver.new()
	var graph := _graph()
	var first := resolver.resolve([_door("door.b"), _door("door.a")], graph, snapshot, QueueGeometryPolicy.new())
	var reversed := resolver.resolve([_door("door.a"), _door("door.b")], graph, snapshot, QueueGeometryPolicy.new())
	_assert(first.get("status") == "VALID" and first == reversed, "queue allocation is input-order independent")
	var claimed: Dictionary = {}
	var exclusive := true
	for envelope: Dictionary in first.get("candidate_envelopes", []):
		for position: Dictionary in envelope["positions"]:
			for key: String in position["conflict_keys"]:
				if claimed.has(key): exclusive = false
				claimed[key] = true
	_assert(exclusive, "queue conflict keys are exclusive")
	_assert(String(first.get("queue_envelopes_fingerprint", "")).length() == 64, "queue envelopes carry canonical provenance")
	var stale_value := value.duplicate(true)
	stale_value["zone_revision"] = 2
	var stale := QueueResolutionSnapshot.new()
	stale.configure(stale_value)
	var stale_result := resolver.resolve([_door("door.a")], graph, stale, QueueGeometryPolicy.new())
	_assert(stale_result.get("status") == "INPUT_INVALID" and stale_result["diagnostics"][0]["code"] == "QUEUE_INPUT_STALE", "queue resolution rejects graph revision mismatch")

func _test_graph_and_parity() -> void:
	var graph := _graph()
	_assert(graph != null and String(graph.duplicate_value()["topology_fingerprint"]).length() == 64, "prospective graph is canonical and fingerprinted")
	var components := {
		"formation_policy_id":"tenant_parcel_formation", "formation_policy_revision":1,
		"queue_policy_id":"tenant_exterior_queue_geometry", "queue_policy_revision":1,
		"selected_door_edges":[], "prospective_graph_fingerprint":graph.duplicate_value()["topology_fingerprint"],
		"queue_input_fingerprint":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		"queue_envelopes":[], "feasible_pool_fingerprint":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
	}
	var made := PhaseAParityRecord.create(components)
	_assert(bool(made.get("valid", false)), "complete Phase-A parity record is created")
	var changed: Dictionary = made["record"].duplicate(true)
	changed["queue_input_fingerprint"] = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
	var compared := PhaseAParityRecord.compare(made["record"], changed)
	_assert(not bool(compared.get("valid", false)) and compared["diagnostics"][0]["code"] == "PHASE_A_QUEUE_INPUT_MISMATCH", "queue-input parity mismatch has a stable reason")

func _test_formation() -> void:
	var planner := TenantParcelFormationPlanner.new()
	var cells: Array[Array] = []
	var frontage: Array[Dictionary] = []
	for y: int in range(6):
		for x: int in range(8):
			cells.append([x,y])
			frontage.append({"parcel_cell":{"x":x,"y":y}})
	var formed: Dictionary = planner.call("_form_parcels", cells, frontage, "Retail", "zone.test", ParcelFormationPolicy.new())
	_assert(formed.get("status") == "VALID" and (formed["parcels"] as Array).size() >= 2, "ordinary formation creates deterministic scale-diverse parcels")
	var reversed_cells: Array = cells.duplicate()
	reversed_cells.reverse()
	var reversed_frontage: Array = frontage.duplicate()
	reversed_frontage.reverse()
	var reversed: Dictionary = planner.call("_form_parcels", reversed_cells, reversed_frontage, "Retail", "zone.test", ParcelFormationPolicy.new())
	_assert(formed == reversed, "formation ignores input insertion order")
	var anchor: Dictionary = planner.call("_form_parcels", cells, frontage, "Anchor", "zone.anchor", ParcelFormationPolicy.new())
	_assert((anchor["parcels"] as Array).size() == 1 and anchor["parcels"][0]["cells"].size() == cells.size(), "Anchor bypasses ordinary splitting")

func _test_full_planner_pipeline() -> void:
	var compiled := TenantInteriorContentCompiler.new().compile(load("res://resources/interiors/catalog/tenant_interiors_default.tres"), true, true)
	var source := (compiled.get("snapshot") as CompiledTenantInteriorContent).get_content()
	var selected_profile: Dictionary = {}
	for profile: Dictionary in source.get("operational_profiles", []):
		if selected_profile.is_empty() or int(profile.get("minimum_area", 999999)) < int(selected_profile.get("minimum_area", 999999)): selected_profile = profile
	source["operational_profiles"] = [selected_profile]
	var encoded := CanonicalJsonFingerprint.new().fingerprint(source, CompiledTenantInteriorContent.FINGERPRINT_DOMAIN, CompiledTenantInteriorContent.SCHEMA_VERSION)
	var content := CompiledTenantInteriorContent.new()
	content.initialize(source, encoded["canonical_json"], encoded["fingerprint"])
	var width: int = int(selected_profile["core_width"])
	var depth: int = maxi(int(selected_profile["core_depth"]), ceili(float(int(selected_profile["minimum_area"])) / float(width)))
	var cells: Array[Array] = []
	for y: int in range(depth):
		for x: int in range(width): cells.append([x, y])
	var spatial := _spatial_snapshot(cells)
	var public_access := _public_access_snapshot(1)
	var queue := QueueResolutionSnapshot.new()
	var queue_value := _queue_value()
	queue_value["public_queue_tiles"] = [{"x":-1,"y":depth-3},{"x":-1,"y":depth-2},{"x":-1,"y":depth},{"x":-1,"y":depth+1}]
	queue.configure(queue_value)
	var zone_type: String = String(selected_profile["zone_type"])
	var intent := {"zone_type":zone_type,"zone_plan_key":"zone.pipeline","runtime_plot_id":"plot.0","floor_id":"floor.0","signed_elevation":0}
	var selected_door := _door_at("door.a", depth - 1)
	var base := {"prospective_graph":_graph(),"selected_doors":[selected_door],"tenant_cells":cells,"frontage_edges":[selected_door["edge"]],"zone_type":zone_type}
	var result := TenantParcelFormationPlanner.new().plan(intent, base, spatial, public_access, queue, content, ParcelFormationPolicy.new(), QueueGeometryPolicy.new())
	_assert(result.get("status") == "VALID" and (result.get("parcels", []) as Array).size() == 1 and not (result.get("phase_a_parity", {}) as Dictionary).is_empty(), "full detached pipeline publishes one feasible parcel with complete parity")
	var stale := _public_access_snapshot(2)
	var rejected := TenantParcelFormationPlanner.new().plan(intent, base, spatial, stale, queue, content, ParcelFormationPolicy.new(), QueueGeometryPolicy.new())
	_assert(rejected.get("status") == "INVALID_INPUT" and rejected["diagnostics"][0]["code"] == "PUBLIC_BAND_ACCESS_STALE", "full planner rejects stale injected public-band access")


func _test_mutations() -> void:
	var validator := DetachedZoneMutationValidator.new()
	var intent := _intent([])
	var old := _parcel("parcel.1", "same", "", "")
	var unchanged := validator.validate(intent, _base([old]), _formation([old]))
	_assert(unchanged.get("valid", false) and unchanged["value"]["activation"] == "DETACHED_COMMIT_ELIGIBLE", "unchanged locked parcel is preserved")
	var vacant_old := _parcel("parcel.1", "old", "", "")
	var vacant_new := _parcel("parcel.1", "new", "", "")
	vacant_new["suitability"] = "UNSUITABLE"
	var vacant := validator.validate(intent, _base([vacant_old]), _formation([vacant_new]))
	_assert(vacant.get("valid", false) and vacant["value"]["suitability_records"][0]["suitability"] == "UNSUITABLE", "changed vacant parcel may remain a visible unsuitable unit")
	var bound := _parcel("parcel.1", "old", "tenant.1", "profile.1")
	var replacement := _parcel("parcel.1", "new", "tenant.1", "profile.1")
	replacement["feasible_profile_ids"] = ["profile.1"]
	var changed := validator.validate(intent, _base([bound]), _formation([replacement]))
	_assert(changed.get("valid", false) and changed["value"]["activation"] == "REQUIRES_H3_PHASE_B", "changed feasible bound parcel requires H3 Phase B")
	replacement["feasible_profile_ids"] = []
	var invalid := validator.validate(intent, _base([bound]), _formation([replacement]))
	_assert(invalid.get("valid", false) and invalid["value"]["status"] == "BOUND_INTERIOR_INVALIDATED", "unauthorized bound-profile invalidation rejects")
	var authorized_intent := _intent([{"authorization_id":"auth.1","parcel_id":"parcel.1","tenant_id":"tenant.1","reason":"PLAYER_PARCEL_RETIREMENT"}])
	var retired := validator.validate(authorized_intent, _base([bound]), _formation([]))
	_assert(retired.get("valid", false) and retired["value"]["activation"] == "REQUIRES_H4_H5_INTEGRATION", "authorized occupied retirement remains integration-gated")

func _test_old_request_rejected() -> void:
	var result := InteriorLayoutPlanner.new().plan_phase_a({"zone_type":"Retail"}, null)
	var found := false
	for diagnostic: Dictionary in result.get("diagnostics", []):
		if diagnostic.get("code") == "REQUEST_SCHEMA_UNSUPPORTED": found = true
	_assert(result.get("status") == "CONTENT_INVALID" and found, "legacy singular H1 request schema rejects without an adapter")

func _queue_value() -> Dictionary:
	return {"schema_id":"queue_resolution_snapshot","schema_version":1,"layout_ref":{"layout_id":"layout","layout_definition_version":1,"definition_fingerprint":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"district_revision":1,"zone_revision":1,"floor_scope":{"floor_id":"floor.0","runtime_plot_id":"plot.0","signed_elevation":0},"public_queue_tiles":[{"x":1,"y":-2},{"x":1,"y":-1},{"x":1,"y":1},{"x":1,"y":2}],"nonpublic_quarter_cells":[],"intersection_quarter_cells":[],"crosswalk_quarter_cells":[],"source_anchor_quarter_cells":[],"vertical_link_quarter_cells":[],"structural_approach_quarter_cells":[],"fixed_occupancy_quarter_cells":[]}

func _graph() -> ProspectivePedestrianGraphSnapshot:
	var nodes := [{"semantic_key":"n.a","kind":"FLOOR_CELL","source_id":"a"},{"semantic_key":"n.b","kind":"PUBLIC_BAND","source_id":"b"}]
	var edges := [{"semantic_key":"e.a","from_semantic_key":"n.a","to_semantic_key":"n.b","kind":"PARCEL_DOOR","source_id":"door"}]
	var made := ProspectivePedestrianGraphBuilder.new().build({"layout_ref":{"layout_id":"layout","layout_definition_version":1,"definition_fingerprint":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"district_revision":1,"zone_revision":1,"nodes":nodes,"edges":edges})
	return made.get("snapshot") as ProspectivePedestrianGraphSnapshot

func _spatial_snapshot(cells: Array[Array]) -> DistrictZoneSpatialSnapshot:
	var records: Array[Dictionary] = []
	for cell: Array in cells: records.append({"x":int(cell[0]),"y":int(cell[1])})
	var value := {"schema_id":"district_zone_spatial_snapshot","schema_version":1,"layout_ref":{"layout_id":"layout","layout_definition_version":1,"definition_fingerprint":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"district_revision":1,"floor_scope":{"floor_id":"floor.0","runtime_plot_id":"plot.0","signed_elevation":0},"valid_cells":records,"acquired_cells":records,"constructed_cells":records,"zone_eligible_cells":records,"explicit_circulation_cells":[],"manual_door_edges":[]}
	var snapshot := DistrictZoneSpatialSnapshot.new()
	snapshot.configure(value)
	return snapshot


func _public_access_snapshot(revision: int) -> PublicBandAccessSnapshot:
	var value := {"schema_id":"public_band_access_snapshot","schema_version":1,"layout_ref":{"layout_id":"layout","layout_definition_version":1,"definition_fingerprint":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"district_revision":revision,"access_edges":[]}
	var snapshot := PublicBandAccessSnapshot.new()
	snapshot.configure(value)
	return snapshot


func _door(key: String) -> Dictionary:
	var edge := {"parcel_cell":{"x":0,"y":0},"direction":"EAST","access_kind":"EXPLICIT_CIRCULATION","access_cell":{"x":1,"y":0},"public_band_access_edge_id":null}
	return {"door_semantic_key":key,"edge":edge,"queue_envelope_key":"envelope.%s"%key,"minimum_positions":0,"maximum_positions":4}


func _door_at(key: String, y: int) -> Dictionary:
	var edge := {"parcel_cell":{"x":0,"y":y},"direction":"WEST","access_kind":"EXPLICIT_CIRCULATION","access_cell":{"x":-1,"y":y},"public_band_access_edge_id":null}
	return {"door_semantic_key":key,"edge":edge,"queue_envelope_key":"envelope.%s"%key,"minimum_positions":0,"maximum_positions":4}

func _intent(authorizations: Array) -> Dictionary:
	return {"schema_id":"detached_tenant_zone_mutation_intent","schema_version":1,"intent_id":"intent.1","operation":"REFORM","zone_plan_key":"zone.plan","paint_mode":"UNCHANGED","zone_type":"Retail","selected_cells":[],"retirement_authorizations":authorizations}

func _parcel(id: String, geometry: String, tenant: String, profile: String) -> Dictionary:
	return {"parcel_id":id,"parcel_key":id,"geometry_fingerprint":geometry,"tenant_id":tenant,"bound_profile_id":profile,"feasible_profile_ids":[profile] if not profile.is_empty() else [],"suitability":"SUITABLE","selected_core_key":"core","selected_door_semantic_key":"door","selected_queue_envelope_key":"queue","phase_a_parity":{}}

func _base(parcels: Array) -> Dictionary:
	return {"provenance":{"layout_ref":{},"district_revision":1,"zone_revision":1},"requested_district_effects":{"remove_explicit_circulation_cells":[],"add_explicit_circulation_cells":[],"remove_manual_door_edges":[]},"parcels":parcels}

func _formation(parcels: Array) -> Dictionary:
	var records: Array[Dictionary] = []
	for parcel: Dictionary in parcels:
		records.append({"parcel_key":parcel["parcel_key"],"freshness":"AVAILABLE","suitability":parcel["suitability"],"source_parity_fingerprint":null,"feasible_profile_count":parcel["feasible_profile_ids"].size(),"diagnostic_codes":[]})
	return {"parcels":parcels,"residual_decoration_cells":[],"graph_fingerprint":null,"queue_input_fingerprint":null,"queue_envelopes":[],"phase_a_parity":null,"suitability_records":records}

func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)
