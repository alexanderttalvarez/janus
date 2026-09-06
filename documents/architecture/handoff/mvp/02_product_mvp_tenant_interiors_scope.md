# MVP Handoff 02 — Product MVP Tenant Interiors Scope

**Status:** Approved — 2026-09-06  
**Depends on:** MVP H1 foundation sequence and Tenant Interiors H1–H5

## Purpose

Distinguish the existing proxy-based technical foundation from Janus's Product MVP. The foundation remains a mandatory integration checkpoint, but Product MVP is incomplete until tenant spaces visibly and operationally respond to parcel geometry through the approved Tenant Interiors program.

## Scope distinction

### Technical Foundation MVP — renamed integration gate

The former proxy-only MVP behavior becomes the **Corridor Service Integration Gate**. It proves:

- Tier-1 tenant identity/lifecycle and daily rent;
- visitor arrival, cap, public routing, cancellation, exit, and save cleanup;
- stable parcel-door proxy identity; and
- strict non-economic proxy outcomes.

It is not a player-facing release definition and receives no additional proxy gameplay polish.

### Product MVP

Product MVP additionally requires:

- subtype-specific parcel feasibility and automatic parcel-scale variation;
- core/annex geometry and dedicated Anchor parcels;
- unsuitable-unit feedback;
- visible deterministic procedural interiors;
- fixture-derived capacity and throughput;
- real bounded exterior queues and corridor occupancy;
- wait-tolerance admission at the door;
- abstract service including cohorts, devices, and one-active/one-next scheduled batches;
- deterministic save/load rebuilding with transient in-flight reset; and
- atomic prospective replacement of placeholder proxy service.

Revenue, tenant viability, satisfaction, tenant-derived Prestige, and indoor visitor navigation remain outside Product MVP.

## Revised implementation order

1. Complete and preserve evidence for MVP H1's foundation sequence through the Corridor Service Integration Gate.
2. Implement Tenant Interiors H1 content/planning contracts.
3. Implement H2 parcel integration against the current authority-local schemas.
4. Implement H3 candidate/lifecycle integration.
5. Implement H4 tenant service and visitor behavior.
6. Implement H5 persistence, presentation, and cutover.
7. Run both the original foundation acceptance scenario and H5 Product MVP scenario.
8. Treat only the combined passing evidence as Product MVP completion.

## Cutover rule

After Tenant Interiors H5 current-schema integration/cutover, the stable parcel-door identity remains but placeholder proxy completion is disabled session-wide. An invalid or missing interior/service is unavailable; it never falls back to proxy completion. Historical proxy outcomes already present in a valid current-schema save remain immutable and non-economic; older or schema-absent saves reject before staging and are not transformed.

## Acceptance requirements

- Foundation evidence remains independently reproducible.
- Product MVP cannot pass using proxy-only tenants.
- Interior cutover does not regress arrival/exit/cap/public-route contracts.
- Product MVP introduces no real visitor revenue, viability, satisfaction, or Prestige effects.
- All Tenant Interiors H1–H5 acceptance requirements and deterministic end-to-end evidence pass.
