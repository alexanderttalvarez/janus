class_name DistrictCommitJournal
extends RefCounted

## In-memory H3 commit journal. append() is the commit point and is designed
## to be non-failing once can_append() has accepted the envelope.

var _entries: Array[Dictionary] = []
var append_enabled: bool = true
var append_preflight_enabled: bool = true


func can_append(envelope: Dictionary) -> bool:
	return append_enabled and append_preflight_enabled and not envelope.is_empty()


func append(envelope: Dictionary) -> bool:
	if not append_enabled or envelope.is_empty():
		return false
	_entries.append(envelope.duplicate(true))
	return true


func get_entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


func get_entry_count() -> int:
	return _entries.size()


func clear() -> void:
	_entries.clear()
