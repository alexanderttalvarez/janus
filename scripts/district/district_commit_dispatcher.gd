class_name DistrictCommitDispatcher
extends RefCounted

## Synchronous ordered committed-envelope fan-out. Subscriber diagnostics never
## affect the already committed authority state or remaining subscribers.

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


func dispatch(envelope: Dictionary) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	for index: int in range(_subscribers.size()):
		var handler: Callable = _subscribers[index]
		if not handler.is_valid():
			diagnostics.append({"code": "SUBSCRIBER_INVALID", "subscriber_index": index})
			continue
		var result: Variant = handler.call(envelope)
		if result is Dictionary and not bool(result.get("ok", true)):
			diagnostics.append({"code": "SUBSCRIBER_FAULT", "subscriber_index": index, "detail": result.get("detail", "subscriber rejected envelope")})
		elif result is String and not String(result).is_empty():
			diagnostics.append({"code": "SUBSCRIBER_FAULT", "subscriber_index": index, "detail": String(result)})
	return diagnostics


func get_subscriber_count() -> int:
	return _subscribers.size()
