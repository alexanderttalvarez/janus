# P01 Foundation Gate Evidence

**Observed:** 2026-09-09  
**Base candidate:** `65614da981244ad62da8f6430d725e1c6e9a07bb`  
**Candidate state:** dirty implementation worktree; see the command inventory below.  
**Engine/platform:** Godot `4.7.stable.official.5b4e0cb0f`, Linux headless.

## Scope

P01 from [MVP delivery and acceptance](../../handoff/mvp/04_product_delivery_and_acceptance.md): explicit startup/content, deterministic calendar delivery, shared session mutation boundary, Economy/Progression immutable policy injection, and District transaction integration.

## Observed Results

| Check | Command / method | Result |
| --- | --- | --- |
| Policy contracts | `godot --headless --path . -s res://tests/test_p01_policy_contracts.gd` | PASS, 65 passed / 0 failed |
| Session gate contracts | `godot --headless --path . -s res://tests/test_p01_session_gate.gd` | PASS, 17 passed / 0 failed |
| Session/content/calendar regression | `godot --headless --path . -s res://tests/test_session_h1.gd` | PASS, 35 passed / 0 failed |
| District transaction regression | `godot --headless --path . -s res://tests/test_district_runtime_h3.gd` | PASS, 44 passed / 0 failed |
| Arrival/shared-boundary regression | `godot --headless --path . -s res://tests/test_visitor_arrival_h8.gd` | PASS, 51 passed / 0 failed |
| H10 caller compatibility | `godot --headless --path . -s res://tests/benchmarks/h10_rvr1_benchmark.gd` | PASS; 200 seeded visitors, 30 rebuild cycles, 20 save/load cycles |
| Production startup | `godot --headless --path . --quit-after 60` | PASS; `MainGame: Ready and paused.` |
| Editor/runtime startup | GodotIQ `run(play, main)` + `state_inspect` | PASS; `GameManager.session_ready=true`, GameManager and TimeManager speed `0`, both clocks `0` |
| Debug console | GodotIQ `read_debug_console` while running | PASS; 0 runtime/script errors |
| Independent implementation review | Separate reviewer after focused verification | PASS; no remaining P01 blocker |

## Boundary Evidence

- `SessionMutationGate` rejects a second owner and blocks non-retry owners after a failed mandatory boundary.
- `TimeManager` pauses a failed boundary, retains its identity, and advances/publishes it only after a successful retry.
- District and Arrival logical gates are bound to the exact same injected session gate; mismatched arrival-gate wiring rejects.
- An arrival invoked as the direct visitor-calendar successor adopts the already-held calendar boundary without reentrant acquisition, then releases only its logical hold. The calendar retains and releases the session boundary itself.
- Save capture/load, gameplay input, District transactions, and Arrival commits use the shared session boundary.

## Limitations

- GodotIQ project-wide script preflight still reports nine pre-existing, line-less, low-confidence `Script reload failed (error 22)` entries in unrelated projection/resource files. Direct focused checks, headless startup, and runtime debugger inspection did not reproduce a parse or runtime error.
- This evidence completes P01 implementation verification only. It does not mark A01-A15 Product acceptance as passed, and P02+ remain separately pending.
