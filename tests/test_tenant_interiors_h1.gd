## Detached Tenant Interiors H1 content, planning, visual, and visitor-goal contract tests.
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _compiler: TenantInteriorContentCompiler
var _planner: InteriorLayoutPlanner
var _goal_planner: VisitorGoalPlanner


func _init() -> void:
	_compiler = load("res://scripts/interiors/tenant_interior_content_compiler.gd").new()
	_planner = load("res://scripts/interiors/interior_layout_planner.gd").new()
	_goal_planner = load("res://scripts/interiors/visitor_goal_planner.gd").new()
	_test_canonical_fingerprint_golden()
	_test_content_compilation_and_detachment()
	_test_visual_restrictions_and_missing_default()
	_test_phase_a_and_phase_b()
	_test_search_indeterminate()
	_test_visitor_goals_and_provenance()
	_test_empty_category_exception()
	print("TenantInteriors H1 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_canonical_fingerprint_golden() -> void:
	var utility: CanonicalJsonFingerprint = CanonicalJsonFingerprint.new()
	var result: Dictionary = utility.fingerprint({"b": 2, "a": 1}, "TEST", 1)
	_assert(result.get("canonical_json", "") == "{\"a\":1,\"b\":2}", "RFC 8785 canonical JSON sorts object keys")
	_assert(result.get("fingerprint", "") == "75a6213322c704c44b098b88372e54d3d9720c40a3718ecc586d51f49e83bd95", "domain-separated SHA-256 matches the frozen golden")
	var rejected: Dictionary = utility.fingerprint({"floating": 1.5}, "TEST", 1)
	_assert(not bool(rejected.get("valid", false)) and _has_code(rejected.get("diagnostics", []), "UNSUPPORTED_VALUE"), "canonical semantic values reject floats")


func _test_content_compilation_and_detachment() -> void:
	var bundle: TenantInteriorContentBundle = _bundle()
	var first: Dictionary = _compiler.compile(bundle, false)
	var second: Dictionary = _compiler.compile(bundle, false)
	_assert(bool(first.get("valid", false)), "typed H1 content bundle compiles")
	_assert(first.get("canonical_json", "") == second.get("canonical_json", "") and first.get("fingerprint", "") == second.get("fingerprint", ""), "same content compiles to byte-identical canonical output")
	_assert(String(first.get("fingerprint", "")).length() == 64, "compiled content has lowercase SHA-256 provenance")
	var snapshot: CompiledTenantInteriorContent = first.get("snapshot") as CompiledTenantInteriorContent
	var snapshot_copy: Dictionary = snapshot.get_content()
	snapshot_copy["planning_policy"]["placement_validation_budget"] = 1
	_assert(snapshot.validate_integrity() and snapshot.get_content()["planning_policy"]["placement_validation_budget"] == 10000, "compiled snapshot rejects mutation through defensive copies")
	var detached: Dictionary = first.get("content", {})
	detached["fixtures"][0]["fixture_id"] = "mutated"
	var third: Dictionary = _compiler.compile(bundle, false)
	_assert(third["content"]["fixtures"][0]["fixture_id"] == "fixture.counter", "nested compiled content is deeply detached from consumers")
	bundle.fixtures[0].fixture_id = "mutated_source"
	_assert(third["content"]["fixtures"][0]["fixture_id"] == "fixture.counter", "authored mutation cannot affect an existing compiled value")
	var production_check: Dictionary = _compiler.compile(_bundle(), true)
	_assert(not bool(production_check.get("valid", false)) and _has_code(production_check.get("diagnostics", []), "VISUAL_NOT_PRODUCTION_RESOURCE"), "test-only visuals cannot satisfy production content compilation")
	var completeness_check: Dictionary = _compiler.compile(_bundle(), false, true)
	_assert(not bool(completeness_check.get("valid", false)) and _has_code(completeness_check.get("diagnostics", []), "REQUIRED_SUBTYPE_MISSING"), "production completeness requires every approved operational subtype")


func _test_visual_restrictions_and_missing_default() -> void:
	var bundle: TenantInteriorContentBundle = _bundle()
	bundle.fixtures[0].default_visual = null
	var missing: Dictionary = _compiler.compile(bundle, false)
	_assert(not bool(missing.get("valid", false)) and _has_code(missing.get("diagnostics", []), "CONTENT_UNAVAILABLE"), "missing default visual rejects the content bundle")
	var forbidden_visual: FixtureVisualDefinition = _visual("visual.forbidden", true)
	var diagnostics: Array[Dictionary] = _compiler.validate_visual(forbidden_visual, "$.visual", false)
	_assert(_has_code(diagnostics, "VISUAL_BEHAVIOR_FORBIDDEN"), "collision or navigation behavior is forbidden in fixture visuals")


func _test_phase_a_and_phase_b() -> void:
	var compiled: CompiledTenantInteriorContent = _compiler.compile(_bundle(), false).get("snapshot") as CompiledTenantInteriorContent
	var phase_a_request: Dictionary = _request()
	var first: Dictionary = _planner.plan_phase_a(phase_a_request, compiled)
	var second: Dictionary = _planner.plan_phase_a(phase_a_request.duplicate(true), compiled)
	_assert(first.get("status", "") == "VALID", "Phase A reports a physically feasible profile")
	_assert(first == second, "Phase A is deterministic for equivalent detached inputs")
	var stable_request: Dictionary = phase_a_request.duplicate(true)
	stable_request.merge({"parcel_id": "parcel.1", "door_id": "door.1", "proxy_id": "proxy.1", "queue_envelope_id": "queue.1", "zone_revision": 3, "door_revision": 2, "queue_envelope_revision": 4}, true)
	var stable_result: Dictionary = _planner.plan_phase_a_stable(stable_request, compiled, String(first.get("feasible_pool_fingerprint", "")))
	_assert(stable_result.get("status", "") == "VALID", "stable-identity Phase A reproduces the prospective feasible pool")
	var mismatched_pool: Dictionary = _planner.plan_phase_a_stable(stable_request, compiled, "wrong")
	_assert(_has_code(mismatched_pool.get("diagnostics", []), "PHASE_A_POOL_MISMATCH"), "Zone publication is blocked when stable Phase A pool parity fails")
	_assert(not first.has("final_fingerprint") and not _contains_key_recursive(first, "fixture_id"), "Phase A allocates no durable fixture identity or final fingerprint")
	var illegal_phase_a: Dictionary = phase_a_request.duplicate(true)
	illegal_phase_a["parcel_id"] = "parcel.1"
	_assert(_planner.plan_phase_a(illegal_phase_a, compiled).get("status", "") == "CONTENT_INVALID", "Phase A rejects persistent identities")
	var phase_b_request: Dictionary = phase_a_request.duplicate(true)
	phase_b_request.merge({
		"parcel_id": "parcel.1",
		"door_id": "door.1",
		"proxy_id": "proxy.1",
		"queue_envelope_id": "queue.1",
		"operational_profile_id": "profile.counter",
		"tenant_profile_id": "tenant.kiosk",
		"variation_id": "variation.1",
		"zone_revision": 3,
		"door_revision": 2,
		"queue_envelope_revision": 4,
	}, true)
	var phase_b: Dictionary = _planner.plan_phase_b(phase_b_request, compiled)
	_assert(phase_b.get("status", "") == "VALID" and String(phase_b.get("final_fingerprint", "")).length() == 64, "Phase B requires stable identities and produces a final fingerprint")
	_assert((phase_b.get("selected_layout", {}).get("placements", []) as Array).size() == 2, "Phase B proves mandatory fixture placement")
	_assert(int(phase_b.get("selected_layout", {}).get("capacity", 0)) == 2, "capacity derives from fixture envelopes")
	_assert(phase_b.get("selected_layout", {}).get("rating", "") == "EXCELLENT" and int(phase_b.get("selected_layout", {}).get("tickets", 0)) == 6, "no-repeatable profile receives Excellent within target and annex limits")
	_assert(String(phase_b.get("selected_layout", {}).get("placements", [])[0].get("fixture_instance_id", "")).begins_with("interior_fixture/parcel.1/"), "Phase B assigns deterministic durable fixture identities")
	var economic_noise: Dictionary = phase_b_request.duplicate(true)
	economic_noise["rent"] = 999999
	economic_noise["prestige"] = 999
	_assert(_planner.plan_phase_b(economic_noise, compiled).get("final_fingerprint", "") == phase_b.get("final_fingerprint", ""), "commercial and Prestige inputs cannot affect physical planning")
	var changed_variation: Dictionary = phase_b_request.duplicate(true)
	changed_variation["variation_id"] = "variation.2"
	_assert(_planner.plan_phase_b(changed_variation, compiled).get("final_fingerprint", "") != phase_b.get("final_fingerprint", ""), "candidate variation identity participates in the final fingerprint")


func _test_search_indeterminate() -> void:
	var bundle: TenantInteriorContentBundle = _bundle()
	bundle.planning_policy.revision = 2
	bundle.planning_policy.placement_validation_budget = 1
	var compiled: CompiledTenantInteriorContent = _compiler.compile(bundle, false).get("snapshot") as CompiledTenantInteriorContent
	var result: Dictionary = _planner.plan_phase_a(_request(), compiled)
	_assert(result.get("status", "") == "SEARCH_INDETERMINATE" and _has_code(result.get("diagnostics", []), "SEARCH_INDETERMINATE"), "search exhaustion is distinct from physical infeasibility")


func _test_visitor_goals_and_provenance() -> void:
	var policy: Dictionary = _bundle().visitor_policy.to_record()
	var first: Dictionary = _goal_planner.generate("session.seed", 42, 7, "visitor.7", ["DINING", "RETAIL"], policy)
	var second: Dictionary = _goal_planner.generate("session.seed", 42, 7, "visitor.7", ["DINING", "RETAIL"], policy)
	_assert(first == second and bool(first.get("valid", false)), "visitor goal generation is seeded and deterministic")
	var record: Dictionary = first.get("record", {})
	_assert((record["goals"] as Array).size() >= 1 and (record["goals"] as Array).size() <= 3, "visitor receives one to three goals")
	_assert(int(record["wait_tolerance_ticks"]) >= 2 and int(record["wait_tolerance_ticks"]) <= 8, "wait tolerance uses the authored inclusive 2-8 tick range")
	_assert(bool(_goal_planner.validate_record(record, policy).get("valid", false)), "visitor provenance validates without rerolling")
	_assert(String(record.get("captured_category_fingerprint", "")).length() == 64, "captured operational categories have distinct provenance")
	var excluded: Dictionary = _goal_planner.exclude_tenant(record, "tenant.1")
	_assert(excluded["current_goal_excluded_tenant_ids"] == ["tenant.1"], "current-goal tenant exclusion is persisted")
	var advanced: Dictionary = _goal_planner.complete_active(excluded, policy)
	_assert(bool(advanced.get("valid", false)) and advanced["record"]["current_goal_excluded_tenant_ids"].is_empty(), "goal completion advances and clears exclusions")
	var tampered: Dictionary = record.duplicate(true)
	tampered["goals"][0]["goal_id"] = "TAMPERED"
	_assert(not bool(_goal_planner.validate_record(tampered, policy).get("valid", false)), "historical generation fingerprint rejects rerolled or changed goals")
	var malformed: Dictionary = record.duplicate(true)
	malformed["active_goal_index"] = "wrong"
	_assert(not bool(_goal_planner.validate_record(malformed, policy).get("valid", false)), "malformed restored visitor provenance rejects without reroll")
	_assert(not bool(_goal_planner.generate("session.seed", 42, 9, "visitor.9", ["RETAIL", "RETAIL"], policy).get("valid", false)), "duplicate categories cannot bias deterministic goal weights")


func _test_empty_category_exception() -> void:
	var policy: Dictionary = _bundle().visitor_policy.to_record()
	var generated: Dictionary = _goal_planner.generate("session.seed", 42, 8, "visitor.8", [], policy)
	var record: Dictionary = generated.get("record", {})
	_assert(bool(generated.get("valid", false)) and record["captured_category_marker"] == "EMPTY", "empty operational categories retain explicit provenance")
	_assert((record["goals"] as Array).size() == 1 and record["goals"][0]["goal_id"] == "BROWSING" and bool(record["goals"][0]["dropped"]), "empty categories generate exactly one immediately dropped Browsing goal")
	_assert(record["next_state"] == "LEAVING", "empty-category Browsing exception assigns Leaving")


func _bundle() -> TenantInteriorContentBundle:
	var visual: FixtureVisualDefinition = _visual("visual.counter", false)
	var fixture: InteriorFixtureDefinition = InteriorFixtureDefinition.new()
	fixture.fixture_id = "fixture.counter"
	fixture.revision = 1
	fixture.occupied_cells = [Vector2i(0, 0)]
	fixture.clearance_cells = [Vector2i(1, 0)]
	fixture.allowed_rotations = [0, 90, 180, 270]
	fixture.interaction_face = "EAST"
	fixture.placement_rule = "FRONTAGE"
	fixture.tags = ["public_counter"]
	fixture.capacity = 1
	fixture.capacity_token = "COUNTER"
	fixture.program_role = InteriorFixtureDefinition.ProgramRole.MANDATORY_SERVICE
	fixture.placement_priority = 1
	fixture.default_visual = visual
	var service: ServicePolicyDefinition = ServicePolicyDefinition.new()
	service.service_policy_id = "service.counter"
	service.revision = 1
	service.typology = "COUNTER"
	service.stages = [{"stage_id": "COUNTER", "duration_ticks": 2}]
	service.queue_cap = 4
	service.capacity_tokens = ["COUNTER"]
	var profile: OperationalProfileDefinition = OperationalProfileDefinition.new()
	profile.operational_profile_id = "profile.counter"
	profile.revision = 1
	profile.subtype_id = "kiosk"
	profile.zone_type = "Food & Beverage"
	profile.minimum_area = 6
	profile.core_width = 2
	profile.core_depth = 3
	profile.target_area_min = 6
	profile.target_area_max = 9
	profile.minimum_frontage = 1
	profile.queue_cap = 4
	profile.queue_required = true
	profile.service_policy_id = service.service_policy_id
	profile.fixture_program = [{"fixture_id": fixture.fixture_id, "count": 2, "kind": "MANDATORY", "priority": 1}]
	var tenant_profile: InteriorTenantProfileDefinition = InteriorTenantProfileDefinition.new()
	tenant_profile.profile_id = "tenant.kiosk"
	tenant_profile.candidate_revision = 1
	tenant_profile.theme_id = "theme.kiosk"
	tenant_profile.subtype_id = profile.subtype_id
	tenant_profile.zone_type = profile.zone_type
	tenant_profile.tier = 1
	tenant_profile.operational_profile_id = profile.operational_profile_id
	var visitor_policy: VisitorServicePolicyDefinition = VisitorServicePolicyDefinition.new()
	visitor_policy.visitor_policy_id = "visitor.default"
	var bundle: TenantInteriorContentBundle = TenantInteriorContentBundle.new()
	bundle.bundle_id = "test.tenant_interiors"
	bundle.revision = 1
	bundle.fixtures = [fixture]
	bundle.service_policies = [service]
	bundle.operational_profiles = [profile]
	bundle.tenant_profiles = [tenant_profile]
	bundle.visitor_policy = visitor_policy
	bundle.planning_policy = InteriorPlanningPolicy.new()
	return bundle


func _visual(id: String, forbidden_collision: bool) -> FixtureVisualDefinition:
	var root: Node3D = Node3D.new()
	root.name = "FixtureVisual"
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.5, 0.5, 0.5)
	mesh_instance.mesh = mesh
	root.add_child(mesh_instance)
	mesh_instance.owner = root
	if forbidden_collision:
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.name = "Collision"
		root.add_child(collision)
		collision.owner = root
	var scene: PackedScene = PackedScene.new()
	scene.pack(root)
	root.free()
	var visual: FixtureVisualDefinition = FixtureVisualDefinition.new()
	visual.visual_id = id
	visual.revision = 1
	visual.scene = scene
	visual.envelope_min_millimeters = Vector3i(-500, -500, -500)
	visual.envelope_max_millimeters = Vector3i(500, 500, 500)
	return visual


func _request() -> Dictionary:
	var cells: Array[Array] = []
	for y: int in range(3):
		for x: int in range(3):
			cells.append([x, y])
	return {
		"plan_local_parcel_key": "prospective.1",
		"zone_type": "Food & Beverage",
		"usable_cells": cells,
		"core_cells": [[0, 0], [1, 0], [0, 1], [1, 1], [0, 2], [1, 2]],
		"annex_cells": [],
		"frontage_cells": [[0, 0], [0, 1], [0, 2]],
		"wall_cells": [[0, 0], [1, 0], [2, 0], [0, 2], [1, 2], [2, 2]],
		"frontage_length": 3,
		"selected_door_cell": [0, 2],
		"queue_cells": [[-1, 1], [-1, 2]],
		"operational_profile_ids": ["profile.counter"],
	}


func _contains_key_recursive(value: Variant, searched_key: String) -> bool:
	if value is Dictionary:
		if value.has(searched_key):
			return true
		for child: Variant in value.values():
			if _contains_key_recursive(child, searched_key):
				return true
	elif value is Array:
		for child: Variant in value:
			if _contains_key_recursive(child, searched_key):
				return true
	return false


func _has_code(diagnostics: Array, code: String) -> bool:
	for diagnostic_value: Variant in diagnostics:
		if diagnostic_value is Dictionary and diagnostic_value.get("code", "") == code:
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)
