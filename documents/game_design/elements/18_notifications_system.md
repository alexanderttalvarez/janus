# Notifications System

## Overview

The Notifications System delivers timely, relevant information to the player without interrupting their workflow. All notifications auto-dismiss from the screen, but important unresolved issues persist in the notification log. A red dot indicator on the notification panel icon signals unresolved high-priority items.

**Design principle:** Inform, don't interrupt. The player stays in control of when to engage with notifications.

---

## Notification Types

| Category | Priority | Examples |
|----------|----------|----------|
| **Zone** | Medium | "No tenant interest for 2 weeks", "Zone X viability low" |
| **Tenant** | High / Medium | "New tenant moving in!", "Tenant Y at risk of closure" |
| **Financial** | High | "Low balance warning", "Loan payment due tomorrow" |
| **Milestone** | High | "Prestige tier reached: Regional Mall!", "New tech unlocked" |
| **Seasonal** | Low | "Summer season starting", "Holiday event approaching" |
| **Visitor Sentiment** | Medium | "Many visitors find Floor 2 too dirty", "Long queues reported at Zone A" |
| **Staff** | Medium | "Operations Room at capacity", "Cleaner queue growing on Floor 3" |

---

## Toast Notifications

### Behavior

- All toasts **auto-dismiss** after a set duration.
- Maximum 3 toasts visible simultaneously. Excess notifications queue and appear as previous ones dismiss.
- Toasts slide in from the bottom-right corner with smooth animation.

### Duration by Priority

| Priority | Duration | Examples |
|----------|----------|----------|
| **High** | 10 seconds | Tenant events, financial warnings, milestones |
| **Medium** | 7 seconds | Zone viability, visitor sentiment, staff alerts |
| **Low** | 5 seconds | Seasonal reminders, minor updates |

### Toast Design

```
┌─────────────────────────────────────────────┐
│ [Icon] [Category]                           │
│ Message text here...                        │
│ [Optional Action Button]                    │
└─────────────────────────────────────────────┘
```

- **Icon:** Category-specific (e.g., 🏢 for Zone, 💰 for Financial, 👤 for Visitor)
- **Category:** Short label (Zone, Tenant, Financial, etc.)
- **Message:** Clear, concise description of the event
- **Action Button:** Optional (e.g., "View Zone", "Open Finances", "Focus Camera")

---

## Notification Panel

### Access

- Toolbar button in the bottom toolbar
- Keyboard shortcut: `N`
- Icon displays a **red dot** when there are unresolved high-priority notifications

### Panel Content

| Column | Description |
|--------|-------------|
| **Status** | Unread (bold) / Read (normal) / Resolved (dimmed) |
| **Category** | Zone, Tenant, Financial, Milestone, Seasonal, Visitor Sentiment, Staff |
| **Message** | Notification text |
| **Timestamp** | When the notification was generated |
| **Action** | Link to relevant location or panel |

### Filtering

- Filter by category: All, Zone, Tenant, Financial, Milestone, Seasonal, Visitor Sentiment, Staff
- Filter by status: Unread, Read, Resolved

### Clear Behavior

- **"Clear All" button** removes only acknowledged (read) notifications.
- **Unresolved notifications** (e.g., zone still vacant, tenant still at risk) remain in the log until the underlying condition is resolved.
- **Resolved notifications** are automatically marked and dimmed when the condition is fixed.

---

## Red Dot Indicator

A small red dot appears on the notification panel icon when:
- There is at least one **unresolved high-priority** notification in the log.
- The dot persists until all high-priority issues are resolved.
- Medium and low priority notifications do **not** trigger the red dot.

---

## Integration with Other Systems

| System | Connection |
|--------|------------|
| **Tenant System** | New tenant arrivals, viability warnings, closure alerts |
| **Visitor Simulation** | Sentiment aggregation ("Many visitors find Floor X dirty"), queue alerts |
| **Staff System** | Operations Room capacity, cleaner queue growth, maintenance alerts (post-MVP) |
| **Economy** | Low balance warnings, loan payment reminders |
| **Prestige** | Tier advancement notifications, prestige milestone alerts |
| **UI / HUD System** | Toast rendering, notification panel UI, red dot indicator |

---

## Design Notes

### Player Mental Model

The player should understand: "Notifications tell me what's happening. I can check them when I'm ready. If something is seriously wrong, I'll see a red dot."

### MVP Scope

MVP includes toast notifications, notification panel with filtering, red dot indicator, and auto-dismiss behavior. Post-MVP adds notification sound effects, customizable alert preferences, and advanced sentiment aggregation.

### Tuning Targets

- Toast duration should be long enough to read but short enough to not clutter
- Red dot should only appear for genuinely urgent issues to avoid alert fatigue
- Notification panel should load instantly and support quick filtering
- Action buttons should focus the camera or open the relevant panel in one click
