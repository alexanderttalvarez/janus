## Visitor state: Exploring the district without a specific goal.
## TODO Phase 7: Implement random wandering, storefront attraction checks.
class_name VisitorExploringState
extends State


func enter() -> void:
	super.enter()
	# TODO Phase 7: Begin wandering behavior, check storefront attraction.


func update(delta: float) -> void:
	super.update(delta)
	# TODO Phase 7: Random walk, check attraction radius → transition to satisfying_need or queuing.


func exit() -> void:
	# TODO Phase 7: Stop wandering.
	super.exit()
