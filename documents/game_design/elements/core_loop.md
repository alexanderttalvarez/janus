# Core Loop

## Overview

The fundamental cycle of play in Janus. The player designs spaces, watches them come alive, analyzes the results, and iterates. Time flows in real-time with player-controlled speed, creating a rhythm of active building and passive observation.

---

## Time System

### Dual Timer Architecture

Janus uses two independent timers that scale together with speed controls:

| Timer | Purpose | Speed (at 1x) | Drives |
|-------|---------|---------------|--------|
| **Simulation Clock** | Game logic, delays, revenue, tenant timing | 1 hour = 1 second | Tenant applications, construction progress, visitor generation, revenue calculation |
| **Visual Clock** | Day/night cycle, sun position, lighting, seasons | 1 full day = ~10 minutes | Atmosphere, time-of-day visitor patterns, seasonal events, holiday triggers |

**Key principle:** The simulation clock is fast because game logic needs to progress at a satisfying pace. The visual clock is slow because watching the sun crawl across the sky every 24 seconds would be distracting and visually jarring.

**Interaction:**
- Time-of-day visitor patterns are driven by the **visual clock**. When the visual clock says "lunchtime," the simulation generates more food-court visitors.
- Seasonal events are driven by the **visual calendar**. After 10 visual days, a season changes. After a set number of visual days, a holiday arrives.
- Both clocks **pause** when the player pauses the game. No time passes visually or logically during pause.
- Both clocks scale proportionally with speed controls.

### Time Scale

| Speed | Simulation: 1 hour | Simulation: 1 day | Visual: 1 day | Visual: 1 season (10 days) |
|-------|-------------------|-------------------|---------------|---------------------------|
| **Pause** | Frozen | Frozen | Frozen | Frozen |
| **1x** | 1 second | 24 seconds | ~10 minutes | ~1.7 hours |
| **2x** | 0.5 seconds | 12 seconds | ~5 minutes | ~50 minutes |
| **3x** | 0.33 seconds | 8 seconds | ~3.3 minutes | ~33 minutes |

**Design rationale:** A full visual day is long enough to observe lighting changes and feel atmospheric, but short enough that seasons cycle at a meaningful pace (~1.7 hours at 1x). The simulation day is fast enough that delays (1 day = 24s) don't drag. Players will naturally use 2x/3x during construction and waiting periods, and 1x or Pause during active building and observation.

### Time-of-Day Effects (Visual Clock)

The visual clock tracks the current hour and applies modifiers to visitor behavior:
- **Morning (6:00–9:00):** Commuters, coffee seekers, quick errands
- **Midday (9:00–12:00):** Office workers, shoppers, services
- **Lunch (12:00–14:00):** Food court spike, quick retail
- **Afternoon (14:00–18:00):** Leisure shoppers, entertainment, browsing
- **Evening (18:00–21:00):** Dining, entertainment, social visits
- **Night (21:00–6:00):** Minimal visitors, only entertainment/nightlife zones active

These patterns affect visitor volume, spending behavior, and which zones are most active at any given time. The player can observe these patterns directly or rely on aggregated heatmaps.

### Seasonal Cycle (Visual Clock)

Each season lasts **10 visual days** (~1.7 hours at 1x, ~50 min at 2x, ~33 min at 3x). Seasons affect:
- Visitor volume modifiers (e.g., summer = more tourists, winter = fewer but higher indoor spending)
- Seasonal events (holiday sales, back-to-school rushes)
- Visual changes (foliage, decorations, lighting temperature)

---

## The Loop

### Macro Cycle (Session-Level)

```
Design → Populate → Observe → Analyze → Optimize → Expand → (repeat)
```

1. **Design:** Player places zones, builds circulation (stairs, elevators, corridors), adds amenities (gardens, seating, art).
2. **Populate:** Tenants apply for vacant zones (after a 1-day delay). If accepted, construction begins. Visitors arrive based on attraction factors.
3. **Observe:** Real-time simulation runs. Visitors flow through the district, spend money, and leave. Tenants earn revenue or struggle. Prestige shifts.
4. **Analyze:** Player checks heatmaps, flow data, viability indicators, prestige changes, and financial reports.
5. **Optimize:** Player adjusts — widens corridors, adds escalators, swaps zone types, reconfigures layout, adds staff or amenities.
6. **Expand:** Once stable, player builds upward, adds a new building, connects structures, or unlocks new tech via prestige milestones.

### Micro Cycle (Moment-to-Moment)

- **Pause:** Full control over placement and UI. Simulation frozen. Primary building state.
- **Play (1x/2x/3x):** Simulation runs. Player watches, makes minor adjustments, toggles informational panels.
- **Feedback:** Contextual indicators appear (congestion warnings, low viability alerts, prestige changes). Heatmaps update in real-time.

---

## Tenant Timing & Construction

### Application Window

| Phase | Duration (sim clock) | Duration at 1x | Player Action |
|-------|---------------------|----------------|---------------|
| **Vacant → Open** | 1 sim day | 24 seconds | Player can expand, resize, or re-zone before any tenant applies |
| **First application** | Triggered after 1 sim day | After 24s | A tenant applies based on zone conditions |
| **Exclusivity lock** | 1 sim week | ~2.8 minutes | No other tenant can apply. Player sees WHO is coming |
| **Construction** | 0.3 sim weeks × tile count | Variable | Construction phases visible |

### Construction Phases

Construction has 3 visual phases, each representing ~33% of total build time:

| Phase | Visual | Function |
|-------|--------|----------|
| **0–33%** | Foundation/scaffolding | Basic structure, no detail |
| **34–66%** | Walls/interior framing | Shape visible, materials partial |
| **67–100%** | Finishing/signage | Near-complete, branding visible |
| **100%** | Final tenant art | Fully operational business |

**MVP approach:** Simple progress-bar-style visuals (colored overlays or placeholder sprites) that clearly indicate phase. Replaced with proper art/animation later.

### Construction Cancellation

The player can cancel construction at any time using the bulldozer tool or by overwriting the zone with a different zone type or amenity.

**Penalty:** A 1-week exclusivity lock starts over. No tenant can apply to that zone for 1 in-game week (~2.8 minutes at 1x).

**Rationale:** This creates meaningful commitment stakes without being punitive. The player has freedom to change their mind, but the delay discourages frivolous re-zoning.

---

## Session Structure

A typical play session flows as follows:

### 1. Load-In & Check-In (30 seconds – 2 minutes)
- Game loads, time is paused
- Player reviews the current state of the district exactly as they left it
- Informational panels show accumulated data (current tenant status, visitor trends, prestige, finances)
- Contextual indicators highlight areas needing attention (low viability, congestion, empty zones)
- Player toggles informational panels as needed

### 2. Active Management (2 – 10 minutes)
- Player addresses issues: re-zone underperforming areas, add circulation, adjust staff, build amenities
- All building happens on Pause
- Player unpauses briefly to test changes, then pauses again

### 3. Observation & Waiting (variable)
- Player runs simulation at 1x to observe visitor flow and time-of-day patterns
- Switches to 2x/3x during construction or when waiting for tenants to apply
- Heatmaps and indicators update in real-time, providing feedback

### 4. Expansion (5 – 15 minutes)
- When the district is stable, player plans and executes new construction
- New floors, new buildings, new connections
- Unlocks new tech if prestige threshold reached
- Returns to step 2

### Session Length
- **Short session:** 15–30 minutes (quick adjustments and observation)
- **Standard session:** 1–2 hours (meaningful expansion and optimization)
- **Long session:** 2+ hours (major construction, reaching new prestige levels)

---

## Sandbox vs. Challenge Mode

### Sandbox (Default)
- No forced goals or events
- Player-driven motivation
- Optional milestones visible but not required
- Best for creative play and experimentation

### Challenge Mode (Optional Toggle at Game Start)
- Seasonal events activate (holiday sales, tourist seasons, economic shifts)
- Milestones offer bonus prestige or rewards
- Time-limited challenges (e.g., "Reach 500 daily visitors before summer ends")
- Best for players who want direction and structured engagement

**MVP scope:** Sandbox mode only. Challenge mode is post-MVP.

---

## Design Notes

### Feedback Density
The loop only works if the player sees results quickly and clearly:
- Heatmaps update in real-time
- Prestige gains are visible (numerical tick + visual indicator)
- Tenant applications appear within the 1-day window
- Revenue reports are accessible via informational panel
- Congestion and viability warnings appear contextually near affected elements

### Motivation Engine
No hard failure means the game must generate internal motivation:
- **Visual pride:** The district should look good as it grows
- **Data satisfaction:** Numbers going up, heatmaps filling in, synergy bonuses triggering
- **Unlock anticipation:** Tech tree progression, new zone types, new building capabilities
- **Creative expression:** The player's vision materializing in 3D space

### Pacing Guards
- Construction time formula (0.3 weeks × tiles) scales with zone size, preventing the player from placing dozens of large zones simultaneously without waiting
- 1-week exclusivity lock prevents instant tenant-swapping
- 1-day application window gives the player a chance to refine before commitment
