# Handoff 02: Resolved District Model

## Status

**Draft - ready for architecture approval.** H2 provisional resolver work may proceed with H1 proof work before KEEP. Production freeze and H3 production implementation require H1 KEEP and reviewed frozen H1/H2 goldens.

## Purpose

Define the pure deterministic resolver and immutable `ResolvedDistrictSnapshot`, including IDs, geometry, topology descriptors, attachments, transforms, ordering, diagnostics, and definition fingerprint.

## Dependencies

- [H1](01_definition_schema_and_validation.md) normalized semantics and exact fixtures.
- [Decision 27](../../decisions/27_district_layout_templates.md) and
  [Decision 28](../../decisions/28_visitor_arrival_architecture.md).

## Source-of-truth documents

- [Handoff index](./_index.md)
- [Architecture blueprint](../../design_handoff.md)

## Current-state findings

Current grid/scene coordinates and corner records mix identity, geometry, and state. They cannot define a deterministic multi-plot snapshot.

## Target state

Equal normalized semantic input yields byte-identical canonical input, IDs, topology, transforms, diagnostics, and fingerprint without Nodes, sessions, policy, random, clock, filesystem, or mutable Resources.

## Scope

Resolved slots/Plots/sections/fixed occupancy/public-realm descriptors/source attachments/transforms; ordering; canonical encoding/hash; immutable state record shapes.

## Explicit non-goals

Source parsing, session mutation, transactions, projection Nodes, traffic graph authority, source allocation, or save migration.

## System ownership

| Owner | Responsibility |
| --- | --- |
| H1 | Semantic inclusion/exclusion. |
| H2 resolver | Resolution, canonical bytes, SHA-256. |
| H3 District Runtime | Mutable state lifecycle and writes. |

## Data contracts

### Snapshot

The snapshot contains layout/schema/resolver versions, fingerprint, resolved slots/Plots/sections/caps/masks, fixed occupancy, public-realm descriptors, authored `arrival_source_id`, authored selector, resolved topology attachment ID, and derived dimensionless grid poses/bounds. Authored selector, resolved attachment, and pose are distinct fields. Selector resolution chooses the target topology ID included in source-attachment identity; a pose or presentation transform does not create or alter identity.

### Canonical byte framing

The byte contract is fixed:

```text
UTF-8("JANUS_DISTRICT_DEFINITION\0" + canonical_schema_version + "\0")
+ RFC 8785 JSON Canonicalization Scheme bytes of the normalized semantic record
```

The record permits only normalized integer, string, boolean, null, array, and object values. Every semantic integer must already be in the inclusive I-JSON safe range `[-9007199254740991, 9007199254740991]`; parsing/normalization rejects values outside that range before RFC 8785 is invoked, while domain validation imposes tighter sizes, ordinals, elevations, and other field limits. Floating and non-finite semantic values are prohibited. The digest is SHA-256 encoded as lowercase 64-character hexadecimal. H1 decides semantic fields; H2 exclusively decides this closed encoding and hash contract.

### Identity, coordinates, and ordering

- Every textual runtime ID is framed exactly as `jid1/<type_tag>/<component>...`. Type tags below are literal. Every string component is first required to be valid UTF-8 and NFC as established by H1, then represented by its UTF-8 bytes; every byte outside the RFC 3986 unreserved set `[A-Za-z0-9._~-]`, including `/` and `%`, is percent-encoded as `%` followed by two uppercase hexadecimal digits. No Unicode normalization occurs during H2 framing beyond requiring H1's NFC input.
- Integer components use canonical ASCII decimal. Zero is `0`; positive integers use digits with no plus sign or leading zeros. Signed elevation is `0`, positive digits with no plus sign or leading zeros, or `-` followed by positive digits with no leading zeros. Enum components are the specified uppercase literals.
- Runtime Slot: `(slot, layout_id, authored_slot_id, slot_ordinal)`.
- Runtime Plot: `(plot, layout_id, slot_id, slot_ordinal)`.
- Runtime Section: `(section, runtime_plot_id, authored_section_id, section_ordinal)`.
- Runtime Floor: `(floor, runtime_plot_id, signed_elevation)`.
- Runtime Cell: `(cell, floor_id, x, y)`.
- Horizontal Street Segment: `(street_h, layout_id, horizontal_boundary_id, column_track_id)`.
- Vertical Street Segment: `(street_v, layout_id, vertical_boundary_id, row_track_id)`.
- Intersection: `(intersection, layout_id, horizontal_boundary_id, vertical_boundary_id)`.
- Pedestrian Band: `(ped_band, street_segment_id, side)`, where side is exactly `NEGATIVE` or `POSITIVE`.
- Carriageway: `(carriageway, street_segment_id, authored_carriageway_ordinal)`.
- Lane: `(lane, carriageway_id, authored_lane_ordinal)`.
- Source attachment: `(source_attachment, layout_id, arrival_source_id, resolved_target_topology_id)`.
- Fixed occupant: `(fixed_occupant, runtime_slot_id, authored_occupant_id, occupant_ordinal)`.
- Nested runtime IDs are encoded as single components, so their `/` and any `%` bytes are escaped by the same rule. A collision between any distinct identity tuples is a resolver error and rejects the snapshot.
- Coordinates appear only in local Cell identity. Parent Plot, Section, Floor, Street Segment, Intersection, Pedestrian Band, Carriageway, Lane, source-attachment, and fixed-occupant topology identities never derive from coordinates, transforms, traversal, or collection order.
- Resolved snapshot type rank is exactly: `0` runtime slot, `1` runtime Plot, `2` runtime Section, `3` fixed occupant, `4` horizontal Street Segment, `5` vertical Street Segment, `6` Intersection, `7` Pedestrian Band, `8` Carriageway, `9` Lane, and `10` source attachment. Mixed snapshot collections sort by this rank. Type-specific collections sort by parent ID, then semantic ordinal, then stable ID; fields that do not apply are absent from the sort key rather than inferred. This ordering is output ordering only and never contributes an unlisted identity-tuple component.
- Every normalized cell set/mask is duplicate-free and ordered row-major ascending by `(y,x)`, comparing `y` first and then `x`. Fixed-occupant elevation masks are duplicate-free by elevation and ordered by signed elevation ascending. Objects follow RFC 8785 key ordering; semantically ordered authored arrays retain their authored semantic order unless this contract assigns their normalized order.
- Physical cap is the strictest district/template/slot intersection. Progression policy is queried later and can only tighten it.

### District coordinate model

H2 emits dimensionless `DistrictGridPose` values, never Godot `Transform3D` values. The closed pose shape is `(x4, z4, elevation, facing)`: `x4` and `z4` are signed integers in quarter-tile units, `elevation` is a signed integer floor index, and `facing` is exactly `NORTH`, `EAST`, `SOUTH`, `WEST`, or `NONE`. Quarter-tile coordinates supersede a half-tile `x2/z2` representation because valid interval centers can lie on quarter tiles. `DistrictGridRect` is the half-open integer-quarter rectangle `(minimum_x4, minimum_z4, maximum_x4, maximum_z4)`, with each minimum no greater than its maximum. These poses and bounds are fingerprint-independent derived data. H4 alone applies physical scale and creates Godot transforms.

Grid `+X` is east/right, grid `+Z` is south/down, and physical `+Y` later maps from elevation. Origin `(0,0)` is the northwest exterior corner of the complete outer ring. Let `P` be the selected road profile's pedestrian width and let `C = 2*P + sum(all lane widths across the profile's ordered carriageways)`. For slot column `j` and row `i`, in tile units:

```text
slot_minimum_x(j) = C + sum(column_width[k] for k < j) + j*C
slot_minimum_z(i) = C + sum(row_depth[k] for k < i) + i*C
district_width  = sum(column_width) + (column_count + 1)*C
district_depth  = sum(row_depth) + (row_count + 1)*C
```

Multiply tile-coordinate rectangle edges by four when storing `DistrictGridRect`. Cell `(x,y)` on a slot-local mask has center `(slot_minimum_x + x + 1/2, slot_minimum_z + y + 1/2)`, encoded as `x4=4*slot_minimum_x+4*x+2` and `z4=4*slot_minimum_z+4*y+2`. A slot pose is its northwest minimum at elevation `0`, facing `NONE`; each floor pose has the same `x4/z4`, its signed elevation, and facing `NONE`. Sections and fixed occupants retain slot-local masks and signed elevation masks; resolving their cell poses uses this formula without creating identity.

### Exact topology geometry

Define boundary starts from prefix sums: horizontal boundary `hi` starts at `z = sum(row_depth[k] for k < i) + i*C`, and vertical boundary `vj` starts at `x = sum(column_width[k] for k < j) + j*C`. At the crossing of `hi` and `vj`, the intersection is exactly the `C x C` half-open rectangle `[vertical_start, vertical_start+C) x [horizontal_start, horizontal_start+C)`. Horizontal segment `(hi,col_j)` is the column-width-by-`C` rectangle between its adjacent intersections; vertical segment `(vj,row_i)` is the `C`-by-row-depth rectangle between its adjacent intersections. These formulas include the outer boundary intervals and generate all and only the H1 golden topology counts.

Within a horizontal corridor, the first `P` tiles across `Z` form pedestrian band `NEGATIVE` (north), the last `P` form `POSITIVE` (south), and the middle is carriageway. Within a vertical corridor, the first `P` tiles across `X` form `NEGATIVE` (west), the last `P` form `POSITIVE` (east), and the middle is carriageway. Ordered lanes pack contiguously through that middle from the `NEGATIVE` band toward the `POSITIVE` band: first by carriageway order, then lane order. `FORWARD` means east on horizontal segments and south on vertical segments; `REVERSE` means west on horizontal segments and north on vertical segments. The H1 fixture order therefore places ordinal-0 `FORWARD` adjacent to the `NEGATIVE` band and ordinal-1 `REVERSE` adjacent to the `POSITIVE` band, with no geometric tie-break or traversal dependency.

### Source selector and gateway pose resolution

`OUTER_PEDESTRIAN_BAND` with `slot_id` and side resolves to the unique outer-ring street segment adjacent to that slot frontage and then to that segment's pedestrian band adjacent to the slot: `POSITIVE` on a north or west outer corridor, `NEGATIVE` on a south or east outer corridor. Zero matches or multiple matches reject. The resolved band's topology ID is the `resolved_target_topology_id` framed into the source-attachment tuple; geometry contributes no additional identity.

Represent the selected slot frontage span as the half-open rectangle spanning the slot edge's along-frontage interval and the full adjacent corridor depth. The gateway rectangle is its intersection with the resolved band rectangle. The gateway pose is the exact rectangle center represented in integer quarter-tile units, with no floats or rounding. Facing is inward: north side `SOUTH`, east side `WEST`, south side `NORTH`, west side `EAST`. Empty intersections, non-point-representable centers, or any arithmetic overflow reject.

### Fixture geometry goldens

All rectangles below are `(minimum_x4,minimum_z4,maximum_x4,maximum_z4)` and are half-open. These values are exact H2 proof outputs independent of H4 presentation metrics.

| Fixture | `C` | District rect | Horizontal boundary starts `z4` | Vertical boundary starts `x4` | Exact slot rects |
| --- | ---: | --- | --- | --- | --- |
| A | 16 | `(0,0,228,228)` | `[0,164]` | `[0,164]` | `legacy_anchor=(64,64,164,164)` |
| B | 16 | `(0,0,248,288)` | `[0,224]` | `[0,184]` | `variable_anchor=(64,64,184,224)` |
| C | 18 | `(0,0,624,576)` | `[0,144,312,504]` | `[0,152,336,552]` | `market_hall=(72,72,152,144)`; `civic_monument=(224,72,336,144)`; `canal_plot=(408,72,552,144)`; `station_plot=(72,216,152,312)`; `central_plaza=(224,216,336,312)`; `garden_plot=(408,216,552,312)`; `workshop_plot=(72,384,152,504)`; `arcade_plot=(224,384,336,504)`; `tower_plot=(408,384,552,504)` |

For each row, the boundary starts plus `4*C` and the exact track widths/depths from H1 instantiate the topology formulas above without any unspecified coordinate: each intersection starts at one horizontal/vertical pair and has size `(4*C)x(4*C)`, and each intervening segment uses the corresponding H1 track extent. Pedestrian-band, carriageway, and lane rectangles then follow the exact profile widths and packing order.

Exact source poses are:

| Fixture/source | Exact resolved target | `DistrictGridPose` |
| --- | --- | --- |
| A `gateway_north` | `ped_band(street_h(h0,col_0),POSITIVE)` | `(114,54,0,SOUTH)` |
| A `gateway_east` | `ped_band(street_v(v1,row_0),NEGATIVE)` | `(174,114,0,WEST)` |
| A `gateway_south` | `ped_band(street_h(h1,col_0),NEGATIVE)` | `(114,174,0,NORTH)` |
| A `gateway_west` | `ped_band(street_v(v0,row_0),POSITIVE)` | `(54,114,0,EAST)` |
| C `gateway_market_north` | `ped_band(street_h(h0,col_0),POSITIVE)` | `(112,60,0,SOUTH)` |
| C `gateway_canal_east` | `ped_band(street_v(v3,row_0),NEGATIVE)` | `(564,108,0,WEST)` |
| C `gateway_tower_south` | `ped_band(street_h(h3,col_2),NEGATIVE)` | `(480,516,0,NORTH)` |
| C `gateway_workshop_west` | `ped_band(street_v(v0,row_2),POSITIVE)` | `(60,444,0,EAST)` |

B has no source pose by contract. Geometry goldens additionally enumerate every generated intersection, segment, pedestrian band, carriageway, and lane rectangle from the formulas above. Metamorphic fixtures translate equivalent integer-quarter geometry and include odd/even track, pedestrian-band, and frontage sizes; exact centers, adjacency, lane packing, bounds, and target topology IDs must translate without changing authored identity or requiring floating arithmetic.

### State record boundary

H2 defines the following closed sparse authority-state schema; H3 owns lifecycle and mutation, and H9 wraps it without extending it.

- `DistrictState` has exactly integer `state_schema_version=2`, nonnegative integer `district_revision`, string `layout_id`, integer `layout_definition_version`, lowercase SHA-256 `definition_fingerprint`, ordered `plot_states`, ordered `street_segment_states`, ordered `arrival_source_states`, and ordered `demolished_fixed_occupant_ids` containing runtime fixed-occupant IDs.
- `PlotState` has exactly `runtime_plot_id`, ordered `section_state_overrides`, and ordered `floor_states`. It exists only when at least one child value differs from the immutable definition baseline; an otherwise empty Plot record is forbidden.
- `PlotSectionState` has exactly `runtime_section_id`, current boolean `owned`, and current boolean `available`. It exists only when either current value differs from its immutable initial definition value and always stores both booleans. Entry eligibility and buildability are immutable definition facts and never appear here.
- `FloorState` has exactly `floor_id`, signed integer `elevation`, and normalized ordered cell sets `acquired_cells` and `constructed_cells`. It exists only when either set is nonempty. Every constructed cell must be in effective acquired rights and satisfy definition rights and physical/progression caps; construction without effective acquired rights rejects. Elevation `0` may contain `acquired_cells` as tile-level floor-space state, independently of section land rights, including partial sets. Section ownership remains separately derived and is neither granted nor revoked by elevation-0 acquired cells.
- `StreetSegmentState` has exactly `street_segment_id` and boolean `converted`. Only internal segments may have a record; the false baseline is omitted and outer-ring records are forbidden.
- `ArrivalSourceState` has exactly `arrival_source_id` and boolean `enabled`. A record is omitted when `enabled` equals immutable `initially_enabled`. Reservations, pending cohorts, transforms, attachments, and topology are forbidden.

Current fixed occupancy is the immutable snapshot occupant set minus `DistrictState.demolished_fixed_occupant_ids`, covering decorative non-Plot occupants and Plot occupants uniformly. Demolition applies atomically to one whole stable runtime fixed-occupant ID across all of its elevation masks; partial elevation demolition is unrepresentable. `district_revision` is the sole district concurrency revision: no child record has a revision. State collections use ascending stable-ID order; within each Plot, `section_state_overrides` use runtime section ID, `floor_states` use signed elevation ascending then floor ID, and all nested cell sets use row-major `(y,x)`. Duplicate IDs, elevations, or cells reject, and empty override records are forbidden. This is the complete district persistence inclusion. Derived Active/Fully Owned flags, rights masks, intersections, graphs, geometry, transforms, reservations, and caches are not mutable district state.

## Communication and event flow

`H1 values -> pure resolve -> immutable snapshot or ordered diagnostics -> H3 session`.

## Persistence impact

Saves store identity/fingerprint and sparse state only. Definition mismatch without registered migration rejects.

## Editor/runtime behavior

The same resolver/encoder runs in editor, runtime, tests, and load preflight.

## Migration and compatibility requirements

Legacy `plot_0`, floor labels, and source corners are not snapshot identity. Explicit H3/H9 boundaries migrate them.

## Expected affected files/systems

Future resolver, immutable values, canonical encoder, fixture goldens, and tests.

## Acceptance criteria

- A-C exact IDs/counts, section/occupant/cap resolution, topology rectangles, grid poses/bounds, source targets/poses, and reviewed literal fingerprints pass after implementation.
- Canonical bytes are identical across platforms/contexts and change for every included semantic change; no out-of-I-JSON-range semantic integer reaches RFC 8785.
- Snapshot collections are immutable and safe across two sessions.
- Sparse state records satisfy the complete inclusion/omission rules, permit elevation-0 tile-level acquired state, and use `district_revision` as their sole concurrency revision.

## Required tests

Golden, metamorphic, RFC 8785 conformance, domain framing, semantic inclusion/exclusion, grid-pose/bounds, topology, cap, immutability, and parity tests. Canonical-number coverage accepts semantic integers exactly at `-9007199254740991` and `9007199254740991`, rejects `-9007199254740992` and `9007199254740992` before RFC 8785, and proves tighter domain rejection for representable but invalid sizes, ordinals, and elevations. Geometry coverage includes every A-C rectangle and source pose above; unique/no-match/multiple selector cases; target-ID attachment framing; horizontal/vertical direction literals; exact lane packing; translated geometry; odd/even interval centers; negative signed coordinates where translated; integer-only round trips; and rejection of overflow or unrepresentable values. ID coverage includes every literal type tag and exact tuple, including Runtime Slot and fixed occupant through `runtime_slot_id`; nested-ID escaping; `/` and `%` escaping with uppercase hex; non-ASCII NFC UTF-8 components; canonical integer/elevation forms; enum literals; collision rejection; and golden IDs for A-C. Ordering tests cover the exact ranks `0..10`, parent-ID/semantic-ordinal/stable-ID type ordering, state stable-ID ordering, signed-ascending nested floors/elevation masks, row-major `(y,x)` cells, and duplicate rejection. State-schema invariant tests cover exact fields/types, canonical ordering, baseline omission, forbidden empty overrides, partial elevation-0 acquisition independent of section rights, construction-subset-effective-acquisition validation, caps, internal-only conversion, immutable outer ring, initially-enabled omission, DistrictState whole-occupant demolition across elevations for decorative and Plot occupants, no child revisions, and rejection of every excluded derived/reservation field.

## Performance/scalability checks

Work scales with authored cells and generated topology, not theoretical elevation volume.

## Failure and rollback behavior

Any resolver error returns diagnostics and no partial snapshot; prior session/preview remains unchanged.

## Technical risks

Mutable collection aliases, incorrect RFC 8785 implementation, and unstable topology ordinals.

## FACTS

- H2 encoding/hash is fully decided.
- H2's derived transform contract is the dimensionless integer-quarter `DistrictGridPose`; H4 owns physical projection.
- Literal SHA values are proof outputs, not pre-proof architecture guesses.
- **2026-08-31 Road & Intersection Addendum:** Corrected the vertical-boundary prefix notation to use column index `j`. H2 continues to resolve topology descriptors only; H4 remains projection lifecycle only, with no retroactive H4 semantic change.

## ASSUMPTIONS

- Immutable value wrappers can prevent Array/Dictionary alias mutation.

## OPEN QUESTIONS

- Cache representation and eviction only; cache behavior cannot affect output.

## GodotPrompter skills required by implementation agents

- `resource-pattern`, `gdscript-advanced`, `math-essentials`, `godot-testing`.
