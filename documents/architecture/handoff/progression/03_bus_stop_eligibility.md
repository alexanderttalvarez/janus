# Progression Handoff 03 — Bus-Stop Eligibility

**Status:** Approved — 2026-09-03

**Revision:** 2026-09-08 delegated consistency pass. Eligibility remains approved future policy; Current MVP disables its player-facing purchase while facility placement/operation is deferred. Element 08 corrects total arithmetic without changing this node's cost.
**Prepared:** 2026-09-03
**Implementation order:** 3 of 3 — after Progression H1–H2

## Purpose

Add Bus Stop as the sole approved first non-pedestrian transport capability to Progression snapshots. This handoff grants eligibility only; it does not create facilities, routes, arrivals, prices, fees, or transport simulation.

## Approved policy

| Capability | Tech cost | Tech prerequisite | Mall Level gate | Effect |
|---|---:|---|---|---|
| `transport.bus_stop` | 1 point | Basic Corridors | Small Market | Progression eligibility for a Bus Stop placement request. |

All other non-pedestrian transport capabilities remain explicitly unavailable.

## Scope

- Add stable `transport.bus_stop` node/capability to the Tech catalog and immutable Progression snapshot.
- Require both Basic Corridors and Small Market in normal play.
- Provide deterministic eligibility/rejection results to future facility-placement consumers.
- Preserve god-mode behavior: Bus Stop is immediately progression-eligible.

## Non-goals

- Bus Stop placement, Node/scene ownership, public-band occupancy, construction price, monthly fee, refunds, removal behavior, or save schema.
- Road/route validation, frontage, active-road state, cap enforcement, street-conversion effects, traffic graph, demand allocation, bus cohorts, visitor arrivals, schedules, or capacity.
- Tram, monorail, metro, train, parking, taxi, or any other transport capability.

## Boundaries

| Owner | Responsibility |
|---|---|
| Progression authority | Emits immutable eligibility for `transport.bus_stop`. |
| Future facility/public-realm owner (District H5 contract) | Validates active road/route, city-owned Pedestrian Band frontage, cap `ceil(Active Plot count / 3)`, placement/removal state, and persistence. |
| Economy | Future price/fee policy only; no transport charge is approved here. |
| Arrival Coordinator | Future source allocation/realization only; pedestrian arrivals remain MVP. |

A positive Progression result is necessary but never sufficient for placement. Missing H5/H7 road/route/public-band capabilities reject placement without Economy capture.

## Snapshot and debug contract

The revisioned Progression snapshot contains a stable boolean/capability result for `transport.bus_stop`, source Tech node ID, Mall Level validation, and diagnostic when unavailable. It never contains route IDs, facility positions, caps, price, or arrival state.

In non-release god mode, this capability is eligible regardless of Tech Points or Mall Level. God mode does not bypass future physical road, route, frontage, cap, ownership, revision, or atomicity validation.

## Acceptance requirements

- Normal eligibility requires Basic Corridors, the Bus Stop node, and Small Market.
- No other transport capability becomes eligible through this handoff.
- Snapshot changes are revisioned and stale snapshots reject before any future placement/economy transaction commits.
- God mode grants only the progression bypass; physical placement still rejects until its owning systems exist.
- The full listed catalogue, including this node, costs 26 of 40 points per element 08; 28/40 was an arithmetic error, not two unnamed nodes.

## Follow-up handoffs

A future transport/public-realm handoff must decide Bus Stop placement ownership, Economy price/fee, removal/refund, source state, arrival behavior, persistence, and the remaining transport catalog.
