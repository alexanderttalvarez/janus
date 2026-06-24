# Project Janus - Game Concept

## Elevator Pitch

Design, build, and manage a vertical commercial district inspired by Japanese urban complexes. You are not a shopkeeper — you are an architect, developer, and urban planner shaping a living three-dimensional space where commerce, transit, and people intersect.

## Core Fantasy

The player fantasy is **creation through spatial design**. The satisfaction comes from looking at a complex you built — with its atriums catching light, its gardens breaking up concrete, its transit hubs pulsing with flow — and knowing every element serves a purpose you chose.

You do not micromanage tenants. You create the conditions for them to thrive.

The player returns to the game because they saw something beautiful in the real world — a mall in their hometown, a photo of a stunning complex, a memory of a great space — and want to recreate or reimagine it. The game gives them the tools and constraints to make that vision real.

## Design Pillars

### 1. Physical Representation
Every important system must have a physical presence in the complex. Transportation, utilities, staff, gardens, prestige features — all are built, placed, and visible. Nothing is an abstract menu toggle.

### 2. Spaces Over Stores
The player designs zones and spaces. The game populates them. The player's creative input is architectural: layout, flow, aesthetics, and function. The game handles the commercial details.

### 3. Creativity With Constraints
This is a creative game, not a puzzle game. The player builds because they want to see something beautiful. But creativity needs boundaries to be meaningful. The constraints — money, flow, verticality, synergy — exist to make good design feel earned, not to frustrate. The player should feel like an architect working within real-world limitations, not a player solving arbitrary game mechanics.

### 4. Discoverable Rules, Transparent UI
The game's systems have rules. Those rules are visible. The player can always see *why* something works or doesn't work. There are no hidden mechanics. The discovery comes from understanding how the rules interact in 3D space, not from guessing what the rules are.

### 5. Verticality Matters
This is not a flat city-builder. Going up and down is a core design challenge. Elevators, escalators, atriums, and sightlines across floors are meaningful decisions, not afterthoughts.

### 6. Expressive, Not Exhaustive
The game provides a focused set of tools that combine in interesting ways. It does not simulate every detail. It simulates the right details.

## Target Audience

- Players of city builders and tycoon games who want more architectural creativity
- Fans of games like *Cities: Skylines*, *Two Point Hospital*, *Dorfromantik*, *Mini Metro*, *Townscaper*
- Players who enjoy spatial design and optimization
- People who like looking at buildings and urban design
- Creative players who get inspired by real architecture and want to recreate it

## Reference Games

| Game | What We Take | What We Avoid |
|------|-------------|---------------|
| Cities: Skylines | Zoning philosophy, infrastructure focus | Micromanagement, traffic simulation complexity |
| Two Point Hospital | Room-based building, staff abstraction | Quirky tone (we aim for serene/professional) |
| Dorfromantik | Satisfying placement, spatial puzzle feel | Randomness-driven progression |
| Mini Metro | Abstract flow visualization, elegance | Extreme minimalism (we need more depth) |
| Project Highrise | Vertical building, tenant management | Individual tenant micromanagement |
| Townscaper | Satisfying building, visual feedback, creative joy | Lack of gameplay systems |
| Planet Coaster | Creative freedom, visual pride in building | Overwhelming tool complexity |

## Art Direction

- **Style**: Low-poly 3D with clean, modern aesthetics
- **Palette**: Warm neutrals with accent colors for zones and services
- **Lighting**: Soft, natural. Atriums and gardens should feel luminous
- **Camera**: Isometric, rotatable in 90° increments, zoomable from district overview to floor-level detail
- **Tone**: Serene, professional, aspirational. Think architectural visualization meets playful simulation

## Unique Selling Points

1. **Vertical district building** — not a single tower, not a flat grid. A multi-building, multi-level commercial ecosystem.
2. **Architecture as gameplay** — your design choices directly drive the simulation. Good design = good results.
3. **Abstract but meaningful visitor simulation** — heatmaps and flow data that reward smart layout without overwhelming the player.
4. **Physical systems** — everything you manage exists in the world. No hidden menus, no invisible stats.
5. **Creative inspiration loop** — the game is designed to make players want to build things they've seen and loved in the real world.

## UI Philosophy

The UI serves the creative fantasy. It provides information without cluttering the view.

### Visibility Rules

| Visibility | Content |
|------------|---------|
| **Always visible** (HUD bar) | Money, daily visitors, simulation speed |
| **Informational windows** (toggleable panels) | Full metrics, heatmap toggles, zone inspector, synergy grid, unlock progress, finance details |
| **Contextual** (appears near relevant elements) | Congestion indicators, viability warnings, construction costs |

### Design Principles

- The build view should feel clean. The world is the focus, not panels and numbers.
- Informational windows are toggled on demand. The player opens them when they need details, closes them when they want to build.
- The synergy grid lives in an informational window. It's a reference tool, not a permanent HUD element.
- Warnings appear contextually near the affected element (a zone with low viability shows a subtle indicator), not as global alerts.

## Scope Philosophy

Start small, think big. The MVP is one flat plot with basic zoning, abstract visitor flow, and a simple economy. Each subsequent layer adds one new dimension: verticality, multiple plots, transit options, prestige features, progression systems.

The game should feel complete at MVP and rich at full scope.

## Clarified Design Decisions

### Pacing & Time Control
Real-time simulation with pause and speed controls (Pause, 1x, 2x, 3x). Standard for the genre, allows players to observe at their own pace and manage during critical moments.

### Progression: Prestige & Mall Levels
**Prestige** is the core progression metric. It represents the district's reputation and desirability. Earning prestige advances the player through **Mall Levels** — tiered milestones with evocative names (e.g., "Local Shopping Building" → "Neighborhood Center" → "Regional Mall" → "Megacity Mall"). Each level unlocks nodes in a tech tree. Progression is hybrid: prestige drives level advancement, which gates tech unlocks, which enable new building capabilities.

### Failure States: The Death Spiral
No hard game over. Bad designs underperform. The failure loop is slow and visible: low visitor attraction → shops close from lack of customers → no new businesses want to move in → expenses (staff, maintenance) outpace revenue → debt grows → player can't afford improvements. The game warns the player when recovery is unlikely, but the choice to continue or restart is theirs.

### Scale
Multiple interconnected buildings across a neighborhood. Buildings are always adjacent, forming a cohesive district. Players design individual buildings and the connections between them (skybridges, shared plazas, underground passages).
