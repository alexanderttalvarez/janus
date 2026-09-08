# Staff Handoff 01: Employment, Coverage and Wages

## Status

Approved 2026-09-05; revised 2026-09-08 under delegated documentation authority, ADR 33 and MVP H3. This explicitly supersedes optional durable-task requirements, per-entry partial payroll and unspecified snapshot failure behavior. It does not claim implementation or release acceptance.

## Purpose

Give the optional physical Operations Room a small, understandable employment/payroll loop without requiring staff agents or cleaning/security simulation.

## In-Scope Behavior

Hire/fire generic Cleaner and Security records in committed Operations Rooms; publish room occupancy and passive floor coverage; supply immutable boundary-employed payroll rosters; settle weekly obligations through Economy; persist employment and unsettled due rosters.

## Out-of-Scope Behavior

Task producers, assignments or durable task queues; garbage/bathrooms; staff Nodes, movement, animation, maintenance, scoring/satisfaction/revenue effects, wage proration and dedicated Staff dashboards. Room construction is already approved by Construction H1; room removal remains unavailable.

## Authorities

[Current MVP](../../../game_design/current_mvp.md), [element 15](../../../game_design/elements/15_staff_system.md) employment/coverage, [element 03](../../../game_design/elements/03_economy.md) wage/failure policy, [ADR 33](../../decisions/33_documentation_consistency_and_minimum_contracts.md), [MVP H3](../mvp/03_foundation_integration_clarifications.md), Construction H1, Economy H1 and Session H2.

## Inputs and Outputs

Inputs: immutable committed room ID/building/floor/revision/validity facts; hire intent with room ID/type/expected revisions; fire intent with staff ID/revision; Time week identity; immutable wage policy; Economy settlement acknowledgement.

Outputs: canonical Staff records and per-room type counts; derived coverage; stable rejected-intent diagnostics; detached due-week payroll with one entry per boundary-employed employee; post-commit employment/read snapshots. No Staff output directly changes balance or gameplay scores.

## State Ownership

Staff alone owns unique staff IDs, employment, revision and retained pending payroll inputs. Construction alone owns room facts. Economy alone owns balances and consumed-week markers. Session coordinates atomic capture and settlement; Presentation submits intents and reads results.

Each staff record contains stable staff ID, Cleaner/Security type, employing room ID and captured building/floor identity. The versioned Staff save contains canonical live records, next staff-ID allocation ordinal, owner revision, and canonical `pending_payroll` entries (empty when settled). Each pending entry contains week identity, captured employment revision, wage-policy identity/revision and entries sorted by staff ID, each with type, room ID and fixed integer wage. These historical due entries need not name a currently employed person after later firing. They must name valid rooms and remain immutable; they are not recalculated from current employment on retry/load. No task or coverage-cache field is current durable state. A schema revision explicitly includes this due-input extension; older payloads missing it reject, never silently default.

## Invariants

- Each room permits at most two Cleaners **and independently** two Security, never a shared four-person pool. No unsupported global staff cap.
- Coverage is the room floor and at most one existing floor above/below within the same building, derived from canonical signed elevations. No cross-building coverage.
- Hire/fire has no price, refund or proration. Stable IDs never derive from Node names or display labels.
- At each weekly boundary, freeze all boundary-employed staff into one valid roster under the session gate. An empty roster is valid and consumes that week at zero cost.
- Economy settles the whole roster once at the element-03 wage, even if balance becomes negative. Within one coordinated commit, Economy publishes the total debit/consumed marker and Staff clears the due entry. No employee-by-employee partial result is observable.
- Failed settlement retains the original due roster; later hire/fire does not rewrite it. Due weeks settle in ascending order. Staff never marks money paid independently.

## Failure and Edge Cases

Unknown type, missing/invalid room, stale revision, full type capacity or unknown staff ID rejects without changing employment/counts. A third Cleaner fails even if Security slots are empty; a Security hire can still succeed. Do not infer room validity from its visual Node.

Missing/invalid due roster or pre-commit failure settles nothing; retain the original week for retry and expose a diagnostic. A retained roster validates its historical capture, not equality with today's Staff revision; later hire/fire cannot make an owed wage stale. If the boundary roster cannot be captured, pause calendar progression and block hire/fire **and save** until capture succeeds; do not infer employment from a later week. Money shortage does not fail payroll. Failed save/load preserves the prior slot/session; restore validates room/count/policy/provenance and cross-checks pending weeks against Economy markers, then resumes unconsumed obligations without replaying employment events. Duplicate/already-consumed pending weeks reject rather than double-debit.

## Dependencies

Construction H1 committed room port; Time/Session H1 identities and gate; Economy H1 exact-once settlement; Session H2 detached restore; Presentation H1/MVP H3 minimal action surfaces. No simulation/task/visitor/interior source is required.

## Ordered Implementation Outcomes

1. Validate room facts and canonical employment/coverage records.
2. Commit revision-safe hire/fire intents and read results.
3. Capture durable due-week rosters and integrate coordinated whole-week Economy settlement.
4. Validate/export/restore employment and pending obligations atomically.
5. Expose minimal source-backed hire/fire controls and payroll diagnostics, without building a new dashboard.

## Acceptance Criteria

- Two hires of each type succeed independently; the third of either rejects with no mutation. Invalid/stale room and fire intents preserve state.
- Room/G/upper/underground boundary cases publish only same-building existing coverage floors.
- Zero staff settles zero; four boundary-employed staff cost 2,000 Kreds; 100 balance becomes -1,900. A later discretionary purchase still rejects insufficient funds.
- Fault before payroll commit charges nobody; retry charges the original roster once even after firing. A complete commit clears that due entry and records the consumed week atomically.
- Save/load preserves a failed-settlement roster and cannot duplicate or reorder weeks; corrupt references, policy, capacity or cross-owner markers reject the whole load.
- No task fact, agent, route, satisfaction, Prestige or revenue system is needed to satisfy this contract.
