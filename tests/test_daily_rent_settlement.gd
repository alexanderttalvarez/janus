## Daily rent settlement consumes only validated active-tenant snapshots.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	var economy := EconomyManager.new()
	economy.balance = 0
	var tenant_manager := TenantManager.new()
	economy.initialize(null, tenant_manager)
	var snapshot := {
		"schema_version": 1,
		"simulation_day": 12,
		"tenant_revision": 3,
		"zone_revision": 4,
		"entries": [{"tenant_id": "tenant_1", "parcel_id": "parcel_1", "zone_id": "zone_1", "subtype_id": "retail.fashion", "parcel_tile_count": 6, "daily_rate_centi_kreds": 25, "rent_amount_kreds": 1}],
	}
	tenant_manager.rent_snapshot_published.emit(snapshot)
	var settled := economy.settle_daily_rent(12)
	_assert(bool(settled.get("committed", false)), "validated active rent snapshot settles")
	_assert(economy.balance == 1, "daily settlement credits exact floored Kreds")
	var duplicate := economy.settle_daily_rent(12)
	_assert(bool(duplicate.get("already_settled", false)), "same simulation day is idempotent")
	_assert(economy.balance == 1, "duplicate settlement does not credit twice")
	var missing := economy.settle_daily_rent(13)
	_assert(not bool(missing.get("committed", false)), "missing current-day snapshot does not fabricate rent")
	economy.free()
	tenant_manager.free()
	print("Daily rent settlement tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)
