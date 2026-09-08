# ADR 34: Product MVP Runtime and Cutover

**Status:** Accepted architecture, 2026-09-08, separate follow-on user request: complete everything other than code implementation. This is the approval of corrected H4/H5 documentation, not implementation, Product acceptance, visual approval or any independent release signoff.

## Context and authority

The prior consistency pass deliberately preserved draft `tenant_interiors/H4-H5`. A second architecture review identified FIFO bypass, budget-dependent wait estimates, unsupported cohort timeouts, incomplete historical generation fingerprints and ambiguous restore ordering. Approving the old drafts unchanged would leave conflicting engineering decisions.

[Current MVP](../../game_design/current_mvp.md) remains the scope authority. [H4](../handoff/tenant_interiors/04_tenant_service_and_visitor_interaction.md) and [H5](../handoff/tenant_interiors/05_persistence_presentation_and_cutover.md) now replace their former drafts. This ADR supersedes ADR 33's draft-only readiness restriction, not its single-writer, gate, or no-overengineering principles. H1-H3 remain detached-first dependencies; their live integration occurs through tested H4/H5. No gameplay implementation is claimed.

## Decisions and tradeoffs

| Concern | Selected contract | Rejected alternative / rationale |
|---|---|---|
| Runtime ownership | One injected session Service owner; existing Visitor/Tenant/Zone/Time owners retained | No global Service autoload, per-fixture behavior or generic ECS/FSM framework |
| FIFO admission | Direct entry skips a physical queue slot, not prior claims | Old draft could let newcomers bypass earlier commitments |
| Scheduling | Global phase-first exact transitions, central visitor ticks, finite positive-stage model under 200 active cap | Budget-delayed promotions require whole-building wait simulation and change timing; optimize work rather than gameplay dates |
| Expected wait | Same pure per-service transition rules through exterior admission, frozen committed work, no predicted future arrivals | Separate heuristic and UI estimate can disagree with actual service |
| Cohorts | Immediate partial FIFO groups as element 20 specifies | Minimum-cohort waits/timeouts were draft inventions; not current gameplay |
| Clock | Existing Session H1 elapsed clocks preserve ordinal and sub-tick remainder | Calendar labels/hash phase alone do not prove reload timing; no extra Time origin or new root schema |
| Generation | Complete captured category array + policy/empty marker + separate durable generation fingerprint | Runtime availability fingerprint includes unsaved live revisions; cannot validate historical generation from current services |
| Persistence | Exact V2 registry, three local schemas, detached canonicalization, all-imports-before-runtime-derivation | No Service root, migrations, live cancellation on save or partial candidate publication |
| Route work | One evaluation per visitor per tick, replace only strictly cheaper path on relevant cost-class change | Removes unspecified draft thresholds/budgets; queue congestion changes costs, not topology |
| Performance | Central records, shared snapshots, finite work; optimization chosen against 200-visitor evidence | Mandatory directory coordinator/path-cache framework before measurement is premature |

## Facts, assumptions and open questions

**FACTS:** Element 20 establishes abstract interiors, partial table groups, table reservation before counter service, exterior wait tolerance, one active/one next batch, and transient reset at load. Session H1 already requires simulation/visual elapsed persistence, not just calendar labels. ADR 32 separates district engineering and external release acceptance.

**ASSUMPTIONS made explicit for review:** (A1) expected wait measures exterior-to-abstract admission; later internal waits are not exterior patience. (A2) element 20's common table-cohort rule applies to counter-then-seating too, with shared counter then seated stages. (A3) transient reset permits changed queue order after load while preserving goals/results/cadence. These are interpretations of current design, not new content or mechanics. They must be checked in Design acceptance; engineers must not silently choose alternative semantics.

**OPEN QUESTIONS:** If the designer intends per-person counter throughput rather than the common table-cohort interpretation, or tolerance to include internal device/checkout waits, A1/A2 require clarification and the affected H4 traces must be revised before final Design signoff. This approval does not represent that independent signoff. No additional systems are justified pending that feedback. Target-hardware performance and actual asset fit remain empirical questions requiring implementation/assets, not answers to invent in architecture.

## Explicit amendments

- H1 Visitor provenance shorthand now means H4/H5's captured category array and generation fingerprint, not an unrepeatable live-snapshot hash.
- H2 occupied edits coordinate Service/Visitor only once H4 exists; preserve prior geometry and reject invalid prospective resume rather than fabricate anchors.
- H3 Open-to-Service activation follows H4; no service/visual fault changes Open/rent deadlines.
- Session H1 clock persistence includes sufficient sub-boundary precision; Session H2 validation may derive temporary pure graph/layout values from the complete detached set before imports, while runtime derived reconstruction still follows all imports. Safe capture cannot split a calendar/service phase chain.
- Visitor proxy and old foundation schemas remain a reproducible engineering checkpoint only; H5 selects current capability at bootstrap/load, never hot-switches live tenants.
- Prior dated draft/status statements in ADR 33 and the consistency ledger are history, explicitly superseded for current readiness by this ADR. Historical PASS records are not proof of this revision.

## Approval and evidence boundary

Architecture review is completed in this documentation pass. No code, scene, resource, asset, runtime test or physical performance measurement is delivered by this ADR. The earlier 2026-09-08 authoring session had a disconnected bridge; the later connected [BOUNDED P00 audit](../evidence/product_mvp/implementation_audit.md) on 2026-09-08 inspected nine source bodies and a depth-limited editor tree, identifying save/schema, live-restore, shared-gate and bootstrap gaps. Its preflight returned FAIL at script_check (188 scripts checked, nine low-confidence reload failures without line attribution); Play was not reached. This is partial conformance evidence, not a complete audit, diagnosed syntax errors or runtime acceptance. Complete implementation conformance stays NOT VERIFIED until the [delivery checklist](../handoff/mvp/04_product_delivery_and_acceptance.md) has candidate-bound artifacts. District H4 formal preview acceptance and H10 external Gate R remain pending, and Product acceptance requires real headless and visual results.

## Acceptance obligations

Run FIFO/full-queue traces, all nine typologies, immediate partial cohorts, phase/batch boundary cases, wait/live parity, historical generation validation, fractional-clock round-trips, canonical save/live isolation, candidate-only restore/fault tests, and 200-active performance. Record A1-A3 explicitly in Design review. Non-code preparation cannot manufacture any of those results.
