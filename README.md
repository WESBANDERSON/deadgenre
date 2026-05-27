# deadgenre

An AI-first MMO. Simple foundations, infinite potential.

**Inspiration**: Old School RuneScape · Albion Online · Farever  
**Engine**: Godot 4.3  
**Backend**: SpacetimeDB (Rust)  
**Visual style**: Programmatic 2D top-down, AI-generated sprite upgrades over time

---

## Philosophy

Traditional MMOs fail the business case because they require everything upfront. deadgenre inverts this:

1. **Simple but solid** — Every system works before it's expanded. No stubs that break.
2. **AI-native** — Code, schemas, and prompts are written for AI agents to read and extend.
3. **Asset generation pipeline** — Run `tools/asset_generator/generate.py` to kick off a batch of AI-generated sprites for any content category.
4. **SpacetimeDB backend** — Real-time, relational, scalable. Upgrade server capacity without changing application code.
5. **Lightweight by default** — The game runs with zero external assets on day one. Fidelity increases as assets are generated.

See [`docs/game-vision.md`](docs/game-vision.md) for the full design vision and tier-based expansion model.

---

## Repository Structure

```
deadgenre/
├── client/                 # Godot 4.3 game client
│   ├── project.godot
│   ├── scenes/             # Scene files (.tscn)
│   ├── scripts/
│   │   ├── autoload/       # Global singletons (GameManager, EventBus, NetworkManager)
│   │   ├── world/          # World, chunks, tilemap, pathfinding
│   │   ├── entities/       # Player, NPC, Mob base classes
│   │   ├── systems/        # Combat, Skills, Inventory, Crafting
│   │   ├── ui/             # HUD, panels, menus
│   │   └── network/        # SpacetimeDB adapter and message handlers
│   └── assets/
│       ├── sprites/        # Organized by category; hand-crafted assets
│       └── generated/      # AI-generated assets land here
│
├── server/                 # SpacetimeDB module (Rust)
│   ├── Cargo.toml
│   └── src/
│       └── lib.rs          # All tables and reducers
│
├── tools/
│   └── asset_generator/    # AI asset generation pipeline
│       ├── generate.py     # Entry point: python generate.py --category items --batch raid_weapons
│       ├── config.py       # Style profiles, API keys, output paths
│       ├── categories/     # Per-category generation logic and prompts
│       └── styles/         # Visual style definitions
│
└── docs/
    ├── ARCHITECTURE.md          # Full system architecture for AI agents
    ├── AI_GUIDE.md              # How to extend this codebase with AI
    ├── SYSTEMS.md               # Detailed system reference
    ├── game-vision.md           # Product vision and design pillars
    ├── technical-architecture.md # Infrastructure and stack decisions
    └── ai-content-pipeline.md  # AI content generation strategy
```

---

## Getting Started

### Prerequisites

- [Godot 4.3](https://godotengine.org/download)
- [Rust](https://rustup.rs/) + `cargo`
- [SpacetimeDB CLI](https://spacetimedb.com/install)
- Python 3.11+ (for asset generation)

### Run the client (offline mode)

```bash
# Open Godot and import client/project.godot
# The game runs in offline mode without a SpacetimeDB connection
```

### Run the server

```bash
cd server
spacetime publish deadgenre --clear-database
spacetime logs deadgenre
```

### Connect client to server

In `client/scripts/autoload/NetworkManager.gd`, set `SPACETIME_HOST` to your server URL and `DATABASE_NAME` to `"deadgenre"`. The client will auto-connect on start.

### Generate assets

```bash
cd tools/asset_generator
pip install -r requirements.txt
# Set OPENAI_API_KEY in your environment (or use Replicate for Stable Diffusion)
python generate.py --category items --batch "iron_sword,fire_staff,oak_bow" --style pixel_art_32
```

---

## Development Roadmap

The game is designed to grow in tiers. Current foundation:

| System | Status | Description |
|--------|--------|-------------|
| World rendering | ✅ | Procedural tile world, chunk streaming |
| Player movement | ✅ | Click-to-move with A* pathfinding |
| Network sync | ✅ | SpacetimeDB player state sync |
| Combat | ✅ | Basic melee combat with cooldowns |
| Skills | ✅ | XP framework (8 skills) |
| Inventory | ✅ | 28-slot server-mirrored inventory |
| AI assets | ✅ | Generation pipeline for any category |
| NPC dialogue | 🔜 | Dialogue trees, AI-generated lines |
| Crafting | 🔜 | Recipe-based crafting system |
| Guilds | 🔜 | Territory control, guild banks |
| Economy | 🔜 | Player-driven market |

---

## Core Schemas (MVP contracts)

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

Common fields on all schemas: `id` (immutable), `version`, `tags`, `author`, `status` (`draft` / `playtest` / `approved` / `deprecated`).

---

## SpacetimeDB World Model (MVP)

### Tables
`players` · `characters` · `inventories` · `equipment` · `zones` · `entities` · `combat_states` · `market_orders` · `craft_jobs` · `world_events`

### Reducers
`move_character` · `use_ability` · `apply_damage` · `loot_entity` · `equip_item` · `unequip_item` · `start_craft` · `complete_craft` · `post_market_order` · `resolve_market_trade` · `accept_quest` · `complete_quest_step`

Rule: reducers stay deterministic and schema-driven; clients send intents, server validates outcomes.

---

## Vertical Slice Scope

- 1 town hub
- 2 gathering zones
- 1 combat wilderness
- 1 mini dungeon / raid
- gathering, crafting, and combat baseline loops
- inventory / equipment progression
- basic social features (party / chat / friends)

Focus on feel first: movement responsiveness, combat readability, reward cadence.

---

## Progressive Fidelity Plan

Start with low-cost defaults and scale by profile: `low | medium | high | cinematic`

Upgrade vectors: LOD and shader quality · animation set quality · VFX/audio layers · environmental density

Gameplay logic and content IDs remain stable while presentation quality evolves.

---

## Milestones

### Milestone 0 — Foundation ✅
- Repository skeleton and documentation
- Client boots in offline mode
- Server module compiles and publishes
- AI asset generation pipeline

### Milestone 1 — Playable Loop
- Login / spawn
- Movement replication
- Baseline combat loop
- Inventory / equipment loop
- Gather → craft → equip chain

### Milestone 2 — Living World
- NPC services and dialogue
- Monster spawns + loot tables
- Quest chain
- Market board + trade settlement

### Milestone 3 — Content Pipeline
- Weapon content pipeline
- Validation gates in import / CI
- Approval and publish workflow
- Hotload for non-critical content

### Milestone 4 — First Group Challenge
- First raid prototype
- Party finder
- Telemetry dashboards
- Regular balance cadence

---

## Definition of Done (new systems)

A system is done only when it includes:

- schema + examples
- authoritative server coverage
- client UX implementation
- telemetry events
- unit / integration tests
- extension notes and approval boundaries

See [`AGENTS.md`](AGENTS.md) for AI contributor conventions.
