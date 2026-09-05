class_name ArrivalCommitDispatcher
extends RefCounted

## Ordered in-memory arrival envelope dispatcher. append() is the commit point;
## dispatch diagnostics never alter committed authority or event order.

var append_enabled: bool = true
var append_preflight_enabled: bool = true
var _entries: Array[Dictionary] = []
var _subscribers: Array[Callable] = []


func subscribe(handler: Callable) -> int:
	if not handler.is_valid():
		return -1
	_subscribers.append(handler)
	return _subscribers.size() - 1


func unsubscribe(handler: Callable) -> bool:
	var index: int = _subscribers.find(handler)
	if index < 0:
		return false
	_subscribers.remove_at(index)
	return true


func can_append(envelope: Dictionary) -> bool:
	return append_enabled and append_preflight_enabled and _is_complete_envelope(envelope) and not _has_commit_id(String(envelope.get("commit_id", "")))


func append(envelope: Dictionary) -> bool:
	if not append_enabled or not _is_complete_envelope(envelope) or _has_commit_id(String(envelope.get("commit_id", ""))):
		return false
	_entries.append(envelope.duplicate(true))
	return true


func dispatch(envelope: Dictionary) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	var subscribers: Array[Callable] = _subscribers.duplicate()
	for index: int in range(subscribers.size()):
		var handler: Callable = subscribers[index]
		if not handler.is_valid():
			diagnostics.append({"code": "ARRIVAL_SUBSCRIBER_INVALID", "subscriber_index": index})
			continue
		var result: Variant = handler.call(envelope)
		if result is Dictionary and not bool(result.get("ok", true)):
			diagnostics.append({"code": "ARRIVAL_SUBSCRIBER_FAULT", "subscriber_index": index, "detail": result.get("detail", "subscriber rejected envelope")})
		elif result is bool and not bool(result):
			diagnostics.append({"code": "ARRIVAL_SUBSCRIBER_FAULT", "subscriber_index": index, "detail": "subscriber rejected envelope"})
		elif result is String and not String(result).is_empty():
			diagnostics.append({"code": "ARRIVAL_SUBSCRIBER_FAULT", "subscriber_index": index, "detail": String(result)})
	return diagnostics


func get_entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


func get_entry_count() -> int:
	return _entries.size()


func get_subscriber_count() -> int:
	return _subscribers.size()


func clear() -> void:
	_entries.clear()


func _is_complete_envelope(envelope: Dictionary) -> bool:
	if String(envelope.get("event_type", "")) != "arrival_realized" or String(envelope.get("commit_id", "")).is_empty() or String(envelope.get("arrival_source_id", "")).is_empty() or String(envelope.get("demand_snapshot_id", "")).is_empty():
		return false
	var revisions: Variant = envelope.get("revisions", null)
	var source: Variant = envelope.get("source", null)
	var visitor: Variant = envelope.get("visitor", null)
	if not revisions is Dictionary or not source is Dictionary or not visitor is Dictionary:
		return false
	for revision_name: String in ["district_revision", "topology_revision", "eligibility_revision"]:
		if typeof(revisions.get(revision_name, null)) != TYPE_INT:
			return false
	return true


func _has_commit_id(commit_id: String) -> bool:
	if commit_id.is_empty():
		return false
	for entry: Dictionary in _entries:
		if String(entry.get("commit_id", "")) == commit_id:
			return true
	return false
