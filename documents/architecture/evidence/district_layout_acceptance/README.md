# District Layout Acceptance Evidence

## Status

This directory contains the **H10 evidence-preparation record**. It is not an
H10 acceptance or release signoff. H10 implementation is complete; the
remaining acceptance evidence and formal signoffs are still outstanding.

**Reconciled 2026-09-08:** Engineering complete; H10 release acceptance pending external Gate R. Start at the [package index](_index.md). Existing results are retained claims, not rerun evidence; a frozen candidate binding and the external Gate R package are still required. ADR 33's new contract amendments are not proven by historical PASS summaries.

## Scope

- Record executable H1-H9 test results and current GodotIQ audit results.
- Record current runtime/performance observations.
- Identify evidence and policy gaps that still block H10 acceptance.

## Artifacts

| Area | Artifact | Purpose |
| --- | --- | --- |
| Proof | `proof/h1_h9_test_results.md` | Ordered H1-H9 test commands and results. |
| Audits | `audits/pre_h10_godotiq_baseline.md` | Static, signal, asset, scene, and runtime audit baseline. |
| Audits | `audits/h10_coverage_matrix.md` | H10 coverage rows and named behavioral evidence. |
| Audits | `audits/h10_policy_manifest.md` | Production and Archive Policy B manifest audit. |
| Migration | `migration/readiness_blockers.md` | Missing approvals, evidence, and policy decisions. |
| Migration | `migration/h10_implementation_progress.md` | Implemented H10 boundary removals and current validation status. |
| Performance | `performance/runtime_baseline.md` | Historical initial runtime metrics; not the selected Hybrid R1 acceptance baseline. |
| Signoff | `signoff/README.md` | Required roles and signoff status. |
| Audits | [Static audit](audits/h10_static_audit.md) | Removal/search claims. |
| Performance | [Headless diagnostic benchmark](performance/rvr1_headless_benchmark.md) | Local workload, not rendered release qualification. |
| Signoff | [Release evidence contract](signoff/h10_release_evidence_contract.md) | Selected budgets, workload, artifacts and independent signoffs. |

## Selected policies

The selected H6, performance, and archive policies are recorded in
`signoff/selected_policies.md`.

## Acceptance boundary

H10 release acceptance remains pending external Gate R evidence/signoffs. Policy choices are recorded; absence of physical hardware, templates, credentials or signers is not an implementation-input blocker under ADR 32.
