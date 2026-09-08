# Session Handoff Index

This program defines gameplay-session composition and readiness without changing any domain authority, gameplay value, or presentation design.

**Current revision:** 2026-09-08, delegated documentation pass. H1/H2 remain approved with element-01 clock units and ADR 33/[MVP H3](../mvp/03_foundation_integration_clarifications.md) coherent capture, all-imports-before-derived-rebuild, reserved `synergy` value and due-payroll persistence. Their gate is foundation acceptance, not Product completion. `tenant_interiors/H4-H5` live runtime/schema/cutover remains draft and unavailable.

**Follow-on review, 2026-09-08:** The preceding revision records the earlier consistency pass. [ADR 34](../../decisions/34_product_mvp_runtime_and_cutover.md) separately architecture-approves interior H4/H5. Foundation -> detached interior H1-H3 -> H4 implementation passes -> H5 candidate cutover passes -> [Product acceptance](../mvp/04_product_delivery_and_acceptance.md); external Gate R is separate. Live Session capability/schema integration requires those implementation/cutover passes, not approval alone. Implementation/cutover remain NOT VERIFIED; Product acceptance/Gate R remain PENDING.

| Order | Handoff | Status | Scope / gate |
| ---: | --- | --- | --- |
| 01 | [Bootstrap, Calendar, and Content](01_bootstrap_calendar_and_content.md) | Approved — 2026-09-05 (delegated architecture authority) | Explicit content/layout selection, session composition, Decision 12 calendar delivery, V2 restore ordering, and projection/UI readiness. |
| 02 | [Atomic Session Restore and MVP Acceptance](02_atomic_session_restore_and_mvp_acceptance.md) | Approved — 2026-09-05 (delegated architecture authority) | Full authority registry, detached validate/stage/commit restore, projection barrier, and end-to-end fault-injection gate. |

## Program rules

- Session orchestration creates, wires, stages, and disposes owners; it never becomes a writer for their state.
- Approved domain handoffs remain authoritative for their data, values, transactions, persistence snapshots, and presentation contracts.
- Any change to an approved handoff requires architecture review and user approval before implementation.
