# Aetheria Architecture

## Design Principles

### 1. Data-Driven Everything

Every piece of game content — items, NPCs, skills, quests, world layout — is defined in JSON files with formal JSON Schemas. This means:

- AI agents can generate valid content by following schemas
- Content can be validated programmatically before deployment
- No code changes are needed to add new items, NPCs, or world areas
- Version control captures all content changes as readable diffs

### 2. Progressive Enhancement

The architecture mirrors the game's own design ethos: start simple, scale up. Each system is a self-contained module with a minimal working implementation that can be enhanced independently. Example progression paths:

| System | V1 (Current) | V2 | V3 |
|--------|-------------|-----|-----|
| **Combat** | Simple tick-based, PvE only | Add PvP, abilities, status effects | Skill-based combat, combo system |
| **World** | Flat chunk grid, color-coded | Height maps, biome blending | Full 3D terrain, weather |
| **Assets** | Colored primitives | AI-generated 2D sprites/icons | Hand-crafted or AI-refined 3D models |
| **Inventory** | 28-slot grid | Drag-drop, item tooltips | Banking, trading, crafting interface |
| **NPCs** | Static spawns, basic AI | Patrol paths, aggro ranges | Dynamic behavior trees, dialogue trees |

### 3. Event-Driven Communication

Systems never reference each other directly. All inter-system communication goes through the `EventBus` singleton, which is a central node with typed signals. This ensures:

- Systems can be added, removed, or replaced independently
- Testing a system in isolation is trivial
- AI agents can trace data flow by reading EventBus signal definitions

### 4. Server Authority

SpacetimeDB is the single source of truth for all game state. The client maintains read-only caches (ContentDB, local inventory mirror) for performance, but all mutations go through server reducers. This architecture:

- Prevents cheating by design
- Enables seamless multiplayer
- Allows the server to be enhanced independently of the client

---

## Data Flow

### Player Action Flow

```
Player Input (Godot)
    → PlayerController handles movement/interaction
    → Calls SpacetimeDB reducer (e.g. update_player_position)
    → SpacetimeDB validates and updates table
    → Subscription pushes update to all nearby clients
    → Client updates visual state
```

### Content Resolution Flow

```
JSON content file (content/items/starter_weapons.json)
    → Loaded by ContentDB at client startup
    → Referenced by asset_key in content definition
    → AssetResolver maps key → file path via manifest.json
    → Godot loads and displays the resource
```

### Combat Tick Flow

```
CombatSystem._process() counts down tick timer
    → On tick: calls combat_tick reducer on SpacetimeDB
    → Server computes damage, updates CombatState table
    → Client receives subscription update
    → Emits EventBus.combat_tick signal
    → HUD shows damage popup
    → If HP <= 0: EventBus.combat_ended signal
```

---

## Server Tables (SpacetimeDB)

| Table | Primary Key | Purpose |
|-------|------------|---------|
| `player` | `identity` | Player state: position, stats, online status |
| `item_def` | `item_id` (String) | Static item definitions |
| `player_inventory` | `row_id` (auto_inc) | Per-player inventory slots |
| `player_equipment` | `row_id` (auto_inc) | Per-player equipped items |
| `combat_state` | `combat_id` (auto_inc) | Active combat encounters |
| `combat_log` | `log_id` (auto_inc) | Per-tick combat history |
| `skill_def` | `skill_id` (String) | Static skill definitions |
| `player_skill` | `row_id` (auto_inc) | Per-player skill progress |
| `world_chunk` | `chunk_id` (auto_inc) | World grid chunks |
| `world_object` | `object_id` (auto_inc) | Interactable objects in chunks |
| `npc_def` | `npc_id` (String) | NPC archetype definitions |
| `npc_instance` | `instance_id` (auto_inc) | Live NPC instances in-world |

---

## Client Singleton Responsibilities

| Singleton | File | Responsibilities |
|-----------|------|-----------------|
| `GameManager` | `autoload/game_manager.gd` | State machine, scene transitions, local player reference, pause |
| `EventBus` | `autoload/event_bus.gd` | Typed signals for all inter-system communication |
| `ContentDB` | `autoload/content_db.gd` | Loads JSON content at startup, provides lookup API |
| `Config` | `autoload/config.gd` | All tunable constants, persists overrides to user://config.json |

---

## File Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Content JSON | `snake_case.json` | `starter_weapons.json` |
| Content IDs | `snake_case` | `bronze_sword` |
| GDScript | `snake_case.gd` | `player_controller.gd` |
| Scenes | `snake_case.tscn` | `main.tscn` |
| Rust modules | `snake_case.rs` | `combat.rs` |
| Asset keys | `category/id` | `weapons/bronze_sword` |
| Asset files | `snake_case.ext` | `bronze_sword.png` |

---

## Extension Points

These are the places where new features connect to the existing architecture:

1. **New content type**: Create schema in `content/schema/`, directory in `content/`, add table + reducer in server, add loader in ContentDB
2. **New game system**: Create `.gd` in `client/scripts/systems/`, add to Systems node in main.tscn, add EventBus signals
3. **New UI panel**: Create `.gd` in `client/scripts/ui/`, add to HUD in main.tscn, connect to EventBus
4. **New server logic**: Create `.rs` in `server/src/`, add mod/pub use in lib.rs
5. **New asset type**: Update AssetResolver conventions, add to manifest.json
