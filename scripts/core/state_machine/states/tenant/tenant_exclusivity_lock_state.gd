## Tenant state: Zone is reserved while the accepted tenant prepares to build.
## TODO Phase 8: Implement 1-week exclusivity lock before construction begins.
class_name TenantExclusivityLockState
extends State


func enter() -> void:
	super.enter()
	# TODO Phase 8: Start 1-week timer. Prevent other tenants from applying.


func exit() -> void:
	super.exit()
