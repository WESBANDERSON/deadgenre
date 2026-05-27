# Aethermoor Architecture

This document is the primary reference for AI agents and developers extending this codebase. Every major system is described here with its responsibilities, data flow, and extension points.

---

## Guiding Principles

1. **One source of truth per concern** — Server owns authoritative state. Client owns visual presentation.
2. **Events over polling** — All cross-system communication goes through `EventBus`. No direct references between systems.
3. **Tables as contracts** — SpacetimeDB table schemas define the game's data contracts. Change them carefully.
4. **Graceful degradation** — Systems check for optional dependencies; the game runs with missing subsystems in offline/dev mode.
5. **Comment the why, not the what** — Code explains intent. Variable names explain what.

---

## System Map

```
┌──────────────────────────────────────────────────────────────┐
│  CLIENT (Godot 4)                                            │
│                                                              │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ GameManager │  │  EventBus    │  │ NetworkManager   │   │
│  │ (state)     │  │  (signals)   │  │ (SpacetimeDB)    │   │
│  └──────┬──────┘  └──────┬───────┘  └────────┬─────────┘   │
│         │                │                    │              │
│  ┌──────▼──────────────────────────────────────▼──────────┐ │
│  │                    World (Node2D)                       │ │
│  │  ┌───────────┐  ┌──────────────┐  ┌────────────────┐  │ │
│  │  │ TileMap   │  │EntityContainer│  │ Camera2D       │  │ │
│  │  │TileRegistry│  │  Player(s)   │  │ (follows local)│  │ │
│  │  │ Pathfinder │  │  NPCs/Mobs   │  └────────────────┘  │ │
│  │  └───────────┘  └──────────────┘                       │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Systems (autoloaded or owned by World)              │   │
│  │  CombatSystem · SkillSystem · InventorySystem        │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  HUD (CanvasLayer)                                   │   │
│  │  HealthBar · ManaBar · Hotbar · Minimap · Chat       │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
                         │ WebSocket
┌──────────────────────────────────────────────────────────────┐
│  SERVER (SpacetimeDB / Rust)                                 │
│                                                              │
│  Tables:  player · player_skills · entity · item_definition  │
│           player_inventory · world_chunk · combat_event      │
│                                                              │
│  Reducers: create_player · move_player · attack_entity       │
│            pick_up_item · request_chunk · use_skill          │
└──────────────────────────────────────────────────────────────┘
```

---

## Client Systems

### GameManager (`scripts/autoload/GameManager.gd`)

**Role**: Central game state registry. Not a god object — it holds references but does not process logic.

```
GameManager
  .local_player         → Node reference to the local player entity
  .game_state           → Enum: LOADING, CONNECTED, PLAYING, DEAD
  .session_id           → SpacetimeDB identity (set on connect)
```

**Extension**: Add new global state here. Keep processing logic in the owning system.

---

### EventBus (`scripts/autoload/EventBus.gd`)

**Role**: Typed signal hub. All cross-system communication passes through here.

Adding a new event:
1. Declare the signal in `EventBus.gd`
2. Emit it from the source system
3. Connect to it in any subscriber's `_ready()`

Never connect nodes directly to other nodes across different scene trees — use EventBus.

---

### NetworkManager (`scripts/autoload/NetworkManager.gd`)

**Role**: Manages the SpacetimeDB WebSocket connection and all subscription callbacks.

SpacetimeDB pushes table changes to subscribed clients automatically. The NetworkManager:
- Subscribes to all relevant tables on connect
- Converts SpacetimeDB row events into `EventBus` signals
- Queues reducers (server-side function calls)

**Extension**: To sync a new server table to the client:
1. Add a subscription query in `_subscribe()`
2. Add an `on_row_insert/update/delete` handler
3. Emit the appropriate EventBus signal

---

### World (`scripts/world/World.gd`)

**Role**: Manages terrain rendering, chunk streaming, and entity spawning.

Chunk lifecycle:
```
Player moves → _update_loaded_chunks() → NetworkManager.request_chunk()
  → Server generates or returns chunk → on_chunk_received()
  → Tiles written to TileMap
```

**Extension**:
- New tile types: add to `TileRegistry.TILE_TYPES`
- New entity types: add a factory in `_spawn_entity()`
- World events (day/night, weather): add to `_process()`

---

### TileRegistry (`scripts/world/TileRegistry.gd`)

**Role**: Single definition of all tile types. Builds the TileSet programmatically so the game works without external texture files. When real sprites are ready, swap `color` for `sprite_path`.

Tile definition structure:
```gdscript
{
    "id": int,           # Must match server TileType enum
    "name": String,
    "color": Color,      # Placeholder; replaced when sprite_path is set
    "sprite_path": String,  # "" = use color placeholder
    "walkable": bool,
    "swim": bool,        # True for water/swamp tiles
    "movement_cost": float  # Pathfinding weight (1.0 = normal, 2.0 = slow)
}
```

---

### Pathfinder (`scripts/world/Pathfinder.gd`)

**Role**: A* tile-grid pathfinding using Godot's `AStarGrid2D`. Updated incrementally as chunks are loaded.

```gdscript
# Request a path in world-space coordinates
var path: Array[Vector2] = Pathfinder.find_path(from_world, to_world)
```

**Extension**: To add movement modifiers (mounts, swim), override `movement_cost` in the tile definition and update `AStarGrid2D.set_point_weight_scale()`.

---

### Player (`scripts/entities/Player.gd`)

**Role**: Handles both local player input and remote player visual sync.

`is_local_player = true` → processes input, runs pathfinding, syncs to server  
`is_local_player = false` → receives server state, interpolates position

Click-to-move flow:
```
MouseButton LEFT → get_global_mouse_position() → Pathfinder.find_path()
  → store path array → _physics_process() walks waypoints → NetworkManager.move_player()
```

**Extension**:
- New input actions: handle in `_input()`
- Abilities/spells: add to `_handle_hotbar_input()`
- Visual upgrades: replace `_draw()` with AnimatedSprite2D when sprites are ready

---

### Entity (`scripts/entities/Entity.gd`)

**Role**: Base class for all world objects (NPC, Mob, ItemDrop). Provides:
- Server ID tracking
- Health/state display
- Click interaction dispatch

Extend for specific entity types:
```gdscript
class_name Goblin
extends Entity

func _on_interact() -> void:
    CombatSystem.initiate_combat(GameManager.local_player, self)
```

---

### CombatSystem (`scripts/systems/CombatSystem.gd`)

**Role**: Client-side combat orchestration. Validates range/cooldown, then calls server reducer.

Server is authoritative on damage. Client shows optimistic feedback (hit animations, damage numbers) but corrects to server health values on next sync.

```
Player clicks mob → CombatSystem.request_attack(mob)
  → validate range & cooldown → NetworkManager.attack_entity(id)
  → Server computes damage → Player/Mob tables updated
  → NetworkManager subscription fires → EventBus.entity_health_changed
  → HUD and mob health bar update
```

---

### SkillSystem (`scripts/systems/SkillSystem.gd`)

**Role**: Manages the 8-skill XP framework. Skills: `melee, ranged, magic, defense, health, crafting, gathering`.

Level = floor(1 + sqrt(XP / 50))  — keeps early levels fast, late levels meaningful.

XP is granted server-side in reducers and synced via `player_skills` table subscription.

---

## Server (SpacetimeDB / Rust)

### Table Reference

| Table | Primary Key | Description |
|-------|-------------|-------------|
| `player` | `identity` | Core player state, position, stats |
| `player_skills` | `id` | Per-skill XP for each player |
| `entity` | `id` | NPCs, mobs, item drops |
| `item_definition` | `id` | Static item catalog |
| `player_inventory` | `id` | Player inventory slots |
| `world_chunk` | `id` | Terrain tile data per chunk |
| `combat_event` | `id` | Recent combat events (TTL-cleared) |

### Reducer Reference

| Reducer | Parameters | Description |
|---------|-----------|-------------|
| `create_player` | `username: String` | Register new player |
| `move_player` | `x: f32, y: f32` | Update authoritative position |
| `attack_entity` | `entity_id: u64` | Deal damage to entity |
| `pick_up_item` | `entity_id: u64` | Add item drop to inventory |
| `request_chunk` | `chunk_x: i32, chunk_y: i32` | Generate/return chunk data |
| `use_skill` | `skill: String, target_id: u64` | Trigger skill-based actions |

### Adding a New Reducer

```rust
#[spacetimedb::reducer]
pub fn my_action(ctx: &ReducerContext, param: Type) -> Result<(), String> {
    let player = ctx.db.player().identity().find(&ctx.sender)
        .ok_or("Player not found")?;
    // validate, compute, update tables
    Ok(())
}
```

---

## Asset Generation Pipeline

See `tools/asset_generator/README.md` and `docs/AI_GUIDE.md` for the full guide.

Quick reference:
```bash
# Generate a batch of items
python generate.py --category items --batch "iron_sword,flame_staff" --style pixel_art_32

# Generate world tiles for a new biome
python generate.py --category tiles --batch "lava_floor,obsidian_wall" --style pixel_art_32 --biome "volcanic"

# Generate a character variant
python generate.py --category characters --batch "goblin_shaman" --style pixel_art_32
```

Generated assets are placed in `client/assets/generated/`. A manifest (`manifest.json`) tracks all generated assets with their prompts and metadata for reproducibility.

---

## Adding a New Game System

1. **Create the GDScript class** in `scripts/systems/YourSystem.gd`
2. **Add relevant signals to EventBus** for cross-system communication
3. **Add server tables + reducers** in `server/src/lib.rs` if server state is needed
4. **Subscribe in NetworkManager** to sync server table changes to the client
5. **Wire to HUD** if the system needs UI representation
6. **Document here** in ARCHITECTURE.md
