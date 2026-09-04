# Economy Handoff 01 — Transaction Authority and Policy Boundary

**Status:** Approved — 2026-09-03
**Prepared:** 2026-09-03
**Implementation order:** 1 of 1

## Purpose

Establish Economy as the sole authority for committed player funds and provide the atomic transaction port required by District Runtime and later paid gameplay systems.

This handoff makes approved charges safely quoteable, reservable, cancellable, and capturable without allowing District Runtime, ZoneManager, UI, or any other consumer to write the balance directly. It reconciles the approved daily rent, weekly wage, monthly loan, debug-free-cost, persistence, and financial-feedback boundaries.

## Authoritative sources

- [Decision 12 — Time System Architecture](../../decisions/12_time_system_architecture.md)
- [Decision 13 — Economy System Architecture](../../decisions/13_economy_system_architecture.md)
- [Decision 20 — Debug Mode Architecture](../../decisions/20_debug_mode_architecture.md)
- [District Handoff 03 — Variable Floor Grid Migration](../district_layout/03_variable_floor_grid_migration.md)
- [Economy design](../../../game_design/elements/03_economy.md)
- [District Layout & Land Expansion design](../../../game_design/elements/19_district_layout_land_expansion.md)

## Scope

- Session-scoped Economy authority for committed balance, loans, and ephemeral transaction reservations.
- Immutable economy-policy snapshot boundary and immutable progression-policy snapshot consumption.
- Quote → reserve → guaranteed-capture → cancel lifecycle for a paid intent.
- Direct economy mutations for approved income, loan, and recurring charge sources, with one committed financial result per mutation.
- Calendar integration: daily rent settlement contract, weekly staff-wage contract, and monthly loan-payment contract.
- Debug cost-bypass behavior at the Economy boundary.
- Save/load ownership for committed balance and loans, explicitly excluding transient reservations/tokens.
- Financial diagnostics and notification-facing condition contract.
- Deterministic tests for transaction safety, policy isolation, debug bypass, recurrence boundaries, and persistence exclusion.

## Explicit non-goals

- Tenant applications, tenant identity/lifecycle, tenant revenue calculation, tenant viability, or rent-setting UI.
- Implementing rent collection before a later tenant-lifecycle handoff supplies authoritative active-tenant/rent inputs.
- New prices or formulas for Plot Sections, Street Segments, demolition, U4/U5 floor space, transport, construction catalogs, refunds, or progression gates.
- Construction cancellation or post-commit refund policy.
- Recurring maintenance, repairs, repair costs, or maintenance staff; all are post-MVP.
- Financial-report UI, loan UI, notification presentation, localization copy, or player-facing settings.
- District, zone, grid, progression, or save orchestration ownership.

## FACTS

- EconomyManager owns committed balance and loans for one gameplay session.
- One simulation day is 24 real seconds at 1×. TimeManager emits authoritative day, week, and month boundaries.
- Rent is a player-set daily zone rate and is credited daily once tenant lifecycle provides active tenant data.
- Staff wages are 500 Kreds per employee per week in MVP.
- The MVP plot is initially owned. District expansion prices and gates remain unapproved.
- District Handoff 03 requires Economy reservation, guaranteed capture, cancellation, revision safety, and no partial cross-authority commit.
- Debug cost bypass makes every player-paid action free while normal gameplay validation and successful state changes continue.
- Committed balance below zero creates a high-priority financial condition. Insufficient funds is an immediate rejected-action diagnostic.

## ASSUMPTIONS

- A session can provide an immutable economy-policy snapshot and revision even before every price family has approved content.
- A valid guaranteed-capture token can be made non-failing while the shared cross-authority transaction gate is held.
- The current SaveManager V2 orchestration can stage Economy's committed snapshot along with other authority snapshots; Economy does not own the outer save envelope.

## OPEN QUESTIONS

These are deliberately not resolved by H1:

- Plot Section, Street Segment, demolition, U4/U5, transport, and construction prices/scaling.
- Progression gates for expansion, elevated floors, street conversion, and transport.
- Post-commit refunds, cancellation costs, demolition consequences, and reversal rules.
- Rent input details after tenant lifecycle exists, including rounding, empty-zone behavior, and the exact active-tenant read snapshot.
- Negative-balance thresholds/resolution beyond the approved below-zero condition.
- Loan term selection, default presentation, and financial-report UI.

## System boundaries and ownership

| Owner | Owns | Must not own |
|---|---|---|
| `EconomyManager` | Committed balance, loans, reservation/token lifecycle, financial mutation results, economy-policy snapshot revision. | District/zone state, progression eligibility, tenant lifecycle, UI, save-file envelope. |
| Economy policy content | Approved cost tables/formulas and charge-category definitions. | Balance, reservations, eligibility, runtime transaction coordination. |
| Progression authority | Immutable eligibility/cap snapshots and revision. | Prices, balance, Economy reservations. |
| District Runtime | District intent/candidate preparation and cross-authority transaction gate. | Direct balance writes, Economy policy mutation. |
| `ZoneManager` | Zone/parcel candidate preparation and sole zone writes. | Direct balance writes, Economy policy mutation. |
| `TimeManager` | Day/week/month boundary signals. | Financial calculations or balance mutation. |
| `DebugManager` | Debug cost-bypass state. | Altering balance, quote values outside the Economy boundary, bypassing spatial validity. |
| `SaveManager` | Atomic save/load orchestration. | Reconstructing or persisting reservations/tokens. |
| Notification/UI systems | Presentation of committed results and diagnostics. | Mutating financial authority. |

Dependency direction:

```text
Economy policy + progression policy + Debug state
    -> EconomyManager quote/result
    -> District/Zone/other consumer transaction coordination
    -> committed financial result
    -> UI / notifications / save orchestration
```

Consumers may submit intents and read results. They never mutate `balance`, loans, reservations, or policy snapshots.

## Data contracts

### Economy read snapshot

Economy exposes an immutable, revisioned session snapshot containing only committed financial facts:

- committed balance;
- committed loan records;
- economy revision;
- economy-policy revision/reference used for quote validation.

The snapshot excludes reservations, capture tokens, pending UI state, derived reports, and Node references.

### Policy snapshots

A quote receives immutable economy and progression policy snapshots captured by the initiating transaction. Economy evaluates only approved values exposed by those snapshots. Missing policy is a rejection; Economy must never substitute a fallback price, default eligibility, or formula.

### Quote

A successful quote contains:

- stable charge category and initiating intent reference;
- quoted amount in integer Kreds;
- captured economy, economy-policy, and progression-policy revisions;
- debug-cost-bypass flag where applicable;
- deterministic expiry/validity context;
- structured diagnostics suitable for presentation.

A debug-bypassed quote has amount `0`. It remains a normal quote with normal validation context; it is not a caller-side omission of the Economy transaction.

### Reservation and guaranteed capture

A reservation is a single-use ephemeral claim over a valid quote. It is not a committed debit, is never saved, and does not emit a committed balance event. Economy internally prevents the same funds from being reserved twice. HUD balance continues to show committed balance until capture.

A reservation may become a guaranteed-capture token only after the coordinator holds its cross-authority transaction gate and revalidates all captured revisions. A valid capture token is non-failing until consumed or invalidated by gate release. Cancellation invalidates the token and releases its claim without a debit.

### Committed financial result

Each committed add, debit, loan mutation, recurring settlement, or capture produces one immutable result containing:

- result type and stable charge/income category;
- before/after balance and signed delta;
- originating intent/reference when applicable;
- economy revision after commit;
- applicable policy revisions;
- debug-bypass indicator;
- structured diagnostic data when no commit occurred.

## Transaction rules

### Common invariants

- Economy is the only balance writer.
- A paid intent never changes balance before capture.
- A reservation or capture token is valid for one transaction only and cannot be replayed.
- A failed, stale, expired, or cancelled transaction produces no committed Economy mutation.
- A consumer cannot capture a different amount, category, or policy revision than its reserved quote.
- Capture cannot fail after the coordinator has reached its pre-append commit point; implementations unable to provide this guarantee must reject before any cross-authority swap.
- No transaction result exposes partially updated Economy, District, or Zone state.

### Standard paid transaction

```text
consumer intent
  -> capture immutable policy snapshots
  -> Economy quote
  -> Economy reserve
  -> consumer-specific validation
  -> Economy guaranteed capture
  -> consumer commit + Economy capture
  -> one committed result/event envelope
```

For a local Economy-only action, Economy owns the entire sequence. For a coordinated transaction, the consumer uses the relevant transaction coordinator.

### District Runtime coordinated transaction

District Handoff 03 remains authoritative for the global order. Economy's required behavior is:

```text
District Runtime holds the shared transaction gate and barriers
  -> Economy reserves the captured quote
  -> Zone/District detached candidates prepare and revisions revalidate
  -> Economy upgrades reservation to guaranteed capture
  -> District/Zone state references swap
  -> Economy captures non-failingly
  -> coordinator appends one complete commit envelope
  -> barrier release flushes ordered observers
```

Any failure before the envelope append cancels Economy's token and preserves the prior committed balance. No post-append compensating debit, refund, or rollback is permitted.

### Diagnostics

H1 requires stable structured rejection categories at least for:

| Condition | Required result |
|---|---|
| Policy unavailable or unapproved cost | `POLICY_UNAVAILABLE` |
| Progression/eligibility snapshot rejects | `ELIGIBILITY_REJECTED` |
| Quote or policy revision changed | `STALE_QUOTE` |
| Committed funds cannot cover the reservation | `INSUFFICIENT_FUNDS` |
| Reservation/capture token invalid, expired, replayed, or gate-invalid | `TRANSACTION_TOKEN_INVALID` |
| Non-guaranteed capture implementation | `CAPTURE_GUARANTEE_UNAVAILABLE` |

`INSUFFICIENT_FUNDS` is an immediate, presentation-owned diagnostic. It does not create a persistent notification-log entry. A committed balance below zero creates the separate high-priority financial condition.

## Recurring financial flow

```text
TimeManager.sim_day_passed
  -> future tenant lifecycle supplies immutable active-tenant rent snapshot
  -> Economy credits daily rent once per zone/tenant contract

TimeManager.sim_week_passed
  -> future staff authority supplies immutable paid-staff snapshot
  -> Economy debits 500 Kreds per eligible MVP employee

TimeManager.sim_month_passed
  -> Economy processes committed loan schedule
```

H1 defines the calendar subscription and read-snapshot boundaries. It does not implement missing tenant or staff lifecycle systems. Every recurring source must be idempotent per authoritative calendar period and must record the consumed period in committed Economy state or another approved persistent authority so save/load cannot duplicate a settlement.

## Debug cost-bypass rules

- Cost bypass is active only when the approved DebugManager state says `god_mode` or `infinite_money` is active in a non-release build.
- A bypassed quote has zero cost; reserve/capture still execute so the normal transaction topology, validation, events, and state changes are testable.
- Debug bypass does not bypass policy existence, geometry, ownership, buildability, progression rules unless their own approved debug rule separately bypasses them, zone validation, revision checks, or atomicity.
- No free-cost decision is distributed into District Runtime, ZoneManager, tools, or UI.

## Persistence and load

| Persist | Exclude |
|---|---|
| Committed balance, committed loan data, required recurring-settlement markers, and Economy revision/schema data. | Quotes, reservations, capture tokens, available-funds overlays, pending UI, diagnostics, transaction gates, and Node references. |

On load, Economy validates and stages only its committed snapshot. It must not recreate a reservation or infer an in-flight payment. Save/load orchestration and whole-session atomicity remain SaveManager/H9 concerns.

## Events and presentation

- Economy publishes committed financial results only after the authoritative commit point.
- HUD reads committed balance/results and must not treat a reservation as a balance mutation.
- NotificationManager owns presentation and resolution of the below-zero financial condition.
- Callers own player-facing copy for rejected quotes; Economy returns stable categories and context, not localized text.
- No direct EventBus emission is required by H1 unless the existing event architecture needs the post-commit result projection. The transaction coordinator remains responsible for coordinated envelope ordering.

## Acceptance requirements

- Only Economy can change the committed balance or loan state.
- The same policy snapshots and intent produce the same quote amount and diagnostics.
- Missing/unapproved policy rejects rather than using a fallback amount.
- Insufficient funds produces `INSUFFICIENT_FUNDS` with no balance, reservation, or consumer-state mutation.
- A reservation cannot be reused, captured after cancellation, or captured after its captured revision/gate becomes invalid.
- A valid guaranteed-capture token completes with exactly one debit, even within a coordinated District transaction.
- Every failure injected before the coordinator's envelope append leaves Economy, District, and Zone committed state unchanged and releases reservation claims.
- A committed transaction emits exactly one complete result/envelope; no observer sees an intermediate balance.
- Debug cost bypass produces a zero-cost successful transaction without bypassing non-economic validity or atomicity.
- Daily rent, weekly wages, and monthly loans consume only TimeManager boundaries and never independently count raw elapsed time.
- Replayed calendar boundaries or load restoration cannot double-settle a recurring charge/income period.
- Saves contain committed Economy state only and cannot restore a reservation, capture token, or in-flight charge.
- Negative committed balance exposes a high-priority financial condition; insufficient funds remains transient.

## Required tests

- Quote determinism, missing policy, stale policy/revision, integer-money boundaries, and diagnostic stability.
- Reservation lifecycle: success, cancellation, expiry, replay rejection, insufficient funds, and no double reservation.
- Guaranteed-capture safety under every pre-append District H3 failure boundary.
- Exact once-only capture and result emission for local and coordinated transactions.
- Debug free-cost quote/reserve/capture behavior with normal validity failures still enforced.
- Calendar settlement ordering, idempotency, speed changes, pause, multi-boundary frames, and load restoration.
- Save round trip for committed balance/loans/settlement markers and proof that transient tokens are absent.
- Negative-balance condition and insufficient-funds diagnostic routing without UI ownership leaking into Economy.

## Technical risks

| Risk | Mitigation |
|---|---|
| Economy is treated as a generic service locator and accumulates policy ownership. | Policy snapshots are immutable inputs; unapproved values reject. |
| Direct `subtract()` calls bypass coordinated transaction safety. | All paid cross-authority actions use the reservation port; direct mutations are limited to Economy-owned recurring/loan/income sources. |
| Save/load duplicates rent, wages, or loan payments. | Persist/revalidate authoritative consumed-period markers; do not persist in-flight work. |
| Debug mode produces paths unlike production. | Run the same quote/reserve/capture topology at zero cost. |
| Pending refunds or demolition requirements pressure H1 to invent policy. | Reject/leave unsupported until a dedicated pricing and refund handoff is approved. |
| Future tenant lifecycle changes rent inputs. | H1 consumes a read-only tenant snapshot rather than tenant Nodes or mutable Zone data. |

## Dependencies and follow-up handoffs

- **Predecessor:** none; this is the first Economy handoff.
- **Direct consumer:** District Layout H3 requires this handoff's reservation-to-guaranteed-capture contract before production transaction implementation.
- **Future Economy H2:** expansion pricing, refund/demolition policy, and approved charge catalogs.
- **Future tenant lifecycle handoff:** active-tenant/rent snapshot, daily rent settlement inputs, revenue and viability.
- **Future staff handoff:** paid-staff snapshot and weekly wage inputs.
- **Future maintenance/transport handoffs:** approved recurring and one-time charges.
