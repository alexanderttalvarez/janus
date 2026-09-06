# Runtime Performance Baseline

This is an observation-only pre-RVR baseline. H10 uses the selected **Hybrid R1** policy defined in `../signoff/h10_release_evidence_contract.md` §1; this capture cannot satisfy release evidence because it was not taken through the required RVR-1 hardware, release-export workload, or sampling protocol.

Captured from the running `res://scenes/levels/main_game.tscn` through GodotIQ after startup:

| Metric | Value |
| --- | ---: |
| FPS | 60 |
| Draw calls | 128 |
| Total nodes | 545 |
| Objects | 214 |
| Triangles | 1,544 |
| Buffer memory | 27,405,304 bytes |
| Texture memory | 68,452,384 bytes |
| Video memory | 113,754,336 bytes |
| Orphan nodes | 0 |

Before H10 acceptance, record the three RVR-1 release-export runs, raw one-second samples, benchmark-cycle timings, console logs, and a clean candidate baseline as specified by the contract. Do not compare this GodotIQ observation to an RVR-1 release candidate.