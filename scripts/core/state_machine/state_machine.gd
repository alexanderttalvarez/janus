## StateMachine — Generic FSM controller for Resource-based states.
## Manages state transitions and delegates update to the current state.
##
## Usage:
##  1. Add StateMachine as a child of any Node.
##  2. Assign an array of State Resources and an initial state.
##  3. The StateMachine calls current_state.update(delta) each frame.
##  4. States request transitions via request_transition(next_state_name).
class_name StateMachine
extends Node


## Signal emitted when the active state changes.
signal state_changed(old_state: String, new_state: String)


## The initial state to activate when the machine starts.
@export var initial_state: State:
	set(value):
		initial_state = value
		if _ready_called and value != null:
			_transition_to(value)

## All possible states. Must include the initial_state.
@export var states: Array[State] = []


## Currently active state (null before _ready).
var current_state: State

## Whether _ready() has completed.
var _ready_called: bool = false

## States indexed by state_name for O(1) lookup.
var _states_by_name: Dictionary = {}


func _ready() -> void:
	if _ready_called:
		return
	_register_states()
	_ready_called = true
	if initial_state != null:
		_transition_to(initial_state)


func _process(delta: float) -> void:
	if current_state != null:
		current_state.update(delta)


func _exit_tree() -> void:
	if current_state != null:
		current_state.exit()


## Register all states and connect their signals.
func _register_states() -> void:
	for s: State in states:
		if s == null:
			push_warning("StateMachine: null State in states array.")
			continue
		if s.state_name.is_empty():
			push_warning("StateMachine: State '%s' has empty state_name." % s.get_path())
			continue

		s.owner = get_parent()
		_states_by_name[s.state_name] = s
		s.transition_requested.connect(_on_transition_requested)


## Handle a transition requested by the current state.
func _on_transition_requested(next_state_name: String) -> void:
	if _states_by_name.has(next_state_name):
		_transition_to(_states_by_name[next_state_name])
	else:
		push_error("StateMachine: requested transition to unknown state '%s'." % next_state_name)


## Transition to a new state immediately.
func _transition_to(next: State) -> void:
	var old_name: String = ""
	if current_state != null:
		current_state.exit()
		old_name = current_state.state_name
		if current_state.transition_requested.is_connected(_on_transition_requested):
			pass  # Stay connected; we need it for future transitions.

	current_state = next
	current_state.enter()
	state_changed.emit(old_name, next.state_name)


## Get the name of the currently active state (empty string if none).
func get_current_state_name() -> String:
	return current_state.state_name if current_state != null else ""


## Check if a state with the given name exists in this machine.
func has_state(state_name: String) -> bool:
	return _states_by_name.has(state_name)


## Get a state by name (null if not found).
func get_state(state_name: String) -> State:
	return _states_by_name.get(state_name, null)
