## Tenant state: A tenant has applied and is being evaluated.
## TODO Phase 8: Implement application scoring (prestige match, rent, location, synergy, competition).
class_name TenantApplyingState
extends State


func enter() -> void:
	super.enter()
	# TODO Phase 8: Generate applicant, evaluate score, show to player or auto-accept.


func exit() -> void:
	super.exit()
