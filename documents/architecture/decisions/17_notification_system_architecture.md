## Decision 17: Notification System Architecture — Condition-Based with Toast Queue
**Date:** 2026-07-28
**Status:** Accepted

### Context
The game needs toast notifications (auto-dismiss, max 3 visible, queued), a notification panel (log with filtering), and a red dot indicator for unresolved high-priority items.

### Decision
- **NotificationManager controls toast queue** — max 3 visible, excess queued, auto-dismiss by priority duration
- **Condition-based resolution** — each notification stores a Callable checked once per sim day
- **Red dot owned by NotificationManager** — visible when any high-priority notification is unresolved
- **Toast lifecycle**: create → show → wait (duration) → dismiss → next from queue
- **Panel is a separate scene** — filters by category/status, clear read only

### NotificationManager Structure
```
NotificationManager (Node, child of game_ui.tscn)
├── visible_toasts: Array[Toast]
├── queue: Array[NotificationData]
├── log: Array[NotificationEntry]
├── MAX_VISIBLE = 3
├── DURATIONS = {"high": 10.0, "medium": 7.0, "low": 5.0}
├── notify(text, category, priority, action_target)
├── _show_toast(data)
├── _dismiss_toast(toast)
├── _on_sim_day_passed(day)  ← Checks resolution conditions
├── open_panel()
├── clear_read()
└── Signals:
    └── red_dot_changed(visible: bool)
```

### NotificationEntry Structure
```
class NotificationEntry:
    data: NotificationData
    status: String  # unread, read, resolved
    condition: Callable  # Optional: returns true when issue is fixed
    check_resolution() → bool
```

### Resolution Flow
```
Sim day passes → NotificationManager checks all entries
    → If condition.call() returns true → status = "resolved"
    → If high-priority and unresolved → red dot visible
    → If all high-priority resolved → red dot hidden
```

### Rationale
- Condition-based resolution means notifications auto-dismiss when issues are fixed (no manual resolve calls)
- Toast queue prevents screen clutter during busy simulation periods
- Centralized management enforces max 3 and handles queuing cleanly
- Red dot tied to actual unresolved state, not just unread notifications

### Consequences
- Condition Callables must be side-effect-free
- Each system creating notifications must provide a resolution condition
- Toast scene must support optional action button
- Panel scene must support filtering by category and status
