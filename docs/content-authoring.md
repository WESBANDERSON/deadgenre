# Content Authoring Guide

This document explains how to create, validate, and deploy new game content for deadgenre — whether you're a human designer or an AI agent.

## Content Types

| Type | Directory | Schema | Server Table |
|------|-----------|--------|-------------|
| Items | `content/items/` | `item.schema.json` | `item_def` |
| Skills | `content/skills/` | `skill.schema.json` | `skill_def` |
| NPCs | `content/npcs/` | `npc.schema.json` | `npc_def` |
| World Chunks | `content/world/` | `world_chunk.schema.json` | `world_chunk` |
| Quests | `content/quests/` | (informal) | (not yet) |

## Workflow

### 1. Author Content

Create or edit a JSON file in the appropriate `content/` subdirectory. Files can contain a single object or an array of objects.

**Naming convention**: Use descriptive filenames like `volcanic_dungeon_weapons.json` or `coastal_region_chunks.json`. One file per logical group.

### 2. Validate

```bash
python tools/generators/content_validator.py
```

This checks every JSON file against its schema. Fix any errors before proceeding.

### 3. Import to Server

```bash
python tools/generators/import_content.py --type items
# or
python tools/generators/import_content.py --type all
```

This calls SpacetimeDB reducers to register each entry.

### 4. Add Assets (Optional)

If your content needs visual assets:

1. Generate or source texture/model files
2. Place them in `client/assets/textures/` or `client/assets/models/`
3. Update `client/assets/manifest.json` with key → path mappings
4. The content's `asset_key` field maps to the manifest entry

### 5. Test

Open the Godot client and verify your content appears correctly.

## AI Generation

### Using the Generator Scripts

```bash
# Generate weapons
python tools/generators/generate_items.py \
  --prompt "5 frost-themed weapons for an ice dungeon" \
  --category weapon \
  --count 5

# Output goes to content/items/generated_*.json
```

### Using Prompt Templates Directly

The `tools/templates/` directory contains detailed prompt templates for each content type. Feed these to your preferred LLM along with the specific request.

Available templates:
- `item_generation.md` — weapons, armor, consumables, materials
- `npc_generation.md` — hostile mobs, friendly NPCs, merchants
- `world_chunk_generation.md` — world layout and area design

### Best Practices for AI Generation

1. **Always validate output** — LLMs can produce invalid JSON or out-of-range values
2. **Check for ID conflicts** — ensure generated IDs don't collide with existing content
3. **Reference existing items** — loot tables should reference items that exist
4. **Follow the power curve** — see the tables in each template for stat ranges per level
5. **Batch by theme** — generate all content for one area/dungeon together for consistency

## Power Curve Reference

### Items

| Rarity | Level Range | Attack (weapon) | Defense (armor) | Value (gold) |
|--------|-------------|-----------------|-----------------|-------------|
| Common (0) | 1-10 | 5-15 | 3-10 | 10-100 |
| Uncommon (1) | 10-25 | 12-30 | 8-20 | 80-500 |
| Rare (2) | 25-50 | 25-50 | 18-35 | 400-2000 |
| Epic (3) | 50-75 | 45-80 | 30-55 | 1500-8000 |
| Legendary (4) | 75-99 | 70-120 | 50-80 | 5000-50000 |

### NPCs (Hostile)

| Level | HP | Attack | Defense | XP |
|-------|-----|--------|---------|-----|
| 1-5 | 15-50 | 2-8 | 1-5 | 5-25 |
| 5-15 | 40-120 | 6-18 | 4-12 | 20-80 |
| 15-30 | 100-250 | 15-35 | 10-25 | 60-200 |
| 30-50 | 200-500 | 30-55 | 20-40 | 150-500 |
| 50+ | 400-1500 | 45-100 | 35-70 | 400-2000 |

### Skills

XP curve: `xp_for_level = base_xp * level^2`

With `base_xp = 100`:
- Level 2: 400 XP
- Level 10: 10,000 XP
- Level 50: 250,000 XP
- Level 99: 980,100 XP
