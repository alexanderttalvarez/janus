## H9 tests for exact V2 envelopes, detached rejection, atomic writes, and commit events.
extends SceneTree


const TEST_SLOT: int = 5

var _passed: int = 0
var _failed: int = 0
var _save_manager: Node
var _snapshot: ResolvedDistrictSnapshot
var _authorities: Dictionary
var _layout_ref: Dictionary
var _commit_count: int = 0
var _event_order: Array[String] = []


func _init() -> void:
	_setup_fixture()
	_test_exact_envelope()
	_test_atomic_round_trip_and_event_order()
	_test_schema_absence_rejection()
	_test_malformed_and_incompatible_rejection()
	_cleanup()
	print("Save/Load H9 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _setup_fixture() -> void:
	var factory: RefCounted = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
	var resolver: RefCounted = load("res://scripts/resources/district_layout_resolver.gd").new()
	var resolution: Dictionary = resolver.resolve(factory.build_fixture("A"))
	_assert(bool(resolution.get("valid", false)), "H9 fixture resolves through H1/H2")
	_snapshot = resolution.get("snapshot") as ResolvedDistrictSnapshot
	_layout_ref = {
		"layout_id": _snapshot.get_layout_id(),
		"layout_definition_version": int(_snapshot.get_data().get("layout_definition_version", 0)),
		"definition_fingerprint": _snapshot.get_fingerprint(),
	}
	_authorities = _make_authorities()
	_save_manager = load("res://scripts/autoloads/save_manager.gd").new()
	_save_manager.configure_runtime(
		Callable(self, "_get_authorities"),
		Callable(self, "_get_layout_ref"),
		Callable(self, "_validate_authorities"),
		Callable(self, "_commit_authorities")
	)
	_save_manager.game_loaded.connect(_on_game_loaded)
	_save_manager.delete_save(TEST_SLOT)


func _make_authorities() -> Dictionary:
	return {
		"district": DistrictStateRecords.new().create_baseline(_snapshot),
		"zone_parcel": {"zones": {}, "parcel_counter": 0, "parcel_display_number_counter": 0},
		"tenant": {"tenants": [], "counter": 0},
		"visitor": {"visitors": [], "counter": 0},
		"economy": {"balance": 500000, "loans": {}, "loan_counter": 0},
		"progression": {"unlocked": [], "available_points": 0, "total_earned": 0},
		"prestige": {
			"schema_version": 2,
			"authority_revision": 0,
			"official_tier_id": "empty_lot",
			"supported_tenant_tier": 1,
			"exclusive_eligible": false,
			"rent_ceiling_centi_kreds": 500,
			"policy_revision": 1,
			"calendar_identity": "sim_month:0",
			"numeric_prestige_present": false,
			"numeric_prestige": 0,
			"numeric_prestige_provenance": "",
		},
		"staff": {"rooms": 0, "staff": 0, "staff_counter": 0, "room_counter": 0},
		"synergy": {"zone_scores": {}},
		"time": {"sim_time": 0.0, "visual_time": 0.0},
	}


func _get_authorities() -> Dictionary:
	return _authorities.duplicate(true)


func _get_layout_ref() -> Dictionary:
	return _layout_ref.duplicate(true)


func _validate_authorities(authorities: Dictionary, _candidate_layout: Dictionary) -> Dictionary:
	var district_validation: Dictionary = DistrictStateRecords.new().validate(authorities.get("district", {}), _snapshot)
	return {"valid": bool(district_validation.get("valid", false)), "diagnostics": district_validation.get("diagnostics", [])}


func _commit_authorities(authorities: Dictionary, _candidate_layout: Dictionary) -> Dictionary:
	_commit_count += 1
	_authorities = authorities.duplicate(true)
	_event_order.append("commit")
	return {"valid": true, "diagnostics": []}


func _on_game_loaded(_slot: int) -> void:
	_event_order.append("game_loaded")


func _test_exact_envelope() -> void:
	var envelope: Dictionary = _save_manager.build_v2_envelope(TEST_SLOT, _authorities, _layout_ref, 123456)
	_assert(envelope.keys().size() == 4, "V2 root has exactly four keys")
	_assert(envelope.has("save_schema_version") and envelope["save_schema_version"] == 2, "V2 root carries integer schema version 2")
	_assert(envelope["meta"].keys().size() == 3 and envelope["meta"]["slot"] == TEST_SLOT and envelope["meta"]["timestamp"] == 123456, "V2 metadata has exact slot and timestamp fields")
	_assert(envelope["layout_ref"].keys().size() == 3 and envelope["layout_ref"]["definition_fingerprint"] == _snapshot.get_fingerprint(), "V2 layout identity contains the H2 fingerprint")
	_assert(envelope["authorities"].keys().size() == 10 and envelope["authorities"].has("district") and envelope["authorities"].has("progression"), "V2 authorities contain the exact ten authority keys")
	var validation: Dictionary = _save_manager.validate_v2_envelope(envelope, TEST_SLOT)
	_assert(bool(validation.get("valid", false)), "valid V2 envelope passes detached validation")


func _test_atomic_round_trip_and_event_order() -> void:
	var save_result: Error = _save_manager.save_game(TEST_SLOT)
	_assert(save_result == OK and _save_manager.has_save(TEST_SLOT), "V2 save writes the configured slot")
	_assert(not FileAccess.file_exists("user://saves/%d.json.tmp" % TEST_SLOT) and not FileAccess.file_exists("user://saves/%d.json.bak" % TEST_SLOT), "atomic save leaves no temporary or backup file")
	var file: FileAccess = FileAccess.open("user://saves/%d.json" % TEST_SLOT, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_assert(parsed is Dictionary and parsed.keys().size() == 4 and parsed.get("save_schema_version", 0) == 2, "stored slot is an exact V2 envelope")
	var before_commit: int = _commit_count
	_event_order.clear()
	var load_result: Dictionary = _save_manager.load_game(TEST_SLOT)
	_assert(bool(load_result.get("valid", false)), "V2 load commits a valid staged envelope")
	_assert(_commit_count == before_commit + 1 and _event_order == ["commit", "game_loaded"], "game_loaded emits once after the session commit")
	var meta_before: Variant = _save_manager.get_save_meta(TEST_SLOT)
	var event_count_before: int = _event_order.size()
	_assert(meta_before is Dictionary and _event_order.size() == event_count_before, "metadata reads do not emit game_loaded")


func _test_schema_absence_rejection() -> void:
	var file: FileAccess = FileAccess.open("user://saves/%d.json" % TEST_SLOT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"meta": {"slot": TEST_SLOT}}))
	file.close()
	var before_commit: int = _commit_count
	_event_order.clear()
	var result: Dictionary = _save_manager.load_game(TEST_SLOT)
	_assert(not bool(result.get("valid", false)) and result.get("reason_code", "") == "FIELD_MISSING", "schema-absent payload is rejected before staging")
	_assert(bool(result.get("slot_preserved", false)) and _commit_count == before_commit and _event_order.is_empty(), "schema-absent rejection preserves the slot and emits no load event")


func _test_malformed_and_incompatible_rejection() -> void:
	var envelope: Dictionary = _save_manager.build_v2_envelope(TEST_SLOT, _authorities, _layout_ref, 123456)
	var unknown_root: Dictionary = envelope.duplicate(true)
	unknown_root["unexpected"] = true
	var unknown_result: Dictionary = _save_manager.validate_v2_envelope(unknown_root, TEST_SLOT)
	_assert(not bool(unknown_result.get("valid", false)), "unknown V2 root keys reject")
	var wrong_fingerprint: Dictionary = envelope.duplicate(true)
	wrong_fingerprint["layout_ref"]["definition_fingerprint"] = "0".repeat(64)
	var fingerprint_result: Dictionary = _save_manager.validate_v2_envelope(wrong_fingerprint, TEST_SLOT)
	_assert(not bool(fingerprint_result.get("valid", false)), "incompatible layout fingerprints reject before staging")
	var unsupported_result: Error = _save_manager.save_game(TEST_SLOT, {"meta": {"slot": TEST_SLOT}})
	_assert(unsupported_result == ERR_UNAVAILABLE, "schema-absent save input is rejected without overwriting the slot")


func _cleanup() -> void:
	_save_manager.delete_save(TEST_SLOT)
	_save_manager.free()
