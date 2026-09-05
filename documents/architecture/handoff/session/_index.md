# Session Handoff Index

This program defines gameplay-session composition and readiness without changing any domain authority, gameplay value, or presentation design.

| Order | Handoff | Status | Scope / gate |
| ---: | --- | --- | --- |
| 01 | [Bootstrap, Calendar, and Content](01_bootstrap_calendar_and_content.md) | Approved — 2026-09-05 (delegated architecture authority) | Explicit content/layout selection, session composition, Decision 12 calendar delivery, V2 restore ordering, and projection/UI readiness. |
| 02 | [Atomic Session Restore and MVP Acceptance](02_atomic_session_restore_and_mvp_acceptance.md) | Approved — 2026-09-05 (delegated architecture authority) | Full authority registry, detached validate/stage/commit restore, projection barrier, and end-to-end fault-injection gate. |

## Program rules

- Session orchestration creates, wires, stages, and disposes owners; it never becomes a writer for their state.
- Approved domain handoffs remain authoritative for their data, values, transactions, persistence snapshots, and presentation contracts.
- Any change to an approved handoff requires architecture review and user approval before implementation.
