# Zone and Parcel Handoff Index

This index is the implementation order and approval record for the zone-and-parcel handoff sequence.

**Current revision:** 2026-09-09 architecture clarification. [Current MVP](../../../game_design/current_mvp.md), ADR 33, and [ADR 35](../../decisions/35_public_band_access_snapshot_and_zone_injection.md) apply. H6 supersedes H1's full resplitting; approved `tenant_interiors/H2` adds staged core/annex feasibility, not live Service cutover. Read the [interior readiness matrix](../tenant_interiors/_index.md) before activating those changes. Manual-door authority is ADRs 30/31, not legacy grid flags. H5 is amended by ADR 35 for transient public-band snapshot injection and exact current-schema door provenance; this clarification is architecture-approved without asserting implementation or migration.

**Current amendment, 2026-09-10:** [ADR 36](../../decisions/36_district_zone_spatial_snapshot_and_zone_mutation.md) amends H1 and H6: production Zone spatial input is the exact injected immutable District snapshot plus the separate ADR 35 snapshot, and paint that changes circulation/manual doors uses the coordinated District/Zone transaction. Architecture approval is binding; implementation, tests, and evidence are not asserted.

## Approved handoffs

| Order | Handoff | Status | Scope |
|---:|---|---|---|
| 01 | [Deterministic Parcel Splitting](01_parcel_splitting.md) | Approved — 2026-08-22 | Valid rectangular, fronted parcel geometry; identity and failure contracts. Amended by Handoff 06 for zone mutation. |
| 02 | [Immediate Debug Business Assignment](02_immediate_debug_business_assignment.md) | Approved — 2026-08-22 | Immediate deterministic parcel subtype assignment; no tenant lifecycle. Amended by Handoff 06 for locked parcels. |
| 03 | [Parcel Number Debug Visualization](03_parcel_number_debug_visualization.md) | Approved — 2026-08-22 | Per-tile parcel numbers and center names for committed parcels. |
| 04 | [Parcel Boundary Walls](04_parcel_boundary_walls.md) | Approved — 2026-08-24 | Thin interior walls between committed parcels, rendered through the global wall visualization modes. |
| 05 | [Automatic Parcel Doors](05_automatic_parcel_doors.md) | Approved — 2026-08-24; amended by ADR 35 — 2026-09-09 | Deterministic physical parcel-door allocation, including injected public-band access, stable provenance, and matching wall gaps. |
| 06 | [Paint-First Zone Mutation and Preservation](06_paint_first_zone_mutation.md) | Approved — 2026-08-26 | Paint-to-create/extend/merge, None removal, and preservation-first parcel transactions. |
| 07 | [Zone Debug Visualization](07_zone_debug_visualization.md) | Approved — 2026-08-27 | Larger debug-only zone-center labels using committed names/types and mathematical centroids. |

## Rules

- Implement only the first approved handoff that has not been completed.
- Handoff 02 may begin only after Handoff 01 is verified complete; Handoff 03 may begin only after both Handoffs 01 and 02 are verified complete.
- Handoff 04 requires committed parcel geometry, not H3 debug labels. H3/H7 are optional read-only tooling and never block gameplay walls/doors; this explicitly supersedes the old label-first gate.
- Handoff 05 may begin only after Handoff 04 is verified complete.
- Handoff 06 may begin only after Handoff 05 is verified complete. It amends the specified mutation rules in Handoffs 01 and 02 without reopening their other approved contracts.
- Handoff 07 may begin only after Handoff 06 is verified complete. It adds a separate read-only debug projection and does not reopen Handoff 03 parcel-label ownership.
- Do not implement tenant lifecycle, door visuals, notification wiring, or save-file integration until their own handoffs are approved.
- Any change to an approved handoff requires an architecture review and user approval before implementation.
