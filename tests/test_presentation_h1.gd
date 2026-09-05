## Presentation read-model, intent, and notification boundary tests.
extends SceneTree

class FakeOwner:
	extends RefCounted

	func preview_intent(_request: Dictionary) -> Dictionary:
		return {"accepted": true, "preview": true}

	func commit_intent(_request: Dictionary) -> Dictionary:
		return {"accepted": true, "committed": true}


var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_read_models()
	_test_intent_gateway()
	_test_notifications()
	print("Presentation H1 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _source(revision: int, values: Dictionary) -> Dictionary:
	return {"availability": PresentationCoordinator.AVAILABLE, "source_revision": revision, "values": values}


func _test_read_models() -> void:
	var coordinator := PresentationCoordinator.new()
	var hud := coordinator.build_hud({"economy": _source(1, {"balance": 500}), "visitors": _source(2, {"current_visitors": 4, "daily_arrivals": 9}), "prestige": _source(3, {"official_prestige": 12}), "time": _source(4, {"simulation_speed": 2, "clock": "Day 3"}), "presentation": _source(5, {"wall_mode": "partial"})})
	_assert(hud["metrics"].size() == 7, "HUD contains only available canonical metrics")
	_assert(hud["metrics"]["money"] == 500 and hud["metrics"]["current_visitors"] == 4 and hud["metrics"]["daily_arrivals"] == 9, "HUD keeps money, current visitors, and daily arrivals distinct")
	var unavailable := coordinator.build_panel("tenants", {})
	_assert(unavailable["availability"] == PresentationCoordinator.UNAVAILABLE, "missing panel source is unavailable")
	var viability := coordinator.build_heatmap("zone_viability", {})
	_assert(not bool(viability["active"]), "viability heatmap does not fabricate a source")
	var density := coordinator.build_heatmap("visitor_density", {"visitor_density": _source(8, {"a": 0.5})})
	_assert(bool(density["active"]) and density["source_revision"] == 8, "available heatmap carries its source revision")


func _test_intent_gateway() -> void:
	var gateway := UIIntentGateway.new()
	gateway.register_owner("owner", FakeOwner.new())
	var preview := gateway.submit_preview({"request_id": "req_1", "owner_id": "owner", "value": 3})
	_assert(bool(preview.get("accepted", false)) and preview["request_id"] == "req_1", "preview routes a typed request and correlates its ID")
	var confirm := gateway.submit_confirm({"request_id": "req_2", "owner_id": "owner"})
	_assert(bool(confirm.get("committed", false)) and confirm["request_id"] == "req_2", "confirm routes through the owner commit port")
	var missing := gateway.submit_confirm({"request_id": "req_3", "owner_id": "missing"})
	_assert(not bool(missing.get("accepted", false)), "unknown owner returns an immediate diagnostic")


func _test_notifications() -> void:
	var adapter := NotificationAdapter.new()
	for index: int in range(4):
		adapter.project({"source_identity": "source_%d" % index, "category": "economy", "priority": "high", "calendar_identity": "day_1", "source_revision": index})
	_assert(adapter.visible_toasts().size() == 3, "notification adapter caps visible toasts at three")
	adapter.project({"source_identity": "source_0", "category": "economy", "priority": "high", "calendar_identity": "day_2", "source_revision": 5})
	_assert(adapter.entries().size() == 4, "duplicate source identity updates rather than duplicates the log")
	_assert(adapter.has_unresolved_high_priority(), "unresolved high-priority entry drives the red dot")
	adapter.mark_read("source_0")
	adapter.mark_resolved("source_0")
	for index: int in range(1, 4):
		adapter.mark_resolved("source_%d" % index)
	_assert(not adapter.has_unresolved_high_priority(), "resolved high-priority entries clear the red dot")
	_assert(adapter.duration_for("high") == 10 and adapter.duration_for("medium") == 7 and adapter.duration_for("low") == 5, "priority durations follow the approved policy")
