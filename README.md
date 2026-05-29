# deadgenre

An AI-first MMO. Simple foundations, infinite potential.

**Inspiration**: Old School RuneScape · Albion Online · Dreadmyst · Megabonk
**Engine**: Godot 4.3 (Forward+ 3D renderer, 2.5D billboards)
**Backend**: SpacetimeDB (Rust)
**Visual style**: 2.5D billboard sprites in a moody Dreadmyst-flavored 3D world. Procedural fallback art ships with the engine; AI-generated billboards drop in seamlessly via `tools/asset_generator`.

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
├── client/                 # Godot 4.3 game client (Forward+ 2.5D)
│   ├── project.godot
│   ├── scenes/             # Scene files (.tscn)
│   │   ├── Main3D.tscn     #   ← main scene (2.5D world + HUD + screens)
│   │   ├── world3d/        #   World3D scene + environment
│   │   └── entities3d/     #   Player3D / Mob3D / NPC3D / Prop3D
│   ├── scripts/
│   │   ├── autoload/       # Global singletons (GameManager, EventBus, NetworkManager)
│   │   ├── world3d/        # World3D, TerrainBuilder, OrbitCamera3D, SpriteFactory
│   │   ├── entities3d/     # Player3D, Entity3D, Mob3D, NPC3D, Prop3D
│   │   ├── world/          # Legacy 2D world (kept for fallback / reference)
│   │   ├── entities/       # Legacy 2D entities (kept for fallback / reference)
│   │   ├── systems/        # Combat, Skills, Inventory, TabTargeting
│   │   ├── ui/             # HUD, panels, menus (CanvasLayer; world-agnostic)
│   │   └── network/        # SpacetimeDB adapter and message handlers
│   └── assets/
│       ├── sprites/        # Organized by category; hand-crafted assets
│       └── generated/      # AI-generated assets land here (characters/, props/, tiles/, items/)
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

## Visual Style & Controls

The 2.5D client targets a **Dreadmyst-meets-Megabonk** look: moody dark
fantasy fog, ember-rim character silhouettes, snappy top-down readable
movement. See [ADR-002](docs/adr/002-dreadmyst-2-5d-billboards.md) for the
full design + tier ladder.

| Input             | Action                                       |
|-------------------|----------------------------------------------|
| `WASD`            | Move (camera-relative)                       |
| `Left click`      | Move / target / talk (context)               |
| `Right click`     | Interact (gather, attack, talk)              |
| `Tab`             | Cycle nearest hostile target                 |
| `Esc`             | Clear target                                 |
| `Space` / `Enter` | Attack current target                        |
| `F`               | Interact with closest entity                 |
| `Q` / `E`         | Rotate orbit camera                          |
| Mouse wheel       | Zoom                                         |
| `1`..`8`          | Hotbar slots                                 |
| `I` / `K` / `M`   | Inventory / Skills / Map panels              |

## Getting Started

### Prerequisites

- [Godot 4.3](https://godotengine.org/download)
- [Rust](https://rustup.rs/) + `cargo`
- [SpacetimeDB CLI](https://spacetimedb.com/install)
- Python 3.11+ (for asset generation)

### Run the client (offline mode)

```bash
# Open Godot and import client/project.godot
# The main scene is scenes/Main3D.tscn (2.5D Dreadmyst world).
# The game runs offline by default; flip NetworkManager.OFFLINE_MODE = false to connect.
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

# OpenAI DALL-E 3:
export OPENAI_API_KEY="sk-..."

# OR Stable Diffusion via Replicate:
export REPLICATE_API_TOKEN="r8_..."

# OR Midjourney / external tool: --provider manual writes prompts.txt and
# placeholder PNGs at the canonical paths; render in Midjourney and overwrite.
```

Starter batches that populate the 2.5D Dreadmyst world:

```bash
python generate.py --batch-file batches/dreadmyst_starter_characters.json
python generate.py --batch-file batches/dreadmyst_starter_props.json
python generate.py --batch-file batches/dreadmyst_starter_tiles.json

# Same flow, but log prompts for Midjourney instead of calling an API:
python generate.py --batch-file batches/dreadmyst_starter_characters.json --provider manual
```

Generated PNGs land at `client/assets/generated/<category>/<name>.png` and
are picked up automatically by `SpriteFactory.try_load_generated`. Until a
real image is dropped in, the client uses the in-engine procedural
Dreadmyst fallback so the game looks coherent on first run.

---

## Development Roadmap

The game is designed to grow in tiers. Current foundation:

| System | Status | Description |
|--------|--------|-------------|
| 2.5D world rendering | ✅ | Forward+ 3D scene, vertex-color terrain chunks, fog, moonlight (Dreadmyst style) |
| Billboard characters | ✅ | Sprite3D billboards with procedural Dreadmyst fallback art (replaceable via AI pipeline) |
| Orbit camera | ✅ | Top-down follow camera, Q/E yaw, mouse-wheel zoom |
| WASD movement | ✅ | Camera-relative, snappy accel/decel; click-to-move preserved as fallback |
| Tab targeting | ✅ | Cycle nearest hostile, ground-ring highlight, Esc clears |
| Player movement | ✅ | Click-to-move with A* pathfinding (bridged to 3D world) |
| Network sync | ✅ | SpacetimeDB player state sync |
| Combat | ✅ | Basic melee combat with cooldowns |
| Skills | ✅ | XP framework (8 skills) |
| Inventory | ✅ | 28-slot server-mirrored inventory with panel UI |
| Equipment | ✅ | Equip/unequip reducers, slot-based gear system |
| Crafting | ✅ | Recipe-based crafting with 6 starter recipes |
| Gathering | ✅ | Resource node interaction, XP, item drops |
| Death/Respawn | ✅ | Death screen, 10% resource drop, respawn flow |
| NPC Dialogue | ✅ | Data-driven dialogue trees with choices |
| Quests | ✅ | 3 starter quests, accept/progress/complete flow |
| Loot Tables | ✅ | Weighted random drops per mob type |
| Mob Respawn | ✅ | Timer-based 30s respawn system |
| Login Flow | ✅ | Character name entry, validation, game state |
| AI assets | ✅ | Generation pipeline for any category |
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

### Milestone 1 — Playable Loop 🔄
- Login / spawn
- Movement replication
- Baseline combat loop
- Inventory / equipment loop ✅ (equip_item, unequip_item, inventory panel)
- Gather → craft → equip chain ✅ (gathering interaction, crafting recipes + UI, equip flow)
- Death / respawn loop ✅ (player_died reducer, DeathScreen, resource drops)

### Milestone 2 — Living World 🔄
- NPC services and dialogue ✅ (data-driven dialogue trees)
- Monster spawns + loot tables ✅ (weighted drops, 30s respawn)
- Quest chain ✅ (3 starter quests with multi-step objectives)
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
