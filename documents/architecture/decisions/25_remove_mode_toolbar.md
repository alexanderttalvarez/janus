## Decision 25: Remove-Mode Toolbar Clarification
**Date:** 2026-08-27
**Status:** Accepted

### Context
Handoff 06 exposed `None` as an active-paint toggle in addition to `Remove`. During ordinary zone painting, that duplicated the player-visible purpose of Remove and made the toolbar unclear.

### Decision
- The top-level Build toolbar exposes **Remove**, not **None**.
- Selecting Remove enters zone-removal (`None`) paint mode.
- An ordinary zone-type paint toolbar shows the active zone type, **Remove**, and Finish Zone. It shows no None button.
- The removal toolbar shows **Remove** and Finish Zone. It shows no Transit control.
- Selecting Remove again returns to the currently selected ordinary zone type.
- Right-click remains the pending-stroke erase operation; it does not remove committed zone membership.

### Consequences
This decision supersedes Handoff 06's active-toolbar requirement to show a None button and its old pending-paint meaning for the Remove button. All other Handoff 06 zone-mutation rules remain unchanged.
