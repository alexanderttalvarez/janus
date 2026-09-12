class_name DistrictRuntime
extends Node

## H3 session-scoped District Runtime contract/proof implementation.
## It owns only immutable snapshot/state references and coordinates injected
## authority ports; it never writes Economy, ZoneManager, or Progression directly.

signal session_created(layout_id: String, definition_fingerprint: String)
signal session_replaced(layout_id: String, definition_fingerprint: String)
signal session_disposed(layout_id: String)
signal transaction_rejected(diagnostics: Array[Dictionary])
signal district_delta_committed(envelope: Dictionary)
signal subscriber_diagnostics(diagnostics: Array[Dictionary])
signal construction_topology_published(topology: Dictionary)

const OP_ACQUIRE_SECTION: String = "ACQUIRE_SECTION"
const OP_ACQUIRE_SPACE: String = "ACQUIRE_SPACE"
const OP_CONSTRUCT: String = "CONSTRUCT"
const OP_DEMOLISH_CONSTRUCTION: String = "DEMOLISH_CONSTRUCTION"
const OP_DEMOLISH_FIXED_OCCUPANT: String = "DEMOLISH_FIXED_OCCUPANT"
const OP_SET_SOURCE_ENABLED: String = "SET_SOURCE_ENABLED"
const OP_CONVERT_STREET: String = "CONVERT_STREET"
const OP_PAINT_ZONE: String = "PAINT_ZONE"
const OP_SET_MANUAL_DOOR: String = "SET_MANUAL_DOOR"

var _snapshot: ResolvedDistrictSnapshot
var _state: Dictionary = {}
var _ports: DistrictRuntimePorts.DistrictRuntimePortsBundle
var _journal: DistrictCommitJournal = DistrictCommitJournal.new()
var _dispatcher: DistrictCommitDispatcher = DistrictCommitDispatcher.new()
var _gate: DistrictTransactionGate = DistrictTransactionGate.new()
var _session_gate: SessionMutationGate
var _transaction_counter: int = 0
var _state_records: DistrictStateRecords = DistrictStateRecords.new()
var _traversal_view: DistrictTraversalReadView
var _street_conversion_validator: Callable
var _arrival_commit_gate: ArrivalCommitGate
var _arrival_token_counter: int = 0
var _arrival_topology_revision: int = -1
var _arrival_eligibility_revision: int = -1
var _construction_policy: ConstructionPolicy
var _construction_authority: ConstructionAuthority
var _construction_topology: Dictionary = {}


func _init() -> void:
	_construction_policy = load("res://scripts/construction/construction_policy.gd").new() as ConstructionPolicy
	_construction_authority = load("res://scripts/construction/construction_authority.gd").new() as ConstructionAuthority


func configure_ports(ports: DistrictRuntimePorts.DistrictRuntimePortsBundle) -> void:
	_ports = ports


func configure_session_gate(session_gate: SessionMutationGate) -> Dictionary:
	if session_gate == null:
		return _reject("SESSION_GATE_REQUIRED", "District Runtime requires the session mutation gate")
	var configuration: Dictionary = _gate.configure(session_gate)
	if not bool(configuration.get("valid", false)):
		return configuration
	_session_gate = session_gate
	return {"valid": true, "diagnostics": []}


func get_session_gate() -> SessionMutationGate:
	return _session_gate


func configure_construction_policy(policy: ConstructionPolicy) -> void:
	_construction_policy = policy


func get_construction_policy_snapshot() -> Dictionary:
	return {} if _construction_policy == null else _construction_policy.duplicate_value()


func get_construction_topology() -> Dictionary:
	return _construction_topology.duplicate(true)


func get_operations_room_facts() -> Array[Dictionary]:
	var facts: Array[Dictionary] = []
	for fact: Variant in _construction_topology.get("operations_room_facts", []):
		if fact is Dictionary:
			facts.append(fact.duplicate(true))
	return facts


func preview_construction(intent: Dictionary) -> Dictionary:
	var normalized: Dictionary = intent.duplicate(true)
	normalized["operation"] = OP_CONSTRUCT
	return preview_transaction(normalized)


func commit_construction(intent: Dictionary) -> Dictionary:
	var normalized: Dictionary = intent.duplicate(true)
	normalized["operation"] = OP_CONSTRUCT
	return commit_transaction(normalized)


func configure_components(
	economy_port: RefCounted,
	zone_port: RefCounted,
	progression_port: RefCounted
) -> void:
	var bundle := DistrictRuntimePorts.DistrictRuntimePortsBundle.new()
	bundle.initialize(economy_port as DistrictRuntimePorts.DistrictEconomyPort, zone_port as DistrictRuntimePorts.DistrictZonePort, progression_port as DistrictRuntimePorts.DistrictProgressionPort)
	_ports = bundle


func set_journal(journal: DistrictCommitJournal) -> void:
	_journal = journal


func set_dispatcher(dispatcher: DistrictCommitDispatcher) -> void:
	_dispatcher = dispatcher


func create_session(snapshot: ResolvedDistrictSnapshot, initial_state: Variant = null) -> Dictionary:
	if snapshot == null:
		return _reject("SNAPSHOT_REQUIRED", "cannot create a session without a snapshot")
	var candidate_state: Dictionary = _state_records.create_baseline(snapshot) if initial_state == null else initial_state
	var validation: Dictionary = _state_records.validate(candidate_state, snapshot)
	if not bool(validation.get("valid", false)):
		return _reject_diagnostics(validation.get("diagnostics", []))
	_snapshot = snapshot
	_state = candidate_state.duplicate(true)
	_traversal_view = _make_empty_traversal_view(snapshot, get_revision(), 0)
	_rebuild_construction_topology("session_created")
	session_created.emit(snapshot.get_layout_id(), snapshot.get_fingerprint())
	return {"valid": true, "snapshot": snapshot, "state": get_state(), "diagnostics": []}


func replace_session(snapshot: ResolvedDistrictSnapshot, state: Variant = null) -> Dictionary:
	if snapshot == null:
		return _reject("SNAPSHOT_REQUIRED", "cannot replace a session without a snapshot")
	var candidate_state: Dictionary = _state_records.create_baseline(snapshot) if state == null else state
	var validation: Dictionary = _state_records.validate(candidate_state, snapshot)
	if not bool(validation.get("valid", false)):
		return _reject_diagnostics(validation.get("diagnostics", []))
	var previous_layout_id: String = "" if _snapshot == null else _snapshot.get_layout_id()
	_snapshot = snapshot
	_state = candidate_state.duplicate(true)
	_traversal_view = _make_empty_traversal_view(snapshot, get_revision(), 0)
	_rebuild_construction_topology("session_replaced")
	session_replaced.emit(snapshot.get_layout_id(), snapshot.get_fingerprint())
	return {"valid": true, "previous_layout_id": previous_layout_id, "state": get_state(), "diagnostics": []}


func dispose_session() -> Dictionary:
	if _snapshot == null:
		return {"valid": true, "diagnostics": []}
	var layout_id: String = _snapshot.get_layout_id()
	_snapshot = null
	_state = {}
	_traversal_view = null
	_construction_topology = {}
	session_disposed.emit(layout_id)
	return {"valid": true, "diagnostics": []}


func has_session() -> bool:
	return _snapshot != null


func get_snapshot() -> ResolvedDistrictSnapshot:
	return _snapshot


func get_state() -> Dictionary:
	return _state.duplicate(true)


func get_revision() -> int:
	return int(_state.get("district_revision", 0))


func get_state_read() -> Dictionary:
	return {"district_revision": get_revision(), "state": get_state(), "snapshot": _snapshot}


func get_progression_policy_snapshot() -> Dictionary:
	return _policy_snapshot()


func get_traversal_read_view() -> DistrictTraversalReadView:
	return null if _traversal_view == null else _traversal_view.duplicate_value()


## H3-owned injection point for committed traversal records. The records are
## validated against the current immutable snapshot and revision before swap.
## Replace only explicit door attachments while preserving other H3 traversal facts.
func set_door_access_edges(records: Array[Dictionary], zone_revision: int) -> Dictionary:
	if _snapshot == null or _traversal_view == null:
		return {"valid": false, "diagnostics": [{"code": "TRAVERSAL_VIEW_REQUIRED", "message": "door attachments require an active district session"}]}
	var refreshed: DistrictTraversalReadView = load("res://scripts/district/district_traversal_read_view.gd").new() as DistrictTraversalReadView
	refreshed.initialize(
		_snapshot.get_fingerprint(),
		get_revision(),
		zone_revision,
		_traversal_view.floor_circulation_edges,
		records,
		_traversal_view.vertical_links
	)
	return set_traversal_read_view(refreshed)


func set_traversal_read_view(view: DistrictTraversalReadView) -> Dictionary:
	if _snapshot == null:
		return _reject("SESSION_REQUIRED", "a District Runtime session is required")
	if view == null:
		return _reject("TRAVERSAL_VIEW_REQUIRED", "traversal read view is required")
	var validation: Dictionary = view.validate(_snapshot)
	if not bool(validation.get("valid", false)):
		return _reject_diagnostics(validation.get("diagnostics", []))
	if view.district_revision != get_revision():
		return _reject("TRAVERSAL_REVISION_MISMATCH", "traversal view revision must match district state")
	_traversal_view = view.duplicate_value()
	return {"valid": true, "diagnostics": []}


func set_street_conversion_validator(validator: Callable) -> void:
	_street_conversion_validator = validator


func subscribe_committed(handler: Callable) -> int:
	return _dispatcher.subscribe(handler)


func unsubscribe_committed(handler: Callable) -> bool:
	return _dispatcher.unsubscribe(handler)


func get_journal() -> DistrictCommitJournal:
	return _journal


func get_gate() -> DistrictTransactionGate:
	return _gate


## H8 injects the shared arrival gate without changing H3 transaction ownership.
func set_arrival_commit_gate(gate: ArrivalCommitGate) -> Dictionary:
	if gate == null:
		return _reject("ARRIVAL_GATE_REQUIRED", "District Runtime requires the configured arrival gate")
	if _session_gate == null or gate.get_session_gate() != _session_gate:
		return _reject("SESSION_GATE_MISMATCH", "arrival and District Runtime must share the same session mutation gate")
	_arrival_commit_gate = gate
	return {"valid": true, "diagnostics": []}


func get_arrival_commit_gate() -> ArrivalCommitGate:
	return _arrival_commit_gate


## H8 supplies the latest committed H5/H6 revision context as a read-only guard.
func set_arrival_revision_context(topology_revision: int, eligibility_revision: int) -> void:
	_arrival_topology_revision = topology_revision
	_arrival_eligibility_revision = eligibility_revision


## Read the current enabled state of an H2 arrival source without mutation.
func is_arrival_source_enabled(arrival_source_id: String) -> bool:
	if _snapshot == null:
		return false
	var source: Dictionary = _record_by_authored_id(_snapshot.get_data().get("arrival_source_attachments", []), arrival_source_id)
	if source.is_empty():
		return false
	for source_state: Dictionary in _state.get("arrival_source_states", []):
		if String(source_state.get("arrival_source_id", "")) == arrival_source_id:
			return bool(source_state.get("enabled", false))
	return bool(source.get("initially_enabled", false))


func get_arrival_source(arrival_source_id: String) -> Dictionary:
	if _snapshot == null:
		return {}
	return _record_by_authored_id(_snapshot.get_data().get("arrival_source_attachments", []), arrival_source_id).duplicate(true)


## Issue an ephemeral source-validation token while the shared arrival gate is held.
func validate_arrival_source(
	arrival_source_id: String,
	demand_snapshot_id: String,
	district_revision: int,
	topology_revision: int,
	eligibility_revision: int
) -> Dictionary:
	var diagnostics: Array[Dictionary] = _arrival_source_diagnostics(arrival_source_id, demand_snapshot_id, district_revision, topology_revision, eligibility_revision)
	if not diagnostics.is_empty():
		return {"valid": false, "token": null, "diagnostics": diagnostics}
	_arrival_token_counter += 1
	var token := ArrivalSourceValidationToken.new()
	token.initialize("arrival_token_%d" % _arrival_token_counter, arrival_source_id, demand_snapshot_id, district_revision, topology_revision, eligibility_revision)
	token.bind_gate(_arrival_commit_gate)
	token.bind_revision_probe(Callable(self, "_get_arrival_revision_context"))
	return {"valid": true, "token": token, "diagnostics": []}


## Revalidate the same token and captured revisions without issuing a new token.
func revalidate_arrival_source(
	token: ArrivalSourceValidationToken,
	demand_snapshot_id: String,
	district_revision: int,
	topology_revision: int,
	eligibility_revision: int
) -> Dictionary:
	if token == null or not token.matches(token.arrival_source_id, demand_snapshot_id, district_revision, topology_revision, eligibility_revision):
		if token != null:
			token.invalidate()
		return {"valid": false, "diagnostics": [{"code": "ARRIVAL_TOKEN_INVALID", "message": "arrival validation token does not match the captured transaction"}]}
	var diagnostics: Array[Dictionary] = _arrival_source_diagnostics(token.arrival_source_id, demand_snapshot_id, district_revision, topology_revision, eligibility_revision)
	if not diagnostics.is_empty():
		token.invalidate()
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}


## Consume a token exactly once; source state and district revision remain unchanged.
func consume_arrival_source_token(token: ArrivalSourceValidationToken) -> bool:
	if _arrival_commit_gate == null or not _arrival_commit_gate.is_held() or token == null or not token.is_valid():
		return false
	return token.consume()


func _get_arrival_revision_context() -> Dictionary:
	return {
		"district_revision": get_revision(),
		"topology_revision": _arrival_topology_revision,
		"eligibility_revision": _arrival_eligibility_revision,
	}


func _arrival_source_diagnostics(
	arrival_source_id: String,
	demand_snapshot_id: String,
	district_revision: int,
	topology_revision: int,
	eligibility_revision: int
) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	if _arrival_commit_gate == null or not _arrival_commit_gate.is_held():
		diagnostics.append({"code": "ARRIVAL_GATE_REQUIRED", "message": "arrival source validation requires the shared arrival gate"})
	if _snapshot == null:
		diagnostics.append({"code": "SESSION_REQUIRED", "message": "a District Runtime session is required"})
	if demand_snapshot_id.is_empty() or district_revision < 0 or topology_revision < 0 or eligibility_revision < 0:
		diagnostics.append({"code": "ARRIVAL_CAPTURE_INVALID", "message": "arrival capture identity and revisions are required"})
	if district_revision != get_revision():
		diagnostics.append({"code": "STALE_DISTRICT_REVISION", "message": "arrival district revision is stale"})
	if _arrival_topology_revision >= 0 and topology_revision != _arrival_topology_revision:
		diagnostics.append({"code": "STALE_TOPOLOGY_REVISION", "message": "arrival H5 topology revision is stale"})
	if _arrival_eligibility_revision >= 0 and eligibility_revision != _arrival_eligibility_revision:
		diagnostics.append({"code": "STALE_ELIGIBILITY_REVISION", "message": "arrival H6 eligibility revision is stale"})
	var source: Dictionary = get_arrival_source(arrival_source_id)
	if source.is_empty():
		diagnostics.append({"code": "ARRIVAL_SOURCE_UNKNOWN", "message": "arrival source ID is not present in the committed snapshot"})
	else:
		if String(source.get("mode", "")) != "PEDESTRIAN":
			diagnostics.append({"code": "ARRIVAL_SOURCE_MODE_INVALID", "message": "MVP arrival sources must use PEDESTRIAN mode"})
		if not is_arrival_source_enabled(arrival_source_id):
			diagnostics.append({"code": "ARRIVAL_SOURCE_DISABLED", "message": "arrival source is disabled"})
	return diagnostics


## Return the district-owned immutable endpoint facts for one explicit cell.
## The returned dictionary is a detached snapshot and is never retained.
func get_manual_door_district_view(address: Dictionary, candidate_state: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"resolved": false,
		"runtime_plot_id": String(address.get("runtime_plot_id", "")),
		"floor_id": String(address.get("floor_id", "")),
		"elevation": int(address.get("elevation", 0)),
		"cell": [],
		"acquired": false,
		"constructed": false,
		"explicit_circulation": false,
		"district_revision": get_revision() if candidate_state.is_empty() else int(candidate_state.get("district_revision", -1)),
	}
	var cell_value: Variant = address.get("cell", null)
	if not cell_value is Array or cell_value.size() != 2 or typeof(cell_value[0]) != TYPE_INT or typeof(cell_value[1]) != TYPE_INT:
		return result
	result["cell"] = [int(cell_value[0]), int(cell_value[1])]
	if _snapshot == null or result["runtime_plot_id"].is_empty() or result["floor_id"].is_empty() or typeof(address.get("elevation", null)) != TYPE_INT:
		return result
	var floor_record: Dictionary = {}
	for value: Variant in _snapshot.get_data().get("floors", []):
		if value is Dictionary and String(value.get("id", "")) == String(result["floor_id"]):
			floor_record = value
			break
	if floor_record.is_empty() or String(floor_record.get("plot_id", "")) != String(result["runtime_plot_id"]) or int(floor_record.get("elevation", 0)) != int(result["elevation"]):
		return result
	var cell_key: String = "%d,%d" % [result["cell"][0], result["cell"][1]]
	var cell_resolves: bool = false
	for value: Variant in _snapshot.get_data().get("cells", []):
		if value is Dictionary and String(value.get("floor_id", "")) == String(result["floor_id"]) and "%d,%d" % [int(value.get("x", -1)), int(value.get("y", -1))] == cell_key:
			cell_resolves = true
			break
	if not cell_resolves:
		return result
	var state: Dictionary = _state if candidate_state.is_empty() else candidate_state
	result["acquired"] = _manual_door_state_has_cell(state, String(result["runtime_plot_id"]), String(result["floor_id"]), result["cell"], "acquired_cells")
	result["constructed"] = _manual_door_state_has_cell(state, String(result["runtime_plot_id"]), String(result["floor_id"]), result["cell"], "constructed_cells")
	result["explicit_circulation"] = _manual_door_state_has_cell(state, String(result["runtime_plot_id"]), String(result["floor_id"]), result["cell"], "explicit_circulation_cells")
	result["resolved"] = true
	return result


func _manual_door_state_has_cell(state: Dictionary, plot_id: String, floor_id: String, cell: Array, collection_name: String) -> bool:
	for plot_state: Variant in state.get("plot_states", []):
		if not plot_state is Dictionary or String(plot_state.get("runtime_plot_id", "")) != plot_id:
			continue
		for floor_state: Variant in plot_state.get("floor_states", []):
			if floor_state is Dictionary and String(floor_state.get("floor_id", "")) == floor_id:
				for value: Variant in floor_state.get(collection_name, []):
					if value is Array and value == cell:
						return true
	return false


func preview_transaction(intent: Dictionary) -> Dictionary:
	if _snapshot == null:
		return _reject("SESSION_REQUIRED", "a District Runtime session is required")
	var evaluation: Dictionary = _evaluate_intent(intent, _state.duplicate(true))
	if not bool(evaluation.get("valid", false)):
		return _reject_diagnostics(evaluation.get("diagnostics", []))
	var quote: Dictionary = _quote(evaluation)
	if not bool(quote.get("accepted", false)):
		return _reject_diagnostics(quote.get("diagnostics", []))
	var zone_preview: Dictionary = _zone_preview(intent, evaluation["state"])
	if not bool(zone_preview.get("accepted", false)):
		return _reject_diagnostics(zone_preview.get("diagnostics", []))
	return {
		"valid": true,
		"candidate_state": evaluation["state"].duplicate(true),
		"delta": evaluation["delta"].duplicate(true),
		"quote": quote.duplicate(true),
		"policy_snapshot": evaluation["policy_snapshot"].duplicate(true),
		"revisions": evaluation["revisions"].duplicate(true),
		"zone_preview": zone_preview.get("preview", null),
		"construction_preview": evaluation.get("construction_preview", {}).duplicate(true),
		"diagnostics": [],
	}


func commit_transaction(intent: Dictionary) -> Dictionary:
	if _session_gate == null:
		return _reject("SESSION_GATE_REQUIRED", "District Runtime requires the session mutation gate")
	if _snapshot == null:
		return _reject("SESSION_REQUIRED", "a District Runtime session is required")
	var initial_evaluation: Dictionary = _evaluate_intent(intent, _state.duplicate(true))
	if not bool(initial_evaluation.get("valid", false)):
		return _reject_diagnostics(initial_evaluation.get("diagnostics", []))
	var initial_quote: Dictionary = _quote(initial_evaluation)
	if not bool(initial_quote.get("accepted", false)):
		return _reject_diagnostics(initial_quote.get("diagnostics", []))
	_transaction_counter += 1
	var owner_token: String = "district_txn_%d" % _transaction_counter
	if not _gate.acquire(owner_token):
		return _reject("SESSION_MUTATION_BUSY", "another session mutation is active")
	if not _gate.enter_barrier(owner_token):
		_gate.release(owner_token)
		return _reject("BARRIER_FAILED", "transaction barrier could not be acquired")
	var reservation: Dictionary = {}
	var prepare_token: Dictionary = {}
	var committed: bool = false
	var previous_state: Dictionary = _state.duplicate(true)
	var result: Dictionary = {}
	var current_evaluation: Dictionary = _evaluate_intent(intent, _state.duplicate(true))
	if not bool(current_evaluation.get("valid", false)):
		result = _abort(owner_token, reservation, prepare_token, current_evaluation.get("diagnostics", []))
	else:
		var quote: Dictionary = _quote(current_evaluation)
		if not bool(quote.get("accepted", false)):
			result = _abort(owner_token, reservation, prepare_token, quote.get("diagnostics", []))
		else:
			reservation = _economy_reserve(quote)
			if not bool(reservation.get("accepted", false)):
				result = _abort(owner_token, reservation, prepare_token, reservation.get("diagnostics", []))
			else:
				prepare_token = _zone_prepare(intent, current_evaluation["state"])
				if not bool(prepare_token.get("accepted", false)):
					result = _abort(owner_token, reservation, prepare_token, prepare_token.get("diagnostics", []))
				else:
					var revision_diagnostics: Array[Dictionary] = _revalidate(current_evaluation["revisions"])
					if not revision_diagnostics.is_empty():
						result = _abort(owner_token, reservation, prepare_token, revision_diagnostics)
					else:
						var guaranteed: Dictionary = _economy_guarantee(reservation)
						if not bool(guaranteed.get("accepted", false)):
							result = _abort(owner_token, reservation, prepare_token, guaranteed.get("diagnostics", []))
						else:
							var envelope: Dictionary = _build_envelope(current_evaluation["state"], current_evaluation["delta"], current_evaluation["revisions"], guaranteed)
							if not _journal.can_append(envelope):
								result = _abort(owner_token, reservation, prepare_token, [{"code": "JOURNAL_PREFLIGHT_FAILED", "message": "commit envelope cannot be appended"}])
							else:
								var zone_commit: Dictionary = _zone_commit(prepare_token)
								if not bool(zone_commit.get("accepted", false)):
									result = _abort(owner_token, reservation, prepare_token, zone_commit.get("diagnostics", []))
								else:
									var capture: Dictionary = _economy_capture(guaranteed)
									if not bool(capture.get("accepted", false)):
										_zone_undo(prepare_token)
										result = _abort(owner_token, reservation, prepare_token, capture.get("diagnostics", []))
									else:
										_state = current_evaluation["state"].duplicate(true)
										envelope["state"] = get_state()
										if not _journal.append(envelope):
											_state = previous_state
											_zone_undo(prepare_token)
											result = _abort(owner_token, reservation, prepare_token, [{"code": "JOURNAL_APPEND_FAILED", "message": "journal append failed before commit point"}])
										else:
											committed = true
											_publish_zone_door_access(zone_commit)
											_publish_committed_topology(envelope.get("construction_topology", {}))
											result = {"valid": true, "envelope": envelope, "state": get_state(), "diagnostics": []}
		if committed:
			_gate.release_barrier(owner_token)
			var subscriber_errors: Array[Dictionary] = _dispatcher.dispatch(result["envelope"])
			var authority_diagnostics: Array[Dictionary] = _flush_authority_notifications()
			district_delta_committed.emit(result["envelope"])
			if not subscriber_errors.is_empty():
				subscriber_diagnostics.emit(subscriber_errors)
			result["subscriber_diagnostics"] = subscriber_errors
			if not authority_diagnostics.is_empty():
				result["authority_diagnostics"] = authority_diagnostics
			_gate.release(owner_token)
	return result


func _evaluate_intent(intent: Dictionary, base_state: Dictionary) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	var operation: String = String(intent.get("operation", ""))
	if operation.is_empty():
		return _evaluation_failure("OPERATION_REQUIRED", "transaction operation is required")
	if not intent.has("expected_district_revision") or typeof(intent["expected_district_revision"]) != TYPE_INT:
		return _evaluation_failure("REVISION_REQUIRED", "every transaction requires expected_district_revision")
	if int(intent["expected_district_revision"]) != int(base_state.get("district_revision", 0)):
		return _evaluation_failure("STALE_DISTRICT_REVISION", "district revision no longer matches the intent")
	var policy: Dictionary = _policy_snapshot()
	if policy.is_empty():
		return _evaluation_failure("PROGRESSION_POLICY_UNAVAILABLE", "an immutable Progression policy snapshot is required")
	var normalized_intent: Dictionary = intent.duplicate(true)
	_normalize_economy_intent(normalized_intent)
	var revisions: Dictionary = _capture_revisions(policy)
	if operation == OP_CONSTRUCT and normalized_intent.has("construction_kind"):
		var construction_result: Dictionary = _construction_authority.resolve(normalized_intent, base_state, _snapshot, policy, _construction_policy)
		if not bool(construction_result.get("valid", false)):
			return _evaluation_failure_diagnostics(construction_result.get("diagnostics", []))
		var construction_candidate: Dictionary = construction_result.get("state", {}).duplicate(true)
		construction_candidate["district_revision"] = int(base_state.get("district_revision", 0)) + 1
		var construction_validation: Dictionary = _state_records.validate(construction_candidate, _snapshot)
		if not bool(construction_validation.get("valid", false)):
			return _evaluation_failure_diagnostics(construction_validation.get("diagnostics", []))
		return {
			"valid": true,
			"state": construction_candidate,
			"delta": construction_result.get("delta", {}).duplicate(true),
			"policy_snapshot": policy,
			"revisions": revisions,
			"intent": construction_result.get("intent", normalized_intent).duplicate(true),
			"construction_preview": construction_result.get("construction_preview", {}).duplicate(true),
			"diagnostics": [],
		}
	var candidate: Dictionary = base_state.duplicate(true)
	var delta: Dictionary = {"operation": operation, "affected_ids": []}
	match operation:
		OP_ACQUIRE_SECTION:
			_apply_acquire_section(intent, candidate, delta, diagnostics)
		OP_ACQUIRE_SPACE:
			_apply_acquire_space(intent, candidate, policy, delta, diagnostics)
		OP_CONSTRUCT:
			_apply_construct(intent, candidate, policy, delta, diagnostics)
		OP_DEMOLISH_CONSTRUCTION:
			_apply_demolish_construction(intent, candidate, delta, diagnostics)
		OP_DEMOLISH_FIXED_OCCUPANT:
			_apply_demolish_occupant(intent, candidate, delta, diagnostics)
		OP_SET_SOURCE_ENABLED:
			_apply_source_enabled(intent, candidate, delta, diagnostics)
		OP_PAINT_ZONE:
			_apply_paint_zone(intent, delta, diagnostics)
		OP_SET_MANUAL_DOOR:
			_apply_set_manual_door(intent, candidate, delta, diagnostics)
		OP_CONVERT_STREET:
			if not bool(policy.get("street_conversion_eligible", false)):
				diagnostics.append({"code": "STREET_CONVERSION_UNAVAILABLE", "message": "Progression does not permit Street Segment conversion"})
			elif not _street_conversion_validator.is_valid():
				diagnostics.append({"code": "CONVERSION_VALIDATOR_REQUIRED", "message": "H5 conversion validator must be injected before street conversion"})
			else:
				var conversion: Dictionary = _street_conversion_validator.call(intent, base_state, _snapshot)
				if not bool(conversion.get("valid", false)):
					diagnostics.append_array(conversion.get("diagnostics", []))
				else:
					_apply_convert_street(intent, candidate, delta, diagnostics)
		_:
			diagnostics.append({"code": "OPERATION_UNKNOWN", "message": "unsupported district transaction operation"})
	if not diagnostics.is_empty():
		return {"valid": false, "diagnostics": diagnostics}
	candidate["district_revision"] = int(base_state.get("district_revision", 0)) + 1
	candidate = _sort_state(candidate)
	var state_validation: Dictionary = _state_records.validate(candidate, _snapshot)
	if not bool(state_validation.get("valid", false)):
		return {"valid": false, "diagnostics": state_validation.get("diagnostics", [])}
	return {"valid": true, "state": candidate, "delta": delta, "policy_snapshot": policy, "revisions": revisions, "intent": normalized_intent, "diagnostics": []}


func _apply_acquire_section(intent: Dictionary, state: Dictionary, delta: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var section_id: String = String(intent.get("runtime_section_id", ""))
	var section: Dictionary = _record_by_id(_snapshot.get_data().get("sections", []), section_id)
	if section.is_empty():
		diagnostics.append({"code": "SECTION_UNKNOWN", "message": "section address is unknown"})
		return
	if _section_owned(state, section_id, section):
		diagnostics.append({"code": "SECTION_ALREADY_OWNED", "message": "section is already owned"})
		return
	if not _section_available(state, section_id, section):
		diagnostics.append({"code": "SECTION_UNAVAILABLE", "message": "section is unavailable"})
		return
	var plot_id: String = String(section["plot_id"])
	if not _plot_active(state, plot_id):
		var selected_plot_ids: Array = _policy_snapshot().get("selected_plot_ids", [])
		if not selected_plot_ids.has(plot_id):
			diagnostics.append({"code": "PLOT_NOT_SELECTED", "message": "first section requires a committed Progression Plot selection"})
		if not bool(section.get("initially_entry_eligible", false)):
			diagnostics.append({"code": "ENTRY_SECTION_REQUIRED", "message": "inactive Plot must begin through an entry-eligible section"})
		elif not _has_runtime_accessible_adjacent_plot(state, plot_id, selected_plot_ids):
			diagnostics.append({"code": "PLOT_NOT_ADJACENT", "message": "first section must be orthogonally adjacent to an Active or selected Plot"})
	if diagnostics.is_empty():
		var plot_state: Dictionary = _ensure_plot_state(state, plot_id)
		var overrides: Array = plot_state["section_state_overrides"]
		overrides.append({"runtime_section_id": section_id, "owned": true, "available": _section_available(state, section_id, section)})
		plot_state["section_state_overrides"] = overrides
		_write_plot_state(state, plot_state)
		delta["affected_ids"].append(section_id)
		delta["kind"] = "section_acquired"


func _apply_acquire_space(intent: Dictionary, state: Dictionary, policy: Dictionary, delta: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var plot_id: String = String(intent.get("runtime_plot_id", ""))
	var elevation: int = int(intent.get("elevation", 0))
	var floor: Dictionary = _record_by_id(_snapshot.get_data().get("floors", []), String(intent.get("floor_id", "")))
	var cells: Array = intent.get("cells", [])
	if floor.is_empty() or String(floor.get("plot_id", "")) != plot_id or int(floor.get("elevation", 999)) != elevation:
		diagnostics.append({"code": "FLOOR_ADDRESS_INVALID", "message": "explicit floor address is invalid"})
	if cells.is_empty():
		diagnostics.append({"code": "ACQUISITION_CELLS_REQUIRED", "message": "space acquisition requires at least one target cell"})
	var physical_range: Dictionary = _physical_range_for_floor(floor, plot_id)
	if elevation < int(physical_range.get("minimum_elevation", -5)) or elevation > int(physical_range.get("maximum_elevation", 9)):
		diagnostics.append({"code": "PHYSICAL_CAP", "message": "requested elevation exceeds the resolved physical Plot cap"})
	if not (policy.get("elevation_eligibility", []) as Array).has(elevation):
		diagnostics.append({"code": "ELEVATION_UNAVAILABLE", "message": "Progression does not permit this elevation"})
	if diagnostics.is_empty():
		var floor_state: Dictionary = _floor_state(state, String(intent["floor_id"]), elevation)
		var acquired_pairs: Array = floor_state["acquired_cells"].duplicate(true)
		for cell_value: Variant in cells:
			var cell: Array = cell_value if cell_value is Array else []
			if cell.size() < 2:
				diagnostics.append({"code": "ACQUISITION_CELL_INVALID", "message": "each acquisition cell must contain x and y"})
				continue
			if _contains_cell(acquired_pairs, cell):
				diagnostics.append({"code": "CELL_ALREADY_ACQUIRED", "message": "cell is already acquired"})
			elif elevation != 0 and not _cell_acquired_at_adjacent_elevation(state, plot_id, elevation, cell):
				diagnostics.append({"code": "VERTICAL_SEQUENCE_REQUIRED", "message": "adjacent elevation must be acquired first"})
			else:
				acquired_pairs.append([int(cell[0]), int(cell[1])])
		if diagnostics.is_empty():
			floor_state["acquired_cells"] = _sort_cells(acquired_pairs)
			_upsert_floor_state(state, plot_id, floor_state)
			delta["affected_ids"].append(String(intent["floor_id"]))
			delta["kind"] = "space_acquired"


func _apply_construct(intent: Dictionary, state: Dictionary, policy: Dictionary, delta: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var plot_id: String = String(intent.get("runtime_plot_id", ""))
	var floor_id: String = String(intent.get("floor_id", ""))
	var floor: Dictionary = _record_by_id(_snapshot.get_data().get("floors", []), floor_id)
	var cells: Array = intent.get("cells", [])
	if floor.is_empty() or String(floor.get("plot_id", "")) != plot_id:
		diagnostics.append({"code": "FLOOR_ADDRESS_INVALID", "message": "explicit floor address is invalid"})
		return
	var elevation: int = int(floor["elevation"])
	var plot: Dictionary = _record_by_id(_snapshot.get_data().get("plots", []), plot_id)
	if not _plot_active(state, plot_id):
		diagnostics.append({"code": "PLOT_NOT_ACTIVE", "message": "construction requires an owned Active Plot"})
	var physical_range: Dictionary = _physical_range_for_floor(floor, plot_id)
	if elevation < int(physical_range.get("minimum_elevation", -5)) or elevation > int(physical_range.get("maximum_elevation", 9)):
		diagnostics.append({"code": "PHYSICAL_CAP", "message": "requested elevation exceeds the resolved physical Plot cap"})
	if not (policy.get("elevation_eligibility", []) as Array).has(elevation):
		diagnostics.append({"code": "ELEVATION_UNAVAILABLE", "message": "Progression does not permit this elevation"})
	if cells.is_empty():
		diagnostics.append({"code": "CONSTRUCTION_CELLS_REQUIRED", "message": "construction requires at least one cell"})
	var floor_state: Dictionary = _floor_state(state, floor_id, elevation)
	for cell: Variant in cells:
		if not _contains_cell(floor_state["acquired_cells"], cell):
			diagnostics.append({"code": "CONSTRUCTION_WITHOUT_ACQUISITION", "message": "every constructed cell requires acquired vertical rights"})
		if not _mask_contains(plot.get("buildability_mask", []), cell):
			diagnostics.append({"code": "CELL_NOT_BUILDABLE", "message": "construction cell is outside immutable buildability"})
		if _occupied_at(plot_id, elevation, cell, state):
			diagnostics.append({"code": "FIXED_OCCUPANCY_CONFLICT", "message": "construction conflicts with immutable fixed occupancy"})
		if _contains_cell(floor_state["constructed_cells"], cell):
			diagnostics.append({"code": "CELL_ALREADY_CONSTRUCTED", "message": "cell is already constructed"})
	if elevation != 0 and diagnostics.is_empty():
		var adjacent_elevation: int = elevation - 1 if elevation > 0 else elevation + 1
		var adjacent_floor_id: String = _floor_id_for_plot_elevation(plot_id, adjacent_elevation)
		var adjacent_floor: Dictionary = _floor_state(state, adjacent_floor_id, adjacent_elevation)
		for cell: Variant in cells:
			if adjacent_floor["constructed_cells"].is_empty() or _distance_to_set(cell, adjacent_floor["constructed_cells"]) > 2:
				diagnostics.append({"code": "ADJACENT_FOOTPRINT_LIMIT", "message": "upper or underground footprint may extend only two orthogonal tiles from adjacent construction"})
	if diagnostics.is_empty():
		for cell: Array in cells:
			floor_state["constructed_cells"].append([int(cell[0]), int(cell[1])])
		floor_state["constructed_cells"] = _sort_cells(floor_state["constructed_cells"])
		_upsert_floor_state(state, plot_id, floor_state)
		delta["affected_ids"].append(floor_id)
		delta["kind"] = "construction_committed"


func _apply_demolish_construction(intent: Dictionary, state: Dictionary, delta: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var floor_id: String = String(intent.get("floor_id", ""))
	var floor: Dictionary = _record_by_id(_snapshot.get_data().get("floors", []), floor_id)
	var cells: Array = intent.get("cells", [])
	if floor.is_empty() or cells.is_empty():
		diagnostics.append({"code": "DEMOLITION_ADDRESS_INVALID", "message": "demolition requires an explicit floor and cells"})
		return
	var floor_state: Dictionary = _floor_state(state, floor_id, int(floor["elevation"]))
	for cell: Variant in cells:
		if not _contains_cell(floor_state["constructed_cells"], cell):
			diagnostics.append({"code": "CONSTRUCTION_NOT_FOUND", "message": "demolition cell is not constructed"})
	if diagnostics.is_empty():
		var remaining: Array = []
		for existing: Array in floor_state["constructed_cells"]:
			if not _contains_cell(cells, existing):
				remaining.append(existing)
		floor_state["constructed_cells"] = remaining
		_upsert_floor_state(state, String(floor["plot_id"]), floor_state)
		delta["affected_ids"].append(floor_id)
		delta["kind"] = "construction_demolished"


func _apply_demolish_occupant(intent: Dictionary, state: Dictionary, delta: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var occupant_id: String = String(intent.get("fixed_occupant_id", ""))
	var occupant: Dictionary = _record_by_id(_snapshot.get_data().get("fixed_occupants", []), occupant_id)
	if occupant.is_empty():
		diagnostics.append({"code": "OCCUPANT_UNKNOWN", "message": "fixed occupant address is unknown"})
		return
	if bool(intent.get("partial", false)) or intent.has("cells"):
		diagnostics.append({"code": "PARTIAL_FIXED_DEMOLITION_UNSUPPORTED", "message": "fixed-occupant demolition addresses one whole stable identity"})
	if bool(intent.get("occupied_dependency", false)) or not intent.get("tenant_dependency_ids", []).is_empty():
		diagnostics.append({"code": "OCCUPIED_DEPENDENCY", "message": "occupied zone or tenant dependencies reject demolition in MVP"})
	var demolished: Array = state.get("demolished_fixed_occupant_ids", []).duplicate(true)
	if demolished.has(occupant_id):
		diagnostics.append({"code": "OCCUPANT_ALREADY_DEMOLISHED", "message": "fixed occupant is already demolished"})
		return
	demolished.append(occupant_id)
	demolished.sort()
	state["demolished_fixed_occupant_ids"] = demolished
	delta["affected_ids"].append(occupant_id)
	delta["kind"] = "fixed_occupant_demolished"


func _apply_set_manual_door(intent: Dictionary, candidate: Dictionary, delta: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var record_result: Dictionary = _manual_door_record_from_intent(intent)
	if not bool(record_result.get("valid", false)):
		diagnostics.append_array(record_result.get("diagnostics", []))
		return
	var record: Dictionary = record_result["record"]
	var endpoint_a: Dictionary = record["endpoint_a"]
	var endpoint_b: Dictionary = record["endpoint_b"]
	var from_cell: Dictionary = endpoint_a["local_cell"]
	var to_cell: Dictionary = endpoint_b["local_cell"]
	var floor_id: String = String(intent["floor_id"])
	var from_view: Dictionary = get_manual_door_district_view({"runtime_plot_id": endpoint_a["runtime_plot_id"], "floor_id": floor_id, "elevation": endpoint_a["signed_elevation"], "cell": [from_cell["x"], from_cell["y"]]}, candidate)
	var to_view: Dictionary = get_manual_door_district_view({"runtime_plot_id": endpoint_b["runtime_plot_id"], "floor_id": floor_id, "elevation": endpoint_b["signed_elevation"], "cell": [to_cell["x"], to_cell["y"]]}, candidate)
	for endpoint: Dictionary in [from_view, to_view]:
		if not bool(endpoint.get("resolved", false)):
			diagnostics.append({"code": "MANUAL_DOOR_ENDPOINT_UNRESOLVED", "message": "manual door endpoint is not in the resolved district"})
		elif not bool(endpoint.get("acquired", false)) or not bool(endpoint.get("constructed", false)):
			diagnostics.append({"code": "MANUAL_DOOR_ENDPOINT_NOT_BUILT", "message": "manual door endpoints require acquired and constructed floor cells"})
	if not diagnostics.is_empty():
		return
	var records: Array = candidate.get("manual_door_edges", []).duplicate(true)
	var identity: String = _manual_door_record_key(record)
	var existing_index: int = -1
	for index: int in range(records.size()):
		if records[index] is Dictionary and _manual_door_record_key(records[index]) == identity:
			existing_index = index
			break
	var enabled: bool = bool(intent.get("enabled", false))
	if enabled:
		if existing_index >= 0:
			diagnostics.append({"code": "MANUAL_DOOR_ALREADY_SET", "message": "manual door is already committed"})
			return
		records.append(record)
		delta["affected_ids"].append(identity)
	else:
		if existing_index < 0:
			diagnostics.append({"code": "MANUAL_DOOR_NOT_FOUND", "message": "manual door is not committed"})
			return
		records.remove_at(existing_index)
		delta["affected_ids"].append(identity)
	candidate["manual_door_edges"] = records
	delta["manual_door"] = record.duplicate(true)
	delta["enabled"] = enabled


func _manual_door_record_from_intent(intent: Dictionary) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	for key: String in ["runtime_plot_id", "floor_id", "elevation", "from_cell", "to_cell", "enabled"]:
		if not intent.has(key):
			diagnostics.append({"code": "MANUAL_DOOR_FIELD_REQUIRED", "message": "manual door intent requires %s" % key})
	if not diagnostics.is_empty():
		return {"valid": false, "diagnostics": diagnostics}
	if typeof(intent["runtime_plot_id"]) != TYPE_STRING or typeof(intent["floor_id"]) != TYPE_STRING or typeof(intent["elevation"]) != TYPE_INT or typeof(intent["enabled"]) != TYPE_BOOL:
		return {"valid": false, "diagnostics": [{"code": "MANUAL_DOOR_INTENT_TYPE_INVALID", "message": "manual door intent fields have invalid types"}]}
	var from_value: Variant = intent["from_cell"]
	var to_value: Variant = intent["to_cell"]
	if not from_value is Array or not to_value is Array or from_value.size() != 2 or to_value.size() != 2 or typeof(from_value[0]) != TYPE_INT or typeof(from_value[1]) != TYPE_INT or typeof(to_value[0]) != TYPE_INT or typeof(to_value[1]) != TYPE_INT:
		return {"valid": false, "diagnostics": [{"code": "MANUAL_DOOR_CELL_INVALID", "message": "manual door endpoints must be integer [x,y] pairs"}]}
	var from: Array = [int(from_value[0]), int(from_value[1])]
	var to: Array = [int(to_value[0]), int(to_value[1])]
	if from == to or absi(from[0] - to[0]) + absi(from[1] - to[1]) != 1:
		return {"valid": false, "diagnostics": [{"code": "MANUAL_DOOR_EDGE_INVALID", "message": "manual door endpoints must be orthogonally adjacent"}]}
	if from[1] > to[1] or (from[1] == to[1] and from[0] > to[0]):
		var swap: Array = from
		from = to
		to = swap
	var plot_id: String = String(intent["runtime_plot_id"])
	var elevation: int = int(intent["elevation"])
	return {"valid": true, "record": {"endpoint_a": {"runtime_plot_id": plot_id, "signed_elevation": elevation, "local_cell": {"x": from[0], "y": from[1]}}, "endpoint_b": {"runtime_plot_id": plot_id, "signed_elevation": elevation, "local_cell": {"x": to[0], "y": to[1]}}}, "diagnostics": []}


func _manual_door_record_key(record: Dictionary) -> String:
	var endpoint_a: Dictionary = record.get("endpoint_a", {})
	var endpoint_b: Dictionary = record.get("endpoint_b", {})
	return "%s|%s" % [_manual_door_endpoint_key(endpoint_a), _manual_door_endpoint_key(endpoint_b)]


func _manual_door_endpoint_key(endpoint: Dictionary) -> String:
	var cell: Dictionary = endpoint.get("local_cell", {})
	return "%s|%+011d|%011d|%011d" % [String(endpoint.get("runtime_plot_id", "")), int(endpoint.get("signed_elevation", 0)), int(cell.get("y", -1)), int(cell.get("x", -1))]


func _apply_paint_zone(intent: Dictionary, delta: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var zone_type: String = String(intent.get("zone_type", ""))
	var cells: Array = intent.get("cells", [])
	if zone_type.is_empty() or cells.is_empty():
		diagnostics.append({"code": "ZONE_PAINT_INPUT_INVALID", "message": "zone paint requires a type and one or more explicit cells"})
		return
	if not intent.has("runtime_plot_id") or not intent.has("floor_id") or not intent.has("elevation"):
		diagnostics.append({"code": "ZONE_PAINT_ADDRESS_REQUIRED", "message": "zone paint requires an explicit plot and floor address"})
		return
	delta["affected_ids"].append(String(intent.get("runtime_plot_id", "")))
	delta["kind"] = "zone_painted"


func _apply_convert_street(intent: Dictionary, state: Dictionary, delta: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var street_id: String = String(intent.get("street_segment_id", ""))
	var states: Array = state.get("street_segment_states", []).duplicate(true)
	for existing: Dictionary in states:
		if String(existing.get("street_segment_id", "")) == street_id:
			if bool(existing.get("converted", false)):
				diagnostics.append({"code": "STREET_ALREADY_CONVERTED", "message": "street segment is already converted"})
				return
			existing["converted"] = true
			states.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["street_segment_id"]) < String(right["street_segment_id"]))
			state["street_segment_states"] = states
			delta["affected_ids"].append(street_id)
			delta["kind"] = "street_converted"
			return
	states.append({"street_segment_id": street_id, "converted": true})
	states.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["street_segment_id"]) < String(right["street_segment_id"]))
	state["street_segment_states"] = states
	delta["affected_ids"].append(street_id)
	delta["kind"] = "street_converted"


func _physical_range_for_floor(floor: Dictionary, plot_id: String) -> Dictionary:
	var plot: Dictionary = _record_by_id(_snapshot.get_data().get("plots", []), plot_id)
	if not plot.is_empty():
		return plot.get("physical_elevation_cap", {})
	return {"minimum_elevation": -5, "maximum_elevation": 9}


func _normalize_economy_intent(intent: Dictionary) -> void:
	var operation: String = String(intent.get("operation", ""))
	match operation:
		OP_ACQUIRE_SECTION:
			intent["charge_category"] = "PLOT_SECTION"
			var section: Dictionary = _record_by_id(_snapshot.get_data().get("sections", []), String(intent.get("runtime_section_id", "")))
			intent["section_tile_count"] = section.get("mask", []).size()
		OP_ACQUIRE_SPACE:
			intent["charge_category"] = "VERTICAL_SPACE"
			intent["tile_count"] = intent.get("cells", []).size()
		OP_CONVERT_STREET:
			intent["charge_category"] = "STREET_CONVERSION"
			var street: Dictionary = _record_by_id(_snapshot.get_data().get("street_segments", []), String(intent.get("street_segment_id", "")))
			var rect: Dictionary = street.get("rect_quarter", {})
			intent["street_corridor_tile_count"] = maxi(0, ((int(rect.get("maximum_x4", 0)) - int(rect.get("minimum_x4", 0))) / 4) * ((int(rect.get("maximum_z4", 0)) - int(rect.get("minimum_z4", 0))) / 4))
		OP_DEMOLISH_FIXED_OCCUPANT:
			intent["charge_category"] = "FIXED_DEMOLITION"
		_:
			intent["charge_category"] = "NO_CHARGE"


func _apply_source_enabled(intent: Dictionary, state: Dictionary, delta: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var source_id: String = String(intent.get("arrival_source_id", ""))
	var source: Dictionary = _record_by_authored_id(_snapshot.get_data().get("arrival_source_attachments", []), source_id)
	if source.is_empty():
		diagnostics.append({"code": "SOURCE_UNKNOWN", "message": "arrival source address is unknown"})
		return
	var enabled: bool = bool(intent.get("enabled", false))
	if enabled == bool(source.get("initially_enabled", false)):
		diagnostics.append({"code": "SOURCE_BASELINE_STATE", "message": "baseline source state must be omitted"})
		return
	var states: Array = state.get("arrival_source_states", []).duplicate(true)
	states.append({"arrival_source_id": source_id, "enabled": enabled})
	states.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["arrival_source_id"]) < String(right["arrival_source_id"]))
	state["arrival_source_states"] = states
	delta["affected_ids"].append(source_id)
	delta["kind"] = "arrival_source_changed"


func _quote(evaluation: Dictionary) -> Dictionary:
	if _ports == null or _ports.economy == null:
		return {"accepted": false, "diagnostics": [{"code": "ECONOMY_POLICY_UNAVAILABLE", "message": "Economy authority is required for every district transaction"}]}
	var transaction: Dictionary = {
		"intent": evaluation.get("intent", {}).duplicate(true),
		"delta": evaluation.get("delta", {}).duplicate(true),
		"candidate_state": evaluation.get("state", {}).duplicate(true),
		"economy_policy_snapshot": _ports.economy.get_policy_snapshot(),
		"progression_policy_snapshot": evaluation.get("policy_snapshot", {}).duplicate(true),
		"construction_policy_snapshot": get_construction_policy_snapshot(),
	}
	return _ports.economy.quote(transaction, evaluation.get("state", {}))


func _economy_reserve(quote: Dictionary) -> Dictionary:
	if _ports == null or _ports.economy == null:
		return {"accepted": true, "reservation_token": {}, "diagnostics": []}
	return _ports.economy.reserve(quote)


func _economy_guarantee(reservation: Dictionary) -> Dictionary:
	if _ports == null or _ports.economy == null:
		return {"accepted": true, "guaranteed_capture_token": reservation, "diagnostics": []}
	return _ports.economy.guarantee_capture(reservation)


func _economy_capture(guaranteed: Dictionary) -> Dictionary:
	if _ports == null or _ports.economy == null:
		return {"accepted": true, "diagnostics": []}
	return _ports.economy.capture(guaranteed)


func _economy_cancel(reservation: Dictionary) -> void:
	if _ports != null and _ports.economy != null and not reservation.is_empty():
		_ports.economy.cancel(reservation)


func _flush_authority_notifications() -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	if _ports != null and _ports.economy != null:
		diagnostics.append_array(_ports.economy.flush_notifications())
	if _ports != null and _ports.zone != null:
		diagnostics.append_array(_ports.zone.flush_notifications())
	return diagnostics


func _zone_preview(intent: Dictionary, candidate_state: Dictionary) -> Dictionary:
	if _zone_transaction_is_noop(intent):
		return {"accepted": true, "preview": null, "district_effects": {}, "diagnostics": []}
	if _ports == null or _ports.zone == null:
		return {"accepted": true, "preview": null, "district_effects": {}, "diagnostics": []}
	var spatial_result: Dictionary = _derive_zone_spatial_snapshot(intent, candidate_state)
	if not bool(spatial_result.get("valid", false)):
		return {"accepted": false, "diagnostics": spatial_result.get("diagnostics", [])}
	var access_result: Dictionary = PublicBandAccessSnapshot.derive(_snapshot, candidate_state, int(candidate_state.get("district_revision", -1)))
	if not bool(access_result.get("valid", false)):
		return {"accepted": false, "diagnostics": access_result.get("diagnostics", [])}
	var zone_plan: Dictionary = _ports.zone.preview(
		intent,
		_zone_district_ref(candidate_state),
		spatial_result.get("snapshot") as DistrictZoneSpatialSnapshot,
		access_result.get("snapshot") as PublicBandAccessSnapshot
	)
	if not bool(zone_plan.get("accepted", false)):
		return zone_plan
	var effects_result: Dictionary = _apply_zone_district_effects(intent, candidate_state, zone_plan.get("district_effects", {}))
	if not bool(effects_result.get("valid", false)):
		return {"accepted": false, "diagnostics": effects_result.get("diagnostics", [])}
	return zone_plan


func _publish_zone_door_access(zone_commit: Dictionary) -> void:
	if _traversal_view == null or not zone_commit.has("door_access_edges"):
		return
	var refreshed := DistrictTraversalReadView.new()
	refreshed.initialize(
		_snapshot.get_fingerprint(),
		get_revision(),
		_ports.zone.get_revision() if _ports != null and _ports.zone != null else _traversal_view.zone_revision,
		_traversal_view.floor_circulation_edges,
		zone_commit.get("door_access_edges", []),
		_traversal_view.vertical_links
	)
	if bool(refreshed.validate(_snapshot).get("valid", false)):
		_traversal_view = refreshed


func _zone_prepare(intent: Dictionary, candidate_state: Dictionary) -> Dictionary:
	if _zone_transaction_is_noop(intent):
		return {
			"accepted": true,
			"prepare_token": {"kind": "ZONE_NOOP", "operation": String(intent.get("operation", "")), "mutated": false},
			"diagnostics": [],
		}
	if _ports == null or _ports.zone == null:
		return {"accepted": true, "prepare_token": {}, "diagnostics": []}
	var base_spatial_result: Dictionary = _derive_zone_spatial_snapshot(intent, candidate_state)
	if not bool(base_spatial_result.get("valid", false)):
		return {"accepted": false, "diagnostics": base_spatial_result.get("diagnostics", [])}
	var base_access_result: Dictionary = PublicBandAccessSnapshot.derive(_snapshot, candidate_state, int(candidate_state.get("district_revision", -1)))
	if not bool(base_access_result.get("valid", false)):
		return {"accepted": false, "diagnostics": base_access_result.get("diagnostics", [])}
	var zone_plan: Dictionary = _ports.zone.preview(
		intent,
		_zone_district_ref(candidate_state),
		base_spatial_result.get("snapshot") as DistrictZoneSpatialSnapshot,
		base_access_result.get("snapshot") as PublicBandAccessSnapshot
	)
	if not bool(zone_plan.get("accepted", false)):
		return zone_plan
	var effects_result: Dictionary = _apply_zone_district_effects(intent, candidate_state, zone_plan.get("district_effects", {}))
	if not bool(effects_result.get("valid", false)):
		return {"accepted": false, "diagnostics": effects_result.get("diagnostics", [])}
	var prospective_spatial_result: Dictionary = _derive_zone_spatial_snapshot(intent, candidate_state)
	if not bool(prospective_spatial_result.get("valid", false)):
		return {"accepted": false, "diagnostics": prospective_spatial_result.get("diagnostics", [])}
	var prospective_access_result: Dictionary = PublicBandAccessSnapshot.derive(_snapshot, candidate_state, int(candidate_state.get("district_revision", -1)))
	if not bool(prospective_access_result.get("valid", false)):
		return {"accepted": false, "diagnostics": prospective_access_result.get("diagnostics", [])}
	return _ports.zone.prepare(
		intent,
		_zone_district_ref(candidate_state),
		prospective_spatial_result.get("snapshot") as DistrictZoneSpatialSnapshot,
		prospective_access_result.get("snapshot") as PublicBandAccessSnapshot,
		zone_plan
	)


func _apply_zone_district_effects(
	intent: Dictionary,
	candidate_state: Dictionary,
	effects: Dictionary
) -> Dictionary:
	if effects.is_empty():
		return {"valid": true, "diagnostics": []}
	var expected_keys: Array[String] = ["remove_explicit_circulation_cells", "add_explicit_circulation_cells", "remove_manual_door_edges"]
	if effects.size() != expected_keys.size():
		return {"valid": false, "diagnostics": [{"code": "INVALID_DISTRICT_ZONE_EFFECTS"}]}
	for key: String in expected_keys:
		if not effects.has(key) or not effects[key] is Array:
			return {"valid": false, "diagnostics": [{"code": "INVALID_DISTRICT_ZONE_EFFECTS"}]}
	var intent_cells: Dictionary = {}
	for value: Variant in intent.get("cells", []):
		if not value is Array or value.size() != 2 or not value[0] is int or not value[1] is int:
			return {"valid": false, "diagnostics": [{"code": "INVALID_DISTRICT_ZONE_EFFECTS"}]}
		intent_cells["%d,%d" % [int(value[0]), int(value[1])]] = true
	var plot_id: String = String(intent.get("runtime_plot_id", ""))
	var floor_id: String = String(intent.get("floor_id", ""))
	var elevation: int = int(intent.get("elevation", 0))
	var floor_state: Dictionary = _floor_state(candidate_state, floor_id, elevation).duplicate(true)
	var circulation: Array = floor_state.get("explicit_circulation_cells", []).duplicate(true)
	var paint_mode: String = String(intent.get("paint_mode", "zone"))
	var circulation_changed: bool = false
	for cell_value: Variant in effects["remove_explicit_circulation_cells"]:
		var parsed: Dictionary = _zone_effect_cell(cell_value, intent_cells)
		if not bool(parsed.get("valid", false)) or paint_mode == "none":
			return {"valid": false, "diagnostics": [{"code": "INVALID_DISTRICT_ZONE_EFFECTS"}]}
		var pair: Array = parsed["pair"]
		if not circulation.has(pair):
			return {"valid": false, "diagnostics": [{"code": "INVALID_DISTRICT_ZONE_EFFECTS"}]}
		circulation.erase(pair)
		circulation_changed = true
	for cell_value: Variant in effects["add_explicit_circulation_cells"]:
		var parsed: Dictionary = _zone_effect_cell(cell_value, intent_cells)
		if not bool(parsed.get("valid", false)) or paint_mode != "none":
			return {"valid": false, "diagnostics": [{"code": "INVALID_DISTRICT_ZONE_EFFECTS"}]}
		var pair: Array = parsed["pair"]
		if not floor_state.get("acquired_cells", []).has(pair) or not floor_state.get("constructed_cells", []).has(pair) or circulation.has(pair):
			return {"valid": false, "diagnostics": [{"code": "INVALID_DISTRICT_ZONE_EFFECTS"}]}
		circulation.append(pair)
		circulation_changed = true
	floor_state["explicit_circulation_cells"] = _sort_cells(circulation)
	_upsert_floor_state(candidate_state, plot_id, floor_state)
	if circulation_changed:
		candidate_state["construction_revision"] = int(candidate_state.get("construction_revision", 0)) + 1
	var manual_edges: Array = candidate_state.get("manual_door_edges", []).duplicate(true)
	for edge_value: Variant in effects["remove_manual_door_edges"]:
		if not edge_value is Dictionary:
			return {"valid": false, "diagnostics": [{"code": "INVALID_DISTRICT_ZONE_EFFECTS"}]}
		var requested_key: String = _manual_door_record_key(edge_value)
		var remove_index: int = -1
		for index: int in range(manual_edges.size()):
			if manual_edges[index] is Dictionary and _manual_door_record_key(manual_edges[index]) == requested_key:
				remove_index = index
				break
		if requested_key.is_empty() or remove_index < 0:
			return {"valid": false, "diagnostics": [{"code": "INVALID_DISTRICT_ZONE_EFFECTS"}]}
		manual_edges.remove_at(remove_index)
	candidate_state["manual_door_edges"] = manual_edges
	var sorted_state: Dictionary = _sort_state(candidate_state)
	candidate_state.clear()
	candidate_state.merge(sorted_state, true)
	var state_validation: Dictionary = _state_records.validate(candidate_state, _snapshot)
	if not bool(state_validation.get("valid", false)):
		return {"valid": false, "diagnostics": state_validation.get("diagnostics", [])}
	return {"valid": true, "diagnostics": []}


func _zone_district_ref(candidate_state: Dictionary) -> Dictionary:
	return {
		"layout_id": String(candidate_state.get("layout_id", "")),
		"layout_definition_version": int(candidate_state.get("layout_definition_version", -1)),
		"definition_fingerprint": String(candidate_state.get("definition_fingerprint", "")),
		"district_revision": int(candidate_state.get("district_revision", -1)),
	}


func _zone_effect_cell(value: Variant, intent_cells: Dictionary) -> Dictionary:
	if not value is Dictionary or value.size() != 2 or not value.has("x") or not value.has("y") or not value["x"] is int or not value["y"] is int:
		return {"valid": false}
	var key: String = "%d,%d" % [int(value["x"]), int(value["y"])]
	if not intent_cells.has(key):
		return {"valid": false}
	return {"valid": true, "pair": [int(value["x"]), int(value["y"])]}


## Return the current immutable zone-painting spatial context for a floor.
## This is read-only and keeps tool eligibility checks on the District Runtime path.
func get_zone_spatial_snapshot(address: Dictionary) -> DistrictZoneSpatialSnapshot:
	if not has_session() or address.is_empty():
		return null
	var runtime_plot_id: String = String(address.get("runtime_plot_id", ""))
	var floor_id: String = String(address.get("floor_id", ""))
	if runtime_plot_id.is_empty() or floor_id.is_empty() or not address.has("elevation"):
		return null
	var elevation: int = int(address.get("elevation", 0))
	var floor_label: String = "G" if elevation == 0 else ("F%d" % elevation if elevation > 0 else "B%d" % absi(elevation))
	var captured: Dictionary = get_state_read()
	var candidate_state: Dictionary = captured.get("state", {}) as Dictionary
	var intent: Dictionary = {
		"operation": OP_PAINT_ZONE,
		"runtime_plot_id": runtime_plot_id,
		"floor_id": floor_id,
		"elevation": elevation,
		"zone_plot_id": runtime_plot_id,
		"zone_floor_label": floor_label,
	}
	var result: Dictionary = _derive_zone_spatial_snapshot(intent, candidate_state)
	return result.get("snapshot") as DistrictZoneSpatialSnapshot if bool(result.get("valid", false)) else null


func _derive_zone_spatial_snapshot(intent: Dictionary, candidate_state: Dictionary) -> Dictionary:
	if String(intent.get("operation", "")) != OP_PAINT_ZONE and String(intent.get("operation", "")) != OP_SET_MANUAL_DOOR:
		return {"valid": true, "snapshot": null, "diagnostics": []}
	if not intent.has("floor_id") or not intent.has("runtime_plot_id") or not intent.has("elevation"):
		return {"valid": false, "diagnostics": [{"code": "DISTRICT_ZONE_SPATIAL_SCOPE_MISMATCH", "message": "Zone coordination requires an explicit floor scope"}]}
	return DistrictZoneSpatialSnapshot.derive(
		_snapshot,
		candidate_state,
		{
			"floor_id": String(intent.get("floor_id", "")),
			"runtime_plot_id": String(intent.get("runtime_plot_id", "")),
			"signed_elevation": int(intent.get("elevation", 0)),
		}
	)


static func _zone_transaction_is_noop(intent: Dictionary) -> bool:
	var operation: String = String(intent.get("operation", ""))
	return operation == OP_ACQUIRE_SPACE or (
		operation == OP_CONSTRUCT
		and String(intent.get("construction_kind", "")) == "corridor"
	)


func _zone_commit(prepare_result: Dictionary) -> Dictionary:
	var prepare_token: Dictionary = prepare_result.get("prepare_token", prepare_result)
	if String(prepare_token.get("kind", "")) == "ZONE_NOOP":
		return {"accepted": true, "diagnostics": []}
	if _ports == null or _ports.zone == null:
		return {"accepted": true, "diagnostics": []}
	return _ports.zone.commit(prepare_result)


func _zone_undo(prepare_result: Dictionary) -> void:
	var prepare_token: Dictionary = prepare_result.get("prepare_token", prepare_result)
	if String(prepare_token.get("kind", "")) == "ZONE_NOOP":
		return
	if _ports != null and _ports.zone != null and not prepare_result.is_empty():
		_ports.zone.undo(prepare_result)


func _policy_snapshot() -> Dictionary:
	if _ports == null or _ports.progression == null:
		return {}
	return _ports.progression.get_policy_snapshot().duplicate(true)


func _capture_revisions(policy: Dictionary) -> Dictionary:
	return {
		"district_revision": get_revision(),
		"economy_revision": 0 if _ports == null or _ports.economy == null else _ports.economy.get_revision(),
		"economy_policy_revision": -1 if _ports == null or _ports.economy == null else int(_ports.economy.get_policy_snapshot().get("revision", -1)),
		"zone_revision": 0 if _ports == null or _ports.zone == null else _ports.zone.get_revision(),
		"progression_revision": int(policy.get("revision", -1)),
		"construction_policy_revision": -1 if _construction_policy == null else _construction_policy.get_revision(),
	}


func _revalidate(revisions: Dictionary) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	if get_revision() != int(revisions.get("district_revision", -1)):
		diagnostics.append({"code": "STALE_DISTRICT_REVISION", "message": "district changed while transaction was preparing"})
	if _ports != null and _ports.economy != null and _ports.economy.get_revision() != int(revisions.get("economy_revision", -1)):
		diagnostics.append({"code": "STALE_ECONOMY_REVISION", "message": "economy changed while transaction was preparing"})
	if _ports != null and _ports.economy != null and int(_ports.economy.get_policy_snapshot().get("revision", -1)) != int(revisions.get("economy_policy_revision", -2)):
		diagnostics.append({"code": "STALE_ECONOMY_POLICY_REVISION", "message": "economy policy changed while transaction was preparing"})
	if _ports != null and _ports.zone != null and _ports.zone.get_revision() != int(revisions.get("zone_revision", -1)):
		diagnostics.append({"code": "STALE_ZONE_REVISION", "message": "ZoneManager changed while transaction was preparing"})
	if _ports != null and _ports.progression != null and int(_ports.progression.get_policy_snapshot().get("revision", -1)) != int(revisions.get("progression_revision", -2)):
		diagnostics.append({"code": "STALE_PROGRESSION_REVISION", "message": "progression policy changed while transaction was preparing"})
	if _construction_policy == null or _construction_policy.get_revision() != int(revisions.get("construction_policy_revision", -2)):
		diagnostics.append({"code": "STALE_CONSTRUCTION_INTENT", "message": "construction policy changed while transaction was preparing"})
	return diagnostics


func _build_envelope(candidate_state: Dictionary, delta: Dictionary, revisions: Dictionary, guaranteed: Dictionary) -> Dictionary:
	return {
		"commit_id": "district_commit_%d" % (_transaction_counter),
		"previous_district_revision": get_revision(),
		"district_revision": int(candidate_state.get("district_revision", 0)),
		"delta": delta.duplicate(true),
		"revisions": revisions.duplicate(true),
		"construction_topology": _build_construction_topology(candidate_state, "district_commit_%d" % (_transaction_counter)),
		"guaranteed_capture": guaranteed.duplicate(true),
		"state": candidate_state.duplicate(true),
	}


func _abort(owner_token: String, reservation: Dictionary, prepare_token: Dictionary, diagnostics: Array) -> Dictionary:
	_zone_undo(prepare_token)
	_economy_cancel(reservation)
	_gate.release_barrier(owner_token)
	_gate.release(owner_token)
	return _reject_diagnostics(diagnostics)


func _make_empty_traversal_view(snapshot: ResolvedDistrictSnapshot, district_revision: int, zone_revision: int) -> DistrictTraversalReadView:
	var view: DistrictTraversalReadView = load("res://scripts/district/district_traversal_read_view.gd").new() as DistrictTraversalReadView
	view.initialize(snapshot.get_fingerprint(), district_revision, zone_revision, [], [], [])
	return view


func _refresh_traversal_revision() -> void:
	if _traversal_view == null or _snapshot == null:
		return
	var refreshed: DistrictTraversalReadView = load("res://scripts/district/district_traversal_read_view.gd").new() as DistrictTraversalReadView
	refreshed.initialize(_snapshot.get_fingerprint(), get_revision(), _traversal_view.zone_revision, _traversal_view.floor_circulation_edges, _traversal_view.door_access_edges, _traversal_view.vertical_links)
	_traversal_view = refreshed


func _build_construction_topology(state: Dictionary, commit_id: String) -> Dictionary:
	var projection: ConstructionTopologyProjection = load("res://scripts/construction/construction_topology_projection.gd").new() as ConstructionTopologyProjection
	var zone_revision: int = 0 if _traversal_view == null else _traversal_view.zone_revision
	return projection.build(_snapshot, state, zone_revision, commit_id)


func _publish_committed_topology(topology: Dictionary) -> void:
	if not bool(topology.get("valid", false)):
		return
	var prior_construction_topology: Dictionary = _construction_topology.duplicate(true)
	if _traversal_view != null and _snapshot != null:
		var prior_floor_edge_ids: Dictionary = {}
		for edge: Dictionary in prior_construction_topology.get("floor_circulation_edges", []):
			prior_floor_edge_ids[String(edge.get("edge_id", ""))] = true
		var floor_edges: Array = _traversal_view.floor_circulation_edges.duplicate(true)
		for edge: Dictionary in topology.get("floor_circulation_edges", []):
			if not prior_floor_edge_ids.has(String(edge.get("edge_id", ""))):
				floor_edges.append(edge.duplicate(true))
		var prior_vertical_link_ids: Dictionary = {}
		for link: Dictionary in prior_construction_topology.get("vertical_links", []):
			prior_vertical_link_ids[String(link.get("link_id", ""))] = true
		var vertical_links: Array = _traversal_view.vertical_links.duplicate(true)
		for link: Dictionary in topology.get("vertical_links", []):
			if not prior_vertical_link_ids.has(String(link.get("link_id", ""))):
				vertical_links.append(link.duplicate(true))
		var refreshed: DistrictTraversalReadView = load("res://scripts/district/district_traversal_read_view.gd").new() as DistrictTraversalReadView
		refreshed.initialize(_snapshot.get_fingerprint(), get_revision(), _traversal_view.zone_revision, floor_edges, _traversal_view.door_access_edges, vertical_links)
		_traversal_view = refreshed
	_construction_topology = topology.duplicate(true)
	construction_topology_published.emit(_construction_topology.duplicate(true))


func _rebuild_construction_topology(commit_id: String) -> void:
	if _snapshot == null or _state.is_empty():
		return
	_publish_committed_topology(_build_construction_topology(_state, commit_id))


func _reject(code: String, message: String) -> Dictionary:
	return _reject_diagnostics([{"code": code, "message": message}])


func _reject_diagnostics(diagnostics: Array) -> Dictionary:
	var typed: Array[Dictionary] = []
	for diagnostic: Variant in diagnostics:
		if diagnostic is Dictionary:
			typed.append(diagnostic)
	transaction_rejected.emit(typed)
	return {"valid": false, "snapshot": null, "diagnostics": typed}


func _evaluation_failure(code: String, message: String) -> Dictionary:
	return {"valid": false, "diagnostics": [{"code": code, "message": message}]}


func _evaluation_failure_diagnostics(values: Array) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	for value: Variant in values:
		if value is Dictionary:
			diagnostics.append(value.duplicate(true))
	return {"valid": false, "diagnostics": diagnostics}


func _record_by_id(records: Array, id: String) -> Dictionary:
	for record: Variant in records:
		if record is Dictionary and String(record.get("id", "")) == id:
			return record
	return {}


func _record_by_authored_id(records: Array, authored_id: String) -> Dictionary:
	for record: Variant in records:
		if record is Dictionary and String(record.get("authored_id", "")) == authored_id:
			return record
	return {}


func _ensure_plot_state(state: Dictionary, plot_id: String) -> Dictionary:
	for plot_state: Dictionary in state.get("plot_states", []):
		if String(plot_state.get("runtime_plot_id", "")) == plot_id:
			return plot_state
	var created: Dictionary = {"runtime_plot_id": plot_id, "section_state_overrides": [], "floor_states": []}
	state["plot_states"].append(created)
	return created


func _write_plot_state(state: Dictionary, plot_state: Dictionary) -> void:
	var plot_id: String = String(plot_state["runtime_plot_id"])
	for index: int in range(state["plot_states"].size()):
		if String(state["plot_states"][index].get("runtime_plot_id", "")) == plot_id:
			state["plot_states"][index] = plot_state
			return


func _section_owned(state: Dictionary, section_id: String, definition: Dictionary) -> bool:
	var override: Dictionary = _section_override(state, section_id)
	return bool(override.get("owned", definition.get("initially_owned", false)))


func _section_available(state: Dictionary, section_id: String, definition: Dictionary) -> bool:
	var override: Dictionary = _section_override(state, section_id)
	return bool(override.get("available", definition.get("initially_available", false)))


func _section_override(state: Dictionary, section_id: String) -> Dictionary:
	for plot_state: Dictionary in state.get("plot_states", []):
		for override: Dictionary in plot_state.get("section_state_overrides", []):
			if String(override.get("runtime_section_id", "")) == section_id:
				return override
	return {}


func _plot_active(state: Dictionary, plot_id: String) -> bool:
	for section: Dictionary in _snapshot.get_data().get("sections", []):
		if String(section.get("plot_id", "")) == plot_id and _section_owned(state, String(section["id"]), section):
			return true
	return false


func _has_runtime_accessible_adjacent_plot(state: Dictionary, plot_id: String, selected_plot_ids: Array) -> bool:
	var target: Dictionary = _record_by_id(_snapshot.get_data().get("plots", []), plot_id)
	if target.is_empty():
		return false
	for candidate: Dictionary in _snapshot.get_data().get("plots", []):
		var candidate_id: String = String(candidate.get("id", ""))
		if candidate_id == plot_id:
			continue
		if not selected_plot_ids.has(candidate_id) and not _plot_active(state, candidate_id):
			continue
		if _plots_adjacent(target, candidate):
			return true
	return false


func _has_active_adjacent_plot(state: Dictionary, plot_id: String) -> bool:
	var target: Dictionary = _record_by_id(_snapshot.get_data().get("plots", []), plot_id)
	if target.is_empty():
		return false
	for candidate: Dictionary in _snapshot.get_data().get("plots", []):
		if String(candidate["id"]) == plot_id or not _plot_active(state, String(candidate["id"])):
			continue
		if _plots_adjacent(target, candidate):
			return true
	return false


func _plots_adjacent(left: Dictionary, right: Dictionary) -> bool:
	var left_slot: Dictionary = _record_by_id(_snapshot.get_data().get("slots", []), String(left.get("slot_id", "")))
	var right_slot: Dictionary = _record_by_id(_snapshot.get_data().get("slots", []), String(right.get("slot_id", "")))
	if left_slot.is_empty() or right_slot.is_empty():
		return false
	var same_row: bool = String(left_slot.get("row_track_id", "")) == String(right_slot.get("row_track_id", ""))
	var same_column: bool = String(left_slot.get("column_track_id", "")) == String(right_slot.get("column_track_id", ""))
	var column_step: int = absi(_track_ordinal(String(left_slot.get("column_track_id", ""))) - _track_ordinal(String(right_slot.get("column_track_id", ""))))
	var row_step: int = absi(_track_ordinal(String(left_slot.get("row_track_id", ""))) - _track_ordinal(String(right_slot.get("row_track_id", ""))))
	return (same_row and column_step == 1) or (same_column and row_step == 1)


func _track_ordinal(track_id: String) -> int:
	var parts: PackedStringArray = track_id.split("_")
	return 0 if parts.size() < 2 else int(parts[1])


func _floor_state(state: Dictionary, floor_id: String, elevation: int) -> Dictionary:
	for plot_state: Dictionary in state.get("plot_states", []):
		for floor_state: Dictionary in plot_state.get("floor_states", []):
			if String(floor_state.get("floor_id", "")) == floor_id:
				return floor_state
	return {"floor_id": floor_id, "elevation": elevation, "acquired_cells": [], "constructed_cells": [], "explicit_circulation_cells": []}


func _upsert_floor_state(state: Dictionary, plot_id: String, floor_state: Dictionary) -> void:
	var plot_state: Dictionary = _ensure_plot_state(state, plot_id)
	for index: int in range(plot_state["floor_states"].size()):
		if String(plot_state["floor_states"][index].get("floor_id", "")) == String(floor_state["floor_id"]):
			plot_state["floor_states"][index] = floor_state
			_write_plot_state(state, plot_state)
			return
	plot_state["floor_states"].append(floor_state)
	_write_plot_state(state, plot_state)


func _floor_id_for_plot_elevation(plot_id: String, elevation: int) -> String:
	for floor: Dictionary in _snapshot.get_data().get("floors", []):
		if String(floor.get("plot_id", "")) == plot_id and int(floor.get("elevation", 999)) == elevation:
			return String(floor["id"])
	return ""


func _cell_acquired_at_adjacent_elevation(state: Dictionary, plot_id: String, elevation: int, cell: Array) -> bool:
	var adjacent: int = elevation - 1 if elevation > 0 else elevation + 1
	var floor_id: String = _floor_id_for_plot_elevation(plot_id, adjacent)
	if floor_id.is_empty():
		return false
	return _contains_cell(_floor_state(state, floor_id, adjacent)["acquired_cells"], cell)


func _occupied_at(plot_id: String, elevation: int, cell: Array, state: Dictionary) -> bool:
	var data: Dictionary = _snapshot.get_data()
	for occupant: Dictionary in data.get("fixed_occupants", []):
		if state.get("demolished_fixed_occupant_ids", []).has(String(occupant["id"])):
			continue
		var slot_id: String = String(occupant.get("runtime_slot_id", ""))
		var slot: Dictionary = _record_by_id(data.get("slots", []), slot_id)
		if slot.is_empty() or not _slot_matches_plot(slot, plot_id):
			continue
		for elevation_mask: Dictionary in occupant.get("elevation_masks", []):
			if int(elevation_mask.get("elevation", 999)) == elevation and _mask_contains(elevation_mask.get("mask", []), cell):
				return true
	return false


func _slot_matches_plot(slot: Dictionary, plot_id: String) -> bool:
	for plot: Dictionary in _snapshot.get_data().get("plots", []):
		if String(plot.get("slot_id", "")) == String(slot.get("id", "")) and String(plot.get("id", "")) == plot_id:
			return true
	return false


func _mask_contains(mask: Array, cell: Array) -> bool:
	for candidate: Array in mask:
		if candidate == cell:
			return true
	return false


func _contains_cell(cells: Array, expected: Array) -> bool:
	for cell: Variant in cells:
		if cell is Array and int(cell[0]) == int(expected[0]) and int(cell[1]) == int(expected[1]):
			return true
	return false


func _sort_cells(cells: Array) -> Array:
	var result: Array = cells.duplicate(true)
	result.sort_custom(func(left: Array, right: Array) -> bool: return left[1] < right[1] or (left[1] == right[1] and left[0] < right[0]))
	return result


func _distance_to_set(cell: Array, cells: Array) -> int:
	var distance: int = 2147483647
	for candidate: Array in cells:
		distance = mini(distance, absi(int(cell[0]) - int(candidate[0])) + absi(int(cell[1]) - int(candidate[1])))
	return distance


func _sort_state(state: Dictionary) -> Dictionary:
	var result: Dictionary = state.duplicate(true)
	result["plot_states"].sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["runtime_plot_id"]) < String(right["runtime_plot_id"]))
	for plot_state: Dictionary in result["plot_states"]:
		plot_state["section_state_overrides"].sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["runtime_section_id"]) < String(right["runtime_section_id"]))
		plot_state["floor_states"].sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left["elevation"]) < int(right["elevation"]) or (int(left["elevation"]) == int(right["elevation"]) and String(left["floor_id"]) < String(right["floor_id"])) )
		for floor_state: Dictionary in plot_state["floor_states"]:
			floor_state["acquired_cells"] = _sort_cells(floor_state["acquired_cells"])
			floor_state["constructed_cells"] = _sort_cells(floor_state["constructed_cells"])
			floor_state["explicit_circulation_cells"] = _sort_cells(floor_state["explicit_circulation_cells"])
	result["street_segment_states"].sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["street_segment_id"]) < String(right["street_segment_id"]))
	result["arrival_source_states"].sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["arrival_source_id"]) < String(right["arrival_source_id"]))
	result["demolished_fixed_occupant_ids"].sort()
	result["manual_door_edges"].sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return _manual_door_record_key(left) < _manual_door_record_key(right))
	return result
