## StateMachineTest — Self-contained unit tests for the StateMachine framework.
## Run this scene directly. Outputs pass/fail results to console.
##
## Tests create StateMachine instances without adding them to the tree
## to avoid async _ready() timing issues. _ready() is called manually.
extends Node


var _passed := 0
var _failed := 0
var _current_test := ""


func _ready() -> void:
	print("\n=== StateMachine Unit Tests ===\n")
	_test_state_creation()
	_test_state_signals()
	_test_state_machine_initialization()
	_test_state_machine_transition()
	_test_state_machine_unknown_transition()
	_test_state_machine_has_state()
	_test_state_machine_get_current_state_name()
	_test_request_transition()
	_test_multiple_transitions()
	print("\n=== Results: %d passed, %d failed ===\n" % [_passed, _failed])
	if _failed == 0:
		print("ALL TESTS PASSED!")
		get_tree().quit(0)
	else:
		print("SOME TESTS FAILED!")
		get_tree().quit(1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] %s" % message)
	else:
		_failed += 1
		push_error("  [FAIL] %s: %s" % [_current_test, message])


func _test_state_creation() -> void:
	_current_test = "State Creation"
	print("[TEST] %s" % _current_test)

	var s := State.new()
	s.state_name = "test_state"
	_assert(s.state_name == "test_state", "state_name is set correctly")
	_assert(s.owner == null, "owner starts as null")
	_assert(s is Resource, "State extends Resource")


func _test_state_signals() -> void:
	_current_test = "State Signals"
	print("[TEST] %s" % _current_test)

	var s := State.new()
	s.state_name = "sig_test"

	var flags: Array[bool] = [false, false, false, false]
	var captured_state: Array[String] = [""]

	s.state_entered.connect(func(): flags[0] = true)
	s.state_exited.connect(func(): flags[1] = true)
	s.state_updated.connect(func(_d: float): flags[2] = true)
	s.transition_requested.connect(func(n: String): captured_state[0] = n; flags[3] = true)

	s.enter()
	_assert(flags[0], "enter() emits state_entered")

	s.update(0.1)
	_assert(flags[2], "update() emits state_updated")

	s.request_transition("next_state")
	_assert(flags[3], "request_transition() emits transition_requested")
	_assert(captured_state[0] == "next_state", "transition_requested carries correct state name")

	s.exit()
	_assert(flags[1], "exit() emits state_exited")


func _test_state_machine_initialization() -> void:
	_current_test = "StateMachine Initialization"
	print("[TEST] %s" % _current_test)

	var sm := StateMachine.new()
	# Simulate being added to a parent for owner assignment.
	var fake_parent := Node.new()
	fake_parent.add_child(sm)

	var s1 := State.new()
	s1.state_name = "idle"
	var s2 := State.new()
	s2.state_name = "active"

	sm.states = [s1, s2]
	sm.initial_state = s1
	sm._ready()

	_assert(sm.current_state == s1, "initial_state becomes current_state")
	_assert(sm.get_current_state_name() == "idle", "get_current_state_name() returns correct name")
	_assert(sm.has_state("idle"), "has_state('idle') returns true")
	_assert(sm.has_state("active"), "has_state('active') returns true")
	_assert(not sm.has_state("nonexistent"), "has_state() returns false for unknown state")
	_assert(s1.owner == fake_parent, "state.owner is set to parent of StateMachine")

	fake_parent.free()


func _test_state_machine_transition() -> void:
	_current_test = "StateMachine Transition"
	print("[TEST] %s" % _current_test)

	var sm := StateMachine.new()

	var s1 := State.new()
	s1.state_name = "idle"
	var s2 := State.new()
	s2.state_name = "active"

	sm.states = [s1, s2]
	sm.initial_state = s1
	sm._ready()

	var flags: Array[bool] = [false]
	var names: Array[String] = ["", ""]
	sm.state_changed.connect(func(o: String, n: String):
		flags[0] = true
		names[0] = o
		names[1] = n
	)

	s1.request_transition("active")

	_assert(sm.current_state == s2, "transition changes current_state")
	_assert(sm.get_current_state_name() == "active", "get_current_state_name() returns new state")
	_assert(flags[0], "state_changed signal emitted on transition")
	_assert(names[0] == "idle", "state_changed carries old state name")
	_assert(names[1] == "active", "state_changed carries new state name")

	sm.free()


func _test_state_machine_unknown_transition() -> void:
	_current_test = "StateMachine Unknown Transition"
	print("[TEST] %s" % _current_test)

	var sm := StateMachine.new()

	var s1 := State.new()
	s1.state_name = "idle"

	sm.states = [s1]
	sm.initial_state = s1
	sm._ready()

	s1.request_transition("nonexistent")

	_assert(sm.current_state == s1, "unknown transition keeps current state unchanged")
	_assert(sm.get_current_state_name() == "idle", "state name unchanged after failed transition")

	sm.free()


func _test_state_machine_has_state() -> void:
	_current_test = "StateMachine State Methods"
	print("[TEST] %s" % _current_test)

	var sm := StateMachine.new()

	var s1 := State.new()
	s1.state_name = "idle"

	sm.states = [s1]
	sm.initial_state = s1
	sm._ready()

	_assert(sm.get_state("idle") == s1, "get_state() returns correct State by name")
	_assert(sm.get_state("unknown") == null, "get_state() returns null for unknown name")

	sm.free()


func _test_state_machine_get_current_state_name() -> void:
	_current_test = "StateMachine Empty State Name"
	print("[TEST] %s" % _current_test)

	var sm := StateMachine.new()
	_assert(sm.get_current_state_name() == "", "get_current_state_name() returns empty when no state")

	sm.free()


func _test_request_transition() -> void:
	_current_test = "State Request Transition Chain"
	print("[TEST] %s" % _current_test)

	var sm := StateMachine.new()

	var s1 := State.new()
	s1.state_name = "a"
	var s2 := State.new()
	s2.state_name = "b"
	var s3 := State.new()
	s3.state_name = "c"

	sm.states = [s1, s2, s3]
	sm.initial_state = s1
	sm._ready()

	s1.request_transition("b")
	_assert(sm.get_current_state_name() == "b", "first transition a -> b")

	s2.request_transition("c")
	_assert(sm.get_current_state_name() == "c", "second transition b -> c")

	sm.free()


func _test_multiple_transitions() -> void:
	_current_test = "Multiple Transitions"
	print("[TEST] %s" % _current_test)

	var sm := StateMachine.new()

	var s1 := State.new()
	s1.state_name = "idle"
	var s2 := State.new()
	s2.state_name = "active"

	sm.states = [s1, s2]
	sm.initial_state = s1
	sm._ready()

	var counter: Array[int] = [0]
	sm.state_changed.connect(func(_o: String, _n: String): counter[0] += 1)

	s1.request_transition("active")
	s2.request_transition("idle")
	s1.request_transition("active")

	_assert(counter[0] == 3, "3 transitions counted")
	_assert(sm.get_current_state_name() == "active", "final state is active")

	sm.free()
