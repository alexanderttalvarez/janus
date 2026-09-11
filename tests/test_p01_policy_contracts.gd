## Focused P01 proofs for immutable Economy and Progression policy contracts.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_economy_policy()
	_test_economy_transactions()
	_test_progression_catalog()
	_test_progression_awards_and_unlocks()
	print("P01 policy contract tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _test_economy_policy() -> void:
	var snapshot: EconomyPolicySnapshot = EconomyPolicySnapshot.new()
	_assert(bool(snapshot.configure(EconomyPolicySnapshot.approved_values()).get("valid", false)), "complete approved Economy policy configures")
	for elevation: int in EconomyPolicySnapshot.APPROVED_FLOOR_TILE_COSTS:
		var quote: Dictionary = snapshot.quote("VERTICAL_SPACE", {"elevation": elevation, "tile_count": 1})
		_assert(bool(quote.get("accepted", false)) and int(quote.get("value", -1)) == int(EconomyPolicySnapshot.APPROVED_FLOOR_TILE_COSTS[elevation]), "signed elevation %d has its exact approved unit price" % elevation)
	var overflow_count: int = EconomyPolicySnapshot.MAX_TRANSACTION_VALUE / 1000 + 1
	var overflow: Dictionary = snapshot.quote("PLOT_SECTION", {"section_tile_count": overflow_count})
	_assert(_rejected_with(overflow, "POLICY_VALUE_OVERFLOW"), "quote multiplication rejects safe-integer overflow")
	var invalid_domain: Dictionary = snapshot.quote("VERTICAL_SPACE", {"elevation": 10, "tile_count": 1})
	_assert(_rejected_with(invalid_domain, "POLICY_INPUT_INVALID"), "out-of-domain elevations reject without fallback pricing")
	var incomplete: Dictionary = EconomyPolicySnapshot.approved_values()
	incomplete.erase("demolition_cost")
	_assert(not bool(EconomyPolicySnapshot.new().configure(incomplete).get("valid", false)), "incomplete Economy policy content is rejected")
	_assert(not bool(snapshot.configure(EconomyPolicySnapshot.approved_values()).get("valid", false)), "configured Economy policy is sealed")


func _test_economy_transactions() -> void:
	var economy: EconomyManager = EconomyManager.new()
	root.add_child(economy)
	var progression: Dictionary = {"revision": 7}
	var missing: Dictionary = economy.district_quote({"intent": {"operation": "NO_CHARGE"}, "economy_policy_snapshot": {}, "progression_policy_snapshot": progression})
	_assert(_rejected_with(missing, "POLICY_UNAVAILABLE"), "Economy manager has no implicit policy fallback")
	_assert(bool(economy.set_policy_snapshot(EconomyPolicySnapshot.approved_values()).get("valid", false)), "Economy manager accepts explicit approved content")
	economy.balance = 2500
	var quote: Dictionary = _vertical_quote(economy, progression, 1)
	var first: Dictionary = economy.reserve_quote(quote)
	var second: Dictionary = economy.reserve_quote(quote)
	var third: Dictionary = economy.reserve_quote(quote)
	_assert(bool(first.get("accepted", false)) and bool(second.get("accepted", false)), "non-overlapping available funds permit two reservations")
	_assert(_rejected_with(third, "INSUFFICIENT_FUNDS"), "existing reservations reduce available funds")
	var tampered: Dictionary = first.duplicate(true)
	tampered["reservation_token"]["value"] = 1
	_assert(_rejected_with(economy.district_guarantee_capture(tampered), "TRANSACTION_TOKEN_INVALID"), "reservation value tampering is rejected for capture")
	_assert(_rejected_with(economy.district_cancel(tampered), "TRANSACTION_TOKEN_INVALID"), "reservation value tampering is rejected for cancellation")
	_assert(bool(economy.district_cancel(first).get("accepted", false)) and bool(economy.district_cancel(second).get("accepted", false)), "valid reservations can be cancelled")
	economy.balance = 5000
	economy.set_infinite_money(true)
	var bypass_quote: Dictionary = _vertical_quote(economy, progression, 1)
	economy.set_infinite_money(false)
	var bypass_reservation: Dictionary = economy.reserve_quote(bypass_quote)
	var bypass_guarantee: Dictionary = economy.district_guarantee_capture(bypass_reservation)
	var bypass_capture: Dictionary = economy.district_capture(bypass_guarantee)
	var financial_result: Dictionary = bypass_capture.get("financial_result", {})
	_assert(bool(bypass_capture.get("accepted", false)) and int(financial_result.get("signed_delta", -1)) == 0 and economy.balance == 5000, "quote-time debug bypass remains immutable and reports actual zero delta")
	economy.free()


func _test_progression_catalog() -> void:
	var catalog: ProgressionPolicyCatalog = ProgressionPolicyCatalog.new()
	_assert(bool(catalog.validate_content().get("valid", false)), "Progression catalog validates")
	var expected: Dictionary = {
		"basic_zoning": [0, [], 0, true],
		"advanced_zoning": [1, [], 0, true],
		"anchor_tenants": [2, ["advanced_zoning"], 0, true],
		"basic_corridors": [0, [], 0, true],
		"stairs": [1, [], 0, true],
		"multi_floor": [2, ["stairs"], 0, true],
		"elevators": [2, ["stairs"], 0, true],
		"underground": [3, ["multi_floor"], 0, true],
		"vertical_expansion_i": [1, ["multi_floor"], 2, true],
		"vertical_expansion_ii": [1, ["vertical_expansion_i"], 3, true],
		"vertical_expansion_iii": [1, ["vertical_expansion_ii"], 4, true],
		"deep_foundations": [1, ["underground"], 3, true],
		"transport.bus_stop": [1, ["basic_corridors"], 1, false],
	}
	_assert(catalog.get_node_definitions().size() == expected.size(), "catalog contains exactly the approved P01 node set")
	for node_id: String in expected:
		var definition: Dictionary = catalog.get_node_definition(node_id)
		var contract: Array = expected[node_id]
		_assert(int(definition.get("cost", -1)) == int(contract[0]) and definition.get("prerequisites", []) == contract[1] and int(definition.get("minimum_tier_index", -1)) == int(contract[2]) and bool(definition.get("available_in_product", false)) == bool(contract[3]), "%s has exact cost, prerequisites, tier gate, and availability" % node_id)


func _test_progression_awards_and_unlocks() -> void:
	var progression: TechTreeManager = TechTreeManager.new()
	_assert(not bool(progression.get_policy_snapshot().get("valid", false)), "Progression manager has no implicit catalog fallback")
	_assert(bool(progression.set_policy_catalog(ProgressionPolicyCatalog.new()).get("valid", false)), "Progression manager accepts explicit approved content")
	root.add_child(progression)
	progression.sync_official_tier("neighborhood_center", "Neighborhood Center", 2, 3)
	progression.sync_official_tier("neighborhood_center", "Neighborhood Center", 2, 3)
	_assert(progression.total_earned == 8 and progression.available_points == 8, "direct Neighborhood jump grants 3 plus 5 Tech Points exactly once")
	_assert(progression.plot_access_grants_earned == 2, "direct Neighborhood jump grants exactly two Plot Access selections")
	var core_route: Array[String] = ["advanced_zoning", "anchor_tenants", "stairs", "multi_floor", "elevators"]
	for node_id: String in core_route:
		_assert(bool(progression.unlock_node(node_id).get("valid", false)), "core route unlocks %s" % node_id)
	_assert(progression.available_points == 0, "the complete core route costs exactly eight points")
	var neighborhood_snapshot: Dictionary = progression.get_policy_snapshot()
	_assert(neighborhood_snapshot.get("elevation_eligibility", []) == [0, 1, 2], "Multi-Floor grants exactly F1 and F2")
	_assert(bool(neighborhood_snapshot.get("street_conversion_eligible", false)), "Neighborhood Center enables Street conversion eligibility")
	var bus_result: Dictionary = progression.unlock_node("transport.bus_stop")
	_assert(_rejected_with(bus_result, "CAPABILITY_UNAVAILABLE"), "Bus Stop remains player-unavailable in current MVP")
	_assert(not bool(neighborhood_snapshot.get("capability_eligibility", {}).get("transport.bus_stop", {}).get("eligible", true)), "normal snapshot explicitly reports Bus Stop unavailable")
	progression.sync_official_tier("megacity_mall", "Megacity Mall", 5, 3)
	for node_id: String in ["underground", "vertical_expansion_i", "vertical_expansion_ii", "vertical_expansion_iii", "deep_foundations"]:
		_assert(bool(progression.unlock_node(node_id).get("valid", false)), "vertical route unlocks %s" % node_id)
	var full_snapshot: Dictionary = progression.get_policy_snapshot()
	_assert(full_snapshot.get("elevation_eligibility", []) == TechTreeManager.DEBUG_ELEVATIONS, "extension nodes grant exactly F1-F9 and U1-U5")
	_assert(int(full_snapshot.get("mall_level_index", -1)) == 5 and String(full_snapshot.get("official_tier_id", "")) == "megacity_mall", "Progression snapshot retains committed tier identity")
	progression.free()

	var gated: TechTreeManager = TechTreeManager.new()
	gated.set_policy_catalog(ProgressionPolicyCatalog.new())
	root.add_child(gated)
	gated.sync_official_tier("small_market", "Small Market", 1, 3)
	gated.unlock_node("stairs")
	gated.unlock_node("multi_floor")
	gated.earn_points(1)
	_assert(_rejected_with(gated.unlock_node("vertical_expansion_i"), "MALL_LEVEL_REQUIRED"), "Vertical Expansion I enforces its Neighborhood Center tier gate")
	gated.free()


func _vertical_quote(economy: EconomyManager, progression: Dictionary, elevation: int) -> Dictionary:
	return economy.district_quote({
		"intent": {"operation": "ACQUIRE_SPACE", "elevation": elevation, "tile_count": 1},
		"economy_policy_snapshot": economy.get_policy_snapshot(),
		"progression_policy_snapshot": progression,
	})


func _rejected_with(result: Dictionary, code: String) -> bool:
	return not bool(result.get("accepted", result.get("valid", false))) and _has_code(result.get("diagnostics", []), code)


func _has_code(diagnostics: Array, code: String) -> bool:
	for diagnostic: Variant in diagnostics:
		if diagnostic is Dictionary and String(diagnostic.get("code", "")) == code:
			return true
	return false
