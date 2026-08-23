# Scale Guide

Use tile-relative dimensions unless a value below is explicitly confirmed. Earlier planning assumed a two-metre tile and a four-unit floor rise; neither value is supported by current project data and must not be used.

## Confirmed Working Scale

| Item | Value | Status / source |
|---|---:|---|
| Building footprint | 25 × 25 tiles | **FACT** — `09_building_structure_system.md`; current `main_game.tscn` spans X/Z 0–25. |
| Horizontal grid spacing | 1 Godot world unit per tile | **FACT** — current live scene aligns the 25-tile plot to X/Z 0–25. This is not a confirmed real-world metre conversion. |
| Wall height | 3.0 world units | **FACT** — `12_wall_system.md`; corner cubes are `0.1 × 3.0 × 0.1`. |
| Pedestrian margin in current scene | 5 world units / tiles | **FACT** — current `PlotData` default and live pedestrian-ring placement. |
| Road width | 6 tiles | **FACT** — `09_building_structure_system.md`. |
| Current camera zoom | Orthographic size 5.0–50.0 | **FACT** — `16_camera_system_architecture.md`. |
| Current camera rotation | 90° increments | **FACT** — `concept.md`, `16_camera_system_architecture.md`. |

## Grid-Footprint Conventions

| Asset family | Required footprint | Notes |
|---|---|---|
| Floor surface / zone overlay | Variable, tile-aligned | A floor may be any valid footprint within the plot mask. |
| Corridor / internal transit | 1+ tiles | Any contiguous shape and width. |
| Stairs | Minimum 2 × 2 tiles | May be extended for wider stairs. |
| Elevator shaft | 1 × 1 tile | Spans selected connected floors. |
| Elevator lobby | 1 × 1 tile per served floor | At each stopping floor. |
| Escalator pair | 2 × 1 tiles per direction | Scope unresolved; see [asset_catalog.md](asset_catalog.md). |
| Operations Room | 2 × 2 tiles | All four tiles must be owned and empty. |
| Bin | 1 tile | Each bin reduces garbage spawn on its floor. |
| Terrace | Variable, tile-aligned | Each tile must touch non-built space. |
| Zone / tenant parcel | Variable contiguous area | Generated parcels are rectangular and have transit frontage. |

## Vertical & Edge Rules

- **FACT:** There can be up to F1–F10 and U1–U3; upper floors can be smaller and may overhang the floor below by up to two tiles per edge without exceeding the plot boundary.
- **FACT:** Wall geometry is centred on tile boundaries. Wall junctions use non-overlapping corner cubes; the 3.0-unit wall outline must remain continuous.
- **FACT:** Terrace edges facing non-built space have no perimeter wall. Interior-to-terrace access uses a manually placed door.
- **OPEN QUESTION:** The vertical floor-to-floor interval, floor-slab depth, nominal door dimensions, character height, and real-world unit conversion are not specified. Do not invent them in a production asset; use relative scale studies until confirmed.

## Camera-Readability Implications

- The camera is orthographic and rotates in four directions. All directional details must read from every cardinal camera rotation.
- At current-floor view, walls can be full, cutaway, or partial. Do not rely on a front wall for essential interaction readability.
- Visitors are hidden above zoom size 35 and culled outside the viewed floor. Character features and small props must communicate primarily through silhouette and color at close/mid zoom.

## Source Conflict: Pedestrian Ring

`09_building_structure_system.md` defines a 2-tile pedestrian area around plots, while the accepted architecture and live scene use a configurable 5-tile pedestrian margin. Until design resolves this, produce perimeter assets as modular tile-aligned pieces that can support either width; do not bake a fixed five-tile visual composition.
