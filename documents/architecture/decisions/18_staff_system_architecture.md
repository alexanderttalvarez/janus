## Decision 18: Staff System Architecture — Centralized Management with Coverage Boundaries
**Date:** 2026-07-28
**Status:** Accepted

### Context
Staff (Cleaners and Security) are hired through Operations Rooms. Cleaners handle garbage and bathroom cleaning via task queues. Security provides passive coverage. Bins reduce garbage spawn rate.

### Decision
- **Dedicated StaffManager** owns all staff logic
- **Centralized task queue** with coverage-filtered assignment (cleaners only work on their coverage floors)
- **Node3D per staff member** (~16 max, negligible overhead)
- **Operations Room is 2×2 tiles** — all 4 must be purchased and empty
- **Bins reduce garbage** — 10% per bin per floor, max 80% reduction
- **Cleanliness and insecurity** calculated periodically from game state

### StaffManager Structure
```
StaffManager (Node, child of main_game.tscn)
├── operations_rooms: Dictionary[String, OperationsRoomData]
├── all_staff: Dictionary[String, StaffData]
├── garbage_queue: Array[GarbageTask]
├── bathroom_queue: Array[BathroomTask]
├── bins_per_floor: Dictionary[String, int]
├── place_operations_room(floor, position) → String
├── place_bin(floor, position)
├── hire_staff(room_id, staff_type) → String
├── fire_staff(staff_id)
├── _on_visitor_tick()  ← Spawns garbage (with bin reduction), assigns tasks
├── _assign_cleaner_tasks()  ← Filters by coverage floors
├── calculate_cleanliness() → int
├── calculate_insecurity() → float
└── get_garbage_reduction(floor) → float
```

### OperationsRoomData Structure
```
class OperationsRoomData:
    id: String
    floor: String
    position: Vector2i  # Top-left corner of 2×2
    size: Vector2i = Vector2i(2, 2)
    cleaners: Array[String]  # max 2
    security: Array[String]  # max 2
    coverage_floors: Array[String]  # floor + 1 above + 1 below
```

### Cleaner Assignment Flow
```
Visitor tick → Garbage spawns (reduced by bins)
    ↓
Garbage added to centralized queue
    ↓
For each FREE cleaner:
    → Filter queue to coverage floors only
    → Find nearest eligible task
    → Assign task → cleaner state = WORKING
    ↓
Cleaner pathfinds → cleans → state = FREE
```

### Bin Mechanics
- 1 tile amenity, placed via build palette
- Each bin = -10% garbage spawn on that floor
- Max 80% reduction (8 bins)
- Formula: `actual_garbage = int(base_garbage * (1.0 - min(0.8, bin_count * 0.1)))`

### Rationale
- Centralized queue enables optimal nearest-cleaner assignment while respecting coverage boundaries
- Node3D per staff is trivial at ~16 max
- Bin reduction creates meaningful player choice (place bins vs hire more cleaners)
- Coverage filtering prevents cross-floor contamination

### Consequences
- Operations Room placement validates 2×2 area (all tiles owned and empty)
- Cleaner task assignment filters by coverage floors before finding nearest
- Bin count tracked per floor for garbage reduction calculation
- Cleanliness and insecurity scores feed into Prestige (Visitor Experience factor)
