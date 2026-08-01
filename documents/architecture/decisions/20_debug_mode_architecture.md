## Decision 20: Debug Mode Architecture — DebugManager Autoload
**Date:** 2026-07-28
**Status:** Accepted

### Context
Development requires a debug mode to bypass unlocks, costs, and time constraints for testing.

### Decision
- **DebugManager is an autoload** — available globally during development
- **Auto-disabled in release builds** — `queue_free()` if `OS.has_feature("release")`
- **Toggle flags**: `god_mode` (unlocks everything), `infinite_money`, `instant_construction`, `time_warp`
- **Debug UI overlay** — toggle with F12, shows toggles and quick-action buttons

### Integration Points
- `TechTreeManager.can_unlock()`: returns `true` if `DebugManager.god_mode`
- `EconomyManager.subtract()`: returns `true` if `DebugManager.infinite_money`
- `TenantManager.start_construction()`: sets duration to 0 if `DebugManager.instant_construction`
- `TimeManager`: sets speed to 100 if `DebugManager.time_warp`

### Rationale
- Autoload ensures debug flags are accessible from any system
- Auto-disabled in release prevents accidental shipping
- Simple boolean flags are easy to toggle and test

### Consequences
- Every system with cost/unlock/time checks must integrate with DebugManager
- Debug UI overlay is a separate scene instanced only in debug builds
