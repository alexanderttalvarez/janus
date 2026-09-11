## ZoneManager — Owns zone lifecycle and atomically commits valid parcel splits.
class_name ZoneManager
extends Node


enum AssignmentMode { DEBUG_IMMEDIATE }

const PHYSICAL_DOOR_ACCESS_KINDS: Array[String] = ["external_circulation", "internal_transit", "public_band"]

## Active parcel-subtype assignment policy for this handoff.
var assignment_mode: AssignmentMode = AssignmentMode.DEBUG_IMMEDIATE

## All zones, keyed by zone ID.
var zones: Dictionary = {}  # Dictionary[String, ZoneData]

## Monotonic authority revision used by coordinated district transactions.
var authority_revision: int = 0

## Zone ID counter for generating unique IDs.
var _zone_counter: int = 0

## Parcel ID counter for globally unique, persistent parcel IDs.
var _parcel_counter: int = 0

## Parcel display-number counter. Numbers are positive and never reused.
var _parcel_display_number_counter: int = 0

## Most recent pure split attempt for future UI/debug feedback.
var last_split_result: SplitResult

## H3 holds zone gameplay notifications until the district envelope commits.
var _district_notifications_deferred: bool = false
var _deferred_district_notifications: Array[Dictionary] = []

signal zone_rent_initialized(zone_id: String, rate_centi_kreds: int, rate_revision: int)
signal zone_rent_changed(zone_id: String, rate_centi_kreds: int, rate_revision: int, request_reference: String)

## Most recent committed debug subtype assignment result.
var last_assignment_result: BusinessAssignmentResult


# ── District Transaction Authority ────────────────────────────────────


## Return the monotonic revision observed by District Runtime.
func get_district_revision() -> int:
	return authority_revision


## Prepare a detached coordination token without writing zone authority.
func preview_district_candidate(
	intent: Dictionary,
	district_ref: Dictionary,
	spatial_snapshot: DistrictZoneSpatialSnapshot,
	public_band_access: PublicBandAccessSnapshot = null
) -> Dictionary:
	var spatial_validation: Dictionary = _validate_spatial_snapshot_input(intent, district_ref, spatial_snapshot)
	if not bool(spatial_validation.get("valid", false)):
		return {"accepted": false, "preview": null, "diagnostics": spatial_validation.get("diagnostics", [])}
	var public_access_validation: Dictionary = _validate_public_band_access_input(district_ref, public_band_access)
	if not bool(public_access_validation.get("valid", false)):
		return {"accepted": false, "preview": null, "diagnostics": public_access_validation.get("diagnostics", [])}
	var retained_validation: Dictionary = _validate_retained_public_band_doors(public_band_access)
	if not bool(retained_validation.get("valid", false)):
		return {"accepted": false, "preview": null, "diagnostics": retained_validation.get("diagnostics", [])}
	if String(intent.get("operation", "")) == DistrictRuntime.OP_SET_MANUAL_DOOR:
		var door_validation: Dictionary = _validate_manual_door_zone_intent(intent, district_ref)
		if not bool(door_validation.get("valid", false)):
			return {"accepted": false, "preview": null, "diagnostics": door_validation.get("diagnostics", [])}
		return {"accepted": true, "preview": null, "diagnostics": []}
	if String(intent.get("operation", "")) != DistrictRuntime.OP_PAINT_ZONE:
		return {"accepted": true, "preview": null, "diagnostics": []}
	var prospective_zone_state: Dictionary = _build_manual_door_zone_candidate(intent)
	var existing_door_validation: Dictionary = _validate_manual_door_records_against_zone_candidate(spatial_snapshot.get_manual_door_edges(), prospective_zone_state, String(intent.get("zone_floor_label", "")))
	if not bool(existing_door_validation.get("valid", false)):
		return {"accepted": false, "preview": null, "diagnostics": existing_door_validation.get("diagnostics", [])}
	var district_effects: Dictionary = _build_district_effects(intent, spatial_snapshot, existing_door_validation)
	var preview: SplitResult = preview_paint(
		String(intent.get("zone_type", "")),
		_to_vector2i_array(intent.get("cells", [])),
		String(intent.get("zone_floor_label", "")),
		String(intent.get("zone_plot_id", "")),
		intent.get("typologies", {}),
		String(intent.get("paint_mode", "zone")),
		spatial_snapshot,
		public_band_access
	)
	if preview == null or not preview.is_success():
		return {"accepted": false, "diagnostics": [{"code": "ZONE_PAINT_REJECTED", "message": "ZoneManager rejected the detached zone paint candidate"}]}
	return {
		"accepted": true,
		"preview": preview,
		"manual_door_zone_candidate": prospective_zone_state,
		"district_effects": district_effects,
		"diagnostics": [],
	}


func _build_manual_door_zone_candidate(intent: Dictionary) -> Dictionary:
	var candidate: Dictionary = {"zones": serialize().get("zones", {}).duplicate(true), "zone_revision": authority_revision + 1}
	var zones: Dictionary = candidate["zones"]
	var plot_id: String = String(intent.get("zone_plot_id", intent.get("runtime_plot_id", "")))
	var floor: String = String(intent.get("zone_floor_label", ""))
	var cells: Array = intent.get("cells", [])
	var paint_mode: String = String(intent.get("paint_mode", "zone"))
	if paint_mode == "none":
		var zone_keys: Array = zones.keys()
		for zone_key: Variant in zone_keys:
			var zone: Dictionary = zones[zone_key]
			if String(zone.get("plot_id", "")) != plot_id or String(zone.get("floor", "")) != floor:
				continue
			var remaining_tiles: Array = []
			for tile: Variant in zone.get("tiles", []):
				if not _manual_door_cell_in_values(tile, cells):
					remaining_tiles.append(tile)
			zone["tiles"] = remaining_tiles
			zone["typologies"] = _manual_door_filter_typologies(zone.get("typologies", []), cells)
			if remaining_tiles.is_empty():
				zones.erase(zone_key)
		return candidate
	var source_ids: Array[String] = []
	for zone_key: Variant in zones.keys():
		var zone: Dictionary = zones[zone_key]
		if String(zone.get("plot_id", "")) != plot_id or String(zone.get("floor", "")) != floor or String(zone.get("type", "")) != String(intent.get("zone_type", "")):
			continue
		var selected: bool = false
		for tile: Variant in zone.get("tiles", []):
			if _manual_door_cell_in_values(tile, cells) or _manual_door_cell_adjacent_to_values(tile, cells):
				selected = true
				break
		if selected:
			source_ids.append(String(zone_key))
	source_ids.sort()
	var survivor_id: String = source_ids[0] if not source_ids.is_empty() else "preview/%s/%s" % [plot_id, floor]
	var merged: Dictionary = {
		"id": survivor_id,
		"plot_id": plot_id,
		"type": String(intent.get("zone_type", "")),
		"floor": floor,
		"tiles": [],
		"typologies": [],
	}
	if zones.has(survivor_id):
		merged = zones[survivor_id].duplicate(true)
	for source_id: String in source_ids:
		var source: Dictionary = zones[source_id]
		for tile: Variant in source.get("tiles", []):
			if not _manual_door_cell_in_values(tile, merged["tiles"]):
				merged["tiles"].append(tile.duplicate(true))
		for typology: Variant in source.get("typologies", []):
			_manual_door_set_serialized_typology(merged["typologies"], typology)
		zones.erase(source_id)
	for cell: Variant in cells:
		if cell is Array and cell.size() == 2 and not _manual_door_cell_in_values(cell, merged["tiles"]):
			merged["tiles"].append({"x": int(cell[0]), "y": int(cell[1])})
		_manual_door_set_serialized_typology(merged["typologies"], {"x": int(cell[0]), "y": int(cell[1]), "typology": _manual_door_intent_typology(intent.get("typologies", {}), cell)})
	zones[survivor_id] = merged
	return candidate


func _validate_manual_door_records_against_zone_candidate(
	records: Variant,
	candidate_state: Dictionary,
	floor_label: String = ""
) -> Dictionary:
	if not records is Array:
		return {"valid": false, "diagnostics": [{"code": "MANUAL_DOOR_EDGES_INVALID", "message": "manual door edges must be an array"}]}
	var obsolete_edges: Array[Dictionary] = []
	for record: Variant in records:
		if not record is Dictionary:
			return {"valid": false, "diagnostics": [{"code": "MANUAL_DOOR_EDGE_INVALID", "message": "manual door edge must be an object"}]}
		var endpoint_a: Dictionary = record.get("endpoint_a", {})
		var endpoint_b: Dictionary = record.get("endpoint_b", {})
		var cell_a: Dictionary = endpoint_a.get("local_cell", {})
		var cell_b: Dictionary = endpoint_b.get("local_cell", {})
		var from_address: Dictionary = {"runtime_plot_id": endpoint_a.get("runtime_plot_id", ""), "floor_id": floor_label, "elevation": int(endpoint_a.get("signed_elevation", 0)), "cell": [int(cell_a.get("x", -1)), int(cell_a.get("y", -1))]}
		var to_address: Dictionary = {"runtime_plot_id": endpoint_b.get("runtime_plot_id", ""), "floor_id": floor_label, "elevation": int(endpoint_b.get("signed_elevation", 0)), "cell": [int(cell_b.get("x", -1)), int(cell_b.get("y", -1))]}
		var from_view: Dictionary = get_manual_door_zone_view(from_address, candidate_state)
		var to_view: Dictionary = get_manual_door_zone_view(to_address, candidate_state)
		var from_zone_id: String = String(from_view.get("zone_id", ""))
		var to_zone_id: String = String(to_view.get("zone_id", ""))
		var reason: String = ""
		if not bool(from_view.get("resolved", false)) or not bool(to_view.get("resolved", false)):
			reason = "ZONE_ENDPOINT_VIEW_INVALID"
		elif from_zone_id.is_empty() and to_zone_id.is_empty():
			reason = "MANUAL_DOOR_CONNECTION_INVALID"
		elif not from_zone_id.is_empty() and from_zone_id == to_zone_id:
			obsolete_edges.append(record.duplicate(true))
		elif not from_zone_id.is_empty() and not to_zone_id.is_empty() and (int(from_view.get("typology", -1)) != ZoneData.TileTypology.TRANSIT or int(to_view.get("typology", -1)) != ZoneData.TileTypology.TRANSIT):
			reason = "INTER_ZONE_REQUIRES_TRANSIT"
		else:
			var zoned_view: Dictionary = from_view if not from_zone_id.is_empty() else to_view
			if int(zoned_view.get("typology", -1)) != ZoneData.TileTypology.TRANSIT:
				reason = "ZONE_TO_CIRCULATION_REQUIRES_TRANSIT"
		if not reason.is_empty():
			return {"valid": false, "diagnostics": [{"code": "EXISTING_DOOR_INVALIDATED", "message": "EXISTING_DOOR_INVALIDATED:MANUAL_DOOR:%s:%s" % [_manual_door_record_key(record), reason]}]}
	return {"valid": true, "obsolete_edges": obsolete_edges, "diagnostics": []}


func _build_district_effects(
	intent: Dictionary,
	spatial_snapshot: DistrictZoneSpatialSnapshot,
	door_validation: Dictionary
) -> Dictionary:
	var remove_cells: Array[Dictionary] = []
	var add_cells: Array[Dictionary] = []
	var paint_mode: String = String(intent.get("paint_mode", "zone"))
	var floor_label: String = String(intent.get("zone_floor_label", ""))
	var plot_id: String = String(intent.get("zone_plot_id", intent.get("runtime_plot_id", "")))
	for tile: Vector2i in _normalized_tiles(_to_vector2i_array(intent.get("cells", []))):
		var cell: Dictionary = {"x": tile.x, "y": tile.y}
		if paint_mode == "none":
			if get_zone_at_tile(tile, floor_label, plot_id) != null:
				add_cells.append(cell)
		elif spatial_snapshot.has_cell("explicit_circulation_cells", tile):
			remove_cells.append(cell)
	return {
		"remove_explicit_circulation_cells": remove_cells,
		"add_explicit_circulation_cells": add_cells,
		"remove_manual_door_edges": door_validation.get("obsolete_edges", []).duplicate(true),
	}


func _manual_door_record_key(record: Dictionary) -> String:
	var endpoint_a: Dictionary = record.get("endpoint_a", {})
	var endpoint_b: Dictionary = record.get("endpoint_b", {})
	return "%s|%s" % [_manual_door_endpoint_key(endpoint_a), _manual_door_endpoint_key(endpoint_b)]


func _manual_door_endpoint_key(endpoint: Dictionary) -> String:
	var cell: Dictionary = endpoint.get("local_cell", {})
	return "%s|%+011d|%011d|%011d" % [String(endpoint.get("runtime_plot_id", "")), int(endpoint.get("signed_elevation", 0)), int(cell.get("y", -1)), int(cell.get("x", -1))]


func _manual_door_cell_in_values(cell: Variant, values: Array) -> bool:
	var target: Array = cell if cell is Array else [int(cell.get("x", -1)), int(cell.get("y", -1))]
	for value: Variant in values:
		var candidate: Array = value if value is Array else [int(value.get("x", -1)), int(value.get("y", -1))]
		if candidate == target:
			return true
	return false


func _manual_door_cell_adjacent_to_values(cell: Variant, values: Array) -> bool:
	var target: Array = cell if cell is Array else [int(cell.get("x", -1)), int(cell.get("y", -1))]
	for value: Variant in values:
		var candidate: Array = value if value is Array else ([int(value.get("x", -1)), int(value.get("y", -1))] if value is Dictionary else [])
		if candidate.size() != 2:
			continue
		if absi(target[0] - int(candidate[0])) + absi(target[1] - int(candidate[1])) == 1:
			return true
	return false


func _manual_door_filter_typologies(values: Variant, cells: Array) -> Array:
	var result: Array = []
	for value: Variant in values:
		if not _manual_door_cell_in_values(value, cells):
			result.append(value.duplicate(true))
	return result


func _manual_door_set_serialized_typology(values: Array, typology: Variant) -> void:
	if not typology is Dictionary:
		return
	for value: Variant in values:
		if value is Dictionary and int(value.get("x", -1)) == int(typology.get("x", -1)) and int(value.get("y", -1)) == int(typology.get("y", -1)):
			value["typology"] = int(typology.get("typology", 0))
			return
	values.append(typology.duplicate(true))


func _manual_door_intent_typology(typologies: Variant, cell: Variant) -> int:
	if not typologies is Dictionary or not cell is Array:
		return 0
	var value: Variant = typologies.get(Vector2i(int(cell[0]), int(cell[1])), typologies.get("%d,%d" % [int(cell[0]), int(cell[1])], 0))
	return int(value)


func _validate_manual_door_zone_intent(intent: Dictionary, _district_candidate: Dictionary) -> Dictionary:
	var required: Array[String] = ["runtime_plot_id", "floor_id", "elevation", "from_cell", "to_cell"]
	for key: String in required:
		if not intent.has(key):
			return {"valid": false, "diagnostics": [{"code": "MANUAL_DOOR_FIELD_REQUIRED", "message": "manual door zone validation requires %s" % key}]}
	var plot_id: String = String(intent.get("runtime_plot_id", ""))
	var floor_id: String = String(intent.get("floor_id", ""))
	var elevation: int = int(intent.get("elevation", 0))
	var from_address: Dictionary = {"runtime_plot_id": plot_id, "floor_id": floor_id, "elevation": elevation, "cell": intent.get("from_cell", [])}
	var to_address: Dictionary = {"runtime_plot_id": plot_id, "floor_id": floor_id, "elevation": elevation, "cell": intent.get("to_cell", [])}
	var from_view: Dictionary = get_manual_door_zone_view(from_address)
	var to_view: Dictionary = get_manual_door_zone_view(to_address)
	if not bool(from_view.get("resolved", false)) or not bool(to_view.get("resolved", false)):
		return {"valid": false, "diagnostics": [{"code": "ZONE_ENDPOINT_VIEW_INVALID", "message": "manual door endpoint zone view is unresolved"}]}
	if not bool(intent.get("enabled", false)):
		return {"valid": true, "diagnostics": []}
	var from_zone_id: String = String(from_view.get("zone_id", ""))
	var to_zone_id: String = String(to_view.get("zone_id", ""))
	if from_zone_id.is_empty() and to_zone_id.is_empty():
		return {"valid": false, "diagnostics": [{"code": "MANUAL_DOOR_CONNECTION_INVALID", "message": "manual doors require a zone endpoint"}]}
	if not from_zone_id.is_empty() and from_zone_id == to_zone_id:
		return {"valid": false, "diagnostics": [{"code": "SAME_ZONE_FORBIDDEN", "message": "manual doors cannot connect two cells in the same zone"}]}
	if not from_zone_id.is_empty() and not to_zone_id.is_empty() and (int(from_view.get("typology", -1)) != 2 or int(to_view.get("typology", -1)) != 2):
		return {"valid": false, "diagnostics": [{"code": "INTER_ZONE_REQUIRES_TRANSIT", "message": "inter-zone manual doors require Transit at both endpoints"}]}
	var zoned_view: Dictionary = from_view if not from_zone_id.is_empty() else to_view
	if int(zoned_view.get("typology", -1)) != 2:
		return {"valid": false, "diagnostics": [{"code": "ZONE_TO_CIRCULATION_REQUIRES_TRANSIT", "message": "zone-to-circulation manual doors require Transit"}]}
	return {"valid": true, "diagnostics": []}


func prepare_district_candidate(
	intent: Dictionary,
	district_ref: Dictionary,
	spatial_snapshot: DistrictZoneSpatialSnapshot,
	public_band_access: PublicBandAccessSnapshot = null,
	zone_plan: Dictionary = {}
) -> Dictionary:
	if zone_plan.is_empty() or not bool(zone_plan.get("accepted", false)):
		return {"accepted": false, "diagnostics": [{"code": "ZONE_PLAN_REQUIRED", "message": "District must provide the accepted Zone preview plan"}]}
	var spatial_validation: Dictionary = _validate_spatial_snapshot_input(intent, district_ref, spatial_snapshot)
	if not bool(spatial_validation.get("valid", false)):
		return {"accepted": false, "diagnostics": spatial_validation.get("diagnostics", [])}
	var public_access_validation: Dictionary = _validate_public_band_access_input(district_ref, public_band_access)
	if not bool(public_access_validation.get("valid", false)):
		return {"accepted": false, "diagnostics": public_access_validation.get("diagnostics", [])}
	var zone_candidate: Dictionary = zone_plan.get("manual_door_zone_candidate", _build_manual_door_zone_candidate(intent)).duplicate(true)
	if String(intent.get("operation", "")) == DistrictRuntime.OP_PAINT_ZONE:
		var planned_preview: SplitResult = zone_plan.get("preview") as SplitResult
		if planned_preview == null or not planned_preview.is_success():
			return {"accepted": false, "diagnostics": [{"code": "ZONE_PLAN_INVALID", "message": "prepared Zone paint requires the successful preview result"}]}
	var door_validation: Dictionary = _validate_manual_door_records_against_zone_candidate(spatial_snapshot.get_manual_door_edges(), zone_candidate, String(intent.get("zone_floor_label", "")))
	if not bool(door_validation.get("valid", false)):
		return {"accepted": false, "diagnostics": door_validation.get("diagnostics", [])}
	return {
		"accepted": true,
		"prepare_token": {
			"intent": intent.duplicate(true),
			"district_ref": district_ref.duplicate(true),
			"zone_plan": zone_plan.duplicate(true),
			"manual_door_edges": spatial_snapshot.get_manual_door_edges(),
			"manual_door_zone_candidate": zone_candidate,
			"prior_zone_state": serialize(),
			"zone_revision": authority_revision,
			"spatial_snapshot": spatial_snapshot.duplicate_snapshot(),
			"public_band_access": public_band_access.duplicate_snapshot() if public_band_access != null else null,
			"mutated": false,
		},
		"diagnostics": [],
	}


## Commit a prepared district coordination token. H3 district operations do not write zones.
func commit_district_candidate(prepare_result: Dictionary) -> Dictionary:
	var prepare_token: Dictionary = prepare_result.get("prepare_token", prepare_result)
	if prepare_token.is_empty() or int(prepare_token.get("zone_revision", -1)) != authority_revision:
		return {"accepted": false, "diagnostics": [{"code": "STALE_ZONE_REVISION", "message": "zone authority changed before coordinated commit"}]}
	var intent: Dictionary = prepare_token.get("intent", {})
	var district_ref: Dictionary = prepare_token.get("district_ref", {})
	var spatial_snapshot: DistrictZoneSpatialSnapshot = prepare_token.get("spatial_snapshot") as DistrictZoneSpatialSnapshot
	var spatial_validation: Dictionary = _validate_spatial_snapshot_input(intent, district_ref, spatial_snapshot)
	if not bool(spatial_validation.get("valid", false)):
		return {"accepted": false, "diagnostics": spatial_validation.get("diagnostics", [])}
	var public_band_access: PublicBandAccessSnapshot = prepare_token.get("public_band_access") as PublicBandAccessSnapshot
	var public_access_validation: Dictionary = _validate_public_band_access_input(district_ref, public_band_access)
	if not bool(public_access_validation.get("valid", false)):
		return {"accepted": false, "diagnostics": public_access_validation.get("diagnostics", [])}
	if String(intent.get("operation", "")) != DistrictRuntime.OP_PAINT_ZONE:
		return {"accepted": true, "door_access_edges": _build_public_band_traversal_edges(public_band_access), "diagnostics": []}
	var door_validation: Dictionary = _validate_manual_door_records_against_zone_candidate(prepare_token.get("manual_door_edges", []), prepare_token.get("manual_door_zone_candidate", {}), String(intent.get("zone_floor_label", "")))
	if not bool(door_validation.get("valid", false)):
		return {"accepted": false, "diagnostics": door_validation.get("diagnostics", [])}
	_district_notifications_deferred = true
	var committed: ZoneData = paint_zone(
		String(intent.get("zone_type", "")),
		_to_vector2i_array(intent.get("cells", [])),
		String(intent.get("zone_floor_label", "")),
		String(intent.get("zone_plot_id", "")),
		intent.get("typologies", {}),
		String(intent.get("paint_mode", "zone")),
		spatial_snapshot,
		public_band_access
	)
	if committed == null and not (String(intent.get("paint_mode", "zone")) == "none" and last_split_result != null and last_split_result.is_success()):
		_district_notifications_deferred = false
		_deferred_district_notifications.clear()
		return {"accepted": false, "diagnostics": [{"code": "ZONE_PAINT_COMMIT_FAILED", "message": "ZoneManager could not commit the prepared paint candidate"}]}
	prepare_token["mutated"] = true
	return {"accepted": true, "door_access_edges": _build_public_band_traversal_edges(public_band_access), "diagnostics": []}


## Restore a prior zone reference if a pre-append failure occurs.
func undo_district_candidate(prepare_result: Dictionary) -> Dictionary:
	var prepare_token: Dictionary = prepare_result.get("prepare_token", prepare_result)
	if prepare_token.is_empty() or not bool(prepare_token.get("mutated", false)):
		return {"accepted": true, "diagnostics": []}
	var prior: Variant = prepare_token.get("prior_zone_state", {})
	if prior is Dictionary:
		_restore_zone_projection(prior, int(prepare_token.get("zone_revision", authority_revision)))
	_district_notifications_deferred = false
	_deferred_district_notifications.clear()
	return {"accepted": true, "diagnostics": []}


# ── Assignment Mode ───────────────────────────────────────────────────


## Whether the active assignment mode permits the normal tenant lifecycle.
func permits_tenant_lifecycle() -> bool:
	return assignment_mode != AssignmentMode.DEBUG_IMMEDIATE


func flush_district_notifications() -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	var notifications: Array[Dictionary] = _deferred_district_notifications.duplicate(true)
	_deferred_district_notifications.clear()
	_district_notifications_deferred = false
	for notification: Dictionary in notifications:
		var event_bus: Node = get_node_or_null("/root/EventBus")
		if event_bus == null:
			continue
		var signal_name: String = String(notification.get("signal", ""))
		var arguments: Array = notification.get("arguments", [])
		if signal_name.is_empty():
			diagnostics.append({"code": "ZONE_NOTIFICATION_INVALID", "message": "deferred zone notification has no signal name"})
			continue
		_emit_zone_event_now(event_bus, signal_name, arguments)
	return diagnostics


func _emit_zone_event(signal_name: String, arguments: Array) -> void:
	if _district_notifications_deferred:
		_deferred_district_notifications.append({"signal": signal_name, "arguments": arguments.duplicate(true)})
		return
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		_emit_zone_event_now(event_bus, signal_name, arguments)


func _emit_zone_event_now(event_bus: Node, signal_name: String, arguments: Array) -> void:
	match signal_name:
		"zone_created":
			if arguments.size() == 3:
				event_bus.emit_signal("zone_created", String(arguments[0]), String(arguments[1]), int(arguments[2]))
		"zone_modified", "zone_deleted":
			if arguments.size() == 1:
				event_bus.emit_signal(signal_name, String(arguments[0]))


func _to_vector2i_array(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		if value is Vector2i:
			result.append(value)
		elif value is Array and value.size() == 2:
			result.append(Vector2i(int(value[0]), int(value[1])))
	return result


func _restore_zone_projection(prior: Dictionary, revision: int) -> void:
	deserialize(prior)
	authority_revision = revision


# ── Zone CRUD ──────────────────────────────────────────────────────────


## Create, split, and atomically commit a new zone. Returns null on rejection.
func create_zone(
	zone_type: String,
	tiles: Array[Vector2i],
	floor: String,
	plot_id: String,
	typologies: Dictionary = {},
	spatial_snapshot: DistrictZoneSpatialSnapshot = null,
	public_band_access: PublicBandAccessSnapshot = null
) -> ZoneData:
	var counter_snapshot := _counter_snapshot()
	var candidate := ZoneData.new()
	candidate.id = _generate_zone_id()
	candidate.parcel_layout_seed = _generate_parcel_layout_seed(candidate.id)
	candidate.plot_id = plot_id
	candidate.type = zone_type
	candidate.floor = floor
	candidate.tiles = _normalized_tiles(tiles)
	candidate.typologies = _normalize_typologies(candidate.tiles, typologies)
	candidate.zone_name = zone_type

	if not _validate_candidate_tiles(candidate, "", spatial_snapshot):
		_restore_counters(counter_snapshot)
		return null
	var transaction := _prepare_access_transaction(candidate, null, spatial_snapshot, public_band_access)
	if transaction.is_empty():
		_restore_counters(counter_snapshot)
		return null
	candidate = transaction[0]
	zones[candidate.id] = candidate
	for committed_zone: ZoneData in transaction:
		if committed_zone != candidate:
			var existing: ZoneData = zones.get(committed_zone.id, null)
			if existing != null:
				_copy_zone_state(committed_zone, existing)
				committed_zone = existing
	authority_revision += 1
	_emit_zone_event("zone_created", [candidate.id, candidate.type, candidate.tiles.size()])
	for committed_zone: ZoneData in transaction:
		if committed_zone != candidate:
			_emit_zone_event("zone_modified", [committed_zone.id])
	return candidate


## Apply one atomic paint-first zone mutation. Type paint creates, extends, or merges
## same-type zones; None removes committed membership back to circulation.
func paint_zone(
	zone_type: String,
	tiles: Array[Vector2i],
	floor: String,
	plot_id: String,
	typologies: Dictionary = {},
	paint_mode: String = "zone",
	spatial_snapshot: DistrictZoneSpatialSnapshot = null,
	public_band_access: PublicBandAccessSnapshot = null
) -> ZoneData:
	var normalized_tiles := _normalized_tiles(tiles)
	if paint_mode == "none":
		return _remove_painted_tiles(normalized_tiles, floor, plot_id, spatial_snapshot, public_band_access)
	if zone_type.is_empty() or normalized_tiles.is_empty():
		last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "EMPTY_PAINT_STROKE")
		return null
	if spatial_snapshot == null:
		last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "DISTRICT_ZONE_SPATIAL_UNAVAILABLE")
		return null
	var source_zones: Array[ZoneData] = []
	var source_ids: Dictionary = {}
	for tile_pos: Vector2i in normalized_tiles:
		if not spatial_snapshot.has_cell("zone_eligible_cells", tile_pos):
			last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "INVALID_OR_UNOWNED_TILE")
			return null
		var source: ZoneData = get_zone_at_tile(tile_pos, floor, plot_id)
		if source != null:
			if source.type != zone_type:
				last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "ZONE_TYPE_CONFLICT")
				return null
			if not source_ids.has(source.id):
				source_ids[source.id] = true
				source_zones.append(source)
	for tile_pos: Vector2i in normalized_tiles:
		for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			var adjacent_source: ZoneData = get_zone_at_tile(tile_pos + direction, floor, plot_id)
			if adjacent_source != null and adjacent_source.type == zone_type and not source_ids.has(adjacent_source.id):
				source_ids[adjacent_source.id] = true
				source_zones.append(adjacent_source)
	source_zones.sort_custom(func(first: ZoneData, second: ZoneData) -> bool: return first.id < second.id)
	if source_zones.is_empty():
		return create_zone(zone_type, normalized_tiles, floor, plot_id, typologies, spatial_snapshot, public_band_access)

	var survivor: ZoneData = source_zones[0]
	var candidate := _copy_zone(survivor)
	var candidate_tiles: Dictionary = {}
	for source: ZoneData in source_zones:
		for source_tile: Vector2i in source.tiles:
			candidate_tiles[source_tile] = true
	for tile_pos: Vector2i in normalized_tiles:
		candidate_tiles[tile_pos] = true
	candidate.tiles = _normalized_tiles(_dictionary_tiles(candidate_tiles))
	var merged_typologies: Dictionary = {}
	for source: ZoneData in source_zones:
		for source_tile: Vector2i in source.tiles:
			merged_typologies[source_tile] = source.typologies.get(source_tile, ZoneData.TileTypology.TENANT)
	for tile_pos: Vector2i in normalized_tiles:
		merged_typologies[tile_pos] = typologies.get(tile_pos, ZoneData.TileTypology.TENANT)
	candidate.typologies = _normalize_typologies(candidate.tiles, merged_typologies)
	if not _is_connected_tiles(candidate.tiles):
		last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "DISCONNECTED_ZONE")
		return null
	if not _prepare_preserving_addition(candidate, source_zones, spatial_snapshot, public_band_access):
		return null

	var counter_snapshot := _counter_snapshot()
	for source: ZoneData in source_zones:
		if source.id != survivor.id:
			zones.erase(source.id)
	_copy_zone_state(candidate, survivor)
	authority_revision += 1
	_emit_zone_event("zone_modified", [survivor.id])
	for source: ZoneData in source_zones:
		if source.id != survivor.id:
			_emit_zone_event("zone_deleted", [source.id])
	_restore_counters(counter_snapshot)
	return survivor


## Remove committed zone membership atomically while preserving unaffected parcels.
func _remove_painted_tiles(
	tiles: Array[Vector2i],
	floor: String,
	plot_id: String,
	spatial_snapshot: DistrictZoneSpatialSnapshot,
	public_band_access: PublicBandAccessSnapshot = null
) -> ZoneData:
	var affected: Dictionary = {}
	if spatial_snapshot == null:
		last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "DISTRICT_ZONE_SPATIAL_UNAVAILABLE")
		return null
	for tile_pos: Vector2i in tiles:
		var zone: ZoneData = get_zone_at_tile(tile_pos, floor, plot_id)
		if zone != null:
			affected[zone.id] = zone
	if affected.is_empty():
		last_split_result = SplitResult.success([], [], [])
		return null
	var candidates: Array[ZoneData] = []
	for zone_id: String in affected:
		var source: ZoneData = affected[zone_id]
		var candidate := _copy_zone(source)
		var remaining: Array[Vector2i] = []
		for source_tile: Vector2i in source.tiles:
			if not tiles.has(source_tile):
				remaining.append(source_tile)
		if remaining.is_empty():
			continue
		if not _is_connected_tiles(remaining):
			last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "DISCONNECTED_ZONE")
			return null
		candidate.tiles = _normalized_tiles(remaining)
		candidate.typologies = _normalize_typologies(candidate.tiles, source.typologies)
		if not _prepare_removal_candidate(candidate, source, spatial_snapshot, public_band_access):
			return null
		candidates.append(candidate)

	last_split_result = SplitResult.success([], [], [])
	for zone_id: String in affected:
		var source: ZoneData = affected[zone_id]
		if not zones.has(zone_id):
			continue
		var candidate: ZoneData = null
		for planned: ZoneData in candidates:
			if planned.id == zone_id:
				candidate = planned
				break
		if candidate == null:
			zones.erase(zone_id)
			_emit_zone_event("zone_deleted", [zone_id])
		else:
			_copy_zone_state(candidate, source)
			_emit_zone_event("zone_modified", [zone_id])
	authority_revision += 1
	return candidates[0] if not candidates.is_empty() else null


func _prepare_preserving_addition(
	candidate: ZoneData,
	sources: Array[ZoneData],
	spatial_snapshot: DistrictZoneSpatialSnapshot,
	public_band_access: PublicBandAccessSnapshot = null
) -> bool:
	if spatial_snapshot == null:
		return false
	var old_tiles: Dictionary = {}
	var old_parcels: Array[Parcel] = []
	for source: ZoneData in sources:
		for tile_pos: Vector2i in source.tiles:
			old_tiles[tile_pos] = true
		for parcel: Parcel in source.parcels:
			old_parcels.append(parcel)
	var new_tenant_tiles: Array[Vector2i] = []
	for tile_pos: Vector2i in candidate.tiles:
		if not old_tiles.has(tile_pos) and candidate.typologies.get(tile_pos, ZoneData.TileTypology.TENANT) == ZoneData.TileTypology.TENANT:
			new_tenant_tiles.append(tile_pos)
	var overlay: Dictionary = {}
	for tile_pos: Vector2i in candidate.tiles:
		overlay[tile_pos] = candidate.id
	var context := _build_access_context(spatial_snapshot, candidate, sources, public_band_access)
	var planned: Array[Parcel] = []
	for parcel: Parcel in old_parcels:
		var preserved := _copy_parcel(parcel)
		var prospective_edges := _physical_door_candidates_for_parcel(
			preserved, candidate, context, overlay
		)
		if not parcel.selected_door_edges.is_empty():
			var preserved_edges: Array[Dictionary] = []
			for old_edge: Dictionary in parcel.selected_door_edges:
				var legal_edge: Dictionary = {}
				for candidate_edge: Dictionary in prospective_edges:
					if _same_door_geometry(old_edge, candidate_edge):
						legal_edge = candidate_edge
						break
				if legal_edge.is_empty():
					last_split_result = SplitResult.failure(SplitResult.Status.EXISTING_DOOR_INVALIDATED, "EXISTING_DOOR_INVALIDATED:%s" % parcel.id)
					return false
				preserved_edges.append(legal_edge.duplicate())
			preserved.selected_door_edges = preserved_edges
		preserved.frontage_edges = prospective_edges
		planned.append(preserved)
	if not new_tenant_tiles.is_empty():
		var new_zone := ZoneData.new()
		new_zone.id = candidate.id
		new_zone.plot_id = candidate.plot_id
		new_zone.floor = candidate.floor
		new_zone.type = candidate.type
		new_zone.parcel_layout_seed = candidate.parcel_layout_seed
		new_zone.tiles = _normalized_tiles(new_tenant_tiles)
		new_zone.typologies = _normalize_typologies(new_zone.tiles, candidate.typologies)
		var new_result := ZoneSplitter.split(new_zone, context)
		if not new_result.is_success():
			last_split_result = new_result
			return false
		_assign_persistent_ids(new_result.parcels, old_parcels)
		if not _assign_selected_door_edges(new_result.parcels, []):
			return false
		_assign_debug_subtypes_for_parcels(new_result.parcels, candidate.type, planned)
		planned.append_array(new_result.parcels)
	else:
		last_split_result = SplitResult.success(planned, [], [])
	if not _all_parcels_have_physical_door_frontage_context(planned, candidate, context, overlay):
		last_split_result = SplitResult.failure(SplitResult.Status.NO_PHYSICAL_DOOR_FRONTAGE, "NO_PHYSICAL_DOOR_FRONTAGE")
		return false
	candidate.parcels = planned
	last_split_result = SplitResult.success(planned, [], [])
	return true


func _prepare_removal_candidate(
	candidate: ZoneData,
	source: ZoneData,
	spatial_snapshot: DistrictZoneSpatialSnapshot,
	public_band_access: PublicBandAccessSnapshot = null
) -> bool:
	if spatial_snapshot == null:
		return false
	var context := _build_access_context(spatial_snapshot, candidate, [source], public_band_access)
	var result := ZoneSplitter.split(candidate, context)
	if not result.is_success():
		last_split_result = result
		return false
	_assign_persistent_ids(result.parcels, source.parcels)
	if not _assign_selected_door_edges(result.parcels, []):
		return false
	var old_parcels_by_id: Dictionary = {}
	for old_parcel: Parcel in source.parcels:
		old_parcels_by_id[old_parcel.id] = old_parcel
	var removed_tiles: Dictionary = {}
	for source_tile: Vector2i in source.tiles:
		if not candidate.tiles.has(source_tile):
			removed_tiles[source_tile] = true
	for parcel: Parcel in result.parcels:
		var old_parcel: Parcel = old_parcels_by_id.get(parcel.id, null)
		var parcel_is_locked := old_parcel != null
		if parcel_is_locked:
			for parcel_tile: Vector2i in old_parcel.tiles:
				if removed_tiles.has(parcel_tile):
					parcel_is_locked = false
					break
		if parcel_is_locked:
			parcel.selected_door_edges = old_parcel.selected_door_edges.duplicate(true)
			parcel.assigned_subtype_id = old_parcel.assigned_subtype_id
			parcel.has_tenant = old_parcel.has_tenant
			parcel.tenant_id = old_parcel.tenant_id
	_assign_debug_subtypes_for_parcels(result.parcels, candidate.type, [])
	candidate.parcels = result.parcels
	last_split_result = result
	return true


func _assign_debug_subtypes_for_parcels(parcels: Array[Parcel], zone_type: String, locked: Array[Parcel]) -> void:
	if assignment_mode != AssignmentMode.DEBUG_IMMEDIATE:
		return
	var all_parcels: Array[Parcel] = locked.duplicate()
	all_parcels.append_array(parcels)
	var fixed_assignments: Dictionary = {}
	for parcel: Parcel in locked:
		if not parcel.assigned_subtype_id.is_empty():
			fixed_assignments[parcel.id] = parcel.assigned_subtype_id
	var snapshot := DebugBusinessSubtypeCatalog.snapshot_for_zone_type(zone_type)
	var result := ZoneBusinessAssigner.assign(all_parcels, zone_type, snapshot, fixed_assignments)
	for parcel: Parcel in parcels:
		if not parcel.assigned_subtype_id.is_empty():
			continue
		parcel.assigned_subtype_id = result.subtype_for(parcel.id)
	last_assignment_result = result


func _copy_parcel(source: Parcel) -> Parcel:
	var copy := Parcel.new()
	copy.id = source.id
	copy.display_number = source.display_number
	copy.set_core_geometry(source.core_tiles)
	copy.set_geometry(source.tiles, source.frontage_edges)
	copy.selected_door_edges = source.selected_door_edges.duplicate(true)
	copy.assigned_subtype_id = source.assigned_subtype_id
	copy.has_tenant = source.has_tenant
	copy.tenant_id = source.tenant_id
	return copy


func _physical_door_candidates_for_parcel(
	parcel: Parcel, zone: ZoneData, context: FloorAccessContext, overlay: Dictionary
) -> Array[Dictionary]:
	var zone_tiles: Dictionary = {}
	for tile_pos: Vector2i in zone.tiles:
		zone_tiles[tile_pos] = true
	var edges := ZoneSplitter._frontage_edges(parcel.tiles, zone_tiles, zone, context)
	var physical: Array[Dictionary] = []
	for edge: Dictionary in edges:
		if PHYSICAL_DOOR_ACCESS_KINDS.has(edge.get("access_kind", "")):
			physical.append(edge)
	physical.sort_custom(_compare_door_edges)
	return physical


func _all_parcels_have_physical_door_frontage_context(
	parcels: Array[Parcel], zone: ZoneData, context: FloorAccessContext, overlay: Dictionary
) -> bool:
	for parcel: Parcel in parcels:
		if _physical_door_candidates_for_parcel(parcel, zone, context, overlay).is_empty():
			return false
	return true


func _serialize_tiles(p_tiles: Array[Vector2i]) -> Array[Dictionary]:
	var serialized_tiles: Array[Dictionary] = []
	for tile: Vector2i in p_tiles:
		serialized_tiles.append({"x": tile.x, "y": tile.y})
	return serialized_tiles


func _dictionary_tiles(tile_set: Dictionary) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for tile_pos: Vector2i in tile_set:
		tiles.append(tile_pos)
	return tiles


static func _is_connected_tiles(tiles: Array[Vector2i]) -> bool:
	if tiles.is_empty():
		return false
	var remaining: Dictionary = {}
	for tile_pos: Vector2i in tiles:
		remaining[tile_pos] = true
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [tiles[0]]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if visited.has(current):
			continue
		visited[current] = true
		for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbor := current + direction
			if remaining.has(neighbor) and not visited.has(neighbor):
				queue.append(neighbor)
	return visited.size() == remaining.size()


## Modify, fully re-split, and atomically commit a zone. Returns null on rejection.
func modify_zone(
	zone_id: String,
	new_tiles: Array[Vector2i],
	plot_id: String,
	typologies: Dictionary = {},
	spatial_snapshot: DistrictZoneSpatialSnapshot = null
) -> ZoneData:
	var counter_snapshot := _counter_snapshot()
	var zone: ZoneData = zones.get(zone_id, null)
	if zone == null:
		push_error("ZoneManager.modify_zone(): zone '%s' not found." % zone_id)
		return null
	if zone.plot_id != plot_id:
		last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "PLOT_MISMATCH")
		return null

	var candidate := _copy_zone(zone)
	candidate.tiles = _normalized_tiles(new_tiles)
	candidate.typologies = _normalize_typologies(
		candidate.tiles, typologies if not typologies.is_empty() else zone.typologies
	)
	if not _validate_candidate_tiles(candidate, zone.id, spatial_snapshot):
		_restore_counters(counter_snapshot)
		return null
	var transaction := _prepare_access_transaction(candidate, zone, spatial_snapshot)
	if transaction.is_empty():
		_restore_counters(counter_snapshot)
		return null
	candidate = transaction[0]
	_copy_zone_state(candidate, zone)
	for committed_zone: ZoneData in transaction:
		if committed_zone != candidate:
			var existing: ZoneData = zones.get(committed_zone.id, null)
			if existing != null:
				_copy_zone_state(committed_zone, existing)
	authority_revision += 1
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.emit_signal("zone_modified", zone_id)
	for committed_zone: ZoneData in transaction:
		if committed_zone != candidate:
			var modified_event_bus: Node = get_node_or_null("/root/EventBus")
			if modified_event_bus != null:
				modified_event_bus.emit_signal("zone_modified", committed_zone.id)
	return zone


## Recalculate an existing zone with its current geometry and typologies.
func split_zone(zone_id: String) -> SplitResult:
	var zone: ZoneData = zones.get(zone_id, null)
	if zone == null:
		last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "ZONE_NOT_FOUND")
		return last_split_result
	var result_zone := modify_zone(zone_id, zone.tiles, zone.plot_id, zone.typologies)
	if result_zone == null:
		return last_split_result
	return last_split_result


## Validate pending ZoneTool data without mutating zones, grid state, counters, or events.
func preview_split(
	zone_type: String,
	tiles: Array[Vector2i],
	floor: String,
	plot_id: String,
	typologies: Dictionary = {},
	preview_zone_id: String = "",
	spatial_snapshot: DistrictZoneSpatialSnapshot = null
) -> SplitResult:
	if spatial_snapshot == null:
		return SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "DISTRICT_ZONE_SPATIAL_UNAVAILABLE")
	var preview_zone := ZoneData.new()
	var replaced_zone: ZoneData = zones.get(preview_zone_id, null)
	if replaced_zone != null:
		preview_zone.id = replaced_zone.id
		preview_zone.parcel_layout_seed = replaced_zone.parcel_layout_seed
	else:
		# Match the ID and deterministic growth seed that the next create commit
		# will allocate without advancing any persistent counters.
		preview_zone.id = "zone_%d" % (_zone_counter + 1)
		preview_zone.parcel_layout_seed = _generate_parcel_layout_seed(preview_zone.id)
	preview_zone.plot_id = plot_id
	preview_zone.type = zone_type
	preview_zone.floor = floor
	preview_zone.tiles = _normalized_tiles(tiles)
	preview_zone.typologies = _normalize_typologies(preview_zone.tiles, typologies)
	return _preview_access_transaction(preview_zone, replaced_zone, spatial_snapshot)


## Preview one paint-first mutation without changing committed state or counters.
func preview_paint(
	zone_type: String,
	tiles: Array[Vector2i],
	floor: String,
	plot_id: String,
	typologies: Dictionary = {},
	paint_mode: String = "zone",
	spatial_snapshot: DistrictZoneSpatialSnapshot = null,
	public_band_access: PublicBandAccessSnapshot = null
) -> SplitResult:
	var normalized_tiles := _normalized_tiles(tiles)
	if paint_mode == "none":
		return _preview_remove_painted_tiles(normalized_tiles, floor, plot_id, spatial_snapshot, public_band_access)
	if spatial_snapshot == null:
		return SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "DISTRICT_ZONE_SPATIAL_UNAVAILABLE")
	var source_zones: Array[ZoneData] = []
	var source_ids: Dictionary = {}
	for tile_pos: Vector2i in normalized_tiles:
		if not spatial_snapshot.has_cell("zone_eligible_cells", tile_pos):
			return SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "INVALID_OR_UNOWNED_ZONE_TILE")
		var source: ZoneData = get_zone_at_tile(tile_pos, floor, plot_id)
		if source != null:
			if source.type != zone_type:
				return SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "ZONE_TYPE_CONFLICT")
			if not source_ids.has(source.id):
				source_ids[source.id] = true
				source_zones.append(source)
	for tile_pos: Vector2i in normalized_tiles:
		for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			var adjacent_source: ZoneData = get_zone_at_tile(tile_pos + direction, floor, plot_id)
			if adjacent_source != null and adjacent_source.type == zone_type and not source_ids.has(adjacent_source.id):
				source_ids[adjacent_source.id] = true
				source_zones.append(adjacent_source)
	source_zones.sort_custom(func(first: ZoneData, second: ZoneData) -> bool: return first.id < second.id)
	if source_zones.is_empty():
		var preview_zone := ZoneData.new()
		preview_zone.id = "zone_%d" % (_zone_counter + 1)
		preview_zone.parcel_layout_seed = _generate_parcel_layout_seed(preview_zone.id)
		preview_zone.plot_id = plot_id
		preview_zone.floor = floor
		preview_zone.type = zone_type
		preview_zone.tiles = normalized_tiles
		preview_zone.typologies = _normalize_typologies(normalized_tiles, typologies)
		return _preview_access_transaction(preview_zone, null, spatial_snapshot, public_band_access)
	source_zones.sort_custom(func(first: ZoneData, second: ZoneData) -> bool: return first.id < second.id)
	var candidate := _copy_zone(source_zones[0])
	var all_tiles: Dictionary = {}
	var merged_typologies: Dictionary = {}
	for source: ZoneData in source_zones:
		for source_tile: Vector2i in source.tiles:
			all_tiles[source_tile] = true
			merged_typologies[source_tile] = source.typologies.get(source_tile, ZoneData.TileTypology.TENANT)
	for tile_pos: Vector2i in normalized_tiles:
		all_tiles[tile_pos] = true
		merged_typologies[tile_pos] = typologies.get(tile_pos, ZoneData.TileTypology.TENANT)
	candidate.tiles = _normalized_tiles(_dictionary_tiles(all_tiles))
	candidate.typologies = _normalize_typologies(candidate.tiles, merged_typologies)
	if not _is_connected_tiles(candidate.tiles):
		return SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "DISCONNECTED_ZONE")
	var counter_snapshot := _counter_snapshot()
	var valid := _prepare_preserving_addition(candidate, source_zones, spatial_snapshot, public_band_access)
	var preview_result := last_split_result
	_restore_counters(counter_snapshot)
	if not valid:
		return preview_result
	return preview_result


func _preview_remove_painted_tiles(
	tiles: Array[Vector2i],
	floor: String,
	plot_id: String,
	spatial_snapshot: DistrictZoneSpatialSnapshot,
	public_band_access: PublicBandAccessSnapshot = null
) -> SplitResult:
	if spatial_snapshot == null:
		return SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "DISTRICT_ZONE_SPATIAL_UNAVAILABLE")
	var affected: Dictionary = {}
	for tile_pos: Vector2i in tiles:
		var zone: ZoneData = get_zone_at_tile(tile_pos, floor, plot_id)
		if zone != null:
			affected[zone.id] = zone
	if affected.is_empty():
		return SplitResult.success([], [], [])
	var counter_snapshot := _counter_snapshot()
	var combined_parcels: Array[Parcel] = []
	for zone_id: String in affected:
		var source: ZoneData = affected[zone_id]
		var remaining: Array[Vector2i] = []
		for source_tile: Vector2i in source.tiles:
			if not tiles.has(source_tile):
				remaining.append(source_tile)
		if remaining.is_empty():
			continue
		if not _is_connected_tiles(remaining):
			_restore_counters(counter_snapshot)
			return SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "DISCONNECTED_ZONE")
		var candidate := _copy_zone(source)
		candidate.tiles = _normalized_tiles(remaining)
		candidate.typologies = _normalize_typologies(candidate.tiles, source.typologies)
		if not _prepare_removal_candidate(candidate, source, spatial_snapshot, public_band_access):
			var failed_result := last_split_result
			_restore_counters(counter_snapshot)
			return failed_result
		combined_parcels.append_array(candidate.parcels)
	var result := SplitResult.success(combined_parcels, [], [])
	_restore_counters(counter_snapshot)
	return result


## Plan the same pure split and physical-door validation transaction as commit
## without assigning IDs, mutating counters, grid state, or existing zones.
func _preview_access_transaction(
	candidate: ZoneData,
	replaced_zone: ZoneData,
	spatial_snapshot: DistrictZoneSpatialSnapshot,
	public_band_access: PublicBandAccessSnapshot = null
) -> SplitResult:
	if spatial_snapshot == null:
		return SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "DISTRICT_ZONE_SPATIAL_UNAVAILABLE")
	var replaced: Array[ZoneData] = []
	if replaced_zone != null:
		replaced.append(replaced_zone)
	var context := _build_access_context(spatial_snapshot, candidate, replaced, public_band_access)
	var result := ZoneSplitter.split(candidate, context)
	if not result.is_success():
		return result
	if replaced_zone != null:
		_match_preview_parcels(result.parcels, replaced_zone.parcels)
		var invalidated_door := _prior_door_invalidation_diagnostic(
			candidate.id, result.parcels, replaced_zone.parcels
		)
		if not invalidated_door.is_empty():
			return _existing_door_failure(result.parcels, invalidated_door)
	if not _all_parcels_have_physical_door_frontage(result.parcels):
		return _physical_door_failure(result.parcels, "NO_PHYSICAL_DOOR_FRONTAGE")

	var prospective_zones: Array[ZoneData] = [_zone_with_split_residuals(candidate, result)]
	for affected_zone: ZoneData in _affected_zones(candidate, replaced_zone):
		var affected_result := ZoneSplitter.split(affected_zone, context)
		if not affected_result.is_success():
			return affected_result
		_match_preview_parcels(affected_result.parcels, affected_zone.parcels)
		var affected_invalidated_door := _prior_door_invalidation_diagnostic(
			affected_zone.id, affected_result.parcels, affected_zone.parcels
		)
		if not affected_invalidated_door.is_empty():
			return _existing_door_failure(affected_result.parcels, affected_invalidated_door)
		if not _all_parcels_have_physical_door_frontage(affected_result.parcels):
			return _physical_door_failure(
				affected_result.parcels,
				"AFFECTED_ZONE_NO_PHYSICAL_DOOR_FRONTAGE:%s" % affected_zone.id
			)
		prospective_zones.append(_zone_with_split_residuals(affected_zone, affected_result))
	var manual_door_diagnostic := _manual_door_invalidation_diagnostic(
		candidate, replaced_zone, prospective_zones, context
	)
	if not manual_door_diagnostic.is_empty():
		return _existing_door_failure(result.parcels, manual_door_diagnostic)
	return result


func _physical_door_failure(parcels: Array[Parcel], diagnostic: String) -> SplitResult:
	var failure := SplitResult.failure(SplitResult.Status.NO_PHYSICAL_DOOR_FRONTAGE, diagnostic)
	failure.parcels = parcels
	return failure


func _existing_door_failure(parcels: Array[Parcel], diagnostic: String) -> SplitResult:
	var failure := SplitResult.failure(SplitResult.Status.EXISTING_DOOR_INVALIDATED, diagnostic)
	failure.parcels = parcels
	return failure


## Delete a zone using the project's existing floor-demolition behavior.
func delete_zone(zone_id: String, plot_id: String = "") -> void:
	var zone: ZoneData = zones.get(zone_id, null)
	if zone == null:
		return
	if not plot_id.is_empty() and plot_id != zone.plot_id:
		push_error("ZoneManager.delete_zone(): plot mismatch for zone '%s'." % zone_id)
		return

	zones.erase(zone_id)
	authority_revision += 1
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.emit_signal("zone_deleted", zone_id)


# ── Zone Queries ───────────────────────────────────────────────────────


## Get the zone containing a specific tile position.
## Return only ZoneManager-owned endpoint semantics for a detached address.
## This view contains no retired grid authority, GridTile, FloorGrid, or world data.
func get_manual_door_zone_view(address: Dictionary, candidate_state: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"resolved": true,
		"zone_id": "",
		"typology": -1,
		"in_mutation_scope": false,
		"zone_revision": get_district_revision(),
	}
	if typeof(address.get("runtime_plot_id", null)) != TYPE_STRING or typeof(address.get("floor_id", null)) != TYPE_STRING or typeof(address.get("elevation", null)) != TYPE_INT:
		result["resolved"] = false
		return result
	var cell_value: Variant = address.get("cell", null)
	if not cell_value is Array or cell_value.size() != 2 or typeof(cell_value[0]) != TYPE_INT or typeof(cell_value[1]) != TYPE_INT:
		result["resolved"] = false
		return result
	var zones: Dictionary = serialize().get("zones", {})
	if not candidate_state.is_empty() and candidate_state.has("zones") and candidate_state["zones"] is Dictionary:
		zones = candidate_state["zones"]
	if candidate_state.has("zone_revision") and typeof(candidate_state["zone_revision"]) == TYPE_INT:
		result["zone_revision"] = int(candidate_state["zone_revision"])
	var plot_id: String = String(address["runtime_plot_id"])
	var floor_id: String = String(address["floor_id"])
	var elevation: int = int(address["elevation"])
	var cell: Array = [int(cell_value[0]), int(cell_value[1])]
	var expected_floor: String = "G" if elevation == 0 else ("F%d" % elevation if elevation > 0 else "B%d" % absi(elevation))
	for value: Variant in zones.values():
		if not value is Dictionary or String(value.get("plot_id", "")) != plot_id or String(value.get("floor", "")) != expected_floor:
			continue
		var owns_cell: bool = false
		for serialized_cell: Variant in value.get("tiles", []):
			if serialized_cell is Dictionary and int(serialized_cell.get("x", -1)) == cell[0] and int(serialized_cell.get("y", -1)) == cell[1]:
				owns_cell = true
				break
		if not owns_cell:
			continue
		if not String(result["zone_id"]).is_empty() and String(result["zone_id"]) != String(value.get("id", "")):
			result["resolved"] = false
			return result
		result["zone_id"] = String(value.get("id", ""))
		result["typology"] = _manual_door_serialized_typology(value, cell)
	return result


func _manual_door_serialized_typology(zone: Dictionary, cell: Array) -> int:
	for value: Variant in zone.get("typologies", []):
		if value is Dictionary and int(value.get("x", -1)) == cell[0] and int(value.get("y", -1)) == cell[1]:
			return int(value.get("typology", 0))
	return 0


func get_zone_at_tile(
	tile_pos: Vector2i, floor: String = "", plot_id: String = ""
) -> ZoneData:
	for zone_value: Variant in zones.values():
		var zone: ZoneData = zone_value as ZoneData
		if zone != null and (floor.is_empty() or zone.floor == floor) and (plot_id.is_empty() or zone.plot_id == plot_id) and zone.tiles.has(tile_pos):
			return zone
	return null


## Get all zones on a specific floor.
func get_zones_on_floor(floor: String) -> Array[ZoneData]:
	var result: Array[ZoneData] = []
	for zone_id: String in zones:
		var zone: ZoneData = zones[zone_id]
		if zone.floor == floor:
			result.append(zone)
	return result


## Check if a tile is inside any zone.
func is_tile_in_zone(
	tile_pos: Vector2i, floor: String = "", plot_id: String = ""
) -> bool:
	return get_zone_at_tile(tile_pos, floor, plot_id) != null


# ── Serialization ──────────────────────────────────────────────────────


## Initialize a newly committed zone with a validated detached recommendation.
func initialize_zone_rate(zone_id: String, recommendation: Dictionary) -> Dictionary:
	var zone_variant: Variant = zones.get(zone_id)
	if not zone_variant is ZoneData:
		return {"committed": false, "diagnostics": [{"code": "ZONE_NOT_FOUND", "zone_id": zone_id}]}
	var zone: ZoneData = zone_variant
	if not bool(recommendation.get("valid", false)) or int(recommendation.get("recommended_rent_centi_kreds", -1)) < 0:
		zone.daily_rent_rate_centi_kreds = -1
		zone.rate_state = "PENDING_RECOMMENDATION"
		return {"committed": false, "diagnostics": [{"code": "ZONE_RATE_PENDING"}]}
	zone.daily_rent_rate_centi_kreds = int(recommendation["recommended_rent_centi_kreds"])
	zone.rate_revision = 0
	zone.rate_state = "READY"
	zone.rate_recommendation_provenance = recommendation.duplicate(true)
	zone_rent_initialized.emit(zone_id, zone.daily_rent_rate_centi_kreds, zone.rate_revision)
	return {"committed": true, "rate_centi_kreds": zone.daily_rent_rate_centi_kreds, "rate_revision": zone.rate_revision, "diagnostics": []}


## Commit a player rate intent through the ZoneManager authority boundary.
func commit_zone_rate_intent(intent: Dictionary) -> Dictionary:
	var zone_id := String(intent.get("zone_id", ""))
	var desired_rate := int(intent.get("desired_rate_centi_kreds", -1))
	var expected_revision := int(intent.get("expected_rate_revision", -1))
	var request_reference := String(intent.get("request_reference", ""))
	if zone_id.is_empty() or desired_rate < 0 or expected_revision < 0:
		return {"committed": false, "diagnostics": [{"code": "RATE_REPRESENTATION_INVALID"}]}
	var zone_variant: Variant = zones.get(zone_id)
	if not zone_variant is ZoneData:
		return {"committed": false, "diagnostics": [{"code": "ZONE_NOT_FOUND", "zone_id": zone_id}]}
	var zone: ZoneData = zone_variant
	if zone.rate_revision != expected_revision:
		return {"committed": false, "diagnostics": [{"code": "RATE_REVISION_STALE", "zone_id": zone_id}]}
	zone.daily_rent_rate_centi_kreds = desired_rate
	zone.rate_revision += 1
	zone.rate_state = "READY"
	zone_rent_changed.emit(zone_id, desired_rate, zone.rate_revision, request_reference)
	return {"committed": true, "rate_centi_kreds": desired_rate, "rate_revision": zone.rate_revision, "diagnostics": []}


func zone_rate_snapshot(zone_id: String) -> Dictionary:
	var zone_variant: Variant = zones.get(zone_id)
	if not zone_variant is ZoneData:
		return {"valid": false, "diagnostics": [{"code": "ZONE_NOT_FOUND", "zone_id": zone_id}]}
	var zone: ZoneData = zone_variant
	return {"valid": true, "zone_id": zone_id, "daily_rent_rate_centi_kreds": zone.daily_rent_rate_centi_kreds, "rate_revision": zone.rate_revision, "rate_state": zone.rate_state, "recommendation": zone.rate_recommendation_provenance.duplicate(true), "diagnostics": []}


## Bind a tenant through the ZoneManager authority boundary.
func bind_tenant_to_parcel(zone_id: String, parcel_id: String, tenant_id: String) -> Dictionary:
	if tenant_id.is_empty() or zone_id.is_empty() or parcel_id.is_empty():
		return {"committed": false, "diagnostics": [{"code": "TENANT_BIND_INVALID_ID"}]}
	var zone_variant: Variant = zones.get(zone_id)
	if not zone_variant is ZoneData:
		return {"committed": false, "diagnostics": [{"code": "TENANT_BIND_ZONE_NOT_FOUND", "zone_id": zone_id}]}
	var zone: ZoneData = zone_variant
	for parcel: Parcel in zone.parcels:
		if parcel.id != parcel_id:
			continue
		if parcel.has_tenant and parcel.tenant_id != tenant_id:
			return {"committed": false, "diagnostics": [{"code": "TENANT_BIND_PARCEL_OCCUPIED", "zone_id": zone_id, "parcel_id": parcel_id}]}
		parcel.has_tenant = true
		parcel.tenant_id = tenant_id
		authority_revision += 1
		return {"committed": true, "diagnostics": []}
	return {"committed": false, "diagnostics": [{"code": "TENANT_BIND_PARCEL_NOT_FOUND", "zone_id": zone_id, "parcel_id": parcel_id}]}


## Release a tenant through the ZoneManager authority boundary.
func release_tenant_from_parcel(zone_id: String, parcel_id: String, tenant_id: String) -> Dictionary:
	var zone_variant: Variant = zones.get(zone_id)
	if not zone_variant is ZoneData:
		return {"committed": false, "diagnostics": [{"code": "TENANT_RELEASE_ZONE_NOT_FOUND", "zone_id": zone_id}]}
	var zone: ZoneData = zone_variant
	for parcel: Parcel in zone.parcels:
		if parcel.id != parcel_id:
			continue
		if not parcel.has_tenant or parcel.tenant_id != tenant_id:
			return {"committed": false, "diagnostics": [{"code": "TENANT_RELEASE_OWNERSHIP_MISMATCH", "zone_id": zone_id, "parcel_id": parcel_id}]}
		parcel.has_tenant = false
		parcel.tenant_id = ""
		authority_revision += 1
		return {"committed": true, "diagnostics": []}
	return {"committed": false, "diagnostics": [{"code": "TENANT_RELEASE_PARCEL_NOT_FOUND", "zone_id": zone_id, "parcel_id": parcel_id}]}


func parcel_snapshot(zone_id: String, parcel_id: String) -> Dictionary:
	var zone_variant: Variant = zones.get(zone_id)
	if not zone_variant is ZoneData:
		return {}
	var zone: ZoneData = zone_variant
	for parcel: Parcel in zone.parcels:
		if parcel.id == parcel_id:
			return {"zone_id": zone_id, "parcel_id": parcel_id, "tile_count": parcel.tiles.size(), "has_tenant": parcel.has_tenant, "tenant_id": parcel.tenant_id}
	return {}


## Return detached committed parcel-door facts for TenantManager proxy publication.
func get_service_proxy_door_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	var zone_ids: Array[String] = []
	for zone_id: Variant in zones.keys():
		zone_ids.append(String(zone_id))
	zone_ids.sort()
	for zone_id: String in zone_ids:
		var zone: ZoneData = zones.get(zone_id, null) as ZoneData
		if zone == null:
			continue
		var parcels: Array[Parcel] = zone.parcels.duplicate()
		parcels.sort_custom(func(left: Parcel, right: Parcel) -> bool: return left.id < right.id)
		for parcel: Parcel in parcels:
			var edges: Array[Dictionary] = parcel.selected_door_edges.duplicate(true)
			edges.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return _door_edge_key(left) < _door_edge_key(right))
			for edge: Dictionary in edges:
				var access_kind: String = String(edge.get("access_kind", ""))
				if not PHYSICAL_DOOR_ACCESS_KINDS.has(access_kind):
					continue
				var door_id: String = service_proxy_door_id(parcel.id, edge)
				snapshots.append({
					"zone_id": zone_id,
					"parcel_id": parcel.id,
					"door_id": door_id,
					"access_kind": access_kind,
					"tenant_id": parcel.tenant_id,
					"tenant_active": parcel.has_tenant,
					"zone_revision": authority_revision,
				})
	return snapshots


func _build_public_band_traversal_edges(snapshot: PublicBandAccessSnapshot) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if snapshot == null:
		return result
	var access_by_id: Dictionary = {}
	for access_edge: Dictionary in snapshot.access_edges:
		access_by_id[String(access_edge["access_edge_id"])] = access_edge
	for zone: ZoneData in zones.values():
		for parcel: Parcel in zone.parcels:
			for selected: Dictionary in parcel.selected_door_edges:
				if String(selected.get("access_kind", "")) != "public_band":
					continue
				var access_id: String = String(selected.get("public_band_access_edge_id", ""))
				if not access_by_id.has(access_id):
					continue
				var access_edge: Dictionary = access_by_id[access_id]
				var tile: Vector2i = selected.get("tile", Vector2i.ZERO)
				result.append({
					"door_edge_id": service_proxy_door_id(parcel.id, selected),
					"floor_id": zone.floor,
					"interior_cell_id": "%s/%d,%d" % [zone.floor, tile.x, tile.y],
					"external_ref": String(access_edge["pedestrian_band_id"]),
					"access_kind": "public_band_physical",
					"source_kind": "H3",
					"public_band_access_edge_id": access_id,
				})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["door_edge_id"]) < String(right["door_edge_id"]))
	return result


static func service_proxy_door_id(parcel_id: String, edge: Dictionary) -> String:
	return "parcel_door/%s/%s" % [parcel_id, _door_edge_key(edge)]


func serialize() -> Dictionary:
	var data: Dictionary = {}
	for zone_id: String in zones:
		var zone: ZoneData = zones[zone_id]
		var serialized_parcels: Array[Dictionary] = []
		for parcel: Parcel in zone.parcels:
			serialized_parcels.append(parcel.serialize())
		data[zone_id] = {
			"id": zone.id,
			"plot_id": zone.plot_id,
			"type": zone.type,
			"subtype": zone.subtype,
			"floor": zone.floor,
			"tiles": _serialize_tiles(zone.tiles),
			"parcel_layout_seed": zone.parcel_layout_seed,
			"typologies": _serialize_typologies(zone.typologies),
			"zone_name": zone.zone_name,
			"daily_rent_rate_centi_kreds": zone.daily_rent_rate_centi_kreds,
			"rate_revision": zone.rate_revision,
			"rate_state": zone.rate_state,
			"rate_recommendation_provenance": zone.rate_recommendation_provenance.duplicate(true),
			"parcels": serialized_parcels,
		}
	return {
		"zones": data,
		"zone_counter": _zone_counter,
		"parcel_counter": _parcel_counter,
		"parcel_display_number_counter": _parcel_display_number_counter,
	}


func validate_serialized_state(data: Dictionary, public_band_access: PublicBandAccessSnapshot) -> Dictionary:
	if public_band_access == null:
		return {"valid": false, "diagnostics": [{"code": "PUBLIC_BAND_ACCESS_UNAVAILABLE"}]}
	var snapshot_validation: Dictionary = PublicBandAccessSnapshot.validate_value(public_band_access.duplicate_value())
	if not bool(snapshot_validation.get("valid", false)):
		return snapshot_validation
	if not data.get("zones") is Dictionary:
		return {"valid": false, "diagnostics": [{"code": "INVALID_PUBLIC_BAND_DOOR_PROVENANCE"}]}
	var edges_by_id: Dictionary = {}
	for edge: Dictionary in public_band_access.access_edges:
		edges_by_id[String(edge["access_edge_id"])] = edge
	for zone_value: Variant in (data["zones"] as Dictionary).values():
		if not zone_value is Dictionary:
			return {"valid": false, "diagnostics": [{"code": "INVALID_PUBLIC_BAND_DOOR_PROVENANCE"}]}
		var zone_data: Dictionary = zone_value
		for parcel_value: Variant in zone_data.get("parcels", []):
			if not parcel_value is Dictionary:
				return {"valid": false, "diagnostics": [{"code": "INVALID_PUBLIC_BAND_DOOR_PROVENANCE"}]}
			var parcel_data: Dictionary = parcel_value
			var selected_validation: Dictionary = Parcel.validate_serialized_selected_door_edges(parcel_data.get("selected_door_edges"))
			if not bool(selected_validation.get("valid", false)):
				return selected_validation
			for selected: Dictionary in parcel_data["selected_door_edges"]:
				if String(selected["access_kind"]) != "PUBLIC_BAND":
					continue
				var edge_id: String = String(selected["public_band_access_edge_id"])
				if not edges_by_id.has(edge_id):
					return {"valid": false, "diagnostics": [{"code": "INVALID_PUBLIC_BAND_DOOR_PROVENANCE"}]}
				var edge: Dictionary = edges_by_id[edge_id]
				var endpoint: Dictionary = edge["parcel_endpoint"]
				if String(endpoint["runtime_plot_id"]) != String(zone_data.get("plot_id", "")) or endpoint["local_cell"] != selected["parcel_cell"] or String(edge["outward_direction"]) != String(selected["direction"]):
					return {"valid": false, "diagnostics": [{"code": "INVALID_PUBLIC_BAND_DOOR_PROVENANCE"}]}
	return {"valid": true, "diagnostics": []}


func deserialize(data: Dictionary) -> void:
	zones.clear()
	_zone_counter = data.get("zone_counter", 0)
	_parcel_counter = data.get("parcel_counter", 0)
	_parcel_display_number_counter = data.get("parcel_display_number_counter", 0)
	var zones_data: Dictionary = data.get("zones", {})
	for zone_id: String in zones_data:
		var zone_data: Dictionary = zones_data[zone_id]
		var zone := ZoneData.new()
		zone.id = zone_data.get("id", zone_id)
		zone.plot_id = zone_data.get("plot_id", "")
		zone.type = zone_data.get("type", "")
		zone.subtype = zone_data.get("subtype", "")
		zone.floor = zone_data.get("floor", "")
		var restored_tiles: Array[Vector2i] = []
		for tile_data: Dictionary in zone_data.get("tiles", []):
			restored_tiles.append(Vector2i(tile_data.get("x", 0), tile_data.get("y", 0)))
		zone.tiles = restored_tiles
		zone.parcel_layout_seed = int(zone_data.get("parcel_layout_seed", _generate_parcel_layout_seed(zone.id)))
		if zone.parcel_layout_seed <= 0:
			zone.parcel_layout_seed = _generate_parcel_layout_seed(zone.id)
		zone.typologies = _deserialize_typologies(zone_data.get("typologies", []))
		zone.zone_name = zone_data.get("zone_name", "")
		zone.daily_rent_rate_centi_kreds = int(zone_data.get("daily_rent_rate_centi_kreds", -1))
		zone.rate_revision = int(zone_data.get("rate_revision", 0))
		zone.rate_state = String(zone_data.get("rate_state", "PENDING_RECOMMENDATION"))
		zone.rate_recommendation_provenance = zone_data.get("rate_recommendation_provenance", {}).duplicate(true)
		for parcel_data: Dictionary in zone_data.get("parcels", []):
			var parcel := Parcel.deserialize(parcel_data)
			zone.parcels.append(parcel)
			_parcel_display_number_counter = maxi(_parcel_display_number_counter, parcel.display_number)
		zones[zone.id] = zone
	authority_revision += 1


# ── Atomic Split Preparation ───────────────────────────────────────────


func _build_access_context(
	spatial_snapshot: DistrictZoneSpatialSnapshot,
	candidate: ZoneData,
	replaced_zones: Array[ZoneData],
	public_band_access: PublicBandAccessSnapshot
) -> FloorAccessContext:
	var replaced_ids: Dictionary = {}
	for replaced_zone: ZoneData in replaced_zones:
		if replaced_zone != null:
			replaced_ids[replaced_zone.id] = true
	var prospective_zone_ids: Dictionary = {}
	var prospective_typologies: Dictionary = {}
	for zone_value: Variant in zones.values():
		var zone: ZoneData = zone_value as ZoneData
		if zone == null or replaced_ids.has(zone.id) or zone.plot_id != candidate.plot_id or zone.floor != candidate.floor:
			continue
		for tile: Vector2i in zone.tiles:
			prospective_zone_ids[tile] = zone.id
			prospective_typologies[tile] = zone.typologies.get(tile, ZoneData.TileTypology.TENANT)
	for tile: Vector2i in candidate.tiles:
		prospective_zone_ids[tile] = candidate.id
		prospective_typologies[tile] = candidate.typologies.get(tile, ZoneData.TileTypology.TENANT)
	return FloorAccessContext.new(
		spatial_snapshot,
		prospective_zone_ids,
		prospective_typologies,
		public_band_access
	)


func _prepare_access_transaction(
	candidate: ZoneData,
	replaced_zone: ZoneData,
	spatial_snapshot: DistrictZoneSpatialSnapshot = null,
	public_band_access: PublicBandAccessSnapshot = null
) -> Array[ZoneData]:
	if spatial_snapshot == null:
		last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "DISTRICT_ZONE_SPATIAL_UNAVAILABLE")
		return []
	var replaced: Array[ZoneData] = []
	if replaced_zone != null:
		replaced.append(replaced_zone)
	var context := _build_access_context(spatial_snapshot, candidate, replaced, public_band_access)
	if not _prepare_split(candidate, context):
		return []
	var prior_parcels: Array[Parcel] = []
	if replaced_zone != null:
		prior_parcels = replaced_zone.parcels
	_assign_persistent_ids(candidate.parcels, prior_parcels)
	if not prior_parcels.is_empty() and not _validate_prior_selected_doors(
		candidate.id, candidate.parcels, prior_parcels
	):
		return []
	if not _assign_selected_door_edges(candidate.parcels, prior_parcels):
		return []
	_assign_debug_subtypes(candidate)
	var prepared: Array[ZoneData] = [candidate]
	for affected_zone: ZoneData in _affected_zones(candidate, replaced_zone):
		var affected_candidate := _copy_zone(affected_zone)
		if not _prepare_split(affected_candidate, context):
			return []
		_assign_persistent_ids(affected_candidate.parcels, affected_zone.parcels)
		if not _validate_prior_selected_doors(
			affected_zone.id, affected_candidate.parcels, affected_zone.parcels
		):
			return []
		if not _assign_selected_door_edges(affected_candidate.parcels, affected_zone.parcels):
			return []
		_assign_debug_subtypes(affected_candidate)
		prepared.append(affected_candidate)
	var manual_door_diagnostic := _manual_door_invalidation_diagnostic(candidate, replaced_zone, prepared, context)
	if not manual_door_diagnostic.is_empty():
		last_split_result = SplitResult.failure(SplitResult.Status.EXISTING_DOOR_INVALIDATED, manual_door_diagnostic)
		return []
	return prepared


func _affected_zones(candidate: ZoneData, replaced_zone: ZoneData) -> Array[ZoneData]:
	var changed_tiles: Dictionary = {}
	for tile_pos: Vector2i in candidate.tiles:
		changed_tiles[tile_pos] = true
	if replaced_zone != null:
		for tile_pos: Vector2i in replaced_zone.tiles:
			changed_tiles[tile_pos] = true
	var affected: Array[ZoneData] = []
	for zone_id: String in zones:
		var zone: ZoneData = zones[zone_id]
		if zone.id == candidate.id or zone.plot_id != candidate.plot_id or zone.floor != candidate.floor:
			continue
		var touches_changed_tile := false
		for tile_pos: Vector2i in zone.tiles:
			for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if changed_tiles.has(tile_pos + direction):
					touches_changed_tile = true
					break
			if touches_changed_tile:
				break
		if touches_changed_tile:
			affected.append(zone)
	affected.sort_custom(func(first: ZoneData, second: ZoneData) -> bool: return first.id < second.id)
	return affected


func _prepare_split(candidate: ZoneData, access_context: FloorAccessContext) -> bool:
	if access_context == null:
		last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "DISTRICT_ZONE_SPATIAL_UNAVAILABLE")
		return false
	last_split_result = ZoneSplitter.split(candidate, access_context)
	if not last_split_result.is_success():
		return false
	for residual_tile: Vector2i in last_split_result.residual_tiles:
		candidate.typologies[residual_tile] = ZoneData.TileTypology.DECORATION
	candidate.parcels = last_split_result.parcels
	return true


## Apply the pure debug assignment result to the uncommitted zone candidate.
func _assign_debug_subtypes(candidate: ZoneData) -> void:
	if assignment_mode != AssignmentMode.DEBUG_IMMEDIATE:
		return
	var catalog_snapshot := DebugBusinessSubtypeCatalog.snapshot_for_zone_type(candidate.type)
	var assignment_result := ZoneBusinessAssigner.assign(
		candidate.parcels,
		candidate.type,
		catalog_snapshot
	)
	for parcel: Parcel in candidate.parcels:
		parcel.assigned_subtype_id = assignment_result.subtype_for(parcel.id)
	last_assignment_result = assignment_result


func _validate_candidate_tiles(
	candidate: ZoneData,
	existing_zone_id: String,
	spatial_snapshot: DistrictZoneSpatialSnapshot
) -> bool:
	if candidate.plot_id.is_empty() or candidate.tiles.is_empty():
		last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "MISSING_ZONE_CONTEXT")
		return false
	if spatial_snapshot == null or String(spatial_snapshot.get_floor_scope().get("runtime_plot_id", "")) != candidate.plot_id:
		last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "DISTRICT_ZONE_SPATIAL_SCOPE_MISMATCH")
		return false
	for tile_pos: Vector2i in candidate.tiles:
		if not spatial_snapshot.has_cell("zone_eligible_cells", tile_pos):
			last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "INVALID_OR_UNOWNED_ZONE_TILE")
			return false
		var occupying_zone: ZoneData = get_zone_at_tile(tile_pos, candidate.floor, candidate.plot_id)
		if occupying_zone != null and occupying_zone.id != existing_zone_id:
			last_split_result = SplitResult.failure(SplitResult.Status.INVALID_ZONE_GEOMETRY, "OVERLAPPING_ZONE_TILE")
			return false
	return true


## Select deterministic physical door edges after parcel IDs are stable and before commit.
func _assign_selected_door_edges(new_parcels: Array[Parcel], old_parcels: Array[Parcel]) -> bool:
	var old_parcels_by_id: Dictionary = {}
	for old_parcel: Parcel in old_parcels:
		if not old_parcel.id.is_empty():
			old_parcels_by_id[old_parcel.id] = old_parcel

	for parcel: Parcel in new_parcels:
		var physical_candidates := _physical_door_candidates(parcel)
		if physical_candidates.is_empty():
			last_split_result = SplitResult.failure(
				SplitResult.Status.NO_PHYSICAL_DOOR_FRONTAGE,
				"NO_PHYSICAL_DOOR_FRONTAGE"
			)
			return false

		var eligible_positions: Dictionary = {}
		var candidates_by_key: Dictionary = {}
		for edge: Dictionary in physical_candidates:
			eligible_positions[edge.get("tile", Vector2i.ZERO)] = true
			candidates_by_key[_door_edge_key(edge)] = edge
		var required_count := ceili(float(eligible_positions.size()) / 10.0)

		var selected: Array[Dictionary] = []
		var selected_positions: Dictionary = {}
		var previous: Parcel = old_parcels_by_id.get(parcel.id, null)
		if previous != null:
			var prior_edges := previous.selected_door_edges.duplicate()
			prior_edges.sort_custom(_compare_door_edges)
			for prior_edge: Dictionary in prior_edges:
				var legal_edge: Dictionary = candidates_by_key.get(_door_edge_key(prior_edge), {})
				var tile: Vector2i = legal_edge.get("tile", Vector2i.ZERO)
				if legal_edge.is_empty() or selected_positions.has(tile) or selected.size() >= required_count:
					continue
				selected.append(legal_edge.duplicate())
				selected_positions[tile] = true

		var covered_transit_areas: Dictionary = {}
		for selected_edge: Dictionary in selected:
			var selected_area := _transit_area_key(selected_edge)
			if not selected_area.is_empty():
				covered_transit_areas[selected_area] = true

		while selected.size() < required_count:
			var next_edge := _preferred_door_candidate(
				physical_candidates, selected.size(), selected_positions, covered_transit_areas
			)
			if next_edge.is_empty():
				break
			selected.append(next_edge.duplicate())
			var selected_tile: Vector2i = next_edge.get("tile", Vector2i.ZERO)
			selected_positions[selected_tile] = true
			var transit_area := _transit_area_key(next_edge)
			if not transit_area.is_empty():
				covered_transit_areas[transit_area] = true
		parcel.selected_door_edges = selected
	return true


func _preferred_door_candidate(
	candidates: Array[Dictionary],
	slot_index: int,
	selected_positions: Dictionary,
	covered_transit_areas: Dictionary
) -> Dictionary:
	var preferred: Array[Dictionary] = []
	var fallback: Array[Dictionary] = []
	for edge: Dictionary in candidates:
		var tile: Vector2i = edge.get("tile", Vector2i.ZERO)
		if selected_positions.has(tile):
			continue
		fallback.append(edge)
		var access_kind: String = edge.get("access_kind", "")
		var transit_area := _transit_area_key(edge)
		if slot_index == 0:
			if access_kind == "internal_transit":
				preferred.append(edge)
		elif slot_index == 1:
			if access_kind == "external_circulation":
				preferred.append(edge)
			elif access_kind == "internal_transit" and not covered_transit_areas.has(transit_area):
				# Used only when no external candidate exists; see fallback below.
				pass
		else:
			if access_kind == "internal_transit" and not covered_transit_areas.has(transit_area):
				preferred.append(edge)
	if not preferred.is_empty():
		return preferred[0]
	if slot_index == 1:
		for edge: Dictionary in fallback:
			if edge.get("access_kind", "") == "internal_transit":
				if not covered_transit_areas.has(_transit_area_key(edge)):
					return edge
	return fallback[0] if not fallback.is_empty() else {}


func _transit_area_key(edge: Dictionary) -> String:
	if edge.get("access_kind", "") != "internal_transit":
		return ""
	var explicit_key: String = edge.get("transit_area_key", "")
	if not explicit_key.is_empty():
		return explicit_key
	var access: Vector2i = edge.get("access", Vector2i.ZERO)
	return "transit:%d,%d" % [access.x, access.y]


func _validate_spatial_snapshot_input(
	intent: Dictionary,
	district_ref: Dictionary,
	snapshot: DistrictZoneSpatialSnapshot
) -> Dictionary:
	var operation: String = String(intent.get("operation", ""))
	if operation != DistrictRuntime.OP_PAINT_ZONE and operation != DistrictRuntime.OP_SET_MANUAL_DOOR:
		return {"valid": true, "diagnostics": []}
	if snapshot == null:
		return {"valid": false, "diagnostics": [{"code": "DISTRICT_ZONE_SPATIAL_UNAVAILABLE"}]}
	var validation: Dictionary = DistrictZoneSpatialSnapshot.validate_value(snapshot.duplicate_value())
	if not bool(validation.get("valid", false)):
		return validation
	var layout: Dictionary = snapshot.get_layout_ref()
	if snapshot.get_district_revision() != int(district_ref.get("district_revision", -1)) or String(layout.get("layout_id", "")) != String(district_ref.get("layout_id", "")) or int(layout.get("layout_definition_version", -1)) != int(district_ref.get("layout_definition_version", -2)) or String(layout.get("definition_fingerprint", "")) != String(district_ref.get("definition_fingerprint", "")):
		return {"valid": false, "diagnostics": [{"code": "DISTRICT_ZONE_SPATIAL_STALE"}]}
	var scope: Dictionary = snapshot.get_floor_scope()
	if String(scope.get("runtime_plot_id", "")) != String(intent.get("runtime_plot_id", "")) or String(scope.get("floor_id", "")) != String(intent.get("floor_id", "")) or int(scope.get("signed_elevation", 999999)) != int(intent.get("elevation", -999999)):
		return {"valid": false, "diagnostics": [{"code": "DISTRICT_ZONE_SPATIAL_SCOPE_MISMATCH"}]}
	return {"valid": true, "diagnostics": []}


func _validate_public_band_access_input(district_ref: Dictionary, snapshot: PublicBandAccessSnapshot) -> Dictionary:
	if snapshot == null:
		return {"valid": false, "diagnostics": [{"code": "PUBLIC_BAND_ACCESS_UNAVAILABLE"}]}
	var validation: Dictionary = PublicBandAccessSnapshot.validate_value(snapshot.duplicate_value())
	if not bool(validation.get("valid", false)):
		return validation
	var layout: Dictionary = snapshot.layout_ref
	if snapshot.district_revision != int(district_ref.get("district_revision", -1)) or String(layout.get("layout_id", "")) != String(district_ref.get("layout_id", "")) or int(layout.get("layout_definition_version", -1)) != int(district_ref.get("layout_definition_version", -2)) or String(layout.get("definition_fingerprint", "")) != String(district_ref.get("definition_fingerprint", "")):
		return {"valid": false, "diagnostics": [{"code": "PUBLIC_BAND_ACCESS_STALE"}]}
	return {"valid": true, "diagnostics": []}


func _validate_retained_public_band_doors(snapshot: PublicBandAccessSnapshot) -> Dictionary:
	if snapshot == null:
		return {"valid": false, "diagnostics": [{"code": "PUBLIC_BAND_ACCESS_UNAVAILABLE"}]}
	var edges_by_id: Dictionary = {}
	for edge: Dictionary in snapshot.access_edges:
		edges_by_id[String(edge["access_edge_id"])] = edge
	for zone: ZoneData in zones.values():
		for parcel: Parcel in zone.parcels:
			for selected: Dictionary in parcel.selected_door_edges:
				if String(selected.get("access_kind", "")) != "public_band":
					continue
				var edge_id: String = String(selected.get("public_band_access_edge_id", ""))
				if edge_id.is_empty() or not edges_by_id.has(edge_id):
					return {"valid": false, "diagnostics": [{"code": "EXISTING_DOOR_INVALIDATED", "parcel_id": parcel.id}]}
				var edge: Dictionary = edges_by_id[edge_id]
				var endpoint: Dictionary = edge["parcel_endpoint"]
				var cell: Dictionary = endpoint["local_cell"]
				if String(endpoint["runtime_plot_id"]) != zone.plot_id or Vector2i(int(cell["x"]), int(cell["y"])) != selected.get("tile", Vector2i.ZERO) or _direction_name(selected.get("direction", Vector2i.ZERO)) != String(edge["outward_direction"]):
					return {"valid": false, "diagnostics": [{"code": "EXISTING_DOOR_INVALIDATED", "parcel_id": parcel.id}]}
	return {"valid": true, "diagnostics": []}


static func _direction_name(direction: Vector2i) -> String:
	match direction:
		Vector2i.UP: return "NORTH"
		Vector2i.RIGHT: return "EAST"
		Vector2i.DOWN: return "SOUTH"
		Vector2i.LEFT: return "WEST"
	return ""


func _all_parcels_have_physical_door_frontage(parcels: Array[Parcel]) -> bool:
	for parcel: Parcel in parcels:
		if _physical_door_candidates(parcel).is_empty():
			return false
	return true


func _physical_door_candidates(parcel: Parcel) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for edge: Dictionary in parcel.frontage_edges:
		var tile: Vector2i = edge.get("tile", Vector2i.ZERO)
		var direction: Vector2i = edge.get("direction", Vector2i.ZERO)
		var access: Vector2i = edge.get("access", Vector2i.ZERO)
		var access_kind: String = edge.get("access_kind", "")
		if direction == Vector2i.ZERO or access != tile + direction:
			continue
		if not PHYSICAL_DOOR_ACCESS_KINDS.has(access_kind):
			continue
		candidates.append(edge.duplicate())
	candidates.sort_custom(_compare_door_edges)
	return candidates


static func _same_door_geometry(first: Dictionary, second: Dictionary) -> bool:
	if first.get("tile", Vector2i.ZERO) != second.get("tile", Vector2i.ZERO) or first.get("direction", Vector2i.ZERO) != second.get("direction", Vector2i.ZERO) or first.get("access", Vector2i.ZERO) != second.get("access", Vector2i.ZERO):
		return false
	if String(first.get("access_kind", "")) == "public_band" or String(second.get("access_kind", "")) == "public_band":
		return String(first.get("access_kind", "")) == "public_band" and String(second.get("access_kind", "")) == "public_band" and not String(first.get("public_band_access_edge_id", "")).is_empty() and String(first.get("public_band_access_edge_id", "")) == String(second.get("public_band_access_edge_id", ""))
	return true


static func _door_edge_key(edge: Dictionary) -> String:
	var tile: Vector2i = edge.get("tile", Vector2i.ZERO)
	var direction: Vector2i = edge.get("direction", Vector2i.ZERO)
	var access: Vector2i = edge.get("access", Vector2i.ZERO)
	return "%d,%d|%d,%d|%d,%d|%s|%s" % [
		tile.x, tile.y, direction.x, direction.y, access.x, access.y, edge.get("access_kind", ""), edge.get("public_band_access_edge_id", "")
	]


static func _compare_door_edges(first: Dictionary, second: Dictionary) -> bool:
	var first_tile: Vector2i = first.get("tile", Vector2i.ZERO)
	var second_tile: Vector2i = second.get("tile", Vector2i.ZERO)
	if first_tile != second_tile:
		return _compare_tile_positions(first_tile, second_tile)
	return _door_direction_rank(first.get("direction", Vector2i.ZERO)) < _door_direction_rank(
		second.get("direction", Vector2i.ZERO)
	)


static func _door_direction_rank(direction: Vector2i) -> int:
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]
	for index: int in range(directions.size()):
		if directions[index] == direction:
			return index
	return directions.size()


func _validate_prior_selected_doors(
	zone_id: String, new_parcels: Array[Parcel], old_parcels: Array[Parcel]
) -> bool:
	var diagnostic := _prior_door_invalidation_diagnostic(zone_id, new_parcels, old_parcels)
	if diagnostic.is_empty():
		return true
	last_split_result = SplitResult.failure(SplitResult.Status.EXISTING_DOOR_INVALIDATED, diagnostic)
	return false


func _prior_door_invalidation_diagnostic(
	zone_id: String, new_parcels: Array[Parcel], old_parcels: Array[Parcel]
) -> String:
	var new_parcels_by_id: Dictionary = {}
	for parcel: Parcel in new_parcels:
		new_parcels_by_id[parcel.id] = parcel
	for old_parcel: Parcel in old_parcels:
		if old_parcel.selected_door_edges.is_empty():
			continue
		var new_parcel: Parcel = new_parcels_by_id.get(old_parcel.id, null)
		if new_parcel == null:
			return "EXISTING_DOOR_INVALIDATED:%s:%s:PARCEL_NO_LONGER_MATCHED" % [zone_id, old_parcel.id]
		var candidate_keys: Dictionary = {}
		for edge: Dictionary in _physical_door_candidates(new_parcel):
			candidate_keys[_door_edge_key(edge)] = true
		for old_edge: Dictionary in old_parcel.selected_door_edges:
			if not candidate_keys.has(_door_edge_key(old_edge)):
				return "EXISTING_DOOR_INVALIDATED:%s:%s:%s:EDGE_NOT_IN_PROSPECTIVE_PARCEL" % [
					zone_id, old_parcel.id, _door_edge_key(old_edge)
				]
	return ""


func _match_preview_parcels(new_parcels: Array[Parcel], old_parcels: Array[Parcel]) -> void:
	var counter_snapshot := _counter_snapshot()
	_assign_persistent_ids(new_parcels, old_parcels)
	_restore_counters(counter_snapshot)


func _assign_persistent_ids(new_parcels: Array[Parcel], old_parcels: Array[Parcel]) -> void:
	var used_old_ids: Dictionary = {}
	for parcel: Parcel in new_parcels:
		var matched_parcel: Parcel
		var best_overlap: int = 0
		for old_parcel: Parcel in old_parcels:
			if old_parcel.id.is_empty() or used_old_ids.has(old_parcel.id):
				continue
			var overlap := _tile_overlap(parcel.tiles, old_parcel.tiles)
			if overlap > best_overlap or (
				overlap == best_overlap and overlap > 0 and matched_parcel != null and old_parcel.id < matched_parcel.id
			):
				matched_parcel = old_parcel
				best_overlap = overlap
		if matched_parcel != null and best_overlap > 0:
			parcel.id = matched_parcel.id
			parcel.display_number = matched_parcel.display_number if matched_parcel.display_number > 0 else _generate_parcel_display_number()
			used_old_ids[matched_parcel.id] = true
		else:
			parcel.id = _generate_parcel_id()
			parcel.display_number = _generate_parcel_display_number()


func _tile_overlap(first: Array[Vector2i], second: Array[Vector2i]) -> int:
	var second_set: Dictionary = {}
	for tile: Vector2i in second:
		second_set[tile] = true
	var overlap: int = 0
	for tile: Vector2i in first:
		if second_set.has(tile):
			overlap += 1
	return overlap


# ── Manual Door Preservation ───────────────────────────────────────────


func _zone_with_split_residuals(source: ZoneData, result: SplitResult) -> ZoneData:
	var projected := _copy_zone(source)
	for tile_pos: Vector2i in result.residual_tiles:
		projected.typologies[tile_pos] = ZoneData.TileTypology.DECORATION
	return projected


func _manual_door_invalidation_diagnostic(
	_candidate: ZoneData,
	replaced_zone: ZoneData,
	prospective_zones: Array[ZoneData],
	context: FloorAccessContext
) -> String:
	if context == null or context.spatial_snapshot == null:
		return "DISTRICT_ZONE_SPATIAL_UNAVAILABLE"
	var changed_tiles: Dictionary = {}
	if replaced_zone != null:
		for tile_pos: Vector2i in replaced_zone.tiles:
			changed_tiles[tile_pos] = true
	for zone: ZoneData in prospective_zones:
		for tile_pos: Vector2i in zone.tiles:
			changed_tiles[tile_pos] = true
	for edge: Dictionary in context.spatial_snapshot.get_manual_door_edges():
		var endpoint_a: Dictionary = edge.get("endpoint_a", {})
		var endpoint_b: Dictionary = edge.get("endpoint_b", {})
		var cell_a: Dictionary = endpoint_a.get("local_cell", {})
		var cell_b: Dictionary = endpoint_b.get("local_cell", {})
		var from := Vector2i(int(cell_a.get("x", -1)), int(cell_a.get("y", -1)))
		var to := Vector2i(int(cell_b.get("x", -1)), int(cell_b.get("y", -1)))
		if not changed_tiles.has(from) and not changed_tiles.has(to):
			continue
		var reason: String = _prospective_manual_door_invalid_reason(context, from, to)
		if not reason.is_empty():
			return "EXISTING_DOOR_INVALIDATED:MANUAL_DOOR:%s:%s" % [_manual_door_edge_key(from, to), reason]
	return ""


func _prospective_manual_door_invalid_reason(
	context: FloorAccessContext,
	from: Vector2i,
	to: Vector2i
) -> String:
	if context == null or not context.is_valid_tile(from) or not context.is_valid_tile(to):
		return "INVALID_ENDPOINT"
	var from_zone: String = context.zone_id_at(from)
	var to_zone: String = context.zone_id_at(to)
	if not from_zone.is_empty() and not to_zone.is_empty():
		if from_zone == to_zone:
			return "SAME_ZONE_FORBIDDEN"
		if context.typology_at(from) != ZoneData.TileTypology.TRANSIT or context.typology_at(to) != ZoneData.TileTypology.TRANSIT:
			return "INTER_ZONE_REQUIRES_TRANSIT"
		return ""
	if not from_zone.is_empty() or not to_zone.is_empty():
		var zone_cell: Vector2i = from if not from_zone.is_empty() else to
		var circulation_cell: Vector2i = to if not from_zone.is_empty() else from
		if context.typology_at(zone_cell) != ZoneData.TileTypology.TRANSIT:
			return "ZONE_TO_CIRCULATION_REQUIRES_TRANSIT"
		if not context.spatial_snapshot.has_cell("explicit_circulation_cells", circulation_cell):
			return "ZONE_TO_CIRCULATION_REQUIRES_EXPLICIT_CIRCULATION"
		return ""
	var from_circulation: bool = context.spatial_snapshot.has_cell("explicit_circulation_cells", from)
	var to_circulation: bool = context.spatial_snapshot.has_cell("explicit_circulation_cells", to)
	if from_circulation == to_circulation:
		return "UNZONED_EDGE_REQUIRES_CIRCULATION_MISMATCH"
	return ""


func _prospective_manual_tile_state(
	context: FloorAccessContext,
	tile_pos: Vector2i
) -> Dictionary:
	if context == null or not context.is_valid_tile(tile_pos):
		return {}
	return {
		"zone_id": context.zone_id_at(tile_pos),
		"typology": context.typology_at(tile_pos),
		"explicit_circulation": context.spatial_snapshot.has_cell("explicit_circulation_cells", tile_pos),
	}


static func _manual_door_edge_key(first: Vector2i, second: Vector2i) -> String:
	if _compare_tile_positions(second, first):
		var swapped := first
		first = second
		second = swapped
	return "%d,%d|%d,%d" % [first.x, first.y, second.x, second.y]


# ── Zone Copying & Serialization Helpers ───────────────────────────────


func _copy_zone(source: ZoneData) -> ZoneData:
	var copy := ZoneData.new()
	copy.id = source.id
	copy.plot_id = source.plot_id
	copy.type = source.type
	copy.subtype = source.subtype
	copy.floor = source.floor
	copy.tiles = source.tiles.duplicate()
	copy.parcel_layout_seed = source.parcel_layout_seed
	copy.typologies = source.typologies.duplicate()
	copy.zone_name = source.zone_name
	copy.daily_rent_rate_centi_kreds = source.daily_rent_rate_centi_kreds
	copy.rate_revision = source.rate_revision
	copy.rate_state = source.rate_state
	copy.rate_recommendation_provenance = source.rate_recommendation_provenance.duplicate(true)
	copy.parcels = source.parcels.duplicate()
	return copy


func _copy_zone_state(source: ZoneData, destination: ZoneData) -> void:
	destination.plot_id = source.plot_id
	destination.type = source.type
	destination.subtype = source.subtype
	destination.floor = source.floor
	destination.tiles = source.tiles.duplicate()
	destination.parcel_layout_seed = source.parcel_layout_seed
	destination.typologies = source.typologies.duplicate()
	destination.zone_name = source.zone_name
	destination.daily_rent_rate_centi_kreds = source.daily_rent_rate_centi_kreds
	destination.rate_revision = source.rate_revision
	destination.rate_state = source.rate_state
	destination.rate_recommendation_provenance = source.rate_recommendation_provenance.duplicate(true)
	destination.parcels = source.parcels.duplicate()


func _counter_snapshot() -> Dictionary:
	return {
		"zone": _zone_counter,
		"parcel": _parcel_counter,
		"display": _parcel_display_number_counter,
	}


func _restore_counters(snapshot: Dictionary) -> void:
	_zone_counter = int(snapshot.get("zone", _zone_counter))
	_parcel_counter = int(snapshot.get("parcel", _parcel_counter))
	_parcel_display_number_counter = int(snapshot.get("display", _parcel_display_number_counter))


func _generate_zone_id() -> String:
	_zone_counter += 1
	return "zone_%d" % _zone_counter


func _generate_parcel_id() -> String:
	_parcel_counter += 1
	return "parcel_%d" % _parcel_counter


## Derive a stable random-looking seed from the persistent zone ID.
func _generate_parcel_layout_seed(zone_id: String) -> int:
	var seed: int = ("parcel_layout:%s" % zone_id).hash()
	return -seed if seed < 0 else seed


func _generate_parcel_display_number() -> int:
	_parcel_display_number_counter += 1
	return _parcel_display_number_counter


func _normalize_typologies(tiles: Array[Vector2i], typologies: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for tile_pos: Vector2i in tiles:
		normalized[tile_pos] = typologies.get(tile_pos, ZoneData.TileTypology.TENANT)
	return normalized


func _normalized_tiles(tiles: Array[Vector2i]) -> Array[Vector2i]:
	var unique: Dictionary = {}
	for tile: Vector2i in tiles:
		unique[tile] = true
	var normalized: Array[Vector2i] = []
	for tile: Vector2i in unique:
		normalized.append(tile)
	normalized.sort_custom(_compare_tile_positions)
	return normalized


func _serialize_typologies(typologies: Dictionary) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for tile_pos: Vector2i in typologies:
		serialized.append({
			"x": tile_pos.x,
			"y": tile_pos.y,
			"typology": int(typologies[tile_pos]),
		})
	serialized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("y", 0) < b.get("y", 0) or (
			a.get("y", 0) == b.get("y", 0) and a.get("x", 0) < b.get("x", 0)
		)
	)
	return serialized


func _deserialize_typologies(data: Array) -> Dictionary:
	var typologies: Dictionary = {}
	for entry: Dictionary in data:
		typologies[Vector2i(entry.get("x", 0), entry.get("y", 0))] = entry.get(
			"typology", ZoneData.TileTypology.TENANT
		)
	return typologies


## Read-only paint eligibility for ZoneTool from injected District and Zone snapshots.
func can_paint_tile_for_tool(
	tile_pos: Vector2i,
	floor: String,
	plot_id: String,
	zone_type: String,
	none_mode: bool,
	spatial_snapshot: DistrictZoneSpatialSnapshot = null
) -> bool:
	var occupying_zone := get_zone_at_tile(tile_pos, floor, plot_id)
	if none_mode:
		return occupying_zone != null
	if spatial_snapshot == null or not spatial_snapshot.has_cell("zone_eligible_cells", tile_pos):
		return false
	if occupying_zone == null:
		return true
	return occupying_zone.type == zone_type


static func _compare_tile_positions(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)
