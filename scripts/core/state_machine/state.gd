## State — Resource-based base class for all entity states.
## Used by Visitor, Tenant, and Staff state machines.
##
## Each concrete state subclasses this Resource and overrides
## enter(), exit(), and update() to implement behavior.
## Transitions are requested by calling request_transition().
class_name State
extends Resource


## Emitted when this state becomes active.
signal state_entered

## Emitted when this state is deactivated.
signal state_exited

## Emitted each frame while this state is active.
signal state_updated(delta: float)

## Emitted when this state requests a transition.
signal transition_requested(next_state: String)


## Unique name for this state, used for transition lookups.
@export var state_name: String = ""


## Reference to the owning Node. Set at runtime by StateMachine.
## Cannot be @export on a Resource (Node is not serializable).
var owner: Node


## Called when this state becomes active.
func enter() -> void:
	state_entered.emit()


## Called when this state is deactivated.
func exit() -> void:
	state_exited.emit()


## Called each frame. Override in subclasses to implement behavior.
func update(_delta: float) -> void:
	state_updated.emit(_delta)


## Request a transition to another state by name.
## The owning StateMachine listens for this signal.
func request_transition(next_state: String) -> void:
	transition_requested.emit(next_state)
