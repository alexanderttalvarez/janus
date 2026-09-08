## Decision 1: Scene Architecture — Single Game Scene with Sub-scene Instancing
**Date:** 2026-07-28
**Status:** Accepted

**Current applicability:** Amended by [ADR 33](33_documentation_consistency_and_minimum_contracts.md), 2026-09-08. Preserve scene composition; universal EventBus wiring below is historical guidance, not a mandate.

### Context
The game has many interconnected systems (economy, visitors, tenants, UI, grid). We needed to decide between few large scenes vs. many smaller scenes.

### Decision
Option A: One `main_game.tscn` that composes everything via instanced sub-scenes.

### Rationale
- No scene transitions during gameplay
- All systems coexist naturally
- Simpler state management
- Sub-scenes provide modularity without lifecycle complexity

### Consequences
- The main game scene tree will be large but well-organized
- Sub-scenes must have clean `@export` interfaces
- Cross-sub-scene communication goes through EventBus
