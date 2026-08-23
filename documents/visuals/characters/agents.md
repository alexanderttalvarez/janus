# Visitor & Staff Agents

## Identity

**Asset IDs:** `3d_character_visitor_base`, `3d_character_cleaner`, `3d_character_security`, `3d_character_maintenance`, `anim_visitor_state_set`, `anim_staff_state_set`  
**Category:** 3D characters and animation  
**Family:** Small-scale simulation agents

## Purpose

Visitors prove that the district is alive and make flow data tangible. Cleaners and security staff give cleanliness and security systems a physical presence rather than hiding them in menus.

## Source

- `05_visitor_simulation.md`, `15_staff_system.md`, `16_maintenance_system.md`.
- `03_visitor_agents.md`, `18_staff_system_architecture.md`, `23_state_machine_architecture.md`.

## Gameplay Context

- Visible visitors are actual individual agents; current spawning targets a population cap of 20, with camera/floor culling.
- Visitors enter and leave through plot-corner spawn points, walk routes, queue, explore, and display rotating thought bubbles.
- Cleaners travel from Operations Rooms to garbage/bathroom tasks; security patrols covered floors. Maintenance is post-MVP.

## Required Assets & Variants

| Asset | MVP representation | Production representation | Required variants |
|---|---|---|---|
| Visitor base | One shared, highly readable low-poly civilian silhouette | Shared compatible body family with visual variety | Palette/clothing blocking; optional body/accessory variation |
| Cleaner | Visitor-derived silhouette with unmistakable cleaner role cue | Cleaner with equipment-aware task readability | Idle/travel/working states |
| Security | Visitor-derived silhouette with unmistakable security role cue | Security with patrol identity | Idle/travel/patrol states |
| Maintenance | N/A | Maintenance role with repair identity | Idle/travel/repair states |
| Visitor motion | Legible stationary and travel states | Full state-aware movement for entering, moving, exploring, queueing, satisfying, leaving | State-based timing only |
| Staff motion | Legible travel and task state | Role-specific cleaning/patrol/repair gestures | Cleaner, security, maintenance |

## Dependencies & Reuse

- Visitors require a shared material strategy; the architecture calls for batching and per-instance spawn transparency, not shared-material mutation.
- All agent types may share proportions and non-role-specific motion where it preserves clarity. Role distinction must not depend only on a tiny icon.
- Thought bubbles, zone labels, and status symbols are documented in [game_ui.md](../ui/game_ui.md), not baked into character meshes.

## Visual Requirements

- Small-screen readability outranks facial detail and individual realism.
- Use simplified proportions, strong silhouettes, restrained facial detail, and clothing color blocking.
- Cleaner and security roles need non-ambiguous primary color/silhouette differentiation from one another and from visitors; final exact colors must not collide with zone overlay colors.
- Avoid realistic humans, chibi extremes, and visual noise in crowds.

## Scale & Technical Requirements

- Character height, width, skeleton convention, pivot, and axis are **OPEN QUESTIONS**. Maintain relative consistency with the 3.0-unit wall height rather than assuming real-world metres.
- Visual identity must survive normal current-floor orthographic zoom; detailed accessories are secondary.
- Only the current viewed floor normally renders agents; do not put essential gameplay information in hidden off-floor character visuals.

## Acceptance Criteria

- A player can identify visitor, cleaner, and security roles while agents are moving at normal gameplay zoom.
- A group of visitors remains visually diverse without making flow density unreadable.
- Entering and leaving are understandable through direction and fade/motion without shared material artifacts.
- Cleaner working and security patrolling read as distinct behaviors even without labels.

## Open Questions

1. Exact character dimensions, skeleton compatibility, pivot, and target budgets are unapproved.
2. Is a visitor palette/wardrobe variation sufficient for MVP, or are body-type variations required?
3. Should staff roles use explicit equipment from MVP or only role-coded silhouette/color?
