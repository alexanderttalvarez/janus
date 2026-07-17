# Structural System: Columns (Draft)

> **Status:** Draft. Requires significant design iteration before implementation.

## Overview

Columns are structural elements that provide visual and logical support for the building. They must feel organic, adapt to player edits, and not interfere with zone placement or gameplay flow.

**Design challenge:** This is a video game, not real architecture. The player will constantly edit floors, buy/sell tiles, and reconfigure zones. A rigid or overly realistic column system will create frustration. The goal is to make columns feel present and structural without becoming a management burden.

---

## Core Constraints

| Constraint | Description |
|------------|-------------|
| **1 element per tile** | A tile cannot have both a column and another element (decoration, shop, amenity) |
| **Zones can include columns** | Columns become part of the interior space, not blockers |
| **Auto-placement** | Player does not manually place columns |
| **Dynamic adaptation** | Columns must respond to floor changes, but not chaotically |

---

## Open Questions

### 1. Placement Logic
How should columns be positioned? Options under consideration:

| Approach | Pros | Cons |
|----------|------|------|
| **Fixed grid** (every N tiles) | Predictable, simple | Mechanical, ignores player design |
| **Load-based** | Realistic, responds to zone size | Complex, unpredictable changes |
| **Edge-driven** | Follows zone boundaries, organic rhythm | May create irregular patterns |
| **Hybrid** | Grid base + suppression where zones exist + addition for long spans | More complex to implement |

### 2. Dynamic Updates
When the player buys/sells tiles or changes zone layout, should columns:
- **Reposition immediately?** (Feels responsive but potentially jarring)
- **Reposition on floor rebuild?** (Stable but may feel outdated)
- **Never move once placed?** (Predictable but may become structurally nonsensical)

### 3. Visual Integration
- How should columns look inside different zone types?
- Should columns be visible through walls, or only in open areas?
- Should column style match the building's exterior theme?

### 4. Performance
- How many columns per floor at maximum plot size (25×25 = 625 tiles)?
- Should columns be rendered as 3D objects or baked into the floor texture?

---

## Next Steps

1. Prototype fixed-grid placement (every 5 tiles) as a baseline
2. Test player editing scenarios: buying/selling tiles, resizing zones, adding floors
3. Evaluate jankiness vs. realism trade-off
4. Iterate toward a hybrid approach that feels organic but stable

---

## Integration with Other Systems

| System | Connection |
|--------|------------|
| **Building & Structure** | Columns are structural elements on floors |
| **Zone Design** | Zones can include columns; columns affect visual layout |
| **Wall System** | Columns may intersect with wall placement rules |
| **UI / Visualization** | Columns should be visible but not distracting |
