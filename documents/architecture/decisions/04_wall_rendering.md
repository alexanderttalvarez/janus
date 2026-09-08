## Decision 4: Wall Rendering — Shader-based Clipping
**Date:** 2026-07-28
**Status:** Accepted

**Current applicability:** [ADR 33](33_documentation_consistency_and_minimum_contracts.md), 2026-09-08, supersedes the 5% clipping values below with element 12's 10% strip and profile-specific rules. The original body is architectural history, not a second dimension authority.

### Context
Wall visualization has 3 modes: Cutaway (front walls 5%, back walls 100%), Partial (all walls 5%), Full (all walls 100%). We needed to decide between shader clipping vs. mesh swapping.

### Decision
A shader clips walls based on camera direction and current visualization mode.

### Rationale
- No mesh swapping needed — single wall mesh works for all modes
- Instant mode transitions (no loading)
- Camera-relative clipping is natural in a shader (dot product of wall normal vs. camera direction)
