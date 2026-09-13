## Pure deterministic H1 visitor goal generation and provenance/state transitions.
class_name VisitorGoalPlanner
extends RefCounted

const GENERATION_DOMAIN: String = "JANUS_VISITOR_GOAL_GENERATION"
const SCHEMA_VERSION: int = 1


func generate(seed_domain_id: String, behavior_seed: int, creation_ordinal: int, visitor_id: String, operational_categories: Array[String], policy: Dictionary) -> Dictionary:
	var diagnostics: Array[Dictionary] = _validate_generation_inputs(seed_domain_id, creation_ordinal, visitor_id, operational_categories, policy)
	if not diagnostics.is_empty():
		return {"valid": false, "record": {}, "diagnostics": diagnostics}
	var categories: Array[String] = operational_categories.duplicate()
	categories.sort()
	var empty_categories: bool = categories.is_empty()
	var goals: Array[Dictionary] = []
	var draw_index: int = 0
	if empty_categories:
		goals.append(_goal(String(policy["empty_category_goal_id"]), 0, true, false))
	else:
		var count_roll: int = _draw(seed_domain_id, behavior_seed, creation_ordinal, visitor_id, int(policy["revision"]), draw_index, 100)
		draw_index += 1
		var weights: Array = policy["goal_count_weights"]
		var goal_count: int = 1 if count_roll < int(weights[0]) else (2 if count_roll < int(weights[0]) + int(weights[1]) else 3)
		for goal_index: int in range(goal_count):
			var category_index: int = _draw(seed_domain_id, behavior_seed, creation_ordinal, visitor_id, int(policy["revision"]), draw_index, categories.size())
			draw_index += 1
			goals.append(_goal(categories[category_index], goal_index, false, false))
	var wait_span: int = int(policy["wait_tolerance_max_ticks"]) - int(policy["wait_tolerance_min_ticks"]) + 1
	var wait_tolerance: int = int(policy["wait_tolerance_min_ticks"]) + _draw(seed_domain_id, behavior_seed, creation_ordinal, visitor_id, int(policy["revision"]), draw_index, wait_span)
	var category_values: Dictionary = {"visitor_policy_id": policy["visitor_policy_id"], "visitor_policy_revision": policy["revision"], "captured_categories": categories, "empty_categories": empty_categories}
	var category_fingerprint_result: Dictionary = CanonicalJsonFingerprint.new().fingerprint(category_values, GENERATION_DOMAIN + ".CATEGORY_SNAPSHOT", SCHEMA_VERSION)
	if not bool(category_fingerprint_result.get("valid", false)):
		return {"valid": false, "record": {}, "diagnostics": category_fingerprint_result.get("diagnostics", [])}
	var generation_values: Dictionary = {
		"seed_domain_id": seed_domain_id,
		"behavior_seed": behavior_seed,
		"creation_ordinal": creation_ordinal,
		"visitor_id": visitor_id,
		"visitor_policy_id": policy["visitor_policy_id"],
		"visitor_policy_revision": policy["revision"],
		"captured_categories": categories,
		"empty_categories": empty_categories,
		"generated_goal_ids": _goal_ids(goals),
		"wait_tolerance_ticks": wait_tolerance,
	}
	var fingerprint_result: Dictionary = CanonicalJsonFingerprint.new().fingerprint(generation_values, GENERATION_DOMAIN, SCHEMA_VERSION)
	if not bool(fingerprint_result.get("valid", false)):
		return {"valid": false, "record": {}, "diagnostics": fingerprint_result.get("diagnostics", [])}
	var record: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"capability_id": "tenant_interiors.visitor_goals",
		"capability_revision": 1,
		"visitor_policy_id": policy["visitor_policy_id"],
		"visitor_policy_revision": policy["revision"],
		"seed_domain_id": seed_domain_id,
		"behavior_seed": behavior_seed,
		"creation_ordinal": creation_ordinal,
		"visitor_id": visitor_id,
		"captured_categories": categories,
		"captured_category_marker": "EMPTY" if empty_categories else "PRESENT",
		"captured_category_fingerprint": category_fingerprint_result["fingerprint"],
		"generation_fingerprint": fingerprint_result["fingerprint"],
		"goals": goals,
		"active_goal_index": 1 if empty_categories else 0,
		"wait_tolerance_ticks": wait_tolerance,
		"current_goal_excluded_tenant_ids": [],
		"next_state": String(policy["leaving_goal_id"]) if empty_categories else "ACTIVE_GOAL",
	}
	return {"valid": true, "record": record, "diagnostics": []}


func validate_record(record: Dictionary, policy: Dictionary) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	var required: Array[String] = [
		"schema_version", "capability_id", "capability_revision", "visitor_policy_id", "visitor_policy_revision",
		"seed_domain_id", "behavior_seed", "creation_ordinal", "visitor_id", "captured_categories",
		"captured_category_marker", "captured_category_fingerprint", "generation_fingerprint", "goals", "active_goal_index",
		"wait_tolerance_ticks", "current_goal_excluded_tenant_ids", "next_state",
	]
	required.sort()
	if _sorted_keys(record) != required:
		return {"valid": false, "diagnostics": [_diagnostic("VISITOR_PROVENANCE_INVALID", "$", {"reason": "fields"})]}
	if not _record_types_valid(record):
		return {"valid": false, "diagnostics": [_diagnostic("VISITOR_PROVENANCE_INVALID", "$", {"reason": "types"})]}
	if int(record["schema_version"]) != SCHEMA_VERSION or record["capability_id"] != "tenant_interiors.visitor_goals" or int(record["capability_revision"]) != 1:
		diagnostics.append(_diagnostic("VISITOR_PROVENANCE_INVALID", "$", {"reason": "capability"}))
	if record["visitor_policy_id"] != policy.get("visitor_policy_id", "") or int(record["visitor_policy_revision"]) != int(policy.get("revision", 0)):
		diagnostics.append(_diagnostic("VISITOR_PROVENANCE_INVALID", "$", {"reason": "policy"}))
	var categories: Array[String] = []
	for value: Variant in record["captured_categories"]:
		if not value is String:
			diagnostics.append(_diagnostic("VISITOR_PROVENANCE_INVALID", "$.captured_categories", {"reason": "type"}))
		else:
			categories.append(String(value))
	var sorted_categories: Array[String] = categories.duplicate()
	sorted_categories.sort()
	if categories != sorted_categories or categories.has("") or _has_duplicates(categories):
		diagnostics.append(_diagnostic("VISITOR_PROVENANCE_INVALID", "$.captured_categories", {}))
	var empty_categories: bool = categories.is_empty()
	if record["captured_category_marker"] != ("EMPTY" if empty_categories else "PRESENT"):
		diagnostics.append(_diagnostic("VISITOR_PROVENANCE_INVALID", "$.captured_category_marker", {}))
	var category_values: Dictionary = {"visitor_policy_id": record["visitor_policy_id"], "visitor_policy_revision": record["visitor_policy_revision"], "captured_categories": categories, "empty_categories": empty_categories}
	var category_fingerprint: Dictionary = CanonicalJsonFingerprint.new().fingerprint(category_values, GENERATION_DOMAIN + ".CATEGORY_SNAPSHOT", SCHEMA_VERSION)
	if category_fingerprint.get("fingerprint", "") != record["captured_category_fingerprint"]:
		diagnostics.append(_diagnostic("VISITOR_CATEGORY_FINGERPRINT_MISMATCH", "$.captured_category_fingerprint", {}))
	var goals: Array = record["goals"]
	var active_index: int = int(record["active_goal_index"])
	if goals.is_empty() or active_index < 0 or active_index > goals.size():
		diagnostics.append(_diagnostic("VISITOR_GOAL_STATE_INVALID", "$.goals", {}))
	for index: int in range(goals.size()):
		if not goals[index] is Dictionary:
			diagnostics.append(_diagnostic("VISITOR_GOAL_STATE_INVALID", "$.goals[%d]" % index, {"reason": "type"}))
			continue
		var goal: Dictionary = goals[index]
		var goal_id: String = String(goal.get("goal_id", ""))
		var is_resolved: bool = bool(goal.get("completed", false)) or bool(goal.get("dropped", false))
		if _sorted_keys(goal) != ["completed", "dropped", "goal_id", "ordinal"] or int(goal.get("ordinal", -1)) != index or goal_id.is_empty() or bool(goal.get("completed", false)) and bool(goal.get("dropped", false)):
			diagnostics.append(_diagnostic("VISITOR_GOAL_STATE_INVALID", "$.goals[%d]" % index, {}))
		if empty_categories:
			if goals.size() != 1 or goal_id != policy.get("empty_category_goal_id", "") or not bool(goal.get("dropped", false)):
				diagnostics.append(_diagnostic("VISITOR_GOAL_STATE_INVALID", "$.goals[%d]" % index, {}))
		elif not categories.has(goal_id):
			diagnostics.append(_diagnostic("VISITOR_GOAL_STATE_INVALID", "$.goals[%d].goal_id" % index, {}))
		if index < active_index and not is_resolved or index >= active_index and is_resolved:
			diagnostics.append(_diagnostic("VISITOR_GOAL_STATE_INVALID", "$.goals[%d]" % index, {"reason": "progress"}))
	var wait: int = int(record["wait_tolerance_ticks"])
	if wait < int(policy.get("wait_tolerance_min_ticks", 0)) or wait > int(policy.get("wait_tolerance_max_ticks", 0)):
		diagnostics.append(_diagnostic("VISITOR_WAIT_POLICY_INVALID", "$.wait_tolerance_ticks", {"value": wait}))
	var expected: Dictionary = generate(String(record["seed_domain_id"]), int(record["behavior_seed"]), int(record["creation_ordinal"]), String(record["visitor_id"]), categories, policy)
	if not bool(expected.get("valid", false)) or _goal_ids(expected.get("record", {}).get("goals", [])) != _goal_ids(goals) or expected.get("record", {}).get("wait_tolerance_ticks", -1) != wait:
		diagnostics.append(_diagnostic("VISITOR_GENERATION_MISMATCH", "$", {}))
	if expected.get("record", {}).get("generation_fingerprint", "") != record["generation_fingerprint"]:
		diagnostics.append(_diagnostic("VISITOR_GENERATION_FINGERPRINT_MISMATCH", "$.generation_fingerprint", {}))
	var exclusions: Array = record["current_goal_excluded_tenant_ids"]
	var exclusions_are_strings: bool = true
	for exclusion: Variant in exclusions:
		if not exclusion is String or String(exclusion).is_empty():
			exclusions_are_strings = false
	var sorted_exclusions: Array = exclusions.duplicate()
	if exclusions_are_strings:
		sorted_exclusions.sort()
	if not exclusions_are_strings or exclusions != sorted_exclusions or _has_duplicates(exclusions) or active_index >= goals.size() and not exclusions.is_empty():
		diagnostics.append(_diagnostic("VISITOR_GOAL_STATE_INVALID", "$.current_goal_excluded_tenant_ids", {}))
	var expected_state: String = String(policy["leaving_goal_id"]) if active_index >= goals.size() else "ACTIVE_GOAL"
	if record["next_state"] != expected_state:
		diagnostics.append(_diagnostic("VISITOR_GOAL_STATE_INVALID", "$.next_state", {}))
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}


func complete_active(record: Dictionary, policy: Dictionary) -> Dictionary:
	return _advance(record, policy, true)


func drop_active(record: Dictionary, policy: Dictionary) -> Dictionary:
	return _advance(record, policy, false)


func exclude_tenant(record: Dictionary, tenant_id: String) -> Dictionary:
	var updated: Dictionary = record.duplicate(true)
	var exclusions: Array = updated.get("current_goal_excluded_tenant_ids", [])
	if not tenant_id.is_empty() and not exclusions.has(tenant_id):
		exclusions.append(tenant_id)
		exclusions.sort()
	updated["current_goal_excluded_tenant_ids"] = exclusions
	return updated


func _advance(record: Dictionary, policy: Dictionary, completed: bool) -> Dictionary:
	var validation: Dictionary = validate_record(record, policy)
	if not bool(validation.get("valid", false)):
		return {"valid": false, "record": record.duplicate(true), "diagnostics": validation.get("diagnostics", [])}
	var updated: Dictionary = record.duplicate(true)
	var index: int = int(updated["active_goal_index"])
	var goals: Array = updated["goals"]
	if index >= goals.size():
		return {"valid": true, "record": updated, "diagnostics": []}
	goals[index]["completed"] = completed
	goals[index]["dropped"] = not completed
	updated["goals"] = goals
	updated["active_goal_index"] = index + 1
	updated["current_goal_excluded_tenant_ids"] = []
	updated["next_state"] = String(policy["leaving_goal_id"]) if index + 1 >= goals.size() else "ACTIVE_GOAL"
	return {"valid": true, "record": updated, "diagnostics": []}


func _validate_generation_inputs(seed_domain_id: String, creation_ordinal: int, visitor_id: String, categories: Array[String], policy: Dictionary) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	if seed_domain_id.is_empty() or creation_ordinal < 0 or visitor_id.is_empty():
		diagnostics.append(_diagnostic("VISITOR_PROVENANCE_INVALID", "$", {}))
	if policy.get("goal_count_weights", []) != [40, 45, 15] or int(policy.get("wait_tolerance_min_ticks", 0)) != 2 or int(policy.get("wait_tolerance_max_ticks", 0)) != 8:
		diagnostics.append(_diagnostic("VISITOR_POLICY_INVALID", "$policy", {}))
	var canonical: Array[String] = categories.duplicate()
	canonical.sort()
	if canonical != categories or canonical.has("") or _has_duplicates(categories):
		diagnostics.append(_diagnostic("VISITOR_CATEGORY_SNAPSHOT_INVALID", "$.operational_categories", {}))
	return diagnostics


func _draw(seed_domain_id: String, behavior_seed: int, creation_ordinal: int, visitor_id: String, policy_revision: int, draw_index: int, modulus: int) -> int:
	var value: Dictionary = {
		"seed_domain_id": seed_domain_id,
		"behavior_seed": behavior_seed,
		"creation_ordinal": creation_ordinal,
		"visitor_id": visitor_id,
		"policy_revision": policy_revision,
		"draw_index": draw_index,
	}
	var hash: Dictionary = CanonicalJsonFingerprint.new().fingerprint(value, GENERATION_DOMAIN + ".DRAW", SCHEMA_VERSION)
	var text: String = String(hash.get("fingerprint", "00000000")).substr(0, 8)
	return text.hex_to_int() % maxi(modulus, 1)


func _goal(goal_id: String, ordinal: int, dropped: bool, completed: bool) -> Dictionary:
	return {"goal_id": goal_id, "ordinal": ordinal, "completed": completed, "dropped": dropped}


func _goal_ids(goals: Array) -> Array[String]:
	var ids: Array[String] = []
	for goal_value: Variant in goals:
		ids.append(String((goal_value as Dictionary).get("goal_id", "")))
	return ids


func _record_types_valid(record: Dictionary) -> bool:
	return record["schema_version"] is int and record["capability_id"] is String and record["capability_revision"] is int and record["visitor_policy_id"] is String and record["visitor_policy_revision"] is int and record["seed_domain_id"] is String and record["behavior_seed"] is int and record["creation_ordinal"] is int and record["visitor_id"] is String and record["captured_categories"] is Array and record["captured_category_marker"] is String and record["captured_category_fingerprint"] is String and record["generation_fingerprint"] is String and record["goals"] is Array and record["active_goal_index"] is int and record["wait_tolerance_ticks"] is int and record["current_goal_excluded_tenant_ids"] is Array and record["next_state"] is String


func _has_duplicates(values: Array) -> bool:
	var seen: Dictionary = {}
	for value: Variant in values:
		if seen.has(value):
			return true
		seen[value] = true
	return false


func _sorted_keys(value: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key: Variant in value.keys():
		keys.append(String(key))
	keys.sort()
	return keys


func _diagnostic(code: String, path: String, values: Dictionary) -> Dictionary:
	return {"code": code, "path": path, "values": values.duplicate(true)}
