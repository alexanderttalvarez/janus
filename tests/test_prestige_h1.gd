extends SceneTree

## Prestige H1 contract tests: authored initial state, detached commits, and V2 rejection.

var _passed: int = 0
var _failed: int = 0
var _snapshot_events: int = 0
var _tier_events: int = 0


func _init() -> void:
	_test_initial_snapshot_and_policy()
	_test_commit_revision_and_tier_events()
	_test_v2_staging_and_legacy_rejection()
	print("Prestige H1 tests: %d passed, %d failed" % [_passed, _failed])
	call_deferred("quit", 0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _new_manager() -> PrestigeManager:
	var manager: PrestigeManager = load("res://scripts/simulation/prestige_manager.gd").new() as PrestigeManager
	var policy: PrestigePolicy = load("res://scripts/simulation/prestige_policy.gd").new() as PrestigePolicy
	var result: Dictionary = manager.initialize("sim_month:0", policy)
	_assert(bool(result.get("valid", false)), "approved immutable Prestige policy initializes the authority")
	return manager


func _test_initial_snapshot_and_policy() -> void:
	var policy: PrestigePolicy = load("res://scripts/simulation/prestige_policy.gd").new() as PrestigePolicy
	var content: Dictionary = policy.validate_content()
	_assert(bool(content.get("valid", false)), "H1 policy content validates")
	for definition: Dictionary in PrestigePolicy.TIER_DEFINITIONS:
		var tier: Dictionary = policy.get_tier_definition(String(definition["tier_id"]))
		_assert(int(tier["supported_tenant_tier"]) >= 1 and int(tier["rent_ceiling_centi_kreds"]) > 0, "every official tier has an approved tenant cap and rent ceiling")
	var manager: PrestigeManager = _new_manager()
	var snapshot: OfficialPrestigeSnapshot = manager.get_committed_snapshot()
	_assert(snapshot.get_tier_id() == "empty_lot", "new sessions start at authored Empty Lot")
	_assert(snapshot.get_supported_tenant_tier() == 1 and snapshot.get_rent_ceiling_centi_kreds() == 500, "Empty Lot starts at Tenant Tier 1 and 500 centi-Kreds")
	_assert(not snapshot.has_numeric_prestige(), "H1 does not synthesize numeric Prestige")
	var detached: Dictionary = snapshot.to_dictionary()
	detached["rent_ceiling_centi_kreds"] = 9999
	_assert(manager.get_committed_snapshot().get_rent_ceiling_centi_kreds() == 500, "snapshot reads are detached from committed authority state")
	manager.free()


func _test_commit_revision_and_tier_events() -> void:
	var manager: PrestigeManager = _new_manager()
	manager.official_prestige_snapshot_changed.connect(_on_snapshot_changed)
	manager.official_tier_changed.connect(_on_tier_changed)
	var candidate_data: Dictionary = manager.get_committed_snapshot().to_dictionary()
	candidate_data["authority_revision"] = 0
	candidate_data["official_tier_id"] = "small_market"
	candidate_data["supported_tenant_tier"] = 2
	candidate_data["rent_ceiling_centi_kreds"] = 1000
	candidate_data["calendar_identity"] = "sim_month:1"
	var candidate: OfficialPrestigeSnapshot = _snapshot(candidate_data)
	var committed: Dictionary = manager.commit_candidate(candidate)
	_assert(bool(committed.get("valid", false)), "a policy-valid detached candidate commits")
	_assert(manager.get_district_revision() == 1 and manager.get_committed_snapshot().get_tier_id() == "small_market", "PrestigeManager alone assigns the next authority revision")
	_assert(_snapshot_events == 1 and _tier_events == 1, "tier commit emits one snapshot event and one tier event")
	var same_tier_data: Dictionary = manager.get_committed_snapshot().to_dictionary()
	same_tier_data["authority_revision"] = 1
	same_tier_data["calendar_identity"] = "sim_month:2"
	var same_tier: Dictionary = manager.commit_candidate(_snapshot(same_tier_data))
	_assert(bool(same_tier.get("valid", false)) and manager.get_district_revision() == 2, "same-tier committed revisions remain authoritative")
	_assert(_snapshot_events == 2 and _tier_events == 1, "a non-tier snapshot change does not emit a tier event")
	manager.free()


func _test_v2_staging_and_legacy_rejection() -> void:
	var manager: PrestigeManager = _new_manager()
	var legacy: Dictionary = {"prestige": 0, "scale": 0, "quality": 0, "tech_points": 0, "loan_multiplier": 1.0}
	var legacy_result: Dictionary = manager.validate_serialized_state(legacy)
	_assert(not bool(legacy_result.get("valid", false)) and _has_code(legacy_result.get("diagnostics", []), "PRESTIGE_FIELD_MISSING"), "superseded six-factor V2 data is rejected")
	var invalid: Dictionary = manager.get_committed_snapshot().to_dictionary()
	invalid["rent_ceiling_centi_kreds"] = 999
	var invalid_result: Dictionary = manager.deserialize(invalid)
	_assert(not bool(invalid_result.get("valid", false)) and manager.get_district_revision() == 0, "invalid V2 data leaves the committed snapshot unchanged")
	var valid_result: Dictionary = manager.deserialize(manager.get_committed_snapshot().to_dictionary())
	_assert(bool(valid_result.get("valid", false)) and _snapshot_events == 2 and _tier_events == 1, "valid restore stages without emitting Prestige business events")
	manager.free()


func _snapshot(data: Dictionary) -> OfficialPrestigeSnapshot:
	var snapshot: OfficialPrestigeSnapshot = load("res://scripts/simulation/official_prestige_snapshot.gd").new() as OfficialPrestigeSnapshot
	snapshot.configure(data)
	return snapshot


func _on_snapshot_changed(_snapshot_value: OfficialPrestigeSnapshot) -> void:
	_snapshot_events += 1


func _on_tier_changed(_previous: OfficialPrestigeSnapshot, _current: OfficialPrestigeSnapshot) -> void:
	_tier_events += 1


func _has_code(diagnostics: Array, code: String) -> bool:
	for diagnostic: Variant in diagnostics:
		if diagnostic is Dictionary and String(diagnostic.get("code", "")) == code:
			return true
	return false
