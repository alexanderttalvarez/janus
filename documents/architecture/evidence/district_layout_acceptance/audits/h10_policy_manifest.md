# H10 Archive Policy B Manifest Audit

**Status:** deterministic source-manifest audit implemented.

## Local command

```text
python3 tools/h10/build_policy_manifests.py --output-dir build/h10
```

## Current result

- Production manifest: 322 files, zero forbidden-content violations.
- Archive Policy B test-pack manifest: 608 files.
- Production excludes tests, documentation, tooling, editor/debug addons, fixture generators, editor preview scripts, and retired grid-authority files.
- Production scan rejects `GridManager`, canonical legacy adapters, and the three proof-fixture IDs.

The CI workflow retains both manifests, exports the production release and test pack separately, records artifact SHA-256 checksums, and fails closed on manifest violations or application console errors.
