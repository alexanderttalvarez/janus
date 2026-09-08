# Product MVP Implementation Audit

## Scope and Candidate

P00 bounded, read-only engineering conformance audit against `handoff/mvp/04_product_delivery_and_acceptance.md` P01-P09, the current MVP H1 sequence, and ADR 33/34. This is not foundation acceptance, Product acceptance, district Gate E re-certification, or external Gate R signoff. New behavior acceptance remains **PENDING**.

- Observation window: 2026-09-08, clock samples `18:19:56+02:00` through `18:21:02+02:00`, before report creation.
- Git HEAD, observed twice: `b87ff21b386fa2778c5f163c2fe6cc78bf57c780`.
- Initial `git status --short`: dirty documentation worktree, including modified architecture/design documents and untracked ADR 33, ADR 34, MVP H4 and scope documents. No implementation/scenes/assets/settings/tests changes were listed. `git diff --stat` reported 98 tracked documentation files, 856 insertions and 960 deletions; untracked documents are not included in those totals.
- Reviewed contracts are the actual working-tree documents, not their older HEAD versions. Contract authority: `documents/game_design/current_mvp.md:18-34`; `documents/architecture/handoff/mvp/04_product_delivery_and_acceptance.md:24-39,55-95`; ADR 33 `:30-49`; ADR 34 `:9-24,34-49`.
- Candidate binding limitation: HEAD and dirty status identify a working observation, not a frozen release candidate. No full dirty/untracked patch digest, content/policy hashes, export hash, or editor-buffer equivalence was captured. No prior PASS is transferred to this observation. Engine version/render backend and production seed/settings were not captured; the startup check never reached Play.
- Only this Markdown report was authored by this audit. No implementation, scene, asset, setting, test, save slot, or evidence index was edited. Evidence index integration belongs to the main agent.

## Access and Coverage

The earlier disconnected-session statements in MVP H4 `:39` and ADR 34 `:45` describe the prior session, not this observation. Here `editor_context` returned `addon_connected=true`, editor PID `11460`, project `/home/aelxan/Programming/Games/janus/`, active scene `res://scenes/levels/main_game.tscn`, no selected nodes, and `game_running=false`. The final context check also reported stopped, connected, and the same active scene.

`project_summary(detail="brief")` returned Janus, 189 scripts, 20 scenes, 53 assets and six autoloads. These counts are not conformance evidence. `ping` returned GodotIQ `0.5.16`, community license/bundle, missing receipt, and 38 tools. `file_context` and `dependency_graph` were callable but full API, dependency targets, reverse imports and signal targets were tier-locked. The MainGame dependency preview reported 16 direct dependencies and 189 discovered files, with the addon excluded; no complete call-graph conclusion is drawn from that preview.

Actual code was accessible through `script_ops(op="read")`. Nine complete script responses were inspected, listed below. `scene_tree(depth=2, detail="normal")` returned 31 nodes out of 128 and confirmed MainGame's root script and scene-owned Simulation Time/Visitor/Tenant/Economy/Prestige/TechTree/Staff/Synergy nodes, World Zone/Wall/Traffic nodes, CameraRig and GameUI. This is editor composition evidence, not runtime-spawned-node evidence. `file_ops(op="tree", path="res://scripts")` was used for discovery only; directory and filename presence or absence is not treated as implementation proof.

Review skills loaded: `godot-code-review`, `dependency-injection`. No scripts were modified. No raw `.gd`, `.tscn` or `.tres` reads or caller/signal grep were used. Before creating this report, `file_context` on its exact path returned `File not found`, confirming it was a new report.

### Source Register

References below use exact file paths and function/constant anchors from successful structured reads. The tool did not return numbered source lines, so line numbers are not invented.

| Ref | Inspected source | Relevant anchors / observed implementation |
|---|---|---|
| S1 | `scripts/levels/main_game.gd` (798 lines) | `_ready`, `_begin_session_bootstrap`, `_composition_is_complete`, `_initialize_district_runtime`, `_initialize_projection`, `_initialize_time`, `_initialize_tenants`, `_initialize_economy`, `_initialize_prestige`, `_initialize_staff`, `_initialize_service_proxies`, `_initialize_arrivals`, `_initialize_save_manager`, `_validate_v2_authorities`, `_commit_v2_authorities`, `_apply_v2_authorities` |
| S2 | `scripts/session/session_bootstrap_coordinator.gd` (147 lines) | `begin`, `mark_authorities_ready`, `mark_projections_ready`, `commit_ready`, `fail`: explicit layout selection and lifecycle barrier |
| S3 | `scripts/session/content_registry.gd` (139 lines) | `initialize_production_catalog`, `resolve_layout`: explicit layout ID/path resolution, catalog sealing, Prestige policy validation; inspected registry stores layouts and Prestige policy |
| S4 | `scripts/simulation/time_manager.gd` (129 lines) | `VISITOR_TICK_INTERVAL=5.0`, `_process`, `_emit_crossed_boundaries`, `serialize`, `deserialize`: elapsed clocks, chronological catch-up and visitor/hour/day/week/month tie order |
| S5 | `scripts/autoloads/save_manager.gd` (440 lines) | `V2_ROOT_FIELDS`, `V2_AUTHORITY_FIELDS`, `configure_runtime`, `set_arrival_commit_gate`, `save_game`, `validate_v2_envelope`, `load_game`, `_restore_failure`, `_write_atomically` |
| S6 | `scripts/tenant/tenant_candidate_policy.gd` (85 lines) | `PROFILES`, `legal_profiles`, `select`: 25 Tier-1 profiles; subtype/neighbor/minimum-tile filtering; stable-hash modulo selection. This policy was read, but its complete caller integration was not traced |
| S7 | `scripts/simulation/synergy_manager.gd` (87 lines) | `recalculate`, `serialize`, `deserialize`: mutable `zone_scores` cache is serialized and imported |
| S8 | `scripts/simulation/prestige_manager.gd` (189 lines) | `initialize`, `create_monthly_candidate`, `commit_monthly_candidate`, `recalculate`, `commit_candidate`: H2 candidate methods do exist despite the older header/log wording; null-source recalculation rejects |
| S9 | `scripts/simulation/staff_manager.gd` (220 lines) | `hire`, `fire`, `paid_staff_weekly_snapshot`, `serialize`, `deserialize`: record-based staffing and wage inputs; serialization lacks `room_counter`; invalid restored references clear records |

## Findings

1. **High: composed save snapshots fail the composed Staff validator.** S1 `_serialize_v2_authorities` obtains S9 `serialize()`, which emits `schema_version`, `staff_revision`, `staff_counter`, `rooms`, `staff`, and `cleaning_tasks`, but not `room_counter`. S1 `_validate_v2_authorities` requires `staff.room_counter`. S5 `save_game` invokes envelope/owner validation before writing. This inspected path therefore rejects its own Staff snapshot with `AUTHORITY_FIELD_MISSING`, including an empty roster. This is a source-proven integration mismatch, not an executed save test. It blocks claiming P04/A12 round-trip success.

2. **High: restore mutates live owners rather than staging a replacement authority set.** S1 `_commit_v2_authorities` captures previous data, calls `_apply_v2_authorities` on existing owner instances and, on failure, calls `_apply_v2_authorities(previous)` without checking that rollback result. `_apply_v2_authorities` replaces the live District session, then deserializes the other live managers before rebuilding projections. S5's detached dictionaries and barrier flag do not change the injected callback's behavior. This conflicts with ADR 33 `:38` and ADR 34 `:22,39`: candidate-owned imports and derived reconstruction before live publication. S5 `_restore_failure` reports `old_session_preserved=true` without proof that S1's rollback succeeded. Fault outcomes remain PENDING; the claim is not supported by the inspected integration.

3. **High: the common calendar/save mutation boundary is not enforced by the inspected paths.** S4 `_process` advances clocks to the end of the frame before synchronously emitting each crossed boundary. S5 `save_game` checks whether the Arrival gate is held, but does not acquire a shared capture gate or check a calendar phase-chain barrier. S1 `_initialize_time` and `_initialize_economy` wire synchronous boundary callbacks directly. A save requested during boundary publication is not rejected by these inspected paths merely because the chain is incomplete; its elapsed timestamp can be ahead of the already-settled owner boundaries. This is a source-level reentrancy risk against ADR 33 `:32-38` and ADR 34 `:39`, not an executed reproduction or a declaration about every uninspected gate.

4. **High: the reserved synergy payload conflicts with the current V2 contract.** S1 `_serialize_v2_authorities` uses S7's `{"zone_scores": ...}` and `_validate_v2_authorities` requires `zone_scores`. ADR 33 `:49` instead requires exactly `{"schema_version":1,"mode":"derived_only"}` and rejection of other payloads before staging. The inspected serializer/validator accepts the wrong shape and rejects the mandated one.

5. **Product cutover is not demonstrated by this composition.** S1 `_ready` calls `_initialize_service_proxies`; that method connects Tenant proxy publication to Visitor consumption through PublicRealm proxy anchors. `_apply_v2_authorities` refreshes proxy snapshots after load. This is positive evidence of the inspected foundation proxy integration, not filename inference. ADR 34 permits a reproducible proxy engineering checkpoint, but not treating that checkpoint as P08/P09 Product runtime or no-proxy cutover evidence. No claim is made that alternate/uninspected Service implementations are absent.

6. **Monthly Prestige implementation and live reachability must be distinguished.** S8 has monthly candidate calculation and commit methods. S1 `_initialize_prestige` initializes the official snapshot and synchronizes TechTree on tier changes; the inspected root does not supply a monthly developed-tile source or directly orchestrate post-commit milestone reconciliation. Thus the old MainGame log saying H2 is unavailable is not proof H2 code is absent, and detached H2 methods are not proof the 100/300-tile normal-play route works. Full callers were tier-locked; P03/A04 remains PENDING.

7. **The readiness barrier has incomplete failure propagation in the inspected root.** S1 `_initialize_projection` can return after failed traffic rebuilding while all fields checked by `_composition_is_complete` are non-null. `_composition_is_complete` checks selected references and District session existence, not each initialization result or matching projection revisions; `_ready` then marks both barriers ready. S2 correctly requires the two flags, but trusts its caller. A fault-injection test is still needed to establish the actual affected failure cases; source inspection does not support the complete-ready-or-preserved-old-state acceptance claim.

## P01-P09 Conformance

**VERIFIED** means the named bounded obligation has direct supporting evidence, not release acceptance. **PARTIAL** means inspected implementation supports some obligations but gaps or untested integration remain. **NOT VERIFIED** means insufficient inspection/evidence, not absent code. **BLOCKED** means an attempted verification could not proceed. No complete work package earns VERIFIED here; startup verification is BLOCKED as recorded below.

| Package | Status | Exact source evidence | Remaining acceptance / limitation |
|---|---|---|---|
| P01 Session/content/clock, Economy/Progression, District transactions | PARTIAL | S1 `_begin_session_bootstrap` uses explicit configuration and S3 registry; S2 `commit_ready` provides lifecycle checks. S4 catch-up and elapsed-clock persistence are implemented. S1 `_initialize_district_runtime` constructs actual Economy/Zone/Progression ports, configures District and creates a session | Findings 3/7; Economy and District transaction bodies, stale/fault atomicity, prices/rights, no-fallback faults and deterministic settlement were not fully inspected or exercised. A01/A02 PENDING |
| P02 Geometry/projection/public graph/construction/camera/traffic/arrivals | PARTIAL | S1 `_initialize_projection` initializes/rebuilds Projection, PublicRealm, CameraGateway and TrafficTopology; `_initialize_arrivals` injects graph/gateway snapshots, VisitorManager and demand owner; `_initialize_walls` configures ManualDoorAuthority and WallManager. Scene tree confirms the corresponding authored owner nodes | Geometry/construction bodies, crossing phase/clearance, 10% wall clipping, camera union, active cap, failed-picking protection and cross-floor correctness not verified. No preview/visual evidence. A03/A11/A14 PENDING |
| P03 Prestige/spatial/Tenant/Visitor/Staff/progression/controls | PARTIAL | S1 `_initialize_tenants`, `_initialize_economy`, `_initialize_staff`, `_initialize_service_proxies` show actual foundation wiring. S8 provides monthly candidates and official snapshots. S9 implements record-based staffing and weekly wage inputs | Finding 6; no complete spatial/commercial/Economy/UI implementation review and no normal-play unlock, rent, payroll or controls test. A04/A05/A06 PENDING |
| P04 Foundation save/restore and gate | PARTIAL | S5 exact V2 envelope and callback orchestration are integrated via S1 `_initialize_save_manager`; full participating owner serializers are called in S1 | Findings 1-4 prevent conformance signoff. No V2 round-trip, all-owner fault matrix, leak/candidate-disposal or foundation scenario result. A12/A13 PENDING |
| P05 Interior content/feasibility/layout | NOT VERIFIED | S3 production registry body and S6 Tier-1 policy were inspected. Those sources establish layout/Prestige and commercial catalog scaffolding, not fixture/layout programs | No complete interior content or feasibility implementation inspected. No minimum-fit/default-visual proof, golden manifest, or indeterminate/infeasible test. Do not infer absence from the inspected registry or directory tree |
| P06 Core/annex/Anchor/exclusive queues | NOT VERIFIED | S1 proves Zone and door owners are composed, but no interior geometry algorithm was inspected | No prospective preservation/leftover/stable-ID/queue-geometry evidence. Existing Zone ownership is not proof of interior H2 conformance; all new geometry acceptance PENDING |
| P07 Feasible selection/lifecycle provenance | NOT VERIFIED | S6 `legal_profiles` uses minimum tiles and DebugBusinessSubtypeCatalog entries; `select` uses stable-hash modulo. S1 `_initialize_tenants` establishes a Tenant owner, not the selected policy's full runtime path | Inspected S6 alone does not establish physical feasibility, 6/3/1 draw classes, interior provenance or integrated binding. Alternate policies and Tenant internals not fully inspected. Detached/integrated H3 outcomes PENDING |
| P08 Service/Visitor runtime | NOT VERIFIED | S1 `_initialize_service_proxies` and `_on_service_proxy_snapshot_published` explicitly wire foundation proxy service | No Product Service owner integration, nine typology traces, FIFO/wait parity, phase/batch cases, historical goals or 200-active performance verified. A07-A11 PENDING. ADR 34 A1/A2 need Design review |
| P09 Schema/projection/UI/candidate cutover | PARTIAL | S5 contains exact V2 root/authority registry; S1 binds save callbacks and performs projection rebuilds. S1 retains proxy composition and post-load proxy refresh | Foundation scaffolding only, not H5 conformance. Findings 1-5; no three-local-schema/canonicalization review, capability selection proof, interior visuals/queues, or no-proxy Product acceptance. A12-A15 PENDING; A3 Design review PENDING |

P10 same-candidate Product acceptance and P11 external release are outside this implementation sample and remain PENDING. None of A01-A16 is promoted to PASS by this report.

## Existing Checks

Executed without implementation changes:

```text
godotiq_verify_project_runs(scene="main", check_scope="project",
                          stop_after=true, settle_seconds=3)
verdict: FAIL
phase: script_check
scripts_checked: 188
errors: 9
```

The tool returned `Script reload failed (error 22)` for each source below, with `confidence="low"`, `line=null`, and `line_unavailable=true`:

| Source |
|---|
| `res://scripts/grid/floor.gd` |
| `res://scripts/projection/projection_editor_source.gd` |
| `res://scripts/projection/projection_preview.gd` |
| `res://scripts/projection/projection_preview_controller.gd` |
| `res://scripts/public_realm/public_realm_descriptor_builder.gd` |
| `res://scripts/resources/district_layout_definition_loader.gd` |
| `res://scripts/resources/district_layout_fixture_factory.gd` |
| `res://scripts/resources/district_layout_resolver.gd` |
| `res://scripts/resources/district_state_records.gd` |

This is an observed failed preflight, not nine independently diagnosed source syntax errors. The check's reload codes carry no parser text or line attribution. The tool recommended fixing/checking scripts before Play; no reload/reset/edit workaround was performed within this non-code audit.

`read_debug_console(limit=20)` immediately afterward returned capture enabled for runtime/script errors, zero entries, zero totals and `game_running=false`. An empty console does not negate the preflight failures. Play/startup was **BLOCKED / NOT RUN** because verification exited at preflight. No runtime behavior, motion, visual, save/load or performance checks were performed. The game remained stopped, as initially observed.

Raw tool responses are in the audit conversation; no separate raw-log artifact or checksum was produced under this one-report write allowance. This embedded result is a bounded engineering record, not the complete candidate-bound artifact package required by MVP H4 `:91-95`.

## Disposition

P00 has a usable but incomplete reconciliation sample, with concrete owner-integration findings and a failed existing preflight. Complete-project conformance remains NOT VERIFIED: nine script bodies and a depth-limited scene tree are not an audit of all 189 scripts/20 scenes. Full dependency/signal target analysis was BLOCKED by community-tier access. Uninspected systems are not declared absent.

The next implementation phase should reconcile the cited save/schema, shared-gate and bootstrap failure-propagation paths, then obtain a clean candidate-bound compiler/startup result before claiming foundation regression or Product acceptance. This report authorizes and performs no such changes. Revised behavior, interior content/fit, visual acceptance, Design A1-A3, physical performance, exports and independent signoffs all remain PENDING.
