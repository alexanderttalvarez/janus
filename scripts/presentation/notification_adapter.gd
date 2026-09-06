class_name NotificationAdapter
extends RefCounted

## Converts committed notification projections into transient toasts and an
## in-session log. Authority state and resolution remain outside this class.
const MAX_VISIBLE_TOASTS: int = 3
const PRIORITY_DURATION_SECONDS: Dictionary = {"high": 10, "medium": 7, "low": 5}
const PRIORITY_RANK: Dictionary = {"high": 0, "medium": 1, "low": 2}

var _entries: Array[Dictionary] = []
var _visible_toasts: Array[String] = []
var _toast_queue: Array[String] = []
var _toast_remaining: Dictionary = {}


func project(condition: Dictionary) -> Dictionary:
	var source_identity: String = String(condition.get("source_identity", ""))
	if source_identity.is_empty():
		return {"committed": false, "diagnostics": [{"code": "NOTIFICATION_SOURCE_INVALID"}]}
	var priority: String = String(condition.get("priority", "low"))
	if not PRIORITY_DURATION_SECONDS.has(priority):
		priority = "low"
	var status: String = String(condition.get("status", "unread"))
	if not ["unread", "read", "resolved"].has(status):
		status = "unread"
	var entry: Dictionary = {
		"source_identity": source_identity,
		"text": String(condition.get("text", condition.get("message", ""))),
		"category": String(condition.get("category", "general")),
		"priority": priority,
		"calendar_identity": String(condition.get("calendar_identity", "")),
		"status": status,
		"source_revision": int(condition.get("source_revision", -1)),
		"navigation_target": String(condition.get("navigation_target", condition.get("action_target", ""))),
	}
	var existing_index: int = _index_for(source_identity)
	if existing_index >= 0:
		_entries[existing_index] = entry
	else:
		_entries.append(entry)
	_entries.sort_custom(_sort_entries)
	if status == "resolved":
		_remove_from_toast_lists(source_identity)
	else:
		_enqueue_if_needed(source_identity)
	_promote_toasts()
	return {"committed": true, "entry": entry.duplicate(true), "diagnostics": []}


func dismiss_toast(source_identity: String) -> void:
	_visible_toasts.erase(source_identity)
	_toast_remaining.erase(source_identity)
	_toast_queue.erase(source_identity)
	_promote_toasts()


func mark_read(source_identity: String) -> void:
	var index: int = _index_for(source_identity)
	if index >= 0 and String(_entries[index].get("status", "")) == "unread":
		_entries[index]["status"] = "read"


func mark_resolved(source_identity: String) -> void:
	var index: int = _index_for(source_identity)
	if index >= 0:
		_entries[index]["status"] = "resolved"
	_remove_from_toast_lists(source_identity)
	_promote_toasts()


func clear_read_resolved() -> void:
	var kept: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		var status: String = String(entry.get("status", ""))
		if status != "read" and status != "resolved":
			kept.append(entry)
	_entries = kept
	var valid_ids: Array[String] = []
	for entry: Dictionary in _entries:
		valid_ids.append(String(entry.get("source_identity", "")))
	_toast_queue = _toast_queue.filter(func(identity: String) -> bool: return valid_ids.has(identity))
	_visible_toasts = _visible_toasts.filter(func(identity: String) -> bool: return valid_ids.has(identity))
	_promote_toasts()


## Advance toast timers without touching authoritative state.
func advance_time(delta_seconds: float) -> void:
	if delta_seconds <= 0.0:
		return
	var expired: Array[String] = []
	for source_identity: String in _visible_toasts:
		var remaining: float = float(_toast_remaining.get(source_identity, 0.0)) - delta_seconds
		_toast_remaining[source_identity] = remaining
		if remaining <= 0.0:
			expired.append(source_identity)
	for source_identity: String in expired:
		dismiss_toast(source_identity)


func entries(category: String = "", status: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		if not category.is_empty() and String(entry.get("category", "")) != category:
			continue
		if not status.is_empty() and String(entry.get("status", "")) != status:
			continue
		result.append(entry.duplicate(true))
	return result


func visible_toasts() -> Array[String]:
	return _visible_toasts.duplicate()


func queued_toasts() -> Array[String]:
	return _toast_queue.duplicate()


func toast_remaining(source_identity: String) -> float:
	return float(_toast_remaining.get(source_identity, 0.0))


func has_unresolved_high_priority() -> bool:
	for entry: Dictionary in _entries:
		if String(entry.get("priority", "")) == "high" and String(entry.get("status", "")) != "resolved":
			return true
	return false


func duration_for(priority: String) -> int:
	return int(PRIORITY_DURATION_SECONDS.get(priority, PRIORITY_DURATION_SECONDS["low"]))


func navigation_intent(source_identity: String) -> Dictionary:
	var index: int = _index_for(source_identity)
	if index < 0:
		return {"accepted": false, "diagnostics": [{"code": "NOTIFICATION_NOT_FOUND"}]}
	var entry: Dictionary = _entries[index]
	var target: String = String(entry.get("navigation_target", ""))
	if target.is_empty():
		return {"accepted": false, "diagnostics": [{"code": "NOTIFICATION_TARGET_UNAVAILABLE"}]}
	return {
		"accepted": true,
		"intent_type": "notification_navigation",
		"source_identity": source_identity,
		"target": target,
		"diagnostics": [],
	}


func _enqueue_if_needed(source_identity: String) -> void:
	if _visible_toasts.has(source_identity) or _toast_queue.has(source_identity):
		return
	_toast_queue.append(source_identity)
	_toast_queue.sort_custom(_sort_toast_ids)


func _promote_toasts() -> void:
	_toast_queue = _toast_queue.filter(func(identity: String) -> bool: return _index_for(identity) >= 0 and not _is_resolved(identity))
	_toast_queue.sort_custom(_sort_toast_ids)
	while _visible_toasts.size() < MAX_VISIBLE_TOASTS and not _toast_queue.is_empty():
		var source_identity: String = _toast_queue.pop_front()
		if _visible_toasts.has(source_identity) or _is_resolved(source_identity):
			continue
		_visible_toasts.append(source_identity)
		var index: int = _index_for(source_identity)
		var priority: String = String(_entries[index].get("priority", "low")) if index >= 0 else "low"
		_toast_remaining[source_identity] = float(duration_for(priority))


func _remove_from_toast_lists(source_identity: String) -> void:
	_visible_toasts.erase(source_identity)
	_toast_queue.erase(source_identity)
	_toast_remaining.erase(source_identity)


func _is_resolved(source_identity: String) -> bool:
	var index: int = _index_for(source_identity)
	return index >= 0 and String(_entries[index].get("status", "")) == "resolved"


func _index_for(source_identity: String) -> int:
	for index: int in range(_entries.size()):
		if String(_entries[index].get("source_identity", "")) == source_identity:
			return index
	return -1


func _sort_entries(first: Dictionary, second: Dictionary) -> bool:
	var first_rank: int = int(PRIORITY_RANK.get(String(first.get("priority", "low")), 2))
	var second_rank: int = int(PRIORITY_RANK.get(String(second.get("priority", "low")), 2))
	if first_rank != second_rank:
		return first_rank < second_rank
	return String(first.get("source_identity", "")) < String(second.get("source_identity", ""))


func _sort_toast_ids(first: String, second: String) -> bool:
	var first_index: int = _index_for(first)
	var second_index: int = _index_for(second)
	if first_index < 0 or second_index < 0:
		return first < second
	return _sort_entries(_entries[first_index], _entries[second_index])
