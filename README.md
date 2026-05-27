# deadgenre

MMO Starter Blueprint v1 for a scalable, systems-driven MMORPG.

This project is designed to:
- start with a small, polished vertical slice
- run lightweight infrastructure early
- expand content depth and visual fidelity without rewrites
- keep systems readable and maintainable as the team grows

---

## Vision

Build a shared-world RPG that feels smooth immediately, then scale scope through stable interfaces and data-driven systems.

### Design priorities
1. **Simple systems, deep interactions**
2. **Authoritative multiplayer simulation**
3. **Data-first content definitions**
4. **Progressive fidelity over time**
5. **Clear boundaries between client, server, and content pipelines**

---

## Recommended foundation

### Runtime
- **Client:** Godot 4.x
- **Authoritative state:** SpacetimeDB
- **Simulation/services:** Rust modules + helper services
- **Tooling:** Python and TypeScript for validation and internal pipelines

### Content and assets
- **Schema format:** JSON/JSON5 with strict schema validation
- **Asset format:** GLB/GLTF + PNG/WebP + OGG
- **Versioning:** Git + semantic content versions (for example: `weapon.v3`)

### Observability
- structured logs
- event metrics
- replay-friendly gameplay traces

---

## Project structure (starter)

```text
/
  README.md
  AGENTS.md
  docs/
    game-vision.md
    technical-architecture.md
    architecture.md
    adr/
      ADR-001-authoritative-server.md
      ADR-002-data-first-content.md
  game-client/
    project.godot
    scenes/
    scripts/
  game-server/
    spacetime/
      src/modules/
      schema/
    services/
      content-validator/
      content-importer/
      content-jobs/
  content/
    schemas/
    data/
    manifests/
  tools/
    policies/
```

---

## Core schemas (MVP contracts)

Target schema set:
1. `zone`
2. `npc`
3. `monster`
4. `ability`
5. `item`
6. `weapon`
7. `armor`
8. `recipe`
9. `loot-table`
10. `quest`

Common fields:
- `id` (immutable key)
- `version`
- `tags`
- `author` (`internal`)
- `status` (`draft`, `playtest`, `approved`, `deprecated`)

---

## SpacetimeDB world model (MVP)

### Core tables
- `players`
- `characters`
- `inventories`
- `equipment`
- `zones`
- `entities`
- `combat_states`
- `market_orders`
- `craft_jobs`
- `world_events`

### Core reducers
- `move_character`
- `use_ability`
- `apply_damage`
- `loot_entity`
- `equip_item`
- `unequip_item`
- `start_craft`
- `complete_craft`
- `post_market_order`
- `resolve_market_trade`
- `accept_quest`
- `complete_quest_step`

Rule: reducers stay deterministic and schema-driven; clients send intents, server validates outcomes.

---

## Vertical slice scope

- 1 town hub
- 2 gathering zones
- 1 combat wilderness
- 1 mini dungeon/raid
- gathering, crafting, and combat baseline loops
- inventory/equipment progression
- basic social features (party/chat/friends)

Focus on feel first: movement responsiveness, combat readability, and reward cadence.

---

## Progressive fidelity plan

Start with low-cost presentation defaults and scale by profile:

- `fidelity_profile = low | medium | high | cinematic`

Upgrade vectors:
- LOD and shader quality
- animation set quality
- VFX/audio layers
- environmental density

Gameplay logic and content IDs remain stable while presentation quality evolves.

---

## Milestones

### Milestone 0: Foundation
- repository skeleton
- schema validation CLI
- ADRs for key architectural decisions
- CI for formatting/lint/schema checks

### Milestone 1: Playable loop
- login/spawn
- movement replication
- baseline combat loop
- inventory/equipment loop
- gather -> craft -> equip chain

### Milestone 2: Living world
- NPC services
- monster spawns + loot
- quest chain
- market board + trade settlement

### Milestone 3: Content pipeline
- weapon content pipeline online
- validation gates in import/CI
- approval and publish workflow
- hotload for non-critical content paths

### Milestone 4: First group challenge
- first raid prototype
- party finder polish
- telemetry dashboards
- regular balance cadence

---

## Definition of done (new systems)

A system is done only when it includes:
- schema + examples
- authoritative server coverage
- client UX implementation
- telemetry events
- unit/integration tests
- extension notes and approval boundaries

