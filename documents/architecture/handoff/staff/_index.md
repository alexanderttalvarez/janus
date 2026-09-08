# Staff Handoff Index

This index records the approved Staff architecture handoffs and their implementation gates.

**Current revision:** 2026-09-08, delegated documentation pass. H1 is revised/approved under ADR 33 and [MVP H3](../mvp/03_foundation_integration_clarifications.md): employment/coverage records, durable due rosters and whole-week mandatory payroll. Cleaning-task facts and task-specific acceptance are deferred; no task/agent system blocks this handoff. `construction/H1` already approves physical Operations Room placement.

| Order | Handoff | Status | Scope |
| --- | --- | --- | --- |
| 01 | [Employment, Coverage and Wages](01_cleaning_security_and_wages.md) | Approved 2026-09-05; revised 2026-09-08 | Operations Room hire/fire, independent Cleaner/Security capacities, coverage, durable due-week payroll input and atomic V2 restore; no cleaning tasks. |

## Program boundary

- This program does not approve Operations Room construction pricing, bins, maintenance, tenant-satisfaction or Prestige effects, staff agents, pathfinding, patrols, animations, or other visual presentation.
- `EconomyManager` remains the sole balance authority. Staff supplies immutable payroll facts; it never debits player funds.
- Future staff handoffs require approval before adding policy, gameplay values, or cross-system consequences.
