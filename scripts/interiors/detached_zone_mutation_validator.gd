## Pure five-case H2 mutation classifier. It creates no live owner state.
class_name DetachedZoneMutationValidator
extends RefCounted

const INTENT_KEYS: Array[String] = ["schema_id", "schema_version", "intent_id", "operation", "zone_plan_key", "paint_mode", "zone_type", "selected_cells", "retirement_authorizations"]


func validate(intent: Dictionary, base: Dictionary, formation_result: Dictionary) -> Dictionary:
	var intent_error := _validate_intent(intent)
	if not intent_error.is_empty(): return _rejected(intent, base, "CONTENT_INVALID", intent_error)
	var base_parcels: Array = base.get("parcels", [])
	var candidate_parcels: Array = formation_result.get("parcels", [])
	var candidates_by_id: Dictionary = {}
	for parcel: Dictionary in candidate_parcels: candidates_by_id[String(parcel.get("parcel_id", parcel.get("parcel_key", "")))] = parcel
	var retired: Array[String] = []; var replacements: Array[Dictionary] = []; var invalidated: Array[String] = []
	var activation := "DETACHED_COMMIT_ELIGIBLE"
	for old: Dictionary in base_parcels:
		var parcel_id := String(old.get("parcel_id", "")); var tenant_id := String(old.get("tenant_id", "")); var candidate: Dictionary = candidates_by_id.get(parcel_id, {})
		if candidate.is_empty():
			var authorization := _authorization(intent["retirement_authorizations"], parcel_id, tenant_id)
			if authorization.is_empty():
				if not tenant_id.is_empty(): return _rejected(intent, base, "BOUND_INTERIOR_INVALIDATED", [{"code":"BOUND_INTERIOR_INVALIDATED","path":"$.parcels","values":{"parcel_id":parcel_id}}])
				retired.append(parcel_id)
			else:
				retired.append(parcel_id)
				if not tenant_id.is_empty(): activation = "REQUIRES_H4_H5_INTEGRATION"
			continue
		if candidate.get("geometry_fingerprint") == old.get("geometry_fingerprint"):
			candidate = old.duplicate(true)
			candidates_by_id[parcel_id] = candidate
			continue
		if not tenant_id.is_empty():
			var bound_profile := String(old.get("bound_profile_id", ""))
			if not (candidate.get("feasible_profile_ids", []) as Array).has(bound_profile): return _rejected(intent, base, "BOUND_INTERIOR_INVALIDATED", [{"code":"BOUND_INTERIOR_INVALIDATED","path":"$.parcels","values":{"parcel_id":parcel_id}}])
			replacements.append({"parcel_id":parcel_id,"tenant_id":tenant_id,"operational_profile_id":bound_profile,"selected_core_key":candidate.get("selected_core_key", ""),"selected_door_semantic_key":candidate.get("selected_door_semantic_key", ""),"selected_queue_envelope_key":candidate.get("selected_queue_envelope_key", ""),"phase_a_parity":candidate.get("phase_a_parity", {})})
			activation = "REQUIRES_H3_PHASE_B"
		if String(candidate.get("suitability", "")) == "INDETERMINATE": return _rejected(intent, base, "SEARCH_INDETERMINATE", [{"code":"SEARCH_INDETERMINATE","path":"$.parcels","values":{"parcel_id":parcel_id}}])
	var parcels: Array = candidates_by_id.values(); parcels.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return String(a.get("parcel_id",a.get("parcel_key",""))) < String(b.get("parcel_id",b.get("parcel_key",""))))
	var value := _base_plan(intent, base, "VALID", activation)
	value["parcels"] = parcels; value["retired_parcel_ids"] = retired; value["residual_decoration_cells"] = formation_result.get("residual_decoration_cells", []).duplicate(true)
	value["graph_fingerprint"] = formation_result.get("graph_fingerprint"); value["queue_input_fingerprint"] = formation_result.get("queue_input_fingerprint"); value["queue_envelopes"] = formation_result.get("queue_envelopes", []).duplicate(true); value["phase_a_parity"] = formation_result.get("phase_a_parity")
	value["suitability_records"] = formation_result.get("suitability_records", []).duplicate(true); value["replacement_requirements"] = replacements; value["invalidation_parcel_ids"] = invalidated
	return DetachedZoneMutationPlan.seal(value)


func _validate_intent(intent: Dictionary) -> Array[Dictionary]:
	if not _exact_keys(intent, INTENT_KEYS) or intent.get("schema_id") != "detached_tenant_zone_mutation_intent" or intent.get("schema_version") != 1 or not ["FORM","REFORM","RETIRE_PARCEL"].has(String(intent.get("operation",""))) or not ["ZONE_TYPE","NONE","UNCHANGED"].has(String(intent.get("paint_mode",""))): return [{"code":"MUTATION_INTENT_INVALID","path":"$","values":{}}]
	return []


func _authorization(values: Array, parcel_id: String, tenant_id: String) -> Dictionary:
	var found: Array[Dictionary] = []
	for value: Dictionary in values:
		if value.get("parcel_id") == parcel_id and value.get("reason") == "PLAYER_PARCEL_RETIREMENT" and (value.get("tenant_id") == null or String(value.get("tenant_id")) == tenant_id): found.append(value)
	return found[0] if found.size() == 1 else {}


func _rejected(intent: Dictionary, base: Dictionary, status: String, diagnostics: Array) -> Dictionary:
	var value := _base_plan(intent, base, status, "REJECTED"); value["diagnostics"] = diagnostics.duplicate(true)
	return DetachedZoneMutationPlan.seal(value)


func _base_plan(intent: Dictionary, base: Dictionary, status: String, activation: String) -> Dictionary:
	var intent_hash := CanonicalJsonFingerprint.new().fingerprint(intent, "JANUS_DETACHED_TENANT_ZONE_MUTATION_INTENT", 1)
	return {"status":status,"activation":activation,"intent_fingerprint":intent_hash.get("fingerprint",""),"base":base.get("provenance",{}).duplicate(true),"requested_district_effects":base.get("requested_district_effects",{"remove_explicit_circulation_cells":[],"add_explicit_circulation_cells":[],"remove_manual_door_edges":[]}).duplicate(true),"parcels":[],"retired_parcel_ids":[],"residual_decoration_cells":[],"graph_fingerprint":null,"queue_input_fingerprint":null,"queue_envelopes":[],"phase_a_parity":null,"suitability_records":[],"replacement_requirements":[],"invalidation_parcel_ids":[],"diagnostics":[]}


func _exact_keys(value: Dictionary, expected: Array[String]) -> bool:
	var actual: Array[String] = []
	for key: Variant in value.keys():
		actual.append(String(key))
	actual.sort()
	var wanted: Array[String] = expected.duplicate()
	wanted.sort()
	return actual == wanted
