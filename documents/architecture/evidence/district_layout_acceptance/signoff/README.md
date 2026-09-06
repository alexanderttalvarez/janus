# H10 External Release Signoff Register

Signoffs belong to Decision 32 **Gate R**, after Gate E produces a frozen candidate commit and evidence-manifest checksum. Unassigned names are expected during implementation and are not a coding blocker.

| Role | Assigned signer | Status | Candidate commit | Evidence manifest checksum | UTC timestamp |
| --- | --- | --- | --- | --- | --- |
| Architecture | Deferred to Release owner | Pending Gate R | — | — | — |
| Design | Deferred to Release owner | Pending Gate R | — | — | — |
| QA | Deferred to Release owner | Pending Gate R | — | — | — |
| Release | Deferred to Release owner | Pending Gate R | — | — | — |

The Release owner assigns four independent people after the candidate and evidence checksum exist. Implementation agents must not request these names as feature inputs or record approvals on another person's behalf.

A valid signoff records explicit `approve` or `reject`, name, role, UTC timestamp, exact commit, and exact evidence checksum. Four approvals are necessary but not sufficient: every Gate R technical artifact must also pass.
