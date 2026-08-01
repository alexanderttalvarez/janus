## Visitor state: Entering the district.
## TODO Phase 7: Spawn visitor, initialize position, begin entry animation.
class_name VisitorEnteringState
extends State


func enter() -> void:
	super.enter()
	# TODO Phase 7: Spawn visitor Node3D, set initial position, play enter animation.
	request_transition("setting_goals")


func exit() -> void:
	# TODO Phase 7: Clean up entry state resources.
	super.exit()
