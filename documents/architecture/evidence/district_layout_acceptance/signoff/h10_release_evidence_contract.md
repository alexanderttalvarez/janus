# H10 Release Evidence Contract

**Status:** Approved architecture/release-evidence policy. This defines what must be measured and signed; it does **not** claim that the measurements, package proof, warning cleanup, or signoffs have occurred.

**Policy clarification:** 2026-09-08 delegated documentation pass resolves sampling and test-pack workload ambiguity only. No hardware run, artifact, signer, checksum or release approval is claimed. Actual feasibility and measurements remain Gate R work.

## FACTS

- H10 uses the already selected **hybrid** performance policy and **Archive Policy B — separate test pack**.
- Design requires 60 FPS with up to 200 simultaneous MVP visitors.
- H10 requires Architecture, Design, QA, and Release signoffs.
- Generated projections, topology, and definitions must not leak mutable authority or survive as unreleased runtime state.

## 1. Performance policy: Hybrid R1

### Release validation reference (RVR-1)

H10 release measurements are taken on one clean, dedicated desktop matching all of the following:

| Component | Required reference |
| --- | --- |
| OS | Ubuntu 24.04 LTS, 64-bit, updated only with recorded package versions |
| CPU | AMD Ryzen 5 3600, six cores / twelve threads, stock clocks |
| GPU | NVIDIA GTX 1660 SUPER, 6 GB VRAM, proprietary driver version recorded |
| Memory | 16 GB DDR4 |
| Display | 1920x1080, 60 Hz |
| Engine/build | Godot 4.7 stable, release export, Forward+ renderer, no editor, profiler, debug overlay, or remote inspector attached |

RVR-1 is the H10 **regression reference**, not a published minimum-spec promise and not a replacement for future platform certification. Measurements from a CI VM, developer laptop, debug build, or a different renderer may diagnose failures but cannot satisfy H10 release evidence.

### Required workload and absolute limits

Use the frozen `fixture.mixed_3x3`, with its required initial ownership, all generated district/public-realm/traffic projections enabled, and 200 realized MVP pedestrian visitors. Run the release build at 1080p with VSync disabled. The benchmark must also execute 30 topology/projection rebuild cycles and 20 V2 save/load cycles without restarting the process.

This workload runs in a separately built **release-mode benchmark test pack** using the candidate's identical runtime modules, renderer and export toolchain. Fixture selection exists only in that test pack. The shipping production package stays fixture-free and is independently exported/scanned; do not add a production fixture selector or mount path to satisfy benchmarking. Bind both artifact checksums to the same candidate. The rebuild cycles change valid topology and verify rebuilt equivalence, not unchanged-revision no-ops; save/load cycles exercise the complete Session H2 registry, not District-only serialization. All 200 visitors are realized/rendered by the runtime, not merely immutable records.

| Metric | Absolute acceptance limit |
| --- | ---: |
| Steady-state median FPS | >= 60 |
| Steady-state 1st-percentile FPS | >= 50 |
| Frames slower than 33.3 ms | 0 during each measured sample |
| Draw calls | <= 160 at steady state |
| Total Nodes | <= 650 at steady state |
| Video memory | <= 256 MiB at steady state |
| Full initial projection build | <= 1,500 ms |
| Targeted projection/topology rebuild | <= 250 ms |
| Resolver, graph regeneration, and staged V2 load | <= 500 ms each |
| V2 save file | <= 2 MiB for the benchmark state |

The existing observation baseline is not an acceptance baseline. On RVR-1, record a clean baseline from the accepted candidate workload before comparing later builds. A later candidate must additionally show no more than a 10% median-FPS regression, a 10% increase in draw calls/nodes/video memory, or a 15% increase in any timed operation, relative to that recorded RVR-1 baseline. A candidate failing either an absolute or relative limit fails H10.

### Sampling protocol

1. Start from a clean reboot; record commit, export checksum, engine version, driver, OS version, renderer, resolution, and benchmark configuration checksum.
2. For each of three independent runs, launch the release export, load the benchmark fixture, wait 30 seconds, then capture a continuous 120-second steady-state sample at one-second cadence.

   Capture every frame duration during that sample; one-second summaries retain frame count, maximum frame duration and the full per-frame distribution/raw timestamps needed for percentiles and the zero-slow-frame rule. One instantaneous FPS reading per second is insufficient. Timed rebuild/load operations are measured separately from the steady-state frame window, never discarded from their operation limits.
3. During the same process, execute the rebuild and V2 save/load cycles above; capture operation durations, node count, draw calls, memory, path size, source count, and save size after every cycle.
4. Save raw samples and a derived report containing median, 1st percentile, maximum, and minimum values. Report the worst qualifying run for each acceptance metric.
5. Stop normally, capture the complete console, and run the leak gate below. Do not average away a failed run; any failed run fails the candidate.

## 2. Warning and leak gate

Assertion success is insufficient. Every required headless suite, the RVR-1 benchmark, and the 30/20 repeated-cycle workload must exit 0 and emit **zero** application-owned `ObjectDB`-leak, resource-leak, orphan-node, or `ERROR:`/`WARNING:` lines after the test harness begins.

A warning is attributed to the creating test/system before it can be suppressed. The evidence record must include the exact command, full console log, Godot version, occurrence count, owner, and fix commit. Earlier H8 process-exit warnings are historical; the proof/readiness records claim clean local reruns. Gate R still requires warning-free candidate-bound logs, not a presumption that an old warning persists or that a local claim proves release cleanup.

The only exception is a documented Godot-engine defect reproducible in a minimal project with no Janus objects, linked to an upstream issue and explicitly waived for this release by Architecture, QA, and Release. A local warning is never waived merely because assertions pass.

## 3. Archive Policy B: separate test pack

Archived fixtures and legacy/test-only support exist only in a separately built **test pack**. They have no production runtime reachability.

### Production package exclusion set

The production export must exclude all test runners, test scenes, proof-only fixtures, archived layouts, and test-only legacy support, including any retained `GridManager` convenience implementation. Production code may not load, reference, register, or select them by resource path, class name, fixture ID, scene reference, autoload, preload/load, or project setting.

### Required CI proof

The release pipeline must create, retain, and link from the evidence folder:

1. a production release export checksum and deterministic included-file manifest;
2. a separately built test-pack checksum and manifest;
3. a forbidden-path/class/fixture scan of the production manifest, with zero hits;
4. a dependency/registration scan proving the production project has zero reachability to archive-only content;
5. the exact headless command that mounts/runs the test pack, showing that proof fixtures are available only there; and
6. CI job URLs, commit SHA, toolchain versions, and retained raw logs.

The CI job fails closed on a missing manifest, a production inclusion, a production-to-archive reference, a test-pack build failure, or a failed proof suite. Merely placing files in a directory named `archive` does not satisfy Policy B.

## 4. GridManager final H10 classification

`GridManager` is **retired legacy grid authority**, not a target District Runtime service and not an H10 adapter. Decision 27 explicitly supersedes it as complete district authority.

| Current convenience surface | H10 classification | Required disposition |
| --- | --- | --- |
| `DEFAULT_PLOT = "plot_0"` and default plot parameters | Forbidden production identity fallback | Remove from production paths; retained only in the archive test pack if old zone/parcel regression harnesses still require it. |
| `GROUND_FLOOR = "G"`, string floor defaults, and floor-label parsing | Forbidden authority fallback; labels may remain presentation-only | Target boundaries require explicit plot ID and signed elevation. |
| Default pedestrian margin and exterior-ring geometry | Superseded by H5 topology/public-band descriptors | No production fallback or direct exterior-grid inference. |
| Tile/floor world-size constants and zero-origin conversion | Superseded by H4 injected `ProjectionMetrics` | No global metric fallback or authority transform inference. |
| Direct `GridTile` mutation, global path rebuild, and legacy serialize/deserialize | Superseded by H3 transactions and H9 V2 snapshots | No production writer or V2 authority dependency. |

A production dependency on `GridManager`, any omitted-identity call, or a `GridManager`-derived fallback fails H10. Its archive-only retention is permitted solely while named regression suites require it, subject to the Policy-B manifest/reachability proof above; otherwise delete it. This classification does not alter approved zone/parcel gameplay behavior.

## 5. Signoff protocol

Each signer reviews the final evidence package at the candidate commit and records name, role, UTC timestamp, commit SHA, evidence-manifest checksum, decision (`approve` or `reject`), and any bounded exception. A reject, missing field, stale commit/checksum, or unresolved exception blocks release.

| Role | Must approve |
| --- | --- |
| Architecture | Authority direction, adapter/default removal, H1-H9/H10 matrix, save/projection invariants, performance and leak evidence. |
| Design | The candidate preserves approved district, frontage/public-band, traffic, and visitor-arrival behavior; no compatibility removal changes gameplay. |
| QA | Complete test matrix, fixtures, fault injection, warning-free logs, archive test-pack exercise, and reproducible evidence. |
| Release | RVR-1 measurements, export/test-pack CI proof, versioned artifacts, rollback readiness, and all prior signoffs. |

Roles may be held by different people only; one person may not sign more than one H10 role. Signers are assigned by the release owner and are intentionally not invented by this document.

## OPEN QUESTIONS

- The actual people assigned to the four roles.
- The production export-preset name and CI-provider/job identifiers. They must be inserted into the evidence record before the first acceptance run; they do not change this policy.
