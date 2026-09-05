# Presentation Handoff Index

This program defines the MVP presentation boundary: UI read models, intent routing, diagnostics, HUD metrics, source-gated panels and heatmaps, and notification delivery. It preserves the existing `game_ui.tscn` multi-CanvasLayer decision and never creates simulation authority in UI.

## Handoffs

| Order | Handoff | Status | Scope |
|---:|---|---|---|
| 01 | [MVP Read Models, Intent Gateway, and Notifications](01_mvp_read_models_intent_gateway_and_notifications.md) | Approved — 2026-09-05 (delegated architecture authority) | Revisioned authority snapshots, UI read models, preview/confirm routing, diagnostics, canonical HUD metrics, source-gated MVP panels/heatmaps, and notification adapter/toast/log state. |

## Program rules

- UI is a read-model and intent consumer. It cannot mutate Economy, Zone, Tenant, Prestige, District, Time, Visitor, or any other authority.
- An authority remains responsible for its committed facts, validation, diagnostics, persistence, and post-commit event. Presentation owns only derived display state and input routing.
- A missing, stale, or incompatible source is shown as unavailable with its stable diagnostic; presentation must not invent a zero, default, estimate, or fallback.
- Preview state is transient and non-authoritative. A confirm action always re-enters the owning authority's normal validation and commit path.
- Later presentation handoffs may add visual polish, additional analytics, localization copy, preferences, or new interaction modes only through an approved change.
- Any change to an approved handoff requires an architecture review and user approval before implementation.
