# Future Tenant Architecture Topics

This register preserves important design-preparation concerns without turning them into approved scope, implementation work, or gameplay decisions. Each topic must receive its own design/architecture discussion and approved handoff before implementation.

## Tenant interiors, furnishing, and visitor interactions

**Recorded:** 2026-09-05
**Status:** Deferred — not designed

### FACTS

- Zone geometry and resulting tenant parcels may have unknown, irregular shapes.
- Different tenant subtypes will need different interior needs; a restaurant may require a cashier and seating/tables/chairs, while other subtypes will require different fixtures, circulation, and interaction points.
- Visitors are expected eventually to interact with tenant spaces and/or tenant-specific points of service.
- Tenant H1 deliberately owns occupancy and daily rent only. It does not create interiors, furnishing, visitor targets, purchases, revenue, or pathfinding destinations.

### Required future architecture discussion

A future tenant-interior/visitor-interaction handoff must decide, before implementation:

1. **Interior representation:** whether each tenant is an abstract simulation, an authored interior template, procedural placement inside parcel geometry, or a hybrid; and what is visible/enterable in the MVP.
2. **Parcel-to-interior boundary:** how irregular parcel footprints, walls, doors, entrance frontage, and walkable public corridors produce a valid usable interior region.
3. **Subtype content contract:** the data model for required/optional fixtures, capacities, service points, seating, clearances, orientation, and fallback behavior per subtype.
4. **Layout validity and degradation:** how layout generation guarantees non-overlap, reachable service points, circulation, and graceful fallback when a legal parcel cannot fit all preferred fixtures. It must not silently create inaccessible interactions.
5. **Visitor interaction contract:** whether visitors enter interiors or interact at exterior/door/service proxies; how a visitor selects a tenant, reserves capacity/queue slots, reaches the interaction point, completes/cancels service, and exits.
6. **Authority and economics:** which authority owns occupancy/capacity, service outcomes, purchase events, tenant revenue, and their links to later viability and Prestige. Tenant nodes, visitor nodes, and UI must not independently write these results.
7. **Performance and authoring:** instance lifetime, batching/LOD or proxy rules, navigation representation, deterministic generation/persistence requirements, tooling, and test fixtures for arbitrary shapes.

### Architectural constraint to preserve

Do not bake a fixed rectangular floor plan or subtype-specific scene hierarchy into Tenant H1. Future interior generation must consume committed parcel geometry and the authoritative tenant subtype, while preserving ZoneManager ownership of parcel/wall/door geometry and TenantManager ownership of tenant identity/lifecycle.
