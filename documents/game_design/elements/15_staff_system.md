# Staff System

## Overview

Staff are the employees who maintain and secure the district. They are a recurring expense but directly impact visitor satisfaction, tenant viability, and prestige. Staff are managed through **Operations Rooms** — physical facilities placed on floors that serve as their base of operations.

**Design principle:** Physical representation (Pillar 1). Staff spawn from visible rooms, walk the corridors, clean garbage, and patrol for security. They are generic entities with uniform performance and wages.

---

## Operations Room

### Definition

| Property | Value |
|----------|-------|
| **Purpose** | Base of operations for staff. Where they spawn, store equipment, and receive assignments. |
| **Placement Cost** | 2,000 Kreds (one-time) |
| **Capacity** | Max 2 Cleaners + Max 2 Security staff per room |
| **Coverage** | Floor where placed + 1 floor above + 1 floor below (same building only) |
| **Skybridge/Passage Coverage** | Staff cover connected skybridges/underground passages but do NOT enter the other building. |

### Management Interface

| Method | Description |
|--------|-------------|
| **Global Staff Panel** | Lists all Operations Rooms in the district. Click to open room details. |
| **Direct Click** | Click an Operations Room in the 3D view → opens room details inline. |

### Room Details Panel

| Information | Description |
|-------------|-------------|
| **Location** | Building name + floor level |
| **Capacity** | Cleaners: X/2, Security: Y/2 |
| **Coverage Floors** | Lists covered floors |
| **Actions** | Hire Cleaner, Hire Security, Fire Cleaner, Fire Security |

**Note:** Staff have no names, no individual attributes, and no unique salaries. They are generic entities ("Cleaner #1", "Security #2").

---

## Staff Types (MVP)

### Cleaner

| Property | Value |
|----------|-------|
| **Role** | Maintains cleanliness by removing garbage and cleaning bathrooms. |
| **Wage** | 500 Kreds/week |
| **Behavior** | Active task queue system. Dispatched to nearest garbage or dirty bathroom on coverage floors. One task at a time. |
| **Visual** | Spawns from Operations Room, pathfinds to task location, performs cleaning animation, returns to patrol or next task. |

### Security

| Property | Value |
|----------|-------|
| **Role** | Provides passive security coverage to reduce insecurity. |
| **Wage** | 500 Kreds/week |
| **Behavior** | Patrols coverage floors. No active task queue. Contributes to insecurity formula. |
| **Visual** | Spawns from Operations Room, walks patrol routes on coverage floors. |

---

## Cleanliness System

### Garbage Spawning

```
Garbage Spawn Rate = floor(floor_visitor_count / 50) per visitor tick
```

- Garbage spawns only on **corridor tiles** (not inside zones).
- Each garbage item is a visible sprite on the tile.
- `floor_visitor_count` is a running counter (O(1) per visitor movement).

### Cleaner Task Queue

```
1. Garbage spawns on corridor tile T
2. System finds closest FREE cleaner assigned to the floor
3. If found: assign task → cleaner pathfinds to T → cleans → becomes FREE
4. If no free cleaner: garbage waits in queue
5. If queue grows: cleanliness drops visibly
```

### Bathroom Cleaning

- Bathrooms are separate facilities placed by the player.
- **Dirtiness Formula:** `Dirtiness = (Visitor Uses × 2) - (Cleaner Visits × 50)`
- Capped at 0–100.
- At 50+: visible grime appears. At 80+: visitors actively avoid the area.
- Cleaners are dispatched to clean bathrooms when dirtiness exceeds threshold.

### Cleanliness Score

```
Cleanliness = max(0, 100 - (Uncollected Garbage Items × 3) - (Dirty Bathrooms × Penalty))
```

| Cleanliness Range | Effect on Visitor Experience |
|-------------------|------------------------------|
| **80–100** | No penalty |
| **50–79** | -2 Cleanliness |
| **20–49** | -5 Cleanliness, -3 Tenant Satisfaction |
| **0–19** | -10 Cleanliness, -8 Tenant Satisfaction, -5 Prestige |

---

## Security / Insecurity System

### Insecurity Formula

```
Insecurity Score = max(0, (Corridor Tiles × 1 + Zone Tiles × 3) / (Security Staff × 4) - Decorative Tiles × 0.5)
```

**Logic:**
- **Corridor tiles (×1):** Movement areas need monitoring but are low-risk.
- **Zone tiles (×3):** High-activity areas need more security coverage.
- **Security staff (÷4):** Each guard effectively covers 4× the area weight.
- **Decorative tiles (×0.5):** Natural surveillance — gardens, seating, and art passively deter issues.
- **Capped at 0:** Insecurity can't go negative.

### Insecurity Impact

| Insecurity Range | Effect on Visitor Experience |
|------------------|------------------------------|
| **0–10** | No penalty |
| **11–20** | -2 Comfort |
| **21–35** | -5 Comfort, -3 Tenant Satisfaction |
| **36+** | -10 Comfort, -8 Tenant Satisfaction, -5 Prestige |

---

## Hiring & Firing

### Hiring

- Click "Hire Cleaner" or "Hire Security" in an Operations Room panel.
- If room is at capacity for that type, hire button is disabled.
- Staff spawns visually from the Operations Room.
- Wage begins accruing immediately (500 Kreds/week).

### Firing

- Click "Fire" next to a staff member in the Operations Room panel.
- Staff disappears immediately.
- Wage stops accruing.
- Capacity slot opens for new hire.

---

## Integration with Other Systems

| System | Connection |
|--------|------------|
| **Economy** | Staff wages (500 Kreds/week), Operations Room placement cost (2,000 Kreds) |
| **Prestige** | Cleanliness and Comfort factors in Visitor Experience. Insecurity affects Tenant Satisfaction. |
| **Visitor Simulation** | Cleanliness and Comfort directly impact visitor satisfaction and dwell time. |
| **Building & Structure** | Operations Rooms are facilities placed on floors. Coverage spans 3 floors per building. |
| **Metrics & Visualization** | Cleanliness and Insecurity scores visible in Prestige panel. Garbage and grime visible in world. |

---

## Design Notes

### Player Mental Model

The player should understand: "I build Operations Rooms. I hire staff. They keep the district clean and safe. More visitors = more mess = more staff needed."

### MVP Scope

MVP includes Cleaners and Security. Customer Service and Maintenance are post-MVP. No individual staff attributes, names, or salaries. Uniform performance and cost.

### Tuning Targets

- Operations Room cost (2,000 Kreds) should encourage strategic placement, not spam
- Cleaner task queue should feel responsive without overwhelming CPU
- Security formula should create meaningful staffing decisions for large vs. small floors
- Garbage spawn rate should create visible but manageable mess at typical visitor counts
