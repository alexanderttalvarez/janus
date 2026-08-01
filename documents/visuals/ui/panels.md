# Panel Assets

## Panel Frame / Background

| Property | Value |
|----------|-------|
| **Position** | Stacks from right edge of screen |
| **Width** | Fixed ~320px |
| **Height** | Variable, scrollable if content overflows |
| **Background** | Semi-transparent dark (80% opacity) |
| **Max open** | 3 panels simultaneously |
| **MVP** | Simple dark rectangle with slight transparency. |
| **Post-MVP** | Rounded corners, subtle shadow, header bar with panel title. |

## Panel Close Button

| Property | Value |
|----------|-------|
| **Position** | Top-right corner of panel |
| **Size** | 24×24px |
| **Icon** | X symbol |
| **Style** | Consistent with icon set |

## Panel Header

| Property | Value |
|----------|-------|
| **Content** | Panel title (e.g., "Finances", "Prestige", "Tenants") |
| **Height** | ~32px |
| **Style** | Slightly darker than panel body, with title text |

## Graph / Chart Rendering

| Property | Value |
|----------|-------|
| **Type** | Simple line charts |
| **Style** | Clean, functional. No unnecessary decoration. |
| **Elements** | Axis labels, data points on hover, clear legends |
| **Time ranges** | 7 / 30 / 90 day toggles |
| **MVP** | Simple line drawing with axis labels. Godot Line2D or custom drawing. |
| **Post-MVP** | Styled charts with grid lines, tooltips, animated transitions. |

### Graph Types Needed

| Graph | Data | Visual |
|-------|------|--------|
| **Prestige History** | Prestige score over time | Line chart |
| **Revenue vs Expenses** | Daily income and costs | Dual line or bar chart |
| **Visitor Count** | Daily visitor total | Line chart |
| **Tenant Viability** | Revenue vs (Rent + Margin) | Bar or line chart |
| **Tier Distribution** | Tenant tier breakdown | Pie or bar chart |
| **Revenue by Zone** | Revenue per zone | Bar chart |

## Notification Panel

| Property | Value |
|----------|-------|
| **Type** | Informational panel (same frame as other panels) |
| **Content** | Table with columns: Status, Category, Message, Timestamp, Action |
| **Filtering** | Filter by category and status buttons |
| **Clear All button** | Removes read notifications |
| **Red dot indicator** | On toolbar icon when unresolved high-priority items exist |

## Reuse Opportunities

- All panels share the same frame/background style
- Close button is reused across all panels
- Graph rendering uses a shared chart component
- Filter buttons share the same button style
