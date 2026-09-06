# Decision 30: Production Manual-Door Authority

## Status

Approved — 2026-09-06  
Endpoint read ownership refined by [Decision 31](31_door_endpoint_semantics_views.md).

## Decision

Production manual grid doors are submitted through a narrow `ManualDoorAuthority` facade and committed by `DistrictRuntime`. `ManualDoorAuthority` is not an independent state owner: committed records live inside the H3 district snapshot. `ZoneManager` remains the sole zone/parcel writer and supplies only its ZoneManager-owned portion of prospective legality input. District-owned endpoint facts come from the H3 view defined by Decision 31.

## Contract

- Every endpoint uses H3's explicit `(runtime_plot_id, signed_elevation, local_cell)` address. Floor labels and omitted identity are invalid.
- Edges are canonical unordered pairs of same-floor cell addresses.
- Placement supports only Transit-to-explicit-CIRCULATION or Transit-to-Transit across two different zones. Same-zone and non-Transit connections reject.
- Preview and commit use the same immutable district, zone, and policy revisions. Stale revisions reject without state, save, or gameplay events.
- Endpoint legality consumes the paired owner-specific immutable views from Decision 31; it never reads a legacy grid mirror.
- A commit is represented as one H3 `SET_MANUAL_DOOR` transaction and one committed delta. Presentation/pathfinding refreshes only after that delta.
- Removal uses the same revision guard and is atomic.
- V2 persistence stores sorted manual-door records inside district authority; malformed, duplicate, unknown, or non-canonical records reject the envelope.
- The legacy `GridManager` door API remains archive-policy test-pack only and is not a production dependency.

## Consequences

The authority adds a deliberately small production command boundary while keeping H3's sole-writer and H5/H8 barrier contracts intact. Door collision, navigation, interaction, and tenant lifecycle remain outside this decision and are not implemented here.
