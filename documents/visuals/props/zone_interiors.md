# Zone Interior Assets

## Zone Floor Overlay (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Colored overlay on floor tiles showing zone type. Visible during zone editing (hover/paint) and optionally after. |
| **Size** | 2m × 2m per tile |
| **Colors** | Retail=purple, Food&Bev=green, Entertainment=orange, Services=blue, Anchor=red |
| **Opacity** | 50% on hover, 100% on paint, 0% when finished (overlay disappears) |
| **MVP** | Simple colored plane overlay per tile. |
| **Post-MVP** | Textured overlay with zone-specific patterns. |

## Business Parcel Overlay (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Visual boundary of individual business parcels within a zone. |
| **Style** | Thin line or subtle floor pattern difference |
| **MVP** | Simple colored line around parcel boundary. |
| **Post-MVP** | Different floor material per business, visible walls between parcels. |

## Business Signage (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Displays business name above entrance. |
| **Type** | Label3D or sprite-based sign |
| **Size** | ~1m wide × 0.3m tall |
| **Position** | Above business door, at ~3m height |
| **MVP** | Label3D with business name text (e.g., "Sakura Sushi"). |
| **Post-MVP** | 3D sign model with business-specific branding. |

## Construction Phase Visuals (MVP)

Construction has 3 visual phases, each representing ~33% of total build time.

| Phase | Progress | Visual | MVP Approach |
|-------|----------|--------|--------------|
| **Foundation** | 0-33% | Basic structure, no detail | Colored overlay (gray/brown) on zone tiles |
| **Framing** | 34-66% | Shape visible, materials partial | Colored overlay (lighter gray) + simple wireframe |
| **Finishing** | 67-99% | Near-complete, branding visible | Colored overlay (near-final colors) + signage preview |
| **Complete** | 100% | Fully operational | Final zone appearance with business name |

### MVP Construction Visuals

Simplest approach: colored overlay that changes color per phase.
- Phase 1: Dark gray overlay (50% opacity)
- Phase 2: Medium gray overlay (30% opacity)
- Phase 3: Zone color overlay (20% opacity) + business name appears

### Post-MVP Construction Visuals

- Phase 1: Scaffolding mesh around zone perimeter
- Phase 2: Partial walls, exposed framing
- Phase 3: Complete walls, signage being installed
- Each phase is a separate mesh or material variant

## Reuse Opportunities

- Zone overlay: single plane mesh, material color changes per zone type
- Construction overlay: same mesh, different colors per phase
- Business signage: Label3D, reused for every business
