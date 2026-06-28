# Wall System (Draft)

> **Status:** Draft. Content extracted from Zone / Space Design. To be fully designed after Transit & Circulation.

## Overview

Walls define the architectural boundaries between spaces in Janus. They operate at three scales: business, zone, and floor. Walls are primarily aesthetic (Pillar 1: Physical Representation) but have functional implications for visitor flow and zone identity.

---

## Business Walls

| Setting | Effect |
|---------|--------|
| **Walls** (default) | Each business has its own enclosed space with a door to circulation |
| **No Walls** | Businesses are open to each other (open-plan layout), but each still has a door to circulation |

- Setting is chosen per zone during creation and can be changed in Edit Zone mode
- Binary choice: all walls or no walls within a zone (no mixing)
- No wall exists where a business door opens to a Transit tile or building corridor

## Zone Perimeter Walls

- A wall surrounds the entire zone perimeter
- **Exceptions** (no wall):
  - Where an external Transit tile connects directly to an internal Transit tile (open passage)
  - Where the zone borders a building corridor (door opening)

## Floor Perimeter Walls

- A wall surrounds the entire floor perimeter
- **Exceptions** (no wall):
  - Where a terrace is placed (open edge)
  - Where a skybridge or building connection exists

## Placeholder Items

The following need full design after Transit & Circulation is defined:

- [ ] Wall materials and visual variants (glass, concrete, decorative)
- [ ] Door placement rules and visual design
- [ ] Terrace wall interaction (railing vs. solid wall)
- [ ] Skybridge connection wall handling
- [ ] Wall cost and maintenance implications (if any)
- [ ] Wall destruction/modification rules during zone editing
