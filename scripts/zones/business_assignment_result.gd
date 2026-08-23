## BusinessAssignmentResult — Pure parcel-subtype assignments and diagnostics.
class_name BusinessAssignmentResult
extends RefCounted


const NO_ELIGIBLE_SUBTYPE: String = "NO_ELIGIBLE_SUBTYPE"
const NO_LEGAL_SUBTYPE: String = "NO_LEGAL_SUBTYPE"

## Assigned subtype ID by stable parcel ID.
var assignments: Dictionary = {}  # Dictionary[String, String]

## Failure diagnostic by unassigned stable parcel ID.
var diagnostics: Dictionary = {}  # Dictionary[String, String]


func assign(parcel_id: String, subtype_id: String) -> void:
	assignments[parcel_id] = subtype_id
	diagnostics.erase(parcel_id)


func leave_unassigned(parcel_id: String, diagnostic: String) -> void:
	assignments.erase(parcel_id)
	diagnostics[parcel_id] = diagnostic


func subtype_for(parcel_id: String) -> String:
	return assignments.get(parcel_id, "")


func diagnostic_for(parcel_id: String) -> String:
	return diagnostics.get(parcel_id, "")
