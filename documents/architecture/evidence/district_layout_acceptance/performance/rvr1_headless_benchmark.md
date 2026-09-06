# H10 RVR-1 Headless Benchmark Evidence

**Status:** authority/projection benchmark captured; release-export sampling remains pending export-template availability.

## Command

```text
godot --headless --path . --script tests/benchmarks/h10_rvr1_benchmark.gd
```

## Captured workload

- `fixture.mixed_3x3`
- 200 immutable `VisitorData` records
- 30 H4/H5/H6/H7 rebuild cycles
- 20 District Runtime state save/load cycles
- Clean application console and normal process exit

## Observed result

- Benchmark exit code: `0`
- Rebuild samples: `80–91 ms` (latest run maximum: `91 ms`)
- Save/load samples: `116–136 ms` (latest run maximum: `136 ms`)
- Latest targeted rebuild maximum: `91 ms`
- Serialized benchmark state: `417 bytes`
- No `ERROR:`, `WARNING:`, ObjectDB leak, or resource-leak lines

The harness intentionally exercises unchanged targeted rebuilds after the initial build; projection owners now return their committed immutable result when the relevant District Runtime revision is unchanged. Full RVR-1 acceptance still requires three clean release-export runs at 1080p with FPS, frame-time, draw-call, node-count, and VRAM sampling on the specified reference hardware.
