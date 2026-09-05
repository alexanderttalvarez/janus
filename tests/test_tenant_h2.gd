## Tenant H2 application score and rate intent tests.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_score_components()
	_test_rent_and_hard_declines()
	print("Tenant H2 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _context(actual_rate: int, candidate_tier: int = 1, supported_tier: int = 1, selectivity: int = -10, prestige_revision: int = 4) -> ApplicationEvaluationContext:
	var context := ApplicationEvaluationContext.new()
	context.configure({
		"schema_version": 1,
		"candidate_id": "candidate_a",
		"parcel_id": "parcel_a",
		"zone_id": "zone_a",
		"subtype_id": "retail.fashion",
		"candidate_profile_id": "tier1.retail.fashion",
		"candidate_tier": candidate_tier,
		"selectivity": selectivity,
		"supported_prestige_tier": supported_tier,
		"rent_ceiling_centi_kreds": 1000,
		"recommended_rent_centi_kreds": 1000,
		"actual_rent_centi_kreds": actual_rate,
		"rate_revision": 2,
		"elevation": 1,
		"public_route_reaches_frontage": true,
		"valid_stair_count": 1,
		"valid_elevator_count": 1,
		"application_adjacency": "positive",
		"competition_band": "within_10",
		"prestige_authority_revision": prestige_revision,
		"topology_revision": 8,
		"geometry_revision": 6,
		"calendar_identity": "day_30",
		"policy_revision": 1,
		"provenance": "tenant_h2_test",
	})
	return context


func _test_score_components() -> void:
	var result := ApplicationEvaluator.new().evaluate(_context(1000))
	_assert(bool(result.get("valid", false)), "complete application context evaluates")
	_assert(result.get("outcome", "") == "passed", "documented favorable application passes")
	var scores: Dictionary = result.get("component_scores", {})
	_assert(scores.get("prestige_match", -1) == 100, "Prestige Match is +100 when supported")
	_assert(scores.get("rent_attractiveness", -1) == 30, "rent at recommendation scores +30")
	_assert(scores.get("location_score", -1) == 48, "location score uses floor and both vertical links")
	_assert(scores.get("synergy_bonus", -1) == 20, "complementary relation scores +20")
	_assert(scores.get("competition_penalty", 0) == -20, "within-ten competition scores -20")
	_assert(result.get("threshold", -1) == 70, "threshold applies Tier 1 and selectivity exactly")


func _test_rent_and_hard_declines() -> void:
	var ten_percent := ApplicationEvaluator.new().evaluate(_context(1100))
	_assert(ten_percent.get("component_scores", {}).get("rent_attractiveness", -1) == 20, "10 percent rent premium scores +20")
	var twenty_one_percent := ApplicationEvaluator.new().evaluate(_context(1210))
	_assert(twenty_one_percent.get("component_scores", {}).get("rent_attractiveness", -1) == 0, "30 percent boundary remains neutral")
	var high_rent := ApplicationEvaluator.new().evaluate(_context(1301))
	_assert(high_rent.get("diagnostic_code", "") == "HARD_DECLINE_RENT", "more than 30 percent rent is a hard decline")
	var low_prestige := ApplicationEvaluator.new().evaluate(_context(1000, 3, 1))
	_assert(low_prestige.get("diagnostic_code", "") == "HARD_DECLINE_PRESTIGE", "two-tier Prestige gap is a hard decline")
	var missing := ApplicationEvaluator.new().evaluate(null)
	_assert(missing.get("outcome", "") == "deferred", "missing evaluation input defers without binding")
