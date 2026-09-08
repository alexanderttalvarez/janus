# ADR 33: Documentation Consistency and Minimum Contracts

**Status:** Accepted, 2026-09-08, delegated documentation consistency pass. No implementation or release evidence is asserted.

## Context

**Follow-on notice, 2026-09-08:** This body preserves the earlier consistency-pass decision, including its then-current H4/H5 draft boundary. In a separate subsequent request and review, [ADR 34](34_product_mvp_runtime_and_cutover.md) architecture-approves `tenant_interiors/H4-H5`. Current dependency order is foundation -> detached H1-H3 -> H4 implementation passes -> H5 candidate cutover passes -> Product acceptance; external Gate R is separate. Implementation/cutover remain NOT VERIFIED; Product acceptance/Gate R remain PENDING. No earlier approval or test result is retroactively changed.

Older ADR examples conflict with newer approved handoffs and the player-facing design. Several prescribe infrastructure beyond the current scope. This amendment preserves history while fixing the smallest coherent target.

## Decision

| Earlier record | Retained | Explicit amendment |
|---|---|---|
| 01 Scene architecture | One gameplay composition root, sub-scene composition | Session-owned dependencies are injected directly; EventBus is post-commit presentation facts, not all inter-owner calls |
| 02 UI rendering, 05 Heatmaps | Source-backed tile heatmaps | Use the existing world-space shader mesh path; a second SubViewport/compositing implementation is not required. ADR 02's mandatory SubViewport is superseded |
| 03 Visitors, 12 Time | Central behavioral ticks; visual interpolation; one calendar owner | [Element 01](../../game_design/elements/01_core_loop.md) defines scaled elapsed seconds versus calendar units. Visitor decisions every 5 scaled seconds, not 5 calendar minutes or independently ticking agent FSMs |
| 04 Walls | Shader clipping, three global modes | [Element 12](../../game_design/elements/12_wall_system.md) owns the 10% base strip and profile dimensions. Supersedes 5% clipping; parcel walls clip symmetrically as `zone_parcels/H4` requires |
| 13 Economy | One balance authority and quote/reserve/capture boundary | Element 03 and MVP H3 resolve mandatory whole-week payroll, no post-commit refunds and source-owned balance conditions; no deferred loan or job system is required |
| 14 UI | Godot Control/CanvasLayer presentation | Panels may cover the HUD; HUD is not globally topmost. Notifications/modal input sit above panels. Inject session Economy read/intent ports; legacy singleton examples are not target wiring |
| 15 Save/load | JSON, detached owner snapshots, atomic orchestration | V2 and Session H2 supersede schema-absent examples, V1 support and live per-manager loading. See reserved synergy payload below |
| 16 Camera, 27 District | Pivot rig, floor navigation, district projection | Active plus Progression-selected Plot rectangle union, expanded by the approved road-relative margin in `district_layout/h6_policy_acceptance.md`; no 20-tile radial rule |
| 17 Notifications | Toast queue and bounded log | Source owns condition identity, active/resolved fact and revision; presentation owns display/dismissal. General Callable polling of all gameplay is not required |
| 18 Staff | Employment, coverage, payroll ownership | Current MVP uses records and room facts, no per-employee agent Nodes or mandatory task simulation |
| 19 Tech, 22 Prestige | Progression sole writer; official Prestige snapshots | Minimum Tech awards follow element 08. Fixed Quality 20 is the current producer; no SynergyManager or six-factor dependency required |
| 23 State machines | Explicit states and legal transitions | Supersedes generic Node/Resource FSM and Phase-7 prerequisite. Owner-local enums/records and centralized transitions suffice. Shared Resources contain immutable definition data, never per-agent mutable state |
| 24 Zone mutation | Pure prospective geometry and preservation-first edits | Later `tenant/H1` is a participating owner for explicit bound-tenant cancellation/retirement. Zone never writes Tenant state, but commit coordinates both; supersedes the blanket lifecycle-outside-transaction consequence |
| 27 District, 28 Arrival | Definition/resolution/state split and immediate pedestrian arrivals | H1/H2 KEEP records froze the hybrid format; provisional-format alternatives are historical. Fixture ownership and crossing clarifications below apply |

## Atomicity Without Extra Frameworks

One session-scoped, main-thread non-reentrant mutation gate serializes participating-owner commits, arrival acceptance, calendar settlement, coherent save capture, and live-session replacement. Existing owner gates are logical participants in that gate, not independently acquired locks. Do fallible preparation outside the gate; revalidate source revisions inside it; publish only complete prepared changes. No `await`, frame yield, scene callback mutation, or recursive transaction may interleave publication.

Callbacks requesting a mutation during commit/flush receive a structured busy rejection and may retry after release; do not silently enqueue an unbounded command stream. Observer failures after commit are diagnostics, not rollback. Preserve existing append/flush ordering where a handoff requires it, but no generic transactional framework or journal persistence is introduced. Off-thread detached calculation is optional, not a dependency.

Required synchronous successor work is orchestrated directly, not attempted by reentrant observers. After a successful monthly Prestige commit returns and releases its gate, the existing session/calendar coordinator invokes idempotent Progression milestone reconciliation before allowing another boundary, input or save capture. Source callbacks remain read-only. Reconciliation failure pauses that boundary chain and blocks save until resolved; otherwise a save could retain a new official tier with a lost award. This ordering adds no persisted event queue or second scheduler.

Save capture holds this gate only while obtaining the complete detached authority set; file I/O follows outside it. Candidate restore imports all durable snapshots before rebuilding derived state in dependency order. Progression derives eligibility from candidate Prestige, never the old live session. No awards/events run during import. These rules amend `district_layout/H3/H8/H9` and `session/H2` together.

## District Clarifications

- Production starts with one owned Plot. Proof Fixture C's three explicit owned entry sections are a test-only initial-state exception, not three free production Plots. Frozen semantic manifests and fingerprints are unchanged by this clarification.
- A literal union of separated Plot rectangles is not connected. Traffic uses the active Plot **slot adjacency** components and bordering road graph, not a filled bounding box or an invented connecting Plot. Multiple components, including Fixture C, are valid; duplicate lane anchors are deduplicated by stable lane/control identity. Conversion may disconnect roads and never fails for ambient traffic connectivity. Element 19 defines this player-facing rule; `district_layout/H7` defines the corresponding outcomes.
- Midpoint lights are not intersection lights. Element 19's phase intervals, offsets, pedestrian clearance and shared clock are the single timing authority. This revision needs new boundary/clearance evidence; historic H7 PASS does not prove it.
- A failed projection rebuild retains the old valid root but disables world picking/build intents until a matching-revision projection is ready. Failed candidate roots alone are disposed. Authority is not rolled back to match stale visuals; load staging still preserves the entire old session on failure.

## Reserved Save Field

The approved V2 root's exact keys remain unchanged. `authorities.synergy` is a reserved value, not a reason to create an unused mutable authority. For this scope it is exactly `{"schema_version":1,"mode":"derived_only"}`, validated by the session registry; spatial synergy is derived from Zone geometry and immutable policy. No mutable synergy cache is saved. Any different payload rejects before staging; no migration is implied. This explicitly amends ADR 15 and `district_layout/H9`, `session/H2` in the absence of a designed durable synergy system.

## Readiness and Consequences

`tenant_interiors/H1-H3` stay approved for detached content/planning, prospective geometry and candidate/lifecycle outcomes. Their references to runtime Service, live Visitor integration, and whole-session interior persistence are deferred integration obligations, not prerequisites for detached acceptance. No live capability/schema cutover or fallback service is authorized before separately approved `tenant_interiors/H4-H5`. Both remain drafts.

The [current scope](../../game_design/current_mvp.md), revised program contracts and [MVP integration clarification](../handoff/mvp/03_foundation_integration_clarifications.md) govern new work. This is not product release approval. ADR 32's Gate E/R separation remains unchanged.

## Acceptance

Verify clock boundaries, wall ratios, camera union, callback reentrancy rejection, coherent save capture, candidate-only restore dependencies, disconnected traffic components, crossing clearance, reserved-field validation, and draft capability gating against these amended contracts. No obligation to build deferred abstractions is created.

## Rationale

Preserve the spatial-design premise, existing stable identities and explicit save boundary while removing duplicate authorities and implementation prerequisites with no current behavior. GodotPrompter's state-machine guidance supports choosing owner-local state for this complexity rather than a universal framework.
