# Column Assets

> **Status:** Draft. Column system is still in design phase. See game design document `10_structural_system_columns.md`.

## Column (Post-MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Structural support elements. Visual only, no gameplay effect. |
| **Placement** | Auto-placed (player does not manually place). |
| **Size** | ~0.4m × 0.4m × 4m (per floor) |
| **MVP** | Not needed. |
| **Post-MVP** | Simple low-poly column. Style matches building material. |

### Open Design Questions

1. **Placement logic**: Fixed grid? Load-based? Edge-driven? Hybrid?
2. **Dynamic updates**: Reposition on floor edit? Stay fixed?
3. **Visual integration**: Visible through walls? Match zone interior style?
4. **Performance**: 3D objects or baked into floor texture?

### MVP Approach

Skip columns entirely for MVP. Add placeholder grid markers if needed for spatial reference.
