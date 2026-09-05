## PrestigeManager — authoritative committed H1 tier and rent-ceiling state.
## Full Prestige calculation is intentionally unavailable until a later handoff.
class_name PrestigeManager
extends Node


signal official_prestige_snapshot_changed(snapshot: OfficialPrestigeSnapshot)
signal official_tier_changed(previous_snapshot: OfficialPrestigeSnapshot, snapshot: OfficialPrestigeSnapshot)


var _policy: PrestigePolicy
var _committed_snapshot: OfficialPrestigeSnapshot


func initialize(calendar_identity: String, policy: PrestigePolicy) -> Dictionary:
	if policy == null:
		return _failure("PRESTIGE_POLICY_REQUIRED", "PrestigeManager requires immutable approved policy content")
	var content_validation: Dictionary = policy.validate_content()
	if not bool(content_validation.get("valid", false)):
		return content_validation
	_policy = policy
	if _committed_snapshot == null:
		if calendar_identity.is_empty():
			return _failure("PRESTIGE_CALENDAR_IDENTITY_REQUIRED", "initial Prestige state requires a calendar identity")
		_committed_snapshot = _policy.create_initial_snapshot(calendar_identity)
	return {"valid": true, "snapshot": get_committed_snapshot(), "diagnostics": []}


func is_initialized() -> bool:
	return _policy != null and _committed_snapshot != null


func get_district_revision() -> int:
	return 0 if _committed_snapshot == null else _committed_snapshot.get_authority_revision()


func get_committed_snapshot() -> OfficialPrestigeSnapshot:
	if _committed_snapshot == null:
		return null
	return _copy_snapshot(_committed_snapshot)


func get_mall_level_index() -> int:
	if _policy == null or _committed_snapshot == null:
		return -1
	return _policy.get_tier_index(_committed_snapshot.get_tier_id())


func get_mall_level_name() -> String:
	if _policy == null or _committed_snapshot == null:
		return ""
	return String(_policy.get_tier_definition(_committed_snapshot.get_tier_id()).get("name", ""))


## Validate a detached future official result without changing committed state.
func stage_candidate(candidate: OfficialPrestigeSnapshot) -> Dictionary:
	if not is_initialized():
		return _failure("PRESTIGE_NOT_INITIALIZED", "PrestigeManager must be initialized before staging")
	if candidate == null:
		return _failure("PRESTIGE_CANDIDATE_REQUIRED", "official Prestige candidate is required")
	var validation: Dictionary = _policy.validate_snapshot_data(candidate.to_dictionary(), get_district_revision())
	if not bool(validation.get("valid", false)):
		return validation
	return {"valid": true, "snapshot": _snapshot_from_dictionary(validation["snapshot"]), "diagnostics": []}


## Atomically replace the committed result. Only this method assigns revisions.
func commit_candidate(candidate: OfficialPrestigeSnapshot) -> Dictionary:
	var staged: Dictionary = stage_candidate(candidate)
	if not bool(staged.get("valid", false)):
		return staged
	var previous: OfficialPrestigeSnapshot = _committed_snapshot
	var committed_data: Dictionary = staged["snapshot"].to_dictionary()
	committed_data["authority_revision"] = previous.get_authority_revision() + 1
	var committed: OfficialPrestigeSnapshot = _snapshot_from_dictionary(committed_data)
	_committed_snapshot = committed
	var previous_copy: OfficialPrestigeSnapshot = _copy_snapshot(previous)
	var committed_copy: OfficialPrestigeSnapshot = _copy_snapshot(committed)
	official_prestige_snapshot_changed.emit(committed_copy)
	if previous.get_tier_id() != committed.get_tier_id():
		official_tier_changed.emit(previous_copy, committed_copy)
	_emit_event_bus(previous_copy, committed_copy)
	return {"valid": true, "snapshot": committed_copy, "diagnostics": []}


## Build a detached H2 candidate from an authoritative developed-tile snapshot.
func create_monthly_candidate(source: DevelopedTileSnapshot, calendar_identity: String) -> OfficialPrestigeCandidate:
	var candidate_script: Script = load("res://scripts/simulation/official_prestige_candidate.gd")
	var candidate: OfficialPrestigeCandidate = candidate_script.new() as OfficialPrestigeCandidate
	if source == null or not is_initialized() or calendar_identity.is_empty():
		return candidate
	var source_validation: Dictionary = source.validate()
	if not bool(source_validation.get("valid", false)):
		return candidate
	return OfficialPrestigeCandidate.calculate(source, calendar_identity, PrestigePolicy.POLICY_REVISION)


## Validate and commit one monthly candidate through the H1 authority boundary.
func commit_monthly_candidate(candidate: OfficialPrestigeCandidate, current_source_revision: int = -1) -> Dictionary:
	if not is_initialized():
		return _failure("PRESTIGE_NOT_INITIALIZED", "PrestigeManager must be initialized before monthly commits")
	if candidate == null:
		return _failure("PRESTIGE_CANDIDATE_REQUIRED", "monthly Prestige candidate is required")
	var candidate_validation: Dictionary = candidate.validate()
	if not bool(candidate_validation.get("valid", false)):
		return candidate_validation
	if candidate.get_policy_revision() != PrestigePolicy.POLICY_REVISION:
		return _failure("PRESTIGE_CANDIDATE_POLICY_STALE", "monthly candidate policy revision is stale")
	if current_source_revision >= 0 and candidate.get_source_revision() != current_source_revision:
		return _failure("PRESTIGE_CANDIDATE_SOURCE_STALE", "developed-tile source revision is stale")
	var tier_definition: Dictionary = _policy.get_tier_for_numeric_prestige(candidate.get_numeric_prestige())
	if tier_definition.is_empty():
		return _failure("PRESTIGE_CANDIDATE_TIER_INVALID", "numeric Prestige did not resolve to an official tier")
	var snapshot_data: Dictionary = {
		"schema_version": PrestigePolicy.SNAPSHOT_SCHEMA_VERSION,
		"authority_revision": get_district_revision(),
		"official_tier_id": tier_definition["tier_id"],
		"supported_tenant_tier": tier_definition["supported_tenant_tier"],
		"exclusive_eligible": tier_definition["exclusive_eligible"],
		"rent_ceiling_centi_kreds": tier_definition["rent_ceiling_centi_kreds"],
		"policy_revision": candidate.get_policy_revision(),
		"calendar_identity": candidate.get_calendar_identity(),
		"numeric_prestige_present": true,
		"numeric_prestige": candidate.get_numeric_prestige(),
		"numeric_prestige_provenance": OfficialPrestigeCandidate.PROVENANCE,
	}
	var snapshot: OfficialPrestigeSnapshot = _snapshot_from_dictionary(snapshot_data)
	return commit_candidate(snapshot)


## H2 cadence hook. With no authoritative source supplied, do nothing rather
## than fabricate a source snapshot, daily trend, or numeric Prestige value.
func recalculate(source: DevelopedTileSnapshot = null, calendar_identity: String = "") -> Dictionary:
	if source == null or calendar_identity.is_empty():
		return _failure("PRESTIGE_SOURCE_UNAVAILABLE", "monthly developed-tile source is unavailable")
	var candidate: OfficialPrestigeCandidate = create_monthly_candidate(source, calendar_identity)
	return commit_monthly_candidate(candidate, source.get_source_revision())


## Restore exact committed V2 state without emitting business events.
func deserialize(data: Dictionary) -> Dictionary:
	var staged: Dictionary = stage_serialized_state(data)
	if not bool(staged.get("valid", false)):
		return staged
	_committed_snapshot = staged["snapshot"]
	return {"valid": true, "snapshot": get_committed_snapshot(), "diagnostics": []}


func stage_serialized_state(data: Variant) -> Dictionary:
	if _policy == null:
		return _failure("PRESTIGE_POLICY_REQUIRED", "Prestige policy must be available before restore staging")
	var validation: Dictionary = _policy.validate_snapshot_data(data)
	if not bool(validation.get("valid", false)):
		return validation
	return {"valid": true, "snapshot": _snapshot_from_dictionary(validation["snapshot"]), "diagnostics": []}


func validate_serialized_state(data: Variant) -> Dictionary:
	return stage_serialized_state(data)


func serialize() -> Dictionary:
	return {} if _committed_snapshot == null else _committed_snapshot.to_dictionary()


func _snapshot_from_dictionary(data: Dictionary) -> OfficialPrestigeSnapshot:
	var snapshot_script: Script = load("res://scripts/simulation/official_prestige_snapshot.gd")
	var snapshot: OfficialPrestigeSnapshot = snapshot_script.new() as OfficialPrestigeSnapshot
	snapshot.configure(data)
	return snapshot


func _copy_snapshot(snapshot: OfficialPrestigeSnapshot) -> OfficialPrestigeSnapshot:
	return _snapshot_from_dictionary(snapshot.to_dictionary())


func _emit_event_bus(previous: OfficialPrestigeSnapshot, current: OfficialPrestigeSnapshot) -> void:
	if not is_inside_tree():
		return
	var event_bus: Node = get_tree().root.get_node_or_null("EventBus")
	if event_bus == null:
		return
	event_bus.official_prestige_snapshot_changed.emit(current.to_dictionary())
	if previous.get_tier_id() != current.get_tier_id():
		event_bus.official_tier_changed.emit(previous.to_dictionary(), current.to_dictionary())


func _failure(code: String, message: String) -> Dictionary:
	return {"valid": false, "snapshot": {}, "diagnostics": [{"code": code, "message": message}]}
