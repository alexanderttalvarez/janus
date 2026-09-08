# Product MVP Evidence Register

**Disposition, 2026-09-08:** Architecture documents approved under [ADR 34](../../decisions/34_product_mvp_runtime_and_cutover.md); Design interpretations A1-A3 PENDING; implementation acceptance PENDING; Product acceptance PENDING; external district Gate R PENDING. This is a tracking template plus a linked bounded audit, not a fabricated test report.

Return to [evidence index](../_index.md). Requirements and test definitions: [MVP delivery/acceptance](../../handoff/mvp/04_product_delivery_and_acceptance.md). Historical district claims remain in their [own package](../district_layout_acceptance/_index.md).

## Observed evidence

- [Bounded implementation audit](implementation_audit.md): nine source bodies and a depth-limited editor tree inspected through structured tools. Concrete save/schema, live-restore, shared-gate and bootstrap gaps identified. P00 is partial, not a complete project audit.
- Existing project preflight attempted: tool returned FAIL in script_check, 188 scripts checked, nine low-confidence reload failures without line attribution. Play was not reached. This does not diagnose nine syntax bugs and is not a runtime regression result. See the audit for sources, candidate limitations and preserved stopped-game state.
- No Product headless suite, visual acceptance, physical performance run, asset fit proof, export or independent signoff was produced in this documentation session. Do not turn source inspection into a behavioral PASS.

## Design decision register

These are explicit pending interpretation decisions, not named people approving unseen behavior. Engineering may proceed on unaffected owner/content/capture infrastructure; do not lock contested service traces or ship them as Design-approved before resolution.

| ID | Interpretation requiring confirmation | Alternative that would change the contract | Decision | Reviewer/date/evidence/revision |
|---|---|---|---|---|
| D-A1 | Expected wait ends at exterior-to-abstract admission; later internal checkout/device wait is excluded | Include internal stages or estimate until final completion | PENDING | Not recorded |
| D-A2 | Café/food-court table cohorts share one counter stage and then seated stage, applying common partial-table rules | Per-person counter throughput or independent seat claims | PENDING | Not recorded |
| D-A3 | Load preserves goals/results/cadence but resets commitments, FIFO position and elapsed service | Exact in-flight continuation, requiring additional durable Service state | PENDING acknowledgement of approved reset scope | Not recorded |

D-A1/D-A2 can be decided before code; their visible consequences still require playtest acceptance. Do not invent a response. If a different meaning is confirmed, revise ADR 34/H4 and corresponding traces before implementation of that behavior. D-A3 records acceptance of the documented reset limitation, not permission to quietly expand persistence.

## Result registry

A01-A15 determine Product engineering/visual acceptance, subject to Design decisions. A16 is a separate external release prerequisite: pending A16 does not turn a passed Product test into a failure, and Product acceptance never implies A16 passed. All rows here remain PENDING.

| Test ID(s) | Required evidence group | Status | Candidate-bound artifact |
|---|---|---|---|
| A01-A03 | Startup, clock/atomicity, geometry | PENDING | Not supplied; audit findings are not PASS |
| A04-A06 | Normal-play unlocks, Tenant/rent, Staff/payroll | PENDING | Not supplied |
| A07-A09 | Nine typologies, FIFO/wait, batches/reload | PENDING | Not supplied; D-A1/D-A2 must be resolved |
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
| Design | D-A1/D-A2 decision; D-A3 reset disclosure; actual capacity/queue/normal-play presentation | PENDING, no signer recorded |
| QA | A01-A15 complete same-candidate artifacts and errors/regressions | PENDING, no signer recorded |
| Architecture | Revised owner/atomicity/persistence conformance against actual candidate | PENDING independent candidate review; ADR approval is not this signoff |
| Release | Exports, artifact binding and H10 external Gate R review | PENDING, no signer recorded |

## Documentation validation

The final documentation-only QA summary belongs in the delivery report, not the gameplay result rows above. Link/whitespace checks do not test the game. Preserve prior evidence unchanged; append superseding records with new candidate/revision provenance rather than relabeling historical PASS.
