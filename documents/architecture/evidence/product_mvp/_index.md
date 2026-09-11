# Product MVP Evidence Register

**Disposition, 2026-09-08:** Architecture documents approved under [ADR 34](../../decisions/34_product_mvp_runtime_and_cutover.md); Design A1/A2 decisions recorded below; A3 reset acknowledgement PENDING; implementation acceptance PENDING; Product acceptance PENDING; external district Gate R PENDING. This is a tracking template plus a linked bounded audit, not a fabricated test report.

Return to [evidence index](../_index.md). Requirements and test definitions: [MVP delivery/acceptance](../../handoff/mvp/04_product_delivery_and_acceptance.md). Historical district claims remain in their [own package](../district_layout_acceptance/_index.md).

## Observed evidence

- [Current P00 reconciliation](p00_reconciliation_65614da.md): candidate `65614da981244ad62da8f6430d725e1c6e9a07bb`, clean initial tree. Direct Play and standalone headless startup reached ready with no debugger/parser/runtime errors, superseding the older Play-blocked observation. The nine low-confidence reload entries persist as a GodotIQ reload artifact. P01-P04/P09 are partial; P05-P08 Product implementations are absent. A01-A15 remain PENDING.
- [P01 foundation gate evidence](p01_foundation_gate_2026-09-09.md): dirty worktree based on `65614da`; focused policy, session, District, Arrival and caller-compatibility suites pass, with paused-ready runtime verification and independent implementation review. The nine low-confidence GodotIQ reload entries remain; A01-A15 are still PENDING.
- [P02 District-Zone snapshot evidence](p02_district_zone_snapshot_2026-09-11.md): ADR 35/36/37 snapshot, local-state and coordinated Zone mutation suites pass on the dirty candidate; main-scene headless startup reaches paused-ready. Manual approval remains PENDING, so P03 has not started.
- [Bounded implementation audit](implementation_audit.md): nine source bodies and a depth-limited editor tree inspected through structured tools. Concrete save/schema, live-restore, shared-gate and bootstrap gaps identified. P00 is partial, not a complete project audit.
- Existing project preflight attempted: tool returned FAIL in script_check, 188 scripts checked, nine low-confidence reload failures without line attribution. Play was not reached. This does not diagnose nine syntax bugs and is not a runtime regression result. See the audit for sources, candidate limitations and preserved stopped-game state.
- No Product headless suite, visual acceptance, physical performance run, asset fit proof, export or independent signoff was produced in this documentation session. Do not turn source inspection into a behavioral PASS.

## Design decision register

These decisions are current gameplay authority for H4/H5 acceptance traces. They do not add spending, revenue, viability, or any other post-MVP economy behavior.

| ID | Decision | Disposition | Evidence/revision |
|---|---|---|---|
| D-A1 | Expected wait ends at exterior-to-abstract admission. Later internal checkout/device waits do not affect patience. | **DECIDED**, user confirmation 2026-09-08 | Current Product MVP; ADR 34; H4 |
| D-A2 | Café/food-court table cohorts share one counter-service stage, then the seated stage. Individual counter payments are explicitly **post-MVP**; Product service results remain non-economic. | **DECIDED**, user confirmation 2026-09-08 | Current Product MVP exclusions; ADR 34; H4 |
| D-A3 | Load preserves goals/results/cadence but resets commitments, FIFO position and elapsed service. | PENDING acknowledgement of approved reset scope | Not recorded |

D-A3 records acknowledgement of the documented reset limitation, not permission to quietly expand persistence. A future change to D-A1/D-A2 requires revision of ADR 34/H4 and affected traces before implementation of the changed behavior.

## Result registry

A01-A15 determine Product engineering/visual acceptance, subject to D-A3 acknowledgement. A16 is a separate external release prerequisite: pending A16 does not turn a passed Product test into a failure, and Product acceptance never implies A16 passed. All rows here remain PENDING.

| Test ID(s) | Required evidence group | Status | Candidate-bound artifact |
|---|---|---|---|
| A01-A03 | Startup, clock/atomicity, geometry | PENDING | Not supplied; audit findings are not PASS |
| A04-A06 | Normal-play unlocks, Tenant/rent, Staff/payroll | PENDING | Not supplied |
| A07-A09 | Nine typologies, FIFO/wait, batches/reload | PENDING | Not supplied; D-A1/D-A2 are decided |
| A10-A11 | Historical visitor provenance, cap/routes/topology | PENDING | Not supplied |
| A12-A13 | Save-state/fault matrix and lifecycle/leak parity | PENDING | Not supplied; audit reports source-level gaps |
| A14 | Visual/UI/content and Design interpretation review | PENDING | Not supplied |
| A15 | Same-candidate foundation regression and Product scenario | PENDING | Not supplied |
| A16 | External H10 release obligations | PENDING | Use existing H10 release package; no duplicate signoff |

Split grouped rows into individual result records when evidence exists. Every required test must have its own result; grouping never permits one passing example to stand for omitted cases.

## Copyable result record

- Test/decision ID and contract revision:
- Disposition: NOT RUN / BLOCKED / FAIL / PASS (select only after observation):
- Candidate commit, dirty-tree/patch digest and editor/disk equivalence:
- Content/layout/policy IDs, versions and hashes:
- Godot version, renderer, OS/platform and hardware where relevant:
- Seed, session setup, input sequence and reproduction steps:
- Executed command and exit code, or visual inspection steps:
- Expected outcome:
- Actual observed outcome:
- Raw log/image/video/metric paths and checksums:
- Reviewer identity and actual observation timestamp:
- Coverage, limitations and unresolved failures:
- Affected prior results invalidated by this revision:

Blank fields remain blank until factual data is supplied. A screenshot alone cannot prove exactly-once settlement; a text assertion alone cannot prove visual clearance. Keep raw artifacts tied to the same candidate as results. H10 hardware thresholds and signoff requirements remain owned by its existing contract, not this template.

## Independent acceptance

| Role | Required review | Status |
|---|---|---|
| Design | D-A3 reset disclosure; actual capacity/queue/normal-play presentation | PENDING, no signer recorded |
| QA | A01-A15 complete same-candidate artifacts and errors/regressions | PENDING, no signer recorded |
| Architecture | Revised owner/atomicity/persistence conformance against actual candidate | PENDING independent candidate review; ADR approval is not this signoff |
| Release | Exports, artifact binding and H10 external Gate R review | PENDING, no signer recorded |

## Documentation validation

The final documentation-only QA summary belongs in the delivery report, not the gameplay result rows above. Link/whitespace checks do not test the game. Preserve prior evidence unchanged; append superseding records with new candidate/revision provenance rather than relabeling historical PASS.
