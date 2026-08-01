## Visitor state: Moving through the district toward a goal.
## TODO Phase 7: Implement pathfinding, movement interpolation, floor transitions.
class_name VisitorMovingState
extends State


func enter() -> void:
	super.enter()
	# TODO Phase 7: Start pathfinding toward current goal location.


func update(delta: float) -> void:
	super.update(delta)
	# TODO Phase 7: Move toward target, check arrival → transition to satisfying_need/exploring.


func exit() -> void:
	# TODO Phase 7: Stop movement animation.
	super.exit()
