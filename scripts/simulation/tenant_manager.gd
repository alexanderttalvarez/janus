## TenantManager — authoritative tenant lifecycle and rent snapshot owner.
class_name TenantManager
extends Node

signal tenant_bound(tenant_id: String, zone_id: String, parcel_id: String)
signal tenant_released(tenant_id: String, zone_id: String, parcel_id: String)
signal rent_snapshot_published(snapshot: Dictionary)
signal spatial_context_invalidated(diagnostics: Array[Dictionary])
signal tenant_application_evaluated(result: Dictionary)
signal service_proxy_snapshot_published(snapshot: Array[Dictionary])

const LIFECYCLE_STATES: Array[String] = ["candidate", "exclusivity", "constructing", "operating", "critical", "closing", "closed"]
const SNAPSHOT_SCHEMA_VERSION: int = 1
const SERVICE_PROXY_POLICY_REVISION: int = 1

var all_tenants: Array[Dictionary] = []
var _tenant_counter: int = 0
var _authority_revision: int = 0
var _session_seed: int = 0
var _evaluation_ordinals: Dictionary = {}
var _next_evaluations: Dictionary = {}
var _zone_manager: ZoneManager
var _last_rent_snapshot: Dictionary = {}
var _last_service_proxy_snapshot: Array[Dictionary] = []
var _spatial_context: SpatialEvaluationContext
var _diagnostics: Array[Dictionary] = []
var _evaluation_results: Dictionary = {}


func _ready() -> void:
	pass


func initialize(zone_manager: ZoneManager, session_seed: int = 0) -> void:
	_zone_manager = zone_manager
	_session_seed = maxi(session_seed, 0)


func configure_session_seed(session_seed: int) -> void:
	_session_seed = maxi(session_seed, 0)


func authority_revision() -> int:
	return _authority_revision


func diagnostics() -> Array[Dictionary]:
	return _diagnostics.duplicate(true)


func generate_candidate(zone_id: String, parcel_id: String, zone_type: String, minimum_tiles: int, legal_subtype_ids: Array, neighbor_subtype_ids: Array, supported_tier: int, sim_day: int, policy: TenantCandidatePolicy) -> Dictionary:
	if policy == null or not bool(policy.validate_content().get("valid", false)):
		return _record_unavailable_evaluation(parcel_id, sim_day, "CANDIDATE_TIER_POLICY_UNAVAILABLE")
	var ordinal: int = int(_evaluation_ordinals.get(parcel_id, 0))
	var selection := policy.select(zone_type, supported_tier, legal_subtype_ids, neighbor_subtype_ids, minimum_tiles, _session_seed, parcel_id, ordinal)
	if not bool(selection.get("valid", false)):
		return _record_unavailable_evaluation(parcel_id, sim_day, String(selection.get("diagnostics", [{"code": "CANDIDATE_POLICY_NO_LEGAL_PROFILE"}])[0].get("code", "CANDIDATE_POLICY_NO_LEGAL_PROFILE")))
	var profile: Dictionary = selection["profile"]
	return {
		"valid": true,
		"candidate_id": "candidate_%s_%d" % [parcel_id, ordinal],
		"parcel_id": parcel_id,
		"zone_id": zone_id,
		"subtype_id": String(profile["subtype_id"]),
		"candidate_profile_id": String(profile["profile_id"]),
		"candidate_tier": int(profile["tier"]),
		"selectivity": int(selection["selectivity"]),
		"policy_revision": int(selection["policy_revision"]),
		"provenance": String(selection["provenance"]),
		"evaluation_ordinal": ordinal,
		"evaluation_day": sim_day,
		"diagnostics": [],
	}


func _record_unavailable_evaluation(parcel_id: String, sim_day: int, code: String) -> Dictionary:
	var result := {"valid": false, "outcome": "deferred", "diagnostics": [{"code": code}], "next_evaluation_after_days": 3}
	return _record_application_result(parcel_id, sim_day, result)


func register_candidate(candidate: Dictionary, sim_day: int) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	for field: String in ["candidate_id", "parcel_id", "zone_id", "subtype_id", "candidate_profile_id"]:
		if String(candidate.get(field, "")).is_empty():
			diagnostics.append({"code": "TENANT_CANDIDATE_INVALID", "path": "$.%s" % field})
	if diagnostics.size() > 0:
		return {"committed": false, "diagnostics": diagnostics}
	var tenant_id := _next_id()
	var record: Dictionary = {
		"tenant_id": tenant_id,
		"candidate_id": String(candidate["candidate_id"]),
		"parcel_id": String(candidate["parcel_id"]),
		"zone_id": String(candidate["zone_id"]),
		"subtype_id": String(candidate["subtype_id"]),
		"candidate_profile_id": String(candidate["candidate_profile_id"]),
		"candidate_tier": int(candidate.get("candidate_tier", 1)),
		"selectivity": int(candidate.get("selectivity", 0)),
		"candidate_policy_revision": int(candidate.get("policy_revision", 1)),
		"candidate_provenance": String(candidate.get("provenance", "")),
		"lifecycle_state": "exclusivity",
		"created_day": sim_day,
		"exclusivity_until_day": sim_day + 7,
		"construction_complete_day": -1,
	}
	var bind_result := _bind_parcel(record)
	if not bool(bind_result.get("committed", false)):
		_tenant_counter -= 1
		return bind_result
	all_tenants.append(record)
	_authority_revision += 1
	tenant_bound.emit(tenant_id, record["zone_id"], record["parcel_id"])
	return {"committed": true, "tenant_id": tenant_id, "authority_revision": _authority_revision, "diagnostics": []}


func release_tenant(tenant_id: String, reason: String, sim_day: int) -> Dictionary:
	for record: Dictionary in all_tenants:
		if String(record.get("tenant_id", "")) != tenant_id:
			continue
		if String(record.get("lifecycle_state", "")) == "closed":
			return {"committed": false, "diagnostics": [{"code": "TENANT_ALREADY_CLOSED"}]}
		var release_result := _zone_manager.release_tenant_from_parcel(String(record["zone_id"]), String(record["parcel_id"]), tenant_id)
		if not bool(release_result.get("committed", false)):
			return release_result
		record["lifecycle_state"] = "closed"
		record["closed_day"] = sim_day
		record["close_reason"] = reason
		_authority_revision += 1
		tenant_released.emit(tenant_id, record["zone_id"], record["parcel_id"])
		return {"committed": true, "authority_revision": _authority_revision, "diagnostics": []}
	return {"committed": false, "diagnostics": [{"code": "TENANT_NOT_FOUND", "tenant_id": tenant_id}]}


func advance_lifecycle(sim_day: int, construction_days: int = 14) -> Dictionary:
	var changed: Array[String] = []
	for record: Dictionary in all_tenants:
		var state := String(record.get("lifecycle_state", ""))
		if state == "candidate":
			record["lifecycle_state"] = "exclusivity"
			changed.append(String(record["tenant_id"]))
		elif state == "exclusivity" and sim_day >= int(record["exclusivity_until_day"]):
			record["lifecycle_state"] = "constructing"
			record["construction_complete_day"] = sim_day + maxi(construction_days, 1)
			changed.append(String(record["tenant_id"]))
		elif state == "constructing" and sim_day >= int(record["construction_complete_day"]):
			record["lifecycle_state"] = "operating"
			changed.append(String(record["tenant_id"]))
	if not changed.is_empty():
		_authority_revision += 1
	return {"committed": true, "changed_tenant_ids": changed, "authority_revision": _authority_revision, "diagnostics": []}


func build_rent_snapshot(sim_day: int, zone_revision: int) -> Dictionary:
	var entries: Array[Dictionary] = []
	for record: Dictionary in all_tenants:
		if String(record.get("lifecycle_state", "")) != "operating":
			continue
		var subtype_id := String(record["subtype_id"])
		var zone_rate := _zone_manager.zone_rate_snapshot(String(record["zone_id"])) if _zone_manager != null else {"valid": false}
		if not bool(zone_rate.get("valid", false)) or String(zone_rate.get("rate_state", "")) != "READY":
			_diagnostics.append({"code": "TENANT_RENT_RATE_MISSING", "zone_id": String(record["zone_id"])})
			continue
		var daily_rate: int = int(zone_rate["daily_rent_rate_centi_kreds"])
		var tile_count: int = _parcel_tile_count(String(record["zone_id"]), String(record["parcel_id"]))
		var rent_amount: int = floori(float(daily_rate * tile_count) / 100.0)
		entries.append({
			"tenant_id": String(record["tenant_id"]),
			"parcel_id": String(record["parcel_id"]),
			"zone_id": String(record["zone_id"]),
			"subtype_id": subtype_id,
			"parcel_tile_count": tile_count,
			"daily_rate_centi_kreds": daily_rate,
			"rent_amount_kreds": rent_amount,
		})
	var snapshot := {
		"schema_version": SNAPSHOT_SCHEMA_VERSION,
		"simulation_day": sim_day,
		"tenant_revision": _authority_revision,
		"zone_revision": zone_revision,
		"entries": entries,
	}
	_last_rent_snapshot = snapshot.duplicate(true)
	rent_snapshot_published.emit(_last_rent_snapshot.duplicate(true))
	return {"committed": true, "snapshot": _last_rent_snapshot.duplicate(true), "diagnostics": []}


func last_rent_snapshot() -> Dictionary:
	return _last_rent_snapshot.duplicate(true)


## Publish detached tenant-facing proxy facts from committed tenant and zone state.
func publish_service_proxy_snapshot(attachments: Array[Dictionary]) -> Dictionary:
	var attachments_by_door: Dictionary = {}
	for attachment: Dictionary in attachments:
		var door_id: String = String(attachment.get("door_id", ""))
		var anchor_id: String = String(attachment.get("corridor_anchor_id", ""))
		if door_id.is_empty() or anchor_id.is_empty():
			continue
		if int(attachment.get("topology_revision", -1)) < 0:
			continue
		attachments_by_door[door_id] = attachment.duplicate(true)
	var proxies: Array[Dictionary] = []
	if _zone_manager != null:
		var door_facts: Array[Dictionary] = _zone_manager.get_service_proxy_door_snapshots()
		for record: Dictionary in all_tenants:
			if String(record.get("lifecycle_state", "")) != "operating":
				continue
			for door_fact: Dictionary in door_facts:
				if String(door_fact.get("tenant_id", "")) != String(record.get("tenant_id", "")):
					continue
				if String(door_fact.get("parcel_id", "")) != String(record.get("parcel_id", "")):
					continue
				var door_id: String = String(door_fact.get("door_id", ""))
				if not attachments_by_door.has(door_id):
					continue
				var attachment: Dictionary = attachments_by_door[door_id]
				if not bool(attachment.get("public_corridor_reachable", false)):
					continue
				var proxy_id: String = "proxy/%s/%s" % [record["parcel_id"], door_id]
				var proxy: Dictionary = {
					"schema_version": VisitorServiceProxy.SCHEMA_VERSION,
					"parcel_door_proxy_id": proxy_id,
					"tenant_id": String(record["tenant_id"]),
					"parcel_id": String(record["parcel_id"]),
					"door_id": door_id,
					"corridor_anchor_id": String(attachment["corridor_anchor_id"]),
					"tenant_active": true,
					"public_corridor_reachable": true,
					"proxy_enabled": bool(attachment.get("proxy_enabled", true)),
					"queue_accepting": true,
					"proxy_policy_revision": SERVICE_PROXY_POLICY_REVISION,
					"topology_revision": int(attachment["topology_revision"]),
					"tenant_revision": _authority_revision,
				}
				var validation := VisitorServiceProxy.new()
				validation.configure(proxy)
				if bool(validation.validate().get("valid", false)):
					proxies.append(proxy)
	proxies.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["parcel_door_proxy_id"]) < String(right["parcel_door_proxy_id"]))
	_last_service_proxy_snapshot = proxies.duplicate(true)
	service_proxy_snapshot_published.emit(_last_service_proxy_snapshot.duplicate(true))
	return {"valid": true, "snapshots": _last_service_proxy_snapshot.duplicate(true), "diagnostics": []}


func last_service_proxy_snapshot() -> Array[Dictionary]:
	return _last_service_proxy_snapshot.duplicate(true)


func evaluate_application(context: ApplicationEvaluationContext, sim_day: int) -> Dictionary:
	var parcel_id := ""
	if context != null:
		var context_data := context.to_dictionary()
		parcel_id = String(context_data.get("parcel_id", ""))
		if int(context_data.get("candidate_tier", 0)) > int(context_data.get("supported_prestige_tier", 0)):
			return _record_application_result(parcel_id, sim_day, {"valid": false, "outcome": "deferred", "diagnostics": [{"code": "CANDIDATE_TIER_POLICY_UNAVAILABLE"}]})
	var result := ApplicationEvaluator.new().evaluate(context)

	if context != null:
		parcel_id = String(context.to_dictionary().get("parcel_id", ""))
	if not bool(result.get("valid", false)):
		return _record_application_result(parcel_id, sim_day, result)
	if String(result.get("outcome", "")) == "passed":
		var data := context.to_dictionary()
		var bind_result := register_candidate({
			"candidate_id": String(data["candidate_id"]),
			"parcel_id": String(data["parcel_id"]),
			"zone_id": String(data["zone_id"]),
			"subtype_id": String(data["subtype_id"]),
			"candidate_profile_id": String(data["candidate_profile_id"]),
			"candidate_tier": int(data["candidate_tier"]),
			"selectivity": int(data["selectivity"]),
			"policy_revision": int(data["policy_revision"]),
			"provenance": String(data["provenance"]),
		}, sim_day)
		if not bool(bind_result.get("committed", false)):
			result["outcome"] = "deferred"
			result["diagnostics"] = [{"code": "APPLICATION_BIND_STALE"}]
			return _record_application_result(parcel_id, sim_day, result)
		result["tenant_id"] = String(bind_result["tenant_id"])
		result["next_evaluation_day"] = -1
		return _record_application_result(parcel_id, sim_day, result)
	return _record_application_result(parcel_id, sim_day, result)


func evaluation_result(parcel_id: String) -> Dictionary:
	return _evaluation_results.get(parcel_id, {}).duplicate(true)


func _record_application_result(parcel_id: String, sim_day: int, result: Dictionary) -> Dictionary:
	var ordinal: int = int(_evaluation_ordinals.get(parcel_id, 0)) + 1 if not parcel_id.is_empty() else 0
	if not parcel_id.is_empty():
		_evaluation_ordinals[parcel_id] = ordinal
		result["evaluation_ordinal"] = ordinal
		result["next_evaluation_day"] = sim_day + int(result.get("next_evaluation_after_days", 3)) if String(result.get("outcome", "")) != "passed" else -1
		_evaluation_results[parcel_id] = result.duplicate(true)
	tenant_application_evaluated.emit(result.duplicate(true))
	return result


func capture_spatial_context(prestige: OfficialPrestigeSnapshot, circulation: CirculationEvaluationSnapshot, relationship: ZoneRelationshipSnapshot, policy: RentRecommendationPolicy) -> Dictionary:
	var result := SpatialEvaluationContext.capture(prestige, circulation, relationship, policy)
	if not bool(result.get("valid", false)):
		var failed_diagnostics: Array[Dictionary] = []
		for diagnostic: Variant in result.get("diagnostics", []):
			if diagnostic is Dictionary:
				failed_diagnostics.append(diagnostic)
		spatial_context_invalidated.emit(failed_diagnostics)
		return result
	_spatial_context = result["context"] as SpatialEvaluationContext
	return {"valid": true, "diagnostics": []}


func evaluate_recommended_rent(elevation: int, prestige_authority_revision: int, topology_revision: int, geometry_revision: int, policy_revision: int) -> Dictionary:
	if _spatial_context == null:
		return {"valid": false, "diagnostics": [{"code": "SPATIAL_CONTEXT_UNAVAILABLE"}]}
	if not _spatial_context.is_current(prestige_authority_revision, topology_revision, geometry_revision, policy_revision):
		var stale_diagnostics: Array[Dictionary] = [{"code": "SPATIAL_CONTEXT_STALE", "message": "one or more captured authority revisions changed"}]
		spatial_context_invalidated.emit(stale_diagnostics)
		return {"valid": false, "diagnostics": stale_diagnostics}
	return _spatial_context.calculate_recommendation(elevation)


func on_sim_day_passed(sim_day: int) -> void:
	advance_lifecycle(sim_day)
	if _zone_manager != null:
		build_rent_snapshot(sim_day, _zone_manager.get_district_revision())


func serialize() -> Dictionary:
	return {
		"schema_version": SNAPSHOT_SCHEMA_VERSION,
		"authority_revision": _authority_revision,
		"session_seed": _session_seed,
		"tenant_counter": _tenant_counter,
		"evaluation_ordinals": _evaluation_ordinals.duplicate(true),
		"next_evaluations": _next_evaluations.duplicate(true),
		"tenants": all_tenants.duplicate(true),
		"diagnostics": _diagnostics.duplicate(true),
		"evaluation_results": _evaluation_results.duplicate(true),
	}


func deserialize(data: Dictionary) -> void:
	var snapshot := TenantAuthoritySnapshot.new()
	snapshot.configure(data)
	var validation := snapshot.validate()
	if not bool(validation["valid"]):
		_diagnostics = validation["diagnostics"]
		return
	_authority_revision = int(data["authority_revision"])
	_session_seed = int(data["session_seed"])
	_tenant_counter = int(data["tenant_counter"])
	_evaluation_ordinals = data["evaluation_ordinals"].duplicate(true)
	_next_evaluations = data["next_evaluations"].duplicate(true)
	all_tenants = data["tenants"].duplicate(true)
	_diagnostics = data["diagnostics"].duplicate(true)
	_evaluation_results = data["evaluation_results"].duplicate(true)


func _bind_parcel(record: Dictionary) -> Dictionary:
	if _zone_manager == null:
		return {"committed": false, "diagnostics": [{"code": "TENANT_ZONE_MANAGER_NOT_BOUND"}]}
	return _zone_manager.bind_tenant_to_parcel(String(record["zone_id"]), String(record["parcel_id"]), String(record["tenant_id"]))


func _parcel_tile_count(zone_id: String, parcel_id: String) -> int:
	if _zone_manager == null:
		return 0
	var parcel_snapshot: Dictionary = _zone_manager.parcel_snapshot(zone_id, parcel_id)
	return int(parcel_snapshot.get("tile_count", 0))


func _next_id() -> String:
	_tenant_counter += 1
	return "tenant_%d" % _tenant_counter
