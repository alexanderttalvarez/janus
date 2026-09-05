# Future Progression Architecture Topics

This register preserves deferred design ideas. It does not authorize implementation or alter current progression/economy ownership.

## Achievement milestones and Kred rewards

**Recorded:** 2026-09-05
**Status:** Deferred — not designed

### Intent

Add a game-internal achievement/milestone mode, for example: “Create 10 zones.” Completing an achievement may grant free Kreds.

This is not dependent on Steam or another platform achievement service. Platform integration is a separate future concern and must remain an optional projection of the game-internal achievement state.

### Future architecture requirements

- An immutable achievement catalog with stable IDs, eligibility conditions, reward definitions, content revision, and presentation metadata.
- One achievement authority owning earned/claimed state, idempotence, persistence, and snapshot publication.
- A read-only event/fact subscription boundary: zone, tenant, construction, Economy, and other systems publish committed facts; the achievement authority never writes their state.
- Economy remains the sole balance writer. A completed/claimed reward must become one idempotent committed Economy credit with stable achievement reference; direct balance mutation is prohibited.
- Save/load must preserve completed/claimed identities and reward idempotence so loading or replaying events never duplicates Kreds.
- UI/notification and optional Steam/platform adapters are presentation/integration consumers, not achievement authorities.

### Open design questions

- Achievement list, thresholds, reward amounts, hidden versus visible milestones, timing of claim versus automatic grant, and whether achievements are profile-wide or save-slot-specific.
- Whether platform achievements mirror all, some, or none of the internal achievements.
