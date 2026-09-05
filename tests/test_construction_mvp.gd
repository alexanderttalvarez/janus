## Construction Handoff 01 focused contract tests.
extends SceneTree


class FakeProgression extends DistrictRuntimePorts.DistrictProgressionPort:
	func get_policy_snapshot() -> Dictionary:
		return {
			"schema_version": 1,
			"revision": 1,
			"elevation_eligibility": [0, 1, 2, -1, -2, -3],
			"construction_capabilities": ["corridor", "stairs", "elevator"],
			"selected_plot_ids": [],
			"god_mode": false,
		}


class RejectingZone extends DistrictRuntimePorts.DistrictZonePort:
	var reject: bool = false

	func prepare(_intent: Dictionary, _candidate_state: Dictionary) -> Dictionary:
		if reject:
			return {"accepted": false, "diagnostics": [{"code": "ZONE_CONSTRUCTION_REJECTED", "message": "injected Zone rejection"}]}
		return {"accepted": true, "prepare_token": {}, "diagnostics": []}

	func commit(_token: Dictionary) -> Dictionary:
		return {"accepted": true, "diagnostics": []}

	func undo(_token: Dictionary) -> Dictionary:
		return {"accepted": true, "diagnostics": []}


var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_policy()
	_test_runtime_transactions()
	print("Construction MVP tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _test_policy() -> void:
	var policy: ConstructionPolicy = load("res://scripts/construction/construction_policy.gd").new() as ConstructionPolicy
	var detached: Dictionary = policy.duplicate_value()
	detached["entries"]["stairs"]["charge_lines"][0]["value"] = 1
	_assert(int(policy.entry_for("stairs").get("charge_lines", [])[0].get("value", -1)) == 500, "construction policy values are detached and immutable at the API boundary")
	_assert(policy.charge_lines_for("elevator", 2).map(func(line: Dictionary) -> int: return int(line.get("value", -1))) == [2000, 500, 500], "elevator policy exposes shaft-once and lobby-per-stop charge lines")
	_assert(policy.entry_for("operations_room").get("geometry_available", true) == false, "unresolved Operations Room geometry is explicit rather than inferred")
	_assert(policy.entry_for("unsupported").is_empty(), "unsupported construction kinds have no fallback policy")


func _test_runtime_transactions() -> void:
	var factory: RefCounted = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
	var resolver: RefCounted = load("res://scripts/resources/district_layout_resolver.gd").new()
	var resolution: Dictionary = resolver.resolve(factory.build_fixture("A"))
	_assert(bool(resolution.get("valid", false)), "construction fixture resolves through H1/H2")
	var snapshot: ResolvedDistrictSnapshot = resolution.get("snapshot") as ResolvedDistrictSnapshot
	var plot: Dictionary = snapshot.get_data().get("plots", [])[0]
	var floor_ground: Dictionary = _floor_at(snapshot, plot["id"], 0)
	var floor_upper: Dictionary = _floor_at(snapshot, plot["id"], 1)
	var state: Dictionary = DistrictStateRecords.new().create_baseline(snapshot)
	state["plot_states"] = [{"runtime_plot_id": plot["id"], "section_state_overrides": [], "floor_states": [_acquired_floor(floor_ground, [[0, 0], [1, 0], [2, 0], [3, 0], [4, 1], [5, 0], [6, 0], [0, 1], [1, 1], [2, 1], [3, 1], [5, 1], [6, 1]]), _acquired_floor(floor_upper, [[0, 0], [1, 0], [2, 0], [3, 0], [4, 1], [5, 0], [6, 0], [0, 1], [1, 1], [2, 1], [3, 1], [5, 1], [6, 1]])]}]
	var economy: EconomyManager = load("res://scripts/simulation/economy_manager.gd").new() as EconomyManager
	root.add_child(economy)
	var zone: RejectingZone = RejectingZone.new()
	var ports: DistrictRuntimePorts.DistrictRuntimePortsBundle = DistrictRuntimePorts.DistrictRuntimePortsBundle.new()
	var economy_port: DistrictRuntimePorts.EconomyManagerPort = DistrictRuntimePorts.EconomyManagerPort.new()
	economy_port.initialize(economy)
	ports.initialize(economy_port, zone, FakeProgression.new())
	var runtime: DistrictRuntime = load("res://scripts/district/district_runtime.gd").new() as DistrictRuntime
	runtime.configure_ports(ports)
	var created: Dictionary = runtime.create_session(snapshot, state)
	_assert(bool(created.get("valid", false)), "construction session restores an explicit acquired sparse state")
	var gateway: ConstructionIntentGateway = load("res://scripts/construction/construction_intent_gateway.gd").new() as ConstructionIntentGateway
	gateway.initialize(runtime)
	var corridor: Dictionary = _intent("corridor_1", "corridor", runtime.get_revision(), [_cell(floor_ground, 0, 0)])
	var before_balance: int = economy.balance
	var preview: Dictionary = gateway.preview(corridor)
	_assert(bool(preview.get("valid", false)) and int(preview.get("quote", {}).get("value", -1)) == 0, "corridor preview uses the zero-cost immutable policy quote")
	_assert(runtime.get_revision() == 0 and economy.balance == before_balance and runtime.get_state().get("construction_records", []).is_empty(), "preview has no District or Economy side effect")
	var corridor_commit: Dictionary = gateway.confirm(corridor)
	_assert(bool(corridor_commit.get("valid", false)) and economy.balance == before_balance, "corridor confirm commits through the normal zero-cost transaction path")
	var duplicate_confirm: Dictionary = gateway.confirm(corridor)
	_assert(not bool(duplicate_confirm.get("valid", false)) and _has_code(duplicate_confirm.get("diagnostics", []), "CONSTRUCTION_REQUEST_ALREADY_CONFIRMED"), "double confirmation is suppressed by the intent gateway")

	var stairs_cells: Array[Dictionary] = []
	for floor: Dictionary in [floor_ground, floor_upper]:
		for pair: Array in [[2, 0], [3, 0], [2, 1], [3, 1]]:
			stairs_cells.append(_cell(floor, pair[0], pair[1]))
	var stairs: Dictionary = _intent("stairs_1", "stairs", runtime.get_revision(), stairs_cells)
	var stairs_commit: Dictionary = gateway.confirm(stairs)
	_assert(bool(stairs_commit.get("valid", false)) and economy.balance == before_balance - 500, "stairs charge exactly 500 Kreds")
	_assert(runtime.get_construction_topology().get("vertical_links", []).size() == 1, "stairs publish exactly one adjacent-floor vertical link")

	var shaft: Array[Dictionary] = [_cell(floor_ground, 5, 0), _cell(floor_upper, 5, 0)]
	var lobbies: Array[Dictionary] = [_cell(floor_ground, 6, 0), _cell(floor_upper, 6, 0)]
	var elevator: Dictionary = _intent("elevator_1", "elevator", runtime.get_revision(), [])
	elevator["shaft_cells"] = shaft
	elevator["lobby_cells"] = lobbies
	var elevator_commit: Dictionary = gateway.confirm(elevator)
	_assert(bool(elevator_commit.get("valid", false)) and economy.balance == before_balance - 3500, "elevator charges 2,000 Kreds once plus 500 Kreds per lobby")
	_assert(runtime.get_construction_topology().get("vertical_links", []).size() == 2, "elevator topology appears only across its committed adjacent stops")
	_assert(runtime.get_traversal_read_view().vertical_links.size() == runtime.get_construction_topology().get("vertical_links", []).size(), "construction topology replaces its prior committed links without duplication")
	_assert(runtime.get_operations_room_facts().is_empty(), "construction does not create Operations Room or staff state without approved room geometry")

	var operations: Dictionary = _intent("room_1", "operations_room", runtime.get_revision(), [_cell(floor_ground, 10, 0), _cell(floor_ground, 11, 0), _cell(floor_ground, 10, 1), _cell(floor_ground, 11, 1)])
	var room_result: Dictionary = gateway.preview(operations)
	_assert(not bool(room_result.get("valid", false)) and _has_code(room_result.get("diagnostics", []), "CONSTRUCTION_GEOMETRY_UNAVAILABLE"), "Operations Room rejects unresolved immutable geometry")
	_assert(economy.balance == before_balance - 3500, "unresolved Operations Room preview does not charge Economy")

	var stale_preview: Dictionary = _intent("stale_1", "corridor", runtime.get_revision(), [_cell(floor_ground, 0, 1)])
	_assert(bool(gateway.preview(stale_preview).get("valid", false)), "stale-preview candidate resolves before a competing commit")
	var competing: Dictionary = _intent("competing_1", "corridor", runtime.get_revision(), [_cell(floor_ground, 1, 1)])
	_assert(bool(gateway.confirm(competing).get("valid", false)), "competing construction commit advances District revision")
	var stale_confirm: Dictionary = gateway.confirm(stale_preview)
	_assert(not bool(stale_confirm.get("valid", false)) and _has_code(stale_confirm.get("diagnostics", []), "STALE_DISTRICT_REVISION"), "confirm revalidates a stale preview and leaves committed state unchanged")

	var before_failure_state: Dictionary = runtime.get_state()
	var before_failure_balance: int = economy.balance
	zone.reject = true
	var zone_failure: Dictionary = gateway.confirm(_intent("zone_failure", "corridor", runtime.get_revision(), [_cell(floor_ground, 4, 1)]))
	zone.reject = false
	_assert(not bool(zone_failure.get("valid", false)) and _has_code(zone_failure.get("diagnostics", []), "ZONE_CONSTRUCTION_REJECTED"), "Zone rejection is atomic and returns construction diagnostics")
	_assert(runtime.get_state() == before_failure_state and economy.balance == before_failure_balance, "Zone rejection leaves District and Economy committed values unchanged")

	var journal: DistrictCommitJournal = runtime.get_journal()
	journal.append_preflight_enabled = false
	var append_failure: Dictionary = gateway.confirm(_intent("append_failure", "corridor", runtime.get_revision(), [_cell(floor_ground, 4, 1)]))
	journal.append_preflight_enabled = true
	_assert(not bool(append_failure.get("valid", false)) and _has_code(append_failure.get("diagnostics", []), "JOURNAL_PREFLIGHT_FAILED"), "append preflight failure occurs before the construction commit point")
	_assert(runtime.get_state() == before_failure_state and economy.balance == before_failure_balance, "append preflight failure restores all committed authority values")

	var records: DistrictStateRecords = DistrictStateRecords.new()
	_assert(bool(records.validate(runtime.get_state(), snapshot).get("valid", false)), "committed construction round-trips through District V2 validation")
	var malformed: Dictionary = runtime.get_state()
	malformed["construction_records"].append(malformed["construction_records"][0].duplicate(true))
	_assert(not bool(records.validate(malformed, snapshot).get("valid", false)), "duplicate construction identities/cells reject atomically")
	runtime.free()
	economy.free()


func _floor_at(snapshot: ResolvedDistrictSnapshot, plot_id: String, elevation: int) -> Dictionary:
	for floor: Dictionary in snapshot.get_data().get("floors", []):
		if String(floor.get("plot_id", "")) == plot_id and int(floor.get("elevation", 999)) == elevation:
			return floor
	return {}


func _acquired_floor(floor: Dictionary, pairs: Array) -> Dictionary:
	var sorted_pairs: Array = pairs.duplicate(true)
	sorted_pairs.sort_custom(func(left: Array, right: Array) -> bool: return int(left[1]) < int(right[1]) or (int(left[1]) == int(right[1]) and int(left[0]) < int(right[0])))
	return {"floor_id": floor["id"], "elevation": floor["elevation"], "acquired_cells": sorted_pairs, "constructed_cells": []}


func _cell(floor: Dictionary, x: int, y: int) -> Dictionary:
	return {"floor_id": floor["id"], "elevation": floor["elevation"], "plot_id": floor["plot_id"], "x": x, "y": y}


func _intent(request_id: String, kind: String, revision: int, cells: Array) -> Dictionary:
	return {"request_id": request_id, "construction_kind": kind, "expected_district_revision": revision, "cells": cells}


func _has_code(diagnostics: Array, code: String) -> bool:
	for diagnostic: Variant in diagnostics:
		if diagnostic is Dictionary and String(diagnostic.get("code", "")) == code:
			return true
	return false
