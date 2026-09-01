class_name ProjectionDescriptorBatch
extends RefCounted

## Immutable-at-boundary generic H4 presentation channel. H5 provides semantic
## primitives; H4 only validates revisions and materializes their payloads.

var channel_id: String = ""
var owner_id: String = ""
var definition_fingerprint: String = ""
var district_revision: int = -1
var zone_revision: int = -1
var affected_scope: Dictionary = {}
var primitives: Array[Dictionary] = []


func initialize(
	p_channel_id: String,
	p_owner_id: String,
	p_definition_fingerprint: String,
	p_district_revision: int,
	p_zone_revision: int,
	p_affected_scope: Dictionary,
	p_primitives: Array
) -> void:
	channel_id = p_channel_id
	owner_id = p_owner_id
	definition_fingerprint = p_definition_fingerprint
	district_revision = p_district_revision
	zone_revision = p_zone_revision
	affected_scope = p_affected_scope.duplicate(true)
	primitives = _typed_copy(p_primitives)


func add_primitive(primitive: Dictionary) -> void:
	primitives.append(primitive.duplicate(true))


func validate(request: ProjectionRequest) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if channel_id.is_empty():
		diagnostics.append({"code": "PROJECTION_CHANNEL_REQUIRED", "message": "projection channel ID is required"})
	if owner_id.is_empty():
		diagnostics.append({"code": "PROJECTION_OWNER_REQUIRED", "message": "projection channel owner ID is required"})
	if request == null:
		diagnostics.append({"code": "REQUEST_REQUIRED", "message": "projection channel requires a request"})
	else:
		if definition_fingerprint != request.definition_fingerprint:
			diagnostics.append({"code": "PROJECTION_CHANNEL_FINGERPRINT_MISMATCH", "message": "projection channel fingerprint does not match the request"})
		if district_revision != request.district_revision:
			diagnostics.append({"code": "PROJECTION_CHANNEL_DISTRICT_REVISION_MISMATCH", "message": "projection channel district revision does not match the request"})
		if zone_revision != request.zone_revision:
			diagnostics.append({"code": "PROJECTION_CHANNEL_ZONE_REVISION_MISMATCH", "message": "projection channel zone revision does not match the request"})
	if district_revision < 0:
		diagnostics.append({"code": "PROJECTION_CHANNEL_DISTRICT_REVISION_INVALID", "message": "projection channel district revision cannot be negative"})
	if zone_revision < 0:
		diagnostics.append({"code": "PROJECTION_CHANNEL_ZONE_REVISION_INVALID", "message": "projection channel zone revision cannot be negative"})
	for index: int in range(primitives.size()):
		var primitive: Dictionary = primitives[index]
		for field: String in ["primitive_id", "source_id", "layer", "primitive_kind", "presentation_payload"]:
			if not primitive.has(field):
				diagnostics.append({"code": "PROJECTION_PRIMITIVE_FIELD_MISSING", "path": "$.primitives[%d].%s" % [index, field], "message": "projection primitive field is required"})
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}


func value() -> Dictionary:
	return {
		"channel_id": channel_id,
		"owner_id": owner_id,
		"definition_fingerprint": definition_fingerprint,
		"district_revision": district_revision,
		"zone_revision": zone_revision,
		"affected_scope": affected_scope.duplicate(true),
		"primitives": primitives.duplicate(true),
	}


func _typed_copy(records: Array) -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	for record: Variant in records:
		if record is Dictionary:
			copied.append(record.duplicate(true))
	return copied
