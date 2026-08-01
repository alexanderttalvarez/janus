## LoanData — Represents a single loan taken by the player.
class_name LoanData
extends RefCounted


var id: String = ""
var principal: int = 0
var remaining: int = 0
var interest_rate: float = 0.05
var monthly_payment: int = 0
var term_months: int = 12
var months_paid: int = 0
var failed_payments: int = 0
var is_active: bool = false


func initialize(p_id: String, amount: int, rate: float, term: int) -> void:
	id = p_id
	principal = amount
	remaining = amount
	interest_rate = rate
	term_months = term
	monthly_payment = _calculate_monthly_payment()
	is_active = true


func _calculate_monthly_payment() -> int:
	var monthly_rate := interest_rate / 12.0
	if monthly_rate <= 0:
		return ceili(float(principal) / float(term_months))
	var payment := float(principal) * monthly_rate / (1.0 - pow(1.0 + monthly_rate, -float(term_months)))
	return int(payment)


func process_payment() -> bool:
	if not is_active:
		return false
	remaining -= monthly_payment
	months_paid += 1
	if remaining <= 0:
		remaining = 0
		is_active = false
		return true  # Fully repaid.
	if months_paid >= term_months:
		# Last payment: forgive remainder.
		remaining = 0
		is_active = false
		return true
	return false  # Still paying.
