# Music Direction

## Identity

**Asset ID:** `music_gameplay_ambient`  
**Category:** Music  
**Family:** Gameplay ambience

## Purpose

Music supports long creative observation/building sessions and the aspirational, slightly nostalgic Janus atmosphere. It must not compete with spatial analysis, notifications, or the player's visual focus.

## Source

- `01_core_loop.md` — sessions alternate active building and passive observation; visual time/seasonal changes are post-MVP in architecture.
- [style_guide.md](../style_guide.md) — cheerful, clean, inviting, slightly nostalgic tone; City Pop is a visual influence only, not an automatic music mandate.

## Gameplay Context

- Plays across pause, building, observing, and accelerated simulation without becoming fatiguing.
- Future time-of-day and seasonal presentation may motivate music variation, but no dynamic music behavior is confirmed.

## Duration & Repetition

| Requirement | Value |
|---|---|
| Playback | Continuous during ordinary gameplay, subject to future player audio settings |
| Looping | Seamless loop required for MVP |
| Approximate duration | **OPEN QUESTION** — no source establishes a loop length |
| Repetition tolerance | Must remain comfortable through repeated long management sessions |

## Required Variants

| Scope | Requirement |
|---|---|
| MVP | One seamless instrumental gameplay loop. |
| Post-MVP | Optional time-of-day and/or seasonal variants only after audio direction and dynamic-music policy are approved. |

## MVP & Production Representation

- **MVP:** One loop that is calm enough for extended management play, unobtrusive during UI analysis, and tonally compatible with clean urban creativity.
- **Production:** A coherent set that can shift atmosphere with time/season without abrupt mood changes or requiring players to listen to a foreground soundtrack.

## Acceptance Criteria

- The loop can play through a standard 1–2 hour session without demanding attention.
- It supports, rather than implies, the approved visual City Pop influence.
- It leaves enough auditory space for future interaction feedback and ambience.

## Open Questions

1. What genre and instrumentation are approved?
2. What energy level is appropriate during building, observation, and higher simulation speed?
3. Is City Pop a musical influence, a visual-only influence, or not a music reference at all?
4. Are time-of-day/season transitions, music layers, and music settings in scope?
5. Audio format, loudness target, loops, and platform constraints are unapproved; see [technical_guide.md](../technical_guide.md).

**Planning status:** `blocked` — the identity questions above materially determine the asset.
