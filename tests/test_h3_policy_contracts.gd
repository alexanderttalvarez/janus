## H3 policy-boundary proofs for Plot Access and Economy snapshots.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_progression()
	_test_economy()
	print("H3 policy contract tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _test_progression() -> void:
	var factory: RefCounted = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
	var resolver: RefCounted = load("res://scripts/resources/district_layout_resolver.gd").new()
	var resolution: Dictionary = resolver.resolve(factory.build_fixture("C"))
	_assert(bool(resolution.get("valid", false)), "Fixture C resolves for progression")
	var snapshot: ResolvedDistrictSnapshot = resolution.get("snapshot") as ResolvedDistrictSnapshot
	var progression: TechTreeManager = load("res://scripts/simulation/tech_tree_manager.gd").new() as TechTreeManager
	root.add_child(progression)
	progression.sync_mall_level(5)
	progression.sync_mall_level(5)
	_assert(progression.plot_access_grants_earned == 8, "all five mall milestones grant exactly eight additional selections")
	_assert(progression.awarded_milestone_ids.size() == 5, "mall milestone identities prevent duplicate grants")
	var selected_result: Dictionary = {}
	for plot: Dictionary in snapshot.get_data().get("plots", []):
		selected_result = progression.select_plot(String(plot.get("id", "")), snapshot)
		if bool(selected_result.get("valid", false)):
			break
	_assert(bool(selected_result.get("valid", false)), "an orthogonally adjacent Plot can be selected")
	var policy: Dictionary = progression.get_policy_snapshot()
	_assert(int(policy.get("plot_access_grants_remaining", -1)) == 7, "Plot selection consumes one committed Plot Access grant")
	_assert(not progression.is_elevation_eligible(3) and not progression.is_elevation_eligible(-4), "higher normal elevations are explicitly unavailable")
	_assert(not bool(policy.get("street_conversion_eligible", true)), "Street conversion is gated below Neighborhood Center")
	progression.free()


func _test_economy() -> void:
	var economy: EconomyManager = load("res://scripts/simulation/economy_manager.gd").new() as EconomyManager
	root.add_child(economy)
	var progression_policy: Dictionary = {"revision": 1, "elevation_eligibility": [0, 1, 2, -1, -2, -3]}
	var policy: Dictionary = economy.get_policy_snapshot()
	var quote: Dictionary = economy.district_quote({"intent": {"operation": "ACQUIRE_SPACE", "elevation": 1, "tile_count": 1}, "economy_policy_snapshot": policy, "progression_policy_snapshot": progression_policy})
	_assert(bool(quote.get("accepted", false)) and int(quote.get("value", -1)) == 1200, "vertical-space quotes use the immutable H2 price table")
	var reservation: Dictionary = economy.reserve_quote(quote)
	var stale_quote: Dictionary = quote.duplicate(true)
	economy.set_policy_snapshot({"revision": 2})
	var stale_reservation: Dictionary = economy.reserve_quote(stale_quote)
	_assert(not bool(stale_reservation.get("accepted", false)) and _has_code(stale_reservation.get("diagnostics", []), "STALE_QUOTE"), "policy revision changes invalidate old quotes")
	policy = economy.get_policy_snapshot()
	quote = economy.district_quote({"intent": {"operation": "ACQUIRE_SPACE", "elevation": 1, "tile_count": 1}, "economy_policy_snapshot": policy, "progression_policy_snapshot": progression_policy})
	reservation = economy.reserve_quote(quote)
	var guaranteed: Dictionary = economy.district_guarantee_capture(reservation)
	var captured: Dictionary = economy.district_capture(guaranteed)
	_assert(bool(captured.get("accepted", false)) and economy.balance == 498800, "guaranteed capture debits exactly once")
	var replay: Dictionary = economy.district_capture(guaranteed)
	_assert(not bool(replay.get("accepted", false)) and _has_code(replay.get("diagnostics", []), "TRANSACTION_TOKEN_INVALID"), "capture tokens cannot be replayed")
	var cancelled: Dictionary = economy.reserve_quote(economy.district_quote({"intent": {"operation": "NO_CHARGE"}, "economy_policy_snapshot": economy.get_policy_snapshot(), "progression_policy_snapshot": progression_policy}))
	_assert(bool(economy.district_cancel(cancelled).get("accepted", false)), "reservation cancellation releases an ephemeral claim")
	var missing_policy: Dictionary = economy.district_quote({"intent": {"operation": "ACQUIRE_SPACE", "elevation": 1, "tile_count": 1}, "economy_policy_snapshot": {}, "progression_policy_snapshot": progression_policy})
	_assert(not bool(missing_policy.get("accepted", false)) and _has_code(missing_policy.get("diagnostics", []), "POLICY_UNAVAILABLE"), "missing economy policy rejects without a fallback price")
	economy.free()


func _has_code(diagnostics: Array, code: String) -> bool:
	for diagnostic: Variant in diagnostics:
		if diagnostic is Dictionary and String(diagnostic.get("code", "")) == code:
			return true
	return false
