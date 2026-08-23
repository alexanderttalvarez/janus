# Sound-Effect Direction

## Identity

**Asset IDs:** `sfx_ui_feedback`, `sfx_world_feedback`, `sfx_district_ambience`  
**Category:** Sound effects and ambience  
**Family:** Non-intrusive confirmation and district life

## Purpose

Sound effects should clarify actions and simulation events without interrupting the serene build/observe loop. Ambient sound, if approved, should make the commercial district feel occupied without masking data feedback.

## Source

- `01_core_loop.md` — building, tenant construction, observation, and construction phase changes.
- `11_transit_circulation.md`, `15_staff_system.md`, `17_ui_hud_system.md`, `18_notifications_system.md`.
- [style_guide.md](../style_guide.md) — audio identity is unresolved.

## Required Families

| Asset | Trigger / purpose | MVP representation | Production representation |
|---|---|---|---|
| UI feedback | Tool selection, confirm, cancel/reject, panel and notification action | Small shared action set | Consistent interaction language with careful priority variation |
| World feedback | Zone placement/removal, construction start/phase/opening, staff cleanup, elevator use | Minimal event cues | Expanded physical-system feedback that reinforces visible events |
| District ambience | Optional background life | N/A until approved | Controlled mall/street/terrace ambience responsive to future time/crowd context |

## Duration & Repetition

| Family | Duration / loop requirement | Expected repetition |
|---|---|---|
| UI feedback | Short, non-looping acknowledgement; exact duration is unapproved | Potentially frequent during building and panel use |
| World feedback | Short, non-looping state acknowledgement; exact duration is unapproved | Repeated during construction, placement, and staff activity |
| District ambience | Looping layer only if approved; duration is unapproved | Continuous but subordinate to feedback |

## Required Variants

- UI: at minimum select, confirm, reject, and notification alert once direction is approved.
- World: at minimum build/place, remove, tenant opening, cleaning completion, and elevator travel once direction is approved.
- Ambience: only if approved; any day/night/crowd variants are post-MVP.

## Acceptance Criteria

- A player can distinguish successful confirmation from an invalid or blocked action without needing to stare at the UI.
- Frequent placement/building sounds do not become tiring during repeated actions.
- Urgent notification feedback is noticeable without being startling or punitive.
- Ambient layers, if used, remain beneath gameplay/UI feedback and preserve long-session comfort.

## Open Questions

1. Should SFX be realistic, abstract/minimal, or more stylized?
2. Should the district have constant mall/street ambience, conditional ambience, or remain quiet outside interaction feedback?
3. What loudness, dynamic-range, mixing, accessibility, and format targets apply?
4. Are notification sounds MVP? Game design lists them as post-MVP while notifications themselves are MVP.
5. What duration range is comfortable for frequent UI and building feedback?

**Planning status:** `blocked` — the required sound style and technical delivery constraints are not confirmed.
