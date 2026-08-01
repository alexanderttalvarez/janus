## Tenant state: The business is open and operating normally.
## TODO Phase 8: Implement revenue generation, visitor service, viability monitoring.
class_name TenantOperatingState
extends State


func enter() -> void:
	super.enter()
	# TODO Phase 8: Start revenue generation, open to visitors, begin viability monitoring.


func update(delta: float) -> void:
	super.update(delta)
	# TODO Phase 8: Generate revenue, check viability thresholds → transition to critical if failing.


func exit() -> void:
	# TODO Phase 8: Close to visitors.
	super.exit()
