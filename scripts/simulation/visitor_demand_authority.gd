class_name VisitorDemandAuthority
extends RefCounted

## H8 demand authority. It owns desired counts and visitor attributes only;
## it never chooses or inspects arrival sources.

var desired_count: int = 20
var profiles: Array[Dictionary] = []
var _snapshot_counter: int = 0


func set_desired_count(count: int) -> Dictionary:
	if count < 0:
		return {"valid": false, "diagnostics": [{"code": "DEMAND_COUNT_INVALID", "message": "desired visitor count cannot be negative"}]}
	desired_count = count
	return {"valid": true, "diagnostics": []}


func set_profiles(next_profiles: Array) -> Dictionary:
	var candidate := ArrivalDemandSnapshot.new()
	var validation: Dictionary = candidate.initialize("validation", desired_count, next_profiles)
	if not bool(validation.get("valid", false)):
		return validation
	profiles.clear()
	for profile: Dictionary in next_profiles:
		profiles.append(profile.duplicate(true))
	return {"valid": true, "diagnostics": []}


func capture_snapshot() -> ArrivalDemandSnapshot:
	_snapshot_counter += 1
	var snapshot := ArrivalDemandSnapshot.new()
	snapshot.initialize("demand_%d" % _snapshot_counter, desired_count, profiles)
	return snapshot


func capture_snapshot_with_identity(snapshot_id: String) -> ArrivalDemandSnapshot:
	var snapshot := ArrivalDemandSnapshot.new()
	var result: Dictionary = snapshot.initialize(snapshot_id, desired_count, profiles)
	return snapshot if bool(result.get("valid", false)) else null
