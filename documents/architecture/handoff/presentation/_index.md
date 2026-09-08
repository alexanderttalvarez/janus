# Presentation Handoff Index

This program defines the MVP presentation boundary: UI read models, intent routing, diagnostics, HUD metrics, source-gated panels and heatmaps, and notification delivery. It preserves the existing `game_ui.tscn` multi-CanvasLayer decision and never creates simulation authority in UI.

**Current revision:** 2026-09-08, delegated documentation pass. H1 remains approved under [Current MVP](../../../game_design/current_mvp.md), ADR 33 and MVP H3. Minimal Tech purchase/room staffing/unpaid fit-out-cancel actions are required; full Tech/Staff dashboards are not. Conditions resolve at their source, not by toast dismissal. Draft `tenant_interiors/H5` does not authorize live interior presentation/cutover here.

**Follow-on review, 2026-09-08:** The preceding revision records the earlier consistency pass. [ADR 34](../../decisions/34_product_mvp_runtime_and_cutover.md) separately architecture-approves interior H4/H5. Foundation -> detached interior H1-H3 -> H4 implementation passes -> H5 candidate cutover passes -> Product acceptance; external Gate R is separate. Live interior read views/capability activation require those implementation/cutover passes; approval supplies no source facts. Implementation/cutover remain NOT VERIFIED; Product acceptance/Gate R remain PENDING.

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
