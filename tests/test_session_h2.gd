## Session H2 tests for registry order, detached restore, barrier, and faults.
extends SceneTree


const TEST_SLOT: int = 4

var _passed: int = 0
var _failed: int = 0
var _save_manager: Node
var _snapshot: ResolvedDistrictSnapshot
var _layout_ref: Dictionary
var _authorities: Dictionary
var _commit_count: int = 0
var _commit_saw_barrier: bool = false
var _loaded_count: int = 0
var _failed_count: int = 0


func _init() -> void:
	_setup()
	_test_registry_order()
	_test_successful_restore_barrier()
	_test_faults_preserve_session()
	_cleanup()
	print("Session H2 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _setup() -> void:
	var factory: RefCounted = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
	var resolver: RefCounted = load("res://scripts/resources/district_layout_resolver.gd").new() as DistrictLayoutResolver
	var resolution: Dictionary = resolver.resolve(factory.build_fixture("A"))
	_assert(bool(resolution.get("valid", false)), "H2 test fixture resolves")
	_snapshot = resolution.get("snapshot") as ResolvedDistrictSnapshot
	_layout_ref = {"layout_id": _snapshot.get_layout_id(), "layout_definition_version": int(_snapshot.get_data().get("layout_definition_version", 0)), "definition_fingerprint": _snapshot.get_fingerprint()}
	_authorities = {"district": DistrictStateRecords.new().create_baseline(_snapshot), "zone_parcel": {"zones": {}, "parcel_counter": 0, "parcel_display_number_counter": 0}, "tenant": {"tenants": [], "counter": 0}, "visitor": {"visitors": [], "counter": 0}, "economy": {"balance": 500000, "loans": {}, "loan_counter": 0}, "progression": {"unlocked": [], "available_points": 0, "total_earned": 0}, "prestige": {"schema_version": 2, "authority_revision": 0, "official_tier_id": "empty_lot", "supported_tenant_tier": 1, "exclusive_eligible": false, "rent_ceiling_centi_kreds": 500, "policy_revision": 1, "calendar_identity": "sim_month:0", "numeric_prestige_present": false, "numeric_prestige": 0, "numeric_prestige_provenance": ""}, "staff": {"rooms": 0, "staff": 0, "staff_counter": 0, "room_counter": 0}, "synergy": {"zone_scores": {}}, "time": {"sim_time": 0.0, "visual_time": 0.0}}
	_save_manager = load("res://scripts/autoloads/save_manager.gd").new()
	_save_manager.configure_runtime(Callable(self, "_get_authorities"), Callable(self, "_get_layout_ref"), Callable(self, "_validate_authorities"), Callable(self, "_commit_authorities"))
	_save_manager.game_loaded.connect(_on_loaded)
	_save_manager.restore_failed.connect(_on_restore_failed)
	_save_manager.delete_save(TEST_SLOT)
	_assert(_save_manager.save_game(TEST_SLOT) == OK, "H2 fixture is written through the production V2 save path")


func _test_registry_order() -> void:
	var expected: Array[String] = ["district", "zone_parcel", "economy", "progression", "prestige", "staff", "synergy", "tenant", "visitor", "time"]
	var actual: Array[String] = []
	for entry: Dictionary in _save_manager.get_v2_authority_registry():
		actual.append(String(entry.get("key", "")))
	_assert(actual == expected, "SaveManager exposes the exact Session H2 registry order")
	_assert(_save_manager.get_v2_authority_fields() == expected, "registry order is the sole V2 authority key order")


func _test_successful_restore_barrier() -> void:
	var before: Dictionary = _authorities.duplicate(true)
	var result: Dictionary = _save_manager.load_game(TEST_SLOT)
	_assert(bool(result.get("valid", false)) and _commit_count == 1 and _loaded_count == 1, "valid restore commits exactly once and emits one game_loaded")
	_assert(_commit_saw_barrier and not _save_manager.is_restore_barrier_active(), "session commit runs behind the restore barrier and releases it afterward")
	_assert(_save_manager.get_restore_trace() == ["restore_requested", "parse", "detached_validation", "candidate_staged", "commit_barrier", "committed", "game_loaded"], "restore reports fixed stage ordering")
	var restored_json: String = JSON.stringify(_authorities, "", true)
	var before_json: String = JSON.stringify(before, "", true)
	before_json = before_json.replace("\"sim_time\":0.0", "\"sim_time\":0").replace("\"visual_time\":0.0", "\"visual_time\":0")
	_assert(restored_json == before_json, "successful restore publishes the detached authority snapshot")


func _test_faults_preserve_session() -> void:
	var stages: Array[String] = ["parse", "authority_validation", "projection_preparation", "commit"]
	for stage: String in stages:
		_save_manager.set_restore_fault_stage(stage)
		var before_commit: int = _commit_count
		var before_loaded: int = _loaded_count
		var result: Dictionary = _save_manager.load_game(TEST_SLOT)
		_assert(not bool(result.get("valid", false)) and bool(result.get("old_session_preserved", false)) and bool(result.get("slot_preserved", false)), "injected %s failure preserves old session and slot" % stage)
		_assert(_commit_count == before_commit and _loaded_count == before_loaded, "injected %s failure emits no commit or game_loaded" % stage)
		_save_manager.set_restore_fault_stage("")
	_assert(_failed_count == stages.size(), "each discarded candidate emits one structured restore_failed result")


func _get_authorities() -> Dictionary:
	return _authorities.duplicate(true)


func _get_layout_ref() -> Dictionary:
	return _layout_ref.duplicate(true)


func _validate_authorities(authorities: Dictionary, _candidate_layout: Dictionary) -> Dictionary:
	var validation: Dictionary = DistrictStateRecords.new().validate(authorities.get("district", {}), _snapshot)
	return {"valid": bool(validation.get("valid", false)), "diagnostics": validation.get("diagnostics", [])}


func _commit_authorities(authorities: Dictionary, _candidate_layout: Dictionary) -> Dictionary:
	_commit_count += 1
	_commit_saw_barrier = _save_manager.is_restore_barrier_active()
	_authorities = authorities.duplicate(true)
	return {"valid": true, "diagnostics": []}


func _on_loaded(_slot: int) -> void:
	_loaded_count += 1


func _on_restore_failed(_result: Dictionary) -> void:
	_failed_count += 1


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
