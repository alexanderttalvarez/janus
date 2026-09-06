## Tenant H3 candidate catalog and deterministic selection tests.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	var first_manager := TenantManager.new()
	first_manager.initialize(null, 777)
	var first: Dictionary = first_manager.generate_candidate("zone_a", "parcel_a", "Retail", 6, [], [], 1, 10, TenantCandidatePolicy.new())
	_assert(bool(first.get("valid", false)), "valid legal parcel produces a candidate")
	_assert(int(first.get("candidate_tier", 99)) <= 1, "candidate tier is capped by supported Prestige tier")
	_assert(int(first.get("selectivity", 99)) >= -10 and int(first.get("selectivity", -99)) <= 20, "candidate selectivity uses the inclusive policy range")
	var second_manager := TenantManager.new()
	second_manager.initialize(null, 777)
	var second: Dictionary = second_manager.generate_candidate("zone_a", "parcel_a", "Retail", 6, [], [], 1, 10, TenantCandidatePolicy.new())
	_assert(first.get("candidate_profile_id", "") == second.get("candidate_profile_id", "") and first.get("selectivity", 99) == second.get("selectivity", -99), "selection is stable across manager instances")
	var blocked: Dictionary = first_manager.generate_candidate("zone_a", "parcel_b", "Retail", 5, [], [], 1, 10, TenantCandidatePolicy.new())
	_assert(not bool(blocked.get("valid", false)), "undersized parcel produces no fallback candidate")
	_assert(first_manager.evaluation_result("parcel_b").get("next_evaluation_day", -1) == 13, "unavailable candidate schedules the documented three-day retry")
	var excluded: Dictionary = first_manager.generate_candidate("zone_a", "parcel_c", "Retail", 6, [], ["retail.fashion", "retail.electronics", "retail.home_goods", "retail.jewelry", "retail.bookstore"], 1, 10, TenantCandidatePolicy.new())
	_assert(not bool(excluded.get("valid", false)), "adjacency exclusion can remove every legal subtype")
	first_manager.free()
	second_manager.free()
	print("Tenant H3 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)
