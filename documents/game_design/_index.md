# Janus Design

**Current authority; reviewed 2026-09-08 under delegated documentation approval.**

**Follow-on review, 2026-09-08:** [ADR 34](../architecture/decisions/34_product_mvp_runtime_and_cutover.md) separately approves Tenant Interiors H4/H5 architecture after the earlier consistency pass. Foundation -> detached H1-H3 -> H4 implementation passes -> H5 candidate cutover passes -> Product acceptance; external Gate R is separate. Implementation/cutover remain NOT VERIFIED and Product acceptance/Gate R PENDING; no gameplay or numerical scope changes follow from this approval.

1. Read [Concept](concept.md) for the architectural creation fantasy and player experience.
2. Read [Current MVP](current_mvp.md) for the single current scope definition and deferred behavior.
3. Use the [element register](elements/_index.md) for player-facing rules and numerical authorities.
4. Continue at the [architecture entry point](../architecture/_index.md) for decisions, implementation order, and readiness.

The [status register](_status.md) tracks design agreement, not implementation. Agreed full-game design is not permission to implement a deferred feature. The concept's premise takes precedence; the explicitly superseding current MVP replaces its original flat prototype scope, not its pillars.

Historical discussion is retained in [archive](archive/_index.md) and is not an instruction source.
