# Staff Assets

Staff are generic employees (no names, no individual attributes). Two types in MVP: Cleaner and Security.

## Staff Base Mesh (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Visual representation of staff members. |
| **Style** | Low-poly humanoid, same proportions as visitors. |
| **Height** | 1.75m (slightly taller than visitors) |
| **Width** | 0.5m |
| **Polygon budget** | ~200-500 triangles (MVP) |
| **MVP** | Same base mesh as visitor, differentiated by uniform color. |

## Staff Types

### Cleaner

| Property | Value |
|----------|-------|
| **Uniform color** | Light blue or green (distinct from visitors) |
| **Equipment** | Cleaning cart or tool (post-MVP) |
| **Behavior** | Walks to garbage/bathroom, performs cleaning action |
| **Spawn** | From Operations Room |

### Security

| Property | Value |
|----------|-------|
| **Uniform color** | Dark blue or black (distinct from visitors and cleaners) |
| **Equipment** | Badge or radio (post-MVP) |
| **Behavior** | Patrols coverage floors |
| **Spawn** | From Operations Room |

## Post-MVP Staff Types

| Type | Uniform Color | Equipment |
|------|--------------|-----------|
| **Maintenance** | Orange or yellow | Tool belt |
| **Customer Service** | Red or pink | Clipboard/tablet |

## Staff Identification

| Method | Description |
|--------|-------------|
| **Uniform color** | Primary visual differentiator (MVP) |
| **Label** | "Cleaner #1", "Security #2" in UI (not in-world) |
| **Equipment prop** | Post-MVP: visible tools differentiate types |

## Staff Animation Requirements

See [animations/staff_animations.md](../animations/staff_animations.md) for animation specifications.

## Reuse Opportunities

- **Same base mesh** as visitors (or very similar), differentiated by uniform color
- **Shared material** approach: base mesh + color parameter
- **Equipment props** can be shared across staff types (post-MVP)
- Operations Room is a building asset, not a character asset
