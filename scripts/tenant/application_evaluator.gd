class_name ApplicationEvaluator
extends RefCounted

## Pure Tenant H2 score and threshold evaluation.


func evaluate(context: ApplicationEvaluationContext) -> Dictionary:
	if context == null:
		return _failure("EVALUATION_INPUT_UNAVAILABLE", "application context is required")
	var validation := context.validate()
	if not bool(validation.get("valid", false)):
		return {"valid": false, "outcome": "deferred", "diagnostics": validation.get("diagnostics", [])}
	var data := context.to_dictionary()
	var supported_tier: int = int(data["supported_prestige_tier"])
	var candidate_tier: int = int(data["candidate_tier"])
	var prestige_match := 100
	var hard_decline_reason := ""
	if supported_tier == candidate_tier - 1:
		prestige_match = -50
	elif supported_tier < candidate_tier - 1:
		hard_decline_reason = "HARD_DECLINE_PRESTIGE"
	var rent_result := _rent_attractiveness(int(data["actual_rent_centi_kreds"]), int(data["recommended_rent_centi_kreds"]))
	if not bool(rent_result["valid"]):
		return _failure("RECOMMENDATION_INPUT_UNAVAILABLE", "recommended rent must be positive")
	var rent_score: int = int(rent_result["score"])
	if bool(rent_result["hard_decline"]):
		hard_decline_reason = "HARD_DECLINE_RENT"
	var elevation: int = int(data["elevation"])
	var elevator_bonus: int = 1 if int(data["valid_elevator_count"]) > 0 else 0
	var stairs_bonus: int = 1 if int(data["valid_stair_count"]) > 0 else 0
	var floor_distance: int = absi(elevation)
	var location_score: int = maxi(0, 50 - (4 - elevator_bonus - stairs_bonus) * floor_distance)
	var synergy_bonus: int = 20 if String(data["application_adjacency"]) == "positive" else (-10 if String(data["application_adjacency"]) == "negative" else 0)
	var competition_penalty: int = -20 if String(data["competition_band"]) == "within_10" else (-10 if String(data["competition_band"]) == "within_20" else 0)
	var score: int = prestige_match + rent_score + location_score + synergy_bonus + competition_penalty
	var threshold: int = 80 + (candidate_tier - 1) * 10 + int(data["selectivity"])
	var passed: bool = hard_decline_reason.is_empty() and score >= threshold
	var outcome := "passed" if passed else "declined"
	var diagnostic_code := "" if passed else (hard_decline_reason if not hard_decline_reason.is_empty() else "APPLICATION_SCORE_BELOW_THRESHOLD")
	return {
		"valid": true,
		"outcome": outcome,
		"candidate_id": String(data["candidate_id"]),
		"parcel_id": String(data["parcel_id"]),
		"zone_id": String(data["zone_id"]),
		"component_scores": {
			"prestige_match": prestige_match,
			"rent_attractiveness": rent_score,
			"location_score": location_score,
			"synergy_bonus": synergy_bonus,
			"competition_penalty": competition_penalty,
		},
		"score": score,
		"threshold": threshold,
		"hard_decline_reason": hard_decline_reason,
		"diagnostic_code": diagnostic_code,
		"next_evaluation_after_days": 0 if passed else 3,
		"source_revisions": {
			"prestige_authority_revision": int(data["prestige_authority_revision"]),
			"topology_revision": int(data["topology_revision"]),
			"geometry_revision": int(data["geometry_revision"]),
			"rate_revision": int(data["rate_revision"]),
			"policy_revision": int(data["policy_revision"]),
		},
		"provenance": String(data["provenance"]),
		"diagnostics": [] if passed else [{"code": diagnostic_code}],
	}


func _rent_attractiveness(actual: int, recommended: int) -> Dictionary:
	if recommended <= 0 or actual < 0:
		return {"valid": false, "score": 0, "hard_decline": false}
	if actual <= recommended:
		return {"valid": true, "score": 30, "hard_decline": false}
	var delta: int = actual - recommended
	if delta * 100 <= recommended * 10:
		return {"valid": true, "score": 20, "hard_decline": false}
	if delta * 100 <= recommended * 20:
		return {"valid": true, "score": 10, "hard_decline": false}
	if delta * 100 <= recommended * 30:
		return {"valid": true, "score": 0, "hard_decline": false}
	return {"valid": true, "score": -20, "hard_decline": true}


func _failure(code: String, message: String) -> Dictionary:
	return {"valid": false, "outcome": "deferred", "diagnostics": [{"code": code, "message": message}]}
