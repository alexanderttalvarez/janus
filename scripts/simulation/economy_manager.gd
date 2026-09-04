## EconomyManager — Single financial authority: balance, rent, loans, wages.
## Wired to TimeManager for weekly/monthly processing.
class_name EconomyManager
extends Node


## Emitted when balance changes.
signal balance_changed(new_balance: int, delta: int)


## Starting balance in Kreds.
const STARTING_BALANCE: int = 500_000

## Current money balance.
var balance: int = STARTING_BALANCE

## Monotonic authority revision used by coordinated district transactions.
var authority_revision: int = 0

## Pending balance change held until a district commit reaches its commit point.
var _pending_district_balance_delta: int = 0

## District reservation counter.
var _district_reservation_counter: int = 0
var _reservations: Dictionary = {}
var _policy_snapshot: RefCounted

## Active loans.
var loans: Dictionary = {}  # Dictionary[String, LoanData]

## Loan ID counter.
var _loan_counter: int = 0

## Reference to ZoneManager for rent collection.
var _zone_manager: ZoneManager

## Reference to TenantManager for tenant data.
var _tenant_manager: TenantManager

## Accumulated staff wages (paid monthly).
var _staff_wages: int = 0

## Whether infinite money debug flag is active.
var _infinite_money: bool = false


func _init() -> void:
	_policy_snapshot = load("res://scripts/simulation/economy_policy_snapshot.gd").new()


func initialize(zone_manager: ZoneManager, tenant_manager: TenantManager) -> void:
	_zone_manager = zone_manager
	_tenant_manager = tenant_manager


# ── Balance Operations ─────────────────────────────────────────────────

func add(amount: int, _reason: String = "") -> void:
	if _infinite_money:
		return
	var old: int = balance
	balance += amount
	authority_revision += 1
	balance_changed.emit(balance, balance - old)
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.money_changed.emit(balance, balance - old)


func subtract(amount: int, _reason: String = "") -> bool:
	if _infinite_money:
		return true
	if balance < amount:
		return false
	var old: int = balance
	balance -= amount
	authority_revision += 1
	balance_changed.emit(balance, balance - old)
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.money_changed.emit(balance, balance - old)
	return true


# ── District Transaction Authority ────────────────────────────────────

## Return the monotonic revision observed by District Runtime.
func get_district_revision() -> int:
	return authority_revision


func get_policy_snapshot() -> Dictionary:
	return {} if _policy_snapshot == null else _policy_snapshot.call("duplicate_value")


func set_policy_snapshot(values: Dictionary) -> void:
	if _policy_snapshot == null:
		_policy_snapshot = load("res://scripts/simulation/economy_policy_snapshot.gd").new()
	var next_revision: int = int(values.get("revision", authority_revision + 1))
	_policy_snapshot.call("initialize", next_revision, values)
	authority_revision += 1


func district_quote(transaction: Dictionary) -> Dictionary:
	if _policy_snapshot == null:
		return _diagnostic_result("POLICY_UNAVAILABLE", "Economy policy snapshot is required")
	var intent: Dictionary = transaction.get("intent", {})
	var policy: Dictionary = transaction.get("economy_policy_snapshot", get_policy_snapshot())
	if policy.is_empty():
		return _diagnostic_result("POLICY_UNAVAILABLE", "Economy policy snapshot is required")
	var policy_revision: int = int(policy.get("revision", -1))
	if policy_revision != int(get_policy_snapshot().get("revision", -2)):
		return _diagnostic_result("STALE_QUOTE", "Economy policy revision is stale")
	var category: String = String(intent.get("charge_category", _category_for_intent(intent)))
	var quote_result: Dictionary = _policy_snapshot.call("quote", category, intent)
	if not bool(quote_result.get("accepted", false)):
		return quote_result
	var progression: Dictionary = transaction.get("progression_policy_snapshot", {})
	if progression.is_empty():
		return _diagnostic_result("ELIGIBILITY_REJECTED", "Progression policy snapshot is required")
	var debug_bypass: bool = _debug_cost_bypass_active()
	var value: int = 0 if debug_bypass else int(quote_result.get("value", -1))
	if value < 0:
		return _diagnostic_result("POLICY_UNAVAILABLE", "Economy policy did not provide a valid quote")
	return {
		"accepted": true,
		"value": value,
		"charge_category": category,
		"economy_revision": authority_revision,
		"economy_policy_revision": policy_revision,
		"progression_policy_revision": int(progression.get("revision", -1)),
		"debug_cost_bypass": debug_bypass,
		"intent_reference": intent.get("transaction_id", intent.get("operation", "")),
		"quote_valid": true,
		"diagnostics": [],
	}


## Compatibility wrapper for legacy zero-cost calls; paid H3 calls use district_quote.
func district_reserve(value: int) -> Dictionary:
	if value != 0:
		return _diagnostic_result("POLICY_UNAVAILABLE", "paid district reservations require a policy-bound quote")
	return _reserve_quote({"accepted": true, "value": 0, "charge_category": "NO_CHARGE", "economy_revision": authority_revision, "economy_policy_revision": int(get_policy_snapshot().get("revision", -1)), "progression_policy_revision": 0})


func reserve_quote(quote: Dictionary) -> Dictionary:
	return _reserve_quote(quote)


func _reserve_quote(quote: Dictionary) -> Dictionary:
	if not bool(quote.get("accepted", false)):
		return _diagnostic_result("QUOTE_REQUIRED", "a valid Economy quote is required")
	var value: int = int(quote.get("value", -1))
	if value < 0:
		return _diagnostic_result("ECONOMY_VALUE_INVALID", "quoted value cannot be negative")
	var quote_policy_revision: int = int(quote.get("economy_policy_revision", -1))
	if quote_policy_revision >= 0 and quote_policy_revision != int(get_policy_snapshot().get("revision", -2)):
		return _diagnostic_result("STALE_QUOTE", "quote policy revision is no longer current")
	if not _debug_cost_bypass_active() and balance < value:
		return _diagnostic_result("INSUFFICIENT_FUNDS", "economy balance cannot cover the requested reservation")
	_district_reservation_counter += 1
	var token: Dictionary = {
		"id": _district_reservation_counter,
		"value": value,
		"economy_revision": authority_revision,
		"economy_policy_revision": int(quote.get("economy_policy_revision", -1)),
		"progression_policy_revision": int(quote.get("progression_policy_revision", -1)),
		"charge_category": String(quote.get("charge_category", "")),
		"debug_cost_bypass": bool(quote.get("debug_cost_bypass", _debug_cost_bypass_active())),
		"consumed": false,
		"cancelled": false,
	}
	_reservations[token["id"]] = token
	return {"accepted": true, "reservation_token": token.duplicate(true), "diagnostics": []}


## Convert a reservation into a non-failing capture contract while its revision is held.
func district_guarantee_capture(reservation: Dictionary) -> Dictionary:
	var token: Dictionary = reservation.get("reservation_token", {})
	if not _valid_reservation(token):
		return _diagnostic_result("TRANSACTION_TOKEN_INVALID", "a valid Economy reservation is required")
	if int(token.get("economy_revision", -1)) != authority_revision:
		return _diagnostic_result("STALE_ECONOMY_REVISION", "economy changed after reservation")
	if not _debug_cost_bypass_active() and balance < int(token.get("value", 0)):
		return _diagnostic_result("INSUFFICIENT_FUNDS", "economy balance cannot guarantee capture")
	var guaranteed: Dictionary = token.duplicate(true)
	guaranteed["guaranteed"] = true
	return {"accepted": true, "guaranteed_capture_token": guaranteed, "diagnostics": []}


## Apply a guaranteed capture silently; notifications flush after the commit point.
func district_capture(guaranteed: Dictionary) -> Dictionary:
	var token: Dictionary = guaranteed.get("guaranteed_capture_token", {})
	if not bool(guaranteed.get("accepted", false)) or not bool(token.get("guaranteed", false)) or not _valid_reservation(token):
		return _diagnostic_result("TRANSACTION_TOKEN_INVALID", "a valid guaranteed capture token is required")
	var value: int = int(token.get("value", 0))
	var bypassed: bool = bool(token.get("debug_cost_bypass", false)) or _debug_cost_bypass_active()
	var before: int = balance
	if not bypassed:
		balance -= value
		authority_revision += 1
		_pending_district_balance_delta -= value
	_reservations.erase(int(token.get("id", -1)))
	return {"accepted": true, "financial_result": {"result_type": "DISTRICT_CAPTURE", "charge_category": String(token.get("charge_category", "")), "before_balance": before, "after_balance": balance, "signed_delta": -value, "economy_revision": authority_revision, "economy_policy_revision": int(token.get("economy_policy_revision", -1)), "progression_policy_revision": int(token.get("progression_policy_revision", -1)), "debug_cost_bypass": bypassed}, "diagnostics": []}


## Cancel a reservation without changing the financial authority.
func district_cancel(reservation: Dictionary) -> Dictionary:
	var token: Dictionary = reservation.get("reservation_token", reservation.get("guaranteed_capture_token", {}))
	var reservation_id: int = int(token.get("id", -1))
	if reservation_id < 0 or not _reservations.has(reservation_id):
		return _diagnostic_result("TRANSACTION_TOKEN_INVALID", "Economy reservation token is invalid or already consumed")
	_reservations.erase(reservation_id)
	return {"accepted": true, "diagnostics": []}


func _valid_reservation(token: Dictionary) -> bool:
	var reservation_id: int = int(token.get("id", -1))
	return reservation_id >= 0 and _reservations.has(reservation_id) and not bool(_reservations[reservation_id].get("consumed", false)) and not bool(_reservations[reservation_id].get("cancelled", false))


func _category_for_intent(intent: Dictionary) -> String:
	match String(intent.get("operation", "")):
		"ACQUIRE_SECTION":
			return "PLOT_SECTION"
		"ACQUIRE_SPACE":
			return "VERTICAL_SPACE"
		"CONVERT_STREET":
			return "STREET_CONVERSION"
		"DEMOLISH_FIXED_OCCUPANT":
			return "FIXED_DEMOLITION"
		_:
			return "NO_CHARGE"


func _debug_cost_bypass_active() -> bool:
	if _infinite_money:
		return true
	if OS.has_feature("release"):
		return false
	if not is_inside_tree():
		return false
	var debug_manager: Node = get_tree().root.get_node_or_null("DebugManager")
	return debug_manager != null and (bool(debug_manager.get("god_mode")) or bool(debug_manager.get("infinite_money")))


func _diagnostic_result(code: String, message: String) -> Dictionary:
	return {"accepted": false, "diagnostics": [{"code": code, "message": message}]}


## Publish buffered balance notifications after District Runtime commits.
func flush_district_notifications() -> Array[Dictionary]:
	if _pending_district_balance_delta == 0:
		return []
	var delta: int = _pending_district_balance_delta
	_pending_district_balance_delta = 0
	balance_changed.emit(balance, delta)
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.money_changed.emit(balance, delta)
	return []


# ── Rent Collection (Weekly) ───────────────────────────────────────────

func _on_sim_week_passed(_week: int) -> void:
	_collect_rent()


func _collect_rent() -> void:
	if _tenant_manager == null:
		return
	for tenant: TenantData in _tenant_manager.all_tenants:
		if tenant.is_active and tenant.current_state == TenantData.TenantState.OPERATING:
			var rent := tenant.monthly_rent / 4  # Weekly portion.
			add(rent, "Rent from %s" % tenant.name)
			var event_bus: Node = get_node_or_null("/root/EventBus")
			if event_bus != null:
				event_bus.rent_collected.emit(rent)


# ── Staff Wages (Monthly) ──────────────────────────────────────────────

func _on_sim_month_passed(_month: int) -> void:
	_pay_staff_wages()
	_process_loan_payments()


func _pay_staff_wages() -> void:
	if _staff_wages > 0:
		subtract(_staff_wages, "Staff wages")
	_staff_wages = 0


# ── Loans ──────────────────────────────────────────────────────────────

func take_loan(amount: int, rate: float = 0.05, term: int = 12) -> String:
	var loan := LoanData.new()
	var loan_id := "loan_%d" % _loan_counter
	_loan_counter += 1
	loan.initialize(loan_id, amount, rate, term)
	loans[loan_id] = loan
	add(amount, "Loan taken")
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.loan_taken.emit(loan_id, amount, rate)
	return loan_id


func repay_loan(loan_id: String, amount: int) -> bool:
	if not loans.has(loan_id):
		return false
	if not subtract(amount, "Loan repayment"):
		return false
	var loan: LoanData = loans[loan_id]
	loan.remaining -= amount
	if loan.remaining <= 0:
		loan.remaining = 0
		loan.is_active = false
		var event_bus: Node = get_node_or_null("/root/EventBus")
		if event_bus != null:
			event_bus.loan_repaid.emit(loan_id)
	return true


func _process_loan_payments() -> void:
	var event_bus: Node = get_node_or_null("/root/EventBus")
	for loan_id: String in loans:
		var loan: LoanData = loans[loan_id]
		if not loan.is_active:
			continue
		if subtract(loan.monthly_payment, "Loan payment %s" % loan_id):
			var done: bool = loan.process_payment()
			if done and event_bus != null:
				event_bus.loan_repaid.emit(loan_id)
			if event_bus != null:
				event_bus.loan_payment.emit(loan_id, true)
		else:
			loan.failed_payments += 1
			if event_bus != null:
				event_bus.loan_payment.emit(loan_id, false)
			if loan.failed_payments >= 3 and event_bus != null:
				event_bus.loan_default.emit(loan_id, loan.failed_payments)


# ── Debug ──────────────────────────────────────────────────────────────

func set_infinite_money(enabled: bool) -> void:
	_infinite_money = enabled
	if enabled:
		# Keep the legacy setter as a boundary input; quote/capture still run.
		return


# ── Simulation Hooks ───────────────────────────────────────────────────

## Track days to fire weekly event.
var _days_since_week: int = 0

func on_sim_day_passed(day: int) -> void:
	_days_since_week += 1
	if _days_since_week >= 7:
		_days_since_week = 0
		_on_sim_week_passed(day / 7)


func on_sim_month_passed(month: int) -> void:
	_on_sim_month_passed(month)


# ── Serialization ──────────────────────────────────────────────────────

func serialize() -> Dictionary:
	var loan_data: Dictionary = {}
	for lid: String in loans:
		var l: LoanData = loans[lid]
		loan_data[lid] = {"id": l.id, "principal": l.principal, "remaining": l.remaining,
			"interest_rate": l.interest_rate, "term_months": l.term_months,
			"months_paid": l.months_paid, "failed_payments": l.failed_payments, "is_active": l.is_active}
	return {
		"balance": balance,
		"loans": loan_data,
		"loan_counter": _loan_counter,
		"authority_revision": authority_revision,
		"economy_policy_revision": int(get_policy_snapshot().get("revision", -1)),
	}


func deserialize(data: Dictionary) -> void:
	balance = data.get("balance", STARTING_BALANCE)
	authority_revision += 1
	_loan_counter = data.get("loan_counter", 0)
	loans.clear()
	for lid: String in data.get("loans", {}):
		var ld: Dictionary = data["loans"][lid]
		var l := LoanData.new()
		l.id = ld["id"]; l.principal = ld["principal"]; l.remaining = ld["remaining"]
		l.interest_rate = ld.get("interest_rate", 0.05); l.term_months = ld.get("term_months", 12)
		l.months_paid = ld.get("months_paid", 0); l.failed_payments = ld.get("failed_payments", 0)
		l.is_active = ld.get("is_active", false)
		loans[lid] = l
