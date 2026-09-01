# Handoff 01: Definition Schema and Validation

## Status

**Draft - ready for architecture approval.** H1 and H2 may be approved and implemented together for proof only. Production use requires A-C evidence and H1 **KEEP**; **REVISE** or **REJECT** regenerates H1/H2 goldens and blocks H3 production implementation.

## Purpose

Define immutable versioned authoring semantics, deterministic validation, and three exact proof fixtures. H1 owns semantic inclusion in the definition fingerprint; H2 owns bytes and hashing.

## Dependencies

- [Decision 27](../../decisions/27_district_layout_templates.md), [Decision 28](../../decisions/28_visitor_arrival_architecture.md), and the [architecture blueprint](../../design_handoff.md).
- H2 may build a provisional resolver against this contract before KEEP.

## Source-of-truth documents

- [District Layout and Land Expansion](../../../game_design/elements/19_district_layout_land_expansion.md)
- [Handoff index](./_index.md)

## Current-state findings

The old `25x25_full.txt`, `plot_0`, corner coordinates, and mutable grid cannot express separate roles or state concepts and are not target authority.

## Target state

Validated normalized integer/string/bool/null/array/object values are immutable. Every semantic integer is in the inclusive I-JSON safe range `[-9007199254740991, 9007199254740991]`; parsing/normalization rejects any value outside that range before H2 RFC 8785 canonicalization. Domain validators then enforce tighter field-specific limits for sizes, ordinals, elevations, and every other bounded integer. Definitions contain authored facts and initial conditions only; session mutation never writes back.

## Scope

- Layout tracks/slots, plot templates/variants, masks, caps, fixed occupancy, road profiles, source selectors, diagnostics, fixtures, and fingerprint semantic inclusion.

## Explicit non-goals

- Runtime mutation, generated transforms/geometry, prices, formulas, progression, source allocation, saves, or production gameplay layouts.

## System ownership

| Owner | Responsibility |
| --- | --- |
| Definition authors | Stable semantic IDs, roles, variants, masks, selectors, caps. |
| Definition pipeline | Parse, normalize, validate, publish immutable values. |
| H2 resolver | Resolve topology/transforms and encode/hash H1 semantics. |

## Data contracts

### Roles and identity

- `BlockSlotDefinition.role` is exactly `PLOT`, `DECORATIVE_FIXED`, `PARK`, `PUBLIC_PLAZA`, or `UNAVAILABLE`.
- Parks and public plazas are distinct non-Plot roles. Neither contains purchasable Plot Sections.
- Authored source identity is exactly `arrival_source_id`. An authored topology selector is separate. H2 resolves a separate topology attachment ID and baseline `DistrictGridPose`.
- Runtime rotation is forbidden. Authors provide an explicit reviewed rotated `shape_variant_id`; otherwise dimension/orientation mismatch is deterministically rejected.
- Authored definition IDs and authored ordinals are stable semantic facts. Derived IDs use only the exact closed typed tuples in H2. Topology IDs never derive from transforms, traversal, serialized order, or coordinates; only local runtime Cell identity may include local `x,y` exactly as H2 specifies.

### Token layers and validation

Each UTF-8/LF whitespace-token grid represents one concept. Section, fixed occupancy, and buildability are separate. `.` is layer absence. Ownership/availability are metadata sets. Acquired and constructed state are forbidden. Every normalized cell set or mask is duplicate-free and ordered row-major ascending by `(y,x)`, comparing `y` first and then `x`. Sections are non-empty, in-bounds, non-overlapping, and 4-connected. Every row depth and column width is at least 18 tiles. For every `PLOT` slot, `buildability_mask` is exactly the set union of all section masks; no additional or missing cell is valid. Every non-`PLOT` slot has exactly empty `sections` and an empty `buildability_mask`. Fixed occupancy remains a separate layer and never changes either invariant; each occupant's elevation-mask records are duplicate-free by elevation and ordered by signed elevation ascending, and every nested mask uses the same row-major order. Physical elevations are `0,+1..+9,-1..-5`; stricter template/slot caps are allowed. Pedestrian bands are 5-10 tiles; each road profile has 2-6 total 3-tile lanes, at least one lane per direction, and contiguous same-direction groups. The outer ring is complete and permanent.

### Canonical semantic input

H1 includes schema/version identities, stable IDs/ordinals, tracks, roles, references, selected variants, overrides, caps, catalogs, initial facts, normalized cells, road profile, outer-ring declaration, `arrival_source_id`, and authored selector. It excludes formatting, comments, paths, UIDs, labels, notes, editor metadata, runtime state, and all derived transforms/geometry. Semantic values contain no floating or non-finite values.

Every semantic string is valid UTF-8 and normalized to Unicode NFC before validation and H2 canonicalization. Every semantic integer must first pass the inclusive I-JSON safe-range rule; acceptance by that representation-level rule never relaxes a tighter domain limit. The normalized semantic record has this closed architecture shape; every named field is required, including fields whose value is null or an empty collection:

- Root: `definition_schema_version`, `layout_definition_version`, `canonical_schema_version`, `resolver_schema_version`, `layout`, `template_catalog`, `variant_catalog`, `fixed_block_catalog`, and `road_profile_catalog`.
- `layout`: `layout_id`, `physical_elevation_range`, `row_tracks`, `column_tracks`, `horizontal_boundaries`, `vertical_boundaries`, `slots`, `outer_ring`, and `arrival_sources`. `physical_elevation_range` is a non-null object with signed integer `minimum_elevation` and `maximum_elevation`; its minimum cannot exceed its maximum.
- Each row/column track: `track_id`, `ordinal`, and integer `size`. Each horizontal/vertical boundary: `boundary_id` and `ordinal`; these are authored semantic identities rather than values inferred from coordinates or serialized order.
- Each slot: `slot_id`, `ordinal`, `row_track_id`, `column_track_id`, `role`, nullable `template_id`, nullable `selected_variant_id`, nullable `fixed_block_definition_id`, `sections`, `buildability_mask`, `fixed_occupants`, and nullable `physical_elevation_cap_override`. Role-specific references that do not apply are serialized as null, not omitted.
- Each section: `section_id`, `section_role`, `ordinal`, `mask`, `initially_owned`, `initially_available`, and `initially_entry_eligible`. `section_role` is a stable uppercase variant-binding key, not gameplay state, ownership, availability, or progression. Each mask is the normalized ordered cell set for that layer.
- Each fixed occupant: `occupant_id`, `ordinal`, and `elevation_masks`, where each elevation-mask record contains signed integer `elevation` and `mask`.
- Each template catalog record: `template_id`, `template_version`, nullable `physical_elevation_cap`, and ordered `variant_ids`. Each variant catalog record: `variant_id`, `template_id`, `template_version`, integer `width`, integer `depth`, and complete ordered `section_mappings`; each mapping contains `section_role`, `ordinal`, and `mask`. Each fixed-block catalog record: `fixed_block_definition_id`, `fixed_block_definition_version`, and ordered `fixed_occupants` using the same occupant shape defined above. A nullable physical cap or slot override is either the whole value `null`, or a non-null object whose `minimum_elevation` and `maximum_elevation` are both signed integers with minimum no greater than maximum. A record with either member null or absent is invalid; partial-null cap objects have no meaning.
- Each road-profile catalog record: `road_profile_id`, `road_profile_version`, integer `pedestrian_width`, and ordered `carriageways`. Each carriageway has authored `ordinal` and ordered `lanes`; each lane has authored `ordinal`, uppercase direction literal, and integer `width`.
- `outer_ring`: `complete` and `permanent` booleans plus `road_profile_id`. It is an authored declaration, not inferred geometry.
- Each arrival source: `arrival_source_id`, `mode`, `selector`, `initially_enabled`, nullable `capacity`, nullable `weight`, nullable ordered-array `schedule`, and nullable object `presentation`. The selector is the complete authored topology-selector object. Proof fixtures serialize these fields exactly as `capacity=null`, `weight=null`, `schedule=[]`, and `presentation={}`.

Each exact catalog contains all and only records transitively referenced by the layout: every `template_catalog`, `variant_catalog`, `fixed_block_catalog`, and `road_profile_catalog` entry is explicit, referenced, and complete, and every reference resolves to one such entry. Unreferenced, duplicate, resolver-synthesized, or incomplete catalog records reject. Definition records contain authored facts and initial conditions only and cannot contain mutable runtime state, generated IDs, resolved attachments, transforms, geometry, revisions, balances, acquired space, or construction state. Optional contract fields are still serialized explicitly as null, false, or an empty collection as prescribed; omission is invalid. The whole-value nullable cap rule above is authoritative and is not overridden by any general wording about unspecified null values.

### Exact fixtures

All values below are authored fixture facts. Physical caps prove geometry constraints and strictest-cap precedence; they are not progression or economy values. Token grids are mechanical representations of the exact predicates and rectangles below, reviewed and frozen, never semantic content chosen during implementation.

#### Common fixture semantic defaults

- Proof-contract versions are exactly `definition_schema_version=1`, `layout_definition_version=1`, `template_version=1`, `fixed_block_definition_version=1`, `road_profile_version=1`, `canonical_schema_version=1`, and `resolver_schema_version=1` wherever the corresponding record exists.
- Every proof layout authors `physical_elevation_range={minimum_elevation:-5, maximum_elevation:+9}`. Template caps and slot overrides may only tighten the intersection; they never replace or expand the root range.
- Row IDs are `row_0`, `row_1`, ... and column IDs are `col_0`, `col_1`, ...; their authored semantic ordinals are zero-based and match the listed order. A and B each have slot ordinal 0. C slot ordinals 0 through 8 match the row-major slot table from `market_hall` through `tower_plot`. Slot IDs are exactly the IDs listed below. Coordinates and serialized/list order never derive any stable ID.
- Every unspecified optional array or object is explicitly empty, every unspecified optional reference is explicitly null, and every unspecified boolean is explicitly false. For physical caps and overrides, only the whole record may be null; a non-null record always contains two integers. No resolver-implicit default is permitted: generated fixture manifests expand every value. Capacities, weights, schedules, and presentation values are respectively explicit null or empty according to their field type.
- Every proof-fixture `PLOT` buildability mask is exactly the union of its section masks and therefore covers its full slot, including every P2/P3 slot in C. `civic_monument` and `central_plaza` have exactly empty buildability masks and empty sections. Fixed occupancy is a separate construction veto/state; it does not alter buildability and never implies ownership.
- Initial availability, ownership, and entry eligibility are exactly the sets listed for each fixture, with no hidden initial states.
- Fixture A uses layout `fixture.legacy_25_single`, template `fixture.template.legacy_25`, variant `fixture.variant.legacy_25.full`, and road profile `fixture.road.two_lane_p5`. Fixture B uses layout `fixture.variable_30x40_single`, template `fixture.template.variable_30x40`, variant `fixture.variant.variable_30x40.proof`, and road profile `fixture.road.two_lane_p5`. Fixture C uses layout `fixture.mixed_3x3`, road profile `fixture.road.two_lane_p6`, fixed-block definition `fixture.fixed.civic_monument`, and the template/variant IDs listed in its mapping table.
- Exact catalog membership is closed. A has template catalog `[fixture.template.legacy_25]` whose ordered `variant_ids` is `[fixture.variant.legacy_25.full]`, variant catalog `[fixture.variant.legacy_25.full]`, empty fixed-block catalog, and road-profile catalog `[fixture.road.two_lane_p5]`. B has template catalog `[fixture.template.variable_30x40]` whose ordered `variant_ids` is `[fixture.variant.variable_30x40.proof]`, variant catalog `[fixture.variant.variable_30x40.proof]`, empty fixed-block catalog, and road-profile catalog `[fixture.road.two_lane_p5]`. C has template catalog `[fixture.template.market, fixture.template.courtyard, fixture.template.tower]`; their ordered `variant_ids` are respectively `[fixture.variant.market.market_hall, fixture.variant.market.canal_plot, fixture.variant.market.arcade_plot]`, `[fixture.variant.courtyard.station_plot, fixture.variant.courtyard.garden_plot]`, and `[fixture.variant.tower.workshop_plot, fixture.variant.tower.tower_plot]`; its variant catalog is those seven records in that order, fixed-block catalog `[fixture.fixed.civic_monument]`, and road-profile catalog `[fixture.road.two_lane_p6]`. Every named member is a complete explicit record of the closed shape above; no other catalog record exists in that fixture.
- Both exact road-profile records contain one carriageway only: carriageway ordinal `0`, with lane ordinal `0`, direction `FORWARD`, width `3`, followed by lane ordinal `1`, direction `REVERSE`, width `3`. There are no other carriageways or lanes. H2 maps these direction literals and this authored order to deterministic corridor geometry; the generated segment counts below therefore remain unchanged.
- Every listed source has mode `PEDESTRIAN` and `initially_enabled=true`. Sources have no capacities, weights, schedules, or presentation values; they serialize exactly as `capacity=null`, `weight=null`, `schedule=[]`, and `presentation={}`. B has no source records.
- The proof-fixture generator must emit the complete normalized semantic record shape above for A-C, including every common/default, catalog, nested, nullable, false, and empty field. Missing required fields, omitted optional fields, implicit defaults, extra runtime-state fields, and incomplete referenced catalog records reject before H2. These generation rules are normative and closed; exact literal manifests and goldens are generated artifacts created and reviewed only after implementation. Runtime IDs and fingerprints are therefore fully determined without resolver inference.

#### A: `fixture.legacy_25_single`

- Tracks are rows `[25]` and columns `[25]`. The sole slot is `legacy_anchor`, role `PLOT`, size 25x25. Runtime Plot identity uses H2's exact `(plot, layout_id, slot_id, slot_ordinal)` tuple.
- Authored horizontal boundaries are exactly `h0` ordinal 0 and `h1` ordinal 1. Authored vertical boundaries are exactly `v0` ordinal 0 and `v1` ordinal 1. These identities and ordinals are not inferred from coordinates or collection order.
- The sole section is `whole_plot`, `section_role=FULL`, ordinal `0`, with mask `{(x,y) | 0<=x<=24 and 0<=y<=24}`. It is initially owned, initially available, and entry-eligible. Fixed occupancy is empty.
- The buildability mask is exactly that whole-plot section mask.
- The selected variant has exactly one section mapping: `section_role=FULL`, ordinal `0`, with that exact whole-plot mask. After binding `FULL` to `whole_plot`, the slot section repeats the selected mapping's ordinal and normalized mask; byte equality is required.
- The template cap is null and the slot override is null, so the effective physical range is exactly the root `-5..+9` (`0,+1..+9,-1..-5`).
- The uniform road profile is `fixture.road.two_lane_p5` with pedestrian width 5 and the exact common carriageway/lane record above. The permanent outer ring is complete.
- Pedestrian arrival sources and exact authored topology selectors are:

| `arrival_source_id` | Selector |
| --- | --- |
| `gateway_north` | `{kind: OUTER_PEDESTRIAN_BAND, slot_id: legacy_anchor, side: NORTH}` |
| `gateway_east` | `{kind: OUTER_PEDESTRIAN_BAND, slot_id: legacy_anchor, side: EAST}` |
| `gateway_south` | `{kind: OUTER_PEDESTRIAN_BAND, slot_id: legacy_anchor, side: SOUTH}` |
| `gateway_west` | `{kind: OUTER_PEDESTRIAN_BAND, slot_id: legacy_anchor, side: WEST}` |

Selectors are topology facts and contain no coordinates.

#### B: `fixture.variable_30x40_single`

- Tracks are rows `[40]` and columns `[30]`. The sole slot is `variable_anchor`, role `PLOT`, size 30x40.
- Authored horizontal boundaries are exactly `h0` ordinal 0 and `h1` ordinal 1. Authored vertical boundaries are exactly `v0` ordinal 0 and `v1` ordinal 1. These identities and ordinals are not inferred from coordinates or collection order.
- In listed order, sections are `arrival_section` with `section_role=ARRIVAL`, ordinal `0`; `east_section` with `section_role=EAST`, ordinal `1`; and `south_section` with `section_role=SOUTH`, ordinal `2`. `arrival_section` is initially owned, initially available, and entry-eligible. `east_section` and `south_section` are initially available but unowned and not entry-eligible. Fixed occupancy is empty.
- The selected variant has exactly those three mappings with matching role literals, ordinals, and the masks below. After role-to-ID binding, each slot section repeats its selected mapping's ordinal and normalized mask; byte equality is required.
- The template physical cap is `-2..+6`; the stricter slot override is `-1..+4`, so the effective cap is `-1..+4`. This proves strictest-cap precedence, not progression.
- The uniform road profile is `fixture.road.two_lane_p5` with pedestrian width 5 and the exact common carriageway/lane record above. The permanent outer ring is complete.
- Pedestrian arrival sources are exactly empty by design; this fixture is resolver proof only.

B masks are exact:

- `arrival_section = {(x,y) | 0<=y<=19 and 0<=x<=11} UNION {(x,y) | 20<=y<=27 and 0<=x<=7}`.
- `east_section = {(x,y) | 0<=y<=19 and 12<=x<=29} UNION {(x,y) | 20<=y<=27 and 8<=x<=29}`.
- `south_section = {(x,y) | 28<=y<=39 and 0<=x<=29}`.
- The buildability mask is exactly `arrival_section UNION east_section UNION south_section`, which is the full 30x40 slot.

#### C: `fixture.mixed_3x3`

Tracks are rows `[18,24,30]` and columns `[20,28,36]`. Authored horizontal boundaries are exactly `h0`, `h1`, `h2`, and `h3`, with ordinals matching suffixes 0 through 3; authored vertical boundaries are exactly `v0`, `v1`, `v2`, and `v3`, with ordinals matching suffixes 0 through 3. These identities and ordinals are not inferred from coordinates or collection order. The uniform road profile is `fixture.road.two_lane_p6` with pedestrian width 6 and the exact common carriageway/lane record above. The permanent outer ring is complete. Slots are exact:

| Position | Slot ID | Role and size | Sections / fixed occupancy |
| --- | --- | --- | --- |
| `r0c0` | `market_hall` | `PLOT`, 20x18 | P3: `market_entry`, `market_rear`, `market_court` |
| `r0c1` | `civic_monument` | `DECORATIVE_FIXED`, 28x18 | Fixed-block occupant `monument_mass`: deterministic centered rectangle `9<=x<=18,4<=y<=13`, elevation `0`; slot-local fixed list empty |
| `r0c2` | `canal_plot` | `PLOT`, 36x18 | P2: `canal_entry`, `canal_rear` |
| `r1c0` | `station_plot` | `PLOT`, 20x24 | P3: `station_entry`, `station_wing`, `station_yard` |
| `r1c1` | `central_plaza` | `PUBLIC_PLAZA`, 28x24 | No sections or fixed occupancy |
| `r1c2` | `garden_plot` | `PLOT`, 36x24 | P2: `garden_entry`, `garden_rear` |
| `r2c0` | `workshop_plot` | `PLOT`, 20x30 | P2: `workshop_entry`, `workshop_rear`; occupant `service_core_workshop`: `8<=x<=11,12<=y<=17`, elevation `0` |
| `r2c1` | `arcade_plot` | `PLOT`, 28x30 | P2: `arcade_entry`, `arcade_rear` |
| `r2c2` | `tower_plot` | `PLOT`, 36x30 | P2: `tower_entry`, `tower_rear`; occupant `service_core_tower`: `15<=x<=20,12<=y<=17`, elevations `0,+1`, with the same occupant ID in both masks |

Template and selected authored variant mapping is exact:

| Template ID | Variant ID | Slot | Mask mapping |
| --- | --- | --- | --- |
| `fixture.template.market` | `fixture.variant.market.market_hall` | `market_hall` | P3 `entry/rear/court` -> `market_entry/market_rear/market_court` |
| `fixture.template.market` | `fixture.variant.market.canal_plot` | `canal_plot` | P2 `entry/rear` -> `canal_entry/canal_rear` |
| `fixture.template.market` | `fixture.variant.market.arcade_plot` | `arcade_plot` | P2 `entry/rear` -> `arcade_entry/arcade_rear` |
| `fixture.template.courtyard` | `fixture.variant.courtyard.station_plot` | `station_plot` | P3 `entry/rear/court` -> `station_entry/station_wing/station_yard` |
| `fixture.template.courtyard` | `fixture.variant.courtyard.garden_plot` | `garden_plot` | P2 `entry/rear` -> `garden_entry/garden_rear` |
| `fixture.template.tower` | `fixture.variant.tower.workshop_plot` | `workshop_plot` | P2 `entry/rear` -> `workshop_entry/workshop_rear` |
| `fixture.template.tower` | `fixture.variant.tower.tower_plot` | `tower_plot` | P2 `entry/rear` -> `tower_entry/tower_rear` |

These authored variants prove reusable template metadata across dimensions and P2/P3 mappings. Runtime scale and rotation are forbidden.

Every C `PLOT` buildability mask is exactly the union of its listed P2/P3 section masks and is the full slot. `civic_monument` and `central_plaza` each have exactly empty `sections` and an empty buildability mask; `monument_mass` remains separate fixed occupancy.

- P2 variant mappings are exactly `ENTRY` ordinal `0` and `REAR` ordinal `1`, in that order. P3 mappings are exactly `ENTRY` ordinal `0`, `REAR` ordinal `1`, and `COURT` ordinal `2`, in that order. Every C slot section carries the applicable uppercase `section_role`, repeats the selected mapping ordinal and exact normalized P2/P3 mask after binding the role to its authored section ID, and must be byte-equal to that mapping. Station binds `ENTRY -> station_entry`, `REAR -> station_wing`, and `COURT -> station_yard`; all other bindings are the names shown in the table. A mismatch in role, ordinal, or mask rejects rather than choosing either copy.
- `monument_mass` exists exactly once, in `fixture.fixed.civic_monument.fixed_occupants`, with occupant ordinal `0`; `civic_monument.fixed_occupants` is empty and references that fixed-block definition. `service_core_workshop` and `service_core_tower` each exist exactly once as slot-level fixed occupants on their named Plot slots, each with occupant ordinal `0`; they do not occur in any template or variant. `service_core_tower` has one occupant ID and ordinal across its two elevation-mask records. Every proof-fixture occupant is therefore ordinal `0` within its owning slot or fixed-block definition, with no duplicated occupant definition.

- Initial ownership is exactly `{market_entry,station_entry,garden_entry}`.
- All seven `*_entry` sections are initially available and entry-eligible. Every other section is initially available, unowned, and not entry-eligible. Fixed occupancy never implies ownership.
- Cap provenance is closed. `fixture.template.market` has cap `-3..+6`: `market_hall` overrides it with `-2..+5`, `canal_plot` overrides it with `-1..+3`, and `arcade_plot` has no override and therefore remains `-3..+6`. `fixture.template.courtyard` has cap `-2..+4`: `station_plot` has no override and therefore remains `-2..+4`, while `garden_plot` overrides it with `0..+2`. `fixture.template.tower` has cap `-5..+9`: `workshop_plot` overrides it with `-1..+2`, and `tower_plot` overrides it with `-4..+7`. These are the exact effective physical caps. No other district, template, or slot cap exists in fixture C beyond the root legal range `-5..+9`; these constraints are physical fixture facts only.
- Pedestrian arrival sources and exact authored topology selectors are:

| `arrival_source_id` | Selector |
| --- | --- |
| `gateway_market_north` | `{kind: OUTER_PEDESTRIAN_BAND, slot_id: market_hall, side: NORTH}` |
| `gateway_canal_east` | `{kind: OUTER_PEDESTRIAN_BAND, slot_id: canal_plot, side: EAST}` |
| `gateway_tower_south` | `{kind: OUTER_PEDESTRIAN_BAND, slot_id: tower_plot, side: SOUTH}` |
| `gateway_workshop_west` | `{kind: OUTER_PEDESTRIAN_BAND, slot_id: workshop_plot, side: WEST}` |

These selectors name outer pedestrian bands without coordinates.

Golden resolved counts remain normative expectations:

| Fixture | Expected resolved counts |
| --- | --- |
| A | 1 slot, 1 Plot, 1 section, 4 Street Segments, 4 Intersections, 8 Pedestrian Bands, 4 Carriageways, 8 lanes, 4 arrival sources, 0 fixed occupants. |
| B | 1 slot, 1 Plot, 3 sections, 4 Street Segments, 4 Intersections, 8 Pedestrian Bands, 4 Carriageways, 8 lanes, 0 arrival sources, 0 fixed occupants. |
| C | 9 slots, 7 Plots, 16 sections, 24 Street Segments, 16 Intersections, 48 Pedestrian Bands, 24 Carriageways, 48 lanes, 4 arrival sources, 3 fixed occupants; roles are 7 `PLOT`, 1 `DECORATIVE_FIXED`, and 1 `PUBLIC_PLAZA`. |

For C, `P2(W,D)` uses `h=floor(W/2)`, `t=floor(D/3)`:

- `entry={(x,y)|0<=x<h,0<=y<D} UNION {(x,y)|h<=x<W,0<=y<t}`.
- `rear={(x,y)|h<=x<W,t<=y<D}`.

`P3(W,D)` uses `a=floor(W/3)`, `b=floor(2W/3)`, `m=floor(D/2)`:

- `entry={(x,y)|0<=x<a,0<=y<D} UNION {(x,y)|a<=x<b,0<=y<m}`.
- `rear={(x,y)|a<=x<b,m<=y<D}`.
- `court={(x,y)|b<=x<W,0<=y<D}`.

Apply P3 with ordinals `0/1/2` to market as `market_entry`, `market_rear`, `market_court`, and station as `station_entry`, `station_wing`, `station_yard`. Apply P2 with ordinals `0/1` to canal (`canal_entry`,`canal_rear`), garden (`garden_entry`,`garden_rear`), workshop (`workshop_entry`,`workshop_rear`), arcade (`arcade_entry`,`arcade_rear`), and tower (`tower_entry`,`tower_rear`). Total: exactly 16 section IDs and three occupant IDs. Exact token grids are generated mechanically from these predicates and the fixed-occupancy rectangles; implementation agents must not choose, reinterpret, scale, rotate, or otherwise design their semantic content.

Fixture source-anchor/segment counts remain golden expectations. Literal lowercase SHA-256 values appear only after proof implementation and review.

## Communication and event flow

`assets -> normalize -> validate -> immutable semantic record or ordered diagnostics -> H2 resolver`.

## Persistence impact

Definitions are not save state. Saves reference compatible layout/version/fingerprint; semantic ID changes require H9 migration.

## Editor/runtime behavior

Editor and runtime use identical normalization/validation. Preview is disposable and definitions remain unchanged across sessions.

## Migration and compatibility requirements

`LegacyFootprintLayerAdapter` may read the old mask into one explicit layer only. It is removed by H10. No production save irreversibly depends on the provisional representation before KEEP.

## Expected affected files/systems

Future definition resources, parser, validator, fixture assets, proof tooling, and tests only.

## Acceptance criteria

- Exact predicates, IDs, roles, counts, diagnostics, semantic inclusion, immutability, parity, and reviewed goldens pass A-C.
- Validator and golden evidence covers the inclusive I-JSON semantic-integer boundaries and pre-canonicalization rejection immediately outside them; tighter domain limits for sizes, ordinals, elevations, and other bounded integers; every section/carriageway/lane/occupant ordinal; duplicate-free row-major `(y,x)` ordering for every normalized cell set/mask and signed-ascending elevation masks; exact role-to-ID bindings and byte-equal slot/variant masks; exact `PLOT` buildability-union equality and empty non-`PLOT` sections/buildability; exact initial ownership, availability, and entry eligibility; template, variant, whole-null cap, non-null cap, partial-null rejection, strictest-intersection resolution; fixed-occupant provenance and elevation masks; source selectors; exact road literals/order; and complete permanent outer rings.
- Normalized A-C manifests contain every common/default field, are accepted as direct canonical input, and deterministically produce the reviewed runtime IDs and fingerprints; omitted required fields and any request for implicit defaults reject.
- Evidence records exactly KEEP, REVISE, or REJECT.

## Required tests

Parser/validator malformed cases; semantic integers exactly at `-9007199254740991` and `9007199254740991`; rejection of `-9007199254740992` and `9007199254740992` during parsing/normalization before RFC 8785; tighter domain rejection even for representable but invalid sizes, ordinals, and elevations; normalized manifest completeness and rejection of missing required or implicit-default fields; exact referenced-only catalogs; duplicate-cell and duplicate-elevation rejection; row-major `(y,x)` normalization/permutation cases for every cell-set/mask kind; signed-ascending elevation-mask normalization; partition coverage/connectivity; exact buildability equals section-mask union for every `PLOT`, with missing/extra-cell rejection; exact empty sections/buildability for every non-`PLOT`; exact fixture state sets; root/template/slot cap null and intersection cases including partial-null rejection; all section, mapping, carriageway, lane, and occupant ordinals; `FULL`/`ARRIVAL`/`EAST`/`SOUTH`/`ENTRY`/`REAR`/`COURT` bindings; byte-equal selected-mapping/slot masks; occupant provenance and tower identity across elevations; coordinate-free source selectors; exact `FORWARD`/`REVERSE` road records and outer-ring validation; permutation and formatting invariance; semantic-change fingerprints; editor/runtime and fresh-process parity.

## Performance/scalability checks

Parsing/validation scales with cells/catalogs and requires no scene instantiation.

## Failure and rollback behavior

Any error rejects the package with no partial publication. Goldens never auto-update.

## Technical risks

Resource aliasing, noisy grids, over-flexible overrides, and selector vocabulary drifting into coordinate identity.

## FACTS

- Exact fixture geometry and section mappings above are normative.
- H1 owns semantic inclusion; H2 owns encoding/hash.
- **2026-08-31 Road & Intersection Addendum:** Row depths and column widths have a minimum of 18 tiles. Road profiles have 2-6 total 3-tile lanes, with at least one lane per direction and contiguous same-direction groups.

## ASSUMPTIONS

- Reviewed generated token fixtures are adequate proof artifacts.

## OPEN QUESTIONS

- KEEP/REVISE/REJECT after proof evidence.
- Future authoring editor UX; it cannot change authority or deterministic semantics.

## GodotPrompter skills required by implementation agents

- `resource-pattern`, `assets-pipeline`, `gdscript-patterns`, `godot-testing`.
