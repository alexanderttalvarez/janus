## Visitor state: Waiting in a queue.
## TODO Phase 7: Implement queue position tracking, patience decay.
class_name VisitorQueuingState
extends State


func enter() -> void:
	super.enter()
	# TODO Phase 7: Join queue at storefront/elevator/transit point.


func update(delta: float) -> void:
	super.update(delta)
	# TODO Phase 7: Decrease patience, check position advancement → transition to satisfying_need or exploring.


func exit() -> void:
	# TODO Phase 7: Leave queue, update queue data.
	super.exit()
