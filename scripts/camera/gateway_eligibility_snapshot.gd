class_name GatewayEligibilitySnapshot
extends RefCounted

## Immutable structural gateway view consumed by H8. It contains no
## allocation, demand, capacity, visitor, or district-state mutation.

var definition_fingerprint: String = ""
var district_revision: int = -1
var topology_revision: int = -1
var entries: Array[Dictionary] = []


func initialize(p_fingerprint: String, p_district_revision: int, p_topology_revision: int, p_entries: Array) -> void:
	definition_fingerprint = p_fingerprint
	district_revision = p_district_revision
	topology_revision = p_topology_revision
	entries = []
	for entry: Variant in p_entries:
		if entry is Dictionary:
			entries.append(entry.duplicate(true))
	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.get("arrival_source_id", "")) < String(right.get("arrival_source_id", "")))


func duplicate_value() -> GatewayEligibilitySnapshot:
	var copy: GatewayEligibilitySnapshot = load("res://scripts/camera/gateway_eligibility_snapshot.gd").new() as GatewayEligibilitySnapshot
	copy.initialize(definition_fingerprint, district_revision, topology_revision, entries)
	return copy


func value() -> Dictionary:
	return {
		"definition_fingerprint": definition_fingerprint,
		"district_revision": district_revision,
		"topology_revision": topology_revision,
		"entries": entries.duplicate(true),
	}


func eligible_source_ids() -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in entries:
		if bool(entry.get("eligible", false)):
			result.append(String(entry.get("arrival_source_id", "")))
	return result
