# ADR History

Use the [ADR registry](../decisions.md) for current applicability and supersession. Read [ADR 33](33_documentation_consistency_and_minimum_contracts.md) before earlier examples. Accepted history is retained; a status header alone does not undo a later explicit amendment.

**Follow-on review, 2026-09-08:** Read [ADR 34](34_product_mvp_runtime_and_cutover.md) after ADR 33 for the separate H4/H5 architecture approval and staged Product delivery boundary. It supersedes the earlier draft disposition, not the earlier record or its other contracts. Implementation/cutover remain NOT VERIFIED; Product acceptance and external Gate R remain PENDING.

**Follow-on resolution, 2026-09-09:** [ADR 35](35_public_band_access_snapshot_and_zone_injection.md) accepts the exact transient public-band access snapshot, District-to-Zone candidate injection, and stable Zone door provenance representation. It adds no manager, save root, migration, or implementation evidence.

**Follow-on resolution, 2026-09-10:** [ADR 36](36_district_zone_spatial_snapshot_and_zone_mutation.md) accepts DistrictState local schema v3 within unchanged Save V2, the bounded transient District-to-Zone floor snapshot, and coordinated Zone paint transactions. It adds no manager or generalized spatial authority and asserts no implementation or evidence.

**Current correction, 2026-09-10:** [ADR 37](37_district_construction_annex_schema.md) corrects ADR 36's accidental exact-root omission by retaining the Construction H1 annex in DistrictState v3, with corridors represented only by explicit circulation and `district_revision` remaining the sole concurrency guard. Save V2 and the authority registry remain unchanged; implementation and evidence are not asserted.
