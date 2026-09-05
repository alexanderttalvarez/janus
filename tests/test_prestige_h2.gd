## Prestige H2 tests for developed-tile Scale and baseline Quality.
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _snapshot_events: int = 0


func _init() -> void:
	_test_scale_values()
	_test_candidate_and_commit()
	_test_stale_source_rejection()
	print("Prestige H2 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _make_source(revision: int, count: int) -> DevelopedTileSnapshot:
	var ids: Array = []
	for index: int in range(count):
		ids.append("tile_%04d" % index)
	return DevelopedTileSnapshot.from_ids(revision, ids, "district_authority")


func _test_scale_values() -> void:
	var expected: Array[int] = [0, 1, 4, 399, 400, 401]
	var expected_scale: Array[int] = [0, 1, 4, 399, 400, 400]
	for index: int in range(expected.size()):
		var source := _make_source(1, expected[index])
		var result: Dictionary = source.validate()
		_assert(bool(result.get("valid", false)), "developed source validates at %d tiles" % expected[index])
		var candidate: OfficialPrestigeCandidate = OfficialPrestigeCandidate.calculate(source, "month_%d" % expected[index], PrestigePolicy.POLICY_REVISION)
		var candidate_result: Dictionary = candidate.validate()
		_assert(bool(candidate_result.get("valid", false)), "candidate validates at %d tiles" % expected[index])
		_assert(int(candidate.to_dictionary()["scale_quarters"]) == expected_scale[index], "Scale quarters clamp at %d tiles" % expected[index])
		_assert(int(candidate.to_dictionary()["baseline_quality"]) == 20, "baseline Quality remains 20 at %d tiles" % expected[index])
		_assert(int(candidate.to_dictionary()["numeric_prestige"]) == expected_scale[index] * 5, "Prestige uses exact quarter arithmetic at %d tiles" % expected[index])
	var duplicate_source := DevelopedTileSnapshot.from_ids(2, ["same", "same", "other"], "district_authority")
	_assert(duplicate_source.get_developed_tile_count() == 2, "duplicate qualifications count once per stable tile")


func _test_candidate_and_commit() -> void:
	var manager := PrestigeManager.new()
	var initialized: Dictionary = manager.initialize("calendar_h2", PrestigePolicy.new())
	_assert(bool(initialized.get("valid", false)), "H2 manager initializes through H1 policy")
	var source := _make_source(7, 400)
	var candidate: OfficialPrestigeCandidate = manager.create_monthly_candidate(source, "month_1")
	_assert(bool(candidate.validate().get("valid", false)), "monthly candidate is detached and valid")
	var event_count: int = 0
	_snapshot_events = 0
	manager.official_prestige_snapshot_changed.connect(_on_snapshot_changed)
	var committed: Dictionary = manager.commit_monthly_candidate(candidate, 7)
	_assert(bool(committed.get("valid", false)), "valid monthly candidate commits through H1")
	var snapshot: OfficialPrestigeSnapshot = manager.get_committed_snapshot()
	_assert(snapshot.has_numeric_prestige() and snapshot.get_numeric_prestige() == 2000, "committed snapshot preserves official numeric Prestige")
	_assert(snapshot.get_numeric_prestige_provenance() == OfficialPrestigeCandidate.PROVENANCE, "committed snapshot preserves calculation provenance")
	_assert(_snapshot_events == 1, "monthly commit publishes one H1 snapshot event")
	var empty_candidate: OfficialPrestigeCandidate = manager.create_monthly_candidate(_make_source(8, 0), "month_2")
	_assert(bool(manager.commit_monthly_candidate(empty_candidate, 8).get("valid", false)), "zero-developed-tile candidate commits without fallback factors")
	_assert(manager.get_committed_snapshot().get_numeric_prestige() == 0, "zero developed tiles produce zero official Prestige")
	manager.free()


func _on_snapshot_changed(_snapshot: OfficialPrestigeSnapshot) -> void:
	_snapshot_events += 1


func _test_stale_source_rejection() -> void:
	var manager := PrestigeManager.new()
	manager.initialize("calendar_h2_stale", PrestigePolicy.new())
	var candidate: OfficialPrestigeCandidate = manager.create_monthly_candidate(_make_source(3, 4), "month_stale")
	var rejected: Dictionary = manager.commit_monthly_candidate(candidate, 4)
	_assert(not bool(rejected.get("valid", false)), "stale developed source candidate is rejected")
	_assert(manager.get_committed_snapshot().get_tier_id() == "empty_lot", "stale candidate leaves official state unchanged")
	var no_source: Dictionary = manager.recalculate()
	_assert(not bool(no_source.get("valid", false)), "missing monthly source does not fabricate a candidate")
	manager.free()
