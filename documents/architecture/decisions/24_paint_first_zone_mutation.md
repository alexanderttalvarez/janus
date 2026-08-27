## Decision 24: Paint-First Zone Mutation with Preservation-First Parcels
**Date:** 2026-08-26
**Status:** Accepted

### Context
The prior edit contract re-split an entire zone after every tile mutation, then spatially matched parcels. That is computationally acceptable, but it changes established parcel geometry, subtype assignments, and doors when players merely add nearby space or merge compatible zones. This conflicts with the intended stable-business experience.

### Decision
- Build Zone is a paint-first mutation tool: zone-type paint creates, extends, or merges same-type zones; None removes committed zone tiles back to explicit built circulation.
- The whole pending paint stroke is planned and committed atomically.
- Same-type merge identity is deterministic: the lowest persistent zone ID survives.
- Existing parcels whose geometry is untouched are locked and preserved. Only newly painted or removal-affected space is eligible for parcel solving.
- None removal rejects if it disconnects a remaining zone; the tool does not auto-split a disconnected remainder into multiple zones.
- The former manual Transit↔Transit boundary door of merging zones is obsolete and removed automatically. Other door preservation rules remain strict.

### Rationale
A localized pure planning pass is slightly more complex than a global re-split but directly protects the player-visible state that matters: established businesses and their access. It remains deterministic, testable, and bounded by the small affected region. This is preferable to a generalized incremental parcel-edit framework, which would be premature and riskier.

### Consequences
- `ZoneManager` must resolve a prospective `ZonePaintIntent` into one mutation plan shared by preview and commit.
- The parcel solver needs an immutable locked-parcel input/boundary model for additive and affected-removal calculations.
- Handoff 02 assignment becomes fixed-constraint assignment for locked neighboring parcels rather than a complete reassignment.
- Handoff 01's full-recalculation policy and this decision's prior full-recalculation choice are superseded only for additive paint, merges, and partial removal under Handoff 06. The original pure splitter remains the baseline for new zones and mutable-space solving.
- Future tenant lifecycle consumes retirement outcomes but is not part of the zone-edit transaction.

### References
- [Handoff 06 — Paint-First Zone Mutation and Preservation](../handoff/06_paint_first_zone_mutation.md)
- [Handoff 01 — Deterministic Parcel Splitting](../handoff/01_parcel_splitting.md)
- [Handoff 02 — Immediate Debug Business Assignment](../handoff/02_immediate_debug_business_assignment.md)
- [Handoff 05 — Automatic Parcel Doors](../handoff/05_automatic_parcel_doors.md)
