# MVP Handoff 04: Product Delivery and Acceptance

**Status:** Approved work and evidence specification, 2026-09-08 follow-on non-code request. Architecture reference: [ADR 34](../../decisions/34_product_mvp_runtime_and_cutover.md). Complete implementation conformance remains NOT VERIFIED; the linked bounded P00 audit records partial findings and a failed preflight. Every acceptance test/visual/release result is PENDING unless linked to actual candidate-bound evidence. This document neither expands [Current MVP](../../../game_design/current_mvp.md) nor invents a completion percentage.

## Engineer entry and gate order

Read Current MVP -> ADR 33/34 -> [foundation sequence](01_implementation_sequence_and_scope.md) with [integration clarification](03_foundation_integration_clarifications.md) -> relevant program contracts -> [Product gate](02_product_mvp_tenant_interiors_scope.md).

```
Evidence-backed foundation reconciliation
  -> Corridor Service Integration Gate
  -> interior H1 content/planning -> H2 parcel geometry -> H3 candidate/lifecycle
  -> H4 runtime integration -> H5 save/presentation candidate cutover
  -> same-candidate foundation regression + Product headless/visual acceptance
  -> release decision with separate district H10 external Gate R
```

H4/H5 are now architecture-approved; implementation remains NOT VERIFIED, not established absent. Unaffected detached work can proceed while runtime evidence is pending. No live Product activation occurs until H4 and H5 predecessor evidence passes. District H4 preview acceptance remains unrecorded but does not block its approved runtime successors. H10 Gate R need not prevent isolated engineering; it must not be inferred from it.

## Work packages

Each package owns its changed domain only; cross-owner changes require the existing coordinator and contract review. Do not recreate retired adapters, implement deferred systems or tune away failing content. Each package returns a change inventory, cited contract revision, tests/results and residual risks. NOT VERIFIED does not mean code is absent.

| ID | Required outcome / authority | Prerequisite | Exit evidence | Implementation skills |
|---|---|---|---|---|
| P00 | Reconcile existing implementation against MVP H1 stages and ADR 33/34 without assuming historic PASS applies | Current docs and readable implementation | Per-contract verified/partial/absent/blocked map with source locations and candidate identity | godot-code-review, dependency-injection |
| P01 | Session/content/clock, Economy/Progression and District transactions | P00 | Explicit startup; deterministic boundary catch-up; stale/fault atomicity; prices/rights; no fallback | resource-pattern, dependency-injection, save-load, godot-testing |
| P02 | Zone parcels/doors, projection/public graph, construction, camera/traffic/arrivals | P01, MVP H1 branch order | Geometry preservation, legal cross-floor graph, crossings, active cap; runtime projection tests and separate preview evidence | scene-organization, camera-system, godot-testing |
| P03 | Prestige/spatial inputs, Tenant/rent, proxy Visitor, Staff/payroll, progression and controls | P01/P02; precise MVP H1 stages 5-7 | Normal-play awards and actions; exactly-once daily rent/weekly wages; source-backed presentation | state-machine, resource-pattern, godot-ui, godot-testing |
| P04 | Full foundation save/restore and integration gate | P01-P03 | V2 round-trip, all-owner fault matrix, no retained candidates; foundation scenario | save-load, godot-testing |
| P05 | Interior H1 immutable content and deterministic feasibility/layout | P04 for live content wiring; isolated tests may start earlier | Every listed subtype has minimum-fit proof/default visual specification; golden manifests; indeterminate versus infeasible | resource-pattern, assets-pipeline, godot-testing |
| P06 | Interior H2 core/annex/Anchor and exclusive queue geometry | P05 | Prospective transaction/preservation/leftover tests, stable IDs, no destructive indeterminate repair | resource-pattern, godot-testing |
| P07 | Interior H3 feasible selection and lifecycle provenance | P06 and Tenant commercial contracts | 6/3/1 draw proof separate from commercial score; bind/fault/round-trip; unchanged Open/rent | state-machine, resource-pattern, godot-testing |
| P08 | Interior H4 Service/Visitor runtime | P05-P07; ADR 34 A1/A2 interpretations reviewed with design before signing affected outcomes | Nine typology traces, FIFO/wait/batch/clock/topology tests, 200-active measurements | state-machine, ai-navigation, event-bus, godot-testing, godot-optimization |
| P09 | Interior H5 schema, projection/UI and candidate cutover | P08 | Complete save-state/fault matrix; deterministic rebuild; visible interiors/queues; no proxy capability | save-load, scene-organization, godot-ui, hud-system, godot-testing |
| P10 | Product acceptance on frozen candidate | P04-P09 | Same-candidate foundation regression, normal-play scenario, all typologies, visual/Design review | godot-testing, godot-optimization |
| P11 | External release package | P10 and H10 contract | Exports, artifact binding, physical performance and actual independent signoffs | export-pipeline, godot-optimization |

P00 now has a [BOUNDED implementation audit](../../evidence/product_mvp/implementation_audit.md), not a complete conformance result: nine source bodies and a depth-limited editor tree were inspected, with save/schema, live-restore, shared-gate and bootstrap findings. The earlier 2026-09-08 authoring session had a disconnected bridge and metadata-only context; the later connected audit on 2026-09-08 attempted preflight: FAIL at script_check, 188 scripts checked and nine low-confidence reload failures without line attribution. Play was not reached. These are not nine diagnosed syntax bugs or behavioral test results. P00 remains partial; full-project conformance is NOT VERIFIED. Do not infer absence, readiness or coding effort from metadata counts.

## Content authoring specification

No assets are created by this handoff. Content engineering/art owns authoring after contracts are accepted; code agents must not fabricate unapproved gameplay to make content fit.

- Catalogue: all operational subtypes listed in element 20, covering nine typologies, at least one Tier-1 candidate per subtype and stable distinct customer-facing themes where adjacency needs them.
- Fixture records: explicit occupied/clearance masks, rotations, interaction faces, tags, placement priority, required/repeatable/optional classification, capacity source and bounded default visual reference.
- Policy records: stable IDs/revisions, exact element-owned numeric values, normalized integer/tick units, legal token sources and finite transition graphs. No runtime defaults or Resource mutation.
- Authoring flow: definition and footprint -> immutable validation -> minimum-program fit proof for a listed core orientation -> preferred/annex/Anchor golden layout -> visual-bounds inspection -> versioned production registry entry.
- Reject unknown/missing IDs, invalid masks/tags/capacity, visual envelope mismatch, inconclusive minimum-fit proof and revision mismatches. Never increase a locked minimum or silently substitute proxy service.
- Changes to semantics require policy revision and regenerated golden cases. Shared visual variants cannot alter simulation footprints/capacity. Mandatory defaults are required; optional decoration/theme variants can be omitted.
- Export inclusion: production registry explicitly references required content. Proof fixtures remain separately identified; excluded production fixtures must not become fallback defaults. Verify exported resource resolution, not merely editor availability.

## Acceptance matrix

Every row is PENDING. Attach actual results in the [Product evidence register](../../evidence/product_mvp/_index.md); a checked box without artifacts is not PASS.

A01-A15 aggregate Product engineering/visual acceptance: all required results must be evidenced on the same candidate, including Design review. A16 is separate external district Gate R, not part of that Product aggregation. Pending A16 does not turn a passed Product test into a failure; Product acceptance never implies Gate R has passed or authorizes release without it. Design A1/A2 decisions and A3 reset acknowledgement remain PENDING; unaffected engineering may proceed, but A1 exterior-only wait and A2 shared cafe/food-court cohort counter semantics must be confirmed before locking affected implementation or acceptance.

| Test ID | Setup/action | Required observable result | Owner |
|---|---|---|---|
| A01 | New explicit production session, valid/invalid content | Complete ready state or preserved prior state/structured failure, no legacy fallback | Session/content |
| A02 | Pause/speeds and multi-boundary frames; save before/at/after boundaries | Correct ordinal/remainder/order, no duplicate rent/wages/awards, no split phase chain | Time/Session/Economy |
| A03 | Construct/edit/reject floors, zones, doors, parcels, queues and vertical links | Atomic ownership, preserved legal parcels, exclusive safe queues, indeterminate is not Unsuitable | District/Zone/Construction |
| A04 | 100 then 300 distinct developed tiles at monthly boundaries | 3 then cumulative 8 points exactly once; five core unlocks purchasable without debug | Prestige/Progression |
| A05 | Candidate commercial acceptance, fit-out, Open, rent, cancel | Physical selection separate from commercial score; unchanged deadline/rent with Service visual fault | Tenant/Economy |
| A06 | Zero/four staff, 100-Kred balance, week replay/load/fault | Zero consumed once; four cost 2000, balance -1900; original due roster settled once | Staff/Economy |
| A07 | All nine typologies, min/preferred capacity, partial groups | Correct capacity/token/occupancy/stage/release traces, no economics | Service |
| A08 | Full/zero exterior capacity, earlier queued claims, equal/excessive tolerance | No FIFO bypass; direct entry only when immediately legal; wait/live parity under frozen inputs | Service/Visitor |
| A09 | Arrival around cadence/turnover, active+next batches, repeated load | No third batch/off-cadence entry/retroactive completion; documented transient reset and stable cadence | Service/Time/Save |
| A10 | Historical availability changes, empty category, zero visitors | Original categories/policy/seed/ordinal validate without replacing goals or consulting current availability | Visitor/Save |
| A11 | 200 active across every state/floor; congestion and invalidated routes | Cap includes abstract occupants; no stale-edge traversal, overlapping queues or non-exit removal | Visitor/Service/public graph |
| A12 | Save every state; fault each validation/import/rebuild/write/pre-publication stage | Save does not cancel live service; canonical load and old session/slot preservation on failure | Session/Save |
| A13 | Destroy/rebuild/load cycles, cancel/supersede staging | Equivalent manifests, one loaded event, no growing roots/subscriptions/caches or stale session publication | Session/Projection |
| A14 | Minimum/preferred/oversized/annex/Anchor visuals and controls | Readable bounded interiors, legal doors/walls/queues, source-backed capacity/wait/batch/suitability, no debug-only route | Art/Presentation/Design QA |
| A15 | Frozen candidate Product scenario + foundation regressions | All included scope represented, proxy removed from Product runtime, no skipped row counted passed | QA |
| A16 | External H10 workloads/exports/reference hardware | Existing absolute/relative limits and actual four-party signoffs; no guessed hardware metrics | Release/independent reviewers |

## Reproducible normal-play Product scenario

Use an explicitly identified production layout and frozen catalogue/policies. Record seed, candidate, settings and inputs. Do not hard-code assumed world coordinates into this document.

1. Start paused through normal controls; construct legal circulation and zone space, view compatibility, adjust rent, and let a legal tenant reach Open. Show daily rent from tenancy only.
2. Develop 100 then 300 distinct qualifying tiles through legal affordable actions and normal time controls. At the appropriate monthly publications earn 3 then 8 cumulative points. Buy Advanced Zoning, Anchors, Stairs, Multi-Floor and Elevators for 8 total. No debug grants, altered time constants or free-cost bypass.
3. Construct a legal upper-floor route and an eligible Anchor footprint through the unlocked controls; demonstrate same/cross-floor visits and geometry-responsive interiors.
4. Use explicit reproducible scenario content/seeds to cover every typology, including queue rejection, partial cohorts, active/next batch, service invalidation and valid exit. Separate targeted fixtures may prove rare edge cases; they do not substitute for the normal-play unlock scenario.
5. Optionally hire/fire through an Operations Room and cross payroll; save/load while visitors occupy representative states. Show preserved goals/results/cadence and disclosed reset of transient service.
6. Capture visible capacity/queue/wait feedback, successful and rejected intents, wall/floor controls, diagnostics and save failure behavior. Finish with same-candidate regressions and error logs.

Do not assert all scenarios fit in a fixed real-time duration or all tenant subtypes fit concurrently on Ground. Use unlocked floors or separate explicit test scenarios while preserving one-candidate evidence binding.

## Evidence capture and independent review

For each row record: test ID; candidate commit and dirty-tree/patch digest; Godot version/render backend/platform; content/policy identities and hashes; setup/seed/input sequence; command and exit result or visual steps; raw-log/image/video paths and checksums; expected/actual outcome; reviewer/time; limitations. Failed/blocked/not-run are distinct. A new code/content revision invalidates affected results; rerun rather than relabel old evidence.

Performance follows the existing [H10 evidence contract](../../evidence/district_layout_acceptance/signoff/h10_release_evidence_contract.md), not invented limits. Add H4's representative 200-active workload, all typologies/states/floors, congestion/topology churn, save/load/rebuild and leak cycles; retain per-frame and service/route/wait metrics. Physical hardware, release exports and baseline comparison must actually be supplied.

Architecture documentation approval is recorded in ADR 34. It is NOT the independent Architecture Gate R signer. Design must explicitly confirm ADR 34 A1-A3 against visible behavior; QA must inspect actual artifacts; Release must bind the shipped candidate. Do not prefill signer identities, dates, hashes, FPS, commands run or PASS counts.

## Non-code completion boundary

Completed here: architecture review and corrected H4/H5, explicit tradeoffs/ownership/save/UI/content contracts, ordered engineering packages, acceptance cases and evidence templates. The later [BOUNDED P00 audit](../../evidence/product_mvp/implementation_audit.md) supplies partial source-level conformance findings and an attempted, failed preflight; it does not complete the project audit or reach Play. Still incomplete: full implementation conformance, Design A1/A2 decisions and A3 reset acknowledgement, asset creation/fit evidence, executable acceptance suites, visual acceptance, physical performance, exports and independent signoffs. These require further inspection, produced assets/a runnable candidate, or the actual responsible reviewer. No implementation or release readiness is inferred from this plan or bounded audit.
