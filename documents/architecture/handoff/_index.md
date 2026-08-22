# Architecture Handoff Index

This index is the implementation order and approval record for architecture handoffs.

## Approved handoffs

| Order | Handoff | Status | Scope |
|---:|---|---|---|
| 01 | [Deterministic Parcel Splitting](01_parcel_splitting.md) | Approved — 2026-08-22 | Valid rectangular, fronted parcel geometry; identity and failure contracts. |
| 02 | [Immediate Debug Business Assignment](02_immediate_debug_business_assignment.md) | Approved — 2026-08-22 | Immediate deterministic parcel subtype assignment; no tenant lifecycle. |
| 03 | [Parcel Number Debug Visualization](03_parcel_number_debug_visualization.md) | Approved — 2026-08-22 | Per-tile parcel numbers, center names, and transient rejected-zone feedback. |

## Rules

- Implement only the first approved handoff that has not been completed.
- Handoff 02 may begin only after Handoff 01 is verified complete; Handoff 03 may begin only after both Handoffs 01 and 02 are verified complete.
- Do not implement tenant lifecycle, door visuals, notification wiring, or save-file integration until their own handoffs are approved.
- Any change to an approved handoff requires an architecture review and user approval before implementation.
