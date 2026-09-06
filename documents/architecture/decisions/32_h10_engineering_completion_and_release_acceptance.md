# Decision 32: H10 Engineering Completion and External Release Acceptance

**Date:** 2026-09-06  
**Status:** Accepted — release evidence is no longer an implementation-input blocker.

## Context

H10 combines work executable by implementation agents with evidence that requires external release infrastructure or human authority. The implementation candidate now reports passing H1-H10 and regression suites, a valid 200-visitor/30-rebuild/20-save-load headless workload, valid production/test-pack policy manifests, clean project/runtime validation, and no orphan signals.

Linux export templates, the specified RVR-1 physical machine, CI artifact retention, and named human signers are not architectural inputs and cannot legitimately be invented by an implementation agent. Repeatedly requesting them before declaring engineering work complete conflates two different gates.

## Decision

H10 is divided into two explicit gates.

### Gate E — Engineering completion

Gate E is owned by implementation and QA-automation agents. It is complete when:

- H1-H10 and required regression suites pass;
- the headless RVR workload reaches 200 visitors and completes 30 rebuild plus 20 V2 save/load cycles;
- production and test-pack source/policy manifests pass their forbidden-content and reachability rules;
- the main scene starts without runtime errors;
- project validation and signal audits pass;
- application-owned ObjectDB/resource leaks are absent from the completed local suites; and
- scripts/tools needed to produce exports, checksums, manifests, benchmark samples, and evidence reports are present and documented.

Unavailable export templates, unavailable RVR-1 hardware, absent CI credentials/job URLs, and unassigned human signers do **not** block Gate E. Once the above automated work is complete, implementation agents must report **Engineering complete; H10 release acceptance pending external Gate R** and stop requesting those external inputs as implementation prerequisites.

### Gate R — External release acceptance

Gate R is owned by Release coordination and starts from a frozen candidate commit after Gate E. It requires:

1. install the official Godot 4.7 Linux export templates matching the candidate engine exactly;
2. produce the production export and separate test pack;
3. record export checksums, included-file manifests, forbidden-content/reachability results, CI job URLs, toolchain versions, and retained logs;
4. run the release export on RVR-1 hardware using the approved sampling protocol and record raw/derived measurements;
5. bind the complete evidence-manifest checksum to the frozen candidate commit; and
6. obtain Architecture, Design, QA, and Release approvals for that exact commit and checksum.

Gate R may fail and return corrective work to implementation. Until then, its missing artifacts are a release hold, not an unresolved architecture or coding blocker.

## Export-template responsibility

The Release owner or CI-infrastructure owner installs and verifies export templates. The implementation agent owns only the reproducible export command/configuration and failure diagnostics. It must fail clearly when templates are absent; it must not download unverified binaries, alter the engine version, or fabricate package checksums.

## Signoff responsibility

The Release owner assigns actual people to Architecture, Design, QA, and Release after a candidate and evidence checksum exist. Signoffs are deliberately unassigned during Gate E. Implementation agents must not request names during feature work and must not mark roles approved on anyone's behalf.

## GodotIQ reload-diagnostic disposition

A low-confidence `Script reload failed (error 22)` entry without file position or compiler diagnostic is classified as a **tooling-only advisory** and does not block Gate E or Gate R when all of the following are recorded for the same candidate:

- direct headless parse/check succeeds for every named script;
- all affected suites pass;
- the production main scene starts without script/runtime errors; and
- the Godot debugger/console contains no corresponding reproducible error.

Any diagnostic with a location, reproducible parse failure, runtime failure, or failing suite remains blocking. The advisory and corroborating checks remain in the audit record; they are not silently deleted.

## Current disposition

Based on the recorded implementation report, Gate E is **complete subject to committing the final evidence/tooling changes at one candidate revision**. Gate R remains pending because release templates, exported artifacts/checksums, RVR-1 physical measurements, CI records, and human signoffs are external work.

This status means implementation may stop. It does not mean H10 is release-accepted.

## FACTS

- Export templates and physical reference hardware are environmental dependencies.
- Human signoffs can only bind to an actual candidate commit and evidence checksum.
- Headless benchmark validity does not substitute for release-build RVR-1 measurements.

## OPEN QUESTIONS

- Candidate commit SHA.
- Assigned Release/CI owner and eventual four signers.
- CI job URLs and physical benchmark execution date.
