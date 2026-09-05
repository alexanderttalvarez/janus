# Tenant Handoff 03 — Candidate Policy and Catalog

**Status:** Approved — 2026-09-05 (delegated architecture authority)
**Implementation order:** 3 of TBD — after Tenant Handoffs 01–02

## Purpose

Provide the missing immutable candidate content required for Tenant H2 to produce real deterministic applications in an MVP. The policy turns H1/H2's seeded candidate contract into a small, inspectable, data-driven catalog without inventing tenant performance, brands, or final balancing.

## Scope

- Typed immutable candidate-policy Resource/catalog and revision contract.
- Initial Tier 1 MVP profile entries for the existing five legal subtype examples of each zone type.
- Uniform deterministic selection among legal entries and uniform inclusive Selectivity from `-10` through `+20`.
- Stable profile identity/provenance, validation, V2 policy-reference compatibility, and fixtures.

## Non-goals

- Final brands, narrative tenant identities, tier weighting curves, upgrades, revenue, viability, visitor behavior, or subtype-specific area tuning.
- Changing H1 subtype graph legality, H2 supported-tier cap, score formula, retry flow, or rate policy.
- Mutable per-candidate Resources, random call-order state, direct UI editing, or save ownership of static content.

## Ownership

| Owner | Owns | Must not own |
|---|---|---|
| Candidate policy content | Stable profile IDs, subtype ID, zone type, tier, optional weight, catalog revision. | Runtime candidate/lifecycle state. |
| `TenantManager` | Seeded selection, persisted evaluation ordinal, profile provenance on successful bind. | Content mutation, zone writes, policy fallback. |
| `ZoneBusinessAssigner` / Zone snapshot | Legal subtype domain and adjacency exclusion. | Candidate profile selection/state. |
| Prestige H1 | Supported tier cap. | Candidate catalog/weights. |
| SaveManager | Session snapshot orchestration. | Saving/recreating static content. |

## Policy model

The catalog is a read-only typed Resource asset. Each profile contains only stable `profile_id`, `subtype_id`, permitted zone type, tenant tier, and optional future selection weight. Resources are shared read-only definitions and must never hold mutable lifecycle/candidate state.

Initial MVP content contains one Tier 1 profile for each of the existing subtype catalog examples:

- Retail: fashion, electronics, home goods, jewelry, bookstore.
- Food & Beverage: sushi restaurant, Italian restaurant, cafe, Mexican restaurant, local food.
- Entertainment: cinema, arcade, bowling alley, escape room, VR experience.
- Services: bank, hair salon, repair shop, clinic, travel agency.
- Anchor: department store, supermarket, gym, food court, exhibition hall.

These profiles use the existing zone-type and generic minimum-area eligibility from Zone Handoff 02. They are gameplay candidate content, not `DEBUG_IMMEDIATE` assignments; debug mode remains unchanged.

## Selection contract

At each due H2 evaluation:

1. Tenant captures immutable candidate policy, Prestige H1, and Zone legal-subtype snapshot.
2. It filters profiles by matching zone type, profile tier `<=` supported tier, valid size/type, and legal edge-adjacency subtype.
3. It canonically sorts remaining profiles by stable profile ID.
4. It derives deterministic random values from the persisted session seed, parcel ID, evaluation ordinal, and policy revision.
5. It chooses uniformly among filtered profiles. It chooses Selectivity uniformly from the inclusive integers `-10..20`.
6. It persists only successful bound profile ID/tier/Selectivity/provenance. A failed/declined evaluation persists only the advanced ordinal and retry identity required by H2.

No legal profile means `CANDIDATE_POLICY_NO_LEGAL_PROFILE`; H2 binds nothing and retries after three sim days. Missing/mismatched policy revision means `CANDIDATE_TIER_POLICY_UNAVAILABLE`; no Tier 1 fallback is allowed.

## Persistence and compatibility

Catalog content is not saved in `authorities.tenant`. Tenant V2 persists the policy revision/reference alongside any successful candidate provenance. On restore, the referenced policy must load and validate with the bound profile; otherwise the whole V2 session rejects under H9. A changed catalog requires an explicit compatible revision or a separately approved migration; implementation must not silently remap profile IDs.

## Acceptance requirements

- The same seed, parcel, ordinal, policy revision, Prestige cap, and legal snapshot yield the same profile and Selectivity across save/load.
- Only legal zone/subtype/area/adjacency profiles are selectable.
- Initial catalog enables a Tier 1 candidate for every valid debug-catalog zone subtype without altering debug mode.
- Tenant profile state never mutates a shared policy Resource.
- Missing/incompatible content results in a defer diagnostic, never a fabricated candidate or partial parcel binding.

## Required implementation skills

Load `resource-pattern`, `godot-testing`, `save-load`, and `dependency-injection` before implementation.
