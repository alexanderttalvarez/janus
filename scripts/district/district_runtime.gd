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

const OP_ACQUIRE_SECTION: String = "ACQUIRE_SECTION"
const OP_ACQUIRE_SPACE: String = "ACQUIRE_SPACE"
const OP_CONSTRUCT: String = "CONSTRUCT"
const OP_DEMOLISH_CONSTRUCTION: String = "DEMOLISH_CONSTRUCTION"
const OP_DEMOLISH_FIXED_OCCUPANT: String = "DEMOLISH_FIXED_OCCUPANT"
const OP_SET_SOURCE_ENABLED: String = "SET_SOURCE_ENABLED"
const OP_CONVERT_STREET: String = "CONVERT_STREET"
const OP_PAINT_ZONE: String = "PAINT_ZONE"

var _snapshot: ResolvedDistrictSnapshot
var _state: Dictionary = {}
var _ports: DistrictRuntimePorts.DistrictRuntimePortsBundle
var _journal: DistrictCommitJournal = DistrictCommitJournal.new()
var _dispatcher: DistrictCommitDispatcher = DistrictCommitDispatcher.new()
var _gate: DistrictTransactionGate = DistrictTransactionGate.new()
var _transaction_counter: int = 0
var _state_records: DistrictStateRecords = DistrictStateRecords.new()
var _traversal_view: DistrictTraversalReadView
var _street_conversion_validator: Callable
var _arrival_commit_gate: ArrivalCommitGate = ArrivalCommitGate.new()
var _arrival_token_counter: int = 0
var _arrival_topology_revision: int = -1
var _arrival_eligibility_revision: int = -1


func configure_ports(ports: DistrictRuntimePorts.DistrictRuntimePortsBundle) -> void:
	_ports = ports


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
	session_replaced.emit(snapshot.get_layout_id(), snapshot.get_fingerprint())
	return {"valid": true, "previous_layout_id": previous_layout_id, "state": get_state(), "diagnostics": []}


func dispose_session() -> Dictionary:
	if _snapshot == null:
		return {"valid": true, "diagnostics": []}
	var layout_id: String = _snapshot.get_layout_id()
	_snapshot = null
	_state = {}
	_traversal_view = null
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


func get_traversal_read_view() -> DistrictTraversalReadView:
	return null if _traversal_view == null else _traversal_view.duplicate_value()


## H3-owned injection point for committed traversal records. The records are
## validated against the current immutable snapshot and revision before swap.
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
func set_arrival_commit_gate(gate: ArrivalCommitGate) -> void:
	if gate != null:
		_arrival_commit_gate = gate


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
		"diagnostics": [],
	}


func commit_transaction(intent: Dictionary) -> Dictionary:
	if _arrival_commit_gate != null and _arrival_commit_gate.is_held():
		return _reject("ARRIVAL_TRANSACTION_BUSY", "district mutations are blocked while an arrival transaction is flushing")
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
		return _reject("TRANSACTION_BUSY", "another district transaction is active")
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
										_refresh_traversal_revision()
										envelope["state"] = get_state()
										if not _journal.append(envelope):
											_state = previous_state
											_zone_undo(prepare_token)
											result = _abort(owner_token, reservation, prepare_token, [{"code": "JOURNAL_APPEND_FAILED", "message": "journal append failed before commit point"}])
										else:
											committed = true
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
	var revisions: Dictionary = _capture_revisions(policy)
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
		OP_CONVERT_STREET:
			if not _street_conversion_validator.is_valid():
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
	return {"valid": true, "state": candidate, "delta": delta, "policy_snapshot": policy, "revisions": revisions, "intent": intent.duplicate(true), "diagnostics": []}


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
		if not bool(section.get("initially_entry_eligible", false)):
			diagnostics.append({"code": "ENTRY_SECTION_REQUIRED", "message": "inactive Plot must begin through an entry-eligible section"})
		elif not bool(intent.get("approved_initial_entry_context", false)) and not _has_active_adjacent_plot(state, plot_id):
			diagnostics.append({"code": "PLOT_NOT_ADJACENT", "message": "first section must be orthogonally adjacent to an Active Plot or approved initial context"})
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
	if cells.size() != 1:
		diagnostics.append({"code": "SEQUENTIAL_ACQUISITION_REQUIRED", "message": "vertical space is acquired one tile at a time"})
	if elevation < int(policy.get("minimum_elevation", -5)) or elevation > int(policy.get("maximum_elevation", 9)):
		diagnostics.append({"code": "PROGRESSION_CAP", "message": "progression policy does not permit this elevation"})
	if diagnostics.is_empty():
		var cell: Array = cells[0]
		var floor_state: Dictionary = _floor_state(state, String(intent["floor_id"]), elevation)
		if _contains_cell(floor_state["acquired_cells"], cell):
			diagnostics.append({"code": "CELL_ALREADY_ACQUIRED", "message": "cell is already acquired"})
		elif elevation != 0 and not _cell_acquired_at_adjacent_elevation(state, plot_id, elevation, cell):
			diagnostics.append({"code": "VERTICAL_SEQUENCE_REQUIRED", "message": "adjacent elevation must be acquired first"})
		else:
			floor_state["acquired_cells"].append([int(cell[0]), int(cell[1])])
			floor_state["acquired_cells"] = _sort_cells(floor_state["acquired_cells"])
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
	if elevation < int(policy.get("minimum_elevation", -5)) or elevation > int(policy.get("maximum_elevation", 9)):
		diagnostics.append({"code": "PROGRESSION_CAP", "message": "progression policy does not permit this elevation"})
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
	if _record_by_id(_snapshot.get_data().get("fixed_occupants", []), occupant_id).is_empty():
		diagnostics.append({"code": "OCCUPANT_UNKNOWN", "message": "fixed occupant address is unknown"})
		return
	var demolished: Array = state.get("demolished_fixed_occupant_ids", []).duplicate(true)
	if demolished.has(occupant_id):
		diagnostics.append({"code": "OCCUPANT_ALREADY_DEMOLISHED", "message": "fixed occupant is already demolished"})
		return
	demolished.append(occupant_id)
	demolished.sort()
	state["demolished_fixed_occupant_ids"] = demolished
	delta["affected_ids"].append(occupant_id)
	delta["kind"] = "fixed_occupant_demolished"


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
		return {"accepted": true, "value": 0, "economy_revision": 0, "diagnostics": []}
	return _ports.economy.quote({"intent": evaluation.get("intent", {}), "delta": evaluation.get("delta", {}), "candidate_state": evaluation.get("state", {})}, evaluation.get("state", {}))


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
	if _ports == null or _ports.zone == null:
		return {"accepted": true, "preview": null, "diagnostics": []}
	return _ports.zone.preview(intent, candidate_state)


func _zone_prepare(intent: Dictionary, candidate_state: Dictionary) -> Dictionary:
	if _ports == null or _ports.zone == null:
		return {"accepted": true, "prepare_token": {}, "diagnostics": []}
	return _ports.zone.prepare(intent, candidate_state)


func _zone_commit(prepare_token: Dictionary) -> Dictionary:
	if _ports == null or _ports.zone == null:
		return {"accepted": true, "diagnostics": []}
	return _ports.zone.commit(prepare_token)


func _zone_undo(prepare_token: Dictionary) -> void:
	if _ports != null and _ports.zone != null and not prepare_token.is_empty():
		_ports.zone.undo(prepare_token)


func _policy_snapshot() -> Dictionary:
	if _ports == null or _ports.progression == null:
		return {"revision": 0, "minimum_elevation": -5, "maximum_elevation": 9}
	return _ports.progression.get_policy_snapshot().duplicate(true)


func _capture_revisions(policy: Dictionary) -> Dictionary:
	return {
		"district_revision": get_revision(),
		"economy_revision": 0 if _ports == null or _ports.economy == null else _ports.economy.get_revision(),
		"zone_revision": 0 if _ports == null or _ports.zone == null else _ports.zone.get_revision(),
		"progression_revision": int(policy.get("revision", 0)),
	}


func _revalidate(revisions: Dictionary) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	if get_revision() != int(revisions.get("district_revision", -1)):
		diagnostics.append({"code": "STALE_DISTRICT_REVISION", "message": "district changed while transaction was preparing"})
	if _ports != null and _ports.economy != null and _ports.economy.get_revision() != int(revisions.get("economy_revision", -1)):
		diagnostics.append({"code": "STALE_ECONOMY_REVISION", "message": "economy changed while transaction was preparing"})
	if _ports != null and _ports.zone != null and _ports.zone.get_revision() != int(revisions.get("zone_revision", -1)):
		diagnostics.append({"code": "STALE_ZONE_REVISION", "message": "ZoneManager changed while transaction was preparing"})
	if _ports != null and _ports.progression != null and int(_ports.progression.get_policy_snapshot().get("revision", -1)) != int(revisions.get("progression_revision", -2)):
		diagnostics.append({"code": "STALE_PROGRESSION_REVISION", "message": "progression policy changed while transaction was preparing"})
	return diagnostics


func _build_envelope(candidate_state: Dictionary, delta: Dictionary, revisions: Dictionary, guaranteed: Dictionary) -> Dictionary:
	return {
		"commit_id": "district_commit_%d" % (_transaction_counter),
		"previous_district_revision": get_revision(),
		"district_revision": int(candidate_state.get("district_revision", 0)),
		"delta": delta.duplicate(true),
		"revisions": revisions.duplicate(true),
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
	return (String(left_slot["row_track_id"]) == String(right_slot["row_track_id"]) and absi(int(left_slot["ordinal"]) - int(right_slot["ordinal"])) == 1) or (String(left_slot["column_track_id"]) == String(right_slot["column_track_id"]) and absi(int(left_slot["ordinal"]) - int(right_slot["ordinal"])) == 1)


func _floor_state(state: Dictionary, floor_id: String, elevation: int) -> Dictionary:
	for plot_state: Dictionary in state.get("plot_states", []):
		for floor_state: Dictionary in plot_state.get("floor_states", []):
			if String(floor_state.get("floor_id", "")) == floor_id:
				return floor_state
	return {"floor_id": floor_id, "elevation": elevation, "acquired_cells": [], "constructed_cells": []}


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
	result["street_segment_states"].sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["street_segment_id"]) < String(right["street_segment_id"]))
	result["arrival_source_states"].sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["arrival_source_id"]) < String(right["arrival_source_id"]))
	result["demolished_fixed_occupant_ids"].sort()
	return result
