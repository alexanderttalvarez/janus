## Tenant state: The business is in financial distress.
## TODO Phase 8: Implement 3-period grace window, viability recovery checks.
class_name TenantCriticalState
extends State


func enter() -> void:
	super.enter()
	# TODO Phase 8: Start 3-period grace timer. Monitor for recovery.


func update(delta: float) -> void:
	super.update(delta)
	# TODO Phase 8: Check if recovery conditions met → transition to operating, or to closing after grace.


func exit() -> void:
	super.exit()
