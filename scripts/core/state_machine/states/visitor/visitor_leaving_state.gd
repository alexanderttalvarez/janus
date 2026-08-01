## Visitor state: Leaving the district.
## TODO Phase 7: Record visit data, despawning logic, satisfaction calculation.
class_name VisitorLeavingState
extends State


func enter() -> void:
	super.enter()
	# TODO Phase 7: Record satisfaction, emit visitor_left on EventBus, despawn.


func exit() -> void:
	super.exit()
