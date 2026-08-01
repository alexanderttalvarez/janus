# Decision 23: State Machine Architecture — Resource-Based FSM Pattern
**Date:** 2026-07-28
**Status:** Accepted

## Context
Several core systems (Visitor Agents, Tenant Lifecycle, Staff Behavior, Zone Tool) have complex, interdependent behavior with clear state transitions. We needed a consistent, debuggable, and maintainable state machine pattern.

## Decision
- **Resource-based State Machine** — each state is a `Resource` with `enter()`, `exit()`, `update(delta)` methods
- **StateMachine controller** — generic Node that manages state transitions, emits signals
- **Used by**: Visitor Agents, Tenant Lifecycle, Staff Behavior, Zone Tool, Game Session
- **Not used for**: Simple 2-3 state systems (UI modes use enum + match instead)

## Core Structure
```
scripts/core/state_machine/
├── state_machine.gd          # Generic FSM controller (Node)
├── state.gd                  # Base state class (Resource)
└── states/
    ├── visitor/              # Visitor agent states
    ├── tenant/               # Tenant lifecycle states
    └── staff/                # Staff behavior states
```

## StateMachine Structure
```gdscript
class_name StateMachine extends Node

@export var initial_state: State
@export var states: Array[State]
var current_state: State

func _ready() -> void: ...
func _process(delta: float) -> void: ...
func _on_transition_requested(next_state_name: String) -> void: ...
```

## State Base Class
```gdscript
class_name State extends Resource

signal state_entered
signal state_exited
signal state_updated(delta: float)
signal transition_requested(next_state: String)

@export var state_name: String
@export var owner: Node

func enter() -> void: ...
func exit() -> void: ...
func update(delta: float) -> void: ...
func request_transition(next_state: String) -> void: ...
```

## Visitor State Machine
```
ENTERING → SETTING_GOALS → MOVING → SATISFYING_NEED → EXPLORING → QUEUING → LEAVING
```

## Tenant State Machine
```
VACANT → APPLYING → EXCLUSIVITY_LOCK → CONSTRUCTING → OPERATING → CRITICAL → CLOSING → CLOSED
```

## Staff State Machine
```
IDLE → MOVING_TO_TASK → WORKING → IDLE
```

## Rationale
- Resource-based states are Inspector-editable and reusable across entities
- Centralized StateMachine controller handles transitions cleanly
- Each state is a separate file — easy to test, debug, and iterate
- Signals provide visibility into state changes (useful for debugging and UI)
- Avoids enum + match sprawl in large files

## Consequences
- State Machine framework must be built before Phase 7 (Visitor System)
- Can be developed in parallel with Phases 2-6 (Grid, Camera, Shaders, Time)
- Each state file is small and focused — easy to maintain
- Debug overlay can show current state for any entity
