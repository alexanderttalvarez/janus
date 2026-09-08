# Economy Handoff Index

This index records the ordered Economy architecture handoffs and their implementation gates.

**Current revision:** 2026-09-08, delegated documentation pass. H1/H2 remain approved as explicitly amended by element 03, ADR 33 and [MVP H3](../mvp/03_foundation_integration_clarifications.md): complete pricing/no-refund policy, whole-week mandatory payroll and source-owned balance conditions. [Current MVP](../../../game_design/current_mvp.md) excludes loans/transport operation and playable multi-Plot expansion; no pending pricing question blocks the approved foundation.

## Ordered handoffs

| Order | Handoff | Architecture status | Scope / gate |
|---:|---|---|---|
| 01 | [Transaction Authority and Policy Boundary](01_transaction_authority_and_policy_boundary.md) | Approved — 2026-09-03 | Establishes Economy's sole balance authority, policy-snapshot boundary, quote/reserve/guaranteed-capture/cancel contract, debug-free-cost behavior, recurrence boundaries, and persistence exclusion for transient tokens. Required before District Layout H3 production transaction work. |
| 02 | [Expansion Pricing and Refund Policy](02_expansion_pricing_and_refund_policy.md) | Approved — 2026-09-03 | Centralizes tunable approved prices for Plot Sections, vertical floor tiles, Street Segment conversion, and eligible demolition; defines no-refund/no-reversal MVP policy. Consumes but does not define progression gates. |

## Rules

- Handoff 01 does not approve new prices, formulas, refunds, demolition, expansion gates, tenant lifecycle, maintenance, or transport operations.
- Handoff 02 approves only the listed expansion price/refund policy; it does not approve progression gates, construction-cancellation refunds, tenant eviction, transport, or maintenance.
- Economy consumes price and progression policy snapshots; it never invents missing policy.
- Any paid cross-authority transaction must use the approved Economy transaction port. Direct balance writes are prohibited.
- Any change to an approved handoff requires architecture review and user approval before implementation.
