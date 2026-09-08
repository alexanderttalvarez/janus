# Prestige Handoff 02 - MVP Official Scale and Baseline Quality

**Status:** Approved — 2026-09-05 (delegated architecture authority)
**Prepared:** 2026-09-05
**Implementation order:** 2 of 2

**Revision:** 2026-09-08 delegated consistency pass. Element 02 is the single calculation authority. ADR 33/[MVP H3](../mvp/03_foundation_integration_clarifications.md) name the coherent developed-tile read assembler and complete source revision tuple. The calculation producer reads District/Zone/Tenant state without adding an owner or saved cache; Progression alone applies element-08 Tech awards.

## Purpose

Define the smallest truthful official Prestige calculation needed to test progression: approved developed-tile Scale multiplied by the documented functional Quality minimum of 20. On each monthly calendar boundary, this handoff produces a detached official candidate for Prestige H1 to validate and commit. It does not claim that any of the intended Quality factors, loan-default behavior, daily trend, Tech-point awards, or visitor effects exist.

## Authoritative sources

- [Prestige System design](../../../game_design/elements/02_prestige_system.md): core formula, developed-tile rule, Scale cap, Quality minimum, monthly cadence, and deferred Quality factors.
- [Decision 22 - Prestige Calculation Architecture](../../decisions/22_prestige_calculation_architecture.md): `PrestigeManager` aggregation intent and monthly official recalculation boundary.
- [Prestige Handoff 01 - Official Tier Publication](01_official_tier_publication.md): the only official commit, revision, event, and prestige-persistence authority.
- [Progression Handoff 01 - Eligibility Policy and Snapshot Boundary](../progression/01_eligibility_policy_and_snapshot_boundary.md): Progression consumes committed tier changes and remains the sole Tech/point owner.
- [District Handoff 09 - Save/Load V2 and District Persistence](../district_layout/09_save_load_v2.md): detached authority snapshots, staging, and atomic V2 session replacement.

## Scope

- A revisioned developed-tile source snapshot from the existing District/zone/parcel authority.
- Official Scale as 0.25 points for each distinct developed tile, capped at 100.
- Official Quality fixed at the documented minimum of 20.
- A monthly detached calculation candidate submitted to `PrestigeManager` under H1's existing commit boundary.
- Candidate provenance, H1 persistence usage, post-commit event behavior, and tests.

## Explicit non-goals

- Implementing, naming, weighting, approximating, or supplying placeholder values for the six Quality factors.
- Loan-default multiplier/default-state integration, visitor attraction, within-tier effects, Quality history, or Quality-factor presentation.
- A daily trend estimate or trend indicator. Daily trend is explicitly **unavailable** for this MVP.
- Tech-point awards, Tech ownership, unlock mutation, Plot Access mutation, or any new Progression policy.
- Changing tier thresholds, supported tenant tiers, rent ceilings, the H1 initial Empty Lot snapshot, or H1's validation/commit ownership.

## Approved MVP calculation

### Developed-tile source

A tile is developed when the authoritative resolved District/zone/parcel state marks that stable tile as containing a zone, tenant, or amenity, as defined by the Prestige System design. Empty purchased land and undeveloped plots do not count. A tile counts once even when more than one qualifying condition is true.

The source authority exposes a detached snapshot containing the canonical distinct developed-tile count and its monotonic `source_revision`. The calculator does not scan Nodes, infer development from presentation, or reconstruct it from save JSON. The source revision changes whenever the authoritative developed-tile set can change.

### Values and arithmetic

Use exact quarter-point arithmetic:

```text
developed_tile_count = source snapshot's distinct qualifying-tile count
scale_quarters = min(developed_tile_count, 400)
Scale = scale_quarters / 4
Quality = 20
Prestige = Scale * Quality
```

`scale_quarters` is the canonical calculation value, avoiding floating-point ambiguity. `Scale` is 0 through 100 in 0.25-point increments; the display conversion is derived. `Prestige` is the exact product of the approved Scale and baseline Quality, yielding 0 through 2,000 for this MVP. Tier resolution uses the existing immutable H1 policy; it is not duplicated in the calculator.

Quality 20 is a baseline, not an estimate, a score for a missing factor, or evidence that the six-factor Quality model is implemented. The six-factor model and the loan-default multiplier remain unavailable rather than being treated as neutral values.

## Candidate, source revisions, and cross-references

At each authoritative monthly calendar identity, the calculator captures one detached developed-tile source snapshot and produces one `OfficialPrestigeCandidate` containing:

- calculation schema/revision and baseline-quality policy revision;
- calendar/recalculation identity;
- developed-tile `source_revision` and count;
- `scale_quarters`, baseline Quality `20`, and numeric Prestige;
- the H1 policy revision against which the tier is resolved; and
- provenance declaring `mvp_developed_tile_scale_baseline_quality`.

The candidate is valid only when its captured source revision and H1 policy revision still match at commit validation. A changed source or policy revision invalidates the candidate; the next monthly boundary must produce a replacement. The candidate contains no Node references, mutable source objects, Tech data, loan state, factor breakdown, trend, visitor multiplier, or UI data.

```text
monthly Time authority boundary
  -> calculation producer captures coherent District/Zone/Tenant developed-tile union + full revision tuple
  -> calculate Scale x fixed Quality 20
  -> resolve tier through H1 policy
  -> submit detached candidate to PrestigeManager
  -> H1 validates provenance, calendar, policy, and source revision
  -> H1 atomically commits OfficialPrestigeSnapshot or leaves prior official state unchanged
```

This calculation is a producer, not a second Prestige authority. `PrestigeManager` alone assigns `authority_revision`, replaces `OfficialPrestigeSnapshot`, and decides whether a tier-change event occurred. Tenant H2 continues to consume the resulting committed H1 snapshot. Progression H1 continues to consume only committed tier changes and retains sole ownership of Tech points, milestone state, Plot Access, and progression revision.

## Cadence and availability

The Time authority invokes candidate production once every 30 simulation days using the same official calendar/recalculation identity required by H1. No initial calculation is fabricated: a new session starts with H1's authored Empty Lot official snapshot until the first valid monthly candidate commits.

There is no daily source capture, lightweight recalculation, comparison, arrow, or neutral trend value. Any presentation consumer must expose trend as unavailable, not as stable or zero. Presentation may show H1's committed official numeric Prestige and tier only when those fields are available through the existing official snapshot contract; it must not read a pending candidate.

## Persistence and load

H2 does not add a second persisted Prestige state or alter the V2 root envelope. `authorities.prestige` remains H1-owned and persists only H1's committed official snapshot, including its optional official numeric Prestige and provenance metadata when supplied by this calculation. The persisted provenance identifies this calculation revision, baseline-quality policy revision, developed-tile source revision, and source calendar identity; it does not persist a live candidate, source snapshot, factor values, trend, or derived UI state.

During V2 load, H1 validates and stages the committed snapshot under its existing rules before exposure. The developed-tile source authority independently stages its own state. No recalculation, candidate submission, tier event, or Progression/Tech mutation occurs during load. The next normal monthly boundary produces a fresh candidate from committed source state.

## Events

Candidate production is internal calculation work and emits no authoritative gameplay event. A successful H1 commit follows H1 exactly:

1. H1 assigns the next authority revision and publishes `official_prestige_snapshot_changed(snapshot)` with a detached snapshot.
2. H1 publishes `official_tier_changed(previous_snapshot, snapshot)` only if the official tier ID changed.
3. Progression performs its existing idempotent tier-milestone synchronization; it receives no Tech-point instruction or award from H2.

Failed, stale, missing, or mismatched candidates leave the prior committed snapshot unchanged and publish neither event. Load staging/import publishes neither event.

## Acceptance requirements and tests

- A source snapshot with 0, 1, 4, 399, 400, and more than 400 qualifying tiles produces Scale of 0, 0.25, 1, 99.75, 100, and 100 respectively; duplicate qualifications on one stable tile count once.
- Empty purchased/undeveloped tiles do not contribute; authoritative zone, tenant, and amenity development each contribute once per stable tile.
- Every valid candidate has Quality exactly 20 and Prestige exactly `scale_quarters * 5`; no factor, loan, or visitor value participates.
- A valid monthly candidate commits through H1 and resolves tier/rent/tenant eligibility exclusively through the existing H1 policy.
- A candidate with a stale developed-tile source revision, policy revision, calendar identity, malformed provenance, or invalid arithmetic is rejected without changing the official snapshot or emitting events.
- No candidate is produced before the first monthly boundary; no daily trend source, value, event, or persisted field exists.
- A tier change emits H1's existing typed events once and lets Progression perform only its approved idempotent milestone work; no H2 path creates, awards, spends, or persists Tech points.
- V2 round-trip preserves H1's committed numeric Prestige and calculation provenance, stages without events, and does not persist pending candidates, source snapshots, Quality factors, loan state, or trend.
- Debug previews remain non-authoritative under H1 and cannot overwrite, imitate, or be substituted for this official candidate.

## Later extension

A later approved calculation handoff may replace fixed baseline Quality with revisioned detached source contracts for the six designed factors and may define the loan-default multiplier, daily trend, history, visitor effects, and presentation. It must retain this handoff's H1 candidate/commit boundary, define each new source's revision and stale-candidate behavior, version persistence deliberately, and keep Tech points under Progression ownership. It must not silently reinterpret Quality 20 as any factor contribution or retroactively manufacture historical daily trends.

## Required implementation skills

Before implementation, load `resource-pattern`, `event-bus`, `dependency-injection`, `save-load`, `godot-testing`, and `gdscript-patterns`.
