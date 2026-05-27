# AI Guide — Extending Aethermoor

This guide is written for AI agents (and the humans prompting them) who want to add features, generate content, or refactor systems in this codebase. Every section tells you exactly what to touch and in what order.

---

## How to Read This Codebase

1. Start with `docs/ARCHITECTURE.md` for system-level understanding.
2. Read `server/src/lib.rs` to understand the game's authoritative data model.
3. Read `client/scripts/autoload/EventBus.gd` to understand cross-system communication.
4. Find the system you want to extend and read it top to bottom — files are structured with constants, then state, then public API, then private implementation.

### Naming Conventions

| Pattern | Meaning |
|---------|---------|
| `_on_*` | Signal handler (called by EventBus or node signal) |
| `_setup_*` | Initialization helper (called once in `_ready`) |
| `_update_*` | State mutation (called per frame or per event) |
| `request_*` | Sends a message to the server (non-blocking) |
| `get_*` | Pure getter, no side effects |
| `UPPER_SNAKE` | Constant or enum value |
| `snake_case` | Variable or function |
| `PascalCase` | Class name |

---

## Common Tasks

### Add a New Item Type

1. **Server** (`server/src/lib.rs`): Add a row to `item_definition` in the `init` reducer.
   ```rust
   seed_item(ctx, ItemDefinition {
       id: 101,
       name: "Iron Sword".to_string(),
       description: "A sturdy iron blade.".to_string(),
       item_type: "weapon".to_string(),
       subtype: "melee_1h".to_string(),
       stats_json: r#"{"attack":10,"speed":2.0}"#.to_string(),
       stackable: false,
       max_stack: 1,
   });
   ```

2. **Asset generation**: Run the generator to create the sprite.
   ```bash
   python tools/asset_generator/generate.py --category items --batch "iron_sword" --style pixel_art_32
   ```
   This creates `client/assets/generated/items/iron_sword.png` and updates `manifest.json`.

3. **Register in client** (`client/scripts/systems/InventorySystem.gd`): The system auto-reads `item_definition` from the server subscription — no code change needed for basic items.

---

### Add a New Mob

1. **Server**: Insert an `entity` row via a world-population reducer.
2. **Client**: Create `client/scripts/entities/mobs/YourMob.gd` extending `Entity`:
   ```gdscript
   class_name YourMob
   extends Entity
   
   func _on_interact() -> void:
       CombatSystem.initiate_combat(GameManager.local_player, self)
   
   func _setup_visual() -> void:
       # use generated sprite or draw() override
       pass
   ```
3. **Register** in `World._spawn_entity()`:
   ```gdscript
   "your_mob": preload("res://scenes/entities/mobs/YourMob.tscn"),
   ```
4. **Generate sprite**: `python generate.py --category characters --batch "your_mob" --style pixel_art_32`

---

### Add a New Skill Action

1. **Server** (`server/src/lib.rs`): Add handling in the `use_skill` reducer.
2. **Client** (`scripts/systems/SkillSystem.gd`): Add the skill constant and XP calculation.
3. **HUD** (`scripts/ui/HUD.gd`): Add a hotbar icon for the skill.
4. **Asset**: `python generate.py --category ui --batch "skill_icon_your_skill" --style icon_32`

---

### Add a New Biome

1. **Server** (`server/src/lib.rs`): Add new tile IDs to the `TileType` section and update `generate_chunk_tiles()` to use them based on world position.
2. **Client** (`scripts/world/TileRegistry.gd`): Add tile definitions with matching IDs.
3. **Pathfinder**: Update walkability in `TileRegistry.TILE_TYPES` — Pathfinder reads this automatically.
4. **Assets**: `python generate.py --category tiles --batch "your_tile_1,your_tile_2" --style pixel_art_32 --biome "your_biome"`

---

## Asset Generation System

### How It Works

The asset generator (`tools/asset_generator/generate.py`) wraps AI image APIs (OpenAI DALL-E 3 or Replicate/Stable Diffusion) with:

- **Style profiles**: Consistent prompt prefixes that lock the visual language (e.g., `pixel_art_32` = "32x32 pixel art, OSRS-style, black outline, flat shading, no anti-aliasing")
- **Category templates**: Per-category base prompts with slot variables (e.g., items category: "top-down RPG item sprite of {item_name}")
- **Manifest tracking**: Every generated asset is logged with its prompt, model, seed, and timestamp for reproducibility
- **Auto-placement**: Generated files go to `client/assets/generated/{category}/` with lowercase names

### Style Profiles

| Profile | Resolution | Visual Style | Best For |
|---------|-----------|-------------|---------|
| `pixel_art_32` | 32×32 | OSRS-style pixel art | Tiles, items, characters |
| `pixel_art_64` | 64×64 | HD pixel art | Bosses, key items |
| `icon_32` | 32×32 | Clean UI icon | Skills, abilities, menus |
| `portrait_128` | 128×128 | Character portrait | NPC dialogue, character select |

### Controlling the Look

To enforce a specific visual style, edit `tools/asset_generator/styles/base.py`. The style prefix is prepended to every prompt:

```python
PIXEL_ART_32 = StyleProfile(
    prefix="32x32 pixel art sprite, RPG game asset, OSRS-inspired color palette, "
           "black pixel outline, flat shading, no anti-aliasing, transparent background",
    negative="realistic, 3d, blurry, gradient, noise, photo",
    width=32, height=32,
    upscale=4  # Output saved at 128x128 for crisp display
)
```

### Batch Generation for Content Releases

For a raid or content drop, create a batch file:

```json
// tools/asset_generator/batches/fire_raid.json
{
    "style": "pixel_art_32",
    "category": "items",
    "context": "volcanic raid dungeon, fire theme, molten metal aesthetic",
    "items": [
        "flame_sword",
        "magma_staff",
        "ember_shield",
        "phoenix_bow",
        "obsidian_ring"
    ]
}
```

Then run: `python generate.py --batch-file batches/fire_raid.json`

---

## Server Schema Evolution

SpacetimeDB supports additive schema changes (add columns, add tables) without breaking connected clients. Destructive changes (rename/remove columns) require a migration.

**Safe changes**: Adding new tables, adding nullable columns, adding reducers.  
**Careful changes**: Removing columns (use `Option<T>` first), renaming (add new + deprecate old).

Always update ARCHITECTURE.md's table reference after schema changes.

---

## Performance Considerations

- **Chunk streaming**: The load radius is 2 chunks (configurable in `World.gd`). Increase for better visual density; decrease for lower bandwidth.
- **Entity culling**: Only entities in loaded chunks should exist as nodes. `World._on_network_entity_spawned()` handles this.
- **Network sync rate**: Position sync is throttled to 10hz by default in `NetworkManager`. Increase for more responsive multiplayer; decrease for lower server load.
- **TileMap layers**: Layer 0 = terrain, Layer 1 = overlay (roads, water effects). Keep layers minimal.

---

## Testing Without a Server

Set `NetworkManager.OFFLINE_MODE = true` to run with a local dummy world. The `WorldGenerator` client-side stub generates chunks locally using the same algorithm as the server. This ensures visual parity between offline dev and live play.
