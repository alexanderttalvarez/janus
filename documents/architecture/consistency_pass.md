# Documentation Consistency Record

**Status:** Approved documentation decisions, 2026-09-08, under the user's delegated design/architecture authority. This is a bounded inventory/disposition ledger, not an implementation audit or release approval. Only `documents/game_design/` and `documents/architecture/` were edited; visuals, implementation, tests and assets were not inspected for implementation status.

## Authority and Inventory

**Final-review notice, 2026-09-08:** This dated ledger and its 146-document/495-link QA result below describe the earlier pass, not the expanded current tree. The later [bounded P00 audit](evidence/product_mvp/implementation_audit.md) records partial source findings and failed preflight, with no Play result. Design A1/A2 decisions and A3 reset acknowledgement remain PENDING in the [Product register](evidence/product_mvp/_index.md#design-decision-register); architecture approval does not settle these gameplay interpretations. Unaffected engineering may proceed, but confirm A1 exterior-only wait and A2 shared cafe cohort counter semantics before locking affected implementation or acceptance. Historical conclusions and PASS claims below remain dated records, not current approvals or rerun evidence.

**Follow-on notice, 2026-09-08:** The ledger below preserves the earlier consistency pass and its H4/H5 draft disposition. A separate subsequent request and review approves that architecture in [ADR 34](decisions/34_product_mvp_runtime_and_cutover.md), with delivery governed by [MVP H4](handoff/mvp/04_product_delivery_and_acceptance.md). Current order is foundation -> detached `tenant_interiors/H1-H3` -> H4 implementation passes -> H5 candidate cutover passes -> Product acceptance; external Gate R is separate. Implementation/cutover remain NOT VERIFIED; Product acceptance/Gate R remain PENDING. Historical inventory, conclusions and claimed results below are not rewritten as follow-on approvals. District disposition remains: Engineering complete; H10 release acceptance pending external Gate R.

Authority order: concept premise; explicitly agreed design; accepted non-superseded ADRs; approved handoffs; drafts; trackers/evidence/history. Newer explicit amendments win within their stated scope. Design agreement, architectural approval, dependency readiness, implementation completion, engineering Gate E and release Gate R are independent.

The initial inventory contained **129 Markdown documents**: 22 design and 107 architecture (32 ADRs, 60 handoff-tree documents, 13 evidence documents and two architecture-root documents). Every original document was read in one bounded extraction group; no implementation audit was used. The linked registers enumerate exact filenames; ranges below refer to those registers, not omitted files. Unless noted, gameplay element documents had no global revision date. Later revision headers do not invent earlier dates.

| Inventory group | Purpose / original authority and date | Current disposition, supersession and dependents |
|---|---|---|
| [Concept](../game_design/concept.md) | Premise; agreed, undated | Current highest premise authority; original flat release scope explicitly superseded by Current MVP; all design depends on pillars |
| Former design `_status.md` | Tracker, undated discussion | Original contents retained in [archive](../game_design/archive/01_tenant_interior_discussion.md); replaced by current approval/status register |
| [Elements 01-09](../game_design/elements/_index.md) | Agreed loop, Prestige, Economy, zones, visitors, tenants, metrics, Tech, building | Current player rules as revised/scope-gated; 20 amends 04/05/06 geometry/service, 19 owns district facts; source documents for corresponding handoffs |
| Elements 10-18 | 10 draft; 11-18 agreed circulation/walls/terraces/synergy/staff/maintenance/UI/notifications | 10 stays draft/deferred; 13/16 wholly deferred; current subset of others follows Current MVP. Numerical/terminology contradictions resolved in-place |
| Elements 19-20 | Agreed district/interiors; 19 road addendum 2026-08-31 | Current geometry and interior-design authorities; 03/08 own prices/gates; interior runtime approval remains distinct from agreed design |
| [ADR registry](decisions.md) | Architecture index, undated | Current applicability map plus complete numbered history; supersession is explicit, not inferred from tracker status |
| ADRs 01-06 | Accepted 2026-07-28; 03/06 later district/arrival amendments | Composition/visitors/rendering retained as scoped by 27/28/33; 02 mandatory SubViewport and 04 5% strip superseded; foundation/presentation consumers |
| ADRs 07-09 | Accepted 2026-07-28, supersession 2026-08-30 | Historical grid/Plot/mask targets superseded by 27-29; no production dependency or legacy fallback |
| ADRs 10-11 | Accepted 2026-07-28; 11 partly superseded 2026-08-26 | Zone authority retained; 24/H6 preservation and staged interior H2 amend old splitting; Zone/Tenant consumers |
| ADRs 12-23 | Accepted 2026-07-28, with recorded later amendments in 12/13/15/20 | Retained domain boundaries subject to ADR 33; old FSM framework, agents, extra managers and absent-source calculations not prerequisites; domain handoff consumers |
| ADRs 24-26 | Accepted 2026-08-26/27 | Current paint/remove/cancel semantics; 24 partly supersedes 11; Zone interaction consumers |
| ADRs 27-28 | Accepted 2026-08-30 | Current district/arrival split; ADR 33 reconciles frozen format, cameras, clocks/gates and fixture rationale; district/arrival/save consumers |
| ADRs 29-31 | Accepted 2026-09-05/06 | Current production content/bootstrap, manual-door and endpoint-view authority; 31 refines 30; no generic door service |
| ADR 32 | Accepted 2026-09-06 | Current E/R separation; engineering record retains candidate-binding qualification; release evidence consumers |
| [Central blueprint](design_handoff.md) | Architecture-approved 2026-08-30 with 08-31 addenda | Historical synthesis; no longer duplicate current authority. Later ADRs and focused handoffs supersede current-runtime findings/proposals |
| [District program](handoff/district_layout/_index.md), 10 handoffs + two records + index | H1/H2 KEEP 08-31, C refresh 09-04; H3/H5-H9 approved 09-03; H4 projection/preview; H10 cutover | Current target contracts; adapter/migration observations historical. H4 tests reported passing, no formal preview acceptance; H10 engineering complete, external R pending. H1/H2 -> H3 -> H4/H5 -> H6/H7/H8 -> H9/H10 as qualified in MVP H1 |
| [Zone/Parcels](handoff/zone_parcels/_index.md), seven + index | Approved 08-22 through 08-27 | H6 amends H1/H2/H5; interior H2 adds staged core/annex. H3/H7 debug labels are optional, not gameplay blockers; Tenant/Construction depend on committed geometry |
| [Economy](handoff/economy/_index.md), two + index | Approved 09-03 | Current transaction/pricing boundaries amended by element 03/MVP H3; District/Construction/rent/payroll consumers |
| [Progression](handoff/progression/_index.md), three + index + future register | H1-H3 approved 09-03; future achievements deferred 09-05 | H2 revises elevation gates, H3 eligibility only; MVP H3 enables existing milestone awards. No speculative achievement dependency |
| [Tenant](handoff/tenant/_index.md), three + index + future register | Approved 09-05; future topic recorded same date | Lifecycle/rent/current score contract; interior H3 amends selection/provenance for staged work. "Not designed" interior register is historical; Service economics still deferred |
| [Tenant Interiors](handoff/tenant_interiors/_index.md), five + index | H1-H3 approved 09-06; H4/H5 undated drafts | H1-H3 detached outcomes ready; live Service/Visitor/whole-save integration gated. H4/H5 stay drafts; no approval inferred from Product scope |
| [Prestige](handoff/prestige/_index.md), two + index | Approved 09-05 | Official publication then fixed-Quality calculation; MVP H3 names coherent read assembly; Spatial/Tenant/Progression consumers |
| [Spatial](handoff/spatial_evaluation/_index.md), one + index | Approved 09-05 | Pure facts/recommendation; depends on District/Zone/Prestige plus frozen Tenant input types, not running Tenant; no durable synergy owner |
| [Session](handoff/session/_index.md), two + index | Approved 09-05 | Content/calendar spine then coherent atomic save/restore; ADR 33/MVP H3 amend timing/derived order and reserved payload; no draft interior cutover |
| [Visitor](handoff/visitor/_index.md), one + index | Approved 09-05 | Foundation proxy/metrics; explicit baseline policy closes missing provider. Depends on arrival/topology/Tenant facts; supersession by interior runtime remains proposed |
| [Presentation](handoff/presentation/_index.md), one + index | Approved 09-05 | Source-backed intents/views; MVP H3 adds minimal action surfaces, not new dashboards; no source -> unavailable |
| [Staff](handoff/staff/_index.md), one + index | Approved 09-05 | Revised employment/coverage/whole-week wage contract; tasks/agents deferred; Construction room, Time and Economy dependencies only |
| [Construction](handoff/construction/_index.md), one + index | Approved 09-05 | Current fixed footprints/cost/placement/topology; no operational elevator mechanics or pending room-size choice |
| [MVP](handoff/mvp/_index.md), originally two + index | H1 approved 09-05, H2 09-06 | H1 now only orders work, H2 gates Product completion; new H3 closes foundation integration. Current MVP owns scope once |
| [Evidence package](evidence/district_layout_acceptance/_index.md), originally 13 | One package README, four audits, two migration, two performance, one proof, three signoff records | Exact files indexed by subfolder. Most capture records undated/unbound: historical/local claims only. Selected policies approved 09-05; signoff contract normative; four actual signoffs pending. No deleted evidence, fabricated artifact or implementation check |
| New entry points, ADR 33, MVP H3 and this ledger | Documentation approval 2026-09-08 | Current navigation/amendment authority; evidence subindexes are navigation only. No new status dimension or hidden implementation scope |

## Contradiction Ledger

Each row closes a reported issue unless the disposition explicitly identifies external evidence or a deliberate draft gate. Older illustrative details are not an alternative current contract.

| Class | Issue / disputed authority | Resolution and rationale |
|---|---|---|
| CONTRADICTION | Concept flat MVP vs approved interior Product scope | Current MVP explicitly supersedes prototype scope while retaining premise; proxy becomes technical integration checkpoint |
| STALE | Design tracker mixed final agreement and open discussion | Replace tracker; archive complete discussion and fix element navigation |
| BLOCKER | Approved interior H1-H3 require draft runtime/persistence | Explicit detached readiness matrix; fixtures prove declared ports only. Live integration waits for separately approved H4/H5, not invented adapters |
| STALE | District H10 index said draft/blocked | Approved E/R contract; exact engineering-complete/external-R-pending wording everywhere; no release signoff inferred |
| AMBIGUITY | H4 preview pending vs 15/15 reported tests | Distinguish reported implementation tests from unrecorded formal full-preview acceptance; preserve runtime successor readiness |
| CONTRADICTION | 23/27/28 Tech totals vs listed costs; escalators both MVP/deferred | 12+6+8 = 26, surplus 14; cost values unchanged. Current player route costs 8; escalators and buses operationally deferred |
| BLOCKER | Required vertical/category unlocks but Tech awards excluded | Implement existing element-08 milestones once; 100/300 developed tiles grant 3/8 cumulative points via fixed Quality 20, no debug or extra quality system |
| CONTRADICTION | Five calendar minutes equated to five seconds | Element 01 defines scaled elapsed units; visitor tick five scaled seconds, day 24; one Time owner and deterministic boundary delivery |
| CONTRADICTION | Wall 5%/10%, unspecified thickness, old one-door/No-Walls/junction rules | Element 12 owns 10% strip, 0.10/0.05 profiles and H4-style junctions. ADR 33 amends ADR 04; actual doors differ from one operational entrance |
| STALE | Element 19 prices/elevations/hybrid format still open | Point to approved element 03/08 and H1/H2 KEEP; no repeated format decision or guessed price |
| CONTRADICTION | Three-owned-Plot Fixture C and "connected rectangle union" | Preserve frozen test semantics; proof-only ownership exception and active-slot components, no synthetic connecting land |
| CONTRADICTION | 5T half-cycle yields yellow, not required initial east-west red | East-west offset 6, exact intervals in element 19; midpoint controls need no half-cycle/intersection coordination |
| BLOCKER | Crossing late entry/clearance unspecified | Final-T pedestrian clearance plus mutual occupancy hold; shared Time and explicit transient owner; no safety dependency on coarse behavior ticks |
| AMBIGUITY | Multiple gates, reentrant observers, torn exports, early derived import | One non-reentrant session boundary; coherent capture; import all durable state before candidate-only derived reconstruction |
| AMBIGUITY | Failed projection retains stale pickable world; preview root cleanup conflicts | Retain old valid root, dispose candidate only, disable stale world intents; restore failure preserves old whole session |
| CONTRADICTION | Prestige adds seventh 15-point Synergy factor; trend compares Quality to Prestige | Keep six-factor full-game budget; current Quality 20 has no synergy/trend; future trend compares same units |
| AMBIGUITY | Fractional premium gaps, zero recommendation and legacy floor labels | Element 03 floors recommendation once; element 06 uses exhaustive integer comparisons/zero case and absolute signed elevation |
| AMBIGUITY | Unnamed spatial distance/read assembly | Element 14 same-elevation Manhattan boundary gap; existing Prestige producer coherently assembles developed-tile union with full revisions |
| CONTRADICTION | Door preference overrides preservation; retirement blocked by vanished doors | Preserve prior legal selection; preference fills new slots only. Authorized retirement owns automatic-door removal, not unrelated manual doors |
| STALE | Rectangular/category-average parcels, global recoloring and minimum-only eviction | Mark historical sketch; element 20 and preservation-first handoffs govern. Customer theme identity is distinct from shared operational profile |
| BLOCKER | Missing service/planning content values and inconclusive search treated as unsuitable | Element 20 supplies authored revision-1 defaults/compound-module meanings. Any relevant indeterminate profile defers full selection and destructive repair; no fallback at runtime |
| AMBIGUITY | Closed fit-out term conflicts with Open/rent independence | Service unavailable is not a Tenant lifecycle transition; fixed Open/rent deadline survives visual/service failure; invalid saves still reject |
| AMBIGUITY | Payroll overdraft, partial results and retry roster unspecified | Whole-week mandatory settlement; retain boundary roster durably, no proration or employee-by-employee partial debit. Existing owners suffice |
| OVERENGINEERING | Required staff tasks, generic FSM, duplicate heatmap/manager layers | ADR 33 retains necessary owner boundaries, drops unused runtime systems; owner-local states and single heatmap path suffice |
| AMBIGUITY | V2 demands undefined mutable Synergy authority | Preserve root key as exact versioned derived-only marker; validate in Session, no invented simulation or cache |
| CONTRADICTION | Required player actions but Tech/Staff UI entirely excluded | Minimal non-debug action lists, no graph/dashboard scope expansion; fit-out cancel uses existing state-only intent |
| STALE | Maintenance charges and erroneous examples; zero-guard division, missing bathroom constants | No recurring tile charge; correct future examples/canonical elevations; finite conservative post-MVP constants, no current simulation requirement |
| HYGIENE | Misleading local H IDs, old future-topic status, missing folder indexes, UI shortcut/count | Qualify cross-program references; current indexes link amendments; preserve future-topic history; Z edits, E rotates; one obvious entry point per tree |
| AMBIGUITY | Fixture-free production vs fixture benchmark; one-second FPS cannot prove slow-frame limit | Separate release-mode benchmark test pack at same candidate; per-frame samples; changed topology and full-session load workloads required |
| HYGIENE | Evidence PASS lacks raw provenance/candidate binding | Preserve as claims and add explicit evidence boundary/indexes; never fabricate missing dates, logs, hashes or acceptance |

## Remaining External Gates

- `tenant_interiors/H4-H5` are deliberately drafts. Approved detached work is ready; full Product runtime/cutover is not authorized by this pass.
- `district_layout/H4` formal full-preview acceptance has not been recorded, despite passing test claims. This does not block its runtime successors.
- `district_layout/H10` requires frozen candidate binding and external Gate R exports, physical reference-hardware measurements, retained artifact/log manifests and independent Architecture/Design/QA/Release signoffs. These are factual evidence obligations, not unanswered design choices.

## Verification Boundary

Documentation QA checks local links, indexes, scope/status consistency, arithmetic and allowed changed paths. It does not run Godot, tests, benchmarks, exports or an implementation audit. The final report states actual validation outcomes; historical evidence remains unmodified except explicit status/policy clarifications.

**Completed documentation checks, 2026-09-08:** 146 Markdown documents; 495 local Markdown links resolve; no local heading-fragment references require checking; every active folder has `_index.md`; `git diff --check` is clean; all changed paths are inside the two permitted trees and no implementation files changed. Read-only arithmetic checks confirm branch costs 12/6/8 (total 26), 14 unallocated points, the 8-point core route, cumulative awards 3/8/15/25/40, 500/1,500 Prestige at 100/300 tiles, exhaustive fractional rent-band boundaries and zero-recommendation behavior, and the crossing epoch/clearance arithmetic. These are documentation checks, not game test or release results.
