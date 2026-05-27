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

## Project structure

```text
/
  README.md
  AGENTS.md
  docs/
    game-vision.md
    technical-architecture.md
    ai-content-pipeline.md
    ARCHITECTURE.md
    ai-guide.md
    content-authoring.md
    systems/
      combat.md
      inventory.md
      world.md
  client/                         # Godot 4 project
    project.godot
    scenes/
      main.tscn
    scripts/
      autoload/                   # Singletons: GameManager, EventBus, ContentDB, Config
      systems/                    # Combat, inventory, skills, world
      entities/                   # Player controller, camera rig, NPC entity
      ui/                         # HUD, inventory panel, damage popups
      utils/                      # AssetResolver
    assets/
      manifest.json               # asset_key -> file path mapping
      textures/
      models/
      audio/
    content -> ../content         # Symlink to shared content
  server/                         # SpacetimeDB Rust module
    Cargo.toml
    src/
      lib.rs
      player.rs
      items.rs
      inventory.rs
      combat.rs
      skills.rs
      world.rs
      npc.rs
  content/
    schema/                       # JSON Schemas for validation
    items/
    skills/
    npcs/
    world/
    quests/
  tools/
    generators/
      content_validator.py
      import_content.py
      generate_items.py
    templates/
      item_generation.md
      npc_generation.md
      world_chunk_generation.md
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

Implemented schemas (in `content/schema/`):
- `item.schema.json` — weapons, armor, consumables, materials, tools, quest items
- `skill.schema.json` — skill definitions with XP curves
- `npc.schema.json` — NPC archetypes with loot tables
- `world_chunk.schema.json` — world grid chunks with spawn lists

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

### Implemented tables and reducers (in `server/src/`)

| Table | Key | Reducer(s) |
|-------|-----|-----------|
| `player` | Identity | `create_player`, `update_player_position`, `set_online_status` |
| `item_def` | item_id | `register_item` |
| `player_inventory` | auto_inc | `add_item_to_inventory` |
| `player_equipment` | auto_inc | `equip_item` |
| `combat_state` | auto_inc | `start_combat`, `combat_tick`, `flee_combat` |
| `combat_log` | auto_inc | (written by `combat_tick`) |
| `skill_def` | skill_id | `register_skill` |
| `player_skill` | auto_inc | `grant_skill_xp` |
| `world_chunk` | auto_inc | `register_chunk` |
| `world_object` | auto_inc | `place_world_object`, `interact_with_object` |
| `npc_def` | npc_id | `register_npc` |
| `npc_instance` | auto_inc | `spawn_npc`, `respawn_npc` |

---

## Quick start

### Prerequisites

- [Godot 4.4+](https://godotengine.org/download)
- [Rust](https://rustup.rs/)
- [SpacetimeDB CLI](https://spacetimedb.com/install)
- Python 3.10+

### Server

```bash
cd server
spacetime build
spacetime start
spacetime publish deadgenre
```

### Import content

```bash
python tools/generators/import_content.py --type all
```

### Client

Open `client/project.godot` in Godot 4 and press Play (F5). The client runs in local/offline mode by default.

### Generate new content

```bash
python tools/generators/generate_items.py \
  --prompt "5 fire-themed weapons for a volcanic dungeon" \
  --category weapon

python tools/generators/content_validator.py
```

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

## Core documents

- [Game vision](docs/game-vision.md)
- [Technical architecture](docs/technical-architecture.md)
- [AI content pipeline](docs/ai-content-pipeline.md)
- [AI contributor guide](AGENTS.md)
- [System architecture](docs/ARCHITECTURE.md)
- [AI agent guide](docs/ai-guide.md)
- [Content authoring](docs/content-authoring.md)

---

## Definition of done (new systems)

A system is done only when it includes:
- schema + examples
- authoritative server coverage
- client UX implementation
- telemetry events
- unit/integration tests
- extension notes and approval boundaries
