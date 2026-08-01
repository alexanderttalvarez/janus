## Staff state: Moving to a task location.
## TODO Phase 11: Implement pathfinding, movement interpolation, arrival detection.
class_name StaffMovingToTaskState
extends State


func enter() -> void:
	super.enter()
	# TODO Phase 11: Start pathfinding to assigned task location.


func update(delta: float) -> void:
	super.update(delta)
	# TODO Phase 11: Move toward target, check arrival → transition to working.


func exit() -> void:
	# TODO Phase 11: Stop movement animation.
	super.exit()
