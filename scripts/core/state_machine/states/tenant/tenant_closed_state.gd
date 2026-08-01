## Tenant state: The business has permanently closed.
## TODO Phase 8: Zone returns to vacant, notify player, record history.
class_name TenantClosedState
extends State


func enter() -> void:
	super.enter()
	# TODO Phase 8: Finalize closure, emit tenant_closed on EventBus, start vacancy timer.


func exit() -> void:
	super.exit()
