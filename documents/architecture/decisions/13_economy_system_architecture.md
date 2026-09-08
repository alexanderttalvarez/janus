## Decision 13: Economy System Architecture
**Date:** 2026-07-28
**Status:** Accepted; amended 2026-09-03

**Current applicability:** [ADR 33](33_documentation_consistency_and_minimum_contracts.md) and [MVP H3](../handoff/mvp/03_foundation_integration_clarifications.md), 2026-09-08, clarify the shared session gate, whole-week mandatory payroll, and source-owned balance conditions. Loans remain deferred by current scope.

### Context
The economy drives tension between creative ambition and financial reality. It handles money balance, approved charges, rent collection, loans, and expenses. We needed to decide on money ownership, transaction scheduling, loan management, and the transaction boundary required by district acquisition.

### Decision
- **EconomyManager owns the committed money balance** (single financial authority).
- **Recurring transactions are driven only by TimeManager calendar signals.** Consumers do not define their own raw time constants.
- **Rent is credited daily** on `sim_day_passed`, using each active tenant's player-set daily rate. A simulation day is 24 real seconds at 1× speed.
- **Staff wages are charged weekly** on `sim_week_passed`.
- **Loans are charged monthly** on `sim_month_passed` and are managed as `LoanData` objects within EconomyManager.
- **Recurring maintenance cost is post-MVP.** No maintenance charge, repair charge, or maintenance staff is implemented in MVP.
- **EconomyManager is not an autoload** — it is a child of `main_game.tscn` and exists only for an active gameplay session.
- **The Economy transaction port is quote → reserve → guaranteed capture → cancel.** Economy retains balance ownership; other authorities never debit it directly.
- **Reservations are ephemeral and non-persistent.** They are valid only for the guarded transaction that created them, create no committed balance event, and must be cancelled on every pre-commit failure.
- **Prices and eligibility remain external policy inputs.** Economy consumes immutable economy-policy and progression-policy snapshots; it does not invent district-expansion prices, progression gates, refunds, or demolition policy.
- **An active debug cost bypass makes all player-paid economy actions free.** A bypassed quote is zero and capture does not alter balance. This applies at the quote/capture boundary, not as scattered caller-side exceptions.

### EconomyManager Structure
```text
EconomyManager (Node, child of main_game.tscn)
├── balance: int = 500_000
├── loans: Dictionary[String, LoanData]
├── ephemeral reservations
├── quote(policy_snapshot, purchase_intent) → quote or diagnostic
├── reserve(quote, revision) → reservation token or diagnostic
├── guarantee_capture(reservation) → capture token or diagnostic
├── capture(capture_token) → committed financial result
├── cancel(reservation_or_capture_token)
├── add(amount, reason)
├── subtract(amount, reason) → bool
├── take_loan(amount, term) → String
├── repay_loan(loan_id)
├── _on_sim_day_passed(day)
│   └── _collect_daily_rent()
├── _on_sim_week_passed(week)
│   └── _accrue_staff_wages(week)
├── _on_sim_month_passed(month)
│   └── _process_loan_payments()
└── Signals:
    └── balance_changed(new_balance, delta)
```

### LoanData Structure
```text
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

### District Transaction Flow
```text
District Runtime prepares detached candidates and policy snapshots
    → Economy quotes the approved cost
    → Economy reserves the quote under the cross-authority transaction gate
    → Zone/District validation and revision revalidation
    → Economy upgrades the reservation to guaranteed capture
    → authority state swaps + non-failing capture
    → one committed envelope publishes results
```

A stale, insufficient, expired, or cancelled reservation cannot capture. The final capture is contractually non-failing while its valid token and the transaction gate remain held; otherwise the coordinated transaction must reject before any authority swap.

### Financial Feedback
- A rejected insufficient-funds request returns a structured, transient financial diagnostic suitable for immediate UI feedback.
- A committed balance below zero raises a high-priority financial condition for the notification system.
- The exact threshold and resolution policy beyond negative balance remain future design work.

### Rationale
- Single balance ownership prevents inconsistent or double charges.
- Daily rent matches the designed daily player feedback cadence: one simulation day is 24 seconds at 1× speed.
- Weekly wages and monthly loans preserve their intended slower financial rhythm.
- Reservation-to-guaranteed-capture permits District Runtime and ZoneManager to coordinate atomic transactions without moving balance authority.
- Policy snapshots prevent Economy from owning district geometry, progression eligibility, or unapproved pricing design.
- One explicit debug bypass prevents partial test-only charging behavior.

### Consequences
- EconomyManager depends on TimeManager calendar signals and read-only tenant/staff data.
- District Runtime depends on the transaction port but cannot mutate EconomyManager state except through it.
- Balance changes emit signals for HUD updates only after committed adds, debits, or captures.
- Save data includes committed balance and loans only; reservations and capture tokens are excluded.
- Later handoffs must separately approve tenant lifecycle/rent calculation inputs, expansion prices, refunds, maintenance, transport operations, and financial-report UI.
