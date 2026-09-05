# Construction Handoff Index

This index records approved construction architecture handoffs and their implementation gates.

| Order | Handoff | Status | Scope |
| --- | --- | --- | --- |
| 01 | [MVP Circulation, Vertical Links, and Operations Room](01_mvp_circulation_vertical_links_and_operations_room.md) | Approved — 2026-09-05 (delegated architecture authority) | Player construction intents, preview/confirm, authoritative placement, immutable costs, topology publication, persistence, and tests for corridors, stairs, elevators, and Operations Rooms. |

## Program boundary

- District Runtime remains the sole district writer; `ZoneManager` remains the sole zone/parcel writer.
- Economy owns balance and the approved quote/reserve/guaranteed-capture lifecycle. Progression owns eligibility snapshots. Construction policy is immutable content and never a mutable session tuning surface.
- Escalators, plazas/terraces, amenities, removal/cancellation after commit, and refunds require later approved handoffs.
