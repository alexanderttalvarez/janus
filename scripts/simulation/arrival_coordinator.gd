class_name ArrivalCoordinator
extends RefCounted

## H8 immediate pedestrian arrival authority. It separates demand snapshots,
## canonical source allocation, and VisitorManager realization.

signal arrival_realized(envelope: Dictionary)
signal arrival_rejected(diagnostics: Array[Dictionary])

var _district_runtime: DistrictRuntime
var _pedestrian_graph: PedestrianGraphSnapshot
var _gateway_eligibility: GatewayEligibilitySnapshot
var _visitor_manager: VisitorManager
var _demand_authority: VisitorDemandAuthority
var _legacy_spawn_adapter: LegacyVisitorSpawnAdapter
var _gate: ArrivalCommitGate = ArrivalCommitGate.new()
var _dispatcher: ArrivalCommitDispatcher = ArrivalCommitDispatcher.new()
var _transaction_counter: int = 0


func initialize(
	p_district_runtime: DistrictRuntime,
	p_pedestrian_graph: PedestrianGraphSnapshot,
	p_gateway_eligibility: GatewayEligibilitySnapshot,
	p_visitor_manager: VisitorManager
) -> Dictionary:
	if p_district_runtime == null or p_pedestrian_graph == null or p_gateway_eligibility == null or p_visitor_manager == null:
		return _reject("ARRIVAL_DEPENDENCY_REQUIRED", "District Runtime, H5, H6, and VisitorManager are required")
	_district_runtime = p_district_runtime
	_pedestrian_graph = p_pedestrian_graph.duplicate_value()
	_gateway_eligibility = p_gateway_eligibility.duplicate_value()
	_district_runtime.set_arrival_revision_context(_pedestrian_graph.zone_revision, _gateway_eligibility.topology_revision)
	_visitor_manager = p_visitor_manager
	_legacy_spawn_adapter = load("res://scripts/simulation/legacy_visitor_spawn_adapter.gd").new() as LegacyVisitorSpawnAdapter
	_visitor_manager.configure_arrival_coordinator(self)
	_district_runtime.set_arrival_commit_gate(_gate)
	_visitor_manager.set_arrival_commit_gate(_gate)
	if _dispatcher.get_subscriber_count() == 0:
		_dispatcher.subscribe(Callable(self, "_publish_event_bus"))
	return {"valid": true, "diagnostics": []}


func set_demand_authority(authority: VisitorDemandAuthority) -> void:
	_demand_authority = authority


func set_snapshots(
	p_pedestrian_graph: PedestrianGraphSnapshot,
	p_gateway_eligibility: GatewayEligibilitySnapshot
) -> Dictionary:
	if p_pedestrian_graph == null or p_gateway_eligibility == null:
		return _reject("ARRIVAL_SNAPSHOT_REQUIRED", "H5 and H6 snapshots are required")
	_pedestrian_graph = p_pedestrian_graph.duplicate_value()
	_gateway_eligibility = p_gateway_eligibility.duplicate_value()
	if _district_runtime != null:
		_district_runtime.set_arrival_revision_context(_pedestrian_graph.zone_revision, _gateway_eligibility.topology_revision)
	return {"valid": true, "diagnostics": []}


func get_gate() -> ArrivalCommitGate:
	return _gate


func get_dispatcher() -> ArrivalCommitDispatcher:
	return _dispatcher


## Demand is sampled independently from source selection.
func on_visitor_tick() -> Dictionary:
	if _demand_authority == null:
		return {"valid": true, "skipped": true, "diagnostics": []}
	var demand: ArrivalDemandSnapshot = _demand_authority.capture_snapshot()
	var target_count: int = mini(demand.desired_count, VisitorManager.MAX_VISITORS) if demand != null else 0
	if demand == null or _visitor_manager.get_active_visitor_count() >= target_count:
		return {"valid": true, "skipped": true, "diagnostics": []}
	return realize_arrival(demand)


## Return the canonical first equally eligible pedestrian source.
func allocate_source(demand: ArrivalDemandSnapshot) -> Dictionary:
	var context: Dictionary = _capture_context()
	if not bool(context.get("valid", false)):
		return _reject_diagnostics(context.get("diagnostics", []))
	if demand == null or demand.snapshot_id.is_empty():
		return _reject("DEMAND_SNAPSHOT_REQUIRED", "allocation requires a demand snapshot identity")
	var candidates: Array[Dictionary] = context.get("candidates", [])
	if candidates.is_empty():
		return _reject("NO_ELIGIBLE_PEDESTRIAN_SOURCE", "no enabled structurally eligible pedestrian source is available")
	return {"valid": true, "source": candidates[0].duplicate(true), "candidates": candidates.duplicate(true), "revisions": context["revisions"].duplicate(true), "diagnostics": []}


## Execute the exact H8 immediate realization transaction.
func realize_arrival(demand: ArrivalDemandSnapshot) -> Dictionary:
	if demand == null or demand.snapshot_id.is_empty():
		return _reject("DEMAND_SNAPSHOT_REQUIRED", "arrival realization requires a demand snapshot identity")
	if _visitor_manager != null and _visitor_manager.get_active_visitor_count() >= VisitorManager.MAX_VISITORS:
		return _reject("MAX_ACTIVE_VISITORS_REACHED", "the global active visitor budget is full")
	var initial: Dictionary = allocate_source(demand)
	if not bool(initial.get("valid", false)):
		return initial
	_transaction_counter += 1
	var owner_token: String = "arrival_txn_%d" % _transaction_counter
	if not _gate.acquire(owner_token):
		return _reject("ARRIVAL_TRANSACTION_BUSY", "another arrival transaction is active")
	if not _gate.enter_barrier(owner_token):
		_gate.release(owner_token)
		return _reject("ARRIVAL_BARRIER_FAILED", "arrival barrier could not be acquired")
	var token: ArrivalSourceValidationToken
	var prepared: Dictionary = {}
	var source: Dictionary = initial.get("source", {})
	var source_id: String = String(source.get("arrival_source_id", ""))
	var result: Dictionary = {}
	var validation: Dictionary = _district_runtime.validate_arrival_source(
		source_id,
		demand.snapshot_id,
		int(initial["revisions"]["district_revision"]),
		int(initial["revisions"]["topology_revision"]),
		int(initial["revisions"]["eligibility_revision"])
	)
	if not bool(validation.get("valid", false)):
		return _abort(owner_token, token, prepared, validation.get("diagnostics", []))
	token = validation.get("token", null) as ArrivalSourceValidationToken
	var bridged_source: Dictionary = _legacy_spawn_adapter.bridge_selected_source(source_id, source)
	if not bool(bridged_source.get("valid", false)):
		return _abort(owner_token, token, prepared, bridged_source.get("diagnostics", []))
	prepared = _visitor_manager.prepare_detached_visitor(String(bridged_source.get("arrival_source_id", "")), bridged_source.get("source", {}), demand)
	if not bool(prepared.get("valid", false)):
		return _abort(owner_token, token, prepared, prepared.get("diagnostics", []))
	var current: Dictionary = _capture_context()
	var current_source: Dictionary = _source_by_id(current.get("candidates", []), source_id)
	if not bool(current.get("valid", false)) or current_source.is_empty():
		return _abort(owner_token, token, prepared, [{"code": "ARRIVAL_SOURCE_STALE", "message": "selected source is no longer eligible before commit"}])
	var revalidation: Dictionary = _district_runtime.revalidate_arrival_source(
		token,
		demand.snapshot_id,
		int(current["revisions"]["district_revision"]),
		int(current["revisions"]["topology_revision"]),
		int(current["revisions"]["eligibility_revision"])
	)
	if not bool(revalidation.get("valid", false)):
		return _abort(owner_token, token, prepared, revalidation.get("diagnostics", []))
	var envelope: Dictionary = _build_envelope(prepared, source, demand, current["revisions"])
	if not _dispatcher.can_append(envelope):
		return _abort(owner_token, token, prepared, [{"code": "ARRIVAL_APPEND_PREFLIGHT_FAILED", "message": "arrival dispatcher cannot accept the complete envelope"}])
	var committed: Dictionary = _visitor_manager.commit_prepared_visitor(prepared)
	if not bool(committed.get("valid", false)):
		return _abort(owner_token, token, prepared, committed.get("diagnostics", []))
	if not _district_runtime.consume_arrival_source_token(token):
		return _abort(owner_token, token, prepared, [{"code": "ARRIVAL_TOKEN_CONSUME_FAILED", "message": "arrival validation token could not be consumed"}])
	if not _dispatcher.append(envelope):
		return _abort(owner_token, token, prepared, [{"code": "ARRIVAL_APPEND_FAILED", "message": "arrival envelope append failed before commit point"}])
	_gate.release_barrier(owner_token)
	var subscriber_diagnostics: Array[Dictionary] = _dispatcher.dispatch(envelope)
	arrival_realized.emit(envelope)
	_gate.release(owner_token)
	result = {"valid": true, "envelope": envelope, "visitor": committed.get("visitor"), "subscriber_diagnostics": subscriber_diagnostics, "diagnostics": []}
	return result


## Select an exit source using the same canonical ordering as entry.
func select_exit_source() -> Dictionary:
	return revalidate_exit_source("")


## Revalidate an in-flight exit against current H3/H5/H6 facts. If the
## selected source is no longer eligible, the first current canonical source
## is returned; no coordinate-based fallback is permitted.
func revalidate_exit_source(current_source_id: String) -> Dictionary:
	var context: Dictionary = _capture_context()
	if not bool(context.get("valid", false)):
		return _reject_diagnostics(context.get("diagnostics", []))
	var candidates: Array[Dictionary] = context.get("candidates", [])
	if candidates.is_empty():
		return _reject("NO_ELIGIBLE_EXIT_SOURCE", "no eligible source is available for visitor exit")
	var selected: Dictionary = candidates[0]
	if not current_source_id.is_empty():
		var current: Dictionary = _source_by_id(candidates, current_source_id)
		if not current.is_empty():
			selected = current
	return {"valid": true, "source": selected.duplicate(true), "revisions": context["revisions"].duplicate(true), "diagnostics": []}


func _capture_context() -> Dictionary:
	if _district_runtime == null or not _district_runtime.has_session() or _pedestrian_graph == null or _gateway_eligibility == null:
		return {"valid": false, "diagnostics": [{"code": "ARRIVAL_CONTEXT_MISSING", "message": "arrival inputs are unavailable"}]}
	var snapshot: ResolvedDistrictSnapshot = _district_runtime.get_snapshot()
	var runtime_revision: int = _district_runtime.get_revision()
	var revisions: Dictionary = {
		"district_revision": runtime_revision,
		"topology_revision": _pedestrian_graph.zone_revision,
		"eligibility_revision": _gateway_eligibility.topology_revision,
		"h5_district_revision": _pedestrian_graph.district_revision,
		"h6_district_revision": _gateway_eligibility.district_revision,
	}
	var diagnostics: Array[Dictionary] = []
	if _pedestrian_graph.definition_fingerprint != snapshot.get_fingerprint() or _gateway_eligibility.definition_fingerprint != snapshot.get_fingerprint():
		diagnostics.append({"code": "ARRIVAL_FINGERPRINT_MISMATCH", "message": "H5/H6 inputs do not match the committed district snapshot"})
	if _pedestrian_graph.district_revision != runtime_revision or _gateway_eligibility.district_revision != runtime_revision:
		diagnostics.append({"code": "ARRIVAL_DISTRICT_REVISION_MISMATCH", "message": "H5/H6 district revisions do not match District Runtime"})
	if _pedestrian_graph.zone_revision != _gateway_eligibility.topology_revision:
		diagnostics.append({"code": "ARRIVAL_TOPOLOGY_REVISION_MISMATCH", "message": "H5 topology and H6 eligibility revisions do not match"})
	if not diagnostics.is_empty():
		return {"valid": false, "diagnostics": diagnostics, "revisions": revisions}
	var attachments: Dictionary = {}
	for attachment: Dictionary in snapshot.get_data().get("arrival_source_attachments", []):
		attachments[String(attachment.get("authored_id", ""))] = attachment
	var candidates: Array[Dictionary] = []
	for entry: Dictionary in _gateway_eligibility.entries:
		var source_id: String = String(entry.get("arrival_source_id", ""))
		if not bool(entry.get("structurally_eligible", false)) or not attachments.has(source_id):
			continue
		var attachment: Dictionary = attachments[source_id]
		if String(attachment.get("mode", "")) != "PEDESTRIAN":
			continue
		if not _district_runtime.is_arrival_source_enabled(source_id):
			continue
		var source: Dictionary = attachment.duplicate(true)
		source["arrival_source_id"] = source_id
		source["gateway_eligibility"] = entry.duplicate(true)
		candidates.append(source)
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return _canonical_source_less(String(left.get("arrival_source_id", "")), String(right.get("arrival_source_id", ""))))
	return {"valid": true, "candidates": candidates, "revisions": revisions, "diagnostics": []}


func _source_by_id(sources: Array, source_id: String) -> Dictionary:
	for source: Variant in sources:
		if source is Dictionary and String(source.get("arrival_source_id", "")) == source_id:
			return source
	return {}


func _build_envelope(prepared: Dictionary, source: Dictionary, demand: ArrivalDemandSnapshot, revisions: Dictionary) -> Dictionary:
	var visitor: VisitorData = prepared.get("visitor", null) as VisitorData
	return {
		"event_type": "arrival_realized",
		"commit_id": "arrival_commit_%d" % _transaction_counter,
		"arrival_source_id": String(source.get("arrival_source_id", "")),
		"demand_snapshot_id": demand.snapshot_id,
		"demand": demand.value(),
		"revisions": revisions.duplicate(true),
		"source": source.duplicate(true),
		"visitor": _visitor_value(visitor),
	}


func _visitor_value(visitor: VisitorData) -> Dictionary:
	return {
		"id": visitor.id,
		"arrival_source_id": visitor.arrival_source_id,
		"position": {"x": visitor.position.x, "y": visitor.position.y, "z": visitor.position.z},
		"floor_level": visitor.floor_level,
		"location_type": visitor.location_type,
		"current_state": visitor.current_state,
		"purpose": visitor.purpose,
		"budget": visitor.budget,
		"satisfaction": visitor.satisfaction,
	}


func _publish_event_bus(envelope: Dictionary) -> Dictionary:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var event_bus: Node = (main_loop as SceneTree).root.get_node_or_null("EventBus")
		if event_bus != null:
			event_bus.emit_signal("arrival_realized", envelope.duplicate(true))
			event_bus.emit_signal("visitor_entered", String(envelope.get("visitor", {}).get("id", "")))
	return {"ok": true}


func _abort(
	owner_token: String,
	token: ArrivalSourceValidationToken,
	prepared: Dictionary,
	diagnostics: Array,
	rollback_visitor: bool = true
) -> Dictionary:
	if token != null:
		token.invalidate()
	if rollback_visitor and not prepared.is_empty():
		_visitor_manager.rollback_prepared_visitor(prepared)
	_gate.release_barrier(owner_token)
	_gate.release(owner_token)
	return _reject_diagnostics(diagnostics)


func _reject(code: String, message: String) -> Dictionary:
	return _reject_diagnostics([{"code": code, "message": message}])


func _reject_diagnostics(diagnostics: Array) -> Dictionary:
	var typed: Array[Dictionary] = []
	for diagnostic: Variant in diagnostics:
		if diagnostic is Dictionary:
			typed.append(diagnostic.duplicate(true))
	arrival_rejected.emit(typed)
	return {"valid": false, "diagnostics": typed}


func _canonical_source_less(left: String, right: String) -> bool:
	var left_bytes: PackedByteArray = _normalize_nfc(left).to_utf8_buffer()
	var right_bytes: PackedByteArray = _normalize_nfc(right).to_utf8_buffer()
	var count: int = mini(left_bytes.size(), right_bytes.size())
	for index: int in range(count):
		if left_bytes[index] == right_bytes[index]:
			continue
		return left_bytes[index] < right_bytes[index]
	return left_bytes.size() < right_bytes.size()


func _normalize_nfc(value: String) -> String:
	var composed: Dictionary = {
		"65:768": 0x00C0, "65:769": 0x00C1, "65:770": 0x00C2, "65:771": 0x00C3, "65:776": 0x00C4, "65:807": 0x00C7,
		"69:768": 0x00C8, "69:769": 0x00C9, "69:770": 0x00CA, "69:776": 0x00CB,
		"73:768": 0x00CC, "73:769": 0x00CD, "73:770": 0x00CE, "73:776": 0x00CF,
		"78:771": 0x00D1, "79:768": 0x00D2, "79:769": 0x00D3, "79:770": 0x00D4, "79:771": 0x00D5, "79:776": 0x00D6,
		"85:768": 0x00D9, "85:769": 0x00DA, "85:770": 0x00DB, "85:776": 0x00DC,
		"97:768": 0x00E0, "97:769": 0x00E1, "97:770": 0x00E2, "97:771": 0x00E3, "97:776": 0x00E4, "97:807": 0x00E7,
		"101:768": 0x00E8, "101:769": 0x00E9, "101:770": 0x00EA, "101:776": 0x00EB,
		"105:768": 0x00EC, "105:769": 0x00ED, "105:770": 0x00EE, "105:776": 0x00EF,
		"110:771": 0x00F1, "111:768": 0x00F2, "111:769": 0x00F3, "111:770": 0x00F4, "111:771": 0x00F5, "111:776": 0x00F6,
		"117:768": 0x00F9, "117:769": 0x00FA, "117:770": 0x00FB, "117:776": 0x00FC,
	}
	var result: String = ""
	for index: int in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		if codepoint >= 0x0300 and codepoint <= 0x0327 and not result.is_empty():
			var base: int = result.unicode_at(result.length() - 1)
			var key: String = "%d:%d" % [base, codepoint]
			if composed.has(key):
				result = result.substr(0, result.length() - 1) + String.chr(int(composed[key]))
				continue
		result += String.chr(codepoint)
	return result
