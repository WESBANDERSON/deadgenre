# Aethermoor

An AI-first MMO built on the principle that the codebase structure mirrors the gameplay: starts simple, feels good, and expands naturally as development evolves.

**Inspiration**: Old School RuneScape · Albion Online · Farever  
**Engine**: Godot 4.3  
**Backend**: SpacetimeDB (Rust)  
**Visual style**: Programmatic 2D top-down, AI-generated sprite upgrades over time

---

## Philosophy

Traditional MMOs fail the business case because they require everything upfront. Aethermoor inverts this:

1. **Simple but solid** — Every system works before it's expanded. No stubs that break.
2. **AI-native** — Code, schemas, and prompts are written for AI agents to read and extend.
3. **Asset generation pipeline** — Run `tools/asset_generator/generate.py` to kick off a batch of AI-generated sprites for any content category.
4. **SpacetimeDB backend** — Real-time, relational, scalable. Upgrade server capacity without changing application code.
5. **Lightweight by default** — The game runs with zero external assets on day one. Fidelity increases as assets are generated.

---

## Repository Structure

```
aethermoor/
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
    ├── ARCHITECTURE.md     # Full system architecture for AI agents
    ├── AI_GUIDE.md         # How to extend this codebase with AI
    └── SYSTEMS.md          # Detailed system reference
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
spacetime publish aethermoor --clear-database
spacetime logs aethermoor
```

### Connect client to server

In `client/scripts/autoload/NetworkManager.gd`, set `SPACETIME_HOST` to your server URL and `DATABASE_NAME` to `"aethermoor"`. The client will auto-connect on start.

### Generate assets

```bash
cd tools/asset_generator
pip install -r requirements.txt
# Set OPENAI_API_KEY in your environment (or use Replicate for Stable Diffusion)
python generate.py --category items --batch "iron_sword,fire_staff,oak_bow" --style pixel_art_32
```

---

## Development Roadmap

The game is designed to grow in layers. Current foundation:

| Layer | Status | Description |
|-------|--------|-------------|
| World rendering | ✅ | Procedural tile world, chunk streaming |
| Player movement | ✅ | Click-to-move with A* pathfinding |
| Network sync | ✅ | SpacetimeDB player state sync |
| Combat | ✅ | Basic melee combat with cooldowns |
| Skills | ✅ | Skill XP framework (8 skills) |
| Inventory | ✅ | Slot-based inventory system |
| AI assets | ✅ | Generation pipeline for any category |
| NPC dialogue | 🔜 | Dialogue trees with AI-generated lines |
| Crafting | 🔜 | Recipe-based crafting system |
| Guilds | 🔜 | Territory control, guild banks |
| Economy | 🔜 | Player-driven market |

See `docs/ARCHITECTURE.md` for how to extend each layer.
