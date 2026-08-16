# Wall Assets

Walls are generated procedurally based on tile layout. The wall system uses a shader for cutaway/partial/full visualization modes.

## Wall Segments

| Property | Value |
|----------|-------|
| **Purpose** | Define boundaries between corridors, zones, and exterior. |
| **Height** | 3m (full floor height) |
| **Thickness** | 0.1m |
| **Length** | 1m (per tile edge) |
| **MVP** | Simple flat panel with clipping shader. Single material. |
| **Post-MVP** | Multiple materials (concrete, glass, brick, metal, decorative). Window segments. |

### Wall Types

| Type | Context | Visual |
|------|---------|--------|
| **Corridor wall** | Between corridor tiles and empty space | Shared walls removed between adjacent corridors |
| **Zone perimeter wall** | Around zone boundary | Gaps at doors/transit connections |
| **Floor perimeter wall** | Around floor boundary | Gaps at terraces, skybridges |
| **Business wall** | Around individual business parcel (post-MVP) | Gaps at business entrance |

## Wall Door Segments

| Property | Value |
|----------|-------|
| **Purpose** | Opening in wall where visitors pass through. |
| **Height** | Full wall height (open gap) |
| **Width** | 0.6m (centered in the tile edge) |
| **MVP** | Gap in wall mesh (no door model). |
| **Post-MVP** | Door frame + door panel (open/closed animation). |

### Door Placement Rules

| Connection | Door |
|------------|------|
| Zone ↔ Corridor | Automatic |
| Internal Transit ↔ External Transit | Automatic |
| Business ↔ Transit/Corridor | Automatic (1 per business) |
| Floor ↔ Terrace | Manual (player places) |

## Wall Window Segments (Post-MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Glass sections in exterior walls. |
| **Size** | 1.5m × 2m per window |
| **Material** | Glass (transparent, reflective) |
| **Placement** | On exterior walls, spaced regularly |

## Wall Shader (MVP)

The wall clipping shader handles three visualization modes:

| Mode | Front Walls | Back Walls |
|------|-------------|------------|
| **Cutaway** (default) | 10% height | 100% height |
| **Partial** | 10% height | 10% height |
| **Full** | 100% height | 100% height |

- Front = walls facing the camera direction
- Back = walls facing away from camera
- Camera direction passed as global shader parameter
- Instant mode switching, no mesh swapping

## Wall Materials (Post-MVP)

| Material | Unlock | Visual Style |
|----------|--------|--------------|
| Concrete + Windows | Default | Standard commercial |
| Glass Curtain | Tech tree | Modern, transparent |
| Brick | Tech tree | Warm, traditional |
| Metal Panel | Tech tree | Industrial, sleek |
| Decorative | Tech tree | Ornamental, premium |

## Reuse Opportunities

- Single wall segment mesh (1m wide × 3m tall × 0.1m thick), instanced per wall edge
- Corner cube mesh (0.1m × 3m × 0.1m) at every wall junction
- Door segment is a modified wall segment with a gap
- Window segment is a wall segment with glass material
- All wall types share the same base geometry, differentiated by material and shader params
