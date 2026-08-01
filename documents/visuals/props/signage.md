# Signage Assets

## Zone Type Icons (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Visual icons for zone types in the build palette and zone labels. |
| **Size** | 24×24px (UI), 32×32px (large) |
| **Format** | PNG or SVG |
| **Style** | Simple, recognizable icons |

### Zone Type Icons

| Zone Type | Icon Concept | Color |
|-----------|-------------|-------|
| **Retail** | Shopping bag | Purple |
| **Food & Beverage** | Fork & knife or cup | Green |
| **Entertainment** | Game controller or film strip | Orange |
| **Services** | Wrench or briefcase | Blue |
| **Anchor** | Building or star | Red |

## Business Name Labels (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Display business name at center of parcel. |
| **Type** | Label3D (Godot) |
| **Size** | Scales with zoom level |
| **MVP** | Text label with business name (e.g., "Sakura Sushi"). |
| **Post-MVP** | Styled label with business tier indicator. |

## Zone Name Labels (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Display zone name at center of zone. |
| **Type** | Label3D or UI overlay |
| **Format** | "Food & B — Zone A" or custom name |
| **Visibility** | Visible at appropriate zoom levels |

## UI Icons (See ui/icons.md)

Icons used in the UI are documented in the UI category.

## Reuse Opportunities

- Zone type icons: single icon set, recolored per zone type
- Business labels: Label3D, reused for every business
- Zone labels: Label3D, reused for every zone
