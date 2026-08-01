## Staff state: Performing a task at the target location.
## TODO Phase 11: Implement task execution, progress tracking, completion detection.
class_name StaffWorkingState
extends State


func enter() -> void:
	super.enter()
	# TODO Phase 11: Begin task execution (cleaning, security patrol, etc.).


func update(delta: float) -> void:
	super.update(delta)
	# TODO Phase 11: Progress task, check completion → transition to idle.


func exit() -> void:
	# TODO Phase 11: Finalize task, update world state.
	super.exit()
