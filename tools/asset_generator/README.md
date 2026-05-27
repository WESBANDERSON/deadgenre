# deadgenre Asset Generator

AI-powered sprite generator for all game content. Uses OpenAI DALL-E 3 or Stable Diffusion (via Replicate) to generate pixel art sprites that fit the deadgenre visual style.

## Setup

```bash
cd tools/asset_generator
pip install -r requirements.txt

# Set your API key (only one provider needed)
export OPENAI_API_KEY="sk-..."
# OR
export REPLICATE_API_TOKEN="r8_..."
```

## Usage

### Generate a single item
```bash
python generate.py --category items --batch "iron_sword" --style pixel_art_32
```

### Generate a raid's worth of items
```bash
python generate.py --category items \
  --batch "flame_sword,magma_staff,ember_shield,phoenix_bow,obsidian_ring" \
  --biome "volcanic" \
  --extra "fire theme, molten metal, glowing orange accents"
```

### Generate a new mob
```bash
python generate.py --category characters --batch "frost_giant"
```

### Generate tiles for a new biome
```bash
python generate.py --category tiles \
  --batch "lava_floor,obsidian_wall,magma_pool" \
  --biome "volcanic"
```

### Batch file (for content releases)
Create a JSON file in `batches/`:
```json
{
    "category": "items",
    "style": "pixel_art_32",
    "context": "fire dungeon raid, volcanic theme",
    "biome": "volcanic",
    "items": ["flame_sword", "magma_staff", "ember_shield"]
}
```
Run: `python generate.py --batch-file batches/fire_raid.json`

### Dry run (preview prompts without API calls)
```bash
python generate.py --category items --batch "iron_sword" --dry-run
```

### Check what's already been generated
```bash
python generate.py --show-manifest
```

## Output

Generated files are placed in `client/assets/generated/<category>/`.

Every generation is logged to `client/assets/generated/manifest.json` with:
- The exact prompt used
- Model and provider
- Generation timestamp
- File path

This makes regeneration reproducible: re-run with `--force` to refresh any asset.

## Style Profiles

List available styles: `python generate.py --list-styles`

| Profile | Output Size | Best For |
|---------|------------|---------|
| `pixel_art_32` | 128×128 (4× upscale) | Tiles, items, characters |
| `pixel_art_64` | 256×256 | Bosses, key items |
| `icon_32` | 128×128 | Skill icons, UI |
| `portrait_128` | 256×256 | NPC dialogue portraits |

## Wiring Generated Assets into the Game

After generating, tell the game to use the new sprite:

**For tiles** (`client/scripts/world/TileRegistry.gd`):
```gdscript
{ "id": 0, "name": "grass", "sprite_path": "res://assets/generated/tiles/grass.png", ... }
```

**For mobs** (`scripts/entities/Mob.gd` or specific mob script):
```gdscript
@onready var sprite = $AnimatedSprite2D
func _setup_visual():
    sprite.sprite_frames = load("res://assets/generated/characters/goblin.png")
```

**For items** (HUD inventory grid):
The inventory grid reads `icon_path` from `item_definition` server table.
Set `icon_path = "res://assets/generated/items/iron_sword.png"` in the server's
`seed_item_catalog()` function.
