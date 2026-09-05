# Presentation Handoff 01 — MVP Read Models, Intent Gateway, and Notifications

**Status:** Approved — 2026-09-05 (delegated architecture authority)

**Prepared:** 2026-09-05

**Implementation order:** 1 of 1 MVP presentation handoff

## Purpose

Define the smallest useful player-facing architecture without creating a second simulation model. The existing UI decision remains intact: `game_ui.tscn` is instanced by `main_game.tscn`, uses HUD, Toolbar, Panel, Notification, and Overlay CanvasLayers, and `PanelManager` manages panel lifecycle. This handoff replaces direct mutable-manager UI access with stable read models and a single intent gateway.

The MVP communicates committed district state, lets the player request approved actions, shows rejected-action diagnostics immediately, and routes committed conditions to transient toasts and a durable in-session log. UI never writes an authority field, executes a transaction, resolves a gameplay condition, or persists as game state.

## Authoritative sources

- [Decision 14 — UI Architecture](../../decisions/14_ui_architecture.md)
- [Decision 17 — Notification System Architecture](../../decisions/17_notification_system_architecture.md)
- [Decision 5 — Heatmap Implementation](../../decisions/05_heatmap_implementation.md)
- [UI / HUD System](../../../game_design/elements/17_ui_hud_system.md)
- [Metrics & Data Visualization](../../../game_design/elements/07_metrics_data_visualization.md)
- [Notifications System](../../../game_design/elements/18_notifications_system.md)
- [Economy Handoff 01 — Transaction Authority and Policy Boundary](../economy/01_transaction_authority_and_policy_boundary.md)
- [Tenant Handoff 02 — Rent Policy and Application Evaluation](../tenant/02_rent_policy_and_application_evaluation.md)
- [District Handoff 09 — Save/Load V2 and District Persistence](../district_layout/09_save_load_v2.md)

## Scope

- A presentation coordinator that projects committed authority snapshots/events into detached UI read models.
- A single UI intent gateway that routes typed player requests to owning authorities and returns structured results.
- A universal preview-versus-confirm contract for actions with prospective effects.
- Stable diagnostics rendered as immediate feedback, disabled controls, and source-unavailable state.
- Canonical MVP HUD metrics and source-gated Finances, Tenants, Visitors, Prestige, and Metrics panels.
- Visitor Density and Zone Viability heatmaps only when their respective authoritative source contracts exist.
- A notification adapter, toast queue state, notification-log state, and red-dot projection.
- In-session presentation persistence rules and deterministic acceptance/testing requirements.

## Explicit non-goals

- Changing authority ownership, event ordering, transaction protocols, save-envelope ownership, or simulation formulas.
- Implementing a generic UI state store that duplicates authority state.
- New financial reports, loan controls, tenant performance/viability, visitor satisfaction, historical graphs, contextual world indicators, localization, sounds, preferences, or accessibility settings.
- Rendering any panel field, chart, or heatmap from guessed, sampled, Node-derived, or stale data.
- Creating new notification conditions. Authorities define committed conditions and their resolution facts; presentation only adapts them.
- Restoring the design's simultaneous five informational panels. The MVP uses a smaller panel policy below.

## MVP decisions

### Panel count reconciliation

Decision 14 limits `PanelManager` to three simultaneous panels. The game-design MVP names five informational panels. To avoid both a cluttered world view and premature panel infrastructure, this handoff approves:

- exactly one **primary detail panel** at a time: Finances, Prestige, Tenants, Visitors, or Metrics;
- one optional **pinned HUD summary drawer** at a time, containing only canonical HUD metrics and no duplicate full-panel content;
- the notification log may open as a modal panel and temporarily replaces, rather than stacks with, the primary detail panel;
- opening a different primary panel replaces the current primary panel; Escape/X/outside-click follows the existing close behavior.

This is a stricter MVP use of the existing maximum-three capability, not a change to its scene structure. Tech Tree, Staff, advanced dashboards, and concurrent detail-panel comparison remain post-MVP.

### Presentation data freshness

Each read-model section carries `source_revision`, `generated_at` or authoritative calendar identity where provided, and `availability`:

- `AVAILABLE`: all required committed source snapshots match their declared revision contract.
- `UNAVAILABLE`: a required source is absent, incompatible, or deliberately not implemented.
- `STALE`: an expected revision no longer matches while an intent/preview/result is being displayed.

Only `AVAILABLE` values may be rendered as current metrics. `UNAVAILABLE` and `STALE` render a compact unavailable state with the stable diagnostic code; they do not display a retained prior value as current.

## Ownership and dependency direction

| Owner | Owns | Must not own |
|---|---|---|
| Named gameplay authority (`EconomyManager`, `ZoneManager`, `TenantManager`, `PrestigeManager`, `VisitorManager`, `TimeManager`, District Runtime, and future authorities) | Committed state, detached snapshots, validation, action preview/commit semantics, stable diagnostics, conditions, persistence, and post-commit events. | UI state, panel lifecycle, toasts, notification-log presentation, localized copy. |
| `PresentationCoordinator` | Snapshot subscriptions, read-model assembly, freshness/availability projection, source routing registry, and post-commit UI refresh scheduling. | Mutable gameplay facts, source fallback values, transaction coordination, save orchestration. |
| `UIIntentGateway` | Typed UI request correlation, preview/confirm routing, in-flight display state, result-to-diagnostic routing, and input de-duplication. | Validating business rules independently, writing authority fields, capturing Economy tokens, committing actions. |
| `PanelManager` | Existing panel lifecycle and this handoff's one-primary/one-summary/modal-log policy. | Data ownership, action validation, notification resolution. |
| HUD, panels, toolbar, overlays | Render detached read models and emit typed user intents. | Direct manager mutation or cross-authority reads. |
| `NotificationAdapter` | Conversion of committed conditions/results into presentation entries; toast queue, in-session log, read state, filtering, red-dot projection. | Deciding whether a gameplay condition is resolved, mutating its source, persistence of authority conditions. |
| `SaveManager` | V2 authority persistence and whole-session atomicity. | Persisting presentation queue, panels, filters, or read state. |

```text
committed authority snapshot/event
  -> PresentationCoordinator read model
  -> HUD / panel / heatmap / NotificationAdapter

player input
  -> UIIntentGateway
  -> owner preview or confirm port
  -> owner result / committed event
  -> PresentationCoordinator + NotificationAdapter
```

`EventBus` may carry a projection of a committed event for existing UI wiring, but it is not an authority API and must not be used to mutate or infer committed state. On panel open and after a dropped/reconnected projection, `PresentationCoordinator` refreshes from the owning authority's detached snapshot.

## Authority snapshots and read models

An authority exposes a detached, immutable snapshot with stable identity and revision. No read model may retain a live Node, manager reference, Callable, reservation token, or mutable collection from a source authority.

`PresentationCoordinator` may combine snapshots only into purpose-specific read models. A combined model records every source identity/revision and is `AVAILABLE` only when the named source contract says those revisions are mutually valid. It may format values and select display labels, but may not calculate gameplay values, update a history series, or backfill an absent metric.

### Canonical HUD model

The always-visible HUD has exactly these canonical metrics:

| HUD metric | Owner/source | MVP display rule |
|---|---|---|
| Money | Economy committed snapshot | Current committed balance only. Reservations, quotes, and predicted deltas are excluded. |
| Current visitors | Visitor committed lifecycle snapshot | Live active population currently realized in the district. |
| Daily arrivals | Visitor committed daily-boundary snapshot | Arrivals realized since the current authoritative simulation-day boundary. |
| Prestige | Prestige official snapshot | Official score and supported tier only. Debug-preview prestige is never HUD data. |
| Simulation speed | Time authority | Current committed/effective pause, 1x, 2x, or 3x state. |
| Clock/season | Time authority | Current authoritative time/calendar presentation facts. |
| Wall mode | Wall/view presentation owner | Current presentation mode only; it is not gameplay authority. |

If a source does not yet provide the named snapshot, its HUD slot is omitted rather than replaced with `0`, `N/A` as a numeric value, or a local approximation. The HUD must remain compact; no secondary metrics or trends are added in MVP.

### Basic panels

The five primary panels are source-gated, with no requirement that all exist at first playable MVP:

| Panel | Render only when sources provide | MVP contents |
|---|---|---|
| Finances | Economy committed snapshot plus an approved report snapshot | Balance and committed result summary. Revenue/expense/loan breakdown is hidden until a report source exists. |
| Prestige | Official Prestige snapshot | Official score and tier. Factor breakdown and history are hidden until authoritative sources publish them. |
| Tenants | Tenant/Zone detached occupancy snapshot | Occupancy and active tenant list facts available from the source. Revenue, tier distribution, and viability are hidden until published. |
| Visitors | Visitor detached snapshot | Current visitors and daily arrivals. Average, satisfaction, thoughts, and purpose data are hidden until published. |
| Metrics | Existing canonical read models only | A concise combined snapshot of available HUD metrics plus links to available primary panels. No independently calculated trends or charts. |

An unavailable panel entry may remain visible but is disabled with its source diagnostic. Panels never request an authority to calculate missing analytics merely for rendering.

### Heatmaps

Only one heatmap may be active. Its legend, selection, and shader mesh are presentation state; tile/sample values and revision are authority-provided detached input.

- **Visitor Density** is enabled only with an authoritative spatial visitor-density snapshot keyed to the currently projected district/zone revision.
- **Zone Viability** is enabled only with an authoritative viability snapshot. Tenant H2 does not provide viability; its application score must not be relabeled or reused as a viability heatmap.
- No density or viability source means no heatmap overlay and no synthetic all-cold/all-vacant texture.
- A source revision change invalidates the displayed texture; the adapter hides the overlay until a matching replacement arrives.

The existing shader-driven mesh decision remains the rendering implementation when a source exists. This handoff does not prescribe texture format, color tuning, or sampling resolution.

## Intent gateway, preview, confirm, and diagnostics

Every UI-originated request is a typed intent containing a stable request ID, target stable ID(s), user-selected values, and expected authority/source revisions when the owner requires them. Input controls never invoke a manager setter or modify a snapshot.

### Preview contract

For a prospective action, UI calls the owner preview port through `UIIntentGateway`. A preview result is detached and contains:

- the request ID, target identity, captured source revisions, and explicit `preview` status;
- prospective player-visible effects that the owner supports exposing, such as a price quote or validation outcome;
- stable diagnostics and affected stable IDs; and
- an expiration/revalidation requirement when applicable.

Preview may allocate transient owner-local candidate data but cannot consume IDs/counters, create a reservation, change committed funds, emit a committed event, create a notification-log entry, or alter save data. The UI labels previewed values as estimates/prospective effects, never as committed results.

### Confirm contract

Confirm submits a new typed confirm intent through the gateway. It must include the relevant expected revisions and, where required by the owner, a preview/quote reference. Confirm always invokes the authority's normal final validation and commit path. A valid preview does not guarantee success.

On success, UI waits for the owning authority's committed result/event and refreshes its read model. It must not locally apply the predicted delta. On rejection or stale validation, it keeps committed values unchanged, clears the pending preview, and renders the returned diagnostic. Double activation for the same in-flight request is ignored by the gateway until a result/cancellation arrives.

### Immediate diagnostics versus notifications

Diagnostics explain the request just attempted: examples include `INSUFFICIENT_FUNDS`, `RATE_REVISION_STALE`, `EVALUATION_INPUT_UNAVAILABLE`, and V2 load incompatibility. They are immediate, contextual, and transient by default. The owner supplies stable code/context; presentation owns wording and placement.

A notification-log entry is created only from an authority's committed notification condition or committed result explicitly marked notification-worthy. A rejected action does not become a durable notification merely because it has a diagnostic. In particular, Economy's `INSUFFICIENT_FUNDS` remains immediate feedback, while the committed below-zero financial condition is eligible for notification adaptation.

## Notification adapter and presentation state

`NotificationAdapter` receives typed post-commit condition/result projections after authoritative observers have completed. It creates an in-session `NotificationEntry` with stable source condition/result identity, category, priority, timestamp/calendar identity, status (`unread`, `read`, `resolved`), optional safe navigation target, and source revision.

- The source authority owns whether a condition exists and whether it is resolved. The adapter reflects a committed resolution event; it never stores or invokes a source-mutating resolution Callable.
- Duplicate projections with the same stable source identity update the existing entry rather than create repeated toasts.
- The adapter shows up to three visible toasts. Excess eligible entries queue. Priority durations remain high 10 seconds, medium 7 seconds, and low 5 seconds.
- Toast dismissal changes toast visibility only. Opening the log marks an entry read; it does not resolve it.
- `Clear All` removes only read, resolved entries from the in-session presentation log. Unresolved entries remain.
- The red dot is visible exactly while an unread or read high-priority entry remains unresolved. It is not driven by queue length or toast visibility.
- A toast/log action emits a new typed navigation intent (for example, focus a stable target or open an available panel). It cannot mutate the underlying condition.

The current notification panel filtering by category/status is retained, but no preferences, sounds, action-specific gameplay commands, or cross-session archive are added.

## Events and ordering

1. An authority completes validation and atomically commits its own state or a coordinating authority appends its complete committed envelope.
2. The authority emits its typed post-commit result/condition event with stable IDs, revisions, and diagnostics.
3. `PresentationCoordinator` rebuilds affected detached read models from snapshots; `NotificationAdapter` adapts notification-worthy committed facts.
4. HUD/panels/heatmap/toasts render the resulting presentation state.

No UI observer may cause rollback, delay a commit, reorder authority observers, or throw into an authority's transaction path. Subscriber/render faults are isolated as presentation diagnostics and leave committed authority state intact.

## Persistence and load

No presentation state is part of `authorities` in Save V2. Exclude panel selection, panel geometry, drawer state, filter state, in-flight previews, quoted display values, read models, heatmap textures/selections, visible toast queue, notification-log read/cleared state, diagnostics, and Node references.

After a successful `game_loaded`, `PresentationCoordinator` rebuilds read models from the restored authority snapshots. `NotificationAdapter` reconstructs only entries justified by restored committed conditions/results that their source republishes. It does not restore dismissed toasts, read markers, cleared log entries, or an old pending intent. Failed/staged loads expose the structured SaveManager diagnostic through immediate presentation feedback and do not replace the live read model.

## Acceptance requirements

- No UI scene, panel, adapter, or gateway can directly assign authority state or use a mutable authority collection as UI state.
- Every rendered current gameplay metric originates from a detached committed snapshot with an explicit owner/revision.
- Money excludes reservations and previews; HUD Prestige excludes debug-preview values; visitors and daily arrivals retain their distinct source semantics.
- Missing, incompatible, and stale sources are unavailable with stable diagnostics, never silently defaulted or retained as current.
- Preview leaves all committed authority state, persistent IDs/counters, reservations, events, save data, and notification log unchanged.
- Confirm revalidates through the owner and a stale or rejected confirm leaves committed UI values unchanged.
- The MVP permits one primary detail panel, one optional pinned summary drawer, or a replacement notification-log modal; it does not open five detail panels simultaneously.
- Every primary panel and heatmap is source-gated. Zone Viability remains disabled until a real authoritative viability source exists.
- At most three toasts are visible; duplicate condition projections do not duplicate log entries; only unresolved high-priority entries drive the red dot.
- A rejected action diagnostic remains transient unless a separate committed condition/result explicitly requests notification adaptation.
- Save/load contains no presentation state and a successful load rebuilds presentation from restored authorities only.

## Required tests

- Snapshot immutability/detachment, revision propagation, and unavailable/stale rendering for every HUD source.
- HUD semantic tests proving balance ignores reservations, official Prestige excludes debug preview, and current visitors differs from daily arrivals.
- Intent gateway tests for request correlation, double-submit suppression, preview non-mutation, confirm revalidation, stale rejection, and post-commit-only refresh.
- Contract tests that panels and heatmaps remain disabled/hidden without their named source and never fabricate charts, values, textures, or viability from tenant application score.
- Panel policy tests for primary replacement, drawer limit, notification-log modal replacement, close behavior, and no regression of the existing CanvasLayer structure.
- Notification tests for priority duration, three-visible queue cap, duplicate source identity coalescing, read versus resolved behavior, red-dot condition, clear-read-only behavior, and navigation intents.
- Event-order/fault-isolation tests proving presentation listeners cannot observe intermediate authority state, roll back commits, or prevent other post-commit consumers.
- V2 save/load tests proving presentation state is absent, no in-flight intent/toast/read marker restores, and read models rebuild only after successful `game_loaded`.

## Dependencies and later work

Implementation depends on each participating authority exposing the named detached snapshot, stable diagnostics, and post-commit event contract. A panel or heatmap with no source remains out of scope rather than blocked by a fabricated adapter.

Later approved handoffs may add authoritative reporting snapshots, trends/history, tenant viability, visitor sentiment, contextual indicators, panel customization, notification preferences/sound, localization, and durable notification policy. They must preserve this handoff's rule that presentation consumes authorities and submits intents but never becomes one.
