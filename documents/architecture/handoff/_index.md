# Architecture Handoff Index

Architecture handoffs are organized into focused implementation programs. Each program owns its ordered handoff sequence, approval record, and implementation gates.

**Current revision:** 2026-09-08, delegated documentation approval. Start with [Current MVP](../../game_design/current_mvp.md), [ADR 33](../decisions/33_documentation_consistency_and_minimum_contracts.md), then [MVP H1 implementation order](mvp/01_implementation_sequence_and_scope.md). The older central blueprint and migration "current-state findings" are history, not an implementation audit.

## Readiness

**Design A1/A2 decisions and A3 reset acknowledgement: PENDING.** See the [Product Design decision register](../evidence/product_mvp/_index.md#design-decision-register). Architecture approval is not approval of open gameplay interpretations. Unaffected engineering may proceed; A1 exterior-only expected wait and A2 shared cafe/food-court cohort counter semantics must be confirmed before locking affected implementation or acceptance.

**Follow-on review, 2026-09-08:** [ADR 34](../decisions/34_product_mvp_runtime_and_cutover.md) separately approves interior H4/H5 after the earlier consistency pass. [MVP H4](mvp/04_product_delivery_and_acceptance.md) records delivery/acceptance obligations. Foundation -> detached interior H1-H3 -> H4 implementation passes -> H5 candidate cutover passes -> Product acceptance; external Gate R is separate. Documentation approval alone activates nothing.

| Work | Documentation status | Implementation boundary |
|---|---|---|
| Foundation programs below, MVP H1-H3 | Approved, including explicit 2026-09-08 amendments | Ready in MVP H1 dependency order; predecessor implementation evidence still required |
| `tenant_interiors/H1-H3` | Approved | Detached planning, prospective geometry and candidate/lifecycle contracts ready; no live runtime or schema cutover |
| `tenant_interiors/H4-H5` | Architecture-approved 2026-09-08, follow-on review | H4 follows detached H1-H3; H5 follows H4 implementation passes. Runtime implementation/candidate cutover NOT VERIFIED; no live activation from documentation approval |
| `district_layout/H4` | Approved contract | Runtime and preview tests reported passing; formal full-preview acceptance not recorded; no inferred acceptance |
| `district_layout/H10` | Approved engineering/release contract | Engineering complete; H10 release acceptance pending external Gate R |
| Product MVP | Approved target and delivery contract; acceptance PENDING | H4 implementation and H5 candidate cutover passes required before Product acceptance. External Gate R remains separate and PENDING; not release-ready |

IDs are program-local. Use `district_layout/H4`, `tenant_interiors/H4`, or `zone_parcels/H4` outside their own program; a bare H4 never orders another program. In inherited prose, an unqualified local H number means its containing folder only; explicit named program prefixes take precedence.

## Programs

| Program | Scope | Index |
|---|---|---|
| Zone and Parcels | Zone painting and mutation, parcel splitting and debug assignment, parcel walls/doors, and zone/parcel debug projections. | [Zone and Parcel Handoff Index](zone_parcels/_index.md) |
| District Layout | District definitions, resolution, state, runtime projection, public realm, traffic, visitor arrival, persistence, and legacy cutover. | [District Layout Handoff Index](district_layout/_index.md) |
| Economy | Session financial authority, transaction safety, policy snapshots, recurring financial boundaries, and later pricing/refund policy. | [Economy Handoff Index](economy/_index.md) |
| Progression | Prestige/Tech-derived eligibility, Plot Access selection, elevation availability, and progression snapshots for transactions. | [Progression Handoff Index](progression/_index.md) |
| Tenant | Tenant occupancy lifecycle, legal seeded candidate selection, rent-input snapshots, and later business-performance handoffs. | [Tenant Handoff Index](tenant/_index.md) |
| Tenant Interiors | Subtype/fixture content, parcel feasibility, procedural layouts, candidate weighting, runtime service, queues, visitor interaction, persistence, and Product MVP cutover. | [Tenant Interiors Handoff Index](tenant_interiors/_index.md) |
| Prestige | Official tier/rent-ceiling publication, future calculation inputs, and consumers across Tenant and Progression. | [Prestige Handoff Index](prestige/_index.md) |
| Spatial Evaluation Inputs | Revisioned topology and zone-relationship facts plus pure rent recommendation for tenant evaluation. | [Spatial Evaluation Inputs Handoff Index](spatial_evaluation/_index.md) |
| Session | Gameplay composition, authoritative calendar/content bootstrap, full atomic V2 restore, and MVP acceptance gate. | [Session Handoff Index](session/_index.md) |
| Visitor | Corridor-door proxy service behavior, realized-visitor lifecycle, and operational visitor metrics. | [Visitor Handoff Index](visitor/_index.md) |
| Presentation | Read models, player intent gateway, diagnostics, source-gated panels/heatmaps, and notifications. | [Presentation Handoff Index](presentation/_index.md) |
| Staff | MVP Operations Room, cleaner/security records, coverage/task facts, and weekly payroll inputs. | [Staff Handoff Index](staff/_index.md) |
| Construction | MVP interior circulation, vertical links, Operations Rooms, placement transactions, and topology publication. | [Construction Handoff Index](construction/_index.md) |
| MVP Scope | Cross-program implementation order, testable player loop, exclusions, and end-to-end acceptance gate. | [MVP Scope Handoff Index](mvp/_index.md) |

## Repository-wide rule

Changes to approved contracts require recorded approval. The user delegated that approval for the 2026-09-08 documentation consistency pass; dated revision blocks and ADR 33 explicitly identify amendments. No prior approval date, implementation PASS, evidence signer or Gate R result is fabricated. Future changes still require explicit approval.

Owner/invariant/input/output/failure/acceptance clauses are binding. Legacy examples of classes, helper layering, signals, directories and broad skill lists are illustrative unless an active ADR genuinely requires them. Do not build extra abstractions merely to match an old file-layout sketch. Older migration findings and temporary-adapter steps are historical; target implementation must not recreate removed compatibility paths.
