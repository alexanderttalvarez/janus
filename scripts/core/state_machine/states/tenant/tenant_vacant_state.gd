## Tenant state: Zone is empty, waiting for an application.
## TODO Phase 8: Trigger application evaluation after 1 sim day.
class_name TenantVacantState
extends State


func enter() -> void:
	super.enter()
	# TODO Phase 8: Start vacancy timer (1 sim day). After timer, transition to applying.


func exit() -> void:
	super.exit()
