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
	EventBus.money_changed.emit(balance, balance - old)


func subtract(amount: int, _reason: String = "") -> bool:
	if _infinite_money:
		return true
	if balance < amount:
		return false
	var old: int = balance
	balance -= amount
	authority_revision += 1
	balance_changed.emit(balance, balance - old)
	EventBus.money_changed.emit(balance, balance - old)
	return true


# ── District Transaction Authority ────────────────────────────────────

## Return the monotonic revision observed by District Runtime.
func get_district_revision() -> int:
	return authority_revision


## Reserve an explicit value without mutating the balance.
func district_reserve(value: int) -> Dictionary:
	if value < 0:
		return {"accepted": false, "diagnostics": [{"code": "ECONOMY_VALUE_INVALID", "message": "district transaction value cannot be negative"}]}
	if not _infinite_money and balance < value:
		return {"accepted": false, "diagnostics": [{"code": "INSUFFICIENT_FUNDS", "message": "economy balance cannot cover the requested reservation"}]}
	_district_reservation_counter += 1
	return {"accepted": true, "reservation_token": {"id": _district_reservation_counter, "value": value, "economy_revision": authority_revision}, "diagnostics": []}


## Convert a reservation into a non-failing capture contract while its revision is held.
func district_guarantee_capture(reservation: Dictionary) -> Dictionary:
	var token: Dictionary = reservation.get("reservation_token", {})
	if not bool(reservation.get("accepted", false)) or token.is_empty():
		return {"accepted": false, "diagnostics": [{"code": "RESERVATION_REQUIRED", "message": "a valid economy reservation is required"}]}
	if int(token.get("economy_revision", -1)) != authority_revision:
		return {"accepted": false, "diagnostics": [{"code": "STALE_ECONOMY_REVISION", "message": "economy changed after reservation"}]}
	if not _infinite_money and balance < int(token.get("value", 0)):
		return {"accepted": false, "diagnostics": [{"code": "INSUFFICIENT_FUNDS", "message": "economy balance cannot guarantee capture"}]}
	return {"accepted": true, "guaranteed_capture_token": token.duplicate(true), "diagnostics": []}


## Apply a guaranteed capture silently; notifications flush after the commit point.
func district_capture(guaranteed: Dictionary) -> Dictionary:
	var token: Dictionary = guaranteed.get("guaranteed_capture_token", {})
	if not bool(guaranteed.get("accepted", false)) or token.is_empty():
		return {"accepted": false, "diagnostics": [{"code": "GUARANTEED_CAPTURE_REQUIRED", "message": "a guaranteed capture token is required"}]}
	var value: int = int(token.get("value", 0))
	if not _infinite_money and balance < value:
		return {"accepted": false, "diagnostics": [{"code": "CAPTURE_NOT_GUARANTEED", "message": "economy balance changed before capture"}]}
	if not _infinite_money:
		balance -= value
		authority_revision += 1
		_pending_district_balance_delta -= value
	return {"accepted": true, "diagnostics": []}


## Cancel a reservation without changing the financial authority.
func district_cancel(_reservation: Dictionary) -> Dictionary:
	return {"accepted": true, "diagnostics": []}


## Publish buffered balance notifications after District Runtime commits.
func flush_district_notifications() -> Array[Dictionary]:
	if _pending_district_balance_delta == 0:
		return []
	var delta: int = _pending_district_balance_delta
	_pending_district_balance_delta = 0
	balance_changed.emit(balance, delta)
	EventBus.money_changed.emit(balance, delta)
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
			EventBus.rent_collected.emit(rent)


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
	EventBus.loan_taken.emit(loan_id, amount, rate)
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
		EventBus.loan_repaid.emit(loan_id)
	return true


func _process_loan_payments() -> void:
	for loan_id: String in loans:
		var loan: LoanData = loans[loan_id]
		if not loan.is_active:
			continue
		if subtract(loan.monthly_payment, "Loan payment %s" % loan_id):
			var done := loan.process_payment()
			if done:
				EventBus.loan_repaid.emit(loan_id)
			EventBus.loan_payment.emit(loan_id, true)
		else:
			loan.failed_payments += 1
			EventBus.loan_payment.emit(loan_id, false)
			if loan.failed_payments >= 3:
				EventBus.loan_default.emit(loan_id, loan.failed_payments)


# ── Debug ──────────────────────────────────────────────────────────────

func set_infinite_money(enabled: bool) -> void:
	_infinite_money = enabled


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
	return {"balance": balance, "loans": loan_data, "loan_counter": _loan_counter}


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
