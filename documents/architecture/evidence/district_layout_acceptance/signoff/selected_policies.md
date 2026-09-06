# Selected Release and Migration Policies

These selections were approved by the project owner after the pre-H10 evidence review.

## H6 camera policies

| Policy | Selection | Status |
| --- | --- | --- |
| Camera infrastructure margin | **B — road-profile-relative** | Approved; implementation record: `documents/architecture/handoff/district_layout/h6_policy_acceptance.md` |
| Legacy 20-purchased-tile rule | **A — remove at migration** | Approved; implementation record: `documents/architecture/handoff/district_layout/h6_policy_acceptance.md` |

## H10 release policies

| Policy | Selection | Binding contract |
| --- | --- | --- |
| Performance | **Hybrid R1** — RVR-1 absolute limits plus same-hardware relative regression limits | `h10_release_evidence_contract.md` §§1 and 2 |
| Archive | **B — separate test pack** — zero production reachability, manifest and CI proof required | `h10_release_evidence_contract.md` §3 |
| GridManager | **Archive-only retired legacy authority**; no production identity, geometry, mutation, or serialization fallback | `h10_release_evidence_contract.md` §4 |
| Signoffs | Architecture, Design, QA, and Release; independent, commit-bound approvals | `h10_release_evidence_contract.md` §5 |

## Approval record

- Initial policy selection: `H6: B/A, Performance: hybrid; Archive: B`.
- **2026-09-05:** Project owner approved the Hybrid R1, Archive Policy B, GridManager classification, warning/leak gate, and signoff protocol in `h10_release_evidence_contract.md`.

This is an architecture/policy approval. It does not substitute for completed measurements, CI artifacts, warning cleanup, signer assignments, or the four required candidate-specific release signoffs.
