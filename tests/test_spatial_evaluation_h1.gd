## Spatial Evaluation H1 tests for detached facts and fixed-point rent policy.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_circulation_bands()
	_test_relationship_and_competition()
	_test_rent_arithmetic()
	print("Spatial Evaluation H1 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _test_circulation_bands() -> void:
	var poor := CirculationEvaluationSnapshot.create("parcel", "zone", 1, false, 0, 0, 4, "h5")
	var average_ground := CirculationEvaluationSnapshot.create("parcel", "zone", 0, true, 0, 0, 4, "h5")
	var good := CirculationEvaluationSnapshot.create("parcel", "zone", 1, true, 1, 0, 4, "h5")
	var excellent := CirculationEvaluationSnapshot.create("parcel", "zone", 1, true, 1, 1, 4, "h5")
	_assert(poor.to_dictionary()["accessibility_band"] == "poor", "missing public route is Poor")
	_assert(average_ground.to_dictionary()["accessibility_band"] == "average", "ground route is Average")
	_assert(good.to_dictionary()["accessibility_band"] == "good", "one vertical link is Good")
	_assert(excellent.to_dictionary()["accessibility_band"] == "excellent", "stairs and elevator are Excellent")
	_assert(bool(excellent.validate().get("valid", false)), "circulation snapshots validate as detached facts")


func _test_relationship_and_competition() -> void:
	var policy := RentRecommendationPolicy.new()
	var evaluator := ZoneRelationshipEvaluator.new()
	var target: Dictionary = {"zone_id": "zone_a", "zone_type": "Retail", "tiles": [[0, 0]]}
	var others: Array = [
		{"zone_id": "zone_same", "zone_type": "Retail", "tiles": [[1, 0]]},
		{"zone_id": "zone_food", "zone_type": "Food & Beverage", "tiles": [[2, 0]]},
	]
	var result: ZoneRelationshipSnapshot = evaluator.evaluate(target, others, policy, 9)
	var data: Dictionary = result.to_dictionary()
	_assert(data["application_adjacency"] == "positive", "complementary nearby zone produces positive application adjacency")
	_assert(data["selected_zone_id"] == "zone_food", "same-type zones are excluded from application synergy")
	_assert(data["nearest_same_type_distance"] == 1 and data["competition_band"] == "within_10", "same-type proximity produces separate competition band")
	_assert(bool(result.validate().get("valid", false)), "relationship snapshots validate as detached facts")
	var tie_target: Dictionary = {"zone_id": "zone_services", "zone_type": "Services", "tiles": [[0, 0]]}
	var tie: ZoneRelationshipSnapshot = evaluator.evaluate(tie_target, [
		{"zone_id": "z_negative_late", "zone_type": "Entertainment", "tiles": [[2, 0]]},
		{"zone_id": "z_negative_early", "zone_type": "Entertainment", "tiles": [[1, 1]]},
	], policy, 10)
	_assert(tie.to_dictionary()["application_adjacency"] == "negative", "negative application relation is selected")
	_assert(tie.to_dictionary()["selected_zone_id"] == "z_negative_early", "equal negative relation tie preserves canonical stable zone identity")


func _test_rent_arithmetic() -> void:
	var manager := PrestigeManager.new()
	manager.initialize("spatial", PrestigePolicy.new())
	var prestige: OfficialPrestigeSnapshot = manager.get_committed_snapshot()
	var policy := RentRecommendationPolicy.new()
	var circulation := CirculationEvaluationSnapshot.create("parcel", "zone", 0, true, 0, 0, 1, "h5")
	var relationship := ZoneRelationshipSnapshot.new()
	relationship.configure({
		"schema_version": 1,
		"target_zone_id": "zone",
		"application_adjacency": "neutral",
		"selected_zone_id": "",
		"selected_relation_distance": -1,
		"nearest_same_type_distance": -1,
		"competition_band": "none",
		"policy_revision": 1,
		"geometry_revision": 1,
		"provenance": "committed_zone_geometry",
	})
	var calculator := RentRecommendationCalculator.new()
	var ground: Dictionary = calculator.calculate(policy, prestige, circulation, relationship, 0)
	_assert(bool(ground.get("valid", false)), "ground rent recommendation validates")
	_assert(ground["recommended_rent_centi_kreds"] == 425, "ground recommendation uses exact fixed-point arithmetic")
	var upper: Dictionary = calculator.calculate(policy, prestige, circulation, relationship, 1)
	_assert(upper["recommended_rent_centi_kreds"] == 446, "F1 recommendation applies the 1.05 factor")
	var missing: Dictionary = calculator.calculate(policy, null, circulation, relationship, 0)
	_assert(not bool(missing.get("valid", false)) and missing["diagnostics"][0]["code"] == "PRESTIGE_CONTEXT_UNAVAILABLE", "missing Prestige context defers without fallback")
	manager.free()
