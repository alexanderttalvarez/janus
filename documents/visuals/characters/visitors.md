# Visitor Assets

Visitors are individual agents that walk through the mall. They are Node3D instances with shared materials for efficient rendering (1 draw call).

## Visitor Base Mesh (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Visual representation of a visitor walking through the mall. |
| **Style** | Low-poly humanoid. Simple body, head, limbs. |
| **Height** | 1.7m |
| **Width** | 0.5m |
| **Polygon budget** | ~200-500 triangles (MVP) |
| **MVP** | Simple capsule or very low-poly humanoid (head + body). |
| **Post-MVP** | More detailed humanoid with clothing, accessories, hair variations. |

### MVP Visitor Design

The simplest viable visitor:
- **Option A**: Capsule shape (cylinder + sphere head) with a single color
- **Option B**: Very low-poly humanoid (box body, sphere head, cylinder limbs) ~50 triangles
- Both options allow readable movement and scale

### Post-MVP Visitor Variations

| Variation | Description | Reuse |
|-----------|-------------|-------|
| **Body type** | 2-3 body proportions | Shared skeleton |
| **Clothing** | 5-10 color/material variations | Same mesh, different materials |
| **Hair** | 3-5 simple hair styles | Add-on meshes |
| **Accessories** | Bags, hats, etc. | Add-on meshes |
| **Age groups** | Adult, child, elderly | Scaled/modified base mesh |

## Visitor Color Variations (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Visual variety among visitors without unique meshes. |
| **Method** | Material color parameter on shared mesh. |
| **Palette** | 8-12 distinct colors (clothing colors). |
| **Assignment** | Random per visitor spawn. |

## Visitor Thought Bubble

| Property | Value |
|----------|-------|
| **Purpose** | Shows visitor's current goal or state need. 3 random visitors show bubbles at any time. |
| **Type** | Label3D node (Godot) or sprite-based bubble |
| **Size** | ~0.5m wide × 0.3m tall in world space |
| **Position** | Above visitor's head (~2.2m from ground) |
| **MVP** | Simple text label (Label3D) with emoji or short text. |
| **Post-MVP** | Sprite-based bubble with icons (shoe icon for shopping, fork for dining, etc.). |

### Thought Bubble Content (MVP)

| Bubble Text | Meaning |
|-------------|---------|
| "I need new shoes" | Shopping goal |
| "I'm hungry!" | Hunger need |
| "That restaurant looks good" | Evaluating business |
| "My feet hurt..." | Fatigue need |
| "Nothing here for me" | Unfulfilled goal |
| "Where's the bathroom?" | Bathroom need |
| "Great visit!" | Satisfied |
| "Worth the price!" | Price satisfaction |
| "Too expensive..." | Price too high |

### Thought Bubble Content (Post-MVP Icons)

| Icon | Meaning |
|------|---------|
| 👟 / 🛍️ | Shopping |
| 🍔 / 🍕 | Dining/Hunger |
| 🎮 / 🎬 | Entertainment |
| 💇 / 🏦 | Services |
| 😴 | Fatigue |
| 🚻 | Bathroom |
| 💰 | Price concern |
| ⭐ | Satisfaction |

## Visitor Animation Requirements

See [animations/visitor_animations.md](../animations/visitor_animations.md) for animation specifications.

## Reuse Opportunities

- **Single base mesh** for all visitors, differentiated by material color
- **Shared material** across all visitor meshes → 1 draw call
- **Thought bubble** is a single Label3D or sprite, reused across all visitors
- Post-MVP: shared skeleton for all visitor variations, swap clothing/hair as child meshes
