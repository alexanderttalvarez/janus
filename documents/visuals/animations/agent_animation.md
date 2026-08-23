# Animation & Motion Requirements

## Identity

**Asset IDs:** `anim_visitor_state_set`, `anim_staff_state_set`, `anim_world_ui_feedback`  
**Category:** Animation  
**Family:** Readable state change at simulation scale

## Purpose

Motion gives visible proof of visitor, staff, tenant, elevator, camera, and notification state changes. It must aid comprehension of systems, not add arbitrary visual activity.

## Source

- `01_core_loop.md`, `05_visitor_simulation.md`, `06_tenant_shop_system.md`, `11_transit_circulation.md`, `15_staff_system.md`, `17_ui_hud_system.md`, `18_notifications_system.md`.
- `03_visitor_agents.md`, `16_camera_system_architecture.md`, `17_notification_system_architecture.md`, `23_state_machine_architecture.md`.

## Gameplay Context

- Visitor state machine covers entering, setting goals, moving, satisfying a need, exploring, queueing, and leaving.
- Staff state machine covers idle, moving to task, working, and returning to idle. Security patrols rather than processes a cleaning queue.
- Construction is visible in three phases. Elevator travel has capacity/queue meaning. Camera rotation and UI panel/toast transitions support interaction feedback.

## Required Motion Sets

| Asset | MVP representation | Production representation | State / reuse requirement |
|---|---|---|---|
| Visitor state set | Clear idle and travel presentation; spawn fade; leaving direction | Distinct explore, queue, satisfy, and leave motion | Shared base locomotion allowed; intent must stay readable |
| Cleaner state set | Shared travel plus a clear cleaning action | Cleaner task action for litter and bathroom work | Idle, travel, work |
| Security state set | Shared travel plus visually calmer patrol/readiness posture | Patrol/observe behavior | Idle, travel, patrol |
| Maintenance state set | N/A | Repair task motion | Idle, travel, repair |
| Elevator travel | Clear floor-to-floor cab movement | Smooth readable travel/door state if door art exists | Shared across all elevators |
| Construction transition | State change at phase thresholds | Visually progressive construction family | Phase 1, 2, 3, operational |
| UI/camera feedback | Panel/toast/camera movement cue | Consistent responsive interaction motion | Open/close, show/dismiss, 90° rotation |

## Dependencies & Reuse

- Visitor and staff motion must align with the shared agent families in [agents.md](../characters/agents.md).
- Motion state names/changes are driven explicitly by managers, not inferred from visual polling.
- Construction motion depends on lifecycle overlays in [overlays.md](../vfx/overlays.md); it may be a state treatment where full geometric progression is not justified.

## Visual Requirements

- Calm, legible, and restrained. Avoid exaggerated comic timing or hyperactive idle loops that conflict with the serene professional tone.
- In small orthographic view, direction, pause, queue, and task state matter more than detailed limb acting.
- Staff task motion must not be confused with visitor browsing.
- UI motion should support the "inform, don't interrupt" principle.

## Technical Requirements

- Visitor and staff render selectively by floor/zoom, so state readability must not depend on a long, hidden setup animation.
- Current architecture uses per-instance visitor fade-in and explicit animation state selection.
- Exact skeleton format, animation frame rate, root-motion policy, and clip delivery conventions are unresolved; do not lock production to a method yet.

## Acceptance Criteria

- A player can tell whether an agent is walking, waiting, working, patrolling, or leaving at normal zoom.
- New visitors appear without a shared-material transparency artifact.
- Construction and elevator state changes have an observable visual transition or distinct new state.
- UI motion is quick and does not make a player wait before issuing the next building action.

## Open Questions

1. Is simple positional movement sufficient for the first playable MVP, or is a visible walk cycle required from the outset?
2. Are elevator door states part of MVP presentation?
3. Which motion clips may be shared across visitor and staff rigs after final character direction is approved?
