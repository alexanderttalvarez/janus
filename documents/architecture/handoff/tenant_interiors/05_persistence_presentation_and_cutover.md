# Tenant Interiors Handoff 05 — Persistence, Presentation, and Cutover

**Status:** Architecture approved, 2026-09-08 follow-on request under [ADR 34](../../decisions/34_product_mvp_runtime_and_cutover.md). Replaces the former draft. Order: 5 of 5; H4 and foundation implementation evidence precede live candidate cutover. Implementation, visual acceptance and Product completion are NOT VERIFIED.

## Requirement and scope

Integrate [Current MVP](../../../game_design/current_mvp.md) interiors without mixed proxy/live service, partial saves, rerolled goals or invented economic outcomes. Preserve Session H2 and District H9 root V2, exact owner registry and atomic slot/session replacement. No executable compatibility adapter, Save V3, durable Service root, indoor navigation, revenue or historical-result conversion.

FACTS: current design explicitly requires deterministic rebuild, transient in-flight service reset and no proxy fallback. ASSUMPTIONS: loss of queue position/elapsed service at load is the accepted MVP simplification, not exact resume. OPEN QUESTIONS: exact in-flight continuity is future scope requiring new approval; it is not silently promised by this schema. The H4 wait/cohort interpretations require explicit Design acceptance with actual behavior.

## Data ownership and schema

Root stays exact V2. Fixed registry: district -> zone_parcel -> economy -> progression -> prestige -> staff -> synergy -> tenant -> visitor -> time. `synergy` retains ADR 33's exact derived-only reserved payload. No Service root or additional Time origin is introduced.

| Authority | Exact local discriminator | Durable extension |
|---|---|---|
| Zone | state_schema_id = zone_parcel_core_annex; state_schema_version = 1 | H2 core/annex geometry, doors, exclusive committed queue envelopes and graph/queue-policy provenance; exact public-door representation is [ADR 35](../../decisions/35_public_band_access_snapshot_and_zone_injection.md) |
| Tenant | state_schema_id = tenant_operational_interior; state_schema_version = 1 | H3 exact profile/variation/policy/proxy/layout provenance; no fixture meshes or generated manifest |
| Visitor | state_schema_id = visitor_interior_service; state_schema_version = 1 | Capability, generation provenance, goals/progress, exclusions, result families and valid resume facts |

Visitor manager requires `service_capability_id = interior_service_v1`, revision 1, visitor-policy identity/revision, behavior seed domain/value and next creation ordinal, including when zero visitors exist. Every visitor retains stable identity, consumed creation ordinal/seed provenance, complete captured canonical category array, empty marker, H4 generation fingerprint, visitor-policy identity/revision, generated goals/wait, progress/drop/current-goal state, excluded tenant IDs, historical/current result records and permitted public resume facts. Creation ordinals are unique in their domain and less than the manager's next ordinal. Existing owner fields remain required; these are not partial replacement schemas.

H4's generation fingerprint hashes exactly category_ids, empty, visitor_policy_id and visitor_policy_revision. Current operational categories are NEVER substituted for historical captured categories. Runtime availability source revisions/fingerprint are diagnostic runtime data, not mandatory durable generation inputs. Integrity fingerprints establish consistency, not trusted proof against malicious edits. Pure deterministic validation recomputes expected generation without consuming RNG or replacing saved state.

Time already persists simulation and visual elapsed values under Session H1. Save must preserve enough numeric precision to recover the visitor ordinal and fractional time until the next boundary exactly in the implementation's clock representation. Reject nonfinite/negative/inconsistent clocks. Prove before/at/after boundary round-trips; do not reconstruct from day/hour labels. Current authority-local schema must reject missing required precision/state rather than silently reset time. No clock-policy change is authorized here.

## Coherent export and canonicalization

Capture the complete detached owner set at a safe boundary under ADR 33's gate; finish all due boundary phases/settlement chains first. Release the gate before validation, canonicalization and file I/O. Canonicalization changes ONLY detached export records, never the live session, queues, tokens, results or clock.

| Live Visitor state | Saved/resumed state |
|---|---|
| DECIDING | DECIDING at validated current logical public anchor; durable goal state unchanged |
| LEAVING | LEAVING with valid current public anchor and existing exit intent/retry facts |
| TRAVELING_TO_SERVICE | Current reached public/source anchor plus destination intent; no teleport to an unreached door |
| EVALUATING_AT_DOOR / WAITING_EXTERIOR / IN_ABSTRACT_SERVICE | DECIDING at validated reached target public proxy; retain goals/wait/exclusions/results, remove all service commitments |

Paths, transforms, interpolation, queue positions held by visitors, FIFO ordinals, tokens, cohorts, stages, active/next batches and scheduler marker are transient and excluded. Zone's legal queue envelopes remain durable. Service is rebuilt empty. Saving cannot complete/drop a goal, append a result, release live capacity, or alter the active cap. Invalid required anchors fail export and preserve the previous slot. Later live mutation after coherent capture cannot change the detached save.

Write validated JSON through existing H9 temporary-file/flush/atomic-replacement protocol under user storage. Serialize save writes so an older in-flight capture cannot overwrite a newer successful capture. Malformed/untrusted data is parsed as data only: no Resource/script loading or object instantiation from save-controlled paths. Validate bounds, types, exact keys, IDs and cross-references before candidate creation/import. No new file format or encryption is required.

## Detached validation and atomic restore

1. Parse and enforce exact V2 root, registered owner keys, current local discriminators and capability. Resolve immutable layout/content identities from the approved registry, not save-supplied paths.
2. Obtain the COMPLETE detached saved authority set. Owner validation and pure derived validation use only that set plus immutable content, never the current live session or a partially imported owner.
3. Validate the detached District candidate, then derive ADR 35's candidate `PublicBandAccessSnapshot` from that candidate and resolved `layout_ref`. Validate Zone `PUBLIC_BAND` selected-door stable IDs, endpoints, and directions against it before accepting the Zone candidate; do not replace or synthesize an edge.
4. Derive a temporary validation graph from accepted saved District/Zone/Construction facts; derive legal envelopes and H1/H3 layouts from saved geometry/provenance. These are detached validation values, not globally registered Nodes or live authority. The public-band snapshot and graph remain unsaved candidate-only derivations.
5. Validate every remaining owner and then cross-owner references in registry order: geometry, preserved door/envelope IDs, layout fingerprints, bindings, unique IDs, captured visitor generation and resume anchors, cap, payroll/milestone markers and Time consistency. Recompute captured generation independently of current operational categories.
6. Create an isolated candidate and import ALL durable snapshots in fixed registry order. Import emits no gameplay events, awards, rent, payroll, service results or boundary ticks.
7. Rebuild derived candidate eligibility, indexes, public graph, spatial facts, layouts, empty Service state, Visitor logical state and projections in dependency order. Compare candidate graph connector IDs, envelopes, and layout manifests to detached validation results. No public edge or envelope is synthesized to repair missing saved data.
8. Initialize Service's last-consumed marker to restored Time visitor ordinal. Derive batch phase from stable service/policy identity and epoch zero. No retroactive completions/batches run. Next boundary occurs after the saved fractional remainder; reset is not a new cadence epoch.
9. Prepare all bindings/projections before Session H2's single publication barrier. Atomically replace active session only when every participant is ready, dispose old roots after publication succeeds, emit exactly one game_loaded, then allow input/calendar.

Any parse, validation, import, derived rebuild, projection or pre-publication failure destroys only the candidate and preserves the complete old session/projections/slot. Failed load never hot-switches service capability. Post-commit observer failures are diagnostics; no mixed rollback or second loaded event. Check old-session generation when publishing so a cancelled or superseded load cannot replace a newer session.

## Compatibility and reset guarantees

Reject V1, missing/older/unknown local schemas, mismatched content and proxy-capability saves before staging; no automatic converter. The reproducible proxy foundation remains a test checkpoint, not a runtime branch in Product sessions. Historical proxy records may exist only as explicitly typed immutable non-economic records inside an otherwise valid current Visitor schema. New tenant-service results remain a separate kind; neither affects Economy or Prestige.

Reload guarantees unchanged durable goals/results, deterministic layout, stable calendar/cadence and valid public resume. It deliberately does NOT preserve FIFO position, occupied seats, elapsed service, active/next batch membership or commitments. A reset can change subsequent queueing; do not advertise an exploit-proof exact service continuation. Repeated reload cannot manufacture completion/results or advance time. Any stronger guarantee requires a new persistence decision.

## Presentation and content pipeline

H1/H3 Resources and layout manifests are the sole content source. Asset authors provide bounded default fixture visuals for every mandatory fixture and operational module; theme variants/signage must preserve footprints/capacity. Optional decoration may be absent. No AI-generated or editor-created asset is delivered by this document. Missing mandatory content is a validation failure, not a proxy substitution.

```
Projection (Node3D)
├── TenantInteriorProjectionRoot
│   └── TenantInteriorView (Node3D; reusable PackedScene)
│       ├── StructuralVisuals
│       ├── FixtureVisuals
│       └── AbstractOccupancyVisuals
├── QueuePresentationRoot (real public-side visitor views)
└── VisitorProjectionRoot
UI (existing CanvasLayer/Control scenes)
└── Existing primary detail panel + contextual diagnostics
```

Views consume immutable facts, own no simulation and need no per-fixture processing. Use ordinary instancing first; pooling, culling or MultiMesh are profiling choices that must preserve behavior. A visual failure marks freshness/unavailability visibly; it cannot change Tenant rent/lifecycle or fabricate service. World picking remains disabled for stale geometry under ADR 33.

| Display | Source | Required behavior |
|---|---|---|
| Profile/theme/sign and current suitability/top three/full list | Tenant + H1/H3 read model | Distinguish suitability from stale/unavailable planning; never show indeterminate as Unsuitable |
| Fixture-derived capacity and occupancy cues | Validated manifest + Service snapshot | Same token/occupancy facts as runtime; no mesh counting |
| Exterior queue/current expected wait | Service + Visitor logical positions | No overlapping claimed position; UI never estimates service itself |
| Active/next batch and countdown | Service + Time read facts | Clearly separated batches; no third booking |
| Build/zone/rent/unlock/staff and save/load controls | Existing presentation intent gateway | Stable target IDs/revisions, source-backed success/rejection, no debug-only Product route |
| Load reset/incompatibility/error | Session/Save result | Explain queue/service reset and preserved/failed save; do not claim progress was resumed exactly |

Use existing Control containers/themes/input focus and one detail panel; no new dashboard framework, UI-owned simulation or EventBus query layer. World culling must not hide state from logical service. Respect floor and wall modes in visual acceptance.

## Risks, alternatives and extensibility

Transient rebuild is simpler than persisting every commitment but visibly resets service on load. Exact continuation is deferred, not partially supported. Strict rejection avoids a migration subsystem at MVP but breaks older snapshots; document that compatibility boundary before release. Layout/content identity must be frozen for acceptance, since changing authored footprints requires a policy revision and new proof. File I/O and derived work remain outside the mutation gate; optional asynchronous work must carry session-generation tokens and cannot expose candidates.

## Required acceptance (NOT RUN)

- Exact-key/schema/type/content rejection matrix; zero and 200 visitors; category capture changed/empty since arrival; no reroll or ordinal advancement; historical result-family isolation.
- Save each Visitor/service state, including simultaneous completion/catch-up/payroll; prove save leaves live commitments unchanged and load restores canonical records only.
- Before/at/after visitor/day/week/month boundaries and batch/turnover boundaries at every speed; fractional-time round-trip, stable phase, no retroactive completion or duplicate rent/payroll/Tech awards.
- Envelope/legal-door/layout byte parity, including ADR 35 stable public-edge provenance and graph connector-ID parity; District-first candidate snapshot derivation; candidate-only sources; all imports before derived runtime; every validation/import/projection/write/publication-precondition fault preserves old session/slot.
- Repeated save/load/destroy, superseded loads and serialized writes; no retained roots/subscriptions/caches or duplicate loaded events.
- Visual proof: minimum/preferred/oversized/annex and Anchor layouts, walls/doors/default bounds, safe exterior queues, capacity/occupancy cues, countdown, unsuitable versus indeterminate feedback and stale-source diagnostics.
- Foundation regression plus all nine H4 typologies on the same candidate, then normal-play vertical/category unlock route; no proxy fallback or debug completion. Use [delivery and acceptance](../mvp/04_product_delivery_and_acceptance.md). District Gate R remains separate.

Implementation skills: `save-load`, `resource-pattern`, `scene-organization`, `godot-ui`, `hud-system`, `assets-pipeline`, `godot-testing`. Generic skill migration examples do not override this approved strict-rejection policy.
