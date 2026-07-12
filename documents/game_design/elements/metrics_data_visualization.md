# Metrics & Data Visualization

## Overview

This system ensures the player can always understand why things are happening in their district. Following Pillar 4 (Discoverable Rules, Transparent UI), all game data is visible, readable, and directly tied to in-world conditions. There are no hidden mechanics.

---

## HUD (Always Visible)

A minimal bar at the top or side of the screen provides essential information at a glance.

| Metric | Description |
|--------|-------------|
| **Money** | Current balance in Kreds |
| **Daily Visitors** | Current number of visitors in the district |
| **Prestige** | Total prestige score + current tier name (e.g., "★ 2,850 — Neighborhood Center") |
| **Simulation Speed** | Pause / 1x / 2x / 3x controls |

**Design principle:** The HUD is compact and non-intrusive. It provides the pulse of the district without cluttering the build view.

---

## Heatmaps (Toggleable)

Heatmaps overlay the 3D view to show spatial data. Only one heatmap mode is active at a time. Each mode includes a color legend in the corner of the screen.

### MVP Heatmaps

| Mode | Purpose | Color Scale |
|------|---------|-------------|
| **Visitor Density** | Shows where visitors concentrate | Hot (red/orange) → Medium (yellow) → Cold (blue/dim) |
| **Zone Viability** | Shows which zones are healthy, struggling, or vacant | Healthy (green) → At Risk (yellow) → Vacant (gray) |

### Post-MVP Heatmaps

| Mode | Purpose | Color Scale |
|------|---------|-------------|
| **Congestion** | Identifies bottlenecks and overcrowded corridors | Blocked (red) → Busy (orange) → Free (green) |
| **Synergy** | Shows positive/negative zone adjacencies | Positive (green) → Neutral (gray) → Negative (red) |
| **Prestige Contribution** | Shows which areas contribute most to prestige | High (gold) → Medium (white) → Low (dim) |

**Interaction:**
- Toggle heatmaps via the HUD or keyboard shortcut
- Heatmap updates in real-time as the simulation runs
- Zooming in shows finer detail; zooming out shows broader patterns

---

## Informational Panels (Toggleable On Demand)

Panels open when the player requests detailed information. They can be closed to return to a clean build view.

### Finances Panel

| Section | Data |
|---------|------|
| **Revenue** | Rent income (daily/weekly/monthly breakdown) |
| **Expenses** | Staff wages, maintenance, loan repayments, transportation fees |
| **Net Profit/Loss** | Revenue - Expenses (daily/weekly/monthly) |
| **Loan Status** | Active loans, remaining balance, next payment date, interest rate |

### Prestige Panel

| Section | Data |
|---------|------|
| **Total Prestige** | Current score + tier name + progress to next tier |
| **Scale** | Active tiles / cap, buildings, floors |
| **Quality** | Total score / 100, with breakdown of all 6 factors |
| **History** | Line graph of prestige over time (7/30/90 day toggle) |
| **Loan Default Multiplier** | Current penalty (if any) |

### Tenant Panel

| Section | Data |
|---------|------|
| **Occupancy Rate** | % of zone tiles currently occupied |
| **Tenant List** | All active tenants with name, tier, zone, status (Healthy/Concerned/Critical/Closing) |
| **Revenue by Zone** | Bar chart showing revenue per zone |
| **Tier Distribution** | Pie chart or bar showing tenant tier breakdown |

### Visitor Panel

| Section | Data |
|---------|------|
| **Current Count** | Visitors currently in the district |
| **Daily Average** | Average visitors per day (last 7/30 days) |
| **Satisfaction** | Average visitor satisfaction score (0–100) |
| **Top Thoughts** | Aggregation of the 5 most common visitor thoughts |
| **Purpose Breakdown** | % of visitors by primary goal (Shopping, Dining, etc.) |

### Metrics Dashboard

A combined view of key metrics for quick assessment:
- Prestige trend line
- Revenue vs. Expenses bar chart
- Visitor count trend
- Tenant occupancy rate
- Quick-access buttons to all other panels

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

**Design principle:** Indicators are subtle and contextual. They appear near the affected element, not as global alerts. The player can ignore them if focused on building, or engage with them for troubleshooting.

---

## Graphs & Timelines

All graphs use simple, readable line charts with toggleable time ranges.

| Graph | Data | Time Ranges |
|-------|------|-------------|
| **Prestige History** | Prestige score over time | 7 / 30 / 90 days |
| **Revenue vs Expenses** | Daily income and costs | 7 / 30 / 90 days |
| **Visitor Count** | Daily visitor total | 7 / 30 / 90 days |
| **Tenant Viability** | Revenue vs (Rent + Margin) per tenant | Last 3 check periods |

**Design principle:** Graphs are clean and functional. No unnecessary decoration. Axis labels, data points on hover, and clear legends.

---

## Integration with Other Systems

| System | Connection |
|--------|------------|
| **UI / HUD System** | Defines layout, visibility rules, and interaction patterns |
| **Prestige System** | Displays Scale, Quality, factor breakdowns, tier progress |
| **Economy** | Displays revenue, expenses, profit/loss, loan status |
| **Visitor Simulation** | Displays visitor count, satisfaction, top thoughts, purpose breakdown |
| **Tenant System** | Displays occupancy, tenant status, viability, revenue by zone |
| **Transit & Circulation** | Displays congestion heatmaps, path efficiency (post-MVP) |

---

## Design Notes

### Player Mental Model

The player should never wonder "why is this happening?" Every metric is traceable to a cause. If a zone is struggling, the viability heatmap shows it. If prestige is dropping, the prestige panel shows which factor declined. If revenue is low, the finances panel shows whether it's rent, expenses, or tenant occupancy.

### MVP Scope

MVP focuses on the essentials: HUD summary, two heatmap modes, five informational panels, contextual indicators, and simple line charts. Post-MVP adds additional heatmap modes, advanced graphs, and comparative analytics.

### Tuning Targets

- Heatmap color scales should be intuitive (green = good, red = bad)
- Contextual indicators should be noticeable but not distracting
- Graphs should render smoothly at all zoom levels
- Panel load times should be instant (cached data)
