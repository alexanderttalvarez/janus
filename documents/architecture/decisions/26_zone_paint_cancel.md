## Decision 26: Zone Paint Cancel Destination
**Date:** 2026-08-27
**Status:** Accepted

### Decision
Cancel in an active zone paint or removal session:

- discards all pending paint/removal selection and preview state;
- preserves committed zones, parcels, doors, grid state, and counters;
- deactivates ZoneTool; and
- returns to the in-game top-level Build toolbar.

It does not leave the game scene or call `GameManager.end_game()`. The title/main-menu scene remains a separate explicit navigation action.

### Toolbar contract

- Ordinary zone paint: active zone controls, optional Transit toggle, Finish Zone, Cancel.
- Removal mode: Remove, Finish Zone, Cancel; no Transit toggle.
- Cancel remains available for valid, invalid, and empty pending sessions.
