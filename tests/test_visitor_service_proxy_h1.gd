## Visitor H1 tests for public proxy behavior, queues, results, and metrics.
extends SceneTree


var _passed: int = 0
var _failed: int = 0
var _manager: VisitorManager
var _events: Array[Dictionary] = []


func _init() -> void:
	_manager = VisitorManager.new()
	_manager.set_proxy_anchor_resolver(Callable(self, "_resolve_proxy_anchor"))
	_manager.visitor_purchase_result_committed.connect(_on_purchase_result)
	_test_proxy_contract_and_ordering()
	_test_route_staleness_and_cancellation()
	_test_fifo_queue_and_exactly_once_result()
	_test_metrics_and_persistence()
	_manager.all_visitors.clear()
	_manager.free()
	print("Visitor H1 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_proxy_contract_and_ordering() -> void:
	var invalid: Dictionary = _proxy("proxy_invalid", true)
	invalid["node"] = Node3D.new()
	var publish: Dictionary = _manager.consume_service_proxies([
		_proxy("proxy_b", true),
		_proxy("proxy_a", true),
		invalid,
	])
	_assert(bool(publish.get("valid", false)) and int(publish.get("proxy_count", -1)) == 2, "only complete eligible proxy snapshots are published")
	var selected: Dictionary = _manager.select_service_proxy("visitor_1")
	_assert(bool(selected.get("valid", false)) and String(selected.get("proxy", {}).get("parcel_door_proxy_id", "")) == "proxy_a", "proxy selection uses canonical stable-ID ordering")
	var invalid_proxy := VisitorServiceProxy.new()
	invalid_proxy.configure(invalid)
	_assert(not bool(invalid_proxy.validate().get("valid", false)), "proxy snapshots reject Node-derived identity fields")
	invalid["node"].free()
	var missing_anchor: Dictionary = _proxy("proxy_missing_anchor", true)
	missing_anchor.erase("corridor_anchor_id")
	_manager.consume_service_proxies([missing_anchor])
	var missing_snapshot: Dictionary = _manager.capture_service_proxy_snapshot("visitor_1")
	_assert(not bool(missing_snapshot.get("valid", false)), "unresolved corridor anchors are unavailable rather than coordinate-fallback targets")
	_manager.consume_service_proxies([_proxy("proxy_b", true), _proxy("proxy_a", true)])


func _test_route_staleness_and_cancellation() -> void:
	var visitor := _add_visitor("visitor_1")
	var snapshot: Dictionary = _manager.capture_service_proxy_snapshot(visitor.id)
	var route: Dictionary = _manager.request_proxy_route(visitor.id, snapshot)
	_assert(bool(route.get("valid", false)) and visitor.current_state == "moving_to_proxy" and visitor.target_proxy_id == "proxy_a", "proxy route stores stable target and captured revisions")
	var stale: Dictionary = _manager.revalidate_service_proxy("proxy_a", 99, 1, 1)
	_assert(not bool(stale.get("valid", false)) and _has_code(stale.get("diagnostics", []), "SERVICE_PROXY_STALE"), "route revisions reject stale proxy snapshots")
	_manager.cancel_proxy_target(visitor.id)
	_assert(visitor.target_proxy_id.is_empty() and visitor.route_request_id.is_empty() and visitor.current_state == "moving", "target cancellation clears transient route state idempotently")
	_manager.cancel_proxy_target(visitor.id)
	_assert(visitor.target_proxy_id.is_empty() and not _manager._proxy_queues.has("proxy_a"), "repeated cancellation does not leak queue participation")


func _test_fifo_queue_and_exactly_once_result() -> void:
	var visitor := _add_visitor("visitor_2")
	var snapshot: Dictionary = _manager.capture_service_proxy_snapshot(visitor.id)
	_manager.request_proxy_route(visitor.id, snapshot)
	var queued: Dictionary = _manager.enqueue_service_proxy(visitor.id, "proxy_a")
	_assert(bool(queued.get("valid", false)), "eligible visitor enters the proxy FIFO queue")
	var duplicate_queue: Dictionary = _manager.enqueue_service_proxy(visitor.id, "proxy_a")
	_assert(bool(duplicate_queue.get("already_queued", false)), "queue admission is idempotent for one visitor")
	var completed: Dictionary = _manager.complete_service_proxy(visitor.id, "proxy_a", 0)
	_assert(bool(completed.get("valid", false)) and _events.size() == 1, "proxy completion commits one visitor-side result event")
	var repeated: Dictionary = _manager.complete_service_proxy(visitor.id, "proxy_a", 0)
	_assert(not bool(repeated.get("valid", false)) and _has_code(repeated.get("diagnostics", []), "VISITOR_PURCHASE_ALREADY_COMMITTED"), "completed proxy result cannot be committed twice")
	_assert(not _manager._proxy_queues.has("proxy_a"), "completed visitor leaves no queue reservation")
	var unavailable: Dictionary = _manager.enqueue_service_proxy("visitor_unavailable", "missing_proxy")
	_assert(not bool(unavailable.get("valid", false)), "unknown proxy cannot accept queue participation")


func _test_metrics_and_persistence() -> void:
	var arriving := VisitorData.new()
	arriving.initialize("visitor_3", "G", Vector3.ZERO)
	arriving.arrival_source_id = "gateway_east"
	var prepared: Dictionary = {"visitor": arriving, "visitor_id": arriving.id}
	_assert(bool(_manager.commit_prepared_visitor(prepared).get("valid", false)), "committed arrivals increment VisitorManager metrics")
	var before_boundary: Dictionary = _manager.get_metrics_snapshot()
	_assert(int(before_boundary.get("current_visitors", -1)) == 3 and int(before_boundary.get("daily_arrivals", -1)) == 1 and not bool(before_boundary.get("average_available", true)), "metrics distinguish active visitors, daily arrivals, and first-day average")
	_manager.on_sim_day_passed(1)
	var after_boundary: Dictionary = _manager.get_metrics_snapshot()
	_assert(bool(after_boundary.get("average_available", false)) and int(after_boundary.get("finalized_day_count", 0)) == 1 and is_equal_approx(float(after_boundary.get("daily_average_arrivals", -1.0)), 1.0), "day rollover finalizes the observed daily-arrival average")
	_manager._visitor_counter = 3
	var saved: Dictionary = _manager.serialize()
	_assert(saved.has("purchase_results") and saved.has("metrics") and saved["metrics"].has("finalized_arrival_total") and not saved.has("proxy_queues") and not saved["visitors"][0].has("position"), "persistence stores committed history and metric provenance, not transient queues or positions")
	var restored := VisitorManager.new()
	restored.deserialize(saved)
	var restored_metrics: Dictionary = restored.get_metrics_snapshot()
	_assert(int(restored_metrics.get("daily_arrivals", -1)) == 0 and int(restored_metrics.get("finalized_arrival_total", -1)) == 1 and restored._purchase_results.has("visitor_2"), "metrics and committed result history restore without replaying transient work")
	restored.all_visitors.clear()
	restored.free()


func _proxy(proxy_id: String, queue_accepting: bool) -> Dictionary:
	return {
		"schema_version": VisitorServiceProxy.SCHEMA_VERSION,
		"parcel_door_proxy_id": proxy_id,
		"tenant_id": "tenant_1",
		"parcel_id": "parcel_1",
		"door_id": "door_1",
		"corridor_anchor_id": "anchor_1",
		"tenant_active": true,
		"public_corridor_reachable": true,
		"proxy_enabled": true,
		"queue_accepting": queue_accepting,
		"proxy_policy_revision": 1,
		"topology_revision": 1,
		"tenant_revision": 1,
	}


func _resolve_proxy_anchor(anchor_id: String) -> Dictionary:
	if anchor_id != "anchor_1":
		return {"valid": false, "diagnostics": [{"code": "CORRIDOR_ANCHOR_UNRESOLVED"}]}
	return {"valid": true, "position": Vector3(2.0, 0.0, 2.0), "path": []}


func _add_visitor(visitor_id: String) -> VisitorData:
	var visitor := VisitorData.new()
	visitor.initialize(visitor_id, "G", Vector3.ZERO)
	visitor.arrival_source_id = "gateway_east"
	_manager.all_visitors.append(visitor)
	return visitor


func _on_purchase_result(result: Dictionary) -> void:
	_events.append(result.duplicate(true))


func _has_code(diagnostics: Array, code: String) -> bool:
	for diagnostic: Variant in diagnostics:
		if diagnostic is Dictionary and String(diagnostic.get("code", "")) == code:
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)
