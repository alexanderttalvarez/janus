## Decision 3: Visitor Agents — Node3D with Centralized Tick + Floor-based Culling
**Date:** 2026-07-28
**Status:** Accepted

### Context
Visitors are individual agents with goals, budgets, needs, and pathfinding. We needed to decide between Node3D per visitor vs. pure data with pooled visuals.

### Decision
Each visible visitor is a Node3D. Invisible visitors exist as data only. Floor-based culling limits visible visitors to ~30-60 at any time.

### Rationale
- "What You See Is What Is Simulated" philosophy is maintained for visible visitors
- Floor-based culling reduces visible count from 200-500 to 30-60
- 30-60 `_process` calls doing simple `move_toward` is trivial for Godot 4
- Thought bubbles are trivial as Label3D children
- Full remote inspector debugging access

### Implementation Details
- **Logic:** Centralized tick in VisitorManager every 5 sim seconds (decisions, pathfinding, state changes)
- **Spawning:** VisitorManager attempts one spawn per visitor tick until the active population reaches the current cap of 20. Spawn locations come from the owning PlotData, not arbitrary pedestrian-ring traversal points.
- **Spawn points:** Each PlotData derives four stable corner spawn points from its plot/pedestrian boundaries. The MVP uses `plot_0_corner_nw`, `plot_0_corner_ne`, `plot_0_corner_se`, and `plot_0_corner_sw`.
- **Visual movement:** Each visitor Node3D has `_process` with `position.move_toward(target, speed * delta)` — simple interpolation only
- **Spawn presentation:** New visitor geometry fades from fully transparent to opaque over 2 seconds using per-instance `GeometryInstance3D.transparency`; shared materials are not modified.
- **Leaving:** A visitor is removed only after VisitorManager explicitly marks it `LEAVING` and the visitor reaches its selected spawn point. Passing a spawn point during ordinary movement never removes a visitor.
- **Animation:** Set explicitly by VisitorManager on state change (`play("walk")`, `play("idle")`) — no polling
- **Culling rules:**
  - Same floor as camera → render
  - Skybridge/underground passage connected to current floor → render
  - Pedestrian areas → render only if viewing floor 1, 2, or 3
  - Other floors/buildings → data only, no visual
  - Zoomed out past threshold → hide all visitors
- **Draw calls:** Shared material across all visitor meshes → 1 draw call

### Consequences
- VisitorManager manages lifecycle: creates/destroys Node3Ds when floors change visibility
- Visitor data always exists in `all_visitors` array regardless of visibility
- When camera switches floor, Node3Ds are created at current data positions
- A leaving visitor continues to count toward the population cap until it reaches its spawn point and is removed.
