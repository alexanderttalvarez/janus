# Game Design Status

## Phase: 3

## Concept: agreed

## Elements

| # | Element | Status | File |
|---|---------|--------|------|
| 01 | Core loop | agreed | `01_core_loop.md` |
| 02 | Prestige system | agreed | `02_prestige_system.md` |
| 03 | Economy | agreed | `03_economy.md` |
| 04 | Zone / space design | agreed | `04_zone_space_design.md` |
| 05 | Visitor simulation | agreed | `05_visitor_simulation.md` |
| 06 | Tenant / shop system | agreed | `06_tenant_shop_system.md` |
| 07 | Metrics & data visualization | agreed | `07_metrics_data_visualization.md` |
| 08 | Mall levels & tech tree | agreed | `08_mall_levels_tech_tree.md` |
| 09 | Building & structure system | agreed | `09_building_structure_system.md` |
| 10 | Structural system (columns) | draft | `10_structural_system_columns.md` |
| 11 | Transit & circulation | agreed | `11_transit_circulation.md` |
| 12 | Wall system | agreed | `12_wall_system.md` |
| 13 | Terrace system | agreed | `13_terrace_system.md` |
| 14 | Synergy system | agreed | `14_synergy_system.md` |
| 15 | Staff system | agreed | `15_staff_system.md` |
| 16 | Maintenance system | agreed | `16_maintenance_system.md` |
| 17 | UI / HUD system | agreed | `17_ui_hud_system.md` |
| 18 | Notifications system | agreed | `18_notifications_system.md` |
| 19 | District layout & land expansion | agreed | `19_district_layout_land_expansion.md` |
| 20 | Tenant interiors & visitor interactions | agreed | `20_tenant_interiors_visitor_interactions.md` |

## Current discussion

Tenant interiors & visitor interactions is agreed and documented. Gameplay documentation only; no architecture handoff or implementation is approved. The next step, when requested, is final design review or later architecture preparation.

Final user approval recorded: the consolidated design accurately represents the agreed direction. Numerical subtype and queue baselines are locked until playtest evidence justifies retuning. No further tenant-interior design discussion is currently open.

Latest queue decisions: scheduled visitors reserve only the next batch; exterior queues use non-overlapping frontage positions, count as real corridor occupancy/congestion, and never exclusively block an entire circulation tile. Clarification in discussion: a tenant may have one active abstract batch inside while its liberated exterior queue forms the next batch; no later batch is reservable.

Batch capacity decision: each tenant supports one active batch inside and one forming next-batch queue outside. New patience issue: normal waiting must not decrement a general emotional state after the visitor has committed. Recommended direction under discussion is an arrival-time expected-wait check followed by commitment, with cancellation only for invalidation/disruption; this may replace the older visitor definition of Patience as maximum people ahead with a common maximum acceptable expected-wait value.

Takeaway food profile agreed: 6-tile minimum, 2x3 rotatable core, 6–12 target range, mandatory frontage counter/prep/back-of-house rows, repeatable 1x3 service-lane strips, shared FIFO counter queue, and maximum 6 waiting visitors. User delegated remaining subtype baselines for rapid playtest-oriented definition; only genuinely new service dynamics require consultation. Two newly identified decisions are shared counter-plus-seating behavior for food courts and whether anchors support multiple active visitor entrances in the first iteration.

Remaining subtype baselines have been defined for Food & Beverage, Retail, Services, Entertainment, and Anchors. Agreed: cafés and food courts reserve a table before counter service; first-iteration anchors use one primary operational visitor entrance, with multi-entry service deferred. Newly identified queue questions: whether scheduled-batch visitors may reserve only the next batch, and whether exterior queues contribute to public-corridor congestion while retaining non-overlapping safe queue positions.

Candidate-selection decision: feasible profiles receive Excellent/Good/Acceptable spatial ratings with 6/3/1 weighted tickets; all feasible profiles retain a chance. The detailed inspector shows the full compatible-profile list and the normal view summarizes the top three. Operational subtype is separate from tenant theme/profile; initial visuals may be shared except for signage, while richer thematic variants remain deferred. Sit-down restaurant is complete; takeaway food is the next subtype under discussion.

Latest decisions: parcel-scale distribution remains automatic for now. Irregular annex tiles may hold repeatable capacity fixtures when the complete module, clearance, and connectivity rules pass. Current question: introduce bounded, seeded parcel-size variation so eligible restaurant parcels vary between the 12-tile minimum and a proposed 24-tile upper target without post-assignment parcel growth.

Size-variation decision: 24 tiles is the sit-down restaurant splitter target maximum, not a hard tenant-eligibility maximum. Every subtype receives its own individually considered minimum/core/preferred size definition, though identical values may occur; profiles are not defined through generic category defaults.

Sit-down restaurant profile agreed: 12-tile minimum, 3x4 rotatable core, 12–24 splitter target range, host/seating queue requiring at least one exterior queue tile, maximum 8 waiting visitors subject to safe space, 2-person and 4-person repeatable table modules, FIFO partial cohorts, comfort-density placement with no hard table-count cap, and abstract occupied-table visuals. New discussion: spatially weighted candidate selection from the feasible-profile pool without conflating profile selection with the existing commercial application score.

Candidate-selection direction agreed: every feasible profile retains a small chance, while spatially excellent matches receive a strong weighted advantage. The detailed parcel inspector shows the full compatible-profile list with qualitative fit ratings; the normal view summarizes the top three. Commercial application scoring remains a separate later step. Exact suitability bands/weights and the distinction between customer-facing subtype labels and operational interior profiles remain in discussion.

Latest decisions: there is no universal parcel minimum; every subtype defines its own minimum usable area and minimum core shape. Future exterior queues use 2 visible visitors per validated queue tile, subject to safe-space and subtype caps. Proposed refinement under discussion: parcels contain a subtype-compatible rectangular core plus optional irregular annex tiles; initial splitting must preserve a useful mix of parcel scales rather than collapsing into the smallest valid subtype.

Latest decisions: sit-down restaurants require at least one exterior queue slot and support both 2-person and 4-person table modules. Current question: revise parcel minimums (universal 9 versus subtype-specific 12+) and reconcile exterior queue density; the existing visitor design currently states 3 visitors per entrance tile, not 2.

Tenant interiors & visitor interactions — visible procedural interiors with abstract public-side service is the leading MVP direction. Agreed: interior MVP affects capacity/queue/readability only; revenue and viability remain deferred. Agreed: candidate selection uses a prevalidated feasible-profile pool rather than repeated fit attempts; empty pools expose a specific geometry diagnosis and a visible unsuitable-unit state. Some categories deliberately require larger/more regular parcels. Agreed: initial parcel generation may absorb infeasible parcels into the best compatible adjacent parcel or convert them to decoration; later edits preserve parcels and allow unsuitable vacant shells with feedback. Anchors require a contiguous suitable player-zoned footprint and bypass ordinary splitting. Agreed: visitors discover actual queues only on arrival at the tenant door; they re-evaluate only then if unwilling to wait; a rejected tenant is excluded for that visitor's current goal. Scheduled-batch service is required. Agreed: queue caps scale with validated safe exterior queue slots, subject to subtype-defined upper bounds. Agreed: restaurant table service forms FIFO temporary cohorts, permits partial table fills, and uses abstract occupied-table visuals rather than interior visitor navigation; real visitor models inside are deferred for evaluation later. Agreed: back-of-house blocks are mandatory where subtype-appropriate; attraction/display fixtures are visual-only. Agreed: each fixture definition specifies footprint/shape, fitted visual variants, queue behavior, clearance, and compatible/incompatible neighbors; profiles distinguish mandatory, repeatable-capacity, and optional visual fixtures. Repeatable placement targets subtype-defined comfort density rather than maximum packing. Each subtype has one mandatory operational program with visual variants; multiple operational variants are post-MVP. In discussion: individual subtype definitions, beginning with sit-down restaurants. No implementation or architecture handoff is approved.
