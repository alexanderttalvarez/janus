## Decision 2: UI Rendering — SubViewport for Heatmap Overlay
**Date:** 2026-07-28
**Status:** Accepted

### Context
Heatmaps need to overlay the 3D world. We needed to decide between CanvasLayer and SubViewport.

### Decision
Heatmaps rendered via SubViewport overlaid on the 3D game view.

### Rationale
- Allows shader-driven tile coloring independent of 3D rendering
- Can toggle heatmap on/off without affecting 3D scene
- Clean separation between game world and data visualization
