## Decision 5: Heatmap Implementation — Shader-driven Mesh
**Date:** 2026-07-28
**Status:** Accepted

### Context
Heatmaps overlay tile data (visitor density, zone viability) with color gradients. We needed to decide between per-tile overlays, shader-driven mesh, or post-processing.

### Decision
A single shader-driven mesh renders heatmap colors based on tile data passed as uniforms or textures.

### Rationale
- One draw call for the entire heatmap
- No per-tile MeshInstance3D overhead
- Color transitions are smooth and GPU-accelerated
- Easy to swap heatmap modes by changing the data texture
