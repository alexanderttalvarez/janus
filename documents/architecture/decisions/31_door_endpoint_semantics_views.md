# Decision 31: Door Endpoint Semantics Views

**Date:** 2026-09-06  
**Status:** Accepted — refines Decision 30 without changing authority ownership.

**Current applicability, 2026-09-10:** [ADR 36](36_district_zone_spatial_snapshot_and_zone_mutation.md) generalizes the District endpoint view into a floor-scoped batch value for Zone transactions. The single-endpoint semantics and owner split here remain authoritative; the batch snapshot creates no parallel authority or generalized spatial service. Implementation and evidence are not asserted.

## Context

Decision 30 places manual-door records in H3 `DistrictState`, committed only by `DistrictRuntime`, while `ZoneManager` remains the sole zone/parcel writer. Door legality requires facts currently read from legacy `GridManager`: endpoint zone identity, typology, explicit circulation, and floor/cell validity. H10 forbids that production dependency.

A single `ZoneManager` endpoint model containing all of those facts would remove `GridManager`, but it would duplicate or transfer district-owned facts into the zone authority. In particular, resolved cell validity and constructed explicit circulation belong to the resolved district/H3 construction state, not to `ZoneManager`.

## Decision

Approve a narrow endpoint-semantics boundary, but split it by authoritative owner. `ManualDoorAuthority` composes the two immutable snapshots transiently for validation.

### Canonical address

Both views are keyed by the H3 explicit cell address:

`FloorCellAddress = (runtime_plot_id, signed_elevation, local_cell)`

`local_cell` is the plot-local integer coordinate. Floor labels, omitted plot/floor values, world positions, Node paths, and implicit defaults are invalid. If an implementation exposes a stable resolved `floor_id`, it must resolve to this exact plot/elevation scope and must not replace signed elevation at authority boundaries.

### District endpoint view

**Owner:** `DistrictRuntime`, sourced from the immutable H2 resolved snapshot plus the captured H3 state/candidate.

It exposes only facts required for door validation:

- whether the plot, elevation, and local cell resolve;
- whether required floor space is acquired and constructed;
- whether the endpoint is explicit constructed circulation under H3 construction state; and
- the captured district revision.

It does not expose zone identity, typology, manual-door mutation methods, Nodes, transforms, or legacy grid objects.

### Zone endpoint view

**Owner:** `ZoneManager`, sourced from committed or prospective immutable zone state.

It exposes only:

- optional stable zone identity at the endpoint;
- endpoint typology when zoned;
- whether the endpoint belongs to the prospective mutation scope; and
- the captured zone revision.

It does not determine floor/cell validity, ownership, acquisition, construction, or explicit circulation. It contains no `GridTile`, `FloorGrid`, or `GridManager` reference.

### Composite door context

`ManualDoorAuthority` combines matching district and zone endpoint values into a short-lived immutable validation context. This composite is derived, unsaved, and owns no state. It carries both revisions and cannot be cached across a commit.

The legality evaluator consumes two canonical endpoint contexts and applies Decision 30/Handoff 05 rules. It must fail closed when either view is missing, either endpoint is unresolved, required acquired/constructed state is absent, revisions do not match the requested preview/commit, or the pair was assembled from different candidate scopes.

## Preview and commit flow

```text
canonical endpoint pair
  -> capture district state/candidate + district revision
  -> capture zone state/candidate + zone revision
  -> derive both owner-specific endpoint views
  -> compose immutable door context
  -> pure legality result
  -> H3 transaction revision revalidation
  -> DistrictRuntime commits SET_MANUAL_DOOR
  -> one committed delta
```

Manual-door placement/removal uses committed snapshots for preview and defensively revalidates both revisions under the H3 transaction gate for commit. A zone paint/merge/remove plan uses its detached prospective ZoneManager candidate together with the corresponding detached H3 district candidate; it must not query live state or legacy mirrors during prospective validation.

## Ownership consequences

- `DistrictRuntime` remains the sole writer of manual-door records and district construction/circulation state.
- `ZoneManager` remains the sole writer of zone identity, typology, parcels, and automatic parcel-door selections.
- `ManualDoorAuthority` owns command orchestration and pure legality composition only.
- H5 consumes committed door/circulation values when deriving `PedestrianGraphSnapshot`; it does not become a door or zone authority.
- `GridManager`, `GridTile`, and `FloorGrid` remain Archive-Policy-B test-pack-only.

## Why this is preferable to one ZoneManager read model

The proposed single read model is directionally correct but over-broad. Splitting the views:

- preserves one authoritative owner per fact;
- prevents ZoneManager from becoming a replacement grid service;
- supports prospective cross-authority validation without live mutable reads;
- makes stale-revision failures explicit; and
- allows reuse by automatic-door preservation and zone mutation without exposing unrelated state.

A generalized spatial query service or new autoload is rejected as premature. The composite exists only at the manual-door validation boundary.

## Persistence

Neither endpoint view nor the composite context is persisted. H9 persists sorted manual-door records in district authority and zone/parcel state under its existing owner. Explicit circulation is reconstructed from H3 state; zone semantics are reconstructed from ZoneManager state.

## Acceptance requirements

- Manual placement and removal produce identical legality from preview and commit snapshots.
- Zone paint/merge/remove validates existing manual doors against paired prospective H3/ZoneManager candidates.
- Transit-to-explicit-circulation and different-zone Transit-to-Transit cases follow Decision 30 exactly; same-zone, non-Transit, unresolved, unacquired, or unconstructed endpoints reject.
- Missing/mixed/stale revisions reject without district, zone, save, projection, path, wall, or event mutation.
- Production dependency and export audits show no `GridManager`, `GridTile`, or `FloorGrid` reachability.
- Endpoint views are immutable values, contain no Node references, and are discarded after validation.

## FACTS

- Zone identity and typology are ZoneManager-owned facts.
- Resolved validity, acquisition/construction, and explicit constructed circulation are district-owned facts.
- Manual-door records are DistrictRuntime-owned under Decision 30.

## ASSUMPTIONS

- H3 construction records can distinguish explicit constructed circulation from merely unzoned or walkable space.

## OPEN QUESTIONS

- None. If H3 cannot represent explicit circulation distinctly, that is an H3 state-schema defect to correct; it must not be compensated for by a ZoneManager or GridManager mirror.
