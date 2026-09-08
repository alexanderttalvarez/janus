# Tenant Interiors Handoff 02 — Parcel Formation Integration

**Status:** Approved — 2026-09-06  
**Implementation order:** 2 of 5

**Revision:** 2026-09-08 delegated consistency pass. [Current MVP](../../../game_design/current_mvp.md), element 20 and ADR 33 apply. The [readiness matrix](_index.md) authorizes detached prospective geometry/transaction proofs only before runtime H4/H5 approval. Service/Visitor swaps below are later integration obligations, not current live dependencies. Search-indeterminate content cannot cause absorption, decoration or an Unsuitable verdict; preserve the parcel and return an inconclusive diagnostic. Retained parcel doors remain protected; explicit authorized retirement removes that parcel's automatic doors atomically, never an unrelated manual door.

## Purpose

**Follow-on review, 2026-09-08:** The revision above records the earlier consistency pass. [ADR 34](../../decisions/34_product_mvp_runtime_and_cutover.md) separately architecture-approves H4/H5. H2 remains a detached stage after foundation and H1; live occupied edits and Service/Visitor swaps require H4 implementation passes and H5 candidate cutover passes, then [Product acceptance](../mvp/04_product_delivery_and_acceptance.md). Documentation approval activates nothing. Implementation/cutover remain NOT VERIFIED; Product acceptance and separate external Gate R remain PENDING.

Amend Zone planning for scale-diverse core-plus-annex parcels, deterministic queue envelopes, dedicated Anchors, preservation-safe mutations, and unsuitable units. ZoneManager remains sole parcel/wall/door writer.

## Supersession

This supersedes Zone H1 only where it requires fully rectangular parcels, generic zone minimum/target count, universal residual Decoration, and no profile capability. Pure planning, canonical identity, frontage, preview parity, atomicity, stable IDs, and H6 preservation remain.

## Parcel geometry

A parcel owns stable plot/floor/zone/parcel identity, canonical connected holed-free tiles, one axis-aligned formation core, annex=set difference, area, physical frontage/doors, committed exclusive queue-envelope IDs/provenance, occupancy binding, geometry revision. Core proves at least one feasible profile but reserves none.

## Prospective planning pipeline

Session injects H1 capability and QueueGeometryPolicy snapshots; Zone never calls TenantManager.

1. Use plan-local parcel keys and prospective legal frontage.
2. Run approved Zone H5 door selection prospectively, including preservation rules.
3. Build detached prospective PedestrianGraphSnapshot from the same candidate state.
4. Derive exclusive queue envelopes only beside guaranteed selected doors.
5. Run H1 plan-local Phase A.
6. Allocate/match persistent parcel IDs; rerun H5 and Phase A with stable IDs.
7. Before Zone publication, require stable Phase A to reproduce selected edges, graph fingerprint, envelopes, and feasible-profile pool from unchanged semantic inputs.
8. After Zone publication, H3 may invoke Phase B only inside a Tenant candidate/bind/rebuild transaction once tenant/profile variation exists. Any Phase B mismatch/staleness blocks that Tenant transaction, not Zone geometry already published.

Preview allocates no persistent IDs.

## Initial splitting

Validate geometry/frontage, apply cheap capability filters, enumerate cores, apply automatic compact/standard/large distribution, and bounded-search by coverage, nonempty pools, scale diversity, compactness. Then run prospective pipeline, annex valid leftovers, absorb initial profile-empty parcels where valid, convert unresolved residuals to Decoration, and reject only when no conclusive valid fronted feasible parcel remains.

Search indeterminacy is technical failure, not unsuitable geometry. Targets may shrink. Leftovers join edge-adjacent parcels ranked by connectivity/frontage, compactness, conclusive fixture gain, canonical order.

## Anchors

One connected Anchor Tenant component becomes exactly one parcel and bypasses multi-splitting. It must be fronted and feasible for at least one Anchor profile; profiles need not share a core. H3 weights the feasible union. Player selects Anchor zone type, not tenant profile.

## QueueGeometryPolicy

Session content owns one immutable versioned policy used by preview, commit, restore, projection. In integer quarter-tile units it defines:

- two offsets per eligible public queue tile in a wall-side frontage-parallel band;
- canonical scan/group order from each operational door across contiguous frontage;
- clear door-approach mask and position/edge clearances;
- forbidden nonpublic cells, vertical links, source anchors, intersections/crosswalk reservations, structural/manual-door approaches, fixed occupancy;
- conflict keys for coincident/clearance-overlapping positions;
- per-door grouping/orientation/max scan length; and
- proof public centerline remains walkable and no whole tile is reserved.

Every value is explicit normalized content. Policy identity/revision enters envelope provenance and layout fingerprints. A pure resolver consumes matching selected doors and graph/policy.

## Exclusive parcel envelopes

Each Zone plan:

1. preserves legal committed envelopes for locked parcels;
2. guarantees capability minima to new/mutable parcels in canonical plan-key order;
3. distributes remaining positions round-robin up to maxima;
4. assigns each conflict key once.

H4 activates only committed parcel positions, so opening order cannot affect capacity. Because locked-envelope preservation is history-sensitive/gameplay-relevant, Zone persists committed position IDs plus door/topology/policy provenance. Restore validates them against freshly derived legal candidates; invalid or missing current-schema provenance rejects before staging. Queue occupants remain transient. No adapter is authorized.

## Suitability

Track freshness (`AVAILABLE/STALE/UNAVAILABLE`) separately from suitability (`SUITABLE/UNSUITABLE/INDETERMINATE`). Empty established parcels may remain unsuitable/rent-free.

## Established mutation cases

1. Unchanged locked: preserve identity/geometry/doors/envelope/provenance.
2. Changed vacant: recompute; may become suitable/unsuitable.
3. Changed occupied retaining identity/profile feasibility: prepare replacement Phase B fingerprint/service rebuild; lifecycle/rent unchanged.
4. Actual parcel retirement through authorized player operation: Tenant H1 retirement plus Visitor/Service cleanup.
5. Bound-profile invalidation without authorized retirement: reject `BOUND_INTERIOR_INVALIDATED`.

Touching geometry alone is not retirement authorization.

## Shared topology mutation protocol

Every Zone, circulation, door, vertical-link, or District transaction altering affected proxy/envelope topology uses ServiceTopologyMutationGate:

1. freeze affected admission/transitions;
2. capture writer, Zone/H5, Service, Visitor, optional Tenant revisions;
3. build prospective graph/envelopes plus visitor resume/cancellation, service rebuild/teardown, optional authorized retirement, topology-owner candidates;
4. complete all fallible validation;
5. acquire session gate and revalidate;
6. swap prepared non-failing states Visitor -> Service -> Tenant if participating -> topology owner/Zone/Grid;
7. increment revisions and publish H5 graph equal to prospective fingerprint;
8. at the commit point, append one complete non-failing aggregate envelope to the synchronous notification queue while the session gate remains held;
9. synchronously flush aggregate and owner fact notifications in fixed owner order while the gate remains held;
10. release ServiceTopologyMutationGate and session gate.

Save/export/another mutation cannot interleave between state swap and notification completion. Failure before first swap commits nothing; notification append/flush after revalidation is non-failing by contract.

## Preview, persistence, and events

ZoneMutationPlan carries cores/annexes, selected-door/graph/policy fingerprints, feasible counts, residual/Anchor result, exclusive envelopes, suitability, replacement fingerprints, invalidation sets.

Current Zone schema persists parcel tiles/core, committed envelope IDs/provenance, geometry/doors; not pools, caches, occupants, fixtures, transforms. Missing/older schema rejects before staging. Zone events publish detached committed geometry/revision facts only.

## Acceptance requirements

- Parcels are non-overlapping, connected, holed-free, fronted, cored.
- Initial pools are conclusive/nonempty with scale diversity.
- Stable Phase A reproduces prospective pool/doors/graph/envelopes before Zone publication.
- Phase B gates only Tenant candidate/bind/rebuild.
- Anchors yield one parcel feasible for at least one profile.
- Queue policy has no implicit values; persisted envelopes are deterministic/exclusive/order-independent and round-trip exactly.
- Five mutation cases exhaustive; unsupported invalidation rejects.
- Every topology writer coordinates Visitor/Service atomically.
- Save/events observe no partial or unannounced transaction.

## Required tests

- Scale/annex/residual/Anchor and indeterminate goldens.
- Prospective/stable H5 door, graph, envelope, and Phase A pool parity.
- Phase B stale/mismatch rejection without Zone rollback.
- Queue policy forbidden/conflict/walkability cases.
- Envelope history preservation/save round trip/reverse-order initialization/edit/invalid provenance rejection.
- Five mutation cases and every topology writer with visitor states/fault injection.
- Commit-envelope ordering, reentrant save/mutation exclusion, and notification fault-proofing.

## Required implementation skills

`resource-pattern`, `godot-testing`, `scene-organization`, and `dependency-injection`.
