class_name ArrivalDemandSnapshot
extends RefCounted

## Immutable demand-only input to the H8 arrival coordinator.
## Demand contains counts and gameplay attributes, never spatial source data.

var snapshot_id: String = ""
var desired_count: int = 0
var profiles: Array[Dictionary] = []


func initialize(p_snapshot_id: String, p_desired_count: int, p_profiles: Array = []) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if p_snapshot_id.is_empty():
		diagnostics.append({"code": "DEMAND_SNAPSHOT_ID_REQUIRED", "message": "demand snapshot identity is required"})
	if p_desired_count < 0:
		diagnostics.append({"code": "DEMAND_COUNT_INVALID", "message": "desired visitor count cannot be negative"})
	var copied_profiles: Array[Dictionary] = []
	for profile: Variant in p_profiles:
		if not profile is Dictionary:
			diagnostics.append({"code": "DEMAND_PROFILE_INVALID", "message": "demand profiles must be dictionaries"})
			continue
		for forbidden: String in ["arrival_source_id", "source_id", "position", "route", "topology"]:
			if profile.has(forbidden):
				diagnostics.append({"code": "DEMAND_SPATIAL_FIELD_FORBIDDEN", "message": "demand cannot contain spatial source fields"})
				break
		copied_profiles.append(profile.duplicate(true))
	if not diagnostics.is_empty():
		return {"valid": false, "diagnostics": diagnostics}
	snapshot_id = p_snapshot_id
	desired_count = p_desired_count
	profiles = copied_profiles
	return {"valid": true, "diagnostics": []}


func duplicate_value() -> ArrivalDemandSnapshot:
	var copy: ArrivalDemandSnapshot = load("res://scripts/simulation/arrival_demand_snapshot.gd").new() as ArrivalDemandSnapshot
	copy.initialize(snapshot_id, desired_count, profiles)
	return copy


func value() -> Dictionary:
	return {
		"snapshot_id": snapshot_id,
		"desired_count": desired_count,
		"profiles": profiles.duplicate(true),
	}
