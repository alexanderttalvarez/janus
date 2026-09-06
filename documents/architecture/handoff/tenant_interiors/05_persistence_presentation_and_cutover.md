# Tenant Interiors Handoff 05 — Persistence, Presentation, and Cutover

**Status:** Draft — awaiting architecture approval  
**Implementation order:** 5 of 5

## Purpose

Integrate strict current-schema validation, deterministic rebuild, transient service reset, presentation, historical-result isolation, and Product MVP cutover without a new root authority key or economic meaning.

## Save strategy and durable amendments

Product MVP does not persist queue occupants/FIFO or service/batch/token state. Exact in-flight restore requires future durable Tenant Service persistence/likely Save V3.

- Zone persists parcel tiles/core, geometry/doors, committed queue-envelope IDs and door/topology/QueueGeometryPolicy provenance.
- Tenant persists operational profile, policy revisions, primary proxy, layout fingerprint.
- Visitor persists service capability, visitor policy, behavior seed domain/creation ordinal even with zero visitors. Each visitor persists policy, captured-category fingerprint/empty marker, consumed seed domain/ordinal, generated goals/progress, wait tolerance, exclusions, results, resume facts.

## Current authority-local schema contract

Root remains exact Save V2. This handoff freezes the three amended authority-local discriminators:

| Authority | `state_schema_id` | `state_schema_version` |
|---|---|---:|
| `zone_parcel` | `zone_parcel_core_annex` | 1 |
| `tenant` | `tenant_operational_interior` | 1 |
| `visitor` | `visitor_interior_service` | 1 |

Both fields are required with exact string/integer type and value. Visitor additionally requires `service_capability_id = "interior_service_v1"` and `service_capability_revision = 1`. Unknown/missing/older values reject before staging. Other authority snapshots retain their already-approved schemas; this handoff does not add fields to them.

## Save barrier and canonicalization

SaveManager freezes all mutations/events for complete registry export.

- DECIDING/LEAVING export existing durable facts.
- TRAVELING exports approved current public/source anchor and destination intent; never teleports to unreached door.
- EVALUATING/WAITING/IN_SERVICE remove transient service/queue/token/batch identity and export target proxy as resume anchor with `DECIDE_AT_PUBLIC_PROXY`.
- Export never completes/drops a goal or fabricates a result.

Invalid required anchors fail export and preserve previous slot. Service has no root snapshot. Cross-authority invariants prove no one-sided commitment.

## Exact detached validation and restore

Session H2 registry order remains:

```text
district -> zone_parcel -> economy -> progression -> prestige
-> staff -> synergy -> tenant -> visitor -> time
```

Before candidate import SaveManager:

1. enforces root V2/exact keys, the three exact current discriminators, and current content/layout;
2. validates detached Zone core/annex geometry plus persisted envelope IDs/provenance against freshly derived legal candidates;
3. validates detached Tenant operational-profile/policy/proxy/layout provenance and derives H1 Phase B layouts;
4. derives canonical operational service-category availability from validated Open tenants;
5. validates Visitor capability and manager policy/seed/ordinal plus every visitor's policy, category fingerprint/empty marker, consumed ordinal, goals, wait, progress, exclusions, results, anchors without reroll;
6. lets every owner validate its current snapshot detached;
7. runs fixed-order cross-authority validation, including envelope legality, graph/layout fingerprints, visitor provenance/anchors;
8. imports candidates only in exact registry order;
9. rebuilds candidate graph/layouts/empty services/scheduler marker/projections and verifies parity;
10. publishes through Session H2 barrier, then exactly one `game_loaded`.

Committed envelopes are required current Zone fields. Restore never synthesizes them. Failure destroys candidate and preserves session/slot. Staging emits no gameplay events or retroactive scheduler work. Service initializes its transient last-consumed marker to restored current Time boundary; batch phase uses H4's exact Time-origin/hash/cadence equation.

## Compatibility boundary

No executable runtime/offline compatibility layer or save transformation is authorized. V1/schema-absent and older/incompatible authority-local snapshots reject before staging. Historical proxy result records may remain immutable/non-economic only inside an otherwise valid current Visitor schema; they do not select legacy capability, regenerate behavior, or provide service. Nothing is silently dropped/remapped or served by proxy.

## Result families

Historical Visitor H1 purchase result is a non-economic proxy observation. New tenant-service result is a non-economic abstract completion. Explicit schema/kind separates them; neither reaches Economy, viability, satisfaction, demand, or Prestige.

## Presentation

```text
Projection
├── TenantInteriorProjectionRoot
│   └── TenantInteriorView (pooled/culled)
│       ├── StructuralVisuals
│       ├── FixtureVisuals
│       └── AbstractOccupancyVisuals
├── QueuePresentationRoot
└── VisitorProjectionRoot
```

Views consume snapshots only. Fixture scenes obey H1 restrictions and require default visuals; themes may fall back. Culling/pooling cannot alter simulation; MultiMesh/LOD follows profiling.

Presentation exposes freshness separately from suitability, full ratings/top three, profile/theme/sign, fixtures/capacity, queue/wait, occupancy/batch countdown, unsuitable diagnostics. UI never reruns planning/selection/scheduling. EventBus only prompts snapshot refresh.

## Capability and scope gates

1. **Corridor Service Integration Gate:** Visitor H1 foundation evidence; not Product MVP.
2. **Interior shadow validation:** H1–H3 detached diagnostics only.
3. **Bootstrap capability:** every Product MVP save/session requires the exact current Visitor capability before readiness. Historical result records do not select proxy capability. No live switch/mixed fallback.
4. **Product MVP:** foundation plus Tenant Interiors H1–H5 headless and visual evidence.

After approval, MVP H1 proxy loop becomes historical foundation evidence and its interior exclusion is superseded for Product MVP. Revenue/viability/satisfaction/Prestige/indoor-navigation exclusions remain.

## Acceptance evidence

Headless: content; scale/core/annex/Anchor; absorption/unsuitable; 6/3/1 vs commercial evaluation; unchanged Open/rent; fingerprints; representative services; wait/goals; congestion; current-schema saves; schedule phase; strict rejection; envelope history; result isolation; no fallback/economics; committed-only read models.

Visual/editor: minimum/preferred/oversized/annex interiors, wall/door fit, comfort density, default bounds, occupancy cues, queues, unsuitable diagnostics, compatibility views. Numeric retuning requires playtest evidence.

## Acceptance requirements

- Root V2/order exact; exact current discriminators load; rejection preserves slot/session.
- Owner/cross-reference validation completes detached before import.
- Persisted envelopes round-trip/remain legal; restore synthesizes none.
- Detached/candidate graph, envelope, layout results are byte-equivalent.
- Capability/policy/seed/ordinal persist with zero visitors.
- Per-visitor goal provenance validates without reroll, including empty category.
- Canonicalization never teleports first-trip travelers/replays completion.
- Save barrier prevents torn state; schedule cannot reset.
- Results remain disjoint/non-economic; bootstrap prevents mixed service.
- Product MVP requires headless and visual evidence.

## Required tests

- Exact current/missing/older/incompatible discriminators and capability; pre-staging rejection preservation.
- Zero/active visitor manager/per-record provenance and no-reroll round trip.
- Envelope history, missing/illegal provenance rejection, detached/candidate parity.
- Fault injection before import/publication.
- Save matrix for every visitor/service state, invalid anchors, simultaneous completion, visitor 200.
- First-trip traveling versus reached-proxy canonicalization.
- Batch boundary/reload exploit tests.
- Presentation freshness/suitability/projection isolation.
- Capability/no-fallback, historical results, complete Product MVP gates.

## Required implementation skills

`save-load`, `scene-organization`, `resource-pattern`, `event-bus`, `godot-ui`, `hud-system`, `assets-pipeline`, and `godot-testing`.
