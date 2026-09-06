# H10 Readiness Blockers

Executable adapter boundary removal is complete. H10 acceptance remains blocked by incomplete evidence, not by an unselected architecture.

## Defined release-evidence policy

`../signoff/h10_release_evidence_contract.md` now fixes the Hybrid R1 target hardware, absolute and relative budgets, sampling protocol, warning/leak gate, Archive Policy B package/CI proof, GridManager classification, and signoff protocol.

## Evidence still required

- Run the RVR-1 benchmark and repeated-cycle workload; retain raw samples, console logs, baseline comparison, and derived report.
- Fix and rerun every suite that emits ObjectDB/resource-leak warnings. The
  previously observed H8, traversal, staff, tenant, visitor-proxy,
  rent-settlement, and zone-tool leaks are cleared; the remaining broad-suite
  warning audit includes the intentional state-machine negative-transition
  diagnostic.
- Implement/run CI proof for the separate production export and test pack, including checksums, manifests, zero-reachability audit, forbidden-content scan, and retained job logs.
- Complete the H10 coverage matrix with named static/dependency/behavioral evidence for every row.
- Record H4 lifecycle, H5 frontage/public-band, H7 Fixture C graph/cleanup/clock, H8 fault-boundary/cleanup, and H9 staged-failure/repeated-cycle evidence.
- Assign independent Architecture, Design, QA, and Release signers and record approvals in `../signoff/README.md` against the final candidate manifest.

## GridManager release status

`GridManager` is archive-only retired legacy authority. It cannot remain in production reachability or supply omitted identity, geometry, mutation, or V2 fallback. Its retention is allowed only inside the separately packaged test pack while named regression suites require it.

## Required next action

Produce the above evidence at one candidate commit, then run the final H10 acceptance gate. Do not mark H10 accepted based on policy definition alone.
