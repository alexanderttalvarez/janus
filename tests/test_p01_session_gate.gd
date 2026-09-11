## P01 contract tests for the single synchronous session mutation boundary.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_non_reentrant_gate_contract()
	_test_boundary_failure_retries_before_input()
	_test_deterministic_consumer_order()
	_test_cross_owner_gate_identity()
	print("P01 session gate tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_non_reentrant_gate_contract() -> void:
	var gate: SessionMutationGate = SessionMutationGate.new()
	_assert(bool(gate.acquire("first").get("valid", false)), "session gate accepts the first main-thread owner")
	var reentrant: Dictionary = gate.acquire("second")
	_assert(not bool(reentrant.get("valid", false)) and _has_code(reentrant.get("diagnostics", []), "SESSION_MUTATION_BUSY"), "session gate rejects reentrant mutation")
	_assert(bool(gate.release("first").get("valid", false)) and not gate.is_busy(), "only the active owner releases the session gate")


func _test_boundary_failure_retries_before_input() -> void:
	var gate: SessionMutationGate = SessionMutationGate.new()
	var time_manager: TimeManager = load("res://scripts/simulation/time_manager.gd").new() as TimeManager
	var delivery_state: Dictionary = {"attempts": 0}
	var observed_hours: Array[int] = []
	time_manager.sim_hour_passed.connect(func(hour: int) -> void: observed_hours.append(hour))
	var setup: Dictionary = time_manager.configure_boundary_delivery(gate, func(_kind: String, _boundary_id: int) -> Dictionary:
		delivery_state["attempts"] = int(delivery_state["attempts"]) + 1
		return {"valid": int(delivery_state["attempts"]) > 1, "diagnostics": [{"code": "INJECTED_BOUNDARY_FAILURE"}]}
	)
	_assert(bool(setup.get("valid", false)), "clock configures its direct boundary coordinator")
	time_manager.set_speed(1)
	time_manager._process(1.0)
	_assert(time_manager.has_pending_boundary() and time_manager.speed == 0 and gate.is_blocked(), "failed mandatory boundary pauses the clock and blocks the session")
	var blocked: Dictionary = gate.acquire("input")
	_assert(not bool(blocked.get("valid", false)) and _has_code(blocked.get("diagnostics", []), "SESSION_BOUNDARY_BLOCKED"), "input/save owners cannot enter before the failed boundary retries")
	var retry: Dictionary = time_manager.retry_pending_boundary()
	_assert(bool(retry.get("valid", false)) and not time_manager.has_pending_boundary() and not gate.is_busy(), "successful retry advances exactly the blocked boundary and clears the gate")
	_assert(int(delivery_state["attempts"]) == 2 and observed_hours == [1], "calendar signals publish only after the mandatory retry succeeds")
	time_manager.free()


func _test_deterministic_consumer_order() -> void:
	var gate: SessionMutationGate = SessionMutationGate.new()
	var coordinator: SessionBootstrapCoordinator = load("res://scripts/session/session_bootstrap_coordinator.gd").new() as SessionBootstrapCoordinator
	_assert(bool(coordinator.configure_session_gate(gate).get("valid", false)), "bootstrap uses the shared session gate")
	var trace: Array[String] = []
	var configured: Dictionary = coordinator.configure_boundary_consumers({
		"visitor": [],
		"hour": [],
		"day": [
			{"name": "tenant_lifecycle", "callable": func(_day: int) -> Dictionary: trace.append("tenant"); return {"valid": true}, "mandatory": true},
			{"name": "economy_rent", "callable": func(_day: int) -> Dictionary: trace.append("rent"); return {"valid": true}, "mandatory": true},
			{"name": "metrics", "callable": func(_day: int) -> Dictionary: trace.append("metrics"); return {"valid": true}, "mandatory": true},
		],
		"week": [{"name": "economy_payroll", "callable": func(_week: int) -> Dictionary: return {"valid": true}, "mandatory": true}],
		"month": [{"name": "economy_loans", "callable": func(_month: int) -> Dictionary: return {"valid": true}, "mandatory": true}],
	})
	_assert(bool(configured.get("valid", false)), "boundary consumer chains validate their required order")
	_assert(bool(gate.acquire("calendar:day:1").get("valid", false)), "calendar acquires the shared mutation gate")
	var delivered: Dictionary = coordinator.deliver_boundary("day", 1)
	_assert(bool(delivered.get("valid", false)) and trace == ["tenant", "rent", "metrics"], "mandatory day consumers run in the architecture-defined sequence")
	gate.release("calendar:day:1")


func _test_cross_owner_gate_identity() -> void:
	var district_gate: SessionMutationGate = SessionMutationGate.new()
	var foreign_gate: SessionMutationGate = SessionMutationGate.new()
	var runtime: DistrictRuntime = load("res://scripts/district/district_runtime.gd").new() as DistrictRuntime
	_assert(bool(runtime.configure_session_gate(district_gate).get("valid", false)), "District Runtime accepts its session gate before session creation")
	var arrival_gate: ArrivalCommitGate = ArrivalCommitGate.new()
	_assert(bool(arrival_gate.configure(foreign_gate).get("valid", false)), "arrival gate can be configured for mismatch verification")
	var mismatch: Dictionary = runtime.set_arrival_commit_gate(arrival_gate)
	_assert(not bool(mismatch.get("valid", false)) and _has_code(mismatch.get("diagnostics", []), "SESSION_GATE_MISMATCH"), "District Runtime rejects an arrival gate with a different session boundary")
	_assert(bool(arrival_gate.configure(district_gate).get("valid", false)), "unheld arrival gate can bind to the District Runtime session gate")
	_assert(bool(runtime.set_arrival_commit_gate(arrival_gate).get("valid", false)), "District Runtime accepts an arrival gate with the same boundary")
	runtime.free()


func _has_code(diagnostics: Array, code: String) -> bool:
	for diagnostic: Variant in diagnostics:
		if diagnostic is Dictionary and String(diagnostic.get("code", "")) == code:
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)
