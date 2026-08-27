## DebugManager — Reusable development debug flags.
## Registered as autoload "DebugManager" in project settings.
extends Node


signal parcel_labels_visibility_changed(is_visible: bool)
signal zone_labels_visibility_changed(is_visible: bool)


var god_mode: bool = false
var infinite_money: bool = false
var instant_construction: bool = false
var time_warp: bool = false

## Enabled by default in debug builds and disabled by default in release builds.
var show_parcel_labels: bool = not OS.has_feature("release")
var show_zone_labels: bool = not OS.has_feature("release")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_show_parcel_labels(is_visible: bool) -> void:
	if show_parcel_labels == is_visible:
		return
	show_parcel_labels = is_visible
	parcel_labels_visibility_changed.emit(show_parcel_labels)


func set_show_zone_labels(is_visible: bool) -> void:
	if show_zone_labels == is_visible:
		return
	show_zone_labels = is_visible
	zone_labels_visibility_changed.emit(show_zone_labels)
