# Progression Handoff 02 — Vertical Expansion

**Status:** Approved — 2026-09-03
**Prepared:** 2026-09-03
**Implementation order:** 2 of 3 — after Progression H1

**Revision:** 2026-09-08 delegated consistency pass; element 08 is the only Tech cost/award authority. This corrects arithmetic, not node costs. Current scope and MVP H3 govern playable availability and normal-play awards.

## Purpose

Extend the approved Progression snapshot with grouped upper-floor and deep-underground unlocks. This handoff supersedes Progression H1's normal-mode `U1–U3` mapping: Underground now unlocks `U1–U2`, while Deep Foundations unlocks `U3–U5`.

It provides eligibility only. Economy H2 prices acquired tiles; District H3 owns physical/elevation/ownership validation and atomic mutation.

## Approved vertical policy

| Node | Cost | Tech prerequisite | Mall Level gate | Eligible elevations |
|---|---:|---|---|---|
| Multi-Floor | 2 | Stairs | Existing | F1–F2 |
| Underground | 3 | Multi-Floor | Existing | U1–U2 |
| Vertical Expansion I | 1 | Multi-Floor | Neighborhood Center | F3–F5 |
| Vertical Expansion II | 1 | Vertical Expansion I | Regional Mall | F6–F7 |
| Vertical Expansion III | 1 | Vertical Expansion II | City Destination | F8–F9 |
| Deep Foundations | 1 | Underground | Regional Mall | U3–U5 |

A node is eligible only when both its Tech prerequisite chain is unlocked and its Mall Level threshold is reached. Unlocking a node grants eligibility for its complete listed elevation range, subject to existing District physical caps, acquired vertical rights, sequential acquisition, construction, and Economy affordability.

The four extension nodes cost 4 points. Use element 08's corrected complete catalogue total, 26 of 40 including Bus Stop; the former 23-plus-4 subtotal double-counted the old branch budget and is not authoritative.

## Scope

- Update Progression H1 snapshot eligibility for all signed elevations.
- Add the four approved Tech-node definitions, prerequisites, tier gates, and stable IDs.
- Ensure District H3 receives/revalidates the resulting immutable snapshot before Economy capture.
- Define save/load, debug, rejection, and test requirements for the extension.

## Non-goals

- New price values, refunds, plot access, street conversion, transport, maintenance, tenant lifecycle, or construction policy.
- Any elevation beyond physical `F9`/`U5` limits.
- Changing Multi-Floor or Underground's existing Tech Point costs/prerequisite chain except Underground's eligible range now ending at U2.

## Ownership and data flow

```text
PrestigeManager tier result + TechTreeManager unlock state
  -> Progression authority computes immutable eligibility snapshot
  -> District Runtime validates physical intent and snapshot revision
  -> Economy quotes/reserves/captures approved tile cost
  -> one committed District/Economy result
```

The snapshot contains stable node IDs, tier reference, eligibility ranges, explicit unavailable ranges, and revision. It must not contain prices, mutable District references, UI state, or Node references.

## Normal and debug behavior

- In normal play, unpurchased/unqualified vertical nodes reject elevation requests with stable progression diagnostics and no Economy capture.
- God mode remains fully progression-unlocked: all physical F1–F9/U1–U5 elevations are eligible without Tech Points or Mall Level gates. District physical constraints and Economy/District atomicity remain enforced.

## Persistence

Persist existing unlocked node IDs and earned/spent Tech Point state. Elevation eligibility is derived after load from the versioned node catalog and committed Mall Level, never saved as duplicate mutable flags. Save migration must map pre-H2 Underground entitlement to its new U1–U2 meaning and must not silently grant Deep Foundations/U3–U5; older save compatibility policy remains owned by the approved save schema/migration process.

## Acceptance requirements

- Underground grants exactly U1–U2; U3–U5 require Deep Foundations plus Regional Mall.
- Each Vertical Expansion node grants exactly its listed F range, with prerequisite chain and tier gate both enforced.
- Extension nodes total four Tech Points; the complete listed catalogue matches element 08 (26/40 including Bus Stop).
- District H3 rejects ineligible elevations before Economy capture and revalidates snapshot revisions atomically.
- Normal unavailable elevation requests produce deterministic diagnostics and no mutation.
- God mode permits the full physical elevation range without bypassing District constraints.
- Save/load derives identical eligibility from stored node IDs/tier and does not silently expand old Underground entitlement.

## Risks

- Treating price availability as unlock eligibility; keep Economy H2 and Progression independent.
- Silent U3 access after the Underground range change; require explicit migration/rejection behavior.
- Coupling display names to IDs; use stable node IDs in saves and snapshots.

## Follow-up

Transport progression and any post-F9/U5 content require separate approved handoffs.
