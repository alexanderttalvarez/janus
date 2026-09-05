# Architecture Handoff Index

Architecture handoffs are organized into focused implementation programs. Each program owns its ordered handoff sequence, approval record, and implementation gates.

## Programs

| Program | Scope | Index |
|---|---|---|
| Zone and Parcels | Zone painting and mutation, parcel splitting and debug assignment, parcel walls/doors, and zone/parcel debug projections. | [Zone and Parcel Handoff Index](zone_parcels/_index.md) |
| District Layout | District definitions, resolution, state, runtime projection, public realm, traffic, visitor arrival, persistence, and legacy cutover. | [District Layout Handoff Index](district_layout/_index.md) |
| Economy | Session financial authority, transaction safety, policy snapshots, recurring financial boundaries, and later pricing/refund policy. | [Economy Handoff Index](economy/_index.md) |
| Progression | Prestige/Tech-derived eligibility, Plot Access selection, elevation availability, and progression snapshots for transactions. | [Progression Handoff Index](progression/_index.md) |
| Tenant | Tenant occupancy lifecycle, legal seeded candidate selection, rent-input snapshots, and later business-performance handoffs. | [Tenant Handoff Index](tenant/_index.md) |
| Prestige | Official tier/rent-ceiling publication, future calculation inputs, and consumers across Tenant and Progression. | [Prestige Handoff Index](prestige/_index.md) |
| Spatial Evaluation Inputs | Revisioned topology and zone-relationship facts plus pure rent recommendation for tenant evaluation. | [Spatial Evaluation Inputs Handoff Index](spatial_evaluation/_index.md) |
| Session | Gameplay composition, authoritative calendar/content bootstrap, full atomic V2 restore, and MVP acceptance gate. | [Session Handoff Index](session/_index.md) |
| Visitor | Corridor-door proxy service behavior, realized-visitor lifecycle, and operational visitor metrics. | [Visitor Handoff Index](visitor/_index.md) |
| Presentation | Read models, player intent gateway, diagnostics, source-gated panels/heatmaps, and notifications. | [Presentation Handoff Index](presentation/_index.md) |
| Staff | MVP Operations Room, cleaner/security records, coverage/task facts, and weekly payroll inputs. | [Staff Handoff Index](staff/_index.md) |
| Construction | MVP interior circulation, vertical links, Operations Rooms, placement transactions, and topology publication. | [Construction Handoff Index](construction/_index.md) |
| MVP Scope | Cross-program implementation order, testable player loop, exclusions, and end-to-end acceptance gate. | [MVP Scope Handoff Index](mvp/_index.md) |

## Repository-wide rule

Any change to an approved handoff requires an architecture review and user approval before implementation.
