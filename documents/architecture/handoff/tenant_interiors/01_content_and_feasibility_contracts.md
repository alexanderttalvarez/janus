# Tenant Interiors Handoff 01 — Content and Feasibility Contracts

**Status:** Approved — 2026-09-06  
**Implementation order:** 1 of 5

**Revision:** 2026-09-08 delegated consistency pass. [Current MVP](../../../game_design/current_mvp.md), [element 20](../../../game_design/elements/20_tenant_interiors_visitor_interactions.md) and ADR 33 apply. Element 20 supplies explicit revision-1 service/planning/fixture defaults for authored content, never runtime fallback. The [program readiness matrix](_index.md) limits this approval to detached outcomes: operational-category inputs and Visitor persistence are fixture-tested contracts, not live H8/schema changes before draft H4/H5 approval. Any indeterminate eligible profile defers selection; it cannot be discarded to label geometry Unsuitable.

## Purpose

**Follow-on review, 2026-09-08:** The revision above records the earlier consistency pass. [ADR 34](../../decisions/34_product_mvp_runtime_and_cutover.md) separately architecture-approves H4/H5. H1 still proceeds detached-first after foundation; fixtures do not activate live categories, H8 goals or Visitor schemas. Live integration follows H4 implementation passes and H5 candidate cutover passes, then [Product acceptance](../mvp/04_product_delivery_and_acceptance.md). Implementation/cutover remain NOT VERIFIED; Product acceptance and separate external Gate R remain PENDING.

Define immutable versioned content and pure deterministic planning for subtype feasibility, fixtures, and minimal Product MVP visitor goals. No runtime service, Nodes, visitor movement, parcel mutation, or economy effect is created here.

## Decisions

Authored typed Resources compile into deeply detached immutable values. Runtime keeps no authored mutable collections. Pure planners inspect no Nodes/scenes/physics/navigation/managers. Capacity comes from envelopes, never visuals. Operational subtype and tenant theme are separate. Planning has plan-local feasibility then stable final layout. Minimal visitor goals are introduced; budgets/satisfaction/attraction/prices remain excluded.

## Immutable content

| Definition | Identity | Owns |
|---|---|---|
| Fixture | fixture ID + revision | Occupied/clearance masks, rotations, interaction faces, tags, capacity, visuals. |
| Fixture visual | visual ID + revision | Restricted projection scene and envelope transform only. |
| Operational profile | profile ID + revision | Zone type, area/core/range, fixture programs, comfort density, frontage/queue, service policy. |
| Service policy | service policy ID + revision | Typology, queue cap, fixed integer visitor-tick durations/cadence, tokens, scheduler/wait inputs. |
| Visitor service policy | visitor policy ID + revision | Goal IDs/distribution, compatibility, wait range/distribution, exclusions, completion/drop. |
| Planning policy | policy ID + revision | Ordering, budgets, placement/rating, 6/3/1 tickets, diagnostics. |
| Tenant profile | preserved profile ID + candidate revision | Candidate theme/tier/subtype and operational-profile reference. |

IDs are canonical stable strings. Missing/duplicate/cyclic/incompatible/unversioned references reject the bundle; no fallback.

## Minimal visitor policy

VisitorManager owns persisted behavior seed and monotonic creation ordinal. On H8 realization, seed-domain identity + ordinal + visitor ID + visitor-policy revision derive:

- 1–3 goals using 40%/45%/15%;
- goal kinds from the one-time captured currently operational service categories, using canonical policy order and deterministic weighted draws;
- wait tolerance from explicit integer visitor-tick range/distribution;
- first goal active.

**Empty-category exception:** generate exactly one Browsing goal. Because it has no target, normal policy immediately drops it and assigns Leaving. This is the only exception to category-filtered generation.

Current-schema Visitor persistence contains capability ID/revision and visitor-policy ID/revision even with zero active visitors. Each visitor record contains seed-domain identity, consumed creation ordinal, captured category-snapshot fingerprint or explicit empty marker, generated goals, completed/dropped markers, active index, wait tolerance, and current-goal excluded tenant IDs. Restore validates provenance and state without rerolling. Completion advances/finishes active goal and clears exclusions. No compatible non-excluded service drops the goal; then advance or Leave. These transitions never spend money/change satisfaction.

## Resource and visual validation

Compilation proves masks/rotations/tags/references, mandatory-core plausibility, finite counts/densities, policy agreement, candidate/profile zone agreement, subtype baselines, and deep detachment.

Every gameplay fixture requires a default visual; theme variants may fall back. Missing default blocks Product MVP. Projection scenes require approved Node3D root, no gameplay script/process/collision/navigation/autoload access, and validated local bounds under transforms/reimport. Editor placeholders do not satisfy MVP.

Service policy validation proves positive fixed durations/cadences, batch service+turnover fits cadence, and coherent tokens/queue minima.

## Two-phase planning

**Phase A formation:** plan-local parcel key, prospective geometry/frontage/selected-door/queue envelope, zone type, policies. Produces feasible profiles/ratings; no persistent IDs, physical-door IDs, fixture IDs, or final fingerprint.

After Zone assigns persistent parcel/door/proxy IDs, it reruns stable-identity Phase A. Unchanged semantic inputs must reproduce the same feasible profile pool before Zone publication.

**Phase B tenant transaction:** after stable Zone publication and once Tenant has candidate/profile variation identity, H3 invokes Phase B to produce primary proxy, fixtures, capacity, queue use, and final fingerprint. Phase B mismatch, indeterminacy, or stale provenance blocks that Tenant candidate/bind/rebuild transaction; it does not roll back already-published valid Zone geometry.

Detached output contains phase, `VALID/INFEASIBLE/SEARCH_INDETERMINATE/CONTENT_INVALID`, source revisions, core/annex, fixture/circulation proof, final proxy, queue/capacity, comfort utilization, rating/tickets, diagnostics, final fingerprint. Durable fixture IDs exist only in Phase B.

## Determinism and fingerprints

Canonical ordering precedes enumeration. Partition search uses cheap capability checks; full search runs for prospective final parcels/profiles. Budgets count deterministic work units. Exhaustion is `SEARCH_INDETERMINATE`, never unsuitable geometry.

Fingerprints normatively reuse District H2 RFC 8785 canonical JSON + lowercase SHA-256. Semantic values are integer/string/boolean/null/array/object only; no floats. Cells are row-major `(y,x)`, enums canonical strings, sets ordered arrays.

Fingerprint includes parcel/core/annex, stable door/proxy and committed queue-envelope IDs, operational profile, fixture placements/orientations, circulation, capacity, every gameplay policy ID/revision. It excludes visual variant, world transform, Node, localized diagnostics, caches, presentation.

## Diagnostics

Required stable codes cover content unavailable, area/core/frontage/door/queue unmet, mandatory fixture/clearance/circulation failure, search indeterminate, and no feasible operational profile. Payloads contain values, not localized copy.

## Ownership and persistence

Session owns compiled content provenance; planner owns detached results; Zone owns geometry/doors/envelopes; Tenant owns candidate/lifecycle/layout provenance; Visitor owns generated goal state/provenance; Presentation owns visuals. Dependencies are injected; planner/content are not autoloads; EventBus carries no queries/commands.

Definitions are referenced, not saved. Current authority-local schema discriminators and content IDs/revisions/fingerprints are required. Missing, older, or incompatible schemas/content reject before staging; this program authorizes no compatibility adapter.

## Acceptance requirements

- Same phase/request/content gives byte-identical output.
- Visitor generation, empty-category Browsing exception, wait tolerance, goals/progress/drop/exclusion clearing are deterministic and persistent without reroll.
- Phase A allocates no persistent identity; stable Phase A pool parity gates Zone publication.
- Phase B requires stable identities and gates only its Tenant transaction.
- Valid results prove mandatory placement/connectivity/clearance.
- Search exhaustion differs from infeasible.
- Default visuals satisfy restricted contract and cannot alter gameplay.
- Ratings contain no commercial inputs; authored mutation cannot affect compiled values.

## Tests

- Resource graph/deep detachment/nested mutation.
- Visitor goal boundaries, category filtering, Browsing exception, seeded creation, provenance, wait, progression/drop/save round trip without reroll.
- Phase A stable-identity pool parity and Phase B subtype footprint/fingerprint goldens.
- RFC 8785/SHA-256 goldens, search budgets.
- Fixture/visual bounds and forbidden behavior.
- Proof commercial/economic/Prestige/Node state cannot affect planning.

## Required implementation skills

`resource-pattern`, `godot-testing`, `dependency-injection`, `assets-pipeline`, and `multithreading` only if detached planning moves off-thread.
