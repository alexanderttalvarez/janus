# Prestige Handoff 01 — Official Tier Publication

**Status:** Approved — 2026-09-05
**Prepared:** 2026-09-05
**Implementation order:** 1 of 2

**Revision:** 2026-09-08 delegated consistency pass. [Current MVP](../../../game_design/current_mvp.md), ADR 33 and MVP H3 apply. Prestige still does not award Tech points; Progression now has an explicit element-08 award policy and must not infer it from rent/tenant tiers. Import-time eligibility is derived only after candidate Prestige exists.

## Purpose

Establish the smallest trustworthy Prestige authority: a detached, revisioned official-tier snapshot that supplies Tenant H2's supported tenant tier and rent ceiling and notifies Progression of committed tier changes. It intentionally does **not** certify the current incomplete Scale/Quality implementation as authoritative.

## Authoritative sources

- [Prestige System design](../../../game_design/elements/02_prestige_system.md)
- [Decision 22 — Prestige Calculation Architecture](../../decisions/22_prestige_calculation_architecture.md)
- [Tenant Handoff 02 — Rent Policy and Application Evaluation](../tenant/02_rent_policy_and_application_evaluation.md)
- [Progression Handoff 01 — Eligibility Policy and Snapshot Boundary](../progression/01_eligibility_policy_and_snapshot_boundary.md)
- [District Handoff 09 — Save/Load V2 and District Persistence](../district_layout/09_save_load_v2.md)

## Scope

- `PrestigeManager` as the sole owner of committed official-tier facts and their revision.
- Immutable, versioned prestige-tier/rent-ceiling policy content.
- Explicit authored initial official snapshot: Empty Lot, supported Tenant Tier 1, 500 centi-Kreds/tile/day ceiling.
- Detached `OfficialPrestigeSnapshot` read, validation, staging, and V2 persistence contract.
- Typed post-commit tier/snapshot signals for Progression and Tenant H2 consumption.
- Clear quarantine of the existing incomplete calculation as non-authoritative debug preview only.

## Explicit non-goals

- Implementing or approximating Scale, Quality, their six factors, trend, loan-default multiplier, monthly recalculation, or visitor-attraction multiplier.
- Tenant Quality/Satisfaction, visitor volume/experience, circulation quality, or any new source snapshot calculation.
- Tech-point grants/awards, Tech ownership, Plot selection, or District mutation.
- Visitor demand changes, UI/panel design, notifications, or save migration adapters.
- Changing the approved Prestige tier thresholds, rent ceilings, names, or tenant-tier mapping.

## FACTS

- Prestige is the authoritative tier calculator/producer; Progression consumes committed tier changes but owns unlock/point/milestone state.
- Tenant H2 requires an immutable official supported-tier plus rent-ceiling snapshot. It must defer, not assume Tier 1, when unavailable/stale.
- Approved tier/rent-ceiling policy is: Empty Lot 5; Small Market 10; Neighborhood Center 18; Regional Mall 30; City Destination 45; Megacity Mall 60 Kreds/tile/day.
- Initial official state is Empty Lot, supporting Tenant Tier 1 with a 500 centi-Kred ceiling.
- Megacity adds an Exclusive eligibility flag; Exclusive is not Tenant Tier 6.
- Save/Load V2 requires exact detached authority snapshots, validation/staging before exposure, and no unapproved migration adapter.

## ASSUMPTIONS

- Rent ceilings use the same fixed-point centi-Kred representation adopted by Tenant H2.
- A future full Prestige-calculation handoff will submit a validated candidate official result to this authority; H1 does not prescribe its calculation algorithm.
- Tier changes are infrequent and can be delivered synchronously as typed post-commit manager signals. Presentation may project them to EventBus separately.

## Resolved Inputs and Deferred Work

- H2 supplies the approved monthly baseline candidate through this handoff's commit boundary; authored initial Empty Lot has no fabricated score. MVP H3 supplies coherent source assembly.
- Element 08/MVP H3 approve exactly-once Tech awards under Progression ownership. No generic achievement system or Prestige-owned point mutation is required.
- Full Quality factors, loan-default effects, daily trend and visitor-attraction consumption remain deferred. Missing future inputs do not block the current baseline.

## Ownership and boundaries

| Owner | Owns | Must not own |
|---|---|---|
| `PrestigeManager` | Official tier snapshot, authority revision, policy-reference validation, staging/commit, typed official signals. | Tech points/unlocks, rate mutation, tenant selection, visitor spawning, mutable source factors. |
| Prestige/rent policy content | Tier IDs/order, thresholds, supported tenant tier, Exclusive flag, rent ceiling, policy revision. | Runtime tier state, calculations, balances. |
| Future Prestige calculation authority | Validated candidate official Prestige/tier result and source provenance. | Direct overwrite of committed Prestige state. |
| `TechTreeManager` / Progression | Idempotent tier-milestone processing, Tech facts, Plot Access, progression revision. | Prestige calculation or Prestige snapshot writes. |
| `TenantManager` | Captures Prestige snapshot as an H2 evaluation input. | Tier/rent-ceiling mutation or fallback policy. |
| `SaveManager` | Whole-session atomic snapshot orchestration. | Prestige inference, repair, migration, or event replay. |
| EventBus/UI | Presentation projection of committed events. | Authoritative consumer contract or state writes. |

```text
immutable PrestigePolicy
  -> PrestigeManager commits OfficialPrestigeSnapshot
  -> typed official_tier_changed(snapshot) -> Progression idempotent milestone sync
  -> typed official_prestige_snapshot_changed(snapshot) -> Tenant H2 next evaluation context
```

## Policy and official snapshot

### Immutable policy

Policy is immutable/revisioned content and maps each official tier to: stable tier ID, documented threshold range, highest supported Tenant tier, rent ceiling in centi-Kreds/tile/day, and `exclusive_eligible` flag. The approved mapping is:

| Official tier | Supported tenant tier | Ceiling (centi-Kreds) | Exclusive |
|---|---:|---:|---|
| `empty_lot` | 1 | 500 | false |
| `small_market` | 2 | 1000 | false |
| `neighborhood_center` | 3 | 1800 | false |
| `regional_mall` | 4 | 3000 | false |
| `city_destination` | 5 | 4500 | false |
| `megacity_mall` | 5 | 6000 | true |

### `OfficialPrestigeSnapshot`

The detached snapshot contains exactly:

- schema version and `authority_revision`;
- official tier ID;
- highest supported tenant tier and Exclusive eligibility flag;
- rent ceiling in centi-Kreds/tile/day;
- referenced immutable policy revision;
- official calendar/recalculation identity; and
- optional official numeric prestige only when a future approved authority supplied it, with explicit presence/provenance metadata.

It excludes trend, scale/quality breakdowns, placeholder factor values, Node references, UI state, Tech points, progression state, visitor multiplier, and live mutable source snapshots. H1 initial snapshot has `empty_lot`, supported tier `1`, ceiling `500`, current policy revision, and initial calendar identity. It does not synthesize numeric Prestige/Scale/Quality.

## Commit and event rules

Only `PrestigeManager` can replace the committed official snapshot. A future calculator supplies a detached candidate with policy revision and calendar identity; PrestigeManager validates schema, policy, tier mapping, calendar identity, and candidate provenance before atomically swapping it. PrestigeManager alone assigns the next authority revision. Invalid/missing candidates leave the prior committed snapshot unchanged.

After a successful swap:

1. increment Prestige authority revision;
2. publish `official_prestige_snapshot_changed(snapshot)` with a detached snapshot;
3. if tier ID changed, publish `official_tier_changed(previous_snapshot, snapshot)`;
4. Progression consumes the typed tier event and performs only its approved idempotent milestone synchronization; and
5. presentation may receive a separate projection after authoritative consumers finish.

No Prestige or Progression business event fires during load staging/import. SaveManager publishes only its post-atomic `game_loaded` boundary; consumers rebuild derived views from committed snapshots.

## Consumer contracts

### Tenant H2

TenantManager captures the complete detached snapshot when preparing an ApplicationEvaluationContext. It uses only `supported_tenant_tier`, `rent_ceiling_centi_kreds`, authority revision, and policy revision. It never reads manager fields directly, changes tier/ceiling, or uses a fallback. A missing/stale snapshot defers application using H2 diagnostics/retry rules.

### Progression H1

Progression captures the committed tier ID and policy revision from the typed event/snapshot. It remains sole owner of Tech points, unlocked nodes, Plot Access grants, and progression revision. H1 preserves only approved idempotent Plot Access milestone behavior; it does not award, mirror, or infer Tech points from Prestige.

### Debug preview

The current non-authoritative Scale/Quality implementation may be retained only behind an explicit debug-preview boundary. It must not overwrite the official snapshot, publish authoritative tier events, feed Tenant/Progression/Economy/Visitor authority, persist in `authorities.prestige`, or masquerade as official HUD data.

## Persistence and load

`authorities.prestige` V2 uses this exact schema. Persist only the committed snapshot fields listed above. Existing development prestige snapshots using another schema are invalid; V2 provides no migration adapter.

Prestige validates and stages its detached snapshot before any live authority exposes restored state. Progression validates/stages its own Tech/milestone facts and then rebuilds eligibility from committed Prestige tier plus its own state. Tenant H2 later consumes the restored snapshot normally. Any policy mismatch, unknown tier, invalid tenant-tier/ceiling mapping, bad revision, or malformed field rejects the entire V2 load and preserves the previous session.

## Acceptance requirements

- A new session exposes the exact authored Empty Lot snapshot without running a fake Scale/Quality calculation.
- Every official tier maps only to its approved tenant cap, rent ceiling, and Exclusive flag.
- Tenant H2 captures detached snapshot data and defers when unavailable/stale; it cannot invent a Tier 1 or rent ceiling.
- Only a committed tier-ID change publishes `official_tier_changed`; a ceiling/policy/revision change without tier change publishes only snapshot-changed.
- Progression receives no duplicate tier milestone after recomputation/load and no Tech points are awarded by Prestige H1.
- Debug-preview values never reach authoritative consumers or V2 prestige persistence.
- V2 rejects invalid/development legacy prestige data atomically, with no event emission during staging.

## Required implementation skills

Before implementation, load `resource-pattern`, `event-bus`, `dependency-injection`, `save-load`, and `godot-testing`. A later official-calculation handoff must additionally define source snapshots and use the same commit/revision boundary rather than writing `PrestigeManager` fields directly.
