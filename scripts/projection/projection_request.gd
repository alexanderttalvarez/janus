class_name ProjectionRequest
extends RefCounted

## Immutable-at-boundary request data for runtime and editor projection builds.

var definition_fingerprint: String = ""
var district_revision: int = -1
var zone_revision: int = -1
var addresses: Array[Dictionary] = []
var affected_scope: Dictionary = {}
var layers: Array[String] = []
var editor_mode: bool = false
var metrics: ProjectionMetrics
var snapshot: ResolvedDistrictSnapshot
var state: Dictionary = {}
var descriptor_batches: Array[ProjectionDescriptorBatch] = []


func validate() -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if snapshot == null:
		diagnostics.append({"code": "SNAPSHOT_REQUIRED", "message": "projection request requires an immutable snapshot"})
	if definition_fingerprint.is_empty():
		diagnostics.append({"code": "FINGERPRINT_REQUIRED", "message": "projection request requires a definition fingerprint"})
	elif snapshot != null and snapshot.get_fingerprint() != definition_fingerprint:
		diagnostics.append({"code": "FINGERPRINT_MISMATCH", "message": "request fingerprint does not match the snapshot"})
	if district_revision < 0:
		diagnostics.append({"code": "DISTRICT_REVISION_INVALID", "message": "district revision cannot be negative"})
	if zone_revision < 0:
		diagnostics.append({"code": "ZONE_REVISION_INVALID", "message": "zone revision cannot be negative"})
	if metrics == null:
		diagnostics.append({"code": "METRICS_REQUIRED", "message": "projection request requires metrics"})
	else:
		var metrics_validation: Dictionary = metrics.validate()
		if not bool(metrics_validation.get("valid", false)):
			diagnostics.append_array(metrics_validation.get("diagnostics", []))
	for batch: ProjectionDescriptorBatch in descriptor_batches:
		var batch_validation: Dictionary = batch.validate(self)
		if not bool(batch_validation.get("valid", false)):
			diagnostics.append_array(batch_validation.get("diagnostics", []))
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}


func _batch_values() -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	for batch: ProjectionDescriptorBatch in descriptor_batches:
		values.append(batch.value())
	return values


func copy_value() -> Dictionary:
	return {
		"definition_fingerprint": definition_fingerprint,
		"district_revision": district_revision,
		"zone_revision": zone_revision,
		"addresses": addresses.duplicate(true),
		"affected_scope": affected_scope.duplicate(true),
		"layers": layers.duplicate(),
		"editor_mode": editor_mode,
		"metrics": metrics.value() if metrics != null else {},
		"descriptor_batches": _batch_values(),
	}
