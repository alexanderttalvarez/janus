class_name DistrictLayoutDefinition
extends Resource

## Immutable, validated H1 district definition.
## Shared Resources are never mutated after initialize() succeeds.

var _semantic_record: Dictionary = {}
var _diagnostics: Array[Dictionary] = []
var _published: bool = false


## Validate and publish a normalized semantic record.
## A failed initialization leaves the resource unpublished and empty.
func initialize(raw_record: Dictionary) -> Array[Dictionary]:
	var validation: Dictionary = DistrictLayoutValidator.new().normalize_and_validate(raw_record)
	_diagnostics = validation.get("diagnostics", []).duplicate(true)
	_published = bool(validation.get("valid", false))
	if _published:
		_semantic_record = validation.get("record", {}).duplicate(true)
	else:
		_semantic_record.clear()
	return _diagnostics.duplicate(true)


func is_published() -> bool:
	return _published


func get_diagnostics() -> Array[Dictionary]:
	return _diagnostics.duplicate(true)


## Returns a defensive copy so callers cannot mutate the published resource.
func get_semantic_record() -> Dictionary:
	return _semantic_record.duplicate(true)


func get_layout_id() -> String:
	return String(_semantic_record.get("layout", {}).get("layout_id", ""))


func get_definition_schema_version() -> int:
	return int(_semantic_record.get("definition_schema_version", 0))


func get_section_count() -> int:
	var count: int = 0
	for slot: Dictionary in _semantic_record.get("layout", {}).get("slots", []):
		count += slot.get("sections", []).size()
	return count


func get_slot_count() -> int:
	return _semantic_record.get("layout", {}).get("slots", []).size()


func get_sources() -> Array:
	return _semantic_record.get("layout", {}).get("arrival_sources", []).duplicate(true)
