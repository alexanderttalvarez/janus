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
	return append_enabled and append_preflight_enabled and not envelope.is_empty()


func append(envelope: Dictionary) -> bool:
	if not append_enabled or envelope.is_empty():
		return false
	_entries.append(envelope.duplicate(true))
	return true


func dispatch(envelope: Dictionary) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	for index: int in range(_subscribers.size()):
		var handler: Callable = _subscribers[index]
		if not handler.is_valid():
			diagnostics.append({"code": "ARRIVAL_SUBSCRIBER_INVALID", "subscriber_index": index})
			continue
		var result: Variant = handler.call(envelope)
		if result is Dictionary and not bool(result.get("ok", true)):
			diagnostics.append({"code": "ARRIVAL_SUBSCRIBER_FAULT", "subscriber_index": index, "detail": result.get("detail", "subscriber rejected envelope")})
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
