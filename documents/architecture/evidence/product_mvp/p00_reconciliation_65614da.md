# P00 Reconciliation — Candidate 65614da

## Candidate

- Commit: `65614da981244ad62da8f6430d725e1c6e9a07bb`
- Branch state at observation: `main`, two commits ahead of `origin/main`
- Initial worktree: clean
- Engine: Godot `4.7.stable.official.5b4e0cb0f`
- Editor project: `/home/aelxan/Programming/Games/janus/`
- Main scene: `res://scenes/levels/main_game.tscn`
- Original and final game state: stopped

This record verifies the P00 classification only. It is not a PASS for any Product acceptance row.

## Preflight Diagnosis

`godotiq_check_errors(scope="project")` still reports nine line-less, low-confidence `Script reload failed (error 22)` entries across 188 scripts. Focused checks reproduce the same reload result without parser diagnostics.

The failures are not demonstrated syntax errors:

- GodotIQ Play successfully started the main scene and attached to runtime.
- `GameManager.session_ready` became true and the game reached `MainGame: Ready.`
- The GodotIQ debugger contained zero script and zero runtime errors.
- A separate `godot --headless --path <project> --quit-after 180` run also reached `MainGame: Ready.` without parser/runtime failures.
- Structured reads of all nine reported scripts succeeded.

Disposition: **tool/editor reload artifact**, with the exact reload/cache mechanism still undiagnosed. The old claim that Play is blocked is superseded for this candidate; the GodotIQ aggregate preflight itself remains unreliable until its reload behavior is corrected.

## Confirmed Integration Findings

1. `scripts/simulation/staff_manager.gd` serialization omits `room_counter`, while `scripts/levels/main_game.gd` requires it during composed V2 validation.
2. `scripts/levels/main_game.gd` restore applies snapshots to existing live owners and attempts unchecked rollback instead of publishing an isolated candidate session.
3. Save/load checks only the Arrival gate; calendar publication, coherent capture, and live-session replacement do not share ADR 33's session-scoped non-reentrant gate.
4. Synergy serializes mutable `zone_scores`; ADR 33 requires exactly `{"schema_version":1,"mode":"derived_only"}`.
5. MainGame explicitly composes Tenant/Visitor proxy service. No Product Service owner is wired.
6. Session readiness checks references rather than successful matching-revision projection results, so some initialization failures can still reach the readiness marks.

Existing detached tests do not close these composition gaps: their synthetic save payloads use the old Synergy shape and supply an invented Staff `room_counter`; detached restore tests commit to a test dictionary rather than MainGame's owner set.

## Package Classification

| Package | P00 disposition | Evidence boundary |
|---|---|---|
| P01 | PARTIAL | Explicit content, clock, Economy/Progression ports and District foundation exist; shared-gate and readiness failure propagation are incomplete. |
| P02 | PARTIAL | Zone/projection/public-realm/construction/camera/traffic/arrival foundations and tests exist; complete Product integration and acceptance coverage remain unverified. |
| P03 | PARTIAL | Prestige/spatial/Tenant/rent/proxy Visitor/Staff foundations exist; normal-play awards/actions and revised payroll contract are not integrated. |
| P04 | PARTIAL | V2 envelope/staging infrastructure exists; Staff, Synergy, live-candidate restore and common-gate defects block conformity. |
| P05 | ABSENT | No Product immutable interior content, feasibility/layout programs, golden manifests, or corresponding tests were found. |
| P06 | ABSENT | No Product core/annex/Anchor or exclusive queue-geometry implementation/tests were found. |
| P07 | ABSENT | No physical-feasibility selection or interior lifecycle provenance exists; current selection is foundation tile-count policy. |
| P08 | ABSENT | No Product Service owner, nine-typology phases/batches/wait runtime, or 200-active Product workload exists. Existing proxy behavior is a superseded target. |
| P09 | PARTIAL | Foundation V2/projection/UI scaffolding exists; Product local schemas, deterministic interior rebuild, reset disclosure, presentation and no-proxy cutover are absent. |

P10 and A01–A15 remain **PENDING**. No historical PASS transfers to this candidate.

## Focused Checks

- Direct GodotIQ Play: started successfully; zero debugger errors; stopped afterward.
- Standalone headless main-scene startup: reached ready without parser/runtime failure.
- Completed focused foundation test scripts observed with zero failures: Session H1/H2, Save H9, Staff H1/payroll, Visitor proxy H1, camera H6, construction, daily rent, district definition/runtime/traversal, legacy removal, policy contracts, presentation, Prestige H1/H2, projection preview, public realm, resolved district model, spatial inputs, Tenant H1-H3, traffic H7, and visitor arrivals H8.
- The broad shell test sweep exceeded its time limit when scene-driven tests were invoked as standalone scripts. Those uncompleted tests are not counted as PASS.

## Limitations

- No Product interior acceptance suite, save-state matrix, visual QA, 200-active Product workload, or leak cycle was available.
- GodotIQ dependency/reverse-import detail was community-tier locked.
- No Product acceptance result, Design signoff, or external Gate R result is inferred.
