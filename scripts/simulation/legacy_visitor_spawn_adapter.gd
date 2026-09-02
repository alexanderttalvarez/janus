class_name LegacyVisitorSpawnAdapter
extends RefCounted

## H8 compatibility seam. It translates an allocated source record into the
## existing VisitorManager detached-record API. It never reads persisted
## corner IDs and never owns source state or allocation policy.

var visitor_manager: VisitorManager


func initialize(manager: VisitorManager) -> void:
	visitor_manager = manager


func prepare_selected_source(source: Dictionary, demand: ArrivalDemandSnapshot) -> Dictionary:
	if visitor_manager == null:
		return {"valid": false, "diagnostics": [{"code": "LEGACY_VISITOR_MANAGER_REQUIRED", "message": "VisitorManager is required"}]}
	var source_id: String = String(source.get("arrival_source_id", ""))
	return visitor_manager.prepare_detached_visitor(source_id, source, demand)


func has_persisted_corner_mapping(data: Dictionary) -> bool:
	return data.has("spawn_point_id")
