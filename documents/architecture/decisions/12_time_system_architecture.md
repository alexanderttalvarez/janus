## Decision 12: Time System Architecture — Accumulated Time with Calendar Signals
**Date:** 2026-07-28
**Status:** Accepted; amended 2026-09-03

**Current applicability:** [ADR 33](33_documentation_consistency_and_minimum_contracts.md), 2026-09-08, replaces the inconsistent visitor-time conversion in the original body. Element 01 owns scaled elapsed seconds/calendar labels; `session/H1` owns chronological and coincident boundary delivery.

### Context
Janus has independent simulation and visual clocks that scale together with speed controls. The simulation calendar drives gameplay periods; the visual clock drives atmosphere. We needed to decide on timer implementation, speed changes, and authoritative calendar boundaries.

### Decision
- **Single `_process`** accumulates simulation and visual elapsed time as independent floats.
- **Speed is a multiplier** on delta — changes are immediate and require no timer recalculation.
- **TimeManager signals are the sole authoritative calendar boundary** for gameplay systems. Consumers must not reproduce day/week/month constants.
- **Simulation clock:** one simulation hour equals one real second at 1×; one simulation day is therefore 24 real seconds at 1×.
- **Visual clock:** one visual day is 600 real seconds at 1×. It advances independently of the simulation calendar, while sharing pause and speed controls.
- **Events are emitted as TimeManager signals**; EventBus forwarding is optional and does not replace the local signal authority.
- **TimeManager is not an autoload** — it is a child of `main_game.tscn`, created and destroyed with the gameplay session.
- **GameManager proxies speed control** — `GameManager.set_speed()` forwards to `TimeManager.speed`.
- Time of day and seasons are post-MVP.

### TimeManager Structure
```text
TimeManager (Node, child of main_game.tscn)
├── sim_time: float
├── visual_time: float
├── speed: int                # 0=pause, 1=1×, 2=2×, 3=3×
├── _process(delta)
└── Signals:
    ├── visitor_tick          # Every 5 simulation minutes / 5 real seconds at 1×
    ├── sim_hour_passed(hour)
    ├── sim_day_passed(day)
    ├── sim_week_passed(week)
    ├── sim_month_passed(month)
    └── [POST-MVP] visual_phase_changed(phase), season_changed(season)
```

### Constants
```text
SIM_SECONDS_PER_HOUR = 1
SIM_SECONDS_PER_DAY = 24
SIM_DAYS_PER_WEEK = 7
SIM_DAYS_PER_MONTH = 30
VISUAL_SECONDS_PER_DAY = 600
VISITOR_TICK_INTERVAL = 5
```

### Event Emission Logic
```text
_process(delta):
    if speed == 0: return
    sim_time += delta * speed
    visual_time += delta * speed

    emit visitor_tick for each crossed VISITOR_TICK_INTERVAL
    emit sim_hour_passed for each crossed simulation hour
    emit sim_day_passed for each crossed simulation day
    emit sim_week_passed for each crossed 7-day boundary
    emit sim_month_passed for each crossed 30-day boundary
```

Signals must be emitted for every elapsed boundary when a frame crosses more than one period, in chronological period order. Economy credits daily rent on `sim_day_passed`, charges staff wages on `sim_week_passed`, and processes loan payments on `sim_month_passed`.

### Rationale
- Accumulated clocks avoid drift from multiple Timer nodes.
- The 24-second simulation day matches the approved core-loop pacing and makes daily rent feedback timely.
- Independent clocks preserve a fast gameplay calendar and a slow visual day/night cycle.
- Explicit week signals support weekly wages without individual systems reconstructing calendar arithmetic.

### Consequences
- TimeManager must be instantiated when `main_game.tscn` loads.
- GameManager checks whether TimeManager exists before forwarding speed, which handles menu state.
- Post-MVP visual phase and season calculations are pure functions of `visual_time`.
- All recurring systems must subscribe to TimeManager calendar signals rather than accumulating their own intervals.
