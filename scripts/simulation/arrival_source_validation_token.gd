class_name ArrivalSourceValidationToken
extends RefCounted

## Ephemeral, single-use validation capability issued by DistrictRuntime.
## It carries no source state and is never serializable.

var token_id: String = ""
var arrival_source_id: String = ""
var demand_snapshot_id: String = ""
var district_revision: int = -1
var topology_revision: int = -1
var eligibility_revision: int = -1
var _invalidated: bool = false
var _consumed: bool = false
var _gate: ArrivalCommitGate


func initialize(
	p_token_id: String,
	p_arrival_source_id: String,
	p_demand_snapshot_id: String,
	p_district_revision: int,
	p_topology_revision: int,
	p_eligibility_revision: int
) -> void:
	token_id = p_token_id
	arrival_source_id = p_arrival_source_id
	demand_snapshot_id = p_demand_snapshot_id
	district_revision = p_district_revision
	topology_revision = p_topology_revision
	eligibility_revision = p_eligibility_revision
	_invalidated = false
	_consumed = false


func bind_gate(gate: ArrivalCommitGate) -> void:
	_gate = gate


func matches(
	p_arrival_source_id: String,
	p_demand_snapshot_id: String,
	p_district_revision: int,
	p_topology_revision: int,
	p_eligibility_revision: int
) -> bool:
	return is_valid() and arrival_source_id == p_arrival_source_id and demand_snapshot_id == p_demand_snapshot_id and district_revision == p_district_revision and topology_revision == p_topology_revision and eligibility_revision == p_eligibility_revision


func is_valid() -> bool:
	var gate_valid: bool = _gate == null or _gate.is_held()
	return not token_id.is_empty() and not arrival_source_id.is_empty() and not demand_snapshot_id.is_empty() and not _invalidated and not _consumed and gate_valid


func invalidate() -> void:
	_invalidated = true


func consume() -> bool:
	if not is_valid():
		return false
	_consumed = true
	return true


func value() -> Dictionary:
	return {
		"token_id": token_id,
		"arrival_source_id": arrival_source_id,
		"demand_snapshot_id": demand_snapshot_id,
		"district_revision": district_revision,
		"topology_revision": topology_revision,
		"eligibility_revision": eligibility_revision,
		"valid": is_valid(),
	}
