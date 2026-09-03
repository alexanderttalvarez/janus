# Selected Release and Migration Policies

These selections were approved by the project owner after the pre-H10
evidence review.

## H6 camera policies

| Policy | Selection | Status |
| --- | --- | --- |
| Camera infrastructure margin | **B — road-profile-relative** | Approved; implementation record: `documents/architecture/handoff/district_layout/h6_policy_acceptance.md` |
| Legacy 20-purchased-tile rule | **A — remove at migration** | Approved; implementation record: `documents/architecture/handoff/district_layout/h6_policy_acceptance.md` |

## Performance policy

**Hybrid** — use baseline-relative comparison together with target-platform
absolute limits. Concrete target hardware, thresholds, and sampling protocol
remain to be supplied by Release/Architecture before final acceptance.

## Archive policy

**B — separate test pack** — archived fixtures and proof-only material remain
outside the production runtime package. Packaging and CI evidence remain to be
recorded before final acceptance.

## Approval record

Approval message: `H6: B/A, Performance: hybrid; Archive: B`.

This records policy selection only. It is not a substitute for the required
Architecture, Design, QA, and Release signoff assignments.
