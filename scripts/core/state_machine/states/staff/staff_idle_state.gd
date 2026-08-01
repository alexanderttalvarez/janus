## Staff state: Waiting for a task assignment.
## TODO Phase 11: Implement task queue polling, assignment logic.
class_name StaffIdleState
extends State


func enter() -> void:
	super.enter()
	# TODO Phase 11: Check task queue for assignments → transition to moving_to_task.


func update(_delta: float) -> void:
	# TODO Phase 11: Poll for new tasks periodically.
	pass


func exit() -> void:
	super.exit()
