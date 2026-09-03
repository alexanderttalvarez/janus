# Handoff 02 — Immediate Debug Business Assignment

**Status:** Approved
**Approved:** 2026-08-22
**Implementation order:** 2 of 2 — after Handoff 01

## Purpose

Immediately assign a business subtype to every eligible parcel after a successful parcel split so parcel allocation can be debugged. An assignment is parcel metadata only; it is not a tenant application, tenant entity, or lifecycle transition.

## Dependencies

- [Handoff 01 — Deterministic Parcel Splitting](01_parcel_splitting.md) must be complete first.
- This handoff consumes only valid parcels from a successful Handoff 01 split result.

## Scope

- Define a debug subtype catalog for each zone type.
- Deterministically assign one legal subtype ID, or a diagnostic, to each valid parcel.
- Enforce type/size eligibility and no duplicate subtype across edge-adjacent parcels.
- Recompute debug assignments after each successful zone edit.
- Commit split geometry and assignment metadata together through `ZoneManager`.

## Explicit non-goals

- Tenant applications, time delays, construction, locks, operations, revenue, viability, closure, or eviction.
- `TenantData`, tenant IDs, tenant instances, or `TenantManager` lifecycle behavior.
- Interiors, doors, walls, signage, labels, tile numbers, UI, and notifications.
- Physical tenant-door creation or pathfinding changes.
- Random tenant selection, balancing, weighting, or final game-economy tuning.

## Data ownership

| Owner | Responsibility |
|---|---|
| `ZoneManager` | Owns assignment mode, invokes pure assignment after a successful split, atomically commits parcel metadata, and prevents normal tenant lifecycle handling in debug mode. |
| `ZoneBusinessAssigner` | Pure, stateless transform: valid parcels + zone type + immutable subtype catalog → assignments + diagnostics. It mutates no scene, grid, zone, or parcel. |
| Subtype catalog | Immutable design/content input. It owns subtype IDs, display names, permitted zone type, size limits, and canonical priority. |
| `Parcel` | Owns its `assigned_subtype_id` only. It does not acquire tenant identity or lifecycle state. |
| `TenantManager` | Not called, extended, or notified by this handoff. |

`ZoneData.subtype` is legacy zone-level data. Handoff 02 must not write it. `Parcel.assigned_subtype_id` is authoritative; retain the legacy field temporarily only for compatibility until a later cleanup/migration handoff.

## Assignment mode

`ZoneManager` owns an explicit `DEBUG_IMMEDIATE` assignment mode. It is the active mode for this handoff.

In this mode, successful split results are assigned immediately and no vacant-parcel trigger reaches `TenantManager`. A later lifecycle handoff may introduce an application-driven mode; it must not alter the debug-mode contract.

## Debug subtype catalog

The catalog uses the five documented subtype examples for each zone type. Subtype IDs are stable, lowercase identifiers. In MVP debug mode every subtype has the generic zone-type minimum and no maximum area.

| Zone type | Minimum tiles | Debug subtypes |
|---|---:|---|
| Retail | 6 | `retail.fashion` (Fashion), `retail.electronics` (Electronics), `retail.home_goods` (Home Goods), `retail.jewelry` (Jewelry), `retail.bookstore` (Bookstore) |
| Food & Beverage | 8 | `food.sushi_restaurant` (Sushi Restaurant), `food.italian_restaurant` (Italian Restaurant), `food.cafe` (Cafe), `food.mexican_restaurant` (Mexican Restaurant), `food.local_food` (Local Food) |
| Entertainment | 12 | `entertainment.cinema` (Cinema), `entertainment.arcade` (Arcade), `entertainment.bowling_alley` (Bowling Alley), `entertainment.escape_room` (Escape Room), `entertainment.vr_experience` (VR Experience) |
| Services | 5 | `services.bank` (Bank), `services.hair_salon` (Hair Salon), `services.repair_shop` (Repair Shop), `services.clinic` (Clinic), `services.travel_agency` (Travel Agency) |
| Anchor | 30 | `anchor.department_store` (Department Store), `anchor.supermarket` (Supermarket), `anchor.gym` (Gym), `anchor.food_court` (Food Court), `anchor.exhibition_hall` (Exhibition Hall) |

Catalog order in the table is the canonical `debug_priority`. This is only a deterministic tie-breaker, not a gameplay desirability or probability weight.

This debug catalog intentionally differs from final content: final subtype-specific minimum/maximum area requirements will be authored in a later content handoff.

## Eligibility and adjacency

A subtype is eligible for a parcel only when:

- it belongs to the parcel's zone type; and
- `min_tiles <= parcel.area <= max_tiles`, where debug catalog `max_tiles` is unbounded.

The adjacency graph is defined as:

```text
Vertex: valid parcel
Edge: two parcels share one or more orthogonal tile edges
Color: assigned subtype ID
```

Corner-only contact does not create an edge. Parcels connected by an edge cannot receive the same subtype.

## Deterministic graph-coloring assignment

The assigner performs constrained vertex graph coloring. “Color” means subtype ID, never a visual color.

1. Canonically sort parcels by stable parcel ID, then canonical bounds; canonically sort catalog entries by `debug_priority`, then subtype ID.
2. Build the parcel adjacency graph and each parcel's eligible subtype domain.
3. Select the next unassigned parcel using DSATUR-style ordering: greatest count of distinct neighbor subtypes already assigned; tie-break by greatest adjacency degree, then canonical parcel order.
4. From legal candidates not used by an edge-adjacent parcel, select the subtype with the lowest current use count; tie-break by `debug_priority`, then subtype ID. This creates varied debug assignments without randomness.
5. If greedy assignment finds no legal subtype, perform one deterministic repair/recolor pass over already assigned parcels. Consider legal alternative subtype assignments in canonical order and adopt the first change that frees a legal subtype without creating an adjacency conflict.
6. If no repair succeeds, leave only the affected parcel unassigned and return `NO_LEGAL_SUBTYPE`.
7. If a parcel's filtered domain is empty before coloring, leave it unassigned and return `NO_ELIGIBLE_SUBTYPE`.

The assigner never changes parcel geometry, typologies, grid state, or zone finalization status.

## Edit and commit behavior

1. Handoff 01 produces and validates the new split result.
2. `ZoneManager` passes all current valid parcels and the zone type to the pure assigner before committing runtime state.
3. `ZoneManager` atomically commits parcel geometry, persistent IDs, residual typology changes, subtype assignments, and diagnostics.
4. On every successful zone tile/typology edit, recompute assignments for the complete current parcel set. Existing debug subtype assignments are not preserved independently of this recomputation.
5. On a rejected split, no parcel subtype data or diagnostics from the attempted edit are committed.
6. Existing zone-created/modified events may occur only after the combined successful commit. This handoff adds no assignment or tenant EventBus events.

## Persistence boundary

`assigned_subtype_id` is persistent parcel state and must be serialized with the stable parcel ID and geometry. Restoration order is: parcel geometry and IDs, then subtype metadata.

This handoff defines the ownership and persistence contract. The actual save-file schema, migration, and SaveManager integration remain a dedicated later handoff; until that work is complete, debug assignments are not guaranteed to survive a save/load round trip.

## Failure behavior

| Condition | Behavior |
|---|---|
| No eligible subtype by zone type/size | Keep valid geometry; leave the parcel unassigned with `NO_ELIGIBLE_SUBTYPE`. |
| Eligible subtypes all conflict with assigned neighbors | Keep valid geometry; leave the parcel unassigned with `NO_LEGAL_SUBTYPE`. |
| Invalid/rejected split | Handoff 01 blocks finalization; this handoff receives no parcel set and commits nothing. |

Assignment failure never forces a wrong-size subtype, duplicate edge-adjacent subtype, or geometry rollback.

## Acceptance requirements

- Every assigned subtype matches the parcel zone type and inclusive size policy.
- Reordering tiles, parcel input, dictionary insertion, or catalog insertion produces the same assignments and diagnostics.
- Edge-adjacent parcels never share a subtype; diagonal-only parcels may.
- The balanced deterministic policy uses the least-used legal subtype before priority tie-breaks.
- A no-eligible or no-legal parcel is the only unassigned parcel affected; valid neighboring assignments remain valid.
- A successful edit recalculates assignments only for the resulting valid parcels and clears retired parcel metadata.
- Assignment creates no `TenantData`, tenant ID, tenant lifecycle state, `TenantManager` activity, tenant event, label, or interior.
- The combined split-and-assignment commit never exposes partially updated parcel metadata.

## Implementation guidance

Replace the current order-dependent, mutating assigner with the pure result-producing contract above. Keep catalog loading/content ownership outside the pure assigner; pass it an immutable snapshot/value input.

Required implementation skills: `godot-prompter:resource-pattern` for catalog/data boundaries and `godot-prompter:godot-testing` for deterministic graph-coloring tests. Do not load or use tenant-lifecycle skills for this debug-only handoff.
