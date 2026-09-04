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

	func get_revision() -> int:
		return revision

	func prepare(_intent: Dictionary, _candidate_state: Dictionary) -> Dictionary:
		calls.append("prepare")
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
