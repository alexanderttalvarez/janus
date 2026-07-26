# UI / HUD System

## Overview

The UI serves the creative fantasy. It provides information without cluttering the view. The build view should feel clean. The world is the focus, not panels and numbers. Informational windows are toggled on demand. Contextual feedback appears near relevant elements.

**Design principle:** The UI is invisible until needed. The 3D game view is always the primary focus.

---

## Screen Layout

```
┌─────────────────────────────────────────────────────────┐
│  [HUD Bar]  Money | Visitors | Prestige | Speed | Clock │
├─────────────────────────────────────────────────────────┤
│                                                         │
│                                                         │
│                    [3D Game View]                       │
│                                                         │
│                                                         │
│                                                         │
├─────────────────────────────────────────────────────────┤
│ [Build Palette]  [Heatmaps]  [Panels]  [Wall Mode]      │
└─────────────────────────────────────────────────────────┘
```

---

## HUD Bar (Always Visible)

Located at the top of the screen. Compact, minimal, always readable.

| Section | Content | Description |
|---------|---------|-------------|
| **Left** | Money, Visitors, Prestige | Current Kreds balance, daily visitor count, prestige score + tier name |
| **Center** | (empty) | Kept empty to maintain focus on the 3D game view |
| **Right** | Speed, Clock, Wall Mode | Pause/1x/2x/3x controls, visual clock (time + season), wall visualization toggle |

### HUD Elements

| Element | Display | Format |
|---------|---------|--------|
| **Money** | Current balance | `125,000 K` |
| **Visitors** | Current in-district count | `👤 147` |
| **Prestige** | Score + tier | `★ 2,850 — Neighborhood Center` |
| **Speed** | Current speed | `⏸`, `▶ 1x`, `▶▶ 2x`, `▶▶▶ 3x` |
| **Clock** | Visual time + season | `14:30 — Summer` |
| **Wall Mode** | Current mode | `🏗 Cutaway` / `🏗 Partial` / `🏗 Full` |

---

## Bottom Toolbar

Contextual toolbar at the bottom of the screen. Changes based on current mode.

### Build Mode

| Tool | Description |
|------|-------------|
| **Zone Types** | Retail, Food & Beverage, Entertainment, Services, Anchor |
| **Corridor Tool** | Paint corridor tiles |
| **Amenities** | Gardens, seating, art (unlocked via tech tree) |
| **Circulation** | Stairs, elevators, escalators (unlocked via tech tree) |
| **Staff Rooms** | Operations Room placement |
| **Bulldozer** | Delete zones, tiles, or structures |

### Observe Mode

| Tool | Description |
|------|-------------|
| **Heatmaps** | Toggle heatmap modes (Visitor Density, Zone Viability) |
| **Panels** | Quick access to Finances, Prestige, Tenants, Visitors, Metrics |
| **Metrics Dashboard** | Combined overview |
| **Thought Bubbles** | Toggle aggregation panel |

### Edit Zone Mode

| Tool | Description |
|------|-------------|
| **Tile Typology** | Tenant, Decoration, Transit paint tools |
| **Zone Name** | Edit zone name field |
| **Walls Toggle** | Walls / No Walls |
| **Finish Zone** | Confirm and exit Edit Zone mode |

---

## Informational Panels

Panels open on demand and close when the player clicks outside or clicks the **X** button in the top-right corner.

### Panel Behavior

| Behavior | Description |
|----------|-------------|
| **Open** | Click toolbar button or use keyboard shortcut |
| **Close** | Click outside panel, press Escape, or click **X** |
| **Stacking** | Panels stack horizontally from the right edge. Maximum 3 panels open simultaneously. |
| **Sizing** | Fixed width, variable height based on content. Scrollable if content overflows. |
| **Transparency** | Semi-transparent background (80% opacity) to keep game view partially visible |

### Available Panels

| Panel | Content |
|-------|---------|
| **Finances** | Revenue, expenses, net profit/loss, loan status |
| **Prestige** | Scale, Quality, factor breakdowns, tier progress, history graph |
| **Tenants** | Occupancy rate, tenant list, revenue by zone, tier distribution |
| **Visitors** | Current count, daily average, satisfaction, top thoughts, purpose breakdown |
| **Metrics Dashboard** | Combined view with trend lines and quick-access buttons |
| **Tech Tree** | Available nodes, tech points, dependency map, unlock buttons |
| **Staff** | Global list of Operations Rooms, hire/fire controls |

---

## Contextual Indicators

Warnings and information appear directly on the 3D view near the relevant element.

| Indicator | Trigger | Visual |
|-----------|---------|--------|
| **Low Viability** | Zone application score below threshold | Subtle yellow/orange glow around zone |
| **Congestion** | Corridor/entrance exceeds capacity | Red pulsing indicator |
| **Tenant Warning** | Tenant enters Concerned/Critical/Closing stage | Icon above zone, tooltip on hover |
| **Vacant Zone** | Zone has been empty for >1 week | "Next evaluation: X days" tooltip |
| **Prestige Feature** | Player hovers over garden, fountain, etc. | "+X Quality" preview |
| **Under Repair** | Tile currently being repaired | Orange overlay, blocked from pathfinder |

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **Space** | Toggle Pause/Play |
| **1** | Speed 1x |
| **2** | Speed 2x |
| **3** | Speed 3x |
| **H** | Toggle heatmap mode (cycle through available modes) |
| **P** | Toggle Prestige panel |
| **F** | Toggle Finances panel |
| **T** | Toggle Tenants panel |
| **V** | Toggle Visitors panel |
| **M** | Toggle Metrics Dashboard |
| **K** | Toggle Tech Tree |
| **S** | Toggle Staff panel |
| **W** | Cycle wall visualization mode (Cutaway → Partial → Full) |
| **Escape** | Close open panel / Exit Edit Zone mode / Cancel current action |
| **B** | Toggle Build Mode |
| **O** | Toggle Observe Mode |
| **E** | Enter Edit Zone mode (when zone is selected) |
| **Delete** | Activate Bulldozer tool |

---

## Camera Controls

| Action | Input |
|--------|-------|
| **Rotate** | Q (90° left), E (90° right) |
| **Zoom** | Mouse scroll wheel |
| **Pan** | Middle mouse button drag / Arrow keys |
| **Focus** | Double-click on zone or building |

---

## Integration with Other Systems

| System | Connection |
|--------|------------|
| **All Systems** | UI displays data from every system. HUD, panels, and indicators are the player's window into the simulation. |
| **Notifications System** | Notification panel integrates with the UI shell (defined in Element 18) |
| **Wall System** | Wall mode toggle in HUD |
| **Metrics** | Heatmap toggles, panel content, graph rendering |

---

## Design Notes

### Player Mental Model

The player should understand: "I build in a clean view. I open panels when I need data. I close them when I'm done. The world is always the focus."

### MVP Scope

MVP includes HUD bar, bottom toolbar, 5 informational panels, contextual indicators, keyboard shortcuts, and camera controls. Post-MVP adds customizable layouts, advanced graph types, and additional heatmap modes.

### Tuning Targets

- Panel opening/closing should feel instant
- Keyboard shortcuts should not conflict with text input (e.g., zone naming)
- Contextual indicators should be noticeable but not distracting
- HUD should remain readable at all zoom levels
