# Game Vision

## Elevator pitch

Build a shared-world online RPG that is intentionally small at first, but feels smooth, social, and alive from day one. It should launch with simple systems that are satisfying on their own, while every layer of code and content stays structured so future AI agents can expand it safely.

## Product thesis

Traditional MMOs often fail because they try to ship with too many expensive systems too early. This project takes the opposite path:

- begin with a dense world instead of a huge world
- begin with a few polished loops instead of many shallow loops
- use AI for leverage, not for unchecked content spam
- make architecture, tools, and asset pipelines easy to read and extend

The business justification improves if content production, balancing, and iteration become cheaper over time without lowering the quality bar.

## Pillars

### 1. Small world, high density

The first world should be compact enough that players routinely cross paths. MMO feeling comes from persistence, shared space, economy, and progression loops, not from raw square mileage.

### 2. Simple but smooth

Movement, combat response, gathering feedback, looting, and UI clarity matter more than raw feature count. If the game feels good with only a handful of systems, expansion becomes an investment instead of a rescue mission.

### 3. Stylized, scalable visuals

The game should look coherent at low production cost, with a path to higher fidelity later. Favor an art direction that makes simple assets feel deliberate:

- readable silhouettes
- limited palettes
- strong materials
- controlled post-processing
- modular props

### 4. AI-accelerated, human-directed content

AI should help produce volume and variants. Humans define taste, constraints, and acceptance thresholds.

### 5. Systems that grow in tiers

Each system needs an explicit expansion ladder:

- **Tier 0:** smallest version that is fun
- **Tier 1:** adds depth without changing structure
- **Tier 2:** adds breadth, specialization, and social complexity

## Initial genre shape

Recommended starting shape:

- online action-RPG with sandbox progression
- camera that favors readability over spectacle
- high social visibility in towns and hotspots
- economy and resource loops introduced early

This keeps the project closer to the strengths of OSRS and Albion than to a theme-park raid MMO with heavy cinematic overhead.

## Initial vertical slice

The first playable slice should include:

- one starter town
- one forest or field region
- one mine
- one ruins/dungeon pocket
- one local bank or storage system
- melee combat only
- wood, ore, and fiber gathering
- basic crafting for weapons and armor
- enemy camps with simple aggro and resets
- visible other players in the same shard
- persistent inventory and progression

## Core loops

### Moment-to-moment loop

Move -> spot opportunity -> act -> get feedback -> receive reward -> choose next action

### Medium loop

Gather -> refine -> craft -> equip -> fight stronger content -> unlock better routes

### Social loop

See players -> compare gear/progress -> cooperate or trade -> return to town -> repeat

## Anti-goals for the first phase

Do not start with:

- large seamless world streaming
- many classes or weapon families
- cinematic questing
- complex player housing
- fully simulated economy across many cities
- handcrafted asset volume that exceeds the systems underneath it

## System growth map

### Combat

- **Tier 0:** one weapon family, one basic attack, one dodge or spacing mechanic
- **Tier 1:** abilities, enemy telegraphs, gear modifiers
- **Tier 2:** builds, PvP flags, group roles, encounter mechanics

### Gathering

- **Tier 0:** node click/harvest with rarity and respawn timing
- **Tier 1:** tools, skill levels, contested nodes
- **Tier 2:** regional scarcity, caravans, guild control

### Crafting

- **Tier 0:** recipe + ingredients -> item
- **Tier 1:** quality tiers, specialization, salvage
- **Tier 2:** economy sinks, refiners, public orders

### World simulation

- **Tier 0:** static spawn tables and simple schedules
- **Tier 1:** event triggers and region state
- **Tier 2:** faction pressure, raids, seasonal content

### Social systems

- **Tier 0:** local presence, chat, inspect, trade
- **Tier 1:** parties, friends, shared goals
- **Tier 2:** guilds, territory, governance

## Visual direction

The visual target should be "clean stylized fantasy that tolerates low complexity gracefully." That means:

- low to medium polygon budgets
- hand-directed palettes
- strong normals/material breakup
- controlled lighting
- reusable environment kits
- selective hero assets where human polish matters most

### Perspective and Camera

The client renders the world in **2.5D**: a true 3D scene with billboard
sprites for characters and props, an orbit follow camera tilted ~55° down,
and a Dreadmyst-flavored fog/lighting WorldEnvironment. See
[ADR-002](adr/002-dreadmyst-2-5d-billboards.md) for the implementation and
the tier path that scales these billboards to low-poly 3D models without
breaking the server schema. [ADR-001](adr/001-2.5d-camera-and-wasd-movement.md)
captured the original intent.

### Movement

Primary movement is **WASD directional** (camera-relative) with `click-to-move`
preserved as a pointer-friendly fallback. Movement uses linear accel/decel
so it stays snappy without feeling robotic. **Tab** cycles to the nearest
hostile target; **Space / Enter** swings at it. Right-click is reserved for
context interactions (talk, gather, attack).

### Look and feel

Inspirations: **Dreadmyst** for atmosphere (moody dark-fantasy, cold palette
pierced by ember and witchfire accents) and **Megabonk** for momentum
(top-down readable, snappy controls, lots of enemies on screen). The
intentional limit at Tier 0 is single-frame billboards rendered in a Godot
Forward+ 3D scene — strong silhouettes, fog, and lighting do the heavy
lifting until production art lands.

## Business logic of the approach

This design reduces risk in three ways:

1. The first shippable state is much smaller than a traditional MMO.
2. AI lowers content and iteration cost where systems are already defined.
3. The architecture leaves room to scale successful loops rather than funding speculative ones.
