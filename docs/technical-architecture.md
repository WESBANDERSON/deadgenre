# Technical Architecture

## Recommended stack

### Client

- **Engine:** Godot 4
- **Language:** GDScript first, C# only where a clear performance or ecosystem reason exists

Why:

- scene files and scripts are text-based and AI-friendly
- iteration is fast
- project weight stays low
- the visual baseline is good enough without forcing AAA asset expectations

### Authoritative multiplayer backend

- **Platform:** SpacetimeDB
- **Module language:** Rust

Why:

- server authority can stay explicit and centralized
- real-time subscriptions fit MMO-style shared state
- Rust gives strong boundaries around simulation and persistence logic

### Tools

- **Language:** TypeScript
- **Use cases:** content generation, validation, import/export, balancing tools, admin dashboards

This lets the game client stay focused while content workflows remain scriptable and easy to automate.

## Important SpacetimeDB note

SpacetimeDB currently has official client SDK support for TypeScript, Rust, C#, and Unreal/C++ workflows. Godot integration appears viable through a community SDK, but that path adds dependency risk compared to official Unity and Unreal support.

Recommendation:

- keep **Rust + SpacetimeDB** as the authoritative backend plan
- keep **Godot** as the preferred client if AI readability and lightweight iteration are top priorities
- isolate the networking layer behind a clear client adapter so the project can fall back to a custom transport or another supported client path if the Godot integration becomes a bottleneck

In other words: use SpacetimeDB, but do not let the first client become tightly coupled to one unofficial plugin.

## Architecture goals

1. **Readable by future AI**  
   Few hidden conventions, small modules, explicit boundaries.

2. **Data-first**  
   Content should live in structured text where possible.

3. **Authority on the server**  
   Clients predict presentation, but inventory, combat, progression, and economy stay authoritative.

4. **Replaceable seams**  
   Rendering, networking adapters, and tooling should be replaceable without rewriting core game rules.

## High-level system layout

```text
Godot client
  -> presentation
  -> input
  -> local feel systems
  -> network adapter

SpacetimeDB + Rust module
  -> persistence
  -> reducers / game actions
  -> combat rules
  -> inventory
  -> progression
  -> subscriptions

TypeScript tools
  -> content generation
  -> validation
  -> balancing reports
  -> admin/liveops utilities
```

## Suggested repository layout

```text
client/
  godot/
    project.godot
    scenes/
    scripts/
    assets/
    data_cache/

server/
  spacetimedb/
    module/
      src/
      tables/
      reducers/
      systems/

tools/
  content/
  balance/
  ops/

shared/
  schemas/
  design/
  prompts/

docs/
  adr/
  systems/
```

## Server-side domain model

Treat the backend as the source of truth for persistent and contested systems.

### Tables to define early

- players
- characters
- inventories
- items
- equipment
- resource_nodes
- npc_spawns
- world_objects
- combat_states
- regions
- encounters

### Reducers to define early

- move_intent
- interact_with_node
- attack_target
- loot_drop
- craft_recipe
- equip_item
- deposit_item
- withdraw_item

Reducers should stay narrow and explicit. Avoid giant "do everything" actions that are hard to reason about or validate.

## Client-side design

The client should be split into four concerns:

### 1. Feel layer

Handles:

- input buffering
- animation timing
- camera motion
- hit feedback
- UI response
- audio feedback

This is where smoothness comes from. Keep it separate from authoritative logic.

### 2. Simulation mirror

Maintains a local, read-only view of subscribed state:

- nearby entities
- resource nodes
- inventory
- active encounters

### 3. Prediction and reconciliation

Use only where necessary:

- movement
- simple action confirmation
- UI optimism

Do not overbuild client prediction before core feel is proven.

### 4. Content renderer

Maps data-defined content to visual/audio presentation.

Example:

- `item_definition.weapon_iron_sword` maps to icon, mesh, material set, swing profile, sound family

This makes content generation and reskinning much easier later.

## Data-driven content strategy

Every content system should separate:

- **definition data**: what something is
- **simulation rules**: how it behaves
- **presentation mapping**: how it looks and sounds

For example, a weapon should not be a one-off script. It should be:

- an item definition
- a combat profile
- a render profile
- optional generated art metadata

## MMO scaling strategy

Start with a narrow concurrency target and prove stability before widening scope.

### Phase 1

- one shard or very small number of shards
- compact world
- subscriptions scoped to nearby regions
- basic persistence and reconnect flows

### Phase 2

- split regions by interest areas
- add monitoring and automated load checks
- refine bandwidth-heavy updates
- introduce content patching and schema migrations

### Phase 3

- horizontal service decomposition only where pressure demands it
- dedicated liveops tools
- richer observability
- region-specific event orchestration

## Art and content infrastructure

The engine baseline should look coherent even with simple assets. Do that with:

- constrained palette
- reusable environment kits
- standard material library
- common rig rules
- post-process profile
- strict naming and import conventions

If the baseline is good, generated assets can fit the world more easily.

## Decision records

Use ADRs for major choices:

- why Godot instead of Unity or Unreal
- why Rust for authority
- where simulation boundaries live
- when to add C# or native extensions
- when to upgrade fidelity

If a future AI changes architecture, it should update the relevant ADR before or alongside the code.
