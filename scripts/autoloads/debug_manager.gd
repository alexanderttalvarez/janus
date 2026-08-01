## DebugManager — Development debug flags. Auto-disabled in release builds.
## Registered as autoload "DebugManager" in project settings.
extends Node


var god_mode: bool = false
var infinite_money: bool = false
var instant_construction: bool = false
var time_warp: bool = false


func _ready() -> void:
	if OS.has_feature("release"):
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
