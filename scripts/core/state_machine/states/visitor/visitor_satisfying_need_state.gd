## Visitor state: Satisfying a need (shopping, eating, etc.).
## TODO Phase 7: Implement need satisfaction loop, queue interaction.
class_name VisitorSatisfyingNeedState
extends State


func enter() -> void:
	super.enter()
	# TODO Phase 7: Enter store, join queue or begin consuming service.


func update(delta: float) -> void:
	super.update(delta)
	# TODO Phase 7: Decrease need value, check satisfaction → check next goal.


func exit() -> void:
	# TODO Phase 7: Leave store/service, update satisfaction score.
	super.exit()
