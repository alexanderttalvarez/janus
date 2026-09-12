## District H9 tests for exact V2, structured incompatibility, and verified replacement.
extends SceneTree

const TEST_SLOT: int = 5

var _passed: int = 0
var _failed: int = 0
var _manager: Node
var _snapshot: ResolvedDistrictSnapshot
var _layout_ref: Dictionary
var _authorities: Dictionary
var _events: Array[String] = []


func _init() -> void:
	_setup()
	_test_exact_envelope_and_round_trip()
	_test_structured_incompatibility()
	_test_verified_replacement_failure()
	_cleanup()
	print("Save/Load H9 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _setup() -> void:
	var factory: RefCounted = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
	var resolver: RefCounted = load("res://scripts/resources/district_layout_resolver.gd").new()
	var resolved: Dictionary = resolver.resolve(factory.build_fixture("A"))
	_snapshot = resolved.get("snapshot") as ResolvedDistrictSnapshot
	_layout_ref = {"layout_id": _snapshot.get_layout_id(), "layout_definition_version": int(_snapshot.get_data().get("layout_definition_version", 0)), "definition_fingerprint": _snapshot.get_fingerprint()}
	_authorities = _make_authorities()
	_manager = load("res://scripts/autoloads/save_manager.gd").new()
	var setup: Dictionary = _manager.configure_runtime(_participants(), Callable(self, "_active_layout"), Callable(self, "_resolve_layout"), Callable(self, "_create_candidate"), _projections(), Callable(self, "_publish"))
	_assert(bool(setup.get("valid", false)), "H9 exact production registry configures")
	_assert(bool(_manager.configure_session_boundary(SessionMutationGate.new(), Callable(self, "_available")).get("valid", false)), "H9 shared session gate configures")
	_manager.game_loaded.connect(func(_slot: int): _events.append("game_loaded"))
	_manager.delete_save(TEST_SLOT)


func _participants() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in _manager.get_v2_authority_fields():
		result.append({"key": key, "export_snapshot": Callable(self, "_export").bind(key), "validate_snapshot": Callable(self, "_validate").bind(key), "import_snapshot": Callable(self, "_import").bind(key), "cross_validate": Callable(self, "_cross_validate").bind(key)})
	return result


func _projections() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in ["district_world", "public_realm_topology", "camera_gateway", "traffic", "tenant_visitor"]:
		result.append({"key": key, "prepare": Callable(self, "_prepare").bind(key)})
	return result


func _test_exact_envelope_and_round_trip() -> void:
	var envelope: Dictionary = _manager.build_v2_envelope(TEST_SLOT, _authorities, _layout_ref, 123456)
	_assert(envelope.keys().size() == 4 and envelope["authorities"].keys().size() == 10, "V2 root and authority set are exact")
	_assert(bool(_manager.validate_v2_envelope(envelope, TEST_SLOT).get("valid", false)), "exact detached V2 validates against resolved content")
	_assert(_manager.save_game(TEST_SLOT) == OK and _manager.has_save(TEST_SLOT), "V2 slot writes successfully")
	_assert(not FileAccess.file_exists("user://saves/%d.json.tmp" % TEST_SLOT) and not FileAccess.file_exists("user://saves/%d.json.bak" % TEST_SLOT), "verified replacement leaves no temporary or backup file")
	_events.clear()
	var loaded: Dictionary = _manager.load_game(TEST_SLOT)
	_assert(bool(loaded.get("valid", false)) and _events == ["publish", "game_loaded"], "canonical load publishes once before one game_loaded")


func _test_structured_incompatibility() -> void:
	var absent: Dictionary = _manager.validate_v2_envelope({"meta": {"slot": TEST_SLOT}}, TEST_SLOT)
	_assert(_first_code(absent) == "SAVE_SCHEMA_ABSENT", "schema-absent data has a stable incompatibility code")
	var v1: Dictionary = _manager.build_v2_envelope(TEST_SLOT, _authorities, _layout_ref, 1)
	v1["save_schema_version"] = 1
	_assert(_first_code(_manager.validate_v2_envelope(v1, TEST_SLOT)) == "SAVE_SCHEMA_V1_UNSUPPORTED", "V1 has a distinct no-migration incompatibility code")
	var unknown: Dictionary = _manager.build_v2_envelope(TEST_SLOT, _authorities, _layout_ref, 1)
	unknown["authorities"]["unknown"] = {}
	_assert(_first_code(_manager.validate_v2_envelope(unknown, TEST_SLOT)) == "UNKNOWN_FIELD", "unknown authority keys reject before candidate construction")
	var unknown_layout: Dictionary = _manager.build_v2_envelope(TEST_SLOT, _authorities, _layout_ref, 1)
	unknown_layout["layout_ref"]["layout_id"] = "missing"
	var layout_result: Dictionary = _manager.validate_v2_envelope(unknown_layout, TEST_SLOT)
	_assert(not bool(layout_result.get("valid", false)) and String(layout_result["diagnostics"][0].get("stage", "")) == "layout_resolution", "unknown saved layout resolves through content registry and rejects structurally")


func _test_verified_replacement_failure() -> void:
	var path: String = "user://saves/%d.json" % TEST_SLOT
	var before_file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var before: String = before_file.get_as_text()
	before_file.close()
	_authorities["economy"]["balance"] = 123
	_manager.set_restore_fault_stage("write:replace")
	var result: Error = _manager.save_game(TEST_SLOT)
	_manager.set_restore_fault_stage("")
	var after_file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var after: String = after_file.get_as_text()
	after_file.close()
	_assert(result != OK and after == before, "replacement failure restores the prior slot byte-for-byte")
	var diagnostics: Array = _manager.get_last_write_diagnostics()
	_assert(not diagnostics.is_empty() and diagnostics[0].get("stage", "") == "write_replace", "replacement failure reports its exact write stage")


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


func _active_layout() -> Dictionary:
	return _layout_ref.duplicate(true)


func _resolve_layout(value: Dictionary) -> Dictionary:
	if value != _layout_ref: return {"valid": false, "diagnostics": [{"code": "LAYOUT_ID_UNKNOWN"}]}
	return {"valid": true, "layout_ref": _layout_ref.duplicate(true), "snapshot": _snapshot, "diagnostics": []}


func _create_candidate(resolved: Dictionary) -> SessionRestoreCandidate:
	var candidate := SessionRestoreCandidate.new()
	return candidate if bool(candidate.initialize(resolved).get("valid", false)) else null


func _export(key: String) -> Dictionary:
	return _authorities[key].duplicate(true)


func _validate(snapshot: Dictionary, resolved: Dictionary, key: String) -> Dictionary:
	if key == "district": return DistrictStateRecords.new().validate(snapshot, resolved["snapshot"])
	if key == "synergy":
		var owner := SynergyManager.new(); var result: Dictionary = owner.validate_serialized(snapshot); owner.free(); return result
	if key == "staff":
		var owner := StaffManager.new(); var result: Dictionary = owner.validate_serialized(snapshot); owner.free(); return result
	if key == "visitor":
		var owner := VisitorManager.new(); var result: Dictionary = owner.validate_serialized(snapshot); owner.free(); return result
	return {"valid": true, "diagnostics": []}


func _import(snapshot: Dictionary, candidate: SessionRestoreCandidate, key: String) -> Dictionary:
	return candidate.import_authority_snapshot(key, snapshot)


func _cross_validate(_candidate: SessionRestoreCandidate, _key: String) -> Dictionary:
	return {"valid": true, "diagnostics": []}


func _prepare(candidate: SessionRestoreCandidate, key: String) -> Dictionary:
	return candidate.set_projection(key, RefCounted.new(), {"ready": true})


func _publish(candidate: SessionRestoreCandidate) -> void:
	_events.append("publish")
	_authorities = candidate.authority_snapshots.duplicate(true)


func _available() -> bool:
	return true


func _first_code(result: Dictionary) -> String:
	return String(result.get("diagnostics", [{}])[0].get("code", ""))


func _cleanup() -> void:
	_manager.delete_save(TEST_SLOT)
	_manager.free()


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)
