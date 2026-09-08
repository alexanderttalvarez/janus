# Visitor Handoff 01 — Service Proxy and Operational Metrics

**Status:** Approved — 2026-09-05 (delegated architecture authority)

**Revision:** 2026-09-08 delegated consistency pass. This is the technical Corridor Service Integration Gate, not Product release. [Element 05](../../../game_design/elements/05_visitor_simulation.md) now owns the explicit foundation-only admission/duration/retry baseline; Session compiles the immutable policy, Tenant supplies Open eligibility, Zone supplies the legal proxy and Visitor alone derives acceptance from its participation. This resolves the unspecified "provided acceptance fact" below without a new service manager. ADR 33 applies; draft `tenant_interiors/H4-H5` do not yet replace this live path.

**Follow-on review, 2026-09-08:** The preceding draft boundary records the earlier consistency pass. [ADR 34](../../decisions/34_product_mvp_runtime_and_cutover.md) separately architecture-approves interior H4/H5. Foundation -> detached interior H1-H3 -> H4 implementation passes -> H5 candidate cutover passes -> Product acceptance; external Gate R is separate. The live proxy path changes only after those implementation/cutover gates pass, not on documentation approval. Implementation/cutover remain NOT VERIFIED; Product acceptance/Gate R remain PENDING.

## Purpose

Define the smallest operational visitor behavior after H8 realizes a pedestrian visitor: select a reachable parcel-door proxy from public corridors, navigate and recover from invalid routes, use a simple bounded proxy queue, record a non-economic outcome, and leave through an H8-eligible pedestrian source.

MVP visitors never enter tenant interiors. A parcel door is a public-corridor interaction proxy, not proof that an interior, fixture, cashier, seating area, or tenant-specific service simulation exists.

## Authoritative sources

- [District Handoff 08 — Visitor Arrival MVP Migration](../district_layout/08_visitor_arrival_mvp_migration.md)
- [Decision 28 — Visitor Demand and Arrival Architecture](../../decisions/28_visitor_arrival_architecture.md)
- [Decision 3 — Visitor Agents](../../decisions/03_visitor_agents.md)
- [Tenant Handoff Index](../tenant/_index.md)
- [Future Tenant Architecture Topics](../tenant/_future_topics.md)
- [Visitor Simulation design](../../../game_design/elements/05_visitor_simulation.md)
- [Metrics and Data Visualization design](../../../game_design/elements/07_metrics_data_visualization.md)

## Scope

- Public-corridor to parcel-door proxy discovery and immutable target snapshots.
- Deterministic target selection from currently reachable proxies.
- Path request, stale-path invalidation, bounded repath, cancellation, and exit behavior.
- One simple proxy capacity/queue policy with no tenant-interior simulation.
- Non-economic purchase-result ownership and post-commit events.
- Read-only operational metrics snapshots: current visitors, daily arrivals, and daily average arrivals.

## Explicit non-goals

- Tenant interiors, furnishings, interior navigation, service points, or entering a tenant parcel.
- Revenue, rent collection, tenant viability, tenant quality, visitor satisfaction, Prestige, attraction, or demand formulas.
- New gameplay values, prices, durations, probabilities, queue limits, budgets, patience values, or scoring formulas.
- Transport modes, pending cohorts, source capacity/weight/fairness, or changes to H8 allocation.
- UI layout, localized copy, heatmaps, notifications, or presentation ownership.

## H8 and tenant reconciliation

H8 owns arrival allocation and its immediate commit. Once that commit has produced a realized visitor, `VisitorManager` owns the visitor's behavior record, transient Node representation, active-population lifecycle, and the global cap of **200 active visitors**. A visitor remains active, and therefore counts against that cap, while walking, queued, cancelled, or leaving; removal occurs only after the selected H8 exit source is reached.

Tenant authority remains unchanged. TenantManager owns tenant identity and occupancy; ZoneManager owns parcel and door geometry. They expose only a revisioned, read-only service-proxy snapshot. Visitor behavior cannot infer a proxy from a Node, coordinate, parcel shape, or tenant scene hierarchy, and it cannot mutate tenant occupancy or lifecycle.

This handoff is deliberately compatible with the deferred tenant-interior topic: a future tenant-service authority may replace the proxy service policy behind the same stable proxy identity only through a new approved handoff. It must not treat the MVP proxy queue or purchase result as an interior layout, revenue ledger, or capacity model.

## Ownership and boundaries

| Owner | Owns | Must not own |
|---|---|---|
| `VisitorManager` (MVP visitor behavior service) | Realized visitor records, target/route/queue participation state, cancellation and exit intent, active-population cap, operational metrics state, and visitor-side result history. | Demand formulas, arrival-source state writes, parcel geometry, tenant lifecycle, revenue, viability, Prestige, or UI. |
| District Runtime / H8 Arrival Coordinator | Arrival-source state, source eligibility validation, source selection, realization transaction, and exit-source validation. | Visitor goals/routes/queues, tenant service policy, or metrics aggregation. |
| ZoneManager / projection | Stable parcel and parcel-door identity, public-corridor attachment, and topology revisions. | Visitor state, queues, purchases, or tenant lifecycle. |
| TenantManager | Tenant identity/occupancy facts and publication of eligible tenant-facing proxy facts. | Visitor movement, queue records, arrival allocation, revenue inferred from an MVP result, or direct visitor mutation. |
| Future tenant-service authority | Interior/service policy, authoritative service capacity, and any tenant-side business outcome approved later. | Retroactively reinterpreting MVP proxy events as revenue or Prestige without a new contract. |
| TimeManager | Authoritative simulation-day identity/boundary. | Visitor counts, averages, or visitor lifecycle mutation. |
| SaveManager | Whole-session atomic save/load orchestration. | Repairing, recomputing, or fabricating visitor/metric facts. |
| UI/EventBus | Projection of committed snapshots/events. | Authoritative state writes or queue decisions. |

## Stable data contracts

### Parcel-door service proxy snapshot

Each candidate is identified by a stable `parcel_door_proxy_id`, with stable tenant ID, parcel ID, door ID, and public-corridor navigation anchor ID. The immutable snapshot also carries:

- tenant occupancy/activity eligibility as published by TenantManager;
- public-corridor reachability attachment as published from committed Zone/District topology;
- proxy policy revision and all referenced topology/tenant revisions; and
- only the approved MVP queue-policy facts necessary to determine whether the proxy can accept a visitor.

It excludes interior geometry, Node references, door transforms as identity, revenue, prices, staffing, tenant performance, and inferred capacity. A missing, stale, disabled, unoccupied, or unreachable proxy is not a candidate.

### Visitor target and route state

A visitor stores stable target proxy ID, captured proxy/topology revisions, route request identity, and behavior state. Route geometry, navigation paths, temporary steering, and Node references are derived/transient and are never stable identity.

MVP may select only a proxy reachable entirely through the committed public pedestrian corridor graph. It may stop at the proxy's public-side interaction anchor, but may not route across a tenant parcel or into an interior.

### Purchase result boundary

`VisitorManager` is the sole writer of a visitor-side `purchase_result` after a proxy interaction completes. The result is immutable and contains stable visitor ID, proxy/tenant/parcel-door IDs, result kind, committed simulation-day identity, and referenced proxy-policy revision. It represents only the visitor's completed or failed proxy interaction and any visitor-goal progress that this MVP behavior owns.

The result has no amount, price, inventory, revenue, rent, viability, satisfaction, Prestige, or demand effect. It does not authorize TenantManager, Economy, or Prestige to mutate from the event. Any tenant-side service completion, sales ledger, revenue recognition, or cross-system consequence requires a future approved tenant-service/economics handoff with its own commit boundary.

### Operational metrics snapshot

`VisitorManager` publishes one detached, revisioned snapshot containing exactly:

- `current_visitors`: committed active visitor count, including leaving visitors until physical removal;
- `daily_arrivals`: arrivals committed by H8 during the current authoritative simulation day;
- `daily_average_arrivals`: arithmetic mean of finalized daily-arrival totals for completed observed simulation days in the current session; and
- current simulation-day identity, metric revision, and the aggregate/count provenance needed to restore the average exactly.

The daily average is an operational observation, not a demand input, balance input, tenant-performance value, or Prestige factor. No default, target, threshold, or gameplay consequence is introduced. During the first incomplete day, the average has explicit unavailable/presence semantics rather than a fabricated value.

## Behavior and event flow

1. H8 commits `arrival_realized`; VisitorManager creates the realized visitor and increments `current_visitors` and current-day `daily_arrivals` in the same visitor-side committed update.
2. On a behavior decision, VisitorManager captures one proxy/topology snapshot and filters to eligible public-corridor candidates reachable from the visitor's current corridor anchor.
3. It applies a deterministic ordering by NFC-normalized UTF-8 bytes of `parcel_door_proxy_id` and selects the first candidate. This is a tie-break only: it is not attractiveness, pricing, preference, weighting, fairness, or a new gameplay formula.
4. VisitorManager requests a public-corridor route to the selected proxy anchor. If the path cannot be produced, the selected target is cancelled without a result and the next behavior decision may choose from a fresh snapshot.
5. Before entering the proxy queue and before completing the interaction, VisitorManager revalidates the proxy and captured topology revisions. A stale, disabled, removed, or unreachable target cancels queue participation and target state without producing a purchase result.
6. Visitor evaluates the compiled element-05 foundation policy against committed Open/door/topology facts and its own participation. The single-entry FIFO accepts only when unoccupied. Full/invalid targets are excluded for that visit; no reservation is created, and bounded retry follows the explicit policy.
7. At the public-side proxy anchor, VisitorManager removes the queue participation and commits exactly one visitor-side purchase result for the completed interaction. It then publishes the result after commit. Consumer faults are diagnostics and cannot roll back visitor state.
8. When no valid target remains, cancellation policy ends the visit, or the visitor otherwise receives a leaving intent, VisitorManager asks H8 to validate/select an eligible exit source. It routes over public corridors, revalidates/repaths as required, and removes the visitor only after reaching that source.

No queue reservation, target, or route may survive a cancellation, stale revision, failed route request, physical removal, or load boundary.

## Pathing, repath, and cancellation rules

- Every route request is tied to the visitor ID, target or exit stable ID, and captured public-topology revision.
- A route is invalid when its target/proxy becomes ineligible, its topology revision changes, navigation cannot supply a path, or the visitor's behavior state changes. Invalid routes are discarded, never followed optimistically.
- Repath uses a fresh eligible snapshot and must preserve the public-corridor-only constraint. It must not fall back to nearest coordinates, an arbitrary Node, tenant interiors, or an obsolete route.
- Repath attempts are bounded by an implementation safety policy. The bound is not a new gameplay value and must be observable in diagnostics/tests; exhaustion cancels the target and proceeds to the normal next decision or exit path.
- Cancellation is idempotent: it clears target, route, and queue participation exactly once and does not create a purchase result.
- If an exit becomes invalid, the visitor remains active, waits or retries under H8's canonical eligible-exit contract, and is never removed at a non-source coordinate.

## Queue and capacity policy

The foundation proxy uses element 05's explicit single-entry FIFO and next-tick completion, followed by Leaving. Session owns immutable policy selection/validation; Visitor owns the revisioned acceptance projection from its committed participation plus Tenant/Zone facts. No parcel-area inference, staff throughput, interior capacity, patience or fairness simulation is introduced. Its historical non-goal of inventing values is satisfied by the now-approved design baseline, not a missing policy provider.

Only VisitorManager writes queue participation. A queue entry is transient, single-visitor, and valid only while the associated proxy snapshot remains valid. A later tenant-service handoff may replace the policy with service-specific capacity and reservation authority; doing so must preserve stable proxy identity or explicitly migrate it.

## Persistence and load

Persist only committed visitor records necessary to restore H8-realized active visitors, visitor-side completed purchase-result history if that history is retained, current-day arrival count/day identity, finalized-day aggregate/count used for the average, and visitor/metric schema and revisions.

Do not persist routes, navigation paths, Node references, target selections, queue entries, proxy snapshots, transient path failures, repath counters, source geometry, commit gates, or in-flight interactions. On load, VisitorManager restores committed visitors and metrics through SaveManager's atomic orchestration, clears all transient behavior state, then reacquires targets/routes from current snapshots. No purchase event, arrival event, or metrics-change event is replayed while staging.

## Events and presentation

- H8's committed `arrival_realized` remains the only arrival fact consumed for daily-arrival counting.
- VisitorManager may publish typed post-commit `visitor_purchase_result_committed` and `visitor_metrics_snapshot_changed` events with detached payloads.
- Events are notifications of committed facts, not commands; EventBus/UI listeners cannot alter queue state, purchase results, cap state, or metrics.
- Presentation owns movement visuals, animations, bubbles, and metric display. It may not use visual arrival, fade completion, or Node visibility as a metrics source.

## Acceptance requirements

- Every MVP tenant interaction occurs at a stable parcel-door proxy from a public corridor; no visitor path enters a tenant interior.
- Target selection uses only one captured eligible snapshot and deterministic proxy-ID ordering; it does not introduce unapproved preference, value, weighting, or gameplay formulas.
- Stale/invalid/unreachable targets and routes clear transient state safely, cannot create a result, and never use coordinate or Node fallback.
- Queue participation is FIFO, transient, owned only by VisitorManager, and cannot outlive target validity, cancellation, visitor removal, or load.
- A completed proxy interaction produces exactly one immutable visitor-side result; it produces no revenue, rent, viability, satisfaction, Prestige, or demand mutation.
- H8 remains the authority for arrival and exit sources, and VisitorManager never exceeds 200 active visitors. Leaving visitors count until they physically reach a valid selected exit source and are removed.
- `current_visitors`, `daily_arrivals`, and `daily_average_arrivals` are derived only from committed visitor/H8 facts, restore exactly from persisted metric provenance, and do not use visual state or fabricated defaults.
- No save contains routes, queues, target selections, proxy geometry, Node references, or in-flight interaction work; load does not replay business events.

## Required tests

- Corridor-only target filtering, stable-ID identity, deterministic canonical target ordering, and rejection of tenant-interior/Node/coordinate fallbacks.
- Route success, topology invalidation, target removal, failed path, bounded repath, cancellation idempotence, and H8 exit revalidation.
- FIFO admission, full/unavailable rejection, queue cleanup on every cancellation/removal/load path, and proof that no unapproved capacity value is derived or added.
- Exactly-once visitor-side purchase-result commit/event and proof that Economy, Tenant revenue/viability, Prestige, and demand receive no mutation.
- Active-cap enforcement at 200 across arrival, queue, leaving, invalid-exit retry, and physical removal transitions.
- Metrics count only committed arrivals; day rollover/finalization, first-day unavailable average, persistence round trip, load non-replay, and no Node/presentation dependency.

## Risks and follow-up

| Risk | Mitigation |
|---|---|
| Proxy behavior is mistaken for a tenant interior model. | Keep interaction anchors public-side and exclude interior geometry/fixtures from the contract. |
| An MVP result is consumed as money or Prestige. | Result payload excludes economic/quality values; no downstream authority is authorized to mutate from it. |
| Navigation mutations leave visitors stuck or queues leaked. | Revision-bound paths, idempotent cancellation, bounded repath, and exit retry preserve lifecycle safety. |
| Proxy capacity becomes an accidental balance decision. | Use only published acceptance facts; require a later approved tenant-service handoff for capacity/throughput policy. |
| Metrics drift from actual population. | Count only committed H8 arrivals and VisitorManager physical removals; persist aggregate provenance, never visual samples. |

Future handoffs must decide tenant interiors and furnishing, subtype-specific service points, authoritative service capacity/queues, service duration, visitor goals/budgets/satisfaction, tenant revenue, viability, Prestige/attraction inputs, and any transport or demand policy. None is approved by this handoff.
