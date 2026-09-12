## Session H2 production-orchestrator tests.
extends SceneTree

const TEST_SLOT: int = 4

var _passed: int = 0
var _failed: int = 0
var _save_manager: Node
var _snapshot: ResolvedDistrictSnapshot
var _layout_ref: Dictionary
var _authorities: Dictionary
var _callback_trace: Array[String] = []
var _loaded_count: int = 0
var _failed_count: int = 0
var _publish_count: int = 0
var _reentry_result: Dictionary = {}
var _fixture_factory: RefCounted
var _layout_resolver: RefCounted


func _init() -> void:
	_setup()
	_test_registry_contract()
	_test_successful_candidate_publication()
	_test_fault_matrix_and_leaks()
	_test_required_fixture_matrix()
	_cleanup()
	print("Session H2 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _setup() -> void:
	_fixture_factory = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
	_layout_resolver = load("res://scripts/resources/district_layout_resolver.gd").new()
	var resolution: Dictionary = _layout_resolver.resolve(_fixture_factory.build_fixture("fixture.legacy_25_single"))
	_snapshot = resolution.get("snapshot") as ResolvedDistrictSnapshot
	_layout_ref = {"layout_id": _snapshot.get_layout_id(), "layout_definition_version": int(_snapshot.get_data().get("layout_definition_version", 0)), "definition_fingerprint": _snapshot.get_fingerprint()}
	_authorities = _make_authorities()
	_save_manager = load("res://scripts/autoloads/save_manager.gd").new()
	var configured: Dictionary = _save_manager.configure_runtime(_participants(), Callable(self, "_active_layout"), Callable(self, "_resolve_layout"), Callable(self, "_create_candidate"), _projections(), Callable(self, "_publish_candidate"))
	_assert(bool(configured.get("valid", false)), "exact authority and projection registries configure")
	_assert(bool(_save_manager.configure_session_boundary(SessionMutationGate.new(), Callable(self, "_session_available")).get("valid", false)), "shared non-reentrant session boundary configures")
	_save_manager.game_loaded.connect(_on_loaded)
	_save_manager.restore_failed.connect(_on_restore_failed)
	_save_manager.delete_save(TEST_SLOT)
	_assert(_save_manager.save_game(TEST_SLOT) == OK, "fixture writes through production atomic replacement")


func _participants() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in _expected_authorities():
		result.append({"key": key, "export_snapshot": Callable(self, "_export").bind(key), "validate_snapshot": Callable(self, "_validate").bind(key), "import_snapshot": Callable(self, "_import").bind(key), "cross_validate": Callable(self, "_cross_validate").bind(key)})
	return result


func _projections() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in ["district_world", "public_realm_topology", "camera_gateway", "traffic", "tenant_visitor"]:
		result.append({"key": key, "prepare": Callable(self, "_prepare").bind(key)})
	return result


func _test_registry_contract() -> void:
	var actual: Array[String] = []
	for descriptor: Dictionary in _save_manager.get_v2_authority_registry():
		actual.append(String(descriptor["key"]))
	_assert(actual == _expected_authorities(), "registry exposes the fixed exact authority order")
	var duplicate: Array[Dictionary] = _participants()
	duplicate[1] = duplicate[0].duplicate()
	var invalid_manager: Node = load("res://scripts/autoloads/save_manager.gd").new()
	var rejected: Dictionary = invalid_manager.configure_runtime(duplicate, Callable(self, "_active_layout"), Callable(self, "_resolve_layout"), Callable(self, "_create_candidate"), _projections(), Callable(self, "_publish_candidate"))
	_assert(not bool(rejected.get("valid", false)), "duplicate and missing participants reject configuration")
	invalid_manager.free()


func _test_successful_candidate_publication() -> void:
	_callback_trace.clear()
	var result: Dictionary = _save_manager.load_game(TEST_SLOT)
	_assert(bool(result.get("valid", false)) and _publish_count == 1 and _loaded_count == 1, "one prepared candidate publishes and emits one game_loaded")
	var first_import: int = _callback_trace.find("import:district")
	var last_validation: int = _callback_trace.find("validate:time")
	var first_prepare: int = _callback_trace.find("prepare:district_world")
	var last_import: int = _callback_trace.find("import:time")
	_assert(first_import > last_validation and first_prepare > last_import, "all detached validations precede all durable imports and all imports precede derived preparation")
	_assert(_callback_trace[-1] == "publish" and not _save_manager.is_restore_barrier_active(), "publication is the sole final candidate callback behind the released barrier")
	_assert(_reentry_result.get("reason_code", "") == "RESTORE_ALREADY_IN_PROGRESS", "game_loaded observers cannot reenter restore")
	var accounting: Dictionary = _save_manager.get_candidate_accounting()
	_assert(accounting["created"] == 1 and accounting["retained"] == 1 and accounting["published"] == 1, "one published candidate is retained as the active session")


func _test_fault_matrix_and_leaks() -> void:
	var stages: Array[String] = ["parse", "layout_resolution", "pre_publish"]
	for key: String in _expected_authorities():
		stages.append("validate:%s" % key)
		stages.append("import:%s" % key)
		stages.append("cross_validate:%s" % key)
	for key: String in ["district_world", "public_realm_topology", "camera_gateway", "traffic", "tenant_visitor"]:
		stages.append("prepare:%s" % key)
	var digest: String = JSON.stringify(_authorities, "", true)
	var retained_before: int = int(_save_manager.get_candidate_accounting()["retained"])
	for stage: String in stages:
		_save_manager.set_restore_fault_stage(stage)
		var before_loaded: int = _loaded_count
		var before_publish: int = _publish_count
		var result: Dictionary = _save_manager.load_game(TEST_SLOT)
		_assert(not bool(result.get("valid", false)) and bool(result.get("old_session_preserved", false)) and String(result.get("failed_stage", "")) != "", "%s reports structured preservation and stage diagnostics" % stage)
		_assert(_loaded_count == before_loaded and _publish_count == before_publish and JSON.stringify(_authorities, "", true) == digest, "%s leaves the live authority digest and load count unchanged" % stage)
		_assert(int(_save_manager.get_candidate_accounting()["retained"]) == retained_before, "%s leaves no retained candidate" % stage)
	_save_manager.set_restore_fault_stage("")
	_assert(_failed_count == stages.size(), "every injected staging failure emits exactly one restore_failed")


func _test_required_fixture_matrix() -> void:
	var fixture_ids: Array[String] = ["fixture.legacy_25_single", "fixture.variable_30x40_single", "fixture.mixed_3x3"]
	for fixture_id: String in fixture_ids:
		var resolution: Dictionary = _layout_resolver.resolve(_fixture_factory.build_fixture(fixture_id))
		var next_snapshot: ResolvedDistrictSnapshot = resolution.get("snapshot") as ResolvedDistrictSnapshot
		_assert(bool(resolution.get("valid", false)) and next_snapshot != null, "%s resolves for the headless restore matrix" % fixture_id)
		if next_snapshot == null:
			continue
		_snapshot = next_snapshot
		_layout_ref = {"layout_id": _snapshot.get_layout_id(), "layout_definition_version": int(_snapshot.get_data().get("layout_definition_version", 0)), "definition_fingerprint": _snapshot.get_fingerprint()}
		_authorities = _make_authorities()
		var save_error: Error = _save_manager.save_game(TEST_SLOT)
		var load_result: Dictionary = _save_manager.load_game(TEST_SLOT)
		_assert(save_error == OK and bool(load_result.get("valid", false)), "%s completes one production-orchestrated V2 save/restore" % fixture_id)
	var accounting: Dictionary = _save_manager.get_candidate_accounting()
	_assert(int(accounting.get("retained", 0)) == 1 and bool(accounting.get("active_candidate", false)), "fixture restore cycles retain exactly one published candidate")


func _make_authorities() -> Dictionary:
	var tenant := TenantManager.new()
	var visitor := VisitorManager.new()
	var staff := StaffManager.new()
	var synergy := SynergyManager.new()
	var result: Dictionary = {
		"district": DistrictStateRecords.new().create_baseline(_snapshot),
		"zone_parcel": {"zones": {}, "zone_counter": 0, "parcel_counter": 0, "parcel_display_number_counter": 0},
		"economy": {"balance": 500000, "loans": {}, "loan_counter": 0, "authority_revision": 0, "economy_policy_revision": 1, "settled_staff_weeks": {}},
		"progression": {"unlocked": [], "available_points": 0, "total_earned": 0, "selected_plot_ids": [], "plot_access_grants_earned": 0, "plot_access_grants_consumed": 0, "awarded_milestone_ids": [], "progression_revision": 0, "content_policy_revision": 1},
		"prestige": {"schema_version": 2, "authority_revision": 0, "official_tier_id": "empty_lot", "supported_tenant_tier": 1, "exclusive_eligible": false, "rent_ceiling_centi_kreds": 500, "policy_revision": 1, "calendar_identity": "sim_month:0", "numeric_prestige_present": false, "numeric_prestige": 0, "numeric_prestige_provenance": ""},
		"staff": staff.serialize(), "synergy": synergy.serialize(), "tenant": tenant.serialize(), "visitor": visitor.serialize(), "time": {"sim_time": 0.0, "visual_time": 0.0},
	}
	tenant.free(); visitor.free(); staff.free(); synergy.free()
	return result


func _expected_authorities() -> Array[String]:
	return ["district", "zone_parcel", "economy", "progression", "prestige", "staff", "synergy", "tenant", "visitor", "time"]


func _active_layout() -> Dictionary:
	return _layout_ref.duplicate(true)


func _resolve_layout(value: Dictionary) -> Dictionary:
	var layout_id: String = String(value.get("layout_id", ""))
	var resolution: Dictionary = _layout_resolver.resolve(_fixture_factory.build_fixture(layout_id))
	var resolved_snapshot: ResolvedDistrictSnapshot = resolution.get("snapshot") as ResolvedDistrictSnapshot
	if not bool(resolution.get("valid", false)) or resolved_snapshot == null:
		return {"valid": false, "diagnostics": [{"code": "LAYOUT_ID_UNKNOWN"}]}
	var resolved_ref: Dictionary = {"layout_id": resolved_snapshot.get_layout_id(), "layout_definition_version": int(resolved_snapshot.get_data().get("layout_definition_version", 0)), "definition_fingerprint": resolved_snapshot.get_fingerprint()}
	var valid: bool = value == resolved_ref
	return {"valid": valid, "layout_ref": resolved_ref, "snapshot": resolved_snapshot, "diagnostics": [] if valid else [{"code": "LAYOUT_REFERENCE_MISMATCH"}]}


func _create_candidate(resolved: Dictionary) -> SessionRestoreCandidate:
	var candidate := SessionRestoreCandidate.new()
	return candidate if bool(candidate.initialize(resolved).get("valid", false)) else null


func _export(key: String) -> Dictionary:
	_callback_trace.append("export:%s" % key)
	return _authorities[key].duplicate(true)


func _validate(snapshot: Dictionary, resolved: Dictionary, key: String) -> Dictionary:
	_callback_trace.append("validate:%s" % key)
	if key == "district": return DistrictStateRecords.new().validate(snapshot, resolved["snapshot"])
	if key == "staff":
		var owner := StaffManager.new(); var result: Dictionary = owner.validate_serialized(snapshot); owner.free(); return result
	if key == "synergy":
		var owner := SynergyManager.new(); var result: Dictionary = owner.validate_serialized(snapshot); owner.free(); return result
	if key == "visitor":
		var owner := VisitorManager.new(); var result: Dictionary = owner.validate_serialized(snapshot); owner.free(); return result
	return {"valid": true, "diagnostics": []}


func _import(snapshot: Dictionary, candidate: SessionRestoreCandidate, key: String) -> Dictionary:
	_callback_trace.append("import:%s" % key)
	return candidate.import_authority_snapshot(key, snapshot)


func _cross_validate(_candidate: SessionRestoreCandidate, key: String) -> Dictionary:
	_callback_trace.append("cross_validate:%s" % key)
	return {"valid": true, "diagnostics": []}


func _prepare(candidate: SessionRestoreCandidate, key: String) -> Dictionary:
	_callback_trace.append("prepare:%s" % key)
	return candidate.set_projection(key, RefCounted.new(), {"ready": true})


func _publish_candidate(candidate: SessionRestoreCandidate) -> void:
	_publish_count += 1
	_callback_trace.append("publish")
	_authorities = candidate.authority_snapshots.duplicate(true)


func _on_loaded(_slot: int) -> void:
	_loaded_count += 1
	_reentry_result = _save_manager.load_game(TEST_SLOT)


func _on_restore_failed(_result: Dictionary) -> void:
	_failed_count += 1


func _session_available() -> bool:
	return true


func _cleanup() -> void:
	_save_manager.delete_save(TEST_SLOT)
	_save_manager.free()


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)
