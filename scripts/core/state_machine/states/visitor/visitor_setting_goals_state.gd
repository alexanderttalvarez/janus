## Visitor state: Setting shopping/visit goals.
## TODO Phase 7: Assign goals based on visitor profile, budget, and available zones.
class_name VisitorSettingGoalsState
extends State


func enter() -> void:
	super.enter()
	# TODO Phase 7: Select target zones, calculate budget, determine visit purpose.
	request_transition("moving")


func exit() -> void:
	# TODO Phase 7: Finalize goal data.
	super.exit()
