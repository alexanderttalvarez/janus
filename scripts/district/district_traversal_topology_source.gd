## Explicit H3-owned traversal door attachment source.
class_name DistrictTraversalTopologySource
extends RefCounted

const REQUIRED_FIELDS: Array[String] = [
	"door_edge_id", "floor_id", "interior_cell_id", "external_ref", "access_kind", "source_kind"
]
const H3_SOURCE_KIND: String = "H3"
const PUBLIC_BAND_ACCESS_KIND: String = "public_band_physical"

var _zone_manager: ZoneManager


func configure(zone_manager: ZoneManager) -> void:
	_zone_manager = zone_manager


## Join explicit H3 attachment records to committed Zone parcel-door identities.
## No door, band, cell, or reachability fact is inferred from Zone geometry.
func build_door_access_edges(explicit_records: Array[Dictionary]) -> Dictionary:
	if _zone_manager == null:
		return _failure("ZONE_MANAGER_REQUIRED", "H3 traversal topology requires ZoneManager door facts")
	var known_doors: Dictionary = {}
	for door_fact: Dictionary in _zone_manager.get_service_proxy_door_snapshots():
		known_doors[String(door_fact.get("door_id", ""))] = door_fact
	var records_by_id: Dictionary = {}
	var diagnostics: Array[Dictionary] = []
	for index: int in range(explicit_records.size()):
		var candidate: Dictionary = explicit_records[index]
		var door_id: String = String(candidate.get("door_edge_id", ""))
		for field: String in REQUIRED_FIELDS:
			if not candidate.has(field) or String(candidate.get(field, "")).is_empty():
				diagnostics.append({"code": "TRAVERSAL_ATTACHMENT_INVALID", "path": "$.door_access_edges[%d].%s" % [index, field]})
		if String(candidate.get("access_kind", "")) != PUBLIC_BAND_ACCESS_KIND:
			diagnostics.append({"code": "TRAVERSAL_ATTACHMENT_ACCESS_KIND_INVALID", "path": "$.door_access_edges[%d].access_kind" % index})
		if String(candidate.get("source_kind", "")) != H3_SOURCE_KIND:
			diagnostics.append({"code": "TRAVERSAL_ATTACHMENT_SOURCE_INVALID", "path": "$.door_access_edges[%d].source_kind" % index})
		if not known_doors.has(door_id):
			diagnostics.append({"code": "TRAVERSAL_ATTACHMENT_DOOR_UNKNOWN", "path": "$.door_access_edges[%d].door_edge_id" % index})
		if records_by_id.has(door_id):
			diagnostics.append({"code": "TRAVERSAL_ATTACHMENT_DUPLICATE", "path": "$.door_access_edges[%d].door_edge_id" % index})
		else:
			records_by_id[door_id] = candidate.duplicate(true)
	if not diagnostics.is_empty():
		return {"valid": false, "records": [], "diagnostics": diagnostics}
	var records: Array[Dictionary] = []
	for door_id: String in records_by_id.keys():
		records.append(records_by_id[door_id])
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["door_edge_id"]) < String(right["door_edge_id"]))
	return {"valid": true, "records": records, "diagnostics": []}


## Replace only the traversal door attachment portion of an active H3 view.
func apply_to_runtime(runtime: DistrictRuntime, explicit_records: Array[Dictionary]) -> Dictionary:
	if runtime == null:
		return _failure("DISTRICT_RUNTIME_REQUIRED", "H3 traversal topology requires DistrictRuntime")
	var current: DistrictTraversalReadView = runtime.get_traversal_read_view()
	if current == null:
		return _failure("TRAVERSAL_VIEW_REQUIRED", "H3 traversal topology requires an active traversal view")
	var built: Dictionary = build_door_access_edges(explicit_records)
	if not bool(built.get("valid", false)):
		return built
	return runtime.set_door_access_edges(built.get("records", []), current.zone_revision)


func _failure(code: String, message: String) -> Dictionary:
	return {"valid": false, "records": [], "diagnostics": [{"code": code, "message": message}]}
