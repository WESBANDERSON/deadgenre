# AI Agent Guide for Aetheria

This document is the primary reference for AI agents working on the Aetheria codebase. It explains the architecture, conventions, and workflows you need to follow.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [How to Add Content](#how-to-add-content)
3. [How to Modify Game Systems](#how-to-modify-game-systems)
4. [How to Add New Systems](#how-to-add-new-systems)
5. [Server Development](#server-development)
6. [Client Development](#client-development)
7. [Asset Pipeline](#asset-pipeline)
8. [Testing](#testing)
9. [Common Tasks](#common-tasks)

---

## Architecture Overview

Aetheria uses a **data-driven, event-driven architecture** across three layers:

```
┌─────────────────────────────────────────────────┐
│                  CONTENT LAYER                   │
│  JSON definitions: items, NPCs, skills, world   │
│  Schema-validated, AI-generatable               │
├─────────────────────────────────────────────────┤
│              SERVER (SpacetimeDB)                 │
│  Rust WASM module: tables + reducers             │
│  Authoritative game state                        │
├─────────────────────────────────────────────────┤
│              CLIENT (Godot 4)                    │
│  GDScript: systems, entities, UI                 │
│  Renders state, handles input                    │
└─────────────────────────────────────────────────┘
```

### Key Principles

1. **Content is data, not code.** Items, NPCs, skills, quests, and world layout are JSON files in `content/`. To add a new sword, create a JSON entry — don't write GDScript or Rust.

2. **The EventBus decouples everything.** Systems communicate through `EventBus` signals. If you need system A to react to system B, emit a signal from B and connect to it in A. Never create direct cross-references between systems.

3. **Config centralizes tuning.** All magic numbers (move speed, combat tick rate, camera angle, etc.) live in `scripts/autoload/config.gd`. Adjust them there.

4. **ContentDB is the client's truth.** The client resolves item/NPC/skill data through `ContentDB`, which loads from JSON at startup. The server has matching tables, but the client cache enables offline rendering and fast lookups.

5. **AssetResolver handles indirection.** Content definitions reference assets by key (e.g. `"weapons/bronze_sword"`). The resolver maps these to actual file paths via `assets/manifest.json` or convention-based lookup. This means you can add assets without changing content definitions.

---

## How to Add Content

### Adding Items

1. Create a JSON file in `content/items/` (or add to an existing one).
2. Follow `content/schema/item.schema.json`.
3. Each item needs a unique `id` (lowercase_snake_case).
4. Run validation: `python tools/generators/content_validator.py --type items`
5. Import to server: `python tools/generators/import_content.py --type items`

**Example — adding a new weapon:**

```json
{
  "id": "mithril_scimitar",
  "display_name": "Mithril Scimitar",
  "description": "Light as air, sharp as spite.",
  "category": "weapon",
  "subcategory": "sword",
  "asset_key": "weapons/mithril_scimitar",
  "rarity": 2,
  "max_stack": 1,
  "level_requirement": 30,
  "is_tradeable": true,
  "stats": { "attack": 35, "defense": 0, "speed": 2, "hp": 0 },
  "equip_slot": "main_hand",
  "base_value": 1200
}
```

### Adding NPCs

1. Define the archetype in `content/npcs/`.
2. Follow `content/schema/npc.schema.json`.
3. Reference existing items in the loot table.
4. Spawn instances via world chunk definitions or the `spawn_npc` reducer.

### Adding Skills

1. Add to `content/skills/`.
2. Follow `content/schema/skill.schema.json`.
3. Register on server: `register_skill` reducer.
4. The client's `SkillSystem` picks it up automatically from ContentDB.

### Adding World Areas

1. Add chunks to `content/world/`.
2. Follow `content/schema/world_chunk.schema.json`.
3. Reference existing NPCs/objects in spawn lists.
4. The `WorldSystem` client-side loads chunks based on player proximity.

### Adding Quests

1. Create in `content/quests/`.
2. No formal schema yet — follow the pattern in `tutorial_quest.json`.
3. Quest system is a stub — implement step tracking when needed.

---

## How to Modify Game Systems

### Combat System

- **Server**: `server/src/combat.rs` — tick resolution, damage formula, death/victory
- **Client**: `client/scripts/systems/combat_system.gd` — tick timer, visual feedback
- **Config**: `combat_tick_interval` in `config.gd`

To change the damage formula, edit `combat_tick()` in `combat.rs`. The formula is:
```
damage = max(1, attacker_stat - defender_stat / 2)
```

### Inventory System

- **Server**: `server/src/inventory.rs` — authoritative state, stacking, equip logic
- **Client**: `client/scripts/systems/inventory_system.gd` — local mirror, UI state
- **Constant**: `MAX_SLOTS = 28` in `inventory_system.gd`

### Skill System

- **Server**: `server/src/skills.rs` — XP granting, level computation
- **Client**: `client/scripts/systems/skill_system.gd` — mirrors server, local XP calc
- **XP curve**: `xp_for_level = base_xp * level^2` (same formula on both sides)

---

## How to Add New Systems

1. **Server side**: Create `server/src/new_system.rs` with `#[spacetimedb::table]` and `#[spacetimedb::reducer]` definitions. Add `mod new_system; pub use new_system::*;` to `server/src/lib.rs`.

2. **Client side**: Create `client/scripts/systems/new_system.gd`. Extend `Node`. Add it to the `Systems` node in `scenes/main.tscn`.

3. **Events**: Add signals to `EventBus` for inter-system communication.

4. **Content**: If the system is data-driven, create a JSON schema in `content/schema/` and a content directory.

5. **Config**: Add tunable values to `config.gd`.

---

## Server Development

### File Map

| File | Purpose |
|------|---------|
| `src/lib.rs` | Module entry point, re-exports all systems |
| `src/player.rs` | Player table: identity, position, stats, online status |
| `src/items.rs` | Item definition table (data-driven, populated via reducer or import) |
| `src/inventory.rs` | Per-player inventory slots + equipment |
| `src/combat.rs` | Combat state machine: start/tick/flee, damage calculation |
| `src/skills.rs` | Skill definitions + per-player skill progress |
| `src/world.rs` | World chunks + interactable objects |
| `src/npc.rs` | NPC archetypes + live instances |

### Adding a Table

```rust
#[spacetimedb::table(name = my_table, public)]
pub struct MyTable {
    #[primary_key]
    pub id: String,
    pub data: String,
}
```

### Adding a Reducer

```rust
#[spacetimedb::reducer]
pub fn my_reducer(ctx: &ReducerContext, arg: String) {
    // ctx.db.my_table() gives typed access
    // ctx.sender is the caller's Identity
}
```

### Build & Deploy

```bash
cd server
spacetime build                    # compile to WASM
spacetime publish aetheria         # deploy to running instance
```

---

## Client Development

### Autoload Singletons

| Singleton | Purpose |
|-----------|---------|
| `GameManager` | Game state machine (LOADING, MENU, CONNECTING, PLAYING), local player reference |
| `EventBus` | Global signals for decoupled inter-system communication |
| `ContentDB` | Loads and caches JSON content definitions at startup |
| `Config` | All tunable constants (speeds, distances, intervals, etc.) |

### Scene Tree (main.tscn)

```
Main (Node3D)
├── Systems (Node)
│   ├── CombatSystem
│   ├── InventorySystem
│   ├── SkillSystem
│   └── WorldSystem
├── WorldEnvironment
├── DirectionalLight3D
├── Player (CharacterBody3D)
│   ├── Model (Node3D)
│   │   └── MeshInstance3D (capsule placeholder)
│   └── CollisionShape3D
├── CameraPivot (Node3D)
│   └── Camera3D
└── HUD (CanvasLayer)
    ├── TopBar (health, XP, level)
    ├── NotificationContainer
    ├── InventoryPanel
    └── SkillsPanel
```

### Adding UI

1. Create a new `.gd` script in `client/scripts/ui/`.
2. Add the UI node to the HUD in `main.tscn`.
3. Connect to EventBus signals for data.

### Input Actions

| Action | Key | Usage |
|--------|-----|-------|
| `move_forward/backward/left/right` | WASD | Player movement |
| `click_action` | Left Mouse | Click-to-move, interact |
| `camera_rotate` | Middle Mouse | Orbit camera |
| `camera_zoom_in/out` | Scroll | Zoom |
| `interact` | E | Context interaction |
| `toggle_inventory` | I | Open/close inventory |
| `toggle_skills` | K | Open/close skills |
| `escape` | Escape | Pause/menu |

---

## Asset Pipeline

### How Assets are Resolved

1. Content definitions reference assets by `asset_key` (e.g. `"weapons/bronze_sword"`).
2. `AssetResolver` checks `assets/manifest.json` first.
3. Falls back to convention: `assets/textures/{key}.png` or `assets/models/{key}.glb`.
4. If nothing found, returns a placeholder.

### Adding Assets

1. Place the file in the appropriate `client/assets/` subdirectory.
2. Update `client/assets/manifest.json` with the key-to-path mapping.
3. The content definition's `asset_key` should match the manifest key.

### AI-Generated Assets

Use the generation scripts in `tools/generators/`:
- `generate_items.py` — creates item JSON definitions (with LLM integration point)
- Templates in `tools/templates/` — prompt engineering for each content type

To generate visual assets (textures, models), use an external AI tool and place outputs in `client/assets/`, then update the manifest.

---

## Testing

### Content Validation

```bash
python tools/generators/content_validator.py           # all types
python tools/generators/content_validator.py --type items  # specific type
```

### Server

```bash
cd server
spacetime build  # ensures it compiles
```

### Client

Open in Godot 4, press F5. The client runs in local/offline mode by default (no server needed for basic testing).

---

## Common Tasks

### "I want to add a new raid with 10 bosses and unique loot"

1. Create boss NPCs in `content/npcs/raid_name_bosses.json`
2. Create loot items in `content/items/raid_name_loot.json`
3. Create the dungeon chunks in `content/world/raid_name_dungeon.json`
4. Validate: `python tools/generators/content_validator.py`
5. Import: `python tools/generators/import_content.py --type all`

### "I want to add a new skill"

1. Add skill definition to `content/skills/`
2. Register on server: `register_skill` reducer
3. (Optional) Create skill-specific server logic in a new `.rs` file
4. (Optional) Create client UI for the skill

### "I want to change how combat feels"

1. Adjust `combat_tick_interval` in `config.gd`
2. Modify the damage formula in `server/src/combat.rs`
3. Tune visual feedback in `client/scripts/systems/combat_system.gd`

### "I want to expand the world"

1. Add chunk definitions to `content/world/`
2. Reference existing NPCs/objects or create new ones first
3. The `WorldSystem` auto-loads chunks near the player

### "I want to generate assets with AI"

1. Use `tools/generators/generate_items.py` with a descriptive `--prompt`
2. For visual assets, use the prompt templates in `tools/templates/` with your preferred image/model AI
3. Place generated files in `client/assets/`, update `manifest.json`
