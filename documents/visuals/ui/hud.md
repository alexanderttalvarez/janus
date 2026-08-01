# HUD Assets

## HUD Bar Background

| Property | Value |
|----------|-------|
| **Position** | Top of screen, full width |
| **Height** | ~48px |
| **Style** | Semi-transparent dark background (80% opacity) |
| **MVP** | Simple dark rectangle with slight transparency. |
| **Post-MVP** | Styled bar with subtle gradient or texture. |

## HUD Icons

| Icon | Purpose | Size | Style |
|------|---------|------|-------|
| **Money/Kred** | Currency display | 24×24px | Coin or credit symbol |
| **Visitors** | Visitor count | 24×24px | Person silhouette (👤) |
| **Prestige** | Prestige score | 24×24px | Star (★) |
| **Pause** | Simulation paused | 24×24px | Pause symbol (⏸) |
| **Play 1x** | Normal speed | 24×24px | Play symbol (▶) |
| **Play 2x** | Double speed | 24×24px | Double play (▶▶) |
| **Play 3x** | Triple speed | 24×24px | Triple play (▶▶▶) |
| **Clock** | Time display | 24×24px | Clock face |
| **Wall mode** | Wall visualization toggle | 24×24px | Building/wall icon |

## Bottom Toolbar Background

| Property | Value |
|----------|-------|
| **Position** | Bottom of screen, full width |
| **Height** | ~56px |
| **Style** | Semi-transparent dark background (80% opacity) |
| **MVP** | Simple dark rectangle with slight transparency. |
| **Post-MVP** | Styled bar with subtle gradient or texture. |

## Toolbar Button Icons

See [build_palette.md](build_palette.md) for tool-specific icons.

## Toast Notification Background

| Property | Value |
|----------|-------|
| **Position** | Bottom-right corner |
| **Size** | ~320px wide, variable height |
| **Style** | Semi-transparent dark background with colored left border by priority |
| **Border colors** | High=red, Medium=yellow, Low=blue |
| **Animation** | Slide in from right, fade out after duration |
| **MVP** | Simple rectangle with colored border. |
| **Post-MVP** | Rounded corners, subtle shadow, smooth animation. |

## Reuse Opportunities

- HUD bar and toolbar backgrounds share the same style (dark semi-transparent)
- All HUD icons share the same size grid (24×24px) and style
- Toast notifications reuse the same frame with different border colors
