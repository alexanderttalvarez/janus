# Zone & Character Materials

## Visitor Material (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Shared material for all visitor meshes. |
| **Type** | StandardMaterial3D |
| **Color** | Variable (8-12 clothing colors) |
| **Roughness** | 0.8 |
| **Metallic** | 0.0 |
| **Key** | Single shared material → 1 draw call for all visitors |

### Visitor Color Palette (MVP)

| Color | Hex (suggested) | Usage |
|-------|-----------------|-------|
| Navy | #2C3E50 | Common |
| Red | #E74C3C | Common |
| Green | #27AE60 | Common |
| Blue | #3498DB | Common |
| Gray | #95A5A6 | Common |
| Brown | #8B6914 | Common |
| Purple | #8E44AD | Less common |
| Orange | #E67E22 | Less common |
| Teal | #1ABC9C | Less common |
| Yellow | #F1C40F | Rare |

## Staff Material - Cleaner (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Material for Cleaner staff mesh. |
| **Type** | StandardMaterial3D |
| **Color** | Light blue or green (#5DADE2 or #58D68D) |
| **Distinction** | Clearly different from visitor colors |

## Staff Material - Security (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Material for Security staff mesh. |
| **Type** | StandardMaterial3D |
| **Color** | Dark blue or black (#2C3E50 or #1C2833) |
| **Distinction** | Clearly different from visitors and cleaners |

## Heatmap Shader Material (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Renders heatmap colors over the floor based on tile data. |
| **Type** | ShaderMaterial |
| **Input** | Data texture or uniform array with tile values |
| **Output** | Color gradient per tile |

### Heatmap Color Scales

| Mode | Hot | Medium | Cold |
|------|-----|--------|------|
| **Visitor Density** | Red (#E74C3C) → Orange (#F39C12) | Yellow (#F1C40F) | Blue (#3498DB) → Dim |
| **Zone Viability** | Green (#27AE60) | Yellow (#F1C40F) | Gray (#95A5A6) |

## Construction Overlay Material (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Visual overlay showing construction progress on zone tiles. |
| **Type** | StandardMaterial3D with transparency |
| **Phase 1 (0-33%)** | Dark gray (#5D6D7E), 50% opacity |
| **Phase 2 (34-66%)** | Medium gray (#AEB6BF), 30% opacity |
| **Phase 3 (67-99%)** | Zone color, 20% opacity |

## Reuse Opportunities

- Single visitor material with color parameter → all visitors share 1 draw call
- Staff materials are variants of visitor material with fixed colors
- Heatmap shader is shared across all heatmap modes (just change color scale)
- Construction overlay uses the same material with different colors per phase
