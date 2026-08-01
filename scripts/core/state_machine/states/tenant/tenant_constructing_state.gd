## Tenant state: The tenant's space is under construction.
## TODO Phase 8: Implement construction phases (3 visual stages), progress tracking.
class_name TenantConstructingState
extends State


func enter() -> void:
	super.enter()
	# TODO Phase 8: Start construction timer (0.3 sim weeks × tile count).


func update(delta: float) -> void:
	super.update(delta)
	# TODO Phase 8: Progress construction, update visual phase, transition to operating on completion.


func exit() -> void:
	# TODO Phase 8: Finalize construction, mark zone as ready.
	super.exit()
