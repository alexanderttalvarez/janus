class_name ProjectionResult
extends RefCounted

## Detached presentation result. The candidate root is attached only by the
## Projection Coordinator after revision/fingerprint validation.

var valid: bool = false
var manifest: Dictionary = {}
var source_mappings: Array[Dictionary] = []
var transforms: Array[Dictionary] = []
var bounds: Array[Dictionary] = []
var budgets: Dictionary = {}
var diagnostics: Array[Dictionary] = []
var candidate_root: Node3D
var descriptor_batches: Array[ProjectionDescriptorBatch] = []


func value() -> Dictionary:
	return {
		"valid": valid,
		"manifest": manifest.duplicate(true),
		"source_mappings": source_mappings.duplicate(true),
		"transforms": transforms.duplicate(true),
		"bounds": bounds.duplicate(true),
		"budgets": budgets.duplicate(true),
		"diagnostics": diagnostics.duplicate(true),
		"descriptor_batches": _batch_values(),
	}


func _batch_values() -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	for batch: ProjectionDescriptorBatch in descriptor_batches:
		values.append(batch.value())
	return values
