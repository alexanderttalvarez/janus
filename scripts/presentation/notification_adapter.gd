class_name NotificationAdapter
extends RefCounted

const MAX_VISIBLE_TOASTS: int = 3
const PRIORITY_DURATION_SECONDS: Dictionary = {"high": 10, "medium": 7, "low": 5}

var _entries: Array[Dictionary] = []
var _visible_toasts: Array[String] = []


func project(condition: Dictionary) -> Dictionary:
	var source_identity := String(condition.get("source_identity", ""))
	if source_identity.is_empty():
		return {"committed": false, "diagnostics": [{"code": "NOTIFICATION_SOURCE_INVALID"}]}
	var entry := {
		"source_identity": source_identity,
		"category": String(condition.get("category", "general")),
		"priority": String(condition.get("priority", "low")),
		"calendar_identity": String(condition.get("calendar_identity", "")),
		"status": String(condition.get("status", "unread")),
		"source_revision": int(condition.get("source_revision", -1)),
		"navigation_target": String(condition.get("navigation_target", "")),
	}
	var existing_index := _index_for(source_identity)
	if existing_index >= 0:
		_entries[existing_index] = entry
	else:
		_entries.append(entry)
		_entries.sort_custom(_sort_entries)
	if entry["status"] != "resolved" and not _visible_toasts.has(source_identity) and _visible_toasts.size() < MAX_VISIBLE_TOASTS:
		_visible_toasts.append(source_identity)
	return {"committed": true, "entry": entry.duplicate(true), "diagnostics": []}


func dismiss_toast(source_identity: String) -> void:
	_visible_toasts.erase(source_identity)


func mark_read(source_identity: String) -> void:
	var index := _index_for(source_identity)
	if index >= 0 and String(_entries[index].get("status", "")) == "unread":
		_entries[index]["status"] = "read"


func mark_resolved(source_identity: String) -> void:
	var index := _index_for(source_identity)
	if index >= 0:
		_entries[index]["status"] = "resolved"
	_visible_toasts.erase(source_identity)


func clear_read_resolved() -> void:
	var kept: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		var status := String(entry.get("status", ""))
		if status != "read" and status != "resolved":
			kept.append(entry)
	_entries = kept


func entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


func visible_toasts() -> Array[String]:
	return _visible_toasts.duplicate()


func has_unresolved_high_priority() -> bool:
	for entry: Dictionary in _entries:
		if String(entry.get("priority", "")) == "high" and String(entry.get("status", "")) != "resolved":
			return true
	return false


func duration_for(priority: String) -> int:
	return int(PRIORITY_DURATION_SECONDS.get(priority, PRIORITY_DURATION_SECONDS["low"]))


func _index_for(source_identity: String) -> int:
	for index: int in range(_entries.size()):
		if String(_entries[index].get("source_identity", "")) == source_identity:
			return index
	return -1


static func _sort_entries(first: Dictionary, second: Dictionary) -> bool:
	return String(first.get("source_identity", "")) < String(second.get("source_identity", ""))
