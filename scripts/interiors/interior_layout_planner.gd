## Pure deterministic two-phase tenant-interior feasibility and layout planner.
class_name InteriorLayoutPlanner
extends RefCounted

const STATUS_VALID: String = "VALID"
const STATUS_INFEASIBLE: String = "INFEASIBLE"
const STATUS_INDETERMINATE: String = "SEARCH_INDETERMINATE"
const STATUS_CONTENT_INVALID: String = "CONTENT_INVALID"
const FINGERPRINT_DOMAIN: String = "JANUS_TENANT_INTERIOR_LAYOUT"


func plan_phase_a(request: Dictionary, compiled_snapshot: CompiledTenantInteriorContent) -> Dictionary:
	return _plan(request, compiled_snapshot, "A_PROSPECTIVE")


func plan_phase_a_stable(request: Dictionary, compiled_snapshot: CompiledTenantInteriorContent, expected_parity: Dictionary) -> Dictionary:
	var result: Dictionary = _plan(request, compiled_snapshot, "A_STABLE")
	if result.get("status", "") != STATUS_VALID:
		return result
	var actual_parity: Dictionary = request.get("phase_a_parity", {}).duplicate(true)
	actual_parity["feasible_pool_fingerprint"] = result.get("feasible_pool_fingerprint", "")
	var compared: Dictionary = PhaseAParityRecord.compare(expected_parity, actual_parity)
	if not bool(compared.get("valid", false)):
		return _result("A", STATUS_CONTENT_INVALID, result.get("feasible_profiles", []), result.get("rejected_profiles", []), compared.get("diagnostics", []))
	result["phase_a_parity"] = actual_parity
	return result


func plan_phase_b(request: Dictionary, compiled_snapshot: CompiledTenantInteriorContent) -> Dictionary:
	return _plan(request, compiled_snapshot, "B")


func _plan(request: Dictionary, compiled_snapshot: CompiledTenantInteriorContent, mode: String) -> Dictionary:
	var input_diagnostics: Array[Dictionary] = _validate_request(request, mode)
	if compiled_snapshot == null or not compiled_snapshot.validate_integrity():
		input_diagnostics.append(_diagnostic("CONTENT_INVALID", "$content", {}))
	if not input_diagnostics.is_empty():
		return _result("B" if mode == "B" else "A", STATUS_CONTENT_INVALID, [], [], input_diagnostics)
	var compiled_content: Dictionary = compiled_snapshot.get_content()
	var stable_phase: bool = mode == "B"
	var profiles: Array = compiled_content.get("operational_profiles", [])
	var requested_ids: Array = request.get("operational_profile_ids", [])
	var feasible: Array[Dictionary] = []
	var indeterminate: Array[Dictionary] = []
	var rejected: Array[Dictionary] = []
	for profile_value: Variant in profiles:
		var profile: Dictionary = profile_value
		if not requested_ids.is_empty() and not requested_ids.has(profile.get("operational_profile_id", "")):
			continue
		if String(profile.get("zone_type", "")) != String(request.get("zone_type", "")):
			continue
		var profile_result: Dictionary = _evaluate_profile_v2(request, profile, compiled_content, stable_phase)
		match String(profile_result.get("status", "")):
			STATUS_VALID:
				feasible.append(profile_result)
			STATUS_INDETERMINATE:
				indeterminate.append(profile_result)
			_:
				rejected.append(profile_result)
	feasible.sort_custom(_compare_profile_results)
	indeterminate.sort_custom(_compare_profile_results)
	rejected.sort_custom(_compare_profile_results)
	if not indeterminate.is_empty():
		return _result("B" if stable_phase else "A", STATUS_INDETERMINATE, feasible, rejected, [_diagnostic("SEARCH_INDETERMINATE", "$", {"profiles": _profile_ids(indeterminate)})])
	if feasible.is_empty():
		return _result("B" if stable_phase else "A", STATUS_INFEASIBLE, [], rejected, [_diagnostic("NO_FEASIBLE_OPERATIONAL_PROFILE", "$", {})])
	var result: Dictionary = _result("B" if stable_phase else "A", STATUS_VALID, feasible, rejected, [])
	var pool_values: Dictionary = {"content_fingerprint": compiled_snapshot.get_fingerprint(), "profiles": _pool_values(feasible)}
	var pool_hash: Dictionary = CanonicalJsonFingerprint.new().fingerprint(pool_values, "JANUS_TENANT_INTERIOR_FEASIBLE_POOL", 1)
	if not bool(pool_hash.get("valid", false)):
		return _result("B" if stable_phase else "A", STATUS_CONTENT_INVALID, [], rejected, pool_hash.get("diagnostics", []))
	result["feasible_pool_fingerprint"] = pool_hash["fingerprint"]
	if stable_phase:
		var selected_id: String = String(request.get("operational_profile_id", ""))
		var selected: Dictionary = {}
		for candidate: Dictionary in feasible:
			if String(candidate.get("operational_profile_id", "")) == selected_id:
				selected = candidate
				break
		if selected.is_empty():
			return _result("B", STATUS_INFEASIBLE, feasible, rejected, [_diagnostic("NO_FEASIBLE_OPERATIONAL_PROFILE", "$.operational_profile_id", {"id": selected_id})])
		result["selected_layout"] = selected.duplicate(true)
		var tenant_profile: Dictionary = _find_record(compiled_content.get("tenant_profiles", []), "profile_id", String(request.get("tenant_profile_id", "")))
		var service_policy: Dictionary = _find_record(compiled_content.get("service_policies", []), "service_policy_id", String(selected.get("service_policy_id", "")))
		if tenant_profile.is_empty() or service_policy.is_empty():
			return _result("B", STATUS_CONTENT_INVALID, feasible, rejected, [_diagnostic("REFERENCE_MISSING", "$", {})])
		if String(tenant_profile.get("operational_profile_id", "")) != selected_id:
			return _result("B", STATUS_CONTENT_INVALID, feasible, rejected, [_diagnostic("TENANT_OPERATIONAL_PROFILE_MISMATCH", "$.tenant_profile_id", {})])
		_assign_durable_fixture_ids(selected["placements"], String(request["parcel_id"]))
		result["selected_layout"] = selected.duplicate(true)
		result["final_proxy"] = {"proxy_id": request["proxy_id"], "door_id": selected["selected_door_id"], "queue_envelope_id": selected["selected_queue_envelope_id"], "capacity": selected["capacity"], "queue_capacity": selected["queue_capacity"]}
		var fingerprint_record: Dictionary = {
			"parcel_id": request["parcel_id"],
			"door_id": selected["selected_door_id"],
			"proxy_id": request["proxy_id"],
			"queue_envelope_id": selected["selected_queue_envelope_id"],
			"zone_revision": request["zone_revision"],
			"door_revision": request["door_revision"],
			"queue_envelope_revision": request["queue_revision"],
			"selected_core_key": selected["selected_core_key"],
			"selected_door_semantic_key": selected["selected_door_semantic_key"],
			"operational_profile_id": selected_id,
			"operational_profile_revision": selected["operational_profile_revision"],
			"tenant_profile_id": tenant_profile["profile_id"],
			"tenant_candidate_revision": tenant_profile["candidate_revision"],
			"variation_id": request["variation_id"],
			"content_bundle_id": compiled_content["bundle_id"],
			"content_bundle_revision": compiled_content["revision"],
			"content_fingerprint": compiled_snapshot.get_fingerprint(),
			"placements": selected["placements"],
			"circulation_cells": selected["circulation_cells"],
			"capacity": selected["capacity"],
			"queue_position_ids": selected["queue_position_ids"],
			"phase_a_parity": request.get("phase_a_parity", {}),
			"service_policy_id": selected["service_policy_id"],
			"service_policy_revision": service_policy["revision"],
			"visitor_policy_id": compiled_content["visitor_policy"]["visitor_policy_id"],
			"visitor_policy_revision": compiled_content["visitor_policy"]["revision"],
			"planning_policy_id": compiled_content["planning_policy"]["planning_policy_id"],
			"planning_policy_revision": compiled_content["planning_policy"]["revision"],
		}
		var encoded: Dictionary = CanonicalJsonFingerprint.new().fingerprint(fingerprint_record, FINGERPRINT_DOMAIN, 1)
		if not bool(encoded.get("valid", false)):
			return _result("B", STATUS_CONTENT_INVALID, [], rejected, encoded.get("diagnostics", []))
		result["final_fingerprint"] = encoded["fingerprint"]
	return result


func _evaluate_profile_v2(request: Dictionary, profile: Dictionary, content: Dictionary, stable_phase: bool) -> Dictionary:
	var best: Dictionary = {}
	var indeterminate: Dictionary = {}
	var last_failure: Dictionary = {}
	var core_options: Array = request.get("profile_core_options", [])
	for core_value: Variant in core_options:
		var core: Dictionary = core_value
		for door_value: Variant in request.get("operational_door_options", []):
			var door: Dictionary = door_value
			var edge: Dictionary = door.get("edge", {})
			var frontage_cells: Array[Array] = []
			for frontage_edge: Dictionary in request.get("frontage_edges", []):
				var cell: Dictionary = frontage_edge.get("parcel_cell", {})
				var array_cell: Array[int] = [int(cell.get("x", 0)), int(cell.get("y", 0))]
				if not frontage_cells.has(array_cell): frontage_cells.append(array_cell)
			var legacy := {
				"usable_cells": request.get("usable_cells", []), "core_cells": core.get("cells", []),
				"annex_cells": _set_difference(request.get("usable_cells", []), core.get("cells", [])),
				"frontage_cells": frontage_cells, "wall_cells": request.get("wall_cells", []),
				"selected_door_cell": door.get("entrance_cell", []), "queue_cells": door.get("queue_positions", []), "frontage_length": frontage_cells.size(),
			}
			var evaluated := _evaluate_profile_legacy(legacy, profile, content, stable_phase)
			if evaluated.get("status") == STATUS_INDETERMINATE: indeterminate = evaluated; continue
			if evaluated.get("status") != STATUS_VALID:
				last_failure = evaluated
				continue
			evaluated["queue_capacity"] = mini(int(profile.get("queue_cap", 0)), (door.get("queue_positions", []) as Array).size())
			if bool(profile.get("queue_required", false)) and int(evaluated["queue_capacity"]) <= 0: continue
			evaluated["selected_core_key"] = core.get("core_key", "")
			evaluated["selected_door_semantic_key"] = door.get("door_semantic_key", "")
			evaluated["selected_door_id"] = door.get("door_id")
			evaluated["selected_queue_envelope_key"] = door.get("queue_envelope_key", "")
			evaluated["selected_queue_envelope_id"] = door.get("queue_envelope_id")
			evaluated["queue_position_ids"] = []
			for position: Dictionary in door.get("queue_positions", []): evaluated["queue_position_ids"].append(position.get("position_id", ""))
			if best.is_empty() or int(evaluated["queue_capacity"]) > int(best["queue_capacity"]) or (evaluated["queue_capacity"] == best["queue_capacity"] and (String(evaluated["selected_core_key"]) < String(best["selected_core_key"]) or (evaluated["selected_core_key"] == best["selected_core_key"] and String(evaluated["selected_door_semantic_key"]) < String(best["selected_door_semantic_key"])))): best = evaluated
	if not best.is_empty(): return best
	if not indeterminate.is_empty(): return indeterminate
	if not last_failure.is_empty(): return last_failure
	return _profile_failure(profile, "CORE_DOOR_PAIR_UNMET", {})


func _evaluate_profile_legacy(request: Dictionary, profile: Dictionary, content: Dictionary, stable_phase: bool) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	var usable: Array = _ordered_cells(request.get("usable_cells", []))
	var usable_set: Dictionary = _cell_set(usable)
	var area: int = usable.size()
	if area < int(profile.get("minimum_area", 0)):
		return _profile_failure(profile, "AREA_UNMET", {"actual": area, "required": profile.get("minimum_area", 0)})
	if not _core_fits(request.get("core_cells", []), int(profile.get("core_width", 0)), int(profile.get("core_depth", 0)), profile.get("core_rotations", [])):
		return _profile_failure(profile, "CORE_UNMET", {})
	if int(request.get("frontage_length", 0)) < int(profile.get("minimum_frontage", 0)):
		return _profile_failure(profile, "FRONTAGE_UNMET", {})
	if (request.get("selected_door_cell", []) as Array).size() != 2:
		return _profile_failure(profile, "DOOR_UNMET", {})
	if bool(profile.get("queue_required", false)) and (request.get("queue_cells", []) as Array).is_empty():
		return _profile_failure(profile, "QUEUE_UNMET", {})
	var fixture_by_id: Dictionary = {}
	for fixture_value: Variant in content.get("fixtures", []):
		var fixture: Dictionary = fixture_value
		fixture_by_id[String(fixture["fixture_id"])] = fixture
	var budget: int = int(content.get("planning_policy", {}).get("placement_validation_budget", 10000))
	var state: Dictionary = {"validations": 0, "occupied": {}, "clearance": {}, "placements": []}
	var program: Array = profile.get("fixture_program", [])
	var mandatory_fixtures: Array[Dictionary] = []
	for entry_value: Variant in program:
		var entry: Dictionary = entry_value
		if String(entry.get("kind", "MANDATORY")) == "REPEATABLE":
			continue
		var fixture: Dictionary = fixture_by_id.get(String(entry.get("fixture_id", "")), {})
		for occurrence: int in range(int(entry.get("count", 0))):
			mandatory_fixtures.append(fixture)
	var mandatory_search: Dictionary = _search_mandatory(mandatory_fixtures, 0, usable, usable_set, request, bool(profile.get("requires_circulation_loop", false)), state, budget)
	if bool(mandatory_search.get("exhausted", false)):
		return _profile_indeterminate(profile, state)
	if not bool(mandatory_search.get("placed", false)):
		return _profile_failure(profile, "MANDATORY_FIXTURE_FAILURE", {})
	var added_modules: int = 0
	var has_repeatables: bool = false
	var ceiling_percent: int = int(content.get("planning_policy", {}).get("occupied_area_ceiling_percent", 75))
	var comfort_modules: int = int(content.get("planning_policy", {}).get("comfort_extra_modules", 2))
	var repeatable_fixtures: Array[Dictionary] = []
	for entry_value: Variant in program:
		var entry: Dictionary = entry_value
		if String(entry.get("kind", "")) == "REPEATABLE":
			has_repeatables = true
			repeatable_fixtures.append(fixture_by_id.get(String(entry.get("fixture_id", "")), {}))
	if has_repeatables:
		var repeatable_search: Dictionary = _search_repeatable_modules(repeatable_fixtures, comfort_modules, usable, usable_set, request, bool(profile.get("requires_circulation_loop", false)), state, budget, area, ceiling_percent)
		if bool(repeatable_search.get("exhausted", false)):
			return _profile_indeterminate(profile, state)
		added_modules = int(repeatable_search.get("count", 0))
	var circulation: Array[Array] = _reachable_free_cells(request.get("selected_door_cell", []), usable_set, state["occupied"])
	if not _layout_constraints_valid(request, usable_set, state, bool(profile.get("requires_circulation_loop", false))):
		return _profile_failure(profile, "CIRCULATION_FAILURE", {"placements": state["placements"], "circulation_cells": circulation, "loop_required": profile.get("requires_circulation_loop", false)})
	if not _tags_compatible(state["placements"]):
		return _profile_failure(profile, "FIXTURE_TAG_CONFLICT", {})
	var capacity: int = 0
	for placement_value: Variant in state["placements"]:
		capacity += int((placement_value as Dictionary).get("capacity", 0))
	if capacity <= 0:
		return _profile_failure(profile, "MANDATORY_FIXTURE_FAILURE", {"capacity": capacity})
	var annex_count: int = (request.get("annex_cells", []) as Array).size()
	var within_target: bool = area >= int(profile.get("target_area_min", 0)) and area <= int(profile.get("target_area_max", 0))
	var rating: String = "ACCEPTABLE"
	if within_target and annex_count * 4 <= area and (not has_repeatables or added_modules >= comfort_modules):
		rating = "EXCELLENT"
	elif within_target and (not has_repeatables or added_modules >= 1):
		rating = "GOOD"
	var planning: Dictionary = content.get("planning_policy", {})
	var tickets: int = int(planning.get("excellent_tickets", 6)) if rating == "EXCELLENT" else (int(planning.get("good_tickets", 3)) if rating == "GOOD" else int(planning.get("acceptable_tickets", 1)))
	var placements: Array = state["placements"] if stable_phase else []
	return {
		"status": STATUS_VALID,
		"operational_profile_id": profile["operational_profile_id"],
		"operational_profile_revision": profile["revision"],
		"service_policy_id": profile["service_policy_id"],
		"rating": rating,
		"tickets": tickets,
		"capacity": capacity,
		"queue_capacity": mini(int(profile.get("queue_cap", 0)), (request.get("queue_cells", []) as Array).size() * 2),
		"comfort_utilization_percent": int(((state["occupied"] as Dictionary).size() * 100) / maxi(area, 1)),
		"placements": placements,
		"circulation_cells": circulation if stable_phase else [],
		"validations_used": state["validations"],
		"diagnostics": diagnostics,
	}


func _search_mandatory(fixtures: Array[Dictionary], fixture_index: int, usable: Array, usable_set: Dictionary, request: Dictionary, requires_loop: bool, state: Dictionary, budget: int) -> Dictionary:
	if fixture_index >= fixtures.size():
		return {"placed": _layout_constraints_valid(request, usable_set, state, requires_loop), "exhausted": false}
	var fixture: Dictionary = fixtures[fixture_index]
	for rotation_value: Variant in fixture.get("allowed_rotations", []):
		var rotation: int = int(rotation_value)
		var occupied_raw: Array[Array] = _transformed_cells(fixture.get("occupied_cells", []), rotation)
		var clearance_raw: Array[Array] = _transformed_cells(fixture.get("clearance_cells", []), rotation)
		var shape_origin: Array = _minimum_cell(occupied_raw)
		var occupied_shape: Array[Array] = _normalize_cells(occupied_raw, shape_origin)
		var clearance_shape: Array[Array] = _normalize_cells(clearance_raw, shape_origin)
		for origin_value: Variant in usable:
			state["validations"] = int(state["validations"]) + 1
			if int(state["validations"]) > budget:
				return {"placed": false, "exhausted": true}
			var origin: Array = origin_value
			var occupied_cells: Array[Array] = _offset_cells(occupied_shape, origin)
			var clearance_cells: Array[Array] = _offset_cells(clearance_shape, origin)
			if not _cells_available(occupied_cells, clearance_cells, usable_set, state["occupied"], state["clearance"]):
				continue
			if not _interaction_face_satisfied(fixture, rotation, occupied_cells, clearance_cells, request, usable_set):
				continue
			if not _placement_rule_satisfied(fixture, occupied_cells, request):
				continue
			var occupied_before: Dictionary = (state["occupied"] as Dictionary).duplicate()
			var clearance_before: Dictionary = (state["clearance"] as Dictionary).duplicate()
			var placement_count: int = (state["placements"] as Array).size()
			_record_placement(fixture, origin, rotation, occupied_cells, clearance_cells, state)
			var successor: Dictionary = _search_mandatory(fixtures, fixture_index + 1, usable, usable_set, request, requires_loop, state, budget)
			if bool(successor.get("placed", false)) or bool(successor.get("exhausted", false)):
				return successor
			state["occupied"] = occupied_before
			state["clearance"] = clearance_before
			while (state["placements"] as Array).size() > placement_count:
				(state["placements"] as Array).pop_back()
	return {"placed": false, "exhausted": false}


func _layout_constraints_valid(request: Dictionary, usable_set: Dictionary, state: Dictionary, requires_loop: bool) -> bool:
	var circulation: Array[Array] = _reachable_free_cells(request.get("selected_door_cell", []), usable_set, state["occupied"])
	var needs_internal_circulation: bool = _requires_internal_circulation(state["placements"])
	var access_valid: bool = not needs_internal_circulation or (not circulation.is_empty() and _all_clearance_reachable(state["placements"], circulation))
	return access_valid and (not requires_loop or _has_four_cell_loop(circulation)) and _tags_compatible(state["placements"])


func _requires_internal_circulation(placements: Array) -> bool:
	for placement_value: Variant in placements:
		var placement: Dictionary = placement_value
		if String(placement.get("interaction_face", "NONE")) != "NONE" and not (placement.get("clearance_cells", []) as Array).is_empty():
			return true
	return false


func _search_repeatable_modules(fixtures: Array[Dictionary], remaining: int, usable: Array, usable_set: Dictionary, request: Dictionary, requires_loop: bool, state: Dictionary, budget: int, area: int, ceiling_percent: int) -> Dictionary:
	if remaining <= 0:
		return {"count": 0, "exhausted": false}
	var best_count: int = 0
	var best_occupied: Dictionary = (state["occupied"] as Dictionary).duplicate()
	var best_clearance: Dictionary = (state["clearance"] as Dictionary).duplicate()
	var best_placements: Array = (state["placements"] as Array).duplicate(true)
	for fixture: Dictionary in fixtures:
		for rotation_value: Variant in fixture.get("allowed_rotations", []):
			var rotation: int = int(rotation_value)
			var occupied_raw: Array[Array] = _transformed_cells(fixture.get("occupied_cells", []), rotation)
			var clearance_raw: Array[Array] = _transformed_cells(fixture.get("clearance_cells", []), rotation)
			var shape_origin: Array = _minimum_cell(occupied_raw)
			var occupied_shape: Array[Array] = _normalize_cells(occupied_raw, shape_origin)
			var clearance_shape: Array[Array] = _normalize_cells(clearance_raw, shape_origin)
			for origin_value: Variant in usable:
				if ((state["occupied"] as Dictionary).size() + occupied_shape.size()) * 100 > area * ceiling_percent:
					continue
				state["validations"] = int(state["validations"]) + 1
				if int(state["validations"]) > budget:
					return {"count": 0, "exhausted": true}
				var origin: Array = origin_value
				var occupied_cells: Array[Array] = _offset_cells(occupied_shape, origin)
				var clearance_cells: Array[Array] = _offset_cells(clearance_shape, origin)
				if not _cells_available(occupied_cells, clearance_cells, usable_set, state["occupied"], state["clearance"]):
					continue
				if not _interaction_face_satisfied(fixture, rotation, occupied_cells, clearance_cells, request, usable_set):
					continue
				if not _placement_rule_satisfied(fixture, occupied_cells, request):
					continue
				var occupied_before: Dictionary = (state["occupied"] as Dictionary).duplicate()
				var clearance_before: Dictionary = (state["clearance"] as Dictionary).duplicate()
				var placements_before: Array = (state["placements"] as Array).duplicate(true)
				_record_placement(fixture, origin, rotation, occupied_cells, clearance_cells, state)
				if _layout_constraints_valid(request, usable_set, state, requires_loop):
					var successor: Dictionary = _search_repeatable_modules(fixtures, remaining - 1, usable, usable_set, request, requires_loop, state, budget, area, ceiling_percent)
					if bool(successor.get("exhausted", false)):
						return successor
					var candidate_count: int = 1 + int(successor.get("count", 0))
					if candidate_count > best_count:
						best_count = candidate_count
						best_occupied = (state["occupied"] as Dictionary).duplicate()
						best_clearance = (state["clearance"] as Dictionary).duplicate()
						best_placements = (state["placements"] as Array).duplicate(true)
				state["occupied"] = occupied_before
				state["clearance"] = clearance_before
				state["placements"] = placements_before
				if best_count == remaining:
					state["occupied"] = best_occupied
					state["clearance"] = best_clearance
					state["placements"] = best_placements
					return {"count": best_count, "exhausted": false}
	state["occupied"] = best_occupied
	state["clearance"] = best_clearance
	state["placements"] = best_placements
	return {"count": best_count, "exhausted": false}


func _place_repeatable_fixture(fixture: Dictionary, usable: Array, usable_set: Dictionary, request: Dictionary, requires_loop: bool, state: Dictionary, budget: int) -> Dictionary:
	for rotation_value: Variant in fixture.get("allowed_rotations", []):
		var rotation: int = int(rotation_value)
		var occupied_raw: Array[Array] = _transformed_cells(fixture.get("occupied_cells", []), rotation)
		var clearance_raw: Array[Array] = _transformed_cells(fixture.get("clearance_cells", []), rotation)
		var shape_origin: Array = _minimum_cell(occupied_raw)
		var occupied_shape: Array[Array] = _normalize_cells(occupied_raw, shape_origin)
		var clearance_shape: Array[Array] = _normalize_cells(clearance_raw, shape_origin)
		for origin_value: Variant in usable:
			state["validations"] = int(state["validations"]) + 1
			if int(state["validations"]) > budget:
				return {"placed": false, "exhausted": true}
			var origin: Array = origin_value
			var occupied_cells: Array[Array] = _offset_cells(occupied_shape, origin)
			var clearance_cells: Array[Array] = _offset_cells(clearance_shape, origin)
			if not _cells_available(occupied_cells, clearance_cells, usable_set, state["occupied"], state["clearance"]):
				continue
			if not _interaction_face_satisfied(fixture, rotation, occupied_cells, clearance_cells):
				continue
			if not _placement_rule_satisfied(fixture, occupied_cells, request):
				continue
			var occupied_before: Dictionary = (state["occupied"] as Dictionary).duplicate()
			var clearance_before: Dictionary = (state["clearance"] as Dictionary).duplicate()
			var placement_count: int = (state["placements"] as Array).size()
			_record_placement(fixture, origin, rotation, occupied_cells, clearance_cells, state)
			if _layout_constraints_valid(request, usable_set, state, requires_loop):
				return {"placed": true, "exhausted": false}
			state["occupied"] = occupied_before
			state["clearance"] = clearance_before
			while (state["placements"] as Array).size() > placement_count:
				(state["placements"] as Array).pop_back()
	return {"placed": false, "exhausted": false}


func _place_fixture(fixture: Dictionary, usable: Array, usable_set: Dictionary, request: Dictionary, state: Dictionary, budget: int) -> Dictionary:
	var rotations: Array = fixture.get("allowed_rotations", [])
	for rotation_value: Variant in rotations:
		var rotation: int = int(rotation_value)
		var occupied_raw: Array[Array] = _transformed_cells(fixture.get("occupied_cells", []), rotation)
		var clearance_raw: Array[Array] = _transformed_cells(fixture.get("clearance_cells", []), rotation)
		var shape_origin: Array = _minimum_cell(occupied_raw)
		var occupied_shape: Array[Array] = _normalize_cells(occupied_raw, shape_origin)
		var clearance_shape: Array[Array] = _normalize_cells(clearance_raw, shape_origin)
		for origin_value: Variant in usable:
			state["validations"] = int(state["validations"]) + 1
			if int(state["validations"]) > budget:
				return {"placed": false, "exhausted": true}
			var origin: Array = origin_value
			var occupied_cells: Array[Array] = _offset_cells(occupied_shape, origin)
			var clearance_cells: Array[Array] = _offset_cells(clearance_shape, origin)
			if not _cells_available(occupied_cells, clearance_cells, usable_set, state["occupied"], state["clearance"]):
				continue
			if not _interaction_face_satisfied(fixture, rotation, occupied_cells, clearance_cells):
				continue
			if not _placement_rule_satisfied(fixture, occupied_cells, request):
				continue
			_record_placement(fixture, origin, rotation, occupied_cells, clearance_cells, state)
			return {"placed": true, "exhausted": false}
	return {"placed": false, "exhausted": false}


func _record_placement(fixture: Dictionary, origin: Array, rotation: int, occupied_cells: Array[Array], clearance_cells: Array[Array], state: Dictionary) -> void:
	for cell: Array in occupied_cells:
		(state["occupied"] as Dictionary)[_cell_key(cell)] = true
	for cell: Array in clearance_cells:
		(state["clearance"] as Dictionary)[_cell_key(cell)] = true
	(state["placements"] as Array).append({
		"fixture_id": fixture["fixture_id"],
		"fixture_revision": fixture["revision"],
		"instance_ordinal": (state["placements"] as Array).size(),
		"origin": origin.duplicate(),
		"rotation": rotation,
		"occupied_cells": occupied_cells,
		"clearance_cells": clearance_cells,
		"interaction_face": fixture.get("interaction_face", "NONE"),
		"capacity": fixture.get("capacity", 0),
		"tags": fixture.get("tags", []).duplicate(),
		"incompatible_neighbor_tags": fixture.get("incompatible_neighbor_tags", []).duplicate(),
	})


func _interaction_face_satisfied(fixture: Dictionary, rotation: int, occupied_cells: Array[Array], clearance_cells: Array[Array], request: Dictionary = {}, usable_set: Dictionary = {}) -> bool:
	var face: String = String(fixture.get("interaction_face", "NONE"))
	if face == "NONE":
		return true
	var direction: Vector2i = {"NORTH": Vector2i(0, -1), "EAST": Vector2i(1, 0), "SOUTH": Vector2i(0, 1), "WEST": Vector2i(-1, 0)}.get(face, Vector2i.ZERO)
	for _turn: int in range((rotation / 90) % 4):
		direction = Vector2i(-direction.y, direction.x)
	var clearance_set: Dictionary = _cell_set(clearance_cells)
	var frontage_set: Dictionary = _cell_set(request.get("frontage_cells", []))
	for cell: Array in occupied_cells:
		var interaction_cell: Array[int] = [int(cell[0]) + direction.x, int(cell[1]) + direction.y]
		if clearance_set.has(_cell_key(interaction_cell)):
			return true
		if String(fixture.get("placement_rule", "")) == "FRONTAGE" and frontage_set.has(_cell_key(cell)) and not usable_set.has(_cell_key(interaction_cell)):
			return true
	return false


func _placement_rule_satisfied(fixture: Dictionary, occupied_cells: Array[Array], request: Dictionary) -> bool:
	var rule: String = String(fixture.get("placement_rule", "FREESTANDING"))
	if rule == "FREESTANDING":
		return true
	var target_cells: Dictionary = _cell_set(request.get("frontage_cells", [])) if rule == "FRONTAGE" else _cell_set(request.get("wall_cells", []))
	for cell: Array in occupied_cells:
		if target_cells.has(_cell_key(cell)):
			return true
	return false


func _cells_available(occupied: Array, clearance: Array, usable: Dictionary, taken: Dictionary, reserved_clearance: Dictionary) -> bool:
	for cell_value: Variant in occupied:
		var key: String = _cell_key(cell_value)
		if not usable.has(key) or taken.has(key) or reserved_clearance.has(key):
			return false
	for cell_value: Variant in clearance:
		var key: String = _cell_key(cell_value)
		if not usable.has(key) or taken.has(key):
			return false
	return true


func _core_fits(core_value: Variant, width: int, depth: int, rotations: Array) -> bool:
	var core: Array = core_value if core_value is Array else []
	var core_set: Dictionary = _cell_set(core)
	for rotation_value: Variant in rotations:
		var required_width: int = depth if int(rotation_value) in [90, 270] else width
		var required_depth: int = width if int(rotation_value) in [90, 270] else depth
		for origin_value: Variant in _ordered_cells(core):
			var origin: Array = origin_value
			var fits: bool = true
			for y: int in range(required_depth):
				for x: int in range(required_width):
					if not core_set.has(_cell_key([int(origin[0]) + x, int(origin[1]) + y])):
						fits = false
						break
				if not fits:
					break
			if fits:
				return true
	return false


func _reachable_free_cells(door_value: Variant, usable: Dictionary, occupied: Dictionary) -> Array[Array]:
	var door: Array = door_value if door_value is Array else []
	if door.size() != 2 or not usable.has(_cell_key(door)) or occupied.has(_cell_key(door)):
		return []
	var pending: Array[Array] = [door.duplicate()]
	var reached: Dictionary = {_cell_key(door): true}
	var output: Array[Array] = []
	while not pending.is_empty():
		var cell: Array = pending.pop_front()
		output.append(cell)
		for offset: Array in [[0, -1], [-1, 0], [1, 0], [0, 1]]:
			var neighbor: Array = [int(cell[0]) + int(offset[0]), int(cell[1]) + int(offset[1])]
			var key: String = _cell_key(neighbor)
			if usable.has(key) and not occupied.has(key) and not reached.has(key):
				reached[key] = true
				pending.append(neighbor)
	return _ordered_cells(output)


func _all_clearance_reachable(placements: Array, circulation: Array) -> bool:
	var reached: Dictionary = _cell_set(circulation)
	for placement_value: Variant in placements:
		for cell_value: Variant in (placement_value as Dictionary).get("clearance_cells", []):
			if not reached.has(_cell_key(cell_value)):
				return false
	return true


func _tags_compatible(placements: Array) -> bool:
	var tags_by_cell: Dictionary = {}
	for placement_value: Variant in placements:
		var placement: Dictionary = placement_value
		for cell_value: Variant in placement.get("occupied_cells", []):
			tags_by_cell[_cell_key(cell_value)] = placement.get("tags", [])
	for placement_value: Variant in placements:
		var placement: Dictionary = placement_value
		var incompatible: Array = placement.get("incompatible_neighbor_tags", [])
		if incompatible.is_empty():
			continue
		for cell_value: Variant in placement.get("occupied_cells", []):
			var cell: Array = cell_value
			for offset: Array in [[0, -1], [-1, 0], [1, 0], [0, 1]]:
				var neighbor_tags: Array = tags_by_cell.get(_cell_key([int(cell[0]) + int(offset[0]), int(cell[1]) + int(offset[1])]), [])
				for tag: Variant in incompatible:
					if neighbor_tags.has(tag):
						return false
	return true


func _has_four_cell_loop(circulation: Array) -> bool:
	var cells: Dictionary = _cell_set(circulation)
	for cell_value: Variant in circulation:
		var cell: Array = cell_value
		if cells.has(_cell_key([int(cell[0]) + 1, int(cell[1])])) and cells.has(_cell_key([int(cell[0]), int(cell[1]) + 1])) and cells.has(_cell_key([int(cell[0]) + 1, int(cell[1]) + 1])):
			return true
	return false


func _transformed_cells(cells: Array, rotation: int) -> Array[Array]:
	var transformed: Array[Array] = []
	for cell_value: Variant in cells:
		var cell: Array = cell_value
		var x: int = int(cell[0])
		var y: int = int(cell[1])
		match rotation:
			90:
				transformed.append([-y, x])
			180:
				transformed.append([-x, -y])
			270:
				transformed.append([y, -x])
			_:
				transformed.append([x, y])
	return transformed


func _minimum_cell(cells: Array[Array]) -> Array:
	if cells.is_empty():
		return [0, 0]
	var minimum_x: int = int(cells[0][0])
	var minimum_y: int = int(cells[0][1])
	for cell: Array in cells:
		minimum_x = mini(minimum_x, int(cell[0]))
		minimum_y = mini(minimum_y, int(cell[1]))
	return [minimum_x, minimum_y]


func _normalize_cells(cells: Array[Array], shape_origin: Array) -> Array[Array]:
	var normalized: Array[Array] = []
	for cell: Array in cells:
		normalized.append([int(cell[0]) - int(shape_origin[0]), int(cell[1]) - int(shape_origin[1])])
	return _ordered_cells(normalized)


func _offset_cells(cells: Array, origin: Array) -> Array[Array]:
	var output: Array[Array] = []
	for cell_value: Variant in cells:
		var cell: Array = cell_value
		output.append([int(origin[0]) + int(cell[0]), int(origin[1]) + int(cell[1])])
	return _ordered_cells(output)


func _pool_values(feasible: Array) -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	for profile_value: Variant in feasible:
		var profile: Dictionary = profile_value
		values.append({"operational_profile_id": profile.get("operational_profile_id", ""), "operational_profile_revision": profile.get("operational_profile_revision", 0), "rating": profile.get("rating", ""), "tickets": profile.get("tickets", 0), "capacity": profile.get("capacity", 0), "queue_capacity": profile.get("queue_capacity", 0)})
	return values


func _set_difference(all_cells: Array, excluded_cells: Array) -> Array[Array]:
	var excluded := _cell_set(excluded_cells)
	var result: Array[Array] = []
	for cell: Array in _ordered_cells(all_cells):
		if not excluded.has(_cell_key(cell)): result.append(cell)
	return result


func _find_record(records: Array, id_field: String, id: String) -> Dictionary:
	for record_value: Variant in records:
		var record: Dictionary = record_value
		if String(record.get(id_field, "")) == id:
			return record.duplicate(true)
	return {}


func _assign_durable_fixture_ids(placements: Array, parcel_id: String) -> void:
	for index: int in range(placements.size()):
		(placements[index] as Dictionary)["fixture_instance_id"] = "interior_fixture/%s/%04d" % [parcel_id.uri_encode(), index]


func _validate_request(request: Dictionary, mode: String) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	if request.get("schema_id") != "interior_phase_a_request" or request.get("schema_version") != 2:
		return [_diagnostic("REQUEST_SCHEMA_UNSUPPORTED", "$", {})]
	var required: Array[String] = ["identity_mode", "plan_local_parcel_key", "parcel_id", "zone_type", "usable_cells", "formation_core", "profile_core_options", "frontage_edges", "wall_cells", "operational_door_options", "operational_profile_ids", "zone_revision", "door_revision", "queue_revision"]
	for field: String in required:
		if not request.has(field): diagnostics.append(_diagnostic("REQUEST_FIELD_MISSING", "$.%s" % field, {}))
	if not diagnostics.is_empty(): return diagnostics
	var stable: bool = mode != "A_PROSPECTIVE"
	if request["identity_mode"] != ("STABLE" if stable else "PLAN_LOCAL"):
		diagnostics.append(_diagnostic("REQUEST_IDENTITY_MODE_INVALID", "$.identity_mode", {}))
	if String(request.get("plan_local_parcel_key", "")).is_empty() or String(request.get("zone_type", "")).is_empty() or not request.get("usable_cells") is Array or not request.get("profile_core_options") is Array or (request["profile_core_options"] as Array).is_empty() or not request.get("operational_door_options") is Array or (request["operational_door_options"] as Array).is_empty():
		diagnostics.append(_diagnostic("REQUEST_VALUE_INVALID", "$", {}))
	if stable:
		if String(request.get("parcel_id", "")).is_empty(): diagnostics.append(_diagnostic("STABLE_IDENTITY_REQUIRED", "$.parcel_id", {}))
		for field: String in ["zone_revision", "door_revision", "queue_revision"]:
			if not request.get(field) is int or int(request[field]) < 0: diagnostics.append(_diagnostic("SOURCE_REVISION_REQUIRED", "$.%s" % field, {}))
		for door: Dictionary in request.get("operational_door_options", []):
			if String(door.get("door_id", "")).is_empty() or String(door.get("queue_envelope_id", "")).is_empty(): diagnostics.append(_diagnostic("STABLE_IDENTITY_REQUIRED", "$.operational_door_options", {}))
	else:
		if request.get("parcel_id") != null or request.get("zone_revision") != null or request.get("door_revision") != null or request.get("queue_revision") != null:
			diagnostics.append(_diagnostic("PHASE_A_PERSISTENT_IDENTITY_FORBIDDEN", "$", {}))
		for door: Dictionary in request.get("operational_door_options", []):
			if door.get("door_id") != null or door.get("queue_envelope_id") != null: diagnostics.append(_diagnostic("PHASE_A_PERSISTENT_IDENTITY_FORBIDDEN", "$.operational_door_options", {}))
	if mode == "A_STABLE" and not request.get("phase_a_parity") is Dictionary:
		diagnostics.append(_diagnostic("REQUEST_FIELD_MISSING", "$.phase_a_parity", {}))
	if mode == "B":
		for field: String in ["proxy_id", "operational_profile_id", "tenant_profile_id", "variation_id"]:
			if String(request.get(field, "")).is_empty(): diagnostics.append(_diagnostic("STABLE_IDENTITY_REQUIRED", "$.%s" % field, {}))
	return diagnostics


func _validate_request_legacy(request: Dictionary, mode: String) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	for field: String in ["zone_type", "usable_cells", "core_cells", "annex_cells", "frontage_cells", "wall_cells", "selected_door_cell", "queue_cells", "frontage_length"]:
		if not request.has(field):
			diagnostics.append(_diagnostic("REQUEST_FIELD_MISSING", "$.%s" % field, {}))
	if diagnostics.is_empty():
		diagnostics.append_array(_validate_geometry_request(request))
	if mode == "B":
		for field: String in ["parcel_id", "door_id", "proxy_id", "queue_envelope_id", "operational_profile_id", "tenant_profile_id", "variation_id"]:
			if not request.has(field) or String(request.get(field, "")).is_empty():
				diagnostics.append(_diagnostic("STABLE_IDENTITY_REQUIRED", "$.%s" % field, {}))
		for field: String in ["zone_revision", "door_revision", "queue_envelope_revision"]:
			if int(request.get(field, -1)) < 0:
				diagnostics.append(_diagnostic("SOURCE_REVISION_REQUIRED", "$.%s" % field, {}))
	elif mode == "A_STABLE":
		for field: String in ["parcel_id", "door_id", "proxy_id", "queue_envelope_id"]:
			if not request.has(field) or String(request.get(field, "")).is_empty():
				diagnostics.append(_diagnostic("STABLE_IDENTITY_REQUIRED", "$.%s" % field, {}))
		for field: String in ["zone_revision", "door_revision", "queue_envelope_revision"]:
			if int(request.get(field, -1)) < 0:
				diagnostics.append(_diagnostic("SOURCE_REVISION_REQUIRED", "$.%s" % field, {}))
		for forbidden: String in ["fixture_ids", "final_fingerprint", "variation_id", "tenant_profile_id"]:
			if request.has(forbidden):
				diagnostics.append(_diagnostic("PHASE_A_PERSISTENT_IDENTITY_FORBIDDEN", "$.%s" % forbidden, {}))
	else:
		if not request.has("plan_local_parcel_key") or String(request.get("plan_local_parcel_key", "")).is_empty():
			diagnostics.append(_diagnostic("REQUEST_FIELD_MISSING", "$.plan_local_parcel_key", {}))
		for forbidden: String in ["parcel_id", "door_id", "proxy_id", "queue_envelope_id", "fixture_ids", "final_fingerprint", "variation_id", "tenant_profile_id"]:
			if request.has(forbidden):
				diagnostics.append(_diagnostic("PHASE_A_PERSISTENT_IDENTITY_FORBIDDEN", "$.%s" % forbidden, {}))
	return diagnostics


func _validate_geometry_request(request: Dictionary) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	var usable: Array = _ordered_cells(request.get("usable_cells", []))
	var core: Array = _ordered_cells(request.get("core_cells", []))
	var annex: Array = _ordered_cells(request.get("annex_cells", []))
	var frontage: Array = _ordered_cells(request.get("frontage_cells", []))
	var walls: Array = _ordered_cells(request.get("wall_cells", []))
	var queue: Array = _ordered_cells(request.get("queue_cells", []))
	for pair: Array in [["usable_cells", usable, request.get("usable_cells", [])], ["core_cells", core, request.get("core_cells", [])], ["annex_cells", annex, request.get("annex_cells", [])], ["frontage_cells", frontage, request.get("frontage_cells", [])], ["wall_cells", walls, request.get("wall_cells", [])], ["queue_cells", queue, request.get("queue_cells", [])]]:
		if (pair[1] as Array).size() != (pair[2] as Array).size() or _cell_set(pair[1]).size() != (pair[1] as Array).size():
			diagnostics.append(_diagnostic("GEOMETRY_CELLS_INVALID", "$.%s" % pair[0], {}))
	var usable_set: Dictionary = _cell_set(usable)
	for cell: Array in core + annex + frontage + walls:
		if not usable_set.has(_cell_key(cell)):
			diagnostics.append(_diagnostic("GEOMETRY_CELLS_INVALID", "$", {"cell": cell}))
	for cell: Array in queue:
		if usable_set.has(_cell_key(cell)):
			diagnostics.append(_diagnostic("QUEUE_UNMET", "$.queue_cells", {"cell": cell}))
	var door: Array = request.get("selected_door_cell", [])
	var frontage_set: Dictionary = _cell_set(frontage)
	if door.size() != 2 or not frontage_set.has(_cell_key(door)):
		diagnostics.append(_diagnostic("DOOR_UNMET", "$.selected_door_cell", {}))
	if not queue.is_empty() and not _queue_connected_to_frontage(queue, frontage_set):
		diagnostics.append(_diagnostic("QUEUE_UNMET", "$.queue_cells", {"reason": "not_connected_to_frontage"}))
	if int(request.get("frontage_length", -1)) != frontage.size():
		diagnostics.append(_diagnostic("FRONTAGE_UNMET", "$.frontage_length", {}))
	return diagnostics


func _queue_connected_to_frontage(queue: Array, frontage_set: Dictionary) -> bool:
	var queue_set: Dictionary = _cell_set(queue)
	var pending: Array[Array] = []
	var reached: Dictionary = {}
	for cell: Array in queue:
		for offset: Array in [[0, -1], [-1, 0], [1, 0], [0, 1]]:
			if frontage_set.has(_cell_key([int(cell[0]) + int(offset[0]), int(cell[1]) + int(offset[1])])):
				pending.append(cell)
				reached[_cell_key(cell)] = true
				break
	while not pending.is_empty():
		var cell: Array = pending.pop_front()
		for offset: Array in [[0, -1], [-1, 0], [1, 0], [0, 1]]:
			var neighbor: Array = [int(cell[0]) + int(offset[0]), int(cell[1]) + int(offset[1])]
			var key: String = _cell_key(neighbor)
			if queue_set.has(key) and not reached.has(key):
				reached[key] = true
				pending.append(neighbor)
	return reached.size() == queue.size()


func _result(phase: String, status: String, feasible: Array, rejected: Array, diagnostics: Array) -> Dictionary:
	return {"phase": phase, "status": status, "feasible_profiles": feasible.duplicate(true), "rejected_profiles": rejected.duplicate(true), "diagnostics": diagnostics.duplicate(true)}


func _profile_failure(profile: Dictionary, code: String, values: Dictionary) -> Dictionary:
	return {"status": STATUS_INFEASIBLE, "operational_profile_id": profile.get("operational_profile_id", ""), "diagnostics": [_diagnostic(code, "$", values)]}


func _profile_indeterminate(profile: Dictionary, state: Dictionary) -> Dictionary:
	return {"status": STATUS_INDETERMINATE, "operational_profile_id": profile.get("operational_profile_id", ""), "diagnostics": [_diagnostic("SEARCH_INDETERMINATE", "$", {"validations_used": state["validations"]})]}


func _profile_ids(results: Array) -> Array[String]:
	var ids: Array[String] = []
	for result_value: Variant in results:
		ids.append(String((result_value as Dictionary).get("operational_profile_id", "")))
	return ids


func _ordered_cells(cells_value: Variant) -> Array[Array]:
	var cells: Array[Array] = []
	if not cells_value is Array:
		return cells
	for cell_value: Variant in cells_value:
		if cell_value is Array and cell_value.size() == 2:
			cells.append([int(cell_value[0]), int(cell_value[1])])
	cells.sort_custom(func(left: Array, right: Array) -> bool: return int(left[1]) < int(right[1]) or (int(left[1]) == int(right[1]) and int(left[0]) < int(right[0])))
	return cells


func _cell_set(cells: Array) -> Dictionary:
	var values: Dictionary = {}
	for cell_value: Variant in cells:
		values[_cell_key(cell_value)] = true
	return values


func _cell_key(cell_value: Variant) -> String:
	var cell: Array = cell_value if cell_value is Array else []
	return "%d,%d" % [int(cell[0]), int(cell[1])] if cell.size() == 2 else "invalid"


func _diagnostic(code: String, path: String, values: Dictionary) -> Dictionary:
	return {"code": code, "path": path, "values": values.duplicate(true)}


func _compare_profile_results(left: Dictionary, right: Dictionary) -> bool:
	return String(left.get("operational_profile_id", "")) < String(right.get("operational_profile_id", ""))
