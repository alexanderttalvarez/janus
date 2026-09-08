# Spatial Evaluation Inputs Handoff Index

This program supplies detached spatial facts and pure policy calculations to tenant evaluation and later consumers. It does not own gameplay state transitions.

**Current revision:** 2026-09-08, delegated documentation pass. H1 remains approved: element 03 owns fixed-point recommendation flooring, element 06 canonical-elevation Location Score, and element 14 same-elevation Manhattan boundary-gap relations. ADR 33/MVP H3 govern coherent capture/restore. No mutable synergy manager or saved derived cache is required.

| Order | Handoff | Status | Scope |
|---:|---|---|---|
| 01 | [Spatial Context and Rent Recommendation](01_spatial_context_and_rent_recommendation.md) | Approved — 2026-09-05 (delegated architecture authority) | Committed topology/relationship snapshots, deterministic accessibility/competition facts, and capped fixed-point rent recommendations. |

## Rules

- H1 requires `district_layout/H3/H5` committed topology, Zone geometry revisions, `prestige/H1`, and frozen `tenant/H2` input types. `tenant/H2` production implementation follows this H1; missing or stale inputs remain unavailable. Type contracts, not running tenant evaluation, break the apparent dependency cycle.
- No legacy navigation fallback or live-visitor data may substitute for committed spatial context.
- Policy is typed immutable Resource content; derived outputs are recomputed, not independently saved.
- Any change to an approved handoff requires architecture review and user approval before implementation.
