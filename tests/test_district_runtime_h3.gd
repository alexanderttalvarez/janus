## H3 contract/proof tests for lifecycle, sparse mutation, revision guards, and atomic fan-out.
extends SceneTree

class FakeEconomy extends DistrictRuntimePorts.DistrictEconomyPort:
	var revision: int = 1
	var fail_reserve: bool = false
	var fail_guarantee: bool = false
	var fail_capture: bool = false
	var calls: Array[String] = []

	func get_revision() -> int:
		return revision

	func get_policy_snapshot() -> Dictionary:
		return {"schema_version": 1, "revision": revision, "plot_section_cost_per_tile": 1000, "street_corridor_cost_per_tile": 3000, "demolition_cost": 20, "floor_tile_costs": {0: 1000, 1: 1200, 2: 1400, -1: 1200, -2: 1400, -3: 1600}}

	func quote(_intent: Dictionary, _candidate_state: Dictionary) -> Dictionary:
		calls.append("quote")
		return {"accepted": true, "value": 0, "economy_revision": revision, "diagnostics": []}

	func reserve(_quote: Dictionary) -> Dictionary:
		calls.append("reserve")
		if fail_reserve:
			return {"accepted": false, "diagnostics": [{"code": "FAKE_RESERVE_FAILED"}]}
		return {"accepted": true, "reservation_token": {"token": calls.size()}, "diagnostics": []}

	func guarantee_capture(reservation: Dictionary) -> Dictionary:
		calls.append("guarantee")
		if fail_guarantee:
			return {"accepted": false, "diagnostics": [{"code": "FAKE_GUARANTEE_FAILED"}]}
		return {"accepted": true, "guaranteed_capture_token": reservation, "diagnostics": []}

	func capture(_token: Dictionary) -> Dictionary:
		calls.append("capture")
		if fail_capture:
			return {"accepted": false, "diagnostics": [{"code": "FAKE_CAPTURE_FAILED"}]}
		return {"accepted": true, "diagnostics": []}

	func cancel(_reservation: Dictionary) -> Dictionary:
		calls.append("cancel")
		return {"accepted": true, "diagnostics": []}


class FakeZone extends DistrictRuntimePorts.DistrictZonePort:
	var revision: int = 1
	var mutate_revision_on_prepare: bool = false
	var fail_prepare: bool = false
	var fail_commit: bool = false
	var calls: Array[String] = []
	var district_effects: Dictionary = {}
	var last_preview_marker: int = 0
	var prepared_preview_marker: int = -1
	var prepared_state: Dictionary = {}
	var prepared_snapshot: DistrictZoneSpatialSnapshot

	func get_revision() -> int:
		return revision

	func preview(
		_intent: Dictionary,
		_candidate_state: Dictionary,
		_spatial_snapshot: DistrictZoneSpatialSnapshot,
		_public_band_access: PublicBandAccessSnapshot = null
	) -> Dictionary:
		last_preview_marker += 1
		return {"accepted": true, "preview": null, "district_effects": district_effects.duplicate(true), "plan_marker": last_preview_marker, "diagnostics": []}

	func prepare(
		_intent: Dictionary,
		_candidate_state: Dictionary,
		_spatial_snapshot: DistrictZoneSpatialSnapshot,
		_public_band_access: PublicBandAccessSnapshot = null,
		_zone_plan: Dictionary = {}
	) -> Dictionary:
		calls.append("prepare")
		prepared_preview_marker = int(_zone_plan.get("plan_marker", -1))
		prepared_state = _candidate_state.duplicate(true)
		prepared_snapshot = _spatial_snapshot.duplicate_snapshot() if _spatial_snapshot != null else null
		if fail_prepare:
			return {"accepted": false, "diagnostics": [{"code": "FAKE_ZONE_PREPARE_FAILED"}]}
		if mutate_revision_on_prepare:
			revision += 1
		return {"accepted": true, "prepare_token": {"token": calls.size()}, "diagnostics": []}

	func commit(_token: Dictionary) -> Dictionary:
		calls.append("commit")
		if fail_commit:
			return {"accepted": false, "diagnostics": [{"code": "FAKE_ZONE_COMMIT_FAILED"}]}
		return {"accepted": true, "diagnostics": []}

	func undo(_token: Dictionary) -> Dictionary:
		calls.append("undo")
		return {"accepted": true, "diagnostics": []}


class FakeDoorZoneManager extends Node:
	var revision: int = 1
	var endpoint_zones: Dictionary = {}

	func get_district_revision() -> int:
		return revision

	func get_manual_door_zone_view(address: Dictionary, _candidate_state: Dictionary = {}) -> Dictionary:
		var cell: Array = address.get("cell", [])
		var key: String = "%d,%d" % [int(cell[0]), int(cell[1])] if cell is Array and cell.size() == 2 else "invalid"
		var facts: Dictionary = endpoint_zones.get(key, {})
		return {
			"resolved": true,
			"zone_id": String(facts.get("zone_id", "")),
			"typology": int(facts.get("typology", -1)),
			"in_mutation_scope": false,
			"zone_revision": revision,
		}


class FakeProgression extends DistrictRuntimePorts.DistrictProgressionPort:
	var revision: int = 1
	var minimum_elevation: int = -5
	var maximum_elevation: int = 9
	var selected_plot_ids: Array = []

	func get_policy_snapshot() -> Dictionary:
		return {"schema_version": 1, "revision": revision, "minimum_elevation": minimum_elevation, "maximum_elevation": maximum_elevation, "elevation_eligibility": [0, 1, 2, -1, -2, -3], "selected_plot_ids": selected_plot_ids.duplicate(), "street_conversion_eligible": true}


var _passed: int = 0
var _failed: int = 0
var _factory: RefCounted
var _resolver: RefCounted
var _runtime: DistrictRuntime
var _economy: FakeEconomy
var _zone: FakeZone
var _progression: FakeProgression
var _fanout_revisions: Array[int] = []
var _fanout_gate_held: Array[bool] = []
var _fanout_barrier_active: Array[bool] = []
var _fault_subscriber_called: bool = false
var _second_subscriber_called: bool = false


func _init() -> void:
	_factory = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
	_resolver = load("res://scripts/resources/district_layout_resolver.gd").new()
	_setup_runtime("C")
	_test_lifecycle_and_preview()
	_test_section_activation_and_revision()
	_test_vertical_space_and_construction()
	_test_zone_district_effect_application()
	_test_manual_door_authority()
	_test_manual_door_zone_candidate()
	_test_atomic_rejection_and_fault_isolation()
	_test_sparse_state_boundary()
	print("DistrictRuntime H3 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _setup_runtime(fixture_id: String) -> void:
	var resolution: Dictionary = _resolver.resolve(_factory.build_fixture(fixture_id))
	_assert(bool(resolution.get("valid", false)), "%s snapshot resolves for H3" % fixture_id)
	var snapshot: ResolvedDistrictSnapshot = resolution.get("snapshot") as ResolvedDistrictSnapshot
	_runtime = load("res://scripts/district/district_runtime.gd").new()
	var gate_setup: Dictionary = _runtime.configure_session_gate(SessionMutationGate.new())
	_assert(bool(gate_setup.get("valid", false)), "%s runtime accepts an injected session mutation gate" % fixture_id)
	_economy = FakeEconomy.new()
	_zone = FakeZone.new()
	_progression = FakeProgression.new()
	for plot: Dictionary in snapshot.get_data().get("plots", []):
		var is_initial: bool = false
		for section: Dictionary in snapshot.get_data().get("sections", []):
			if String(section.get("plot_id", "")) == String(plot.get("id", "")) and bool(section.get("initially_owned", false)):
				is_initial = true
		if not is_initial:
			_progression.selected_plot_ids.append(String(plot.get("id", "")))
	var ports: DistrictRuntimePorts.DistrictRuntimePortsBundle = DistrictRuntimePorts.DistrictRuntimePortsBundle.new()
	ports.initialize(_economy, _zone, _progression)
	_runtime.configure_ports(ports)
	_runtime.subscribe_committed(Callable(self, "_on_committed"))
	var created: Dictionary = _runtime.create_session(snapshot)
	_assert(bool(created.get("valid", false)), "%s session creates from immutable snapshot" % fixture_id)
	_fanout_revisions.clear()
	_fanout_gate_held.clear()
	_fanout_barrier_active.clear()


func _on_committed(envelope: Dictionary) -> Dictionary:
	_fanout_revisions.append(int(envelope.get("district_revision", -1)))
	_fanout_gate_held.append(_runtime.get_gate().is_held())
	_fanout_barrier_active.append(_runtime.get_gate().is_barrier_active())
	return {"ok": true}


func _on_fault_subscriber(_envelope: Dictionary) -> Dictionary:
	_fault_subscriber_called = true
	return {"ok": false, "detail": "injected subscriber fault"}


func _on_second_subscriber(_envelope: Dictionary) -> Dictionary:
	_second_subscriber_called = true
	return {"ok": true}


func _test_lifecycle_and_preview() -> void:
	var before: Dictionary = _runtime.get_state()
	var plot: Dictionary = _runtime.get_snapshot().get_data()["plots"][0]
	var section: Dictionary = _runtime.get_snapshot().get_data()["sections"][6]
	var preview: Dictionary = _runtime.preview_transaction({"operation": "ACQUIRE_SECTION", "runtime_section_id": section["id"], "expected_district_revision": 0})
	_assert(bool(preview.get("valid", false)), "preview evaluates section acquisition")
	_assert(_runtime.get_revision() == 0 and before == _runtime.get_state(), "preview leaves immutable authority state unchanged")
	_assert(not plot.is_empty(), "snapshot exposes resolved Plot descriptors")


func _test_section_activation_and_revision() -> void:
	var sections: Array = _runtime.get_snapshot().get_data()["sections"]
	var station_section: Dictionary = sections[6]
	var intent: Dictionary = {"operation": "ACQUIRE_SECTION", "runtime_section_id": station_section["id"], "expected_district_revision": 0}
	var committed: Dictionary = _runtime.commit_transaction(intent)
	_assert(bool(committed.get("valid", false)), "first section acquisition commits atomically")
	_assert(_runtime.get_revision() == 1, "section acquisition advances the sole district revision")
	_assert(_runtime.get_journal().get_entry_count() == 1, "section acquisition appends exactly one envelope")
	_assert(_economy.calls.has("reserve") and _economy.calls.has("guarantee") and _economy.calls.has("capture"), "section transaction follows reserve guarantee capture protocol")
	_assert(_fanout_revisions == [1], "one committed transaction produces one ordered delta")
	_assert(_fanout_gate_held == [true] and _fanout_barrier_active == [false], "delta flush keeps the transaction gate held after barrier release")
	intent["expected_district_revision"] = 1
	var stale: Dictionary = _runtime.commit_transaction(intent)
	_assert(not bool(stale.get("valid", false)) and _has_code(stale.get("diagnostics", []), "SECTION_ALREADY_OWNED"), "repeating an acquisition is rejected without mutation")
	_assert(_runtime.get_revision() == 1 and _runtime.get_journal().get_entry_count() == 1, "rejected transaction does not publish state or journal output")


func _test_vertical_space_and_construction() -> void:
	var data: Dictionary = _runtime.get_snapshot().get_data()
	var plot: Dictionary = data["plots"][0]
	var floor: Dictionary = _floor_for(data["floors"], plot["id"], 0)
	var cell: Array = plot["buildability_mask"][0]
	var acquire: Dictionary = _runtime.commit_transaction({"operation": "ACQUIRE_SPACE", "runtime_plot_id": plot["id"], "floor_id": floor["id"], "elevation": floor["elevation"], "cells": [cell], "expected_district_revision": 1})
	_assert(bool(acquire.get("valid", false)), "ground space acquisition accepts an explicit FloorAddress")
	_assert(_runtime.get_revision() == 2, "space acquisition advances revision")
	var construct: Dictionary = _runtime.commit_transaction({"operation": "CONSTRUCT", "runtime_plot_id": plot["id"], "floor_id": floor["id"], "cells": [cell], "expected_district_revision": 2})
	_assert(bool(construct.get("valid", false)), "construction requires and consumes acquired sparse rights")
	_assert(_runtime.get_revision() == 3, "construction advances revision")
	var demolition: Dictionary = _runtime.commit_transaction({"operation": "DEMOLISH_CONSTRUCTION", "floor_id": floor["id"], "cells": [cell], "expected_district_revision": 3})
	_assert(bool(demolition.get("valid", false)), "construction demolition commits without clearing acquired rights")
	_assert(_runtime.get_revision() == 4, "demolition advances revision")
	var invalid_upper: Dictionary = _runtime.commit_transaction({"operation": "ACQUIRE_SPACE", "runtime_plot_id": plot["id"], "floor_id": _floor_for(data["floors"], plot["id"], 2)["id"], "elevation": 2, "cells": [cell], "expected_district_revision": 4})
	_assert(not bool(invalid_upper.get("valid", false)) and _has_code(invalid_upper.get("diagnostics", []), "VERTICAL_SEQUENCE_REQUIRED"), "upper space requires the adjacent elevation first")


func _test_zone_district_effect_application() -> void:
	var snapshot: ResolvedDistrictSnapshot = _runtime.get_snapshot()
	var data: Dictionary = snapshot.get_data()
	var plot: Dictionary = data["plots"][0]
	var floor: Dictionary = _floor_for(data["floors"], plot["id"], 0)
	var cells: Array = _find_adjacent_cells(plot["buildability_mask"])
	var cell: Array = cells[0]
	var manual_edge: Dictionary = {
		"endpoint_a": {"runtime_plot_id": plot["id"], "signed_elevation": floor["elevation"], "local_cell": {"x": int(cells[0][0]), "y": int(cells[0][1])}},
		"endpoint_b": {"runtime_plot_id": plot["id"], "signed_elevation": floor["elevation"], "local_cell": {"x": int(cells[1][0]), "y": int(cells[1][1])}},
	}
	var runtime := DistrictRuntime.new()
	_assert(bool(runtime.configure_session_gate(SessionMutationGate.new()).get("valid", false)), "zone-effects runtime accepts the shared session gate")
	var economy := FakeEconomy.new()
	var zone := FakeZone.new()
	var progression := FakeProgression.new()
	var ports := DistrictRuntimePorts.DistrictRuntimePortsBundle.new()
	ports.initialize(economy, zone, progression)
	runtime.configure_ports(ports)
	var state: Dictionary = DistrictStateRecords.new().create_baseline(snapshot)
	state["plot_states"] = [{
		"runtime_plot_id": plot["id"],
		"section_state_overrides": [],
		"floor_states": [{
			"floor_id": floor["id"],
			"elevation": floor["elevation"],
			"acquired_cells": cells.duplicate(true),
			"constructed_cells": cells.duplicate(true),
			"explicit_circulation_cells": [cell.duplicate()],
		}],
	}]
	state["manual_door_edges"] = [manual_edge]
	_assert(bool(runtime.create_session(snapshot, state).get("valid", false)), "zone-effects fixture creates with explicit circulation")
	zone.district_effects = {
		"remove_explicit_circulation_cells": [{"x": int(cell[0]), "y": int(cell[1])}],
		"add_explicit_circulation_cells": [],
		"remove_manual_door_edges": [manual_edge],
	}
	var committed: Dictionary = runtime.commit_transaction({
		"operation": DistrictRuntime.OP_PAINT_ZONE,
		"expected_district_revision": 0,
		"runtime_plot_id": plot["id"],
		"floor_id": floor["id"],
		"elevation": floor["elevation"],
		"zone_plot_id": plot["id"],
		"zone_floor_label": "G",
		"zone_type": "Retail",
		"cells": [cell.duplicate()],
		"typologies": {},
		"paint_mode": "zone",
	})
	_assert(bool(committed.get("valid", false)), "DistrictRuntime commits Zone paint and District effects atomically")
	var committed_floor: Dictionary = runtime.get_state()["plot_states"][0]["floor_states"][0]
	_assert(committed_floor["explicit_circulation_cells"].is_empty(), "Zone paint consumes explicit circulation in DistrictState")
	_assert(int(runtime.get_state().get("construction_revision", -1)) == 1, "circulation effect advances construction revision")
	_assert(runtime.get_state().get("manual_door_edges", []).is_empty(), "obsolete same-zone manual door edge is removed in the atomic District candidate")
	_assert(zone.prepared_preview_marker == zone.last_preview_marker, "prepare receives the exact accepted Zone preview plan")
	_assert(zone.prepared_snapshot != null and not zone.prepared_snapshot.has_cell("explicit_circulation_cells", Vector2i(int(cell[0]), int(cell[1]))), "prepare receives the prospective post-effect spatial snapshot")
	zone.district_effects = {
		"remove_explicit_circulation_cells": [],
		"add_explicit_circulation_cells": [{"x": int(cell[0]), "y": int(cell[1])}],
		"remove_manual_door_edges": [],
	}
	var restored: Dictionary = runtime.commit_transaction({
		"operation": DistrictRuntime.OP_PAINT_ZONE,
		"expected_district_revision": 1,
		"runtime_plot_id": plot["id"],
		"floor_id": floor["id"],
		"elevation": floor["elevation"],
		"zone_plot_id": plot["id"],
		"zone_floor_label": "G",
		"zone_type": "Retail",
		"cells": [cell.duplicate()],
		"typologies": {},
		"paint_mode": "none",
	})
	_assert(bool(restored.get("valid", false)), "None paint restores District circulation through the same transaction")
	var restored_floor: Dictionary = runtime.get_state()["plot_states"][0]["floor_states"][0]
	_assert(restored_floor["explicit_circulation_cells"] == [cell], "None paint restores explicit circulation without changing built rights")
	_assert(restored_floor["acquired_cells"] == cells and restored_floor["constructed_cells"] == cells, "None paint preserves acquired and constructed cells")
	runtime.free()


func _test_manual_door_authority() -> void:
	var snapshot: ResolvedDistrictSnapshot = _runtime.get_snapshot()
	var data: Dictionary = snapshot.get_data()
	var plot: Dictionary = data["plots"][0]
	var floor: Dictionary = _floor_for(data["floors"], plot["id"], 0)
	var cells: Array = _find_adjacent_cells(plot.get("buildability_mask", []))
	_assert(cells.size() == 2, "manual-door fixture provides adjacent immutable cells")
	if cells.size() != 2:
		return
	var door_runtime: DistrictRuntime = load("res://scripts/district/district_runtime.gd").new() as DistrictRuntime
	var door_gate_setup: Dictionary = door_runtime.configure_session_gate(SessionMutationGate.new())
	_assert(bool(door_gate_setup.get("valid", false)), "manual-door runtime accepts an injected session mutation gate")
	var door_economy: FakeEconomy = FakeEconomy.new()
	var door_zone_port: FakeZone = FakeZone.new()
	var door_progression: FakeProgression = FakeProgression.new()
	var ports: DistrictRuntimePorts.DistrictRuntimePortsBundle = DistrictRuntimePorts.DistrictRuntimePortsBundle.new()
	ports.initialize(door_economy, door_zone_port, door_progression)
	door_runtime.configure_ports(ports)
	var door_state: Dictionary = DistrictStateRecords.new().create_baseline(snapshot)
	door_state["plot_states"] = [{
		"runtime_plot_id": plot["id"],
		"section_state_overrides": [],
		"floor_states": [{
			"floor_id": floor["id"],
			"elevation": floor["elevation"],
			"acquired_cells": cells.duplicate(true),
			"constructed_cells": cells.duplicate(true),
			"explicit_circulation_cells": [],
		}],
	}]
	_assert(bool(door_runtime.create_session(snapshot, door_state).get("valid", false)), "manual-door fixture session creates with acquired constructed cells")
	var door_zone_manager: FakeDoorZoneManager = FakeDoorZoneManager.new()
	door_zone_manager.endpoint_zones["%d,%d" % [cells[0][0], cells[0][1]]] = {"zone_id": "zone_a", "typology": ManualDoorAuthority.TRANSIT_TYPOLOGY}
	door_zone_manager.endpoint_zones["%d,%d" % [cells[1][0], cells[1][1]]] = {"zone_id": "zone_b", "typology": ManualDoorAuthority.TRANSIT_TYPOLOGY}
	var authority: ManualDoorAuthority = ManualDoorAuthority.new()
	authority.configure(door_runtime, door_zone_manager)
	var intent: Dictionary = {
		"runtime_plot_id": plot["id"],
		"floor_id": floor["id"],
		"elevation": floor["elevation"],
		"from_cell": cells[0],
		"to_cell": cells[1],
		"enabled": true,
		"expected_district_revision": door_runtime.get_revision(),
		"expected_zone_revision": door_zone_manager.get_district_revision(),
	}
	var preview: Dictionary = authority.preview_manual_door(intent)
	_assert(bool(preview.get("valid", false)) and door_runtime.get_revision() == 0, "manual-door preview composes detached district and zone views without mutation")
	var commit: Dictionary = authority.commit_manual_door(intent)
	_assert(bool(commit.get("valid", false)) and door_runtime.get_revision() == 1, "manual-door commit uses one H3 transaction")
	_assert(door_runtime.get_state().get("manual_door_edges", []).size() == 1, "manual-door edge is owned by DistrictRuntime")
	_assert(bool(DistrictStateRecords.new().validate(door_runtime.get_state(), snapshot).get("valid", false)), "committed manual-door records validate at the H2 boundary")
	intent["expected_district_revision"] = 1
	var duplicate: Dictionary = authority.commit_manual_door(intent)
	_assert(not bool(duplicate.get("valid", false)) and _has_code(duplicate.get("diagnostics", []), "MANUAL_DOOR_ALREADY_SET"), "duplicate manual-door placement rejects atomically")
	intent["enabled"] = false
	var removal: Dictionary = authority.commit_manual_door(intent)
	_assert(bool(removal.get("valid", false)) and door_runtime.get_state().get("manual_door_edges", []).is_empty(), "manual-door removal is revision guarded and atomic")
	intent["enabled"] = true
	intent["expected_district_revision"] = door_runtime.get_revision()
	intent["expected_zone_revision"] = 1
	door_zone_manager.revision = 2
	var stale_zone: Dictionary = authority.preview_manual_door(intent)
	_assert(not bool(stale_zone.get("valid", false)) and _has_code(stale_zone.get("diagnostics", []), "STALE_ZONE_REVISION"), "mixed zone revisions reject before H3 evaluation")
	door_runtime.free()
	door_zone_manager.free()


func _test_manual_door_zone_candidate() -> void:
	var manager: ZoneManager = load("res://scripts/zones/zone_manager.gd").new() as ZoneManager
	var zone: ZoneData = ZoneData.new()
	zone.id = "zone_a"
	zone.plot_id = "plot_a"
	zone.floor = "G"
	zone.type = ZoneData.ZONE_TYPE_NAMES[0]
	zone.tiles = [Vector2i(0, 0)]
	zone.typologies[Vector2i(0, 0)] = ManualDoorAuthority.TRANSIT_TYPOLOGY
	manager.zones[zone.id] = zone
	var paint_intent: Dictionary = {"zone_plot_id": "plot_a", "zone_floor_label": "G", "zone_type": zone.type, "cells": [[1, 0]], "typologies": {Vector2i(1, 0): 0}, "paint_mode": "zone"}
	var candidate: Dictionary = manager._build_manual_door_zone_candidate(paint_intent)
	var record: Dictionary = {
		"endpoint_a": {"runtime_plot_id": "plot_a", "signed_elevation": 0, "local_cell": {"x": 0, "y": 0}},
		"endpoint_b": {"runtime_plot_id": "plot_a", "signed_elevation": 0, "local_cell": {"x": 1, "y": 0}},
	}
	var validation: Dictionary = manager._validate_manual_door_records_against_zone_candidate([record], candidate)
	_assert(bool(validation.get("valid", false)) and validation.get("obsolete_edges", []).size() == 1, "prospective zone candidate identifies a same-zone manual door for atomic removal")
	manager.free()


func _find_adjacent_cells(values: Array) -> Array:
	for first_value: Variant in values:
		if not first_value is Array or first_value.size() != 2:
			continue
		for second_value: Variant in values:
			if not second_value is Array or second_value.size() != 2 or first_value == second_value:
				continue
			if absi(int(first_value[0]) - int(second_value[0])) + absi(int(first_value[1]) - int(second_value[1])) == 1:
				var result: Array = [first_value.duplicate(), second_value.duplicate()]
				result.sort_custom(func(left: Array, right: Array) -> bool: return int(left[1]) < int(right[1]) or (int(left[1]) == int(right[1]) and int(left[0]) < int(right[0])))
				return result
	return []


func _test_atomic_rejection_and_fault_isolation() -> void:
	var data: Dictionary = _runtime.get_snapshot().get_data()
	var plot: Dictionary = data["plots"][0]
	var floor: Dictionary = _floor_for(data["floors"], plot["id"], 0)
	var next_cell: Array = plot["buildability_mask"][1]
	_economy.fail_reserve = true
	var reserve_failure: Dictionary = _runtime.commit_transaction({"operation": "ACQUIRE_SPACE", "runtime_plot_id": plot["id"], "floor_id": floor["id"], "elevation": 0, "cells": [next_cell], "expected_district_revision": 4})
	_economy.fail_reserve = false
	_assert(not bool(reserve_failure.get("valid", false)) and _has_code(reserve_failure.get("diagnostics", []), "FAKE_RESERVE_FAILED"), "economy reservation rejection is observable as diagnostics")
	_assert(_runtime.get_revision() == 4 and _runtime.get_journal().get_entry_count() == 4, "economy rejection leaves district and journal unchanged")
	_zone.mutate_revision_on_prepare = true
	var stale_zone: Dictionary = _runtime.commit_transaction({"operation": "ACQUIRE_SPACE", "runtime_plot_id": plot["id"], "floor_id": floor["id"], "elevation": 0, "cells": [next_cell], "expected_district_revision": 4})
	_zone.mutate_revision_on_prepare = false
	_assert(not bool(stale_zone.get("valid", false)) and _has_code(stale_zone.get("diagnostics", []), "STALE_ZONE_REVISION"), "zone revision drift rejects before authority swap")
	_assert(_runtime.get_revision() == 4 and _runtime.get_journal().get_entry_count() == 4, "revision rejection leaves sparse state unchanged")
	var source: Dictionary = data["arrival_source_attachments"][0]
	_runtime.subscribe_committed(Callable(self, "_on_fault_subscriber"))
	_runtime.subscribe_committed(Callable(self, "_on_second_subscriber"))
	var source_commit: Dictionary = _runtime.commit_transaction({"operation": "SET_SOURCE_ENABLED", "arrival_source_id": source["authored_id"], "enabled": false, "expected_district_revision": 4})
	_assert(bool(source_commit.get("valid", false)), "source state mutation commits through the same coordinator")
	_assert(_runtime.get_revision() == 5 and _runtime.get_journal().get_entry_count() == 5, "source mutation appends one complete envelope")
	_assert(_fault_subscriber_called and _second_subscriber_called and source_commit.get("subscriber_diagnostics", []).size() == 1, "subscriber faults are isolated without suppressing ordered fan-out")
	_runtime.get_journal().append_preflight_enabled = false
	var preflight_failure: Dictionary = _runtime.commit_transaction({"operation": "DEMOLISH_FIXED_OCCUPANT", "fixed_occupant_id": data["fixed_occupants"][0]["id"], "expected_district_revision": 5})
	_runtime.get_journal().append_preflight_enabled = true
	_assert(not bool(preflight_failure.get("valid", false)) and _has_code(preflight_failure.get("diagnostics", []), "JOURNAL_PREFLIGHT_FAILED"), "journal preflight rejects before the commit point")
	_assert(_runtime.get_revision() == 5 and _runtime.get_journal().get_entry_count() == 5, "journal preflight failure leaves authority references unchanged")


func _test_sparse_state_boundary() -> void:
	var records: RefCounted = load("res://scripts/resources/district_state_records.gd").new()
	var validation: Dictionary = records.validate(_runtime.get_state(), _runtime.get_snapshot())
	_assert(bool(validation.get("valid", false)), "runtime state remains valid under H2 sparse-state rules")
	var disposed: Dictionary = _runtime.dispose_session()
	_assert(bool(disposed.get("valid", false)) and not _runtime.has_session(), "session disposal clears the session-scoped runtime")
	var rejected: Dictionary = _runtime.preview_transaction({"operation": "ACQUIRE_SECTION", "expected_district_revision": 0})
	_assert(not bool(rejected.get("valid", false)) and _has_code(rejected.get("diagnostics", []), "SESSION_REQUIRED"), "disposed runtime rejects operations without a session")
	_runtime.free()


func _floor_for(floors: Array, plot_id: String, elevation: int) -> Dictionary:
	for floor: Dictionary in floors:
		if String(floor.get("plot_id", "")) == plot_id and int(floor.get("elevation", 999)) == elevation:
			return floor
	return {}


func _has_code(diagnostics: Array, code: String) -> bool:
	for diagnostic: Variant in diagnostics:
		if diagnostic is Dictionary and diagnostic.get("code", "") == code:
			return true
	return false
