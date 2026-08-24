## ZoneTool rectangle-painting tests.
## Run with: godot --headless --path . -s res://tests/test_zone_tool.gd
extends Node


var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	_test_forward_rectangle()
	_test_reverse_rectangle()
	_test_single_tile_rectangle()
	print("ZoneTool tests: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _test_forward_rectangle() -> void:
	var tiles := ZoneTool.rectangle_tiles(Vector2i(2, 3), Vector2i(4, 5))
	_assert(tiles.size() == 9, "forward drag selects the full inclusive rectangle")
	_assert(tiles.has(Vector2i(2, 3)), "forward rectangle includes its start tile")
	_assert(tiles.has(Vector2i(4, 5)), "forward rectangle includes its end tile")


func _test_reverse_rectangle() -> void:
	var tiles := ZoneTool.rectangle_tiles(Vector2i(4, 5), Vector2i(2, 3))
	_assert(tiles.size() == 9, "reverse drag selects the same rectangle")
	_assert(tiles == ZoneTool.rectangle_tiles(Vector2i(2, 3), Vector2i(4, 5)), "drag direction does not change selection")


func _test_single_tile_rectangle() -> void:
	var tiles := ZoneTool.rectangle_tiles(Vector2i(7, 8), Vector2i(7, 8))
	_assert(tiles == [Vector2i(7, 8)], "click without movement selects one tile")
