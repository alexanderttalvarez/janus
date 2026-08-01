## Decision 4: Wall Rendering — Shader-based Clipping
**Date:** 2026-07-28
**Status:** Accepted

### Context
Wall visualization has 3 modes: Cutaway (front walls 5%, back walls 100%), Partial (all walls 5%), Full (all walls 100%). We needed to decide between shader clipping vs. mesh swapping.

### Decision
A shader clips walls based on camera direction and current visualization mode.

### Rationale
- No mesh swapping needed — single wall mesh works for all modes
- Instant mode transitions (no loading)
- Camera-relative clipping is natural in a shader (dot product of wall normal vs. camera direction)
