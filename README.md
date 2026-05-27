# Aetheria

An AI-native MMO built for progressive enhancement. Starts simple, scales infinitely.

**Inspired by**: Old School RuneScape, Albion Online, Farever

## Philosophy

Every system in Aetheria is designed to be read, understood, and extended by AI agents. The codebase is data-driven: game content lives in JSON files with formal schemas, the server logic is declarative tables + reducers, and the client resolves everything at runtime through lookups rather than hardcoded references.

The game parallels its own development: it starts with a simple, functional foundation and grows richer over time as humans and AI collaborate to add content, refine systems, and increase fidelity.

## Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| **Client** | Godot 4 (GDScript) | Open source, lightweight, text-based scene format (.tscn) that AI can read/write, strong 2D+3D support |
| **Server** | SpacetimeDB (Rust) | Real-time game database with WASM modules, handles multiplayer sync out of the box |
| **Content** | JSON + JSON Schema | Human and AI readable, validatable, versionable |
| **Tools** | Python | Asset generation pipeline, content validation, import scripts |

## Project Structure

```
aetheria/
├── client/                 # Godot 4 project
│   ├── project.godot       # Engine config + input mappings
│   ├── scenes/             # .tscn scene files
│   ├── scripts/
│   │   ├── autoload/       # Singletons: GameManager, EventBus, ContentDB, Config
│   │   ├── systems/        # Game systems: combat, inventory, skills, world
│   │   ├── entities/       # Player controller, camera, NPC entity
│   │   ├── ui/             # HUD, inventory panel, damage popups
│   │   └── utils/          # AssetResolver and helpers
│   ├── assets/             # Textures, models, audio + manifest.json
│   └── content -> ../content  # Symlink to shared content
├── server/                 # SpacetimeDB Rust module
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs          # Module entry, re-exports all systems
│       ├── player.rs       # Player table, movement, stats
│       ├── items.rs        # Item definitions table
│       ├── inventory.rs    # Player inventory + equipment
│       ├── combat.rs       # Tick-based combat state machine
│       ├── skills.rs       # Skill definitions + player progress
│       ├── world.rs        # World chunks + interactable objects
│       └── npc.rs          # NPC definitions + live instances
├── content/                # Data-driven game content
│   ├── schema/             # JSON Schemas for validation
│   ├── items/              # Item definitions
│   ├── skills/             # Skill definitions
│   ├── npcs/               # NPC archetype definitions
│   ├── world/              # World chunk definitions
│   └── quests/             # Quest definitions
├── tools/                  # Development tooling
│   ├── generators/         # Python: validation, import, AI generation
│   └── templates/          # Prompt templates for AI content generation
└── docs/                   # Architecture and AI agent documentation
```

## Quick Start

### Prerequisites

- [Godot 4.4+](https://godotengine.org/download)
- [Rust](https://rustup.rs/) (for the server module)
- [SpacetimeDB CLI](https://spacetimedb.com/install)
- Python 3.10+ (for tools)

### 1. Start the Server

```bash
cd server
spacetime build
spacetime start     # local dev server
spacetime publish aetheria
```

### 2. Import Content

```bash
python tools/generators/import_content.py --type all
```

### 3. Open the Client

Open `client/project.godot` in Godot 4 and press Play (F5).

### 4. Generate New Content

```bash
# Generate weapons for a volcanic dungeon
python tools/generators/generate_items.py \
  --prompt "5 fire-themed weapons for a volcanic dungeon" \
  --category weapon

# Validate all content
python tools/generators/content_validator.py
```

## For AI Agents

**Start here**: [`docs/ai-guide.md`](docs/ai-guide.md) — complete instructions for AI agents working on this project.

Key principles:
- All content is JSON with schemas — generate it, don't hardcode it
- The EventBus decouples systems — emit signals, don't create direct references
- Config singleton holds all tunable values — adjust them there
- AssetResolver handles the mapping between content keys and actual files
- Every server table has a corresponding `register_*` reducer for content import

## License

This project is source-available for now. License TBD.
