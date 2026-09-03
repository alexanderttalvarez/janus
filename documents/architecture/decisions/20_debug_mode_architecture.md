## Decision 20: Debug Mode Architecture — DebugManager Autoload
**Date:** 2026-07-28
**Status:** Accepted; amended 2026-09-03

### Context
Development requires a debug mode to bypass unlocks, costs, and time constraints for testing.

### Decision
- **DebugManager is an autoload** — available globally during development.
- **Auto-disabled in release builds** — it must not permit debug bypasses in a release build.
- **Toggle flags:** `god_mode` (unlocks everything and activates free-cost play), `infinite_money` (activates free-cost play only), `instant_construction`, and `time_warp`.
- **Debug UI overlay** — toggle with F12; it exposes flags and quick actions only in debug builds.
- **Active debug cost bypass makes every player-paid action free.** The Economy transaction boundary returns a zero-cost quote and captures no debit. Cost bypass applies consistently to direct spending, construction, and coordinated District transactions; callers must not implement ad-hoc free-cost exceptions.
- Debug bypasses do not change authoritative eligibility, geometry, validity, atomicity, or persistence contracts. They only override the cost/unlock/time checks explicitly listed here.

### Integration Points
- `TechTreeManager.can_unlock()` returns `true` if `DebugManager.god_mode`.
- Economy's quote/reserve/capture port treats a charge as free if `DebugManager.god_mode` or `DebugManager.infinite_money`.
- `TenantManager.start_construction()` sets duration to `0` if `DebugManager.instant_construction`.
- `TimeManager` sets speed to `100` if `DebugManager.time_warp`.

### Rationale
- Autoload scope makes debug flags available to every development system.
- A centralized cost-bypass decision prevents a debug build from accidentally charging one consumer but not another.
- Release exclusion prevents debug affordances from shipping.

### Consequences
- Every system with cost, unlock, or time checks integrates through DebugManager or the relevant owning authority.
- A free-cost transaction still executes normal validation and emits its normal successful committed result; it simply has a zero economic delta.
- The debug UI overlay is a separate scene instanced only in debug builds.
