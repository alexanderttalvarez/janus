# Decision 28: Visitor Demand and Arrival Architecture

**Date:** 2026-08-30
**Status:** Accepted

**Current applicability:** [ADR 33](33_documentation_consistency_and_minimum_contracts.md), 2026-09-08, defines the common commit gate and staged interior boundary. Immediate pedestrian allocation is current; pending transport cohorts remain unavailable and need no persistence implementation now.

## Context

Decision 3 defines visible visitor agents and the existing runtime spawns them from four plot-corner anchors. District layouts introduce resolved streets, pedestrian bands, multiple Active Plots, and future transport modes. Visitor demand must remain independent from the selection and presentation of physical arrival sources.

## Decision

Visitor demand, arrival allocation, and arrival realization are separate responsibilities.

```text
demand policy
  -> arrival allocation against eligible source contracts
  -> pending arrival/cohort state
  -> visitor realization and presentation
```

### Demand

Demand determines how many visitors want to arrive and with what gameplay attributes. It does not choose scene nodes, spawn coordinates, transport presentation, or route geometry.

### Arrival source contract

Every arrival mode conforms to one contract identified by stable IDs. A source exposes:

- source ID and mode;
- district/topology anchor IDs;
- enabled and eligibility state;
- capacity or allocation limits;
- realization policy; and
- presentation metadata needed by downstream spatial consumers.

Supported contract modes are pedestrian, future bus, parking, taxi, and metro. Pedestrian is the only MVP mode. Future modes must extend this contract rather than add mode-specific demand ownership.

`ArrivalSourceState` stores mutable source state. Physical coordinates and route attachment are resolved from district topology and are not authoritative save data.

### Pedestrian MVP

- Pedestrian sources are derived from resolved public pedestrian topology and access to Active Plots.
- Allocation chooses eligible source IDs; realization requests resolved positions from spatial consumers.
- Decision 3 continues to govern visible visitor representation, centralized behavioral ticks, and culling after realization.
- The four hard-coded plot-corner spawn points are legacy behavior and are superseded as the target arrival model.

### Future bus presentation

- Buses are event presentation with pending cohorts, not continuously simulated off-district vehicles.
- A bus event allocates a cohort to an eligible source, presents an arrival, and realizes cohort members according to source capacity and timing.
- The number of bus stops is capped at `ceil(number of Active Plots / 3)`.
- Buses use the common road topology; there are no bus-only lanes.

### Ownership and communication

| Owner | Responsibility |
|---|---|
| Demand authority | Produces arrival demand independent of transport mode and spatial realization. |
| Arrival authority | Governs source eligibility, capacity allocation, pending arrivals/cohorts, and stable source selection. |
| District runtime | Stores authoritative district/source state and exposes resolved topology by stable ID. |
| Traffic topology | Derives the road graph and mode-compatible route attachments from the resolved district. |
| Visitor authority | Realizes allocated people into visitor data and applies Decision 3 lifecycle rules. |
| Presentation | Creates transient buses, cars, pedestrians, and effects from committed state/events; it owns no demand or arrival truth. |

Communication crosses these boundaries through stable IDs, immutable snapshots, transaction results, and committed events. No authority stores scene-node references as identity.

Ambient cars are presentation-focused. They may visualize generated road topology but do not become an authoritative off-district traffic simulation.

## Persistence

Saves include stable arrival-source mutable state needed for deterministic restoration. Resolved source geometry and road topology are derived from the saved layout identity and runtime district state.

The policy for saving, cancelling, replaying, or re-allocating pending arrivals and bus cohorts is open and must be decided before those pending states ship.

## Consequences

- Decision 3 is amended: its visitor-agent representation remains accepted, while its plot-corner spawning details are superseded by this arrival contract.
- Decision 8's plot-owned corner spawn points are superseded as the target architecture.
- Visitor balancing can change without changing district source realization, and new transport modes can be added without taking ownership of demand.

## Open Questions

- Pending-arrival save/load policy.
- Demand formulas, arrival weighting, capacities, schedules, and failure/retry policy.
- Exact progression gates, prices, and operating costs for non-pedestrian sources.
- Whether parking, taxi, metro, and bus source state needs separate policy modules once their complexity is known.
