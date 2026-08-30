## Decision 9: Footprint Masks — Text Files for Plot/Floor Shapes
**Date:** 2026-07-28
**Status:** Complete format superseded by Decision 27

### Supersession (2026-08-30)

[Decision 27](27_district_layout_templates.md) supersedes the character legend below as a complete plot/floor definition because `.` and `o` conflate ownership, availability, occupancy, and buildability. A simple character-mask parser may remain for one boolean token-grid cell layer. The provisional candidate authoring format combines `.tres` metadata with layered token grids, while mutable ownership, construction, and occupancy remain in separate runtime state. The final authoring format remains subject to proof-layout validation.

### Context
Post-MVP scenarios need irregular plot shapes, pre-occupied tiles, and varying floor footprints. We needed a data-driven way to define which tiles exist on each floor.

### Decision
Footprint masks are plain text files. Each character represents one tile. Lines represent rows (Y axis). Comments start with `#`.

### Character Legend
| Char | Meaning |
|---|---|
| `.` | Valid tile (can be purchased and built on) |
| `x` | Invalid tile (no tile exists here) |
| `o` | Pre-occupied tile (exists, owned, can't be purchased) |
| `#` | Comment line (ignored) |

### Rationale
- Editable in any text editor (no image editor needed)
- 1 char = 1 tile — obvious and precise
- Text diff in version control (clear change history)
- Self-documenting (can add header comments)
- Trivial to parse (~20 lines of GDScript)

### File Location
`resources/plots/footprints/` — one `.txt` file per floor shape.

### Loading
`FootprintLoader` static class parses text files into `Array[Array[bool]]` (footprint) and `Array[Vector2i]` (pre-occupied positions). `FloorDefinition` loads its footprint at runtime from `footprint_path`.

### Consequences
- `FootprintLoader` class in `scripts/grid/footprint_loader.gd`
- `FloorDefinition.footprint_path` replaces `footprint_mask: Texture2D`
- Pathfinding checks `is_valid_tile(x, y)` before adding neighbors
- MVP uses `25x25_full.txt` (all dots)
