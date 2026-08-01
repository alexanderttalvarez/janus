## Decision 13: Economy System Architecture
**Date:** 2026-07-28
**Status:** Accepted

### Context
The economy drives tension between creative ambition and financial reality. It handles money balance, rent collection, loans, and expenses. We needed to decide on money ownership, transaction scheduling, and loan management.

### Decision
- **EconomyManager owns the money balance** (single financial authority)
- **Recurring transactions driven by TimeManager events** (`sim_day_passed`, `sim_month_passed`)
- **Rent collected weekly** (not daily)
- **Loans managed as `LoanData` objects** within EconomyManager
- **Maintenance cost is post-MVP** — no recurring maintenance expense in MVP
- **EconomyManager is NOT an autoload** — child of `main_game.tscn`

### EconomyManager Structure
```
EconomyManager (Node, child of main_game.tscn)
├── balance: int = 500_000
├── loans: Dictionary[String, LoanData]
├── add(amount, reason)
├── subtract(amount, reason) → bool
├── take_loan(amount, term) → String
├── repay_loan(loan_id)
├── _on_sim_day_passed(day)
│   └── _accrue_staff_wages(day)
├── _on_sim_week_passed(week)
│   └── _collect_rent()
├── _on_sim_month_passed(month)
│   └── _process_loan_payments()
└── Signals:
    └── balance_changed(new_balance, delta)
```

### LoanData Structure
```
class LoanData:
    id: String
    principal: int
    remaining: int
    interest_rate: float
    monthly_payment: int
    term_months: int
    months_paid: int
    failed_payments: int
    is_active: bool
    calculate_monthly_payment() → int
    process_payment() → bool
```

### Rent Collection Flow
```
_on_sim_week_passed(week):
    for zone in ZoneManager.zones:
        if zone.has_active_tenants():
            rent = zone.calculate_weekly_rent()
            EconomyManager.add(rent, "Rent from " + zone.name)
```

### Rationale
- Single financial authority prevents balance inconsistencies
- Time-driven transactions are predictable and easy to debug
- Weekly rent matches the design doc's pacing (daily was too frequent)
- Loan objects have clear lifecycle and are easy to serialize
- Not an autoload because economy only exists during gameplay

### Consequences
- EconomyManager depends on TimeManager signals and ZoneManager data
- Balance changes emit signals for HUD updates
- Negative balance triggers high-priority notification
- Post-MVP: maintenance costs, transportation fees, event income added to monthly processing
