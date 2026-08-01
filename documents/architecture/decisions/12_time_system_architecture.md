## Decision 12: Time System Architecture — Accumulated Time with EventBus Signals
**Date:** 2026-07-28
**Status:** Accepted

### Context
Janus has three independent timers (simulation clock, visual clock, visitor tick) that scale together with speed controls. We needed to decide on timer implementation, event subscription, and speed change handling.

### Decision
- **Single `_process`** accumulates `sim_time` and `visual_time` as floats
- **Speed is a multiplier** on delta — instant changes, no timer recalculation
- **Events emitted via signals** from TimeManager (not EventBus directly, but TimeManager can emit on EventBus if needed)
- **TimeManager is NOT an autoload** — it's a child of `main_game.tscn`, created/destroyed with the game session
- **GameManager proxies speed control** — `GameManager.set_speed()` forwards to `TimeManager.speed`
- **Time-of-day and seasons are post-MVP** — calculations are left as commented code for future implementation

### TimeManager Structure
```
TimeManager (Node, child of main_game.tscn)
├── sim_time: float           # Accumulated sim seconds
├── visual_time: float        # Accumulated visual seconds
├── speed: int                # 0=pause, 1=1x, 2=2x, 3=3x
├── _process(delta)           # Accumulates time, emits events
└── Signals:
    ├── visitor_tick          # Every 5 sim seconds
    ├── sim_hour_passed(hour)
    ├── sim_day_passed(day)
    ├── sim_month_passed(month)
    └── [POST-MVP] visual_phase_changed(phase), season_changed(season)
```

### Constants
```
SIM_SECONDS_PER_DAY = 86400       # 24 sim hours
VISUAL_SECONDS_PER_DAY = 600      # 10 real minutes at 1x
VISITOR_TICK_INTERVAL = 5         # 5 sim seconds
VISUAL_TO_SIM_RATIO = VISUAL_SECONDS_PER_DAY / SIM_SECONDS_PER_DAY
```

### Event Emission Logic
```
_process(delta):
    if speed == 0: return
    sim_time += delta * speed
    visual_time += delta * speed * VISUAL_TO_SIM_RATIO
    
    if int(sim_time / VISITOR_TICK_INTERVAL) > last_visitor_tick:
        emit visitor tick
    if int(sim_time / SIM_SECONDS_PER_DAY) > last_sim_day:
        emit sim_day_passed
    if int(sim_time / (SIM_SECONDS_PER_DAY * 30)) > last_sim_month:
        emit sim_month_passed
```

### Rationale
- Accumulated time has no drift (unlike multiple Timer nodes)
- Speed multiplier is instant — no state reset needed
- Signals decouple TimeManager from listeners
- Not an autoload because time only matters during gameplay
- GameManager as proxy keeps speed control accessible from menus

### Consequences
- TimeManager must be instantiated when main_game.tscn loads
- GameManager checks `if TimeManager` before forwarding speed (handles menu state)
- Post-MVP time-of-day and season calculations are pure functions of `visual_time`
