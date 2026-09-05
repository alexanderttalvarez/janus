# Session Handoff 02: Atomic Session Restore and MVP Acceptance

## Status

**Approved — 2026-09-05 (delegated architecture authority).** This handoff extends District H9's detached Save V2 contract into the complete session restore orchestration and defines the MVP end-to-end acceptance gate.

## Purpose

Restore a complete saved session by exporting, validating, staging, and committing detached authority state as one replacement. A restore either publishes one coherent new session or leaves the current session unchanged.

## Scope and boundaries

- Own the full-session authority registry, restore ordering, restore barrier, projection rebuild boundary, failure contract, restore events, and headless acceptance gate.
- Refine, but do not replace, [District H9](../district_layout/09_save_load_v2.md)'s exact V2 envelope, slot-write safety, and V1 rejection policy.
- Reference District H1-H8 authority contracts, rather than redefining district definitions, resolution, transaction policy, public realm, traffic, arrival policy, or visitor behavior.
- This handoff contains no bootstrap or time-system design. Existing startup and time ownership remain external dependencies and must only consume the committed-session event described here.

## Authority registry

`SaveManager` owns the ordered registry for the exact V2 `authorities` keys. The registry is declarative and is the only source for export, detached validation, candidate import, cross-reference validation, commit participation, and teardown participation. No manager may self-register during restore.

| Registry key | State owner | Restore role | Persisted boundary |
| --- | --- | --- | --- |
| `district` | District Runtime | Establishes resolved district identity and sparse district state | H2 identity plus H3 `DistrictState` |
| `zone_parcel` | ZoneManager | Imports zone/parcel state against committed candidate district addresses | Mutable zone/parcel facts only |
| `economy` | Economy authority | Imports committed financial facts | No quotes, reservations, or capture tokens |
| `progression` | Progression authority | Imports committed unlock/selection facts; derives eligibility after import | No derived eligibility snapshot |
| `prestige` | Prestige authority | Imports committed prestige facts used by dependent reconstruction | No presentation cache |
| `staff` | Staff authority | Imports staff facts and validates stable references | Authoritative staff state only |
| `synergy` | Synergy authority | Imports committed synergy facts after referenced owners exist | No computed presentation state |
| `tenant` | Tenant authority | Imports tenant occupancy after district, zone/parcel, and progression facts exist | Authoritative tenant lifecycle only |
| `visitor` | Visitor authority | Imports realized visitor lifecycle state after arrivals can resolve stable sources | Decision below |
| `time` | Existing time authority | Participates only through its existing detached snapshot contract | Existing time-owned state; no new policy here |

Registry order is fixed: `district`, `zone_parcel`, `economy`, `progression`, `prestige`, `staff`, `synergy`, `tenant`, `visitor`, `time`. Validation may inspect only detached snapshots until the candidate import phase. Cross-authority references are stable IDs and revisions, never Node paths, transforms, traversal order, or generated graph handles.

## Restore protocol

### Export and write

1. The registry exports detached snapshots from the current committed session in registry order.
2. `SaveManager` assembles the exact H9 V2 envelope, validates it, writes a temporary slot file, flushes it, and atomically replaces the selected slot.
3. A failed export, validation, temporary write, flush, or replacement preserves the prior slot. It does not alter the active session or emit a load event.

### Detached load and validation

1. `SaveManager` parses the selected slot and enforces H9's V2 schema/version/exact-key rule before candidate construction.
2. It resolves `layout_ref`, verifies definition version and fingerprint, and creates an isolated candidate session container.
3. Every registry owner validates its own snapshot detached; the registry then validates all cross-authority stable-ID and revision references in fixed order.
4. The candidate imports snapshots in registry order. Derived indexes, eligibility, caches, geometry, transforms, navigation/traffic graphs, Nodes, reservations, and presentation are rebuilt only in candidate scope.
5. Any error destroys the candidate and preserves the old committed session, its projections, and its slot.

### Restore barrier and commit

The restore barrier opens only when every registry participant has returned success for detached validation, candidate import, cross-reference validation, and candidate projection preparation. Before that point, no candidate service is globally discoverable and no event advertising loaded gameplay is emitted.

At the barrier, `SaveManager` performs the one commit operation:

1. Freeze external session mutation and event delivery at the session boundary.
2. Publish the complete candidate authority container as the active session.
3. Rebind session-scoped consumers to the published authorities.
4. Dispose old projections and old authority container only after publication succeeds.
5. Release the barrier, then emit exactly one `game_loaded` event.

`game_loaded` means a fully committed session with rebuilt projections; it never means parsed, partially imported, or merely staged data. Observer callbacks may not reenter restore. A post-publication failure is a fatal implementation defect: commit must be engineered so all fallible work completes before the barrier; it must not publish a partial rollback event or retain mixed old/new authority state.

## Projection rebuild contract

Projections are disposable consumers of the committed authority registry. Candidate projection rebuild follows authority import and completes before the restore barrier opens. Rebuild order is: district/world projection, public-realm and topology projections, camera/gateway projection, traffic projection, then tenant/visitor presentation projections. Each projection receives immutable committed-candidate snapshots and returns a readiness result; it never becomes an authority or writes snapshots.

The active old projections remain visible and serviceable until candidate readiness succeeds. Candidate Nodes stay under an isolated staging root and have no input, navigation registration, global lookup, or gameplay event exposure. Commit swaps roots/references atomically; failed staging destroys only candidate projections. Projection destruction followed by rebuild from the same authority snapshots must be behaviorally equivalent to the original committed projection.

## Active visitor persistence decision

**MVP decision: persist active realized visitors as durable lifecycle records, not live agent Nodes.** Each record contains the visitor's stable ID, lifecycle state, durable source/destination or ownership references required by the existing visitor contract, and any authority-owned progression needed to continue that lifecycle. Runtime positions, paths, navigation-agent state, animation state, reservations, presentation Nodes, and transient pending cohorts are excluded.

On restore, the Visitor authority validates every durable reference, recreates active visitor agents from records only after topology and source projections are ready, and resumes them through normal lifecycle realization. A missing or invalid durable reference rejects the entire candidate; it does not silently drop a visitor or downgrade the record. H8's MVP rule remains: pending arrivals/cohorts and source-capacity state are not persisted.

## Ownership and events

| Concern | Owner | Contract |
| --- | --- | --- |
| Registry, envelope I/O, restore coordinator, barrier, result | `SaveManager` | Sole orchestrator and sole emitter of post-commit load event |
| Snapshot export/validation/import | Named authority | Detached, versioned snapshot methods; no live mutation during validation |
| Layout identity and district state | District Runtime | H1-H3 identity/state contracts |
| Projection readiness and teardown | Projection Coordinator and specialist projections | Candidate-only rebuild; no persistence ownership |
| Presentation of restore/incompatibility/failure | Presentation owner | Consumes structured result; cannot mutate restore state |

Events are ordered as `restore_requested` (optional diagnostic only) -> detached validation/staging with no gameplay-loaded event -> atomic commit -> `game_loaded` once. A structured `restore_failed` result/event is permitted only after candidate destruction and must include a stable reason code, failed registry key or stage where safe, and `old_session_preserved: true`. It is not a partial-success signal.

## Failure contract

| Failure point | Required result |
| --- | --- |
| Missing schema, malformed envelope, unknown layout, version/fingerprint mismatch | Reject before candidate construction; slot unchanged; old session unchanged |
| Authority or cross-reference validation | Destroy candidate; old session and projections unchanged |
| Candidate import or derived reconstruction | Destroy candidate; old session and projections unchanged |
| Candidate projection preparation | Destroy staging root; old session and projections unchanged |
| Atomic write failure | Preserve previous slot and active session |
| Commit precondition failure | Do not publish candidate; destroy it; old session unchanged |

No partial load, per-manager live deserialization, fallback identity, V1 conversion, silent visitor loss, or generated-data persistence is permitted.

## Headless MVP Acceptance Gate

The gate runs without editor interaction and is release-blocking for the session restore MVP. It must execute against each district fixture required by H9/H10 and report per-stage timing and stable failure diagnostics.

1. Start a new session, perform representative committed mutations across every registry authority, including a realized active visitor.
2. Export V2, write it atomically, retain an immutable digest of committed authority snapshots and required projection manifests.
3. Destroy all session-scoped projections and dispose the active session; restore from the saved slot through the production coordinator.
4. Assert registry-order detached validation, one barrier commit, exactly one `game_loaded`, and equality of authoritative snapshots/digests excluding explicitly derived values.
5. Assert rebuilt projection manifests/topology and realized visitor lifecycle equivalence, with no persisted Nodes, paths, caches, reservations, pending cohorts, or generated geometry.
6. Inject failure at parse, layout resolution, each registry validation/import step, each projection preparation step, and temporary-file replacement. For every injection, assert unchanged old-session digest, unchanged old projection manifest, unchanged slot where applicable, zero `game_loaded`, and no candidate resource leak.
7. Exercise schema-absent/V1, malformed, unknown-key, unknown-layout, definition-version, fingerprint, and invalid-active-visitor-reference rejections. Assert H9 structured incompatibility/failure results and preserved session/slot.
8. Repeat save/restore/destroy cycles and assert no growth in session roots, projection Nodes, registry registrations, event subscriptions, or retained candidate memory.

Pass requires all scenarios to succeed with a clean runtime error log. The gate is headless evidence for H9 implementation acceptance and a required input to H10; it does not replace H10's broader adapter-removal and release evidence.

## Required implementation tests

- Registry exact-key/order/completeness tests, including rejection of unregistered or duplicate participants.
- Detached export/import round-trip and cross-authority stable-reference validation.
- Barrier tests proving no global candidate discovery, gameplay event, or old-session teardown before readiness.
- Projection destruction/rebuild parity tests with candidate isolation.
- Active-realized-visitor persistence/resume and invalid-reference rejection tests.
- Fault-injection tests for every row in the failure contract.
- Headless end-to-end MVP acceptance gate for `fixture.legacy_25_single`, `fixture.variable_30x40_single`, and `fixture.mixed_3x3`.

## Related authorities

- [District H9: Save/Load V2 and District Persistence](../district_layout/09_save_load_v2.md)
- [District H10: Legacy Removal and Final Acceptance Gate](../district_layout/10_legacy_removal_and_acceptance.md)
- [District Layout Handoff Index](../district_layout/_index.md)
- [Decision 15: Save/Load Architecture](../../decisions/15_save_load_architecture.md)
