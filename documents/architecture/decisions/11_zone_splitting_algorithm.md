## Decision 11: Zone Splitting Algorithm — Full Recalculation with Tenant Preservation
**Date:** 2026-07-28
**Status:** Accepted

### Context
When a zone is edited (tiles added/removed, typologies changed), the frontage-based splitting algorithm must re-run. We needed to decide between incremental updates vs. full recalculation, and how to handle tenant preservation.

### Decision
- **Full recalculation** on every zone edit. The splitting algorithm is fast (pure GDScript on small arrays, milliseconds).
- **Tenant preservation** by spatial matching: after recalculation, existing parcels are matched to new parcels by overlap. If a parcel still meets minimum size, its tenant is preserved.
- **Eviction** only when a parcel falls below its minimum tile requirement after tile removal.
- **ZoneSplitter** and **ZoneBusinessAssigner** are pure static classes with no Godot dependencies.

### Algorithm Phases
1. **Detect Frontage:** Find zone tiles bordering walkable areas (corridors, transit)
2. **Reserve Frontages:** Group contiguous frontage tiles into segments, distribute to target store count
3. **Grow Rectangles:** Each frontage seed grows inward until target area or boundary
4. **Validate and Repair:** Merge undersized parcels, fill gaps, ensure frontage connectivity
5. **Assign Businesses:** Graph coloring to prevent adjacent same-subtype parcels

### Update Flow
```
Player edits zone (add/remove tiles, change typology)
    ↓
ZoneManager identifies affected parcels
    ↓
For each affected parcel:
    if new_tile_count < min_area → mark for eviction
    else → preserve tenant
    ↓
Evicted tenants trigger:
    - 1-week exclusivity lock
    - EventBus.tenant_closed
    - Prestige recalculation
    ↓
ZoneSplitter.split() re-runs on updated zone
    ↓
Existing tenants matched to new parcels by spatial overlap
    ↓
ZoneBusinessAssigner.assign() for new unassigned parcels
    ↓
New tenant applications begin (after 1-day delay)
```

### Rationale
- Incremental updates are exponentially more complex (split parcels, new frontage distribution, edge cases)
- Full recalculation is fast enough (milliseconds on 25×25 grid)
- Tenant preservation is the critical concern, not geometry recalculation
- Design doc says "AI recalculates" — full recalculation is the intended behavior

### Consequences
- `ZoneSplitter` and `ZoneBusinessAssigner` are easily unit-testable
- Zone edits are atomic: either the full recalculation succeeds, or it fails and the zone reverts
- Eviction logic is simple: tile count vs. minimum area
